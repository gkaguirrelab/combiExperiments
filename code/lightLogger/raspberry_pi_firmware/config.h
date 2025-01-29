#include <cstdint>
#include <array> 
#include <function> 

// Initialize an array of sensor names. The index of these names will correspond to the sensor's info in other arrays. For instance, MS info will always be ind 0
constexpr std::array<char, 4> controller_names = {'M', 'W', 'P', 'S'};  // this can be constexpr because values will never change 

// Initialize controller flags as entirely false. This is because we will denote which controllers 
// to use based on arguments passed. 
std::array<bool, 4> controller_flags = {false, false, false, false}; // this CANNOT be constexpr because values will change 
    
// Define the FPS of each of the sensors 
constexpr std::array<uint8_t, 4> sensor_FPS = {1, 200, 120, 1};

// Calculate the data size for each of the sensors per each second of capture. The sunglasses sensor is x2 because it returns a 16bit value and we are storing with 8 bit arrays
// The world is also x2 because it returns a 16-bit image and its size is the downsampled size.
// The pupil images are compressed additionally, hence why it is not 400x400 for the size of the images. Instead, I observed I saw no higher than 21K bytes per image in my brief testing 
// therefore, as a conservative estimate, I've put a total of 22K bytes. Note this is a massive reduction. 160000 bytes per image to 22K. (yay!)
constexpr std::array<uint64_t, 4> data_size_multiplers = {sensor_FPS[0]*148, sensor_FPS[1]*640*480*2, sensor_FPS[2]*400*55, sensor_FPS[3]*2}; // this can be constexpr because values will never change
    
// Initialize a variable for the size of each sensors' buffer in seconds. This will be regularly written out and cleared
constexpr uint8_t sensor_buffer_size = 10; 

// Initialize an array of function pointers that point to the recorder functions for each sensor
std::array<std::function<int(int32_t, std::vector<uint8_t>*, std::vector<uint8_t>*, uint16_t, performance_data*)>, 4> controller_functions = {minispect_recorder, world_recorder, pupil_recorder, sunglasses_recorder}; // this CANNOT be constexpr because function stubs are dynamic
    

// Define a struct to track the performance of all of the 
// recorders of the duration of the video. This will be needed 
// to read in the data in Python and analyze performance. 
typedef struct { 
    uint32_t duration; 
    size_t M_captured_frames = 0;
    size_t W_captured_frames = 0;
    size_t P_captured_frames = 0;
    size_t S_captured_frames = 0;

} performance_data;