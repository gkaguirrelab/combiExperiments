#include <utility>
#include <vector>
#include <cstdint>
#include <cmath> 
#include <algorithm>
#include <iostream> 

extern "C" {
    struct RetVal {
        double adjusted_gain; 
        double adjusted_exposure; 
    }; 

    RetVal AGC(double signal, double gain, double exposure,
                                double speed_setting) 
    {
        RetVal ret_val; 
        ret_val.adjusted_gain = gain; 
        ret_val.adjusted_exposure = exposure;
        
        double signal_target = 127.0; //target value for the signal at any given light source 
        std::vector<double> gain_range = {1.0, 10.666}; // The range of possible gain values
        std::vector<double> exposure_range = {37, std::floor(1e6/206.65)}; // The range of possible exposure values
        std::vector<double> signal_range = {0,255}; // The range of possible signal values
        const double precision_error_margin = 0.025;
        enum class Correction_Direction {
            TURN_DOWN, // 0 
            TURN_UP,   // 1
        };

        // Calculate the adjustment
        double correction = 1+(signal_target - signal) / signal_target;

        // Speed
        double speed = speed_setting; 

        // Move quickly if we are pegged at the signal range
        if(std::abs(signal - signal_range[0]) <= precision_error_margin || std::abs(signal - signal_range[1]) <= precision_error_margin ) {
            speed  = speed_setting * speed_setting;  
        }

        // Move quickly if we are close to the destination
        if(std::abs(correction - 1) < 0.25) {
            speed = speed_setting * speed_setting;  
        }

        // Correct the correction
        correction = 1 + ( (1 - speed) * (correction - 1) );

        // If correction == 1, nothing to be done
        if(std::abs(correction - 1) > precision_error_margin) {
            //std::cout << "DOING NOTHING" << std::endl; 
            //std::cout << std::abs(correction - 1) << std::endl;
            return ret_val; 
        }

        //std::cout << "Correction " << correction << std::endl;

        // Determine whether we need to turn settings up (true)
        // or down (false)
        Correction_Direction mode = Correction_Direction(correction > 1); 
        bool exposure_not_max = exposure < exposure_range[1];
        bool gain_not_min = gain > gain_range[0]; 

        //std::cout << "gain later: " << gain << std::endl ;
        //std::cout << "gain min? " << gain_not_min << std::endl; 

        switch(mode){
            // If correction > 1, it means we need to turn up gain or exposure.
            case Correction_Direction::TURN_UP:
                //std::cout << "INCREASING SETTINGS" << std::endl; 

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
                //std::cout << "DECREASING SETTINGS" << std::endl; 

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

}

int main() {
    double gain = 1.0; 
    double exposure = 37.0; 
    double speed_setting = 0.99; 

    RetVal test = AGC(255, gain, exposure, speed_setting);

    std::cout << test.adjusted_gain << std::endl; 
    std::cout << test.adjusted_exposure << std::endl; 

    
    return 0 ; 
    
}