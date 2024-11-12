#include "ComPort.hpp"

ComPort::ComPort(const std::string portName)
{
    this->portName = portName;
    try
    {
        this->serialHandle = createHandle();
        createProperties();
        createTimeouts();
    }
    catch (const std::exception &e)
    {
        std::cerr << e.what() << '\n';
    }
}

ComPort::~ComPort()
{
    CloseHandle(serialHandle);
}

int ComPort::read()
{
    char * data = nullptr;
    try
    {
        data = readBytes(NUMBER_SIZE);
    }
    catch(const std::exception& e)
    {
        std::cerr << e.what() << '\n';
    }
    return convertCharsToInt(data);
}

HANDLE ComPort::createHandle() noexcept(false)
{
    HANDLE myHandle = CreateFileA(portName.c_str(), GENERIC_READ, 0, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (myHandle == INVALID_HANDLE_VALUE)
    {
        if (GetLastError() == ERROR_FILE_NOT_FOUND)
            throw std::runtime_error("Serial port " + portName + " was not found!");
        throw std::runtime_error("Serial port " + portName + " handle creation failed!");
    }
    return myHandle;
}

void ComPort::createProperties() noexcept(false)
{
    DCB dcbSerialParam = {0};
    dcbSerialParam.DCBlength = sizeof(dcbSerialParam);
    if (!GetCommState(serialHandle, &dcbSerialParam))
        throw std::runtime_error("Cannot get the state of the port " + portName);
    dcbSerialParam.BaudRate = CBR_115200;
    dcbSerialParam.ByteSize = 8;
    dcbSerialParam.StopBits = ONESTOPBIT;
    dcbSerialParam.Parity = NOPARITY;
    if (!SetCommState(serialHandle, &dcbSerialParam))
        throw std::runtime_error("Cannot set the state of the port " + portName);
}

void ComPort::createTimeouts() noexcept(false)
{
    COMMTIMEOUTS timeout = {0};
    timeout.ReadIntervalTimeout = 60;
    timeout.ReadTotalTimeoutConstant = 60;
    timeout.ReadTotalTimeoutMultiplier = 15;
    timeout.WriteTotalTimeoutConstant = 60;
    timeout.WriteTotalTimeoutMultiplier = 8;
    if(!SetCommTimeouts(serialHandle, &timeout))
        throw std::runtime_error("Cannot set the timeouts of the port " + portName);
}

char *ComPort::readBytes(const int numberOfBytes) noexcept(false)
{
    char *buffer = new char[numberOfBytes + 1];
    DWORD dwRead = 0;
    if(!ReadFile(serialHandle, buffer, numberOfBytes, &dwRead, NULL))
        throw std::runtime_error("Cannot read bytes from file!");
    return buffer;
}

int ComPort::convertCharsToInt(const char *data)
{
    return (data == nullptr) ? -1 : atoi(data);
}