include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = Location
Location_FILES = Switch.x
Location_FRAMEWORKS = UIKit
Location_LIBRARIES = flipswitch
Location_INSTALL_PATH = /Library/Switches

ADDITIONAL_CFLAGS = -I../../
ADDITIONAL_LDFLAGS = -L../../$(THEOS_OBJ_DIR_NAME)

include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/bundle.mk
