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

HANDLE ComPort::createHandle() noexcept(false)
{
    HANDLE myHandle = CreateFileA(portName.c_str(), GENERIC_READ, 0, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (myHandle == INVALID_HANDLE_VALUE)
    {
        DWORD errorCode = GetLastError();
        if (errorCode == ERROR_FILE_NOT_FOUND)
            throw std::runtime_error("Serial port " + portName + " was not found! " + std::to_string(errorCode));
        throw std::runtime_error("Serial port " + portName + " handle creation failed! " + std::to_string(errorCode));
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
    timeout.ReadIntervalTimeout = 50;        // 50 milliseconds
    timeout.ReadTotalTimeoutConstant = 100;  // 100 milliseconds
    timeout.ReadTotalTimeoutMultiplier = 10; // 10 milliseconds per byte
    if (!SetCommTimeouts(serialHandle, &timeout))
        throw std::runtime_error("Cannot set the timeouts of the port " + portName);
}

int ComPort::read()
{
    std::string s{"Err"};
    try
    {
        char *data = nullptr;
        data = readBytes(NUMBER_SIZE);
        s = convertBufferToString(data);
    }
    catch (const std::exception &e)
    {
        std::cerr << e.what() << '\n';
    }
    return convertCharsToInt(s);
}

char *ComPort::readBytes(const int numberOfBytes) noexcept(false)
{
    char *buffer = new char[numberOfBytes + 1];
    clearBuffer(numberOfBytes, buffer);
    DWORD dwRead = 0;
    if (!ReadFile(serialHandle, buffer, numberOfBytes, &dwRead, NULL))
        throw std::runtime_error("Cannot read bytes from file!");

    return buffer;
}

std::string ComPort::convertBufferToString(char *data)
{
    std::string s{data};
    std::size_t firstEncounterOfSpace = s.find_first_of(' ');
    s = s.substr(firstEncounterOfSpace + 1, s.size() - firstEncounterOfSpace);
    std::size_t secondEncounterOfSpace = s.find_first_of(' ');
    return s.substr(0, secondEncounterOfSpace);
}

int ComPort::convertCharsToInt(std::string data)
{
    if (data.size() != 8)
        return -1;
    int r = computeInput(data);
    return r;
}

int ComPort::computeInput(std::string data)
{
    return convertHexaToInt(data.at(6)) +
           convertHexaToInt(data.at(4)) * 16 +
           convertHexaToInt(data.at(2)) * 16 * 16 +
           convertHexaToInt(data.at(0)) * 16 * 16 * 16;
}

int ComPort::convertHexaToInt(const char hexD)
{
    return (hexD == '0') ? 0 : (hexD == '1') ? 1
                           : (hexD == '2')   ? 2
                           : (hexD == '3')   ? 3
                           : (hexD == '4')   ? 4
                           : (hexD == '5')   ? 5
                           : (hexD == '6')   ? 6
                           : (hexD == '7')   ? 7
                           : (hexD == '8')   ? 8
                           : (hexD == '9')   ? 9
                           : (hexD == 'A')   ? 10
                           : (hexD == 'B')   ? 11
                           : (hexD == 'C')   ? 12
                           : (hexD == 'D')   ? 13
                           : (hexD == 'E')   ? 14
                                             : 15;
}

void ComPort::clearBuffer(const int numberOfBytes, char *buffer)
{
    for (int i = 0; i < numberOfBytes + 1; i++)
        buffer[i] = 0;
}

ComPort::~ComPort()
{
    CloseHandle(serialHandle);
}