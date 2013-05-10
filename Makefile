include theos/makefiles/common.mk

LIBRARY_NAME = A3ToggleAPI
A3ToggleAPI_FILES = A3ToggleManager.m
A3ToggleAPI_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/library.mk
