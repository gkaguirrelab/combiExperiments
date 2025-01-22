#include <iostream>
#include <vector> 
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <cereal/types/vector.hpp>
#include <cereal/archives/binary.hpp>
#include <bitset>

namespace fs = std::filesystem;

/*
Load in a chunk that was saved from the CPP RPI firmware.
@Param: path - string. Path to the given chunk file. 
@Ret: chunk - vector<vector<uint8_t>> vector of readings from a given chunk
@Mod: N/A 
*/

extern "C" {
    // Define a struct to return to Python filled with basic types.
    //This is because Python only supports returning and not something like vector
    struct chunk_struct {
        uint8_t* M; 
        uint8_t* W;
        uint8_t* P; 
        uint8_t* S; 
        int64_t M_size = 0;
        int64_t W_size = 0; 
        int64_t P_size = 0;
        int64_t S_size = 0;
    };

    /*
    Deserialize the data from a .bin file chunk captured from the C++ implementation 
    of RPI_FIRMWARE and return it as a struct pointer to Python. 
    @Param: python_str_path: char* - The path to the chunk file as a char array. 
    @Ret: chunk: chunk_struct* -  pointer to data from the chunk per sensor 
                                  with its associated buffer size.
                                  Negative sizes in the returned struct 
                                  with signify error codes, as errors 
                                  thrown here simply crash the Python interpreter
                                  with information. 
    @Mod: N/A
    */
    chunk_struct* parse_chunk_binary(const char* python_str_path) {
        // Define the order in which the buffers are stored 
        constexpr std::array<char, 4> controller_names = {'M', 'W', 'P', 'S'};  // this can be constexpr because values will never change 
        
        // First let's convert the Python character array to a CPP string 
        std::string path(python_str_path);

        // Initialize our ret value
        chunk_struct* chunk = new chunk_struct;
        
        // First, convert string to fs::path object
        fs::path filepath(path); 

        // Ensure the file exists. If not, return with error code -1
        if(!fs::exists(filepath)) {
            chunk->M_size = -1;
            chunk->M_size = -1;
            chunk->M_size = -1;
            chunk->M_size = -1;
        }

        // Open the file and read it as binary
        std::ifstream in_file(filepath, std::ios::binary);

        // Ensure the file was properly opened. If not, return with 
        // error code two  
        if(!in_file.is_open()) {
            chunk->M_size = -2;
            chunk->M_size = -2;
            chunk->M_size = -2;
            chunk->M_size = -2;
        }

        // Create a cereal input archive for deserialization
        cereal::BinaryInputArchive in_archive(in_file);

        // Read in the data to an initialized variable
        std::vector<std::vector<uint8_t>> chunk_vector; 
        in_archive(chunk_vector); 

        // Iterate over the sizes of each of the buffers and print out the size
        /*
        std::cout << "Num sensor buffers: " << chunk_vector.size() << '\n'; 
        std::cout << "Sensor buffer sizes" << '\n';
        for(size_t i = 0; i < controller_names.size(); i++) {
            std:: cout << "\t" << controller_names[i] << ": " << chunk_vector[i].size() << '\n';
        }
        */


        // Iterate over the size of the sunglasses vector and print out values just to test
        /*
        for(size_t i = 0; i < chunk_vector[3].size(); i+=2) {
            std::cout << "Sunglasses | Lower Byte: " << std::bitset<8>(chunk_vector[3][i]) << std::endl;
            std::cout << "Sunglasses | Upper Byte: " << std::bitset<8>(chunk_vector[3][i+1]) << std::endl;
        }
        */

        // Now we need to allocate heap memory for each of these readings and copy them over 
        // so that Python can retrieve them and free them later
        chunk->M_size = chunk_vector[0].size(); // First retrieve the number of values in the buffer
        chunk->M = new uint8_t[chunk->M_size]; // Allocate an array for the MS readings
        std::copy(chunk_vector[0].begin(), chunk_vector[0].end(), chunk->M); // Copy over the memory to the return value

        chunk->W_size = chunk_vector[1].size(); // First retrieve the number of values in the buffer
        chunk->W = new uint8_t[chunk->W_size]; // Allocate an array for the World Camera readings
        std::copy(chunk_vector[1].begin(), chunk_vector[1].end(), chunk->W); // Copy over the memory to the return value

        chunk->P_size = chunk_vector[2].size(); // First retrieve the number of values in the buffer
        chunk->P = new uint8_t[chunk->P_size]; // Allocate an array for the Pupil Camera readings
        std::copy(chunk_vector[2].begin(), chunk_vector[2].end(), chunk->P); // Copy over the memory to the return value

        chunk->S_size = chunk_vector[3].size(); // First retrieve the number of values in the buffer
        chunk->S = new uint8_t[chunk->S_size]; // Allocate an array for the sunglasses readings
        std::copy(chunk_vector[3].begin(), chunk_vector[3].end(), chunk->S); // Copy over the memory to the return value
        
        return chunk; 
    }

    /*
    Free the dynamically allocated chunk.
    @Param: chunk - chunk_struct*: structure containing all of the sensors'
                    information for a given chunk. 
    @Ret: N/A 
    @Mod: Deletes all dynamically allocated memory in a chunk, as well as 
          the chunk itself. 
    */
    void free_chunk_struct(chunk_struct* chunk) {
        delete[] chunk->M;
        delete[] chunk->W;
        delete[] chunk->P;
        delete[] chunk->S;

        delete chunk;
    }

}
 

int main() {

}