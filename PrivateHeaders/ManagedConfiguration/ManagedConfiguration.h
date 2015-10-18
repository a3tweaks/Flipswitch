#import <Foundation/Foundation.h>

@interface MCProfileConnection : NSObject
+ (MCProfileConnection *)sharedConnection;
- (void)setValue:(id)value forSetting:(id)setting;
- (id)effectiveParametersForValueSetting:(id)setting;
@end
