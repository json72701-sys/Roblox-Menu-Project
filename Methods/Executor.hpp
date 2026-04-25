#ifndef EXECUTOR_H
#define EXECUTOR_H

#include <string>
#include <cstdint>

namespace Executor {
    // Compiles raw Luau source text into bytecode using the embedded Luau compiler.
    // Returns the bytecode blob on success, or an empty string on failure.
    // On failure, `errorOut` is set to the error message.
    std::string CompileScript(const std::string& source, std::string& errorOut);

    // Compiles and injects script bytecode into memory at a target LocalScript instance.
    // `dataModel` - the DataModel pointer obtained from GetDataModel()
    // `source`    - the raw Luau script text
    // Returns true on success, false on failure (with error in `errorOut`).
    bool ExecuteScript(uintptr_t dataModel, const std::string& source, std::string& errorOut);
}

#endif
