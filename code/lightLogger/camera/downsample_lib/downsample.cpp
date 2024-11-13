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

// Convert a pixel's 2D coordinates to index 
// to an index in a 1D array in a buffer of images
size_t pixel_to_index_buffer(int r, int c, int cols, int img_num) {
    // Find the image number to populate in the buffer 
    // as the image number times the size of images in the buffer 
    size_t output_img_num = img_num * (r * c);

    // Find the coordinate in the flattened image where this pixel should go
    size_t pixel_coord = (r * cols + c);

    return output_img_num + pixel_coord; 
}

/*
Downsample a given image by 2^factor along each dimension while 
being Bayer-aware. 
@Params: flattened_img - a pointer to the original image flattened
         rows, cols - integers representing the original size of the image 
         factor - integer representing the power of 2 to downsample by 
         output - a pointer to the memory buffer to hold the downsampled image
@Modifies: Populates the output memory buffer pointer
           with the downsampled image. 
@Returns: None
*/
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

/*
Downsample a given buffer of images by 2^factor along each dimension while 
being Bayer-aware. 
@Params: flattened_img_buffer - a pointer to a buffer of original images flattened
         buffer_size - integer representing the size of how many images are in the buffer
         rows, cols - integers representing the original size of the images 
         factor - integer representing the power of 2 to downsample by 
         output - a pointer to the memory buffer to hold the downsampled images
@Modifies: Populates the output memory buffer pointer
           with the downsampled images. 
@Returns: None
*/
extern "C" void downsample_buffer(const uint8_t* flattened_img_buffer, 
                                  uint16_t buffer_size,
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

    // Iterate over the images in the buffer
    for(size_t i = 0; i < buffer_size; i++) {
        
        // Iterate over the chunks of the new image
        for(size_t r = 0; r < rows; r += chunk_size) {
            
            // Reset the horizontal insertion chunk equal to 0 for this row
            downsampled_c = 0; 
            for(size_t c = 0; c < cols; c += chunk_size) {
                // Find the locations and values of each of the blue pixels in this chunk
                std::array<uint8_t, 4> b_pixels = { flattened_img_buffer[ pixel_to_index_buffer(r,c,cols,i) ], 
                                                    flattened_img_buffer[ pixel_to_index_buffer(r,c+2,cols,i) ],
                                                    flattened_img_buffer[ pixel_to_index_buffer(r+2,c,cols,i) ],
                                                    flattened_img_buffer[ pixel_to_index_buffer(r+2,c+2,cols,i) ] }; 
            
                // Find the locations and values of each of the green pixels on blue rows
                // in this chunk 
                std::array<uint8_t, 4> gb_pixels = { flattened_img_buffer[ pixel_to_index_buffer(r,c+1,cols,i) ], 
                                                     flattened_img_buffer[ pixel_to_index_buffer(r,c+3,cols,i) ],
                                                     flattened_img_buffer[ pixel_to_index_buffer(r+2,c+1,cols,i) ],
                                                     flattened_img_buffer[ pixel_to_index_buffer(r+2,c+3,cols,i) ] };
                
                // Find the locations and values of each of the red pixels in this chunk
                std::array<uint8_t, 4> r_pixels = { flattened_img_buffer[ pixel_to_index_buffer(r+1,c+1,cols,i) ], 
                                                    flattened_img_buffer[ pixel_to_index_buffer(r+1,c+3,cols,i) ],
                                                    flattened_img_buffer[ pixel_to_index_buffer(r+3,c+1,cols,i) ],
                                                    flattened_img_buffer[ pixel_to_index_buffer(r+3,c+3,cols,i) ] }; 

                // Find the locations and values of each of the green pixels on red rows 
                // in this chunk
                std::array<uint8_t, 4> gr_pixels = { flattened_img_buffer[ pixel_to_index(r+1,c,cols) ], 
                                                     flattened_img_buffer[ pixel_to_index(r+1,c+2,cols) ],
                                                     flattened_img_buffer[ pixel_to_index(r+3,c,cols) ],
                                                     flattened_img_buffer[ pixel_to_index(r+3,c+2,cols) ] }; 

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
}

int main() {
   return 0; 
}