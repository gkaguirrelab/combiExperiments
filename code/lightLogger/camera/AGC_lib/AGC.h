// Define the struct of the return value of the AGC
struct adjusted_settings {
        double adjusted_gain; 
        double adjusted_exposure; 
}; 

// Define these all as constexpr so that they are evaluated at compile time as opposed to runtime
// and their values never change
constexpr double signal_target = 65472; //target value for the signal at any given light source 
constexpr std::array<double, 2> gain_range = {1.0, 10.666}; // The range of possible gain values
constexpr std::array<double, 2> exposure_range = {37, 4839}; // The range of possible exposure values, second val is equal to std::floor(1e6/206.65)
constexpr std::array<double, 2> signal_range = {0, 65472}; // The range of possible signal values
constexpr double precision_error_margin = 0.025; // the allowable margin of floating point error between calculations
enum class Correction_Direction {
    TURN_DOWN, // 0 
    TURN_UP,   // 1
};

// Define the function stub for the AGC
adjusted_settings AGC(double signal, double gain, double exposure, double speed_setting);