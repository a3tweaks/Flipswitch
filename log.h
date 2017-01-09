// Tiny shim to convert NSLog to public os_log statements on iOS 10
#ifdef __OBJC__
#import <Foundation/Foundation.h>
#if __IPHONE_OS_VERSION_MAX_ALLOWED > 100000
#include <os/log.h>
#define NSLog(...) do { \
	@autoreleasepool { \
		if (kCFCoreFoundationVersionNumber > 1299.0) { \
			os_log(OS_LOG_DEFAULT, "%{public}@", [NSString stringWithFormat:__VA_ARGS__]); \
		} else { \
			NSLog(__VA_ARGS__); \
		} \
	} \
} while(0)
#endif
#endif
