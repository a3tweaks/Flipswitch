include theos/makefiles/common.mk

LIBRARY_NAME = libflipswitch
libflipswitch_FILES = FSSwitchPanel.m FSSwitchMainPanel.m NSBundle+Flipswitch.m FSPreferenceSwitchDataSource.m FSSBSettingsSwitch.m FSSwitchDataSource.m FSSwitchButton.m FSLazySwitch.m FSSwitchPanel+Prerender.m
libflipswitch_FRAMEWORKS = UIKit CoreGraphics QuartzCore
libflipswitch_PRIVATE_FRAMEWORKS = GraphicsServices

SUBPROJECTS = Switches/AirplaneMode Switches/Bluetooth Switches/DoNotDisturb Switches/Hotspot Switches/LTE Switches/Respring Switches/Ringer Switches/Rotation Switches/Vibration Switches/Wifi

include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

ARCHS = armv6 armv7

SDKVERSION := 5.1
TARGET_IPHONEOS_DEPLOYMENT_VERSION := 3.0

stage::
	$(ECHO_NOTHING)rsync -a Flipswitch.h FSSwitchDataSource.h FSSwitchPanel.h FSSwitchState.h $(THEOS_STAGING_DIR)/usr/lib/flipswitch/ $(FW_RSYNC_EXCLUDES)$(ECHO_END)
