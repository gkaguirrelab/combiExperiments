#include <iostream>
#include <filesystem>
#include "CLI11.hpp"
#include <algorithm>
#include <boost/asio.hpp>
#include <chrono>
#include <cstdint>
#include <iomanip>
#include <memory>
#include <thread>
#include <AGC.h>
#include <thread>
#include <vector>
#include <fstream>
#include <cereal/types/vector.hpp>
#include <cereal/archives/binary.hpp>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <linux/i2c-dev.h>

namespace fs = std::filesystem; 

/*
ALL LIBRARIES INCLUDED ABOVE HERE. MUST COMPILE WITH THE "libraries"" 
FOLDER FROM CURRENT DIRECTORY INCLUDED
*/

/*
Parse the command line arguments to the program 
@Param: argc: int - commandline argument count, 
        argv: char** - commandline argument values, 
        output_dir: filesystem:path - path to folder to output values in,
        controller_flags: std::array - array of bools to denote which controllers to use 
                          for recording, 
        duration: uint32_t - duration of the recording in seconds. 

@Ret: 0 on success, non-zero on failure
@Mod: output_dir - populates the variable with a filesystem path,
      duration - populates the variable with an int64_t representing the duration 
                 of recording in seconds 
      controller_flags - populates indices of sensors to activate
*/
int parse_args(const int argc, const char** argv, 
               fs::path& output_dir, std::array<bool, 4>& controller_flags,
               uint32_t& duration) {
    // Initialize the argparser class
    CLI::App app{"Control Firmware for GKA Lab Integrated Personal Light Logger Wearable Device"};
    
    // Add the required output path variable and populate the output_dir variable
    app.add_option("-o,--output_dir", output_dir, "The directory in which to output files. Does not need to exist.")
        ->required();

    // Add the required duration variable and populate it with the number of seconds to record for. The range is between 
    // 1 second and the number of seconds in 24 hours. 
    app.add_option("-d,--duration", duration, "Duration of the recording to make")
        ->required()
        ->check(CLI::Range(1, 86400));
    
    // Populate the controller flags for the controllers we will use
    app.add_option("-m,--minispect", controller_flags[0], "0/1 boolean flag to denote whether we will use the MS in recording.");
    app.add_option("-w,--world", controller_flags[1], "0/1 boolean flag to denote whether we will use the World Camera in recording.");
    app.add_option("-p,--pupil", controller_flags[2], "0/1 boolean flag to denote whether we will use the Pupil Camera in recording.");
    app.add_option("-s,--sunglasses", controller_flags[3], "0/1 boolean flag to denote whether we will use the Sunglasses Recorder in recording.");

    // Parse the arguments and catch if there was a parsing error, 
    // outputting helpful information upon failure. 
    try {
        CLI11_PARSE(app, argc, argv);
    }
    catch(CLI::ParseError& e) {
        app.exit(e); //Returns non 0 error code on failure
    }

    return 0; // Returns 0 on success
}


