include theos/makefiles/common.mk

BUNDLE_NAME = Rotation
Rotation_FILES = Toggle.x
Rotation_FRAMEWORKS = UIKit
Rotation_LIBRARIES = A3ToggleAPI
Rotation_PRIVATE_FRAMEWORKS = GraphicsServices
Rotation_INSTALL_PATH = /Library/Toggles

ADDITIONAL_CFLAGS = -I../
ADDITIONAL_LDFLAGS = -L../.theos/obj

include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/bundle.mk
