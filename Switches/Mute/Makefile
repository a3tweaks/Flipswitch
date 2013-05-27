include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = Mute
Mute_FILES = Switch.x
Mute_FRAMEWORKS = UIKit
Mute_LIBRARIES = flipswitch
Mute_INSTALL_PATH = /Library/Switches

ADDITIONAL_CFLAGS = -I../../
ADDITIONAL_LDFLAGS = -L../../$(THEOS_OBJ_DIR_NAME)

include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/bundle.mk