/*
Continous writing monitor for all of the process. 
Writes buffers when they are full (after a small grace period).
@Param: output_dir: fs::path* - The output directory where files will be written 
        duration: uint32_t - The duration in seconds of the entire recording
        buffer_size_s: uint8_t - The duration in seconds a given buffer is allocated for
        buffers_one: std::vector<std::vector<uint8_t>>* - Pointer to the first suprabuffer holding all of the sensors subbuffers
        buffers_two: std::vector<std::vector<uint8_t>>* - Pointer to the second suprabuffer holding all of the sensors subbuffers
@Ret: N/A 
@Mod: Writes binary serialized buffers to numbered files in output_dir 
*/
int write_process_parallel(const fs::path* output_dir, 
                           const uint32_t duration, 
                           const uint8_t buffer_size_s,
                           std::vector<std::vector<uint8_t>>* buffers_one, 
                           std::vector<std::vector<uint8_t>>* buffers_two) 
    {
    // Let the user know the write process started successfully 
    std::cout << "Write | Initialized" << '\n';
    
    // Capture the start time of this process
    auto start_time = std::chrono::steady_clock::now();
    auto last_write_time = std::chrono::steady_clock::now();

    // Define a counter to keep track of which write we are on 
    uint32_t write_num = 1;

    // Define a buffer pointer to use to switch between the buffers when writing.
    // Initialize it as buffers one
    std::vector<std::vector<uint8_t>>* buffer = buffers_one; 

    // Define the variables we will use to keep track of filenames and their open files. 
    fs::path filename = "";
    std::ofstream out_file; 

    // Define timing variables we will use later

    // Write at regular intervals until the end of the recording 
    std::cout << "Write | Beginning waiting for writes..." << '\n';
    while(true) {
        // Capture the elapsed time since the start
        auto current_time = std::chrono::steady_clock::now();
        auto elapsed_time = current_time - start_time;
        auto elapsed_seconds = std::chrono::duration_cast<std::chrono::seconds>(elapsed_time).count();
        auto time_since_last_write = std::chrono::duration_cast<std::chrono::seconds>(current_time - last_write_time).count();

        // End recording if we have reached the desired duration. 
        if ((uint32_t) elapsed_seconds >= duration) {
            break;
        }

        // If we have filled at least one buffer and it is a few seconds into the next buffer, 
        // write out the previous buffer and clear it for the next swap 
        if(time_since_last_write >= (buffer_size_s + 2)) {
            // Begin timing how long writing this chunk took
            auto start_write_time = std::chrono::steady_clock::now();
            std::cout << "Write | Writing buffer: " << write_num << '\n';  

            // Retrieve the correct buffer to write
            buffer = (write_num % 2 == 0) ? buffers_two : buffers_one;

            { // Must force archive to go out of scope, ensuring all contents are flushed
                cereal::BinaryOutputArchive out_archive(out_file);
                out_archive(*buffer);
            } // Source: https://uscilab.github.io/cereal/quickstart.html under Serialize your data
            
            // Close the output file and reset the filename to ""
            out_file.close();
            filename = "";
            
            // Output how long writing this chunk took
            auto elapsed_time_writing = std::chrono::steady_clock::now() - start_write_time;
            std::cout << "Write | Writing buffer: " << write_num << " Took(ms): " << std::chrono::duration<float_t, std::milli>(elapsed_time_writing).count() << '\n';  


            // Update the last time we wrote to the current time 
            last_write_time = current_time;

            // Incremement the write num
            write_num++;
        }
        // Otherwise, let's create the file for the next buffer
        else {  
            // Generate the filename for the next chunk's output
            if(filename == "") {
                filename = "chunk_" + std::to_string(write_num) + ".bin";
            }

            // Open the file for the next chunk
            if(!out_file.is_open()) {
                // Open a file in the output directory for writing 
                out_file.open(*output_dir / filename, std::ios::binary);

                // Ensure the file was opened correctly 
                if(!out_file.is_open()) {
                    std::cerr << "ERROR: Failed to open outfile: " << *output_dir / filename << '\n';
                    exit(1);
                }
            }
        }
    }

    // When we break out of this loop, because need to write out one final buffer. This is because we wait until 
    // after the next buffer to start to write in the loop. At the end, the next buffer will never start, therefore 
    // it will never be written
    
    // Begin timing how long writing this chunk took
    auto start_write_time = std::chrono::steady_clock::now();
    std::cout << "Write | Writing buffer: " << write_num << '\n';  

   // Retrieve the correct buffer to write
    buffer = (write_num % 2 == 0) ? buffers_two : buffers_one;

    { // Must force archive to go out of scope, ensuring all contents are flushed
        cereal::BinaryOutputArchive out_archive(out_file);
        out_archive(*buffer);
    } // Source: https://uscilab.github.io/cereal/quickstart.html under Serialize your data
    
    // Close the output file and reset the filename to ""
    out_file.close();
    filename = "";
    
    // Output how long writing this chunk took
    auto elapsed_time_writing = std::chrono::steady_clock::now() - start_write_time;
    std::cout << "Write | Writing buffer: " << write_num << " Took(ms): " << std::chrono::duration<float_t, std::milli>(elapsed_time_writing).count() << '\n';  

    return 0; 
}


