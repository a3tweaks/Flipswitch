#import "FSLaunchURL.h"

#import <UIKit/UIKit.h>

@interface UIApplication (Private)
- (void)applicationOpenURL:(NSURL *)url;
- (void)applicationOpenURL:(NSURL *)url publicURLsOnly:(BOOL)publicURLsOnly;
@end

@interface SBUnlockActionContext : NSObject
- (id)initWithLockLabel:(NSString *)lockLabel shortLockLabel:(NSString *)label unlockAction:(void (^)())action identifier:(NSString *)id;
- (void)setDeactivateAwayController:(BOOL)deactivate;
@end

@interface SBAlert : UIViewController
@end

@interface SBLockScreenViewControllerBase : SBAlert
- (void)setCustomUnlockActionContext:(SBUnlockActionContext *)context;
- (void)setPasscodeLockVisible:(BOOL)visibile animated:(BOOL)animated completion:(void (^)())completion;
@end

@interface SBLockScreenActionContext : NSObject
- (id)initWithLockLabel:(NSString *)lockLabel shortLockLabel:(NSString *)label action:(void (^)())action identifier:(NSString *)id;
- (void)setDeactivateAwayController:(BOOL)deactivate;
@end

@interface SBLockScreenViewControllerBase (iOS8)
- (void)setCustomLockScreenActionContext:(SBLockScreenActionContext *)context;
@end

@interface SBLockScreenManager : NSObject
+ (SBLockScreenManager *)sharedInstance;
@property (nonatomic, readonly) BOOL isUILocked;
@property (nonatomic, readonly) SBLockScreenViewControllerBase *lockScreenViewController;
@end

@interface SBDeviceLockController : NSObject
+ (SBDeviceLockController *)sharedController;
- (BOOL)isPasscodeLocked;
@end

static void FSLaunchURLDirect(NSURL *url)
{
	UIApplication *app = [UIApplication sharedApplication];
	if ([app respondsToSelector:@selector(applicationOpenURL:publicURLsOnly:)])
		[app applicationOpenURL:url publicURLsOnly:NO];
	else
		[app applicationOpenURL:url];
}

void FSLaunchURL(NSURL *url)
{
	if (!url)
		return;
	SBDeviceLockController *lockController = [%c(SBDeviceLockController) sharedController];
	if ([lockController respondsToSelector:@selector(isPasscodeLocked)]) {
		if (lockController.isPasscodeLocked) {
			SBLockScreenManager *manager = (SBLockScreenManager *)[%c(SBLockScreenManager) sharedInstance];
			if (manager.isUILocked) {
				void (^action)() = ^() {
					FSLaunchURLDirect(url);
				};
				SBLockScreenViewControllerBase *controller = [manager lockScreenViewController];
				id context;
				if ([controller respondsToSelector:@selector(setCustomUnlockActionContext:)]) {
					context = [[%c(SBUnlockActionContext) alloc] initWithLockLabel:nil shortLockLabel:nil unlockAction:action identifier:nil];
					[controller setCustomUnlockActionContext:context];
				} else {
					context = [[%c(SBLockScreenActionContext) alloc] initWithLockLabel:nil shortLockLabel:nil action:action identifier:nil];
					[controller setCustomLockScreenActionContext:context];
				}
				[context setDeactivateAwayController:YES];
				[controller setPasscodeLockVisible:YES animated:YES completion:nil];
				[context release];
				return;
			}
		}
	}
	FSLaunchURLDirect(url);
}
