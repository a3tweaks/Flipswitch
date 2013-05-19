#import <UIKit/UIKit.h>

#import "A3Toggle.h"

@interface A3ToggleManager : NSObject

+ (A3ToggleManager *)sharedToggleManager;

@property (nonatomic, readonly, copy) NSArray *toggleIdentifiers;

- (NSString *)titleForToggleID:(NSString *)toggleID;

- (UIImage *)toggleImageForToggleID:(NSString *)toggleID controlState:(UIControlState)controlState usingTemplateBundle:(NSBundle *)templateBundle;
- (UIImage *)toggleImageForToggleID:(NSString *)toggleID controlState:(UIControlState)controlState scale:(CGFloat)scale usingTemplateBundle:(NSBundle *)templateBundle;
- (id)glyphImageIdentifierForToggleID:(NSString *)toggleID controlState:(UIControlState)controlState size:(CGFloat)size scale:(CGFloat)scale;

- (A3ToggleState)toggleStateForToggleID:(NSString *)toggleID;
- (void)setToggleState:(A3ToggleState)state onToggleID:(NSString *)toggleID;
- (void)applyActionForToggleID:(NSString *)toggleID;

- (BOOL)hasAlternateActionForToggleID:(NSString *)toggleID;
- (void)applyAlternateActionForToggleID:(NSString *)toggleID;

@end

@interface A3ToggleManager (SpringBoard)
- (void)registerToggle:(id<A3Toggle>)toggle forIdentifier:(NSString *)toggleIdentifier;
- (void)unregisterToggleIdentifier:(NSString *)toggleIdentifier;
- (void)stateDidChangeForToggleIdentifier:(NSString *)toggleIdentifier;
@end

/*
@protocol A3Toggle <NSObject>
@required
- (BOOL)stateForToggleIdentifier:(NSString *)toggleIdentifier;
- (void)applyState:(BOOL)newState forToggleIdentifier:(NSString *)toggleIdentifier;
@end
*/