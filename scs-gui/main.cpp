#include <iostream>
#include "raylib.h"
#include "Parameters.hpp"
#include "Plot.hpp"

int main(){

    InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_NAME);

    Plot *myPlot = new Plot(NUMBER_OF_BINS);

    std::vector<float> v = {10.0f, 30.0f, 20.0f, 40.0f, 50.0f, 70.0f, 100.0f, 40.0f, 75.0f};
    myPlot->setData(v);

    SetTargetFPS(120);
    while(!WindowShouldClose()) {
        BeginDrawing();
        ClearBackground(BACKGROUND_COLOR);

        myPlot->draw();
        myPlot->incrementValue(0, 1.0f);
        EndDrawing();
    }
    return 0;
}