/*
Continous recorder for the MS. 
@Param: duration: uint32_t - Time in seconds to record for. 
        buffer one: std::vector<uint8_t>* - The first of two buffers allocated for the sensor
        buffer two: std::vector<uint8_t>* - The second of two buffers allocated for the sensor
        buffer_size_frames: uint16_t - The amount of frames until each buffer is full and needs to swap
@Ret: 0 on success, throws errors otherwise
@Mod: Fills buffer_one and buffer_two with captured values. 
*/
int minispect_recorder(const uint32_t duration, 
                       std::vector<uint8_t>* buffer_one, 
                       std::vector<uint8_t>* buffer_two,
                       const uint16_t buffer_size_frames) 
    {
    // Create a boost io_service object to manage the IO objects
    // and initialize serial port variable
    boost::asio::io_service io;
    boost::asio::serial_port ms(io);

    // Define the data length and the start delimeter. Therefore, 
    // each transmission is actually 2 + the data length 
    constexpr char start_delim = '<';
    constexpr char end_delim = '>';
    constexpr size_t data_length = 148; 

    // Define variables we will use to probe the serial stream and read individual 
    // bytes to look for delimeters, as well as the buffer to read data 
    std::array<char, 1> byte_read; 
    std::array<char, data_length> reading_buffer; 

    // Initialize a counter for how many frames we are going to capture 
    size_t frame_num = 0; 

    // Attempt to connect to the MS
    std::cout << "MS | Initializating..." << '\n'; 
    try {
        // Connect to the MS
        ms.open("/dev/ttyACM0");

    }
    catch(const std::exception& e) {
        std::cerr << "ERROR: " << e.what() << '\n';

        // Close the MS and safely exit from the error
        if(ms.is_open()) { ms.close();}
        exit(1);
    }
    
    // Attempt to set options for the serial connection to the MS
    try{ 
        // Set serial port configuration options
        ms.set_option(boost::asio::serial_port_base::baud_rate(115200));
        ms.set_option(boost::asio::serial_port_base::character_size(8));
        ms.set_option(boost::asio::serial_port_base::parity(boost::asio::serial_port_base::parity::none));
        ms.set_option(boost::asio::serial_port_base::stop_bits(boost::asio::serial_port_base::stop_bits::one));
        ms.set_option(boost::asio::serial_port_base::flow_control(boost::asio::serial_port_base::flow_control::none));
    }
    catch(const std::exception& e) {
        std::cerr << "ERROR: " << e.what() << '\n';

        // Close the MS and safely exit from the error
        if(ms.is_open()) { ms.close();}
        exit(1);
    }

    // Set the initial buffer pointer to buffer 1 and track which one 
    // we are on 
    std::vector<uint8_t>* buffer = buffer_one;
    uint8_t current_buffer = 1;

    std::cout << "MS | Initialized." << '\n';

    // Begin recording for the given duration
    std::cout << "MS | Beginning recording..." << '\n';
    auto start_time = std::chrono::steady_clock::now(); // Capture the start time 
    while(true) {
        // Capture the elapsed time and ensure it is in the units of seconds
        auto elapsed_time = std::chrono::steady_clock::now() - start_time;
        auto elapsed_seconds = std::chrono::duration_cast<std::chrono::seconds>(elapsed_time).count();

        // End recording if we have reached the desired duration.
        if ((uint32_t) elapsed_seconds >= duration) {
            break;
        }
        
        // Swap buffers if we filled up this buffer
        if(frame_num > 0 && frame_num % buffer_size_frames == 0) {
            // If we are using buffer two, switch to buffer one, otherwise vice versa
            buffer = (current_buffer % 2 == 0) ? buffer_one : buffer_two;

            // Update the current buffer state
            current_buffer = (current_buffer % 2) + 1;
        }


        // Read a byte from the serial stream
        boost::asio::read(ms, boost::asio::buffer(byte_read));

        // If this byte is the start buffer, note that we have received a reading
        if (byte_read[0] == start_delim) {            
            // Now we can read the correct amount of data
            boost::asio::read(ms, boost::asio::buffer(reading_buffer, data_length));

            // Read one more byte. This essentially serves to ensure we read the correct amount of data 
            // as well as reset the byte_read buffer to not the starting delimeter. It should ALWAYS be the end 
            // delimeter
            boost::asio::read(ms, boost::asio::buffer(byte_read));

            if(byte_read[0] != end_delim) {
                std::cerr << "MS | ERROR: Start delimeter not closed by end delimeter." << '\n'; 

                // Close the MS and safely exit from the error
                if(ms.is_open()) { ms.close();}
                exit(1);
            }

            // Append these bytes to the buffer for the duration of the video
            buffer->insert(buffer->end(), reading_buffer.begin(), reading_buffer.end()); 

            // Increment the number of captured frames 
            frame_num++; 
        } 
    }
    
    // Output information about how much data we captured 
    std::cout << "MS | Capture Frames: " << frame_num << '\n';

    // Close the connection to the MS device
    std::cout << "MS | Closing..." << '\n'; 
    ms.close(); 
    std::cout << "MS | Closed." << '\n'; 

    return 0;
}

