BUNDLE_NAME = Data
Data_FILES = Switch.x
Data_FRAMEWORKS = UIKit CoreTelephony
Data_PRIVATE_FRAMEWORKS = GraphicsServices
Data_LIBRARIES = flipswitch
Data_INSTALL_PATH = /Library/Switches

ADDITIONAL_CFLAGS = -I../../ -I../../ios-reversed-headers/
ADDITIONAL_LDFLAGS = -L../../$(THEOS_OBJ_DIR_NAME)

SDKVERSION := 5.1
TARGET_IPHONEOS_DEPLOYMENT_VERSION := 3.0
ARCHS = armv6

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/bundle.mk
