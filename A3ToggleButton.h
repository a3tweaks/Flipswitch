#import <UIKit/UIKit.h>

__attribute__((visibility("hidden")))
@interface A3ToggleButton : UIButton {
@private
	NSBundle *template;
	NSString *toggleIdentifier;
}
- (id)initWithToggleIdentifier:(NSString *)toggleIdentifier_ template:(NSBundle *)template_;
@end
