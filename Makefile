include theos/makefiles/common.mk

LIBRARY_NAME = libflipswitch
libflipswitch_FILES = FSSwitchPanel.m FSSwitchMainPanel.m NSBundle+Flipswitch.m FSPreferenceSwitch.m FSSBSettingsSwitch.m FSSwitch.m FSSwitchButton.m FSLazySwitch.m FSSwitchPanel+Prerender.m
libflipswitch_FRAMEWORKS = UIKit CoreGraphics QuartzCore
libflipswitch_PRIVATE_FRAMEWORKS = GraphicsServices

SUBPROJECTS = Switches/AirplaneMode Switches/DoNotDisturb Switches/Rotation Switches/Wifi

include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

stage::
	$(ECHO_NOTHING)rsync -a FSSwitch.h FSSwitchPanel.h $(THEOS_STAGING_DIR)/usr/lib/flipswitch/ $(FW_RSYNC_EXCLUDES)$(ECHO_END)
