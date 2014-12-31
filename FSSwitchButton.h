#import <UIKit/UIKit.h>

// Private class. Do not interact with except through the defined API!
__attribute__((visibility("hidden")))
@interface _FSSwitchButton : UIButton {
@private
	NSBundle *template;
	NSString *switchIdentifier;
	BOOL skippingForHold;
	UIImageView *backgroundView;
	UIImage *currentBackgroundImage;
}
- (id)initWithSwitchIdentifier:(NSString *)switchIdentifier_ template:(NSBundle *)template_;
@end
