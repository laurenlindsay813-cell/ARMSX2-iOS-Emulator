// Sources/Emulator.cpp

#include <cstdint>
#include <iostream>

namespace Hush {

class Emulator {
public:
    bool initialize() {
        std::cout << "Hush PS2 Engine initializing...\n";
        return true;
    }

    void shutdown() {
        std::cout << "Hush PS2 Engine shutting down...\n";
    }
};

}