/*
Continous recorder for the World Camera.
@Param: duration: uint32_t - Time in seconds to record for. 
        buffer one: std::vector<uint8_t>* - The first of two buffers allocated for the sensor
        buffer two: std::vector<uint8_t>* - The second of two buffers allocated for the sensor
        buffer_size_frames: uint16_t - The amount of frames until each buffer is full and needs to swap
@Ret: 0 on success, errors and quits otherwise. 
@Mod: Fills buffer_one and buffer_two with captured values. 
*/
int world_recorder(const uint32_t duration, 
                   std::vector<uint8_t>* buffer_one, 
                   std::vector<uint8_t>* buffer_two,
                   const uint16_t buffer_size_frames) 
    {
    // Initialize libcamera
    std::cout << "World | Initializating..." << '\n'; 
    
    // Initialize a counter for how many frames we are going to capture, 
    // and the size of our buffers 
    size_t frame_num = 0; 

    // Initialize a variable we will use to hold the mean of certain frames when we do AGC
    uint8_t frame_mean;

    // Initialize variables for the initial gain and exposure of the camera 
    float_t current_gain = 1;
    float_t current_exposure = 100; 

    // Set the initial buffer pointer to buffer 1
    std::vector<uint8_t>* buffer = buffer_one;
    uint8_t current_buffer = 1;
    
    std::cout << "World | Initialized." << '\n';

    // Begin recording for the given duration
    std::cout << "World | Beginning recording..." << '\n';
    auto start_time = std::chrono::steady_clock::now(); // Capture the start time
    auto last_gain_change = start_time;
    while(true) {
        // Capture the elapsed time since start and ensure it is in the units of seconds
        auto current_time = std::chrono::steady_clock::now();
        auto elapsed_time = current_time - start_time;
        auto elapsed_seconds = std::chrono::duration_cast<std::chrono::seconds>(elapsed_time).count();

        // End recording if we have reached the desired duration. 
        if ((uint32_t) elapsed_seconds >= duration) {
            break;
        }

        // Swap buffers if this one is full
        if(frame_num > 0 && frame_num % buffer_size_frames == 0) {
            // If we are currently using buffer 2, swap to 1
            
            // If we are using buffer two, switch to buffer one, otherwise vice versa
            buffer = (current_buffer % 2 == 0) ? buffer_one : buffer_two;

            // Update the current buffer state
            current_buffer = (current_buffer % 2) + 1;
        }

        // Capture the desired frame
        int frame = 100;

        // Save the desired frame into the buffer (TODO: This is a kludge method just for now. ideally we will not be overwriting)
        (*buffer)[frame_num % buffer_size_frames] = frame; 


        // Adjust the AGC every 250MS
        auto time_since_last_agc = std::chrono::duration_cast<std::chrono::milliseconds>(current_time - last_gain_change).count();
        if(time_since_last_agc >= 250) {
            // Calculate the mean of the frame
            frame_mean = frame; 

            // Use the mean as an input and current settings to calculate the new gain/exposure 
            RetVal adjusted_camera_info = AGC(frame_mean, current_gain, current_exposure, 0.95);

            // Set the camera to use the new gain/exposure settings
            current_gain = adjusted_camera_info.adjusted_gain;
            current_exposure = adjusted_camera_info.adjusted_exposure; 

            // Update the last gain change if we just changed the gain
            last_gain_change = current_time;
        }

        // Increment the number of captured frames
        frame_num++;
    }

    // Output information about how much data we captured 
    std::cout << "World | Captured Frames: " << frame_num << '\n';

    // Close the connection to the Camera device
    std::cout << "World | Closing..." << '\n'; 

    std::cout << "World | Closed." << '\n'; 


    return 0;
}

