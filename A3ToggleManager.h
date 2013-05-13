#import <UIKit/UIKit.h>

@protocol A3Toggle;

@interface A3ToggleManager : NSObject

+ (A3ToggleManager *)sharedInstance;

@property (nonatomic, readonly, copy) NSArray *toggleIdentifiers;

- (NSString *)toggleNameForToggleID:(NSString *)toggleID;
- (UIImage *)toggleImageForIdentifier:(NSString *)toggleID withBackground:(UIImage *)backgroundImage overlay:(UIImage *)overlayMask andState:(BOOL)state;

- (BOOL)toggleStateForToggleID:(NSString *)toggleID;
- (void)setToggleState:(BOOL)state onToggleID:(NSString *)toggleID;

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