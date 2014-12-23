#import <UIKit/UIKit.h>

__attribute__((visibility("hidden")))
@interface FSSwitchButton : UIButton {
@private
	NSBundle *template;
	NSString *switchIdentifier;
	BOOL skippingForHold;
	UIImageView *backgroundView;
	UIImage *currentBackgroundImage;
}
- (id)initWithSwitchIdentifier:(NSString *)switchIdentifier_ template:(NSBundle *)template_;
@end
