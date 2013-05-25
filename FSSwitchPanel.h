#import <UIKit/UIKit.h>

#import "FSSwitch.h"

@interface FSSwitchPanel : NSObject

+ (FSSwitchPanel *)sharedPanel;

@property (nonatomic, readonly, copy) NSArray *switchIdentifiers;

- (NSString *)titleForSwitchIdentifier:(NSString *)switchIdentifier;
- (BOOL)shouldShowSwitchIdentifier:(NSString *)switchIdentifier;

- (UIButton *)buttonForSwitchIdentifier:(NSString *)switchIdentifier usingTemplate:(NSBundle *)template;

- (UIImage *)imageOfSwitchState:(FSSwitchState)state controlState:(UIControlState)controlState forSwitchIdentifier:(NSString *)switchIdentifier usingTemplate:(NSBundle *)template;
- (UIImage *)imageOfSwitchState:(FSSwitchState)state controlState:(UIControlState)controlState scale:(CGFloat)scale forSwitchIdentifier:(NSString *)switchIdentifier usingTemplate:(NSBundle *)template;

- (id)glyphImageDescriptorOfState:(FSSwitchState)switchState size:(CGFloat)size scale:(CGFloat)scale forSwitchIdentifier:(NSString *)switchIdentifier;

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier;
- (void)setState:(FSSwitchState)state forSwitchIdentifier:(NSString *)switchIdentifier;
- (void)applyActionForSwitchIdentifier:(NSString *)switchIdentifier;

- (BOOL)hasAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier;
- (void)applyAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier;

- (void)openURLAsAlternateAction:(NSURL *)url;

@end

@interface FSSwitchPanel (SpringBoard)
- (void)registerSwitch:(id<FSSwitch>)switchImplementation forIdentifier:(NSString *)switchIdentifier;
- (void)unregisterSwitchIdentifier:(NSString *)switchIdentifier;
- (void)stateDidChangeForSwitchIdentifier:(NSString *)switchIdentifier;
@end

extern NSString * const FSSwitchPanelSwitchsChangedNotification;

extern NSString * const FSSwitchPanelSwitchStateChangedNotification;
extern NSString * const FSSwitchPanelSwitchIdentifierKey;
