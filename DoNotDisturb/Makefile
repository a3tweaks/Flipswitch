include theos/makefiles/common.mk

BUNDLE_NAME = DoNotDisturb
DoNotDisturb_FILES = Toggle.x
DoNotDisturb_FRAMEWORKS = UIKit
DoNotDisturb_PRIVATE_FRAMEWORKS = BulletinBoard
DoNotDisturb_LIBRARIES = A3ToggleAPI
DoNotDisturb_INSTALL_PATH = /Library/Toggles

ADDITIONAL_CFLAGS = -I../
ADDITIONAL_LDFLAGS = -L../$(THEOS_OBJ_PATH)

include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/bundle.mk
