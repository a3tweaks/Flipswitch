#import <UIKit/UIKit.h>

#import "A3Toggle.h"

@interface A3ToggleManager : NSObject

+ (A3ToggleManager *)sharedToggleManager;

@property (nonatomic, readonly, copy) NSArray *toggleIdentifiers;

- (NSString *)titleForToggleIdentifier:(NSString *)toggleIdentifier;

- (UIImage *)toggleImageForToggleIdentifier:(NSString *)toggleIdentifier controlState:(UIControlState)controlState usingTemplateBundle:(NSBundle *)templateBundle;
- (UIImage *)toggleImageForToggleIdentifier:(NSString *)toggleIdentifier controlState:(UIControlState)controlState scale:(CGFloat)scale usingTemplateBundle:(NSBundle *)templateBundle;
- (id)glyphImageIdentifierForToggleIdentifier:(NSString *)toggleIdentifier controlState:(UIControlState)controlState size:(CGFloat)size scale:(CGFloat)scale;

- (A3ToggleState)toggleStateForToggleIdentifier:(NSString *)toggleIdentifier;
- (void)setToggleState:(A3ToggleState)state onToggleIdentifier:(NSString *)toggleIdentifier;
- (void)applyActionForToggleIdentifier:(NSString *)toggleID;

- (BOOL)hasAlternateActionForToggleIdentifier:(NSString *)toggleID;
- (void)applyAlternateActionForToggleIdentifier:(NSString *)toggleID;

@end

@interface A3ToggleManager (SpringBoard)
- (void)registerToggle:(id<A3Toggle>)toggle forIdentifier:(NSString *)toggleIdentifier;
- (void)unregisterToggleIdentifier:(NSString *)toggleIdentifier;
- (void)stateDidChangeForToggleIdentifier:(NSString *)toggleIdentifier;
@end

extern NSString * const A3ToggleManagerTogglesChangedNotification;
/*
@protocol A3Toggle <NSObject>
@required
- (BOOL)stateForToggleIdentifier:(NSString *)toggleIdentifier;
- (void)applyState:(BOOL)newState forToggleIdentifier:(NSString *)toggleIdentifier;
@end
*/