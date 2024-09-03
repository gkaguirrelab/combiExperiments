#include <cstdint>
#include <cstddef>
#include <vector>
#include <numeric>
#include <array>
#include <iostream>
#include <opencv2/opencv.hpp>
#include <filesystem>
#include <vector>
#include <string>
#include <chrono>

using std::cout;
namespace fs = std::filesystem;

// Convert a pixel's 2D coordinates to index 
// to an index in a 1D array
size_t pixel_to_index(int r, int c, int cols) {
    return r * cols + c; 
}

extern "C" uint8_t* downsample(uint8_t* flattened_img, 
                               uint16_t rows, 
                               uint16_t cols) 
{       
    // Downscale the width and the height by 2, so each chunk is 2x2 big
    unsigned int chunk_size = 2 * 2; 

    // Allocate space for the new downsampled image that is 
    // 1/4 the size the original (divide by 2 along each dimension)
    size_t new_rows = rows / 2; 
    size_t new_cols = cols / 2; 
    uint8_t* downsampled_img = new uint8_t[new_rows * new_cols]; 

    // Keep track of where where to put the new pixels
    size_t downsampled_r = 0; 
    size_t downsampled_c = 0; 

    // Iterate over the chunks of the new image
    for(size_t r = 0; r < rows; r += chunk_size) {
        for(size_t c = 0; c < cols; c += chunk_size) {
            // Find the locations and values of each of the blue pixels in this chunk
            std::array<uint8_t, 4> b_pixels = { flattened_img[ pixel_to_index(r,c,cols) ], 
                                                flattened_img[ pixel_to_index(r,c+2,cols) ],
                                                flattened_img[ pixel_to_index(r+2,c,cols) ],
                                                flattened_img[ pixel_to_index(r+2,c+2,cols) ] }; 
           
            // Find the locations and values of each of the green pixels on blue rows
            // in this chunk 
            std::array<uint8_t, 4> gb_pixels = { flattened_img[ pixel_to_index(r,c+1,cols) ], 
                                                 flattened_img[ pixel_to_index(r,c+3,cols) ],
                                                 flattened_img[ pixel_to_index(r+2,c+1,cols) ],
                                                 flattened_img[ pixel_to_index(r+2,c+3,cols) ] };
            
            // Find the locations and values of each of the red pixels in this chunk
            std::array<uint8_t, 4> r_pixels = { flattened_img[ pixel_to_index(r+1,c+1,cols) ], 
                                                flattened_img[ pixel_to_index(r+1,c+3,cols) ],
                                                flattened_img[ pixel_to_index(r+3,c+1,cols) ],
                                                flattened_img[ pixel_to_index(r+3,c+3,cols) ] }; 

            // Find the locations and values of each of the green pixels on red rows 
            // in this chunk
            std::array<uint8_t, 4> gr_pixels = { flattened_img[ pixel_to_index(r+1,c,cols) ], 
                                                flattened_img[ pixel_to_index(r+1,c+2,cols) ],
                                                flattened_img[ pixel_to_index(r+3,c,cols) ],
                                                flattened_img[ pixel_to_index(r+3,c+2,cols) ] }; 

            // Sum the values of the pixels as unsigned
            uint32_t b_sum = std::accumulate(std::begin(b_pixels), std::end(b_pixels), 0u);
            uint32_t gb_sum = std::accumulate(std::begin(gb_pixels), std::end(gb_pixels), 0u);
            uint32_t r_sum = std::accumulate(std::begin(r_pixels), std::end(r_pixels), 0u);
            uint32_t gr_sum = std::accumulate(std::begin(gr_pixels), std::end(gr_pixels), 0u);

            // Calculate the average of this color of pixels and cast back to unsigned 8 bit
            uint8_t b_average = static_cast<uint8_t>(b_sum >> 2);
            uint8_t gb_average = static_cast<uint8_t>(gb_sum >> 2);
            uint8_t r_average = static_cast<uint8_t>(r_sum >> 2);
            uint8_t gr_average = static_cast<uint8_t>(gr_sum >> 2);

            // Set the downsampled image to have their values
            downsampled_img[ pixel_to_index(downsampled_r, downsampled_c, new_cols) ] = b_average; 
            downsampled_img[ pixel_to_index(downsampled_r, downsampled_c+1, new_cols) ] = gb_average; 
            downsampled_img[ pixel_to_index(downsampled_r+1, downsampled_c+1, new_cols) ] = r_average; 
            downsampled_img[ pixel_to_index(downsampled_r+1, downsampled_c, new_cols) ] = gr_average; 

            // After each column block is finished in the downsampled image,
            // move to the next block, and reset to 0 when moving to new row block 
            downsampled_c = (downsampled_c + (chunk_size)/2) % new_cols; 
        }

        // After each row block is finished in the downsampled image,
        // move to the next block, do not have to reset to 0 since when rows are finished, 
        // the downsampling is finished
        downsampled_r = (downsampled_r + (chunk_size)/2);
    }


    // Return the downsampled img array
    return downsampled_img; 
}

int main() {
    std::vector<uint8_t*> img_arr; 
    std::string directory_path = "/Users/zacharykelly/Documents/MATLAB/projects/combiExperiments/code/lightLogger/camera/downsample_lib/tests/blue_video";    
    
    // Iterate over all files in the directory
    for (const auto& entry : fs::directory_iterator(directory_path)) {
        // Get the file path
        std::string file_path = entry.path().string();

        cout << file_path << '\n'; 

        // Read the image
        cv::Mat img = cv::imread(file_path, cv::IMREAD_GRAYSCALE);

        // Check if the image was loaded successfully
        if (img.empty()) {
            std::cerr << "Error: Could not open or find the image: " << file_path << std::endl;
            continue;
        }

        // Append the image to the image vector
        img_arr.push_back(img.reshape(1,1).data); 
    }

    cout << "Downsampling...\n";

    int rows = 480; 
    int cols = 640; 

    auto start = std::chrono::high_resolution_clock::now();
    // Iterate over the images and see how long it takes
    for(size_t i = 0; i < img_arr.size(); i++) {
        uint8_t* downsampled = downsample(img_arr[i], rows, cols);
    }

    auto end = std::chrono::high_resolution_clock::now();

     // Calculate the elapsed time in milliseconds
    std::chrono::duration<double, std::milli> elapsed = end - start;

    // Output the elapsed time
    std::cout << "Elapsed time: " << elapsed.count() << " ms" << std::endl;

}