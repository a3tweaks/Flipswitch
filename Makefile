include theos/makefiles/common.mk

LIBRARY_NAME = libA3ToggleAPI
libA3ToggleAPI_FILES = A3ToggleManager.m A3ToggleManagerMain.m NSBundle+A3Images.m A3PreferenceToggle.m A3SBSettingsToggle.m A3Toggle.m
libA3ToggleAPI_FRAMEWORKS = UIKit CoreGraphics QuartzCore

SUBPROJECTS = Toggles/AirplaneMode Toggles/DoNotDisturb Toggles/Rotation Toggles/Wifi

include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

stage::
	$(ECHO_NOTHING)rsync -a A3Toggle.h A3ToggleManager.h $(THEOS_STAGING_DIR)/usr/lib/A3ToggleAPI/ $(FW_RSYNC_EXCLUDES)$(ECHO_END)
