#include <Availability.h>
#undef __IOS_PROHIBITED
#define __IOS_PROHIBITED

#import <UIKit/UIKit.h>
#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#ifdef __LP64__

@interface UITraitCollection (iOS13)
+ (UITraitCollection *)currentTraitCollection;
@end

@protocol UISUserInterfaceStyleModeDelegate;

@interface UISUserInterfaceStyleMode : NSObject
- (instancetype)initWithDelegate:(id<UISUserInterfaceStyleModeDelegate>)delegate;
@property (nonatomic, assign) long long modeValue;
@end

@protocol UISUserInterfaceStyleModeDelegate<NSObject>
- (void)userInterfaceStyleModeDidChange:(UISUserInterfaceStyleMode *)mode;
@end

@interface DarkModeSwitch : NSObject <FSSwitchDataSource, UISUserInterfaceStyleModeDelegate> {
@private
	UISUserInterfaceStyleMode *mode;
}
@end

@implementation DarkModeSwitch

- (id)init
{
	if (self = [super init]) {
		Class class = %c(UISUserInterfaceStyleMode);
		if (!class || ![UITraitCollection respondsToSelector:@selector(currentTraitCollection)]) {
			[self release];
			return nil;
		}
		mode = [[class alloc] initWithDelegate:self];
	}
	return self;
}

- (void)userInterfaceStyleModeDidChange:(UISUserInterfaceStyleMode *)mode
{
	[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:@"com.a3tweaks.switch.darkmode"];
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	if ([UITraitCollection currentTraitCollection].userInterfaceStyle == UIUserInterfaceStyleDark) {
		return FSSwitchStateOn;
	} else {
		return FSSwitchStateOff;
	}
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	switch (newState) {
		case FSSwitchStateIndeterminate:
		default:
			return;
		case FSSwitchStateOn:
			mode.modeValue = 2;
			break;
		case FSSwitchStateOff:
			mode.modeValue = 1;
			break;
	}
}

@end

#endif
