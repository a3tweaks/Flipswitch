LIBRARY_NAME = libflipswitch libFlipswitchSpringBoard libFlipswitchSwitches

libflipswitch_FILES = FSSwitchPanel.m NSBundle+Flipswitch.m FSSwitchButton.m FSSwitchState.m
libflipswitch_FRAMEWORKS = UIKit CoreGraphics
libflipswitch_USE_MODULES = 0

libFlipswitchSpringBoard_FILES = FSSwitchDataSource.m FSSwitchMainPanel.m FSPreferenceSwitchDataSource.m FSLazySwitch.m FSCapability.m FSLaunchURL.x
libFlipswitchSpringBoard_LIBRARIES = flipswitch bsm
libFlipswitchSpringBoard_FRAMEWORKS = UIKit
libFlipswitchSpringBoard_PRIVATE_FRAMEWORKS = GraphicsServices
libFlipswitchSpringBoard_LDFLAGS = -L$(THEOS_OBJ_DIR)
libFlipswitchSpringBoard_INSTALL_PATH = /Library/Flipswitch
libFlipswitchSpringBoard_USE_MODULES = 0

libFlipswitchSwitches_FILES = Switches/Adblock.x Switches/AirplaneMode.x Switches/AutoBrightness.x Switches/Autolock.x Switches/Bluetooth.x Switches/Data.x Switches/DataSpeed.x Switches/DoNotDisturb.x Switches/Flashlight.x Switches/Hotspot.x Switches/Location.x Switches/LowPower.x Switches/NightShift.x Switches/RecordScreen.x Switches/Respring.x Switches/Ringer.x Switches/Rotation.x Switches/Settings.x Switches/VPN.x Switches/Vibration.x Switches/Wifi.x Switches/WifiProxy.x
libFlipswitchSwitches_FRAMEWORKS = UIKit CoreLocation SystemConfiguration
libFlipswitchSwitches_PRIVATE_FRAMEWORKS = ManagedConfiguration GraphicsServices Preferences
libFlipswitchSwitches_LIBRARIES = flipswitch FlipswitchSpringBoard
libFlipswitchSwitches_LDFLAGS = -L$(THEOS_OBJ_DIR) -weak_framework CoreTelephony
libFlipswitchSwitches_CFLAGS = -I./
libFlipswitchSwitches_INSTALL_PATH = /Library/Flipswitch
libFlipswitchSwitches_USE_MODULES = 0

BUNDLE_NAME = FlipswitchSettings

FlipswitchSettings_FILES = FSSettingsController.m Switches/DataSpeedSettings.m Switches/RotationSettings.m Switches/FlashlightSettings.m Switches/RespringSettings.m
FlipswitchSettings_FRAMEWORKS = UIKit
FlipswitchSettings_PRIVATE_FRAMEWORKS = Preferences
FlipswitchSettings_LIBRARIES = flipswitch
FlipswitchSettings_LDFLAGS = -L$(THEOS_OBJ_DIR)
FlipswitchSettings_INSTALL_PATH = /Library/PreferenceBundles
FlipswitchSettings_USE_MODULES = 0

TOOL_NAME = switch
switch_FILES = tool.m
switch_USE_MODULES = 0
# switch_LIBRARIES = flipswitch
# switch_LDFLAGS = -L$(THEOS_OBJ_DIR)
ifeq ($(THEOS_CURRENT_ARCH),armv6)
	switch_FRAMEWORKS = Foundation UIKit
endif

ADDITIONAL_CFLAGS = -Ipublic -Ioverlayheaders -IPrivateHeaders -include log.h

TARGET_CODESIGN_FLAGS = -Sentitlements.xml

LEGACY_XCODE_PATH ?= /Applications/Xcode_Legacy.app/Contents/Developer
CLASSIC_XCODE_PATH ?= /Volumes/Xcode/Xcode.app/Contents/Developer

ifneq ($(wildcard $(LEGACY_XCODE_PATH)/*),)
THEOS_PLATFORM_SDK_ROOT_armv6 = $(LEGACY_XCODE_PATH)
THEOS_PLATFORM_SDK_ROOT_armv7 = $(CLASSIC_XCODE_PATH)
SDKVERSION_armv6 = 5.1
INCLUDE_SDKVERSION_armv6 = latest
TARGET_IPHONEOS_DEPLOYMENT_VERSION = 7.0
TARGET_IPHONEOS_DEPLOYMENT_VERSION_armv6 = 3.0
TARGET_IPHONEOS_DEPLOYMENT_VERSION_armv7 = 3.0
TARGET_IPHONEOS_DEPLOYMENT_VERSION_armv7s = 6.0
TARGET_IPHONEOS_DEPLOYMENT_VERSION_arm64 = 7.0
IPHONE_ARCHS = armv6 armv7 arm64
libflipswitch_IPHONE_ARCHS = armv6 armv7 armv7s arm64
else
TARGET_IPHONEOS_DEPLOYMENT_VERSION = 7.0
IPHONE_ARCHS = armv7 arm64
libflipswitch_IPHONE_ARCHS = armv7 armv7s arm64
ifeq ($(FINALPACKAGE),1)
$(error Building final package requires a legacy Xcode install!)
endif
endif

ifeq ($(THEOS_CURRENT_ARCH),armv6)
	GO_EASY_ON_ME=1
endif

INSTALL_TARGET_PROCESSES ?= SpringBoard

include theos/makefiles/common.mk
include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk
include $(THEOS_MAKE_PATH)/tool.mk

stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/usr/include$(ECHO_END)
	$(ECHO_NOTHING)rsync -a public/* $(THEOS_STAGING_DIR)/usr/include/flipswitch/ $(FW_RSYNC_EXCLUDES)$(ECHO_END)
