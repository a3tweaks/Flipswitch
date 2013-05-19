include theos/makefiles/common.mk

LIBRARY_NAME = libA3ToggleAPI
libA3ToggleAPI_FILES = A3ToggleManager.m A3ToggleManagerMain.m NSBundle+A3Images.m A3PreferenceToggle.m A3SBSettingsToggle.m A3Toggle.m
libA3ToggleAPI_FRAMEWORKS = UIKit CoreGraphics

SUBPROJECTS = DoNotDisturb

include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
