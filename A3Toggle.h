#import <UIKit/UIKit.h>

@protocol A3Toggle <NSObject>
@required
- (BOOL)stateForToggleIdentifier:(NSString *)toggleIdentifier;
- (void)applyState:(BOOL)newState forToggleIdentifier:(NSString *)toggleIdentifier;

@optional
- (NSString *)titleForToggleIdentifier:(NSString *)toggleIdentifier;
- (id)glyphImageDescriptorForControlState:(UIControlState)controlState size:(CGFloat)size scale:(CGFloat)scale forToggleIdentifier:(NSString *)toggleIdentifier;
@end