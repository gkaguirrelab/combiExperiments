# Compiler and compiler flags
CXX = g++
CXXFLAGS = -Wall -Wextra -shared -O2 -fPIC -std=c++17
LDFLAGS = -shared  # Linker flag to create a shared library

# Directories
SRC_DIR1 = ../camera/AGC_lib
SRC_DIR2 = ../camera/downsample_lib
BUILD_DIR = ../build
BIN_DIR = ../bin

# Output names
AGC_TARGET = $(SRC_DIR1)/AGC.so
DOWNSAMPLE_TARGET = $(SRC_DIR2)/downsample.so

# Source files
AGC_SRC = $(SRC_DIR1)/AGC.cpp
DOWNSAMPLE_SRC = $(SRC_DIR2)/downsample.cpp

# Object files
AGC_OBJ = $(BUILD_DIR)/AGC.o
DOWNSAMPLE_OBJ = $(BUILD_DIR)/downsample.o

# Default rule: Build both programs
all: $(AGC_TARGET) $(DOWNSAMPLE_TARGET)

# Build AGC program
$(AGC_TARGET): $(AGC_OBJ)
	mkdir -p $(BIN_DIR)
	$(CXX) $(LDFLAGS) $(AGC_OBJ) -o $@

# Build Downsample program
$(DOWNSAMPLE_TARGET): $(DOWNSAMPLE_OBJ)
	mkdir -p $(BIN_DIR)
	$(CXX) $(LDFLAGS) $(DOWNSAMPLE_OBJ) -o $@

# Compile AGC.cpp
$(AGC_OBJ): $(AGC_SRC)
	mkdir -p $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Compile Downsample.cpp
$(DOWNSAMPLE_OBJ): $(DOWNSAMPLE_SRC)
	mkdir -p $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Clean build files
clean:
	rm -rf $(BUILD_DIR) $(BIN_DIR) $(AGC_TARGET) $(DOWNSAMPLE_TARGET)

# Phony targets
.PHONY: all clean