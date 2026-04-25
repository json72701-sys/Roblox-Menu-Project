ARCHS = arm64
TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ElxrScriptz

# Main tweak source + Executor + Loadstring
ElxrScriptz_FILES = main.mm \
	Methods/Executor.cpp \
	Methods/Loadstring.cpp \
	Luau/Compiler/src/Compiler.cpp \
	Luau/Compiler/src/BuiltinFolding.cpp \
	Luau/Compiler/src/Builtins.cpp \
	Luau/Compiler/src/ConstantFolding.cpp \
	Luau/Compiler/src/CostModel.cpp \
	Luau/Compiler/src/TableShape.cpp \
	Luau/Compiler/src/Types.cpp \
	Luau/Compiler/src/ValueTracking.cpp \
	Luau/Compiler/src/lcode.cpp \
	Luau/Ast/src/Allocator.cpp \
	Luau/Ast/src/Ast.cpp \
	Luau/Ast/src/Confusables.cpp \
	Luau/Ast/src/Cst.cpp \
	Luau/Ast/src/Lexer.cpp \
	Luau/Ast/src/Location.cpp \
	Luau/Ast/src/Parser.cpp \
	Luau/Ast/src/PrettyPrinter.cpp \
	Luau/Bytecode/src/BytecodeBuilder.cpp \
	Luau/Bytecode/src/BytecodeGraph.cpp \
	Luau/Common/src/BytecodeWire.cpp \
	Luau/Common/src/StringUtils.cpp \
	Luau/Common/src/TimeTrace.cpp

ElxrScriptz_FRAMEWORKS = UIKit Foundation Security
ElxrScriptz_CFLAGS = -fobjc-arc -std=c++17 \
	-I./Include \
	-I./Methods \
	-I./Structures \
	-I./Luau/Compiler/include \
	-I./Luau/Compiler/src \
	-I./Luau/Ast/include \
	-I./Luau/Bytecode/include \
	-I./Luau/Common/include
ElxrScriptz_CCFLAGS = -std=c++17

include $(THEOS_MAKE_PATH)/tweak.mk
