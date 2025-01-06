# Paths to libraries we will use
UTILITY_DIR = ./utility
AGC_DIR = ../camera/AGC_lib
LIBRARIES_DIR = ./libraries
CEREAL_DIR = ./libraries/cereal-1.3.2/include
LIBCAMERA_INCLUDE_DIR = /usr/local/include/libcamera
LIBCAMERA_LIB_DIR = /usr/lib/aarch64-linux-gnu
LIBUVC_INCLUDE_DIR = ./libraries/libuvc/include
LIBUVC_LIB_DIR = ./usr/local/lib/
BINARIES_DIR = ./binaries

# Compiler and compiler flags
CXX = g++
CXXFLAGS = -Wall -Wextra -v -O3 -std=c++17 -I$(LIBRARIES_DIR) -I$(LIBCAMERA_INCLUDE_DIR) -I$(AGC_DIR) -I$(CEREAL_DIR) -I$(LIBUVC_INCLUDE_DIR)
LDFLAGS = -L$(LIBCAMERA_LIB_DIR) -lcamera -L$(LIBCAMERA_LIB_DIR) -luvc -lusb-1.0

# Define the name of the output executable
OUTPUT_EXECUTABLE_NAME = FIRMWARE 

all: $(OUTPUT_EXECUTABLE_NAME) $(UTILITY_DIR)/parse_chunk_binary.so

# Target: Dependencies | Combine the .o files to make the firmware file
# NOTE: For some inexplicable reason, the LDFLAGS MUST go at the end. Otherwise, I get undefined reference errors.
$(OUTPUT_EXECUTABLE_NAME): $(BINARIES_DIR)/rpi_cpp.o $(BINARIES_DIR)/AGC.o 
	$(CXX) $(CXXFLAGS) $(BINARIES_DIR)/rpi_cpp.o $(BINARIES_DIR)/AGC.o -o $(OUTPUT_EXECUTABLE_NAME) $(LDFLAGS)

# Target: Dependencies | Make the RPI firmware into its .o file  
$(BINARIES_DIR)/rpi_cpp.o: rpi_cpp.cpp 
	$(CXX) $(CXXFLAGS) -c rpi_cpp.cpp -o $(BINARIES_DIR)/rpi_cpp.o $(LDFLAGS)

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
