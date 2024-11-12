#ifndef COM_PORT_HPP
#define COM_PORT_HPP

#include <windows.h>
#include <stdexcept>
#include <iostream>

const unsigned int NUMBER_SIZE = 4;

class ComPort {
public:
    ComPort(std::string portName);
    int read();
    ~ComPort();
private:
    HANDLE createHandle() noexcept(false);
    void createProperties() noexcept(false);
    void createTimeouts() noexcept(false);
    char* readBytes(const int numberOfBytes) noexcept(false);
    int convertCharsToInt(const char * data);
    HANDLE serialHandle;
    std::string portName;
};

#endif