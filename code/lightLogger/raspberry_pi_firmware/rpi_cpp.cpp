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
#include <libcamera/libcamera.h>
#include <AGC.cpp>
#include <thread>
#include <vector>
#include <fstream>
#include <cereal/types/vector.hpp>
#include <cereal/archives/binary.hpp>


//#include <libuvc/libuvc.h>
//#include <libcamera/camera_manager.h>

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
Continous monitor for all of the process. Oversees the write queue and writes when necessary
@Param:
@Ret:
@Mod:
*/
int write_process(fs::path& output_dir, std::vector<std::vector<uint8_t>>& buffers) {
    // Generate the filename for this outfile
    fs::path filename = "out.bin";

    // Open a file in the output directory for writing 
    std::ofstream out_file(output_dir / filename, std::ios::binary);

    // Ensure the file was opened correctly 
    if(!out_file.is_open()) {
        std::cerr << "ERROR: Failed to open outfile: " << output_dir / filename << '\n';
        exit(1);
    }

    { // Must force archive to go out of scope, ensuring all contents are flushed
        cereal::BinaryOutputArchive out_archive(out_file);
        out_archive(buffers);
    } // Source: https://uscilab.github.io/cereal/quickstart.html under Serialize your data
    
    // Close the output file
    out_file.close();

    
    // Open a file for reading
    std::ifstream in_file(output_dir / filename, std::ios::binary); 

    if(!in_file.is_open()) {
        std::cerr << "ERROR: Failed to open infile: " << output_dir / filename << '\n';
        exit(1);
    }
    
    std::vector<std::vector<uint8_t>> myData; 
    {   // Read the data in to make sure it was properly serialized
        cereal::BinaryInputArchive archive(in_file);  // Create an input archive
        archive(myData);
    }

    std::cout << "Size of my data: " << myData.size() << '\n';


    return 0; 
}


