#include <cstdint>
#include <cstddef>
#include <vector>

// Convert a pixel's 2D coordinates to index 
// to an index in a 1D array
size_t pixel_to_index(int r, int c, int cols) {
    return r * cols + c 
}


extern "C" uint8_t* downsample(uint8_t* flattened_img, 
                           unsigned int rows, 
                           unsigned int cols) 
{       
    
    // Allocate space for the new downsampled image that is 
    // 1/4 the size the original (divide by 2 along each dimension)
    size_t new_size = (rows*cols)/4; 
    uint8_t* downsampled_img = new uint8_t[downsampled_img_size]; 
    size_t downsampled_index = 0; 

    // Iterate over the chunks of the new image
    for(size_t r = 0; r < rows; r += 4) {
        for(size_t c = 0; c < cols; c+=4) {
            // Find the locations of each color's pixels in this chunk
            uint8_t r_pixels[4] = {flattened_img[ pixel_to_index(r,c) ], 
                                   flattened_img[ pixel_to_index(r,c+2) ],
                                   flattened_img[ pixel_to_index(r+2,c) ],
                                   flattened_img[ pixel_to_index(r+2,c+2) ]
                                   }; 

            // Sum the values of the pixels as unsigned
            uint32_t r_sum = std::accumulate(std::begin(r_pixels), std::end(r_pixels), 0u);
            
            // Calculate the average of this color of pixels and cast back to unsigned 8 bit
            uint8_t r_average = static_cast<uint8_t>(r_sum / 4);

            // Set the downsampled image to have this value
            downsampled_img[downsampled_index] = r_average; 


        }
    }

    return downsampled_img; 
}


int main() {
    

    return 0; 
}