Directory contents:

- ASM7341_spectralSensitivity.mat: spectral sensitivity functions for the first 10 channels of the "minispect" chip. These values were taken from the spreadsheet "AS7341_Filter_Templates.xlsx" which was supplied by the manufacturer. The values in this table correspond to Figures 18 and 19 of the white paper AMS Datasheet DS000504 "AS7341; 11-Channel Multi-Spectral Digital Sensor; v3-00 • 2020-Jun-25"
- IMX219_spectralSensitivity.mat: spectral sensitivity functions for the three channels (RGB) of the IMX camera chip. These values were taken from Figure 18 of the paper Pagnutti 2017 J. Electron. Imaging 26(1), 013014. The values in the figure were extracted using WebPlotDigitizer v5, then interpolated using a spline fit ('SmoothingParam',0.07) in MATLAB, and then sampled at 1 nm resolution between 380 and 800 nm.
- D65_SPD.mat: spectral power distribution for the CIE D65 illuminant standard as a table variable with wavelengths and relative power. Downloaded from:  http://files.cie.co.at/204.xls
- CIEDaylightComponents_T.mat: basis set for reconstruction of daylight illuminant. https://cie.co.at/datatable/components-relative-spectral-distribution-daylight