/*
Continous recorder for the Pupil Camera.
@Param: duration: uint32_t - Time in seconds to record for. 
        buffer one: std::vector<uint8_t>* - The first of two buffers allocated for the sensor
        buffer two: std::vector<uint8_t>* - The second of two buffers allocated for the sensor
        buffer_size_frames: uint16_t - The amount of frames until each buffer is full and needs to swap
@Ret: 0 on success, errors and quits otherwise. 
@Mod: Fills buffer_one and buffer_two with captured values. 
*/
int pupil_recorder(const uint32_t duration, 
                   std::vector<uint8_t>* buffer_one, 
                   std::vector<uint8_t>* buffer_two,
                   const uint16_t buffer_size_frames) 
    {
    // Initialize libUVC 
    std::cout << "Pupil | Initializating..." << '\n'; 

    // Initialize a counter for how many frames we are going to capture 
    // and how big our buffer is
    size_t frame_num = 0; 
    
    std::cout << "Pupil | Initialized." << '\n';

    // Set the initial buffer pointer to buffer 1
    std::vector<uint8_t>* buffer = buffer_one;
    uint8_t current_buffer = 1;

    // Begin recording for the given duration
    std::cout << "Pupil | Beginning recording..." << '\n';
    auto start_time = std::chrono::steady_clock::now(); // Capture the start time
    while(true) {
        // Capture the elapsed time since start and ensure it is in the units of seconds
        auto current_time = std::chrono::steady_clock::now();
        auto elapsed_time = current_time - start_time;
        auto elapsed_seconds = std::chrono::duration_cast<std::chrono::seconds>(elapsed_time).count();

        // End recording if we have reached the desired duration. 
        if ((uint32_t) elapsed_seconds >= duration) {
            break;
        }

        // Swap buffers if this one is full
        if(frame_num > 0 && frame_num % buffer_size_frames == 0) {

            // If we are using buffer two, switch to buffer one, otherwise vice versa
            buffer = (current_buffer % 2 == 0) ? buffer_one : buffer_two;
            
            // Update the current buffer state
            current_buffer = (current_buffer % 2) + 1;
        }

        // Capture the desired frame
        int frame = 100;

        // Save the desired frame into the buffer
        (*buffer)[frame_num % buffer_size_frames] = frame; 

        // Increment the number of captured frames
        frame_num++;
    }

    // Output information about how much data we captured 
    std::cout << "Pupil | Captured Frames: " << frame_num << '\n';

    // Close the connection to the Camera device
    std::cout << "Pupil | Closing..." << '\n'; 

    std::cout << "Pupil | Closed." << '\n'; 

    return 0;
}

