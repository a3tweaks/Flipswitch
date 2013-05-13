include theos/makefiles/common.mk

LIBRARY_NAME = libA3ToggleAPI
libA3ToggleAPI_FILES = A3ToggleManager.m A3ToggleManagerMain.m
libA3ToggleAPI_FRAMEWORKS = UIKit CoreGraphics

include $(THEOS_MAKE_PATH)/library.mk
