BUNDLE_NAME = LowPower
LowPower_FILES = Switch.x
LowPower_PRIVATE_FRAMEWORKS = CoreDuet
LowPower_LIBRARIES = flipswitch
LowPower_INSTALL_PATH = /Library/Switches

IPHONE_ARCHS = armv7 arm64

ADDITIONAL_CFLAGS = -I../../public -I../../PrivateHeaders
ADDITIONAL_LDFLAGS = -L../../$(THEOS_OBJ_DIR_NAME)

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/bundle.mk