/*
Continous recorder for the Sunglasses Hall magnetic sensor. 
@Param: duration: uint32_t - Time in seconds to record for. 
        buffer one: std::vector<uint8_t>* - The first of two buffers allocated for the sensor
        buffer two: std::vector<uint8_t>* - The second of two buffers allocated for the sensor
        buffer_size_frames: uint16_t - The amount of frames until each buffer is full and needs to swap
@Ret: 0 on success, errors and quits otherwise. 
@Mod: Fills buffer_one and buffer_two with captured values. 
*/
int sunglasses_recorder(const uint32_t duration,
                        std::vector<uint8_t>* buffer_one, 
                        std::vector<uint8_t>* buffer_two,
                        const uint16_t buffer_size_frames) 
    {
    // Initialize a connection to the bus to read from the sensor
    std::cout << "Sunglasses | Initializating..." << '\n'; 

    // Define details about where the connection to the device will live
    constexpr const char* i2c_bus_number = "/dev/i2c-1";     // I2C bus number, corresponds to /dev/i2c-1
    constexpr int device_addr = 0x6B; // Define the memory address of the device
    constexpr uint8_t config = 0x10; // Configuration command: Continuous conversion mode, 12-bit Resolution (0x10)
    constexpr uint8_t read_reg = 0x00;

    // Initialize a counter for how many frames we are going to capture 
    // and how big our buffer is
    size_t frame_num = 0; 

    // Set the initial buffer pointer to buffer 1
    std::vector<uint8_t>* buffer = buffer_one;
    uint8_t current_buffer = 1;

    // Attempt to open the I2C bus
    int i2c_bus = open(i2c_bus_number, O_RDWR);
    if (i2c_bus < 0) {
        std::cerr << "Sunglasses | Failed to open the I2C bus" << '\n';
        exit(1);
    }

    // Set the I2C slave address
    if (ioctl(i2c_bus, I2C_SLAVE, device_addr) < 0) {
        std::cerr << "Sunglasses | Failed to set I2C address" << '\n';
        close(i2c_bus);
        exit(1);
    }

    // Write the configuration command
    if (write(i2c_bus, &config, 1) != 1) {
        std::cerr << "Sunglasses | Failed to write to the I2C device" << '\n';
        close(i2c_bus);
        exit(1);
    }

    // Write the register address
    if (write(i2c_bus, &read_reg, 1) != 1) {
        std::cerr << "Sunglasses | Failed to write to the I2C device" << '\n';
        close(i2c_bus);
        exit(1);
    }

    std::cout << "Sunglasses | Initialized..." << '\n'; 

    // Begin recording for the given duration
    std::cout << "Sunglasses | Beginning recording..." << '\n';
    auto start_time = std::chrono::steady_clock::now(); // Capture the start time
    while(true) {
        // Capture the elapsed time since start and ensure it is in the units of seconds
        auto current_time = std::chrono::steady_clock::now();
        auto elapsed_time = current_time - start_time;
        auto elapsed_seconds = std::chrono::duration_cast<std::chrono::seconds>(elapsed_time).count();
        
        // End recording if we have reached the desired duration. 
        if ((uint32_t) elapsed_seconds >= duration) {
            break;
        }

        // Swap buffers if this one is full (divide by two here since we are doing 2 writes per frame captured)
        if(frame_num > 0 && (frame_num / 2) % buffer_size_frames == 0) {

            // If we are using buffer two, switch to buffer one, otherwise vice versa
            buffer = (current_buffer % 2 == 0) ? buffer_one : buffer_two;
            
            // Update the current buffer state
            current_buffer = (current_buffer % 2) + 1;
        }

        // Read 2 bytes from the device
        uint8_t data[2] = {0};
        if (read(i2c_bus, data, 2) != 2) {
            std::cerr << "Failed to read from the I2C device" << '\n';
            close(i2c_bus);
            exit(1);
        }

        // Process the data to convert it to 12 bits
        int16_t raw_adc = ((data[0] & 0x0F) << 8) | data[1];
        if (raw_adc > 2047) {
            raw_adc -= 4096;
        }

        // Need to split our reading in two parts because our reading is 12 bit and 
        // our buffer is for 8 bit values
        uint8_t lower_byte = raw_adc & 0xFF;        // Lower 8 bits of reading
        uint8_t upper_byte = (raw_adc >> 8) & 0xFF; // Upper 8 bits of reading

        // Write the bytes from the reading to the buffer
        (*buffer)[frame_num % buffer_size_frames] = lower_byte; 
        (*buffer)[(frame_num + 1) % buffer_size_frames] = upper_byte; 

        // Increment the captured frame number
        frame_num+=2; 

        // Sleep for a few seconds between readings, as high FPS for sunglasses 
        // is not important
        std::this_thread::sleep_for(std::chrono::seconds(1));

    }

    // Output information about how much data we captured 
    std::cout << "Sunglasses | Captured Frames: " << frame_num << '\n';

    // Close the connection to the i2c_bus device
    std::cout << "Sunglasses | Closing..." << '\n'; 
    close(i2c_bus);
    std::cout << "Sunglasses | Closed." << '\n'; 

    return 0;
}


