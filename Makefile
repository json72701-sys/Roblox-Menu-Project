# The architecture for modern iPads/iPhones
ARCHS = arm64
TARGET = iphone:clang:latest:14.0

# This links the folders so the compiler doesn't get lost
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = NexusExecutor

# Add all your .mm and .cpp files here so they get compiled
NexusExecutor_FILES = main.mm Methods/DataModel.cpp
NexusExecutor_FRAMEWORKS = UIKit Foundation Security
NexusExecutor_CFLAGS = -fobjc-arc -I./Include -I./Methods -I./Structures

include $(THEOS_MAKE_PATH)/tweak.mk
