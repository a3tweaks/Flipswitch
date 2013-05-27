include theos/makefiles/common.mk

LIBRARY_NAME = libflipswitch FlipswitchSpringBoard

libflipswitch_FILES = FSSwitchPanel.m NSBundle+Flipswitch.m FSSwitchButton.m FSSwitchState.m
libflipswitch_FRAMEWORKS = UIKit CoreGraphics
libflipswitch_ARCHS = armv6 armv7

FlipswitchSpringBoard_FILES = FSSwitchMainPanel.m FSSwitchDataSource.m FSSwitchMainPanel.m FSPreferenceSwitchDataSource.m FSLazySwitch.m FSSwitchPanel+Prerender.m
FlipswitchSpringBoard_LIBRARIES = flipswitch
FlipswitchSpringBoard_FRAMEWORKS = UIKit
FlipswitchSpringBoard_PRIVATE_FRAMEWORKS = GraphicsServices
FlipswitchSpringBoard_LDFLAGS = -L$(THEOS_OBJ_DIR_NAME)
FlipswitchSpringBoard_ARCHS = armv6
FlipswitchSpringBoard_INSTALL_PATH = /Library/Flipswitch

SUBPROJECTS = Switches/AirplaneMode Switches/Bluetooth Switches/DoNotDisturb Switches/Hotspot Switches/Respring Switches/Ringer Switches/Rotation Switches/Vibration Switches/Wifi

include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

SDKVERSION := 5.1
TARGET_IPHONEOS_DEPLOYMENT_VERSION := 3.0

stage::
	$(ECHO_NOTHING)rsync -a Flipswitch.h FSSwitchDataSource.h FSSwitchPanel.h FSSwitchState.h $(THEOS_STAGING_DIR)/usr/lib/flipswitch/ $(FW_RSYNC_EXCLUDES)$(ECHO_END)
