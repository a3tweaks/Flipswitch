#import <UIKit/UIKit.h>

#import "A3Toggle.h"

@interface A3ToggleManager : NSObject

+ (A3ToggleManager *)sharedToggleManager;

@property (nonatomic, readonly, copy) NSArray *toggleIdentifiers;

- (NSString *)titleForToggleIdentifier:(NSString *)toggleIdentifier;
- (BOOL)shouldShowToggleForToggleIdentifier:(NSString *)toggleIdentifier;

- (UIButton *)buttonForToggleIdentifier:(NSString *)toggleIdentifier usingTemplate:(NSBundle *)template;
- (UIImage *)imageOfToggleState:(A3ToggleState)state controlState:(UIControlState)controlState forToggleIdentifier:(NSString *)toggleIdentifier usingTemplate:(NSBundle *)template;
- (UIImage *)imageOfToggleState:(A3ToggleState)state controlState:(UIControlState)controlState scale:(CGFloat)scale forToggleIdentifier:(NSString *)toggleIdentifier usingTemplate:(NSBundle *)template;

- (id)glyphImageDescriptorOfToggleState:(A3ToggleState)toggleState size:(CGFloat)size scale:(CGFloat)scale forToggleIdentifier:(NSString *)toggleIdentifier;

- (A3ToggleState)toggleStateForToggleIdentifier:(NSString *)toggleIdentifier;
- (void)setToggleState:(A3ToggleState)state onToggleIdentifier:(NSString *)toggleIdentifier;
- (void)applyActionForToggleIdentifier:(NSString *)toggleIdentifier;

- (BOOL)hasAlternateActionForToggleIdentifier:(NSString *)toggleIdentifier;
- (void)applyAlternateActionForToggleIdentifier:(NSString *)toggleIdentifier;

- (void)openURLAsAlternateAction:(NSURL *)url;

@end

@interface A3ToggleManager (SpringBoard)
- (void)registerToggle:(id<A3Toggle>)toggle forIdentifier:(NSString *)toggleIdentifier;
- (void)unregisterToggleIdentifier:(NSString *)toggleIdentifier;
- (void)stateDidChangeForToggleIdentifier:(NSString *)toggleIdentifier;
@end

extern NSString * const A3ToggleManagerTogglesChangedNotification;

extern NSString * const A3ToggleManagerToggleStateChangedNotification;
extern NSString * const A3ToggleManagerToggleIdentifierKey;

/*
@protocol A3Toggle <NSObject>
@required
- (BOOL)stateForToggleIdentifier:(NSString *)toggleIdentifier;
- (void)applyState:(BOOL)newState forToggleIdentifier:(NSString *)toggleIdentifier;
@end
*/