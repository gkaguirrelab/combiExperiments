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
#include <libuvc/libuvc.h>

namespace fs = std::filesystem;

/*
ALL LIBRARIES INCLUDED ABOVE HERE. MUST COMPILE WITH THE "libraries"" 
FOLDER FROM CURRENT DIRECTORY INCLUDED
*/

/*
Parse the command line arguments to the program 
@Param:     
@Ret: 
@Mod: 
*/
int parse_args(const int argc, const char** argv, 
               fs::path& output_dir, std::array<bool, 4>& controller_flags,
               int64_t& duration) {
    // Initialize the argparser class
    CLI::App app{"Control Firmware for GKA Lab Integrated Personal Light Logger Wearable Device"};
    
    // Add the required output path variable and populate the output_dir variable
    app.add_option("-o,--output_dir", output_dir, "The directory in which to output files. Does not need to exist.")
        ->required();

    // Add the required duration variable and populate it with the number of seconds to record for. if it is negative, it is INF
    // Ensure also that the duration is within -1 and the number of seconds in a day.
    app.add_option("-d,--duration", duration, "Duration of the recording to make")
        ->required()
        ->check(CLI::Range(-1, 86400));
    
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

    // Now let's assure the duration is not 0
    if(duration == 0) {
        std::cerr << "ERROR: Duration cannot be 0 seconds." << '\n'; 
        exit(1);
    }

    return 0; // Returns 0 on success
}


/*
Continous recorder for the MS. Records either INF or for a set duration
@Param: duration. Time in seconds to record for. -1 for INF. 
@Ret: 0 on success, errors and quits otherwise. 
@Mod: N/A
*/
int minispect_recorder(int64_t duration) {
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
    std::array<char, data_length> data_buffer; 

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

        // End recording if we have reached the desired duration. If it is INF 
        // duration, we will never end
        if (duration != -1 && elapsed_seconds >= duration) {
            break;
        }

        // Read a byte from the serial stream
        boost::asio::read(ms, boost::asio::buffer(byte_read));

        // If this byte is the start buffer, note that we have received a reading
        if (byte_read[0] == start_delim) {            
            // Now we can read the correct amount of data
            boost::asio::read(ms, boost::asio::buffer(data_buffer, data_length));

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
@Param:
@Ret:
@Mod:
*/
int world_recorder(int64_t duration) {
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

        // End recording if we have reached the desired duration. If it is INF 
        // duration, we will never end
        if (duration != -1 && elapsed_seconds >= duration) {
            break;
        }

        // Capture the desired frame
        int frame = 0;

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
    int64_t duration; 

    // Initialize controller flags as entirely false. This is because we will denote which controllers 
    // to use based on arguments passed. 
    constexpr std::array<char, 4> controller_names = {'M', 'W', 'P', 'S'};  // this can be constexpr because values will never change 
    std::vector<std::function<int(int64_t)>> controller_functions = {world_recorder, minispect_recorder}; // this CANNOT be constexpr because function stubs are dynamic
    std::array<bool, 4> controller_flags = {false, false, false, false}; // this CANNOT be constexpr because values will change 
    
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
    if(num_active_sensors == 0 || (num_active_sensors > (int64_t) controller_flags.size() )) {
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

    // Begin parallel recording and enter performance critical section. All print statements below 
    // this point MUST use \n as a terminator instead of '\n', which is significantly slower, and all code should be 
    // absolutely optimally written in regards to time efficency. 
    std::vector<std::thread> threads;

    // Output to the user that we are going to spawn the threads 
    std::cout << "----SPAWNING THREADS---" << '\n';

    pupil_recorder(duration);

    // We will spawn only threads for those controllers that we are going to use. 
    // Spawn them, with the duration of recording as an argument
    /*
    for (const auto& sensor_idx : used_controller_indices) {
        threads.emplace_back(controller_functions[sensor_idx], duration);
    }

    // Join threads to ensure they complete before the program ends
    for (auto& t : threads) {
        t.join();
    }

    // Output end of program message to alert the user that things closed successfully
    std::cout << "----THREADS CLOSED SUCCESSFULLY---" << '\n';
    */ 

    return 0; 
}