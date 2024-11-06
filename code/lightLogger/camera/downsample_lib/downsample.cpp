#include <cstdint>
#include <cstddef>
#include <vector>
#include <numeric>
#include <array>
#include <iostream>
#include <vector>

using std::cout;

// Convert a pixel's 2D coordinates to index 
// to an index in a 1D array
size_t pixel_to_index(int r, int c, int cols) {
    return r * cols + c; 
}

extern "C" void downsample(const uint8_t* flattened_img, 
                           uint16_t rows, 
                           uint16_t cols,
                           uint8_t factor,
                           uint8_t* output) 
{       
    // Find the shape of the new image by dividing by 2 x factor 
    // along each dimension
    size_t new_rows = rows >> factor; 
    size_t new_cols = cols >> factor; 

    // Keep track of where where to put the new pixels
    size_t downsampled_r = 0; 
    size_t downsampled_c = 0; 

    // Find the size of the chunk in the original image to modify
    size_t chunk_size = 2 << factor; 

    // Iterate over the chunks of the new image
    for(size_t r = 0; r < rows; r += chunk_size) {
        // Reset the horizontal insertion chunk equal to 0 for this row
        downsampled_c = 0; 
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
            output[ pixel_to_index(downsampled_r, downsampled_c, new_cols) ] = b_average; 
            output[ pixel_to_index(downsampled_r, downsampled_c+1, new_cols) ] = gb_average; 
            output[ pixel_to_index(downsampled_r+1, downsampled_c+1, new_cols) ] = r_average; 
            output[ pixel_to_index(downsampled_r+1, downsampled_c, new_cols) ] = gr_average; 

            // After each column block is finished in the downsampled image,
            // move to the next block 
            downsampled_c += 2; 
        }

        // After each row block is finished in the downsampled image,
        // move to the next block 
        downsampled_r += 2; 
    }
}

int main() {
   return 0; 
}