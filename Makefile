LIBRARY_NAME = libflipswitch libFlipswitchSpringBoard

libflipswitch_FILES = FSSwitchPanel.m NSBundle+Flipswitch.m FSSwitchButton.m FSSwitchState.m
libflipswitch_FRAMEWORKS = UIKit CoreGraphics
libflipswitch_ARCHS = armv6 armv7 armv7s arm64

libFlipswitchSpringBoard_FILES = FSSwitchMainPanel.m FSSwitchDataSource.m FSSwitchMainPanel.m FSPreferenceSwitchDataSource.m FSLazySwitch.m FSCapability.m
libFlipswitchSpringBoard_LIBRARIES = flipswitch
libFlipswitchSpringBoard_FRAMEWORKS = UIKit
libFlipswitchSpringBoard_PRIVATE_FRAMEWORKS = GraphicsServices
libFlipswitchSpringBoard_LDFLAGS = -L$(THEOS_OBJ_DIR_NAME)
libFlipswitchSpringBoard_INSTALL_PATH = /Library/Flipswitch

SUBPROJECTS = Switches/Location Switches/3G Switches/AirplaneMode Switches/Autolock Switches/Bluetooth Switches/Data Switches/DoNotDisturb Switches/Flashlight Switches/Hotspot Switches/Respring Switches/Ringer Switches/Rotation Switches/Settings Switches/Vibration Switches/VPN Switches/Wifi Switches/WifiProxy

export THEOS_PLATFORM_SDK_ROOT_armv6 = /Applications/Xcode_Legacy.app/Contents/Developer
export SDKVERSION_armv6 = 5.1
export TARGET_IPHONEOS_DEPLOYMENT_VERSION = 3.0
export TARGET_IPHONEOS_DEPLOYMENT_VERSION_armv7s = 6.0
export TARGET_IPHONEOS_DEPLOYMENT_VERSION_arm64 = 7.0
export ARCHS = armv6 arm64

include theos/makefiles/common.mk
include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/usr/include$(ECHO_END)
	$(ECHO_NOTHING)rsync -a Flipswitch.h FSSwitchDataSource.h FSSwitchPanel.h FSSwitchState.h $(THEOS_STAGING_DIR)/usr/include/flipswitch/ $(FW_RSYNC_EXCLUDES)$(ECHO_END)
