#import "FSCapability.h"

#import <dlfcn.h>
#import <GraphicsServices/GraphicsServices.h>

static BOOL (*MGGetBoolAnswer)(NSString *capability);

BOOL FSSystemHasCapability(NSString *capabilityName)
{
	if (kCFCoreFoundationVersionNumber <= 793.00)
		return GSSystemHasCapability((CFStringRef)capabilityName);
	if (!MGGetBoolAnswer) {
		void *libMobileGestalt = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
		if (libMobileGestalt)
			MGGetBoolAnswer = dlsym(libMobileGestalt, "MGGetBoolAnswer");
	}
	if (MGGetBoolAnswer != NULL)
		return MGGetBoolAnswer(capabilityName);
	return NO;
}
