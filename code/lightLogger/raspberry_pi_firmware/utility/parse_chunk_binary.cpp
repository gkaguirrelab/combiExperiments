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
    std::vector<std::vector<uint8_t>> parse_chunk_binary(std::string& path) {
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
        std::vector<std::vector<uint8_t>> chunk; 
        in_archive(chunk); 

        return chunk; 
    }
}
 

int main() {

}