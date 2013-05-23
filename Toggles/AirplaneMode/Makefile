include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = AirplaneMode
AirplaneMode_FILES = Toggle.x
AirplaneMode_FRAMEWORKS = UIKit
AirplaneMode_LIBRARIES = A3ToggleAPI
AirplaneMode_INSTALL_PATH = /Library/Toggles

ADDITIONAL_CFLAGS = -I../../
ADDITIONAL_LDFLAGS = -L../../$(THEOS_OBJ_DIR_NAME)

include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/bundle.mk
