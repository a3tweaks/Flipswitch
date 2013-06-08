BUNDLE_NAME = PrivateBrowsing
PrivateBrowsing_FILES = Switch.x
PrivateBrowsing_PRIVATE_FRAMEWORKS = GraphicsServices
PrivateBrowsing_LIBRARIES = flipswitch
PrivateBrowsing_INSTALL_PATH = /Library/Switches

ADDITIONAL_CFLAGS = -I../../
ADDITIONAL_LDFLAGS = -L../../$(THEOS_OBJ_DIR_NAME)

SDKVERSION := 5.1
TARGET_IPHONEOS_DEPLOYMENT_VERSION := 3.0
ARCHS = armv6

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/bundle.mk
