#import "FSLaunchURL.h"

#import <UIKit/UIKit.h>

@interface UIApplication (Private)
- (void)applicationOpenURL:(NSURL *)url;
- (void)applicationOpenURL:(NSURL *)url publicURLsOnly:(BOOL)publicURLsOnly;
@end

@interface SBLockScreenManager : NSObject
+ (SBLockScreenManager *)sharedInstance;
@property (nonatomic, readonly) BOOL isUILocked;
- (void)applicationRequestedDeviceUnlock;
- (void)cancelApplicationRequestedDeviceLockEntry;
@end

@interface SBDeviceLockController : NSObject
+ (SBDeviceLockController *)sharedController;
- (BOOL)isPasscodeLocked;
@end

static NSURL *pendingURL;

static void FSLaunchURLDirect(NSURL *url)
{
	UIApplication *app = [UIApplication sharedApplication];
	if ([app respondsToSelector:@selector(applicationOpenURL:publicURLsOnly:)])
		[app applicationOpenURL:url publicURLsOnly:NO];
	else
		[app applicationOpenURL:url];
}

%hook SBLockScreenManager

- (void)_sendUILockStateChangedNotification
{
	%orig();
	NSURL *url = pendingURL;
	if (url) {
		pendingURL = nil;
		if (!self.isUILocked)
			FSLaunchURLDirect(url);
		[url release];
	}
}

- (void)cancelApplicationRequestedDeviceLockEntry
{
	[pendingURL release];
	pendingURL = nil;
	%orig();
}

%end

void FSLaunchURL(NSURL *url)
{
	if (!url)
		return;
	if ([%c(SBDeviceLockController) sharedController].isPasscodeLocked) {
		SBLockScreenManager *manager = (SBLockScreenManager *)[%c(SBLockScreenManager) sharedInstance];
		if (manager.isUILocked) {
			url = [url retain];
			[pendingURL release];
			pendingURL = url;
			[manager applicationRequestedDeviceUnlock];
			return;
		}
	}
	FSLaunchURLDirect(url);
}
