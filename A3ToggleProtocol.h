#import <UIKit/UIKit.h>

@protocol A3Toggle <NSObject>
@required
- (BOOL)stateForToggleIdentifier:(NSString *)toggleIdentifier;
- (void)applyState:(BOOL)newState forToggleIdentifier:(NSString *)toggleIdentifier;
- (UIImage *)imageForToggleIdentifier:(NSString *)toggleIdentifier withState:(BOOL)state;

@optional
- (NSString *)toggleNameForIdentifier:(NSString *)toggleIdentifier;
@end