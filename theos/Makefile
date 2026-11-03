# Compilazione su Linux (senza Mac) con Theos + toolchain Swift per iOS e SDK iPhoneOS 16.5.
TARGET := iphone:clang:16.5:15.0
ARCHS := arm64
PACKAGE_FORMAT := ipa
include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = PuliziaFoto
PuliziaFoto_FILES = $(wildcard Sources/*.swift)
PuliziaFoto_FRAMEWORKS = UIKit SwiftUI Photos
PuliziaFoto_SWIFTFLAGS = -O

include $(THEOS_MAKE_PATH)/application.mk
