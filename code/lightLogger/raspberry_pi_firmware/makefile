# Paths to libraries we will use
AGC_DIR = ../camera/AGC_lib
LIBRARIES_DIR = ./libraries
CEREAL_DIR = ./libraries/cereal-1.3.2/include
LIBCAMERA_DIR = ./libraries/libcamera/include
RPICAM_DIR = ./libraries/rpicam-apps/

# Compiler and compiler flags
CXX = g++
CXXFLAGS = -Wall -Wextra -v -O3 -std=c++17  -I$(LIBRARIES_DIR) -I$(LIBCAMERA_DIR) -I$(AGC_DIR) -I$(CEREAL_DIR) -I$(RPICAM_DIR)
LDFLAGS = -L 

# Define the name of the output executable
OUTPUT_EXECUTABLE_NAME = FIRMWARE 

all: $(OUTPUT_EXECUTABLE_NAME)

# Target: Dependencies | Combine the .o files to make the firmware file
$(OUTPUT_EXECUTABLE_NAME): rpi_cpp.o AGC.o 
	$(CXX) $(CXXFLAGS) rpi_cpp.o AGC.o -o $(OUTPUT_EXECUTABLE_NAME)

# Target: Dependencies | Make the RPI firmware into its .o file  
rpi_cpp.o: rpi_cpp.cpp 
	$(CXX) $(CXXFLAGS) -c rpi_cpp.cpp 

# Target: Dependencies | Make the Automatic Gain Control into its .o file
AGC.o: $(AGC_DIR)/AGC.cpp $(AGC_DIR)/AGC.h
	$(CXX) $(CXXFLAGS) -c $(AGC_DIR)/AGC.cpp

clean: 
	rm -rf *.o FIRMWARE

.PHONY: all clean
