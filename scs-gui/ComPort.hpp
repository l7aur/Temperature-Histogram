#ifndef COM_PORT_HPP
#define COM_PORT_HPP

#define WIN32_LEAN_AND_MEAN
#define NOUSER
#define NOGDI
#include <windows.h>
#include <stdexcept>
#include <iostream>

class ComPort
{
public:
    ComPort(std::string portName);
    int read();
    ~ComPort();

private:
    HANDLE createHandle() noexcept(false);
    void createProperties() noexcept(false);
    void createTimeouts() noexcept(false);
    char *readBytes(const int numberOfBytes) noexcept(false);
    std::string convertBufferToString(char *data);
    int convertCharsToInt(std::string data);
    int computeInput(std::string data);
    int convertHexaToInt(const char hexD);
    void clearBuffer(const int numberOfBytes, char *buffer);
    HANDLE serialHandle;
    std::string portName;
};

const unsigned int NUMBER_SIZE = 16;


#endif