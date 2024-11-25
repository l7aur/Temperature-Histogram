#ifndef PLOT_HPP
#define PLOT_HPP

#include <vector>
#include <iostream>
#include <stdexcept>
#include "Parameters.hpp"

class Plot {
public:
    Plot(const int howManyBins);
    void setData(std::vector<float> newData);
    void incrementValue(const unsigned int binNumber, const float newValue);
    void draw();
    ~Plot();
private:
    void drawBinLabels();
    void drawColumns();
    int computeHeightOfColumn(const unsigned int binIndex);
    void drawAxes();
    void drawOY();
    void drawOX();
    std::vector<float> data;
    int numberOfBins = -1;
};  

#endif