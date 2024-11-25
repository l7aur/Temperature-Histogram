#include "Plot.hpp"

Plot::Plot(const int howManyBins)
{
    this->numberOfBins = howManyBins;
    this->data = std::vector<float>(howManyBins);
}

void Plot::setData(std::vector<float> newData)
{
    this->data = newData;
}

void Plot::incrementValue(const unsigned int binNumber, const float increment)
{
    try
    {
        data.at(binNumber)  = (data.at(binNumber) + increment > MAXIMUM_ADDMITTED_VALUE) ? MAXIMUM_ADDMITTED_VALUE : data.at(binNumber) + increment;
    }
    catch (const std::exception &e)
    {
        std::cerr << e.what() << '\n';
    }
    for(unsigned int i = 0; i < NUMBER_OF_BINS; i++)
        if(i != binNumber)
            data.at(i) = (data.at(i) - increment > 0) ? data.at(i) - increment : 0.0f;
}

void Plot::draw()
{
    drawAxes();
    drawBinLabels();
    drawColumns();
}

Plot::~Plot()
{
    this->numberOfBins = -1;
    this->data.~vector();
}

void Plot::drawBinLabels()
{
    const int stepSize = 75;
    const int padding = 10;
    const int startingX = 30;
    const int displayY = 580;
    for(unsigned int bin = 0; bin < NUMBER_OF_BINS; bin++) {
        int displayX = startingX + bin * stepSize + padding;
        std::string binName = "BIN" + std::to_string(bin);
        DrawText(binName.c_str(), displayX + stepSize / 3, displayY, 6, AXIS_COLOR);
    }
}

void Plot::drawColumns()
{
    const int startingX = 30;
    const int coordOX = WINDOW_HEIGHT - 30;
    const int padding = 10;
    const int stepSize = 75; // 740 - 30 = 710 pixels of working width / 9 bins => rounded 75
    for (unsigned int bin = 0; bin < NUMBER_OF_BINS; bin++)
    {
        int displayX = startingX + bin * stepSize + padding;
        int displayY = computeHeightOfColumn(bin);
        DrawRectangle(displayX, displayY, stepSize - padding, coordOX - displayY, RED);
    }
}

int Plot::computeHeightOfColumn(const unsigned int binIndex)
{
    const float percent = data.at(binIndex) / MAXIMUM_ADDMITTED_VALUE;
    return 60 + (1.0f - percent) * (WINDOW_HEIGHT - 60);
}

void Plot::drawAxes()
{
    drawOX();
    drawOY();
}

void Plot::drawOY()
{
    const float axisBoundingBoxX = 25.0f;
    const float triangleHeight = 30.0f;
    const float triangleHalfBase = 7.5f;
    const float axisMiddleX = static_cast<float>(axisBoundingBoxX) + AXIS_SIZE / 2.0f;
    DrawRectangle(static_cast<float>(axisBoundingBoxX), static_cast<float>(triangleHeight), AXIS_SIZE, WINDOW_HEIGHT - triangleHeight, AXIS_COLOR);
    DrawTriangle(
        Vector2{axisMiddleX, 0.0f},
        Vector2{axisMiddleX - triangleHalfBase, triangleHeight},
        Vector2{axisMiddleX + triangleHalfBase, triangleHeight},
        AXIS_COLOR);
}

void Plot::drawOX()
{
    const int triangleHeight = 30;
    const float axisBoundingBoxY = static_cast<float>(WINDOW_HEIGHT - triangleHeight);
    const float offsetX = 0.0f;
    const float triangleBaseX = static_cast<float>(WINDOW_WIDTH - triangleHeight);
    const float axisMiddleY = static_cast<float>(axisBoundingBoxY) + AXIS_SIZE / 2.0f;
    const float triangleHalfBase = 7.5f;
    DrawRectangle(offsetX, axisBoundingBoxY, WINDOW_WIDTH - triangleHeight, AXIS_SIZE, AXIS_COLOR);
    DrawTriangle(
        Vector2{static_cast<float>(WINDOW_WIDTH), axisMiddleY},
        Vector2{triangleBaseX, axisMiddleY - triangleHalfBase},
        Vector2{triangleBaseX, axisMiddleY + triangleHalfBase},
        AXIS_COLOR);
}
