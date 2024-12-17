#include <utility>
#include <vector>
#include <cstdint>
#include <cmath> 
#include <algorithm>
#include <iostream>
#include <array> 

// Define the struct of the return value of the AGC
struct RetVal {
        double adjusted_gain; 
        double adjusted_exposure; 
}; 

// Define these all as constexpr so that they are evaluated at compile time as opposed to runtime
// and their values never change
constexpr double signal_target = 127.0; //target value for the signal at any given light source 
constexpr std::array<double, 2> gain_range = {1.0, 10.666}; // The range of possible gain values
constexpr std::array<double, 2> exposure_range = {37, 4839}; // The range of possible exposure values, second val is equal to std::floor(1e6/206.65)
constexpr std::array<double, 2> signal_range = {0, 255}; // The range of possible signal values
constexpr double precision_error_margin = 0.025; // the allowable margin of floating point error between calculations
enum class Correction_Direction {
    TURN_DOWN, // 0 
    TURN_UP,   // 1
};

RetVal AGC(double signal, double gain, 
          double exposure, double speed_setting) {   

        // Initialize a struct of return values
        RetVal ret_val; 
        ret_val.adjusted_gain = gain; 
        ret_val.adjusted_exposure = exposure;
        
        // Calculate the adjustment
        double correction = 1+(signal_target - signal) / signal_target;

        // Speed
        double speed = speed_setting; 

        // Move quickly if we are pegged at the signal range
        if(std::abs(signal - signal_range[0]) <= precision_error_margin || std::abs(signal - signal_range[1]) <= precision_error_margin ) {
            speed  = speed_setting * speed_setting * speed_setting;  
        }

        // Move quickly if we are close to the destination
        if(std::abs(correction - 1) < 0.25) {
            speed = speed_setting * speed_setting;  
        }

        // Correct the correction
        correction = 1 + ( (1 - speed) * (correction - 1) );

        // If correction == 1, nothing to be done
        if(correction == 1) {
            return ret_val; 
        }

        // Determine whether we need to turn settings up (true)
        // or down (false)
        Correction_Direction mode = Correction_Direction(correction > 1); 
        bool exposure_not_max = exposure < exposure_range[1];
        bool gain_not_min = gain > gain_range[0]; 

        switch(mode){
            // If correction > 1, it means we need to turn up gain or exposure.
            case Correction_Direction::TURN_UP:
                // First choice is to turn up exposure
                if(exposure_not_max) {
                    ret_val.adjusted_exposure = exposure * correction; 

                    // Clamp adjusted exposure to be in range
                    ret_val.adjusted_exposure = std::clamp(ret_val.adjusted_exposure, exposure_range[0], exposure_range[1]); 

                }
                // Otherwise, if exposure maxed, turn up the gain
                else {
                    ret_val.adjusted_gain = gain * correction; 

                    // Clamp adjusted gain to be in range
                    ret_val.adjusted_gain = std::clamp(ret_val.adjusted_gain, gain_range[0], gain_range[1]); 
                }

                break; 

            // If correction < 1, it means we need to turn down gain or exposure.
            case Correction_Direction::TURN_DOWN:
                // First choice is to turn down gain
                if(gain_not_min) {
                    ret_val.adjusted_gain = gain * correction; 

                    // Clamp adjusted gain to be in range
                    ret_val.adjusted_gain = std::clamp(ret_val.adjusted_gain, gain_range[0], gain_range[1]); 
                }  
                else {
                    ret_val.adjusted_exposure = exposure * correction; 

                    // Clamp adjusted exposure to be in range
                    ret_val.adjusted_exposure = std::clamp(ret_val.adjusted_exposure, exposure_range[0], exposure_range[1]); 
                }

                break; 

            // Set negative values in case something went wrong
            default: 
                ret_val.adjusted_exposure = -1; 
                ret_val.adjusted_gain = -1; 
                break; 
        }

        //Return the new gain and exposure
        return ret_val;
}