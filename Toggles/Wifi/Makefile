include theos/makefiles/common.mk

BUNDLE_NAME = Wifi
Wifi_FILES = Toggle.x
Wifi_FRAMEWORKS = UIKit
Wifi_LIBRARIES = A3ToggleAPI
Wifi_INSTALL_PATH = /Library/Toggles

ADDITIONAL_CFLAGS = -I../../
ADDITIONAL_LDFLAGS = -L../../$(THEOS_OBJ_PATH)

include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/bundle.mk
