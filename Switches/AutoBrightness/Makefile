BUNDLE_NAME = AutoBrightness
AutoBrightness_FILES = Switch.x
AutoBrightness_FRAMEWORKS = UIKit
AutoBrightness_PRIVATE_FRAMEWORKS = GraphicsServices
AutoBrightness_LIBRARIES = flipswitch
AutoBrightness_INSTALL_PATH = /Library/Switches

ADDITIONAL_CFLAGS = -I../../
ADDITIONAL_LDFLAGS = -L../../$(THEOS_OBJ_DIR_NAME)

SDKVERSION := 5.1
TARGET_IPHONEOS_DEPLOYMENT_VERSION := 3.0
ARCHS = armv6

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/bundle.mk