int main(int argc, char **argv) {
    // Initialize variable to hold output directory path. Path need not exist
    fs::path output_dir;

    // Initialization container for the duration (in seconds) of the video to record. If this is 
    // negative, then it will be for infinity
    uint32_t duration; 

    // Initialize controller flags as entirely false. This is because we will denote which controllers 
    // to use based on arguments passed. 
    constexpr std::array<char, 4> controller_names = {'M', 'W', 'P', 'S'};  // this can be constexpr because values will never change 
    std::vector<std::function<int(int32_t, std::vector<uint8_t>*, std::vector<uint8_t>*, uint16_t)>> controller_functions = {minispect_recorder, world_recorder, pupil_recorder, sunglasses_recorder}; // this CANNOT be constexpr because function stubs are dynamic
    std::array<bool, 4> controller_flags = {false, false, false, false}; // this CANNOT be constexpr because values will change 
    constexpr std::array<uint8_t, 4> sensor_FPS = {1, 200, 120, 1};
    constexpr std::array<uint64_t, 4> data_size_multiplers = {sensor_FPS[0]*148, sensor_FPS[1]*60*80, sensor_FPS[2]*400*400, sensor_FPS[3]*2}; // this can be constexpr because values will never change
    constexpr uint8_t sensor_buffer_size = 10; // Initialize a variable for the size of each sensors' buffer in seconds. This will be regularly written out and cleared

    // Parse the commandline arguments.
    if(parse_args(argc, (const char**) argv, output_dir, controller_flags, duration)) {
        std::cerr << "ERROR: Could not properly parse args." << '\n'; 
        return 1; 
    }; 

    // If argparse was successful, we will ensure the output directory exists
    // First check to see if it does not already exist. If that is true, then we will make it. 
    // Then, we must check if that was succesful. If it was not successful, we output an error
    if(!fs::exists(output_dir) && !fs::create_directories(output_dir)) {
        std::cerr << "ERROR: Could not create output directory: " << output_dir << '\n'; 
        return 1;
    }

    // Find only the indices of sensors we are to use
    std::vector<size_t> used_controller_indices;
    for(size_t i = 0; i < controller_flags.size(); i++) {
        if(controller_flags[i] == true) {
            used_controller_indices.push_back(i);
        }
    }

    // Retrieve the number of sensors we are to use and ensure it is both greater than 0 
    // and within the range of sensors we have available
    const int num_active_sensors = used_controller_indices.size();
    if(num_active_sensors == 0 || (num_active_sensors > (int) controller_flags.size() )) {
        std::cerr << "ERROR: Invalid number of active sensors: " << num_active_sensors << '\n'; 
        return 1; 
    }

    // Output information about where this recording's data will be output, as well as 
    // the controllers we will use
    std::cout << "----ARGPARSE AND FILE SETUP SUCCESSFUL---" << '\n';

    std::cout << "Output Directory: " << output_dir << '\n';
    std::cout << "Duration: " << duration << " seconds" << '\n';
    std::cout << "Buffer size: " << std::to_string(sensor_buffer_size) << " seconds" << '\n'; // Not sure why but I had to use std::to_string to get this to show
    std::cout << "Num Active Controllers: " << num_active_sensors << '\n';
    std::cout << "Controllers to use: " << '\n';
    for(size_t i = 0; i < controller_names.size(); i++) {
        std::cout << '\t' << controller_names[i] << " | " << controller_flags[i] << '\n';
    }

    // Once we know the duration and the sensors we are using, we are going to dynamically 
    // allocate two buffers of duration seconds per sensor of 8bit values. This is because 
    // we are going to spawn between them
    
    // First, allocate outer vectors for all of the potential sensors
    std::vector<std::vector<uint8_t>> buffers_one(controller_names.size());
    std::vector<std::vector<uint8_t>> buffers_two(controller_names.size());

    // Iterate over the inner buffers and reserve enough memory + fill in dummy values for all of the readings.
    // Only do this for the sensors we are actually using
    for(const auto& controller_idx: used_controller_indices) { 
        // Mutiply the duration times the data size. 
        // For instance:
            // the MS reads 148 bytes per second. 
            // the World cam reads at 200x30x40 bytes per second 
            // the Pupil cam reads at 120x400x400 bytes per second
            // the sunglasses sensor reads at 1x2 bytes per second 

        // Allocate time + 1 in case things read a little faster than normal
        buffers_one[controller_idx].resize(sensor_buffer_size * data_size_multiplers[controller_idx]); 
        buffers_two[controller_idx].resize(sensor_buffer_size * data_size_multiplers[controller_idx]); 
    }

    // Output information about how the buffer allocation process went
    std::cout << "----BUFFER ALLOCATIONS SUCCESSFUL---" << '\n';
    std::cout << "Num sensor buffers: " << buffers_one.size() << '\n';
    std::cout << "Sensor buffer capacities(bytes): " << '\n';
    for(size_t i = 0; i < buffers_one.size(); i++) {
        std::cout << '\t' << controller_names[i] << ": " << buffers_one[i].size() << '\n';
    }

    // Begin parallel recording and enter performance critical section. All print statements below 
    // this point MUST use \n as a terminator instead of '\n', which is significantly slower, and all code should be 
    // absolutely optimally written in regards to time efficency. 
    std::vector<std::thread> threads;

    // We will spawn only threads for those controllers that we are going to use. 
    // Spawn them, with the duration of recording as an argument
    std::cout << "----SPAWNING THREADS---" << '\n';
    
    //sunglasses_recorder(duration, &buffers_one[0], &buffers_two[0], 5);
    
    for (const auto& used_controller_idx: used_controller_indices) {
        threads.emplace_back(std::thread(controller_functions[used_controller_idx], 
                                         duration,
                                         &buffers_one[used_controller_idx], &buffers_two[used_controller_idx],
                                         sensor_buffer_size*sensor_FPS[used_controller_idx]));
    }

    // We will also spawn the parallel write process, to monitor output from these threads
    threads.emplace_back(std::thread(write_process_parallel, &output_dir, duration, 
                                                             sensor_buffer_size,
                                                             &buffers_one, &buffers_two));

    // Join threads to ensure they complete before the program ends
    for (auto& t : threads) {
        t.join();
    }

    // Signal to the user that the threads has successfully closed their operation
    std::cout << "----THREADS CLOSED SUCCESSFULLY---" << '\n'; 


    return 0; 
}