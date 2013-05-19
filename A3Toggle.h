#import <UIKit/UIKit.h>

typedef enum {
	A3ToggleStateOff = 0,
	A3ToggleStateOn = 1,
	A3ToggleStateIndeterminate = -1
} A3ToggleState;

@protocol A3Toggle <NSObject>
@optional
- (A3ToggleState)stateForToggleIdentifier:(NSString *)toggleIdentifier;
- (void)applyState:(A3ToggleState)newState forToggleIdentifier:(NSString *)toggleIdentifier;
- (void)applyActionForToggleIdentifier:(NSString *)toggleIdentifier;
- (NSString *)titleForToggleIdentifier:(NSString *)toggleIdentifier;
- (id)glyphImageDescriptorForControlState:(UIControlState)controlState size:(CGFloat)size scale:(CGFloat)scale forToggleIdentifier:(NSString *)toggleIdentifier;
@end