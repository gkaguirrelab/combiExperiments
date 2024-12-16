#include <iostream>
#include <filesystem>
#include "CLI11.hpp"
#include <algorithm>
#include <cstdint>
//#include <SerialPort.h>
//#include <SerialStream.h>

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

    return 0; // Returns 0 on success
}


/*
Continous recorder for the MS. Records either INF or for a set duration
@Param:
@Ret:
@Mod:
*/
int minispect_recorder(int64_t duration) {
    /*
    // Connect to the MS device via the serial port
    LibSerial::SerialStream serial('/dev/ttyACM0');

    // Initialize information about the connection to the MS
    serial.SetBaudRate(LibSerial::BaudRate::BAUD_9600);
    serial.SetCharacterSize(LibSerial::CharacterSize::CHAR_SIZE_8);
    serial.SetParity(LibSerial::Parity::PARITY_NONE);
    serial.SetStopBits(LibSerial::StopBits::STOP_BITS_1);
    serial.SetFlowControl(LibSerial::FlowControl::FLOW_CONTROL_NONE);
    */ 



    return 0;
}


int main(int argc, char **argv) {
    // Initialize variable to hold output directory path. Path need not exist
    fs::path output_dir;

    // Initialization container for the duration (in seconds) of the video to record. If this is 
    // negative, then it will be for infinity
    int64_t duration; 

    // Initialize controller flags as entirely false. This is because we will denote which controllers 
    // to use based on arguments passed. 
    std::array<char, 4> controller_names = {'M', 'W', 'P', 'S'}; 
    std::array<bool, 4> controller_flags = {false, false, false, false}; 

    // Parse the commandline arguments.
    if(parse_args(argc, (const char**) argv, output_dir, controller_flags, duration)) {
        std::cerr << "ERROR: Could not properly parse args." << std::endl; 
        exit(1);
    }; 

    // If argparse was successful, we will ensure the output directory exists
    // First check to see if it does not already exist. If that is true, then we will make it. 
    // Then, we must check if that was succesful. If it was not successful, we output an error
    if(!fs::exists(output_dir) && !fs::create_directories(output_dir)) {
        std::cerr << "ERROR: Could not create output directory: " << output_dir << std::endl; 
        exit(1);
    }

    // Now let's assure the duration is not 0
    if(duration == 0) {
        std::cerr << "ERROR: Duration cannot be 0 seconds." << std::endl; 
        exit(1);
    }


    // Now let's check to make sure we have at LEAST one controller to record with and nothing 
    // went wrong in our counting
    const int num_active_sensors = std::count(controller_flags.begin(), controller_flags.end(), true);
    if(num_active_sensors < 0 || ( (size_t) num_active_sensors > controller_flags.size() )) {
        std::cerr << "ERROR: Invalid number of active sensors: " << num_active_sensors << std::endl; 
        exit(1);
    }


    // Output information about where this recording's data will be output, as well as 
    // the controllers we will use
    std::cout << "----ARGPARSE AND FILE SETUP SUCCESSFUL---" << std::endl;

    std::cout << "Output Directory: " << output_dir << std::endl;
    std::cout << "Controllers used: " << std::endl;
    for(size_t i = 0; i < controller_names.size(); i++) {
        std::cout << '\t' << controller_names[i] << " | " << controller_flags[i] << std::endl;
    }

    // Begin recording

    minispect_recorder(duration);



    return 0; 
}