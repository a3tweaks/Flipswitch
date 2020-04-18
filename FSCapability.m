#import "FSCapability.h"

#import "dlsymfn.h"

static BOOL (*MGGetBoolAnswer)(NSString *capability);

BOOL FSSystemHasCapability(NSString *capabilityName)
{
	if (!MGGetBoolAnswer) {
		void *libMobileGestalt = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
		if (libMobileGestalt) {
			MGGetBoolAnswer = dlsymfn(libMobileGestalt, "MGGetBoolAnswer");
		}
#ifndef __arm64__
		if (!MGGetBoolAnswer) {
			void *libGraphicServices = dlopen("/System/Library/PrivateFrameworks/GraphicsServices.framework/GraphicsServices", RTLD_LAZY);
			if (libGraphicServices) {
				MGGetBoolAnswer = dlsymfn(libGraphicServices, "GSSystemHasCapability");
			}
		}
#endif
	}
	if (MGGetBoolAnswer != NULL)
		return MGGetBoolAnswer(capabilityName);
	return NO;
}
