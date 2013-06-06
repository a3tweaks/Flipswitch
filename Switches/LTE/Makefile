BUNDLE_NAME = LTE
LTE_FILES = Switch.x
LTE_FRAMEWORKS = UIKit CoreTelephony
LTE_PRIVATE_FRAMEWORKS = GraphicsServices
LTE_LIBRARIES = flipswitch
LTE_INSTALL_PATH = /Library/Switches

ADDITIONAL_CFLAGS = -I../../
ADDITIONAL_LDFLAGS = -L../../$(THEOS_OBJ_DIR_NAME)

SDKVERSION := 5.1
TARGET_IPHONEOS_DEPLOYMENT_VERSION := 5.1
ARCHS = armv7

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/bundle.mk
