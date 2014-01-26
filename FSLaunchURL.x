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
	if ([%c(SBDeviceLockController) sharedController].isPasscodeLocked) {
		SBLockScreenManager *manager = (SBLockScreenManager *)[%c(SBLockScreenManager) sharedInstance];
		if (manager.isUILocked) {
			void (^action)() = ^() {
				FSLaunchURLDirect(url);
			};
			SBLockScreenViewControllerBase *controller = [(SBLockScreenManager *)[%c(SBLockScreenManager) sharedInstance] lockScreenViewController];
			SBUnlockActionContext *context = [[%c(SBUnlockActionContext) alloc] initWithLockLabel:nil shortLockLabel:nil unlockAction:action identifier:nil];
			[context setDeactivateAwayController:YES];
			[controller setCustomUnlockActionContext:context];
			[controller setPasscodeLockVisible:YES animated:YES completion:nil];
			[context release];
		}
	}
	FSLaunchURLDirect(url);
}
