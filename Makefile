LIBRARY_NAME = libflipswitch libFlipswitchSpringBoard libFlipswitchSwitches

libflipswitch_FILES = FSSwitchPanel.m NSBundle+Flipswitch.m FSSwitchButton.m FSSwitchState.m
libflipswitch_FRAMEWORKS = UIKit CoreGraphics
libflipswitch_ARCHS = armv6 armv7 armv7s arm64

libFlipswitchSpringBoard_FILES = FSSwitchDataSource.m FSSwitchMainPanel.m FSPreferenceSwitchDataSource.m FSLazySwitch.m FSCapability.m FSLaunchURL.x
libFlipswitchSpringBoard_LIBRARIES = flipswitch bsm
libFlipswitchSpringBoard_FRAMEWORKS = UIKit
libFlipswitchSpringBoard_PRIVATE_FRAMEWORKS = GraphicsServices
libFlipswitchSpringBoard_LDFLAGS = -L$(THEOS_OBJ_DIR_NAME)
libFlipswitchSpringBoard_INSTALL_PATH = /Library/Flipswitch

libFlipswitchSwitches_FILES = Switches/AirplaneMode.x Switches/AutoBrightness.x Switches/Autolock.x Switches/Bluetooth.x Switches/Data.x Switches/DataSpeed.x Switches/DoNotDisturb.x Switches/Flashlight.x Switches/Hotspot.x Switches/Location.x Switches/LowPower.x Switches/NightShift.x Switches/Respring.x Switches/Ringer.x Switches/Rotation.x Switches/Settings.x Switches/VPN.x Switches/Vibration.x Switches/Wifi.x Switches/WifiProxy.x
libFlipswitchSwitches_FRAMEWORKS = UIKit CoreLocation SystemConfiguration
libFlipswitchSwitches_PRIVATE_FRAMEWORKS = ManagedConfiguration GraphicsServices Preferences
libFlipswitchSwitches_LIBRARIES = flipswitch FlipswitchSpringBoard
libFlipswitchSwitches_LDFLAGS = -L$(THEOS_OBJ_DIR_NAME) -weak_framework CoreTelephony
libFlipswitchSwitches_CFLAGS = -I./
libFlipswitchSwitches_INSTALL_PATH = /Library/Flipswitch

BUNDLE_NAME = FlipswitchSettings

FlipswitchSettings_FILES = FSSettingsController.m Switches/DataSpeedSettings.m Switches/RotationSettings.m Switches/FlashlightSettings.m Switches/RespringSettings.m
FlipswitchSettings_FRAMEWORKS = UIKit
FlipswitchSettings_PRIVATE_FRAMEWORKS = Preferences
FlipswitchSettings_LIBRARIES = flipswitch
FlipswitchSettings_LDFLAGS = -L$(THEOS_OBJ_DIR_NAME)
FlipswitchSettings_INSTALL_PATH = /Library/PreferenceBundles

ADDITIONAL_CFLAGS = -Ipublic -Ioverlayheaders -IPrivateHeaders

export THEOS_PLATFORM_SDK_ROOT_armv6 = /Applications/Xcode_Legacy.app/Contents/Developer
export SDKVERSION_armv6 = 5.1
export TARGET_IPHONEOS_DEPLOYMENT_VERSION = 3.0
export TARGET_IPHONEOS_DEPLOYMENT_VERSION_armv7s = 6.0
export TARGET_IPHONEOS_DEPLOYMENT_VERSION_arm64 = 7.0
export ARCHS = armv6 arm64

ifeq ($(THEOS_CURRENT_ARCH),armv6)
	GO_EASY_ON_ME=1
endif

INSTALL_TARGET_PROCESSES = SpringBoard

include theos/makefiles/common.mk
include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk

stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/usr/include$(ECHO_END)
	$(ECHO_NOTHING)rsync -a public/* $(THEOS_STAGING_DIR)/usr/include/flipswitch/ $(FW_RSYNC_EXCLUDES)$(ECHO_END)
