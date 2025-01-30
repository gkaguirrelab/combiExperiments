#include <cstdint>
#include <array> 
#include <functional>
#include <vector>
#include <iostream>
#include <filesystem>
#include <nlohmann/json.hpp>

namespace fs = std::filesystem;
using json = nlohmann::json;  

/***************************************************************
 *                                                             *
 *              GENERAL DATA STRUCTURE DEFINITIONS             *
 *                                                             *
 ***************************************************************/

// Define a json to track the performance of all of the 
// recorders of the duration of the video. This will be needed 
// to read in the data in Python and analyze performance. 

json performance_data; 

/***************************************************************
 *                                                             *
 *                  CONTROLLER FUNCTION DEFINITIONS            *
 *                                                             *
 ***************************************************************/

// Initialize the controller functions that we will use
int minispect_recorder(const uint32_t duration, 
                       std::vector<uint8_t>* buffer_one, 
                       std::vector<uint8_t>* buffer_two,
                       const uint16_t buffer_size_frames,
                       json* performance_json);

int world_recorder(const uint32_t duration, 
                   std::vector<uint8_t>* buffer_one, 
                   std::vector<uint8_t>* buffer_two,
                   const uint16_t buffer_size_frames,
                   json* performance_json); 

int pupil_recorder(const uint32_t duration, 
                   std::vector<uint8_t>* buffer_one, 
                   std::vector<uint8_t>* buffer_two,
                   const uint16_t buffer_size_frames,
                   json* performance_json); 

int sunglasses_recorder(const uint32_t duration,
                        std::vector<uint8_t>* buffer_one, 
                        std::vector<uint8_t>* buffer_two,
                        const uint16_t buffer_size_frames,
                        json* performance_json);

/***************************************************************
 *                                                             *
 *                     MINISPECT CONFIGURATIONS                *
 *                                                             *
 ***************************************************************/
// Define the data length and the start delimeter. Therefore, 
// each transmission is actually 2 + the data length 
constexpr char ms_start_delim = '<';
constexpr char ms_end_delim = '>';
constexpr size_t ms_data_length = 148; 
constexpr uint8_t ms_fps = 1;

/***************************************************************
 *                                                             *
 *                  WORLD CAMERA CONFIGURATIONS                *
 *                                                             *
 ***************************************************************/

// Define parameters for the video stream 
constexpr size_t world_cols = 640; 
constexpr size_t world_rows = 480;
constexpr uint8_t world_fps = 200; // Note, if you update this here, make sure you update the corresponding value in sensor_FPS
constexpr int64_t world_frame_duration = 1e6/world_fps;
constexpr uint8_t world_downsample_factor = 3; // The power of 2 with which to downsample each dimension of the frame (3->[40,60]) 
constexpr size_t world_original_image_bytesize = (world_rows * world_cols * 2); 
constexpr size_t world_downsampled_bytes_per_image = (world_rows >> world_downsample_factor) * (world_cols >> world_downsample_factor) * 2;
constexpr float_t world_initial_gain = 1; 
constexpr int world_initial_exposure = 100; 
constexpr bool world_use_agc = false; 
constexpr float_t world_agc_speed_setting = 0.95;


/***************************************************************
 *                                                             *
 *                  PUPIL CAMERA CONFIGURATIONS                *
 *                                                             *
 ***************************************************************/
// Define parameters for the video stream
constexpr size_t pupil_cols = 400; 
constexpr size_t pupil_rows = 400;
constexpr uint8_t pupil_fps = 120;
constexpr uint16_t pupil_vendor_id = 0x0C45; 
constexpr uint16_t pupil_product_id = 0x64AB; 

/***************************************************************
 *                                                             *
 *                   SUNGLASSES CONFIGURATIONS                *
 *                                                             *
 ***************************************************************/

// Define details about where the connection to the device will live
constexpr const char* sunglasses_i2c_bus_number = "/dev/i2c-1";     // I2C bus number, corresponds to /dev/i2c-1
constexpr int sunglasses_device_addr = 0x6B; // Define the memory address of the device
constexpr uint8_t sunglasses_config = 0x10; // Configuration command: Continuous conversion mode, 12-bit Resolution (0x10)
constexpr uint8_t sunglasses_read_reg = 0x00;
constexpr uint8_t sunglasses_fps = 1; 

/***************************************************************
 *                                                             *
 *            INITIALIZATION INFORMATION/GLOBAL VARS           *
 *                                                             *
 ***************************************************************/

// Initialize variable to hold output directory path. Path need not exist
fs::path output_dir;

// Initialization container for the duration (in seconds) of the video to record. 
uint32_t duration; 

// Initialize an array of sensor names. The index of these names will correspond to the sensor's info in other arrays. For instance, MS info will always be ind 0
constexpr std::array<char, 4> controller_names = {'M', 'W', 'P', 'S'};

// Initialize controller flags as entirely false. This is because we will denote which controllers 
// to use based on arguments passed. 
std::array<bool, 4> controller_flags = {false, false, false, false}; // this CANNOT be constexpr because values will change 
    
// Define the FPS of each of the sensors 
constexpr std::array<uint8_t, 4> sensor_FPS = {ms_fps, world_fps, pupil_fps, sunglasses_fps};

// Define the sizes of each of the sensors data in human form (NOT byte form)
std::array<std::array<uint16_t, 2>, 4> sensor_sizes = {{ {ms_data_length, 1},
                                                         {world_rows, world_cols},
                                                         {pupil_rows, pupil_cols},
                                                         {1,1}
                                                      }}; 

// Calculate the data size for each of the sensors per each second of capture. The sunglasses sensor is x2 because it returns a 16bit value and we are storing with 8 bit arrays
// The world is also x2 because it returns a 16-bit image and its size is the downsampled size.
// The pupil images are compressed additionally, hence why it is not 400x400 for the size of the images. Instead, I observed I saw no higher than 21K bytes per image in my brief testing 
// therefore, as a conservative estimate, I've put a total of 22K bytes. Note this is a massive reduction. 160000 bytes per image to 22K. (yay!)
constexpr std::array<uint64_t, 4> data_size_multiplers = {sensor_FPS[0]*ms_data_length, sensor_FPS[1]*world_rows*world_cols*2, sensor_FPS[2]*400*55, sensor_FPS[3]*2}; // this can be constexpr because values will never change
    
// Initialize a variable for the size of each sensors' buffer in seconds. This will be regularly written out and cleared
constexpr uint8_t sensor_buffer_size = 10; 

// Initialize an array of function pointers that point to the recorder functions for each sensor
std::array<std::function<int(int32_t, std::vector<uint8_t>*, std::vector<uint8_t>*, uint16_t, json*)>, 4> controller_functions = {minispect_recorder, world_recorder, pupil_recorder, sunglasses_recorder}; // this CANNOT be constexpr because function stubs are dynamic


