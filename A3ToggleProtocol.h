#import <UIKit/UIKit.h>

@protocol A3Toggle <NSObject>
@required
- (BOOL)stateForToggleIdentifier:(NSString *)toggleIdentifier;
- (void)applyState:(BOOL)newState forToggleIdentifier:(NSString *)toggleIdentifier;

@optional
- (NSString *)toggleNameForIdentifier:(NSString *)toggleIdentifier;
@end