# Paths to libraries we will use
UTILITY_DIR = ./utility
AGC_DIR = ../camera/AGC_lib
LIBRARIES_DIR = ./libraries
CEREAL_DIR = ./libraries/cereal-1.3.2/include
LIBCAMERA_DIR = ./libraries/libcamera/build/include
LIBCAMERA_MISSING_HEADER_DIR = ./libraries/libcamera/include
RPICAM_DIR = ./libraries/rpicam-apps	
RPICAM_CORE_DIR = ./libraries/rpicam-apps/core
RPICAM_SHARED_LIBRARY_DIR = /usr/lib/aarch64-linux-gnu
BINARIES_DIR = ./binaries

# Compiler and compiler flags
CXX = g++
CXXFLAGS = -Wall -Wextra -v -O3 -std=c++17  -I$(LIBRARIES_DIR) -I$(LIBCAMERA_DIR) -I$(AGC_DIR) -I$(CEREAL_DIR) -I$(RPICAM_DIR) -I$(LIBCAMERA_MISSING_HEADER_DIR) -I$(RPICAM_CORE_DIR)
LDFLAGS = -L$(RPICAM_SHARED_LIBRARY_DIR) -lcamera

# Define the name of the output executable
OUTPUT_EXECUTABLE_NAME = FIRMWARE 

all: $(OUTPUT_EXECUTABLE_NAME) $(UTILITY_DIR)/parse_chunk_binary.so

# Target: Dependencies | Combine the .o files to make the firmware file
$(OUTPUT_EXECUTABLE_NAME): $(BINARIES_DIR)/rpi_cpp.o $(BINARIES_DIR)/AGC.o 
	$(CXX) $(CXXFLAGS) $(LDFLAGS) $(BINARIES_DIR)/rpi_cpp.o $(BINARIES_DIR)/AGC.o -o $(OUTPUT_EXECUTABLE_NAME)

# Target: Dependencies | Make the RPI firmware into its .o file  
$(BINARIES_DIR)/rpi_cpp.o: rpi_cpp.cpp 
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -c rpi_cpp.cpp -o $(BINARIES_DIR)/rpi_cpp.o

# Target: Dependencies | Make the Automatic Gain Control into its .o file
$(BINARIES_DIR)/AGC.o: $(AGC_DIR)/AGC.cpp $(AGC_DIR)/AGC.h
	$(CXX) $(CXXFLAGS) -c $(AGC_DIR)/AGC.cpp -o $(BINARIES_DIR)/AGC.o


# Target: Dependencies | Make the parse_chunks_binary helper function a shared library so that Python can use it
$(UTILITY_DIR)/parse_chunk_binary.so: $(UTILITY_DIR)/parse_chunk_binary.o
	$(CXX) -shared $(UTILITY_DIR)/parse_chunk_binary.o -o $(UTILITY_DIR)/parse_chunk_binary.so

# Target: Dependencies | Make the parse_chunk_binary helper function object file
$(UTILITY_DIR)/parse_chunk_binary.o: $(UTILITY_DIR)/parse_chunk_binary.cpp 
	$(CXX) $(CXXFLAGS) -fPIC -c $(UTILITY_DIR)/parse_chunk_binary.cpp -o $(UTILITY_DIR)/parse_chunk_binary.o

clean: 
	rm -rf *.o FIRMWARE $(UTILITY_DIR)/*.o $(UTILITY_DIR)/*.so $(BINARIES_DIR)/*

.PHONY: all clean
