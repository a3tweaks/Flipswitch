#import "FSCapability.h"

#import <dlfcn.h>

static BOOL (*MGGetBoolAnswer)(NSString *capability);

BOOL FSSystemHasCapability(NSString *capabilityName)
{
	if (!MGGetBoolAnswer) {
		void *libMobileGestalt = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
		if (libMobileGestalt) {
			MGGetBoolAnswer = dlsym(libMobileGestalt, "MGGetBoolAnswer");
		}
		if (!MGGetBoolAnswer) {
			void *libGraphicServices = dlopen("/System/Library/PrivateFrameworks/GraphicsServices.framework/GraphicsServices", RTLD_LAZY);
			if (libGraphicServices) {
				MGGetBoolAnswer = dlsym(libMobileGestalt, "GSSystemHasCapability");
			}
		}
	}
	if (MGGetBoolAnswer != NULL)
		return MGGetBoolAnswer(capabilityName);
	return NO;
}
