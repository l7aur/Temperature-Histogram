#include <iostream>
#include "Parameters.hpp"
#include "Plot.hpp"
#include "ComPort.hpp"

float getTemperature(const int x)
{
    return (1.0f * static_cast<float>(x) / 65536.0f) * 165.0f - 40.0f;
}

int getBinBasedOnValue(int x)
{
    float temp = getTemperature(x);
    std::cout << temp <<'\n';
    if (temp < THRESHOLD1)
        return 0;
    if (temp < THRESHOLD2)
        return 1;
    if (temp < THRESHOLD3)
        return 2;
    if (temp < THRESHOLD4)
        return 3;
    if (temp < THRESHOLD5)
        return 4;
    if (temp < THRESHOLD6)
        return 5;
    if (temp < THRESHOLD7)
        return 6;
    return 7;
}

int main()
{
    ComPort *myPort = new ComPort("COM5");

    InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_NAME);

    Plot *myPlot = new Plot(NUMBER_OF_BINS);

    std::vector<float> v = {0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f};
    myPlot->setData(v);

    SetTargetFPS(120);
    while (!WindowShouldClose())
    {
        BeginDrawing();
        ClearBackground(BACKGROUND_COLOR);
        int x = myPort->read();
        if (x > 0)
        {
            int bin = getBinBasedOnValue(x);
            myPlot->incrementValue(bin, 0.3f);
        }
        myPlot->draw();
        EndDrawing();
    }

    return 0;
}