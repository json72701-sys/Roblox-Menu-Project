ARCHS = arm64
TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ElxrScriptz

ElxrScriptz_FILES = main.mm Methods/DataModel.cpp Menu.cpp
ElxrScriptz_FRAMEWORKS = UIKit Foundation Security
ElxrScriptz_CFLAGS = -fobjc-arc -I./Include -I./Methods -I./Structures

include $(THEOS_MAKE_PATH)/tweak.mk