/*
Continous recorder for the MS. Records either INF or for a set duration
@Param: duration: uint32_t - Time in seconds to record for. 
@Ret: 0 on success, errors and quits otherwise. 
@Mod: N/A
*/
int minispect_recorder(uint32_t duration, std::vector<uint8_t>* buffer) {
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
    std::cout << "MS | Initialized." << '\n';

    // Begin recording
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
Continous recorder for the World Camera. Records either INF or for a set duration
@Param: duration: uint32_t - Duration of the recording in seconds.
@Ret: 0 on success
@Mod: N/A
*/
int world_recorder(uint32_t duration, std::vector<uint8_t>* buffer) {
    // Initialize libcamera
    std::cout << "World | Initializating..." << '\n'; 
    //libcamera::CameraManager cameraManager;

    // Initialize a counter for how many frames we are going to capture 
    size_t frame_num = 0; 

    // Initialize a variable we will use to hold the mean of certain frames when we do AGC
    uint8_t frame_mean;

    // Initialize variables for the initial gain and exposure of the camera 
    float_t current_gain = 1;
    float_t current_exposure = 100; 
    
    std::cout << "World | Initialized." << '\n';

    // Begin recording
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

        // Capture the desired frame
        int frame = 100;

        // Save the desired frame into the buffer (TODO: This is a kludge method just for now. ideally we will not be overwriting)
        (*buffer)[frame_num % duration] = frame; 


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
    std::cout << "World | Capture Frames: " << frame_num << '\n';

    // Close the connection to the Camera device
    std::cout << "World | Closing..." << '\n'; 

    std::cout << "World | Closed." << '\n'; 


    return 0;
}


/*
Continous recorder for the World Camera. Records either INF or for a set duration
@Param:
@Ret:
@Mod:
*/
/*
int pupil_recorder(int64_t duration) {
    // Initialize UVC required variables
    uvc_context_t *context;
    uvc_device_t *device;
    uvc_device_t **device_list;
    uvc_device_handle_t *device_handle;
    uvc_error_t res;
    
    // Initialize libuvc
    res = uvc_init(&context, NULL);
    if (res < 0) {
        std::cerr << "Error initializing libuvc: " << uvc_strerror(res) << '\n';
        exit(1);
    }

    // Retrieve a list of the available devices
    res = uvc_get_device_list(context, &device_list);
    if (res < 0) {
        std::cerr << "Error getting device list: " << uvc_strerror(res) << std::endl;
        uvc_exit(context);
        exit(1);
    }   

    size_t num_cams;
    for(int i = 0; i < 5; i++) {
        if(device_list[i] == NULL) {
            num_cams = i;
            break; 
        }
    }

    std::cout << "Num Cams: " << '\n';
    std::cout << num_cams << '\n';

    // Free device list
    uvc_free_device_list(device_list, 1);

    // Clean up
    uvc_exit(context);


    return 0;

}

*/

int main(int argc, char **argv) {
    // Initialize variable to hold output directory path. Path need not exist
    fs::path output_dir;

    // Initialization container for the duration (in seconds) of the video to record. If this is 
    // negative, then it will be for infinity
    uint32_t duration; 

    // Initialize controller flags as entirely false. This is because we will denote which controllers 
    // to use based on arguments passed. 
    constexpr std::array<char, 4> controller_names = {'M', 'W', 'P', 'S'};  // this can be constexpr because values will never change 
    std::vector<std::function<int(int32_t, std::vector<uint8_t>*)>> controller_functions = {world_recorder, minispect_recorder}; // this CANNOT be constexpr because function stubs are dynamic
    std::array<bool, 4> controller_flags = {false, false, false, false}; // this CANNOT be constexpr because values will change 
    constexpr std::array<uint16_t, 4> data_size_multiplers = {148, 1, 1, 1}; // this can be constexpr because values will never change
    
    // Parse the commandline arguments.
    if(parse_args(argc, (const char**) argv, output_dir, controller_flags, duration)) {
        std::cerr << "ERROR: Could not properly parse args." << '\n'; 
        exit(1);
    }; 

    // If argparse was successful, we will ensure the output directory exists
    // First check to see if it does not already exist. If that is true, then we will make it. 
    // Then, we must check if that was succesful. If it was not successful, we output an error
    if(!fs::exists(output_dir) && !fs::create_directories(output_dir)) {
        std::cerr << "ERROR: Could not create output directory: " << output_dir << '\n'; 
        exit(1);
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
        exit(1);
    }

    // Output information about where this recording's data will be output, as well as 
    // the controllers we will use
    std::cout << "----ARGPARSE AND FILE SETUP SUCCESSFUL---" << '\n';

    std::cout << "Output Directory: " << output_dir << '\n';
    std::cout << "Duration: " << duration << " seconds" << '\n';
    std::cout << "Num Active Controllers: " << num_active_sensors << '\n';
    std::cout << "Controllers to use: " << '\n';
    for(size_t i = 0; i < controller_names.size(); i++) {
        std::cout << '\t' << controller_names[i] << " | " << controller_flags[i] << '\n';
    }

    // Once we know the duration and the number of sensors we are using, we are going to dynamically 
    // allocate a buffer of duration seconds per sensor of 8bit values 
    std::vector<std::vector<uint8_t>> buffers(num_active_sensors); // First, allocate an outer vector of num_active_sensors. 
    
    // Iterate over the inner buffers and reserve enough memory + fill in dummy values for all of the readings.
    for(size_t i = 0; i < buffers.size(); i++) { 
        // Mutiply the duration times the data size. For instance, the MS reads 148 bytes per second. 
        buffers[i].resize((duration + 1) * data_size_multiplers[i]);  // Allocate duration + 1 in case things read a little faster than normal
    }

    // Output information about how the buffer allocation process went
    std::cout << "----BUFFER ALLOCATIONS SUCCESSFUL---" << '\n';
    std::cout << "Num buffers: " << num_active_sensors << '\n';
    std::cout << "Buffer capacities: " << num_active_sensors << '\n';
    for(size_t i = 0; i < buffers.size(); i++) {
        std::cout << '\t' << controller_names[used_controller_indices[i]] << ": " << buffers[i].capacity() << '\n';
    }

    // Begin parallel recording and enter performance critical section. All print statements below 
    // this point MUST use \n as a terminator instead of '\n', which is significantly slower, and all code should be 
    // absolutely optimally written in regards to time efficency. 
    std::vector<std::thread> threads;

    // We will spawn only threads for those controllers that we are going to use. 
    // Spawn them, with the duration of recording as an argument
    std::cout << "----SPAWNING THREADS---" << '\n';
    for (size_t i = 0; i < used_controller_indices.size(); i++) {
        threads.emplace_back(std::thread(controller_functions[used_controller_indices[i]], duration, &buffers[i]));
    }

    // Join threads to ensure they complete before the program ends
    for (auto& t : threads) {
        t.join();
    }

    // Signal to the user that the threads has successfully closed their operation
    std::cout << "----THREADS CLOSED SUCCESSFULLY---" << '\n'; 

    // Sequential write out just for testing 
    auto start_write_time = std::chrono::steady_clock::now();
    write_process(output_dir, buffers);
    auto elapsed_time = std::chrono::steady_clock::now() - start_write_time;

   std::cout << "----WRITING COMPLETE---" << '\n'; 
   std::cout << "Write time(ms): " << std::chrono::duration_cast<std::chrono::milliseconds>(elapsed_time).count() << '\n';


    return 0; 
}