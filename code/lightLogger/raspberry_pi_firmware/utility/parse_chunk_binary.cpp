#include <iostream>
#include <vector> 
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <cereal/types/vector.hpp>
#include <cereal/archives/binary.hpp>

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
        uint64_t M_size;
        uint64_t W_size; 
        uint64_t P_size; 
        uint64_t S_size; 
    };

    chunk_struct* parse_chunk_binary(const char* python_str_path) {
        // First let's convert the Python character array to a CPP string 
        std::string path(python_str_path);

        // Initialize our ret value
        chunk_struct* chunk = new chunk_struct; 
        
        // First, convert string to fs::path object
        fs::path filepath(path); 

        // Ensure the file exists
        if(!fs::exists(filepath)) {
            throw std::runtime_error("ERROR: Path does not exist: " + filepath.string());
        }

        // Open the file and read it as binary
        std::ifstream in_file(filepath, std::ios::binary);

        // Ensure the file was properly opened 
        if(!in_file.is_open()) {
            throw std::runtime_error("ERROR: Unable to open file: " + filepath.string());
        }

        // Create a cereal input archive for deserialization
        cereal::BinaryInputArchive in_archive(in_file);

        // Read in the data to an initialized variable
        std::vector<std::vector<uint8_t>> chunk_vector; 
        in_archive(chunk_vector); 

        // Now we need to allocate heap memory for each of these readings and copy them over 
        // so that Python can retrieve them and free them later
        chunk->M_size = chunk_vector[0].size(); // First retrieve the number of values in the buffer
        chunk->M = new uint8_t[chunk->M_size]; // Allocate an array for the MS readings
        std::copy(chunk_vector[0].begin(), chunk_vector[0].end(), chunk->M); // Copy over the memory to the return value

        chunk->W_size = chunk_vector[1].size(); // First retrieve the number of values in the buffer
        chunk->W = new uint8_t[chunk->W_size]; // Allocate an array for the World Camera readings
        std::copy(chunk_vector[0].begin(), chunk_vector[0].end(), chunk->M); // Copy over the memory to the return value

        chunk->P_size = chunk_vector[2].size(); // First retrieve the number of values in the buffer
        chunk->P = new uint8_t[chunk->P_size]; // Allocate an array for the Pupil Camera readings
        std::copy(chunk_vector[0].begin(), chunk_vector[0].end(), chunk->M); // Copy over the memory to the return value

        chunk->P_size = chunk_vector[2].size(); // First retrieve the number of values in the buffer
        chunk->S = new uint8_t[chunk->P_size]; // Allocate an array for the sunglasses readings
        std::copy(chunk_vector[0].begin(), chunk_vector[0].end(), chunk->M); // Copy over the memory to the return value
        
        return chunk; 
    }

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