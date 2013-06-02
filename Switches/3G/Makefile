BUNDLE_NAME = 3G
3G_FILES = Switch.x
3G_FRAMEWORKS = UIKit CoreTelephony
3G_PRIVATE_FRAMEWORKS = GraphicsServices
3G_LIBRARIES = flipswitch
3G_INSTALL_PATH = /Library/Switches

ADDITIONAL_CFLAGS = -I../../ -I../../ios-reversed-headers/
ADDITIONAL_LDFLAGS = -L../../$(THEOS_OBJ_DIR_NAME)

SDKVERSION := 5.1
TARGET_IPHONEOS_DEPLOYMENT_VERSION := 5.0
ARCHS = armv7

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/bundle.mk
