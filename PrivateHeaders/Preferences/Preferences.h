#import <UIKit/UIKit.h>

@interface PSRootController : UIViewController
- (instancetype)initWithTitle:(NSString *)title identifier:(NSString *)identifier;
@end

@interface PSListController : UIViewController
- (instancetype)initForContentSize:(CGSize)contentSize;
@property (nonatomic, retain) PSRootController *rootController;
@property (nonatomic, retain) UIViewController *parentController;
@end

typedef enum PSCellType {
	PSGroupCell,
	PSLinkCell,
	PSLinkListCell,
	PSListItemCell,
	PSTitleValueCell,
	PSSliderCell,
	PSSwitchCell,
	PSStaticTextCell,
	PSEditTextCell,
	PSSegmentCell,
	PSGiantIconCell,
	PSGiantCell,
	PSSecureEditTextCell,
	PSButtonCell,
	PSEditTextViewCell,
} PSCellType;

@interface PSSpecifier : NSObject
+ (instancetype)preferenceSpecifierNamed:(NSString *)name target:(id)target set:(SEL)setter get:(SEL)getter detail:(Class)detailClass cell:(PSCellType)cellType edit:(Class)editClass;
@end

@interface WirelessModemController : PSListController {
}
- (id)internetTethering:(PSSpecifier *)specifier;
- (void)setInternetTethering:(id)value specifier:(PSSpecifier *)specifier;
@end

@interface VPNBundleController : PSListController {
@private
	PSSpecifier *_vpnSpecifier;
}
- (id)initWithParentListController:(PSListController *)parentListController;
- (id)vpnActiveForSpecifier:(PSSpecifier *)specifier;
- (void)_setVPNActive:(BOOL)active;
- (NSArray *)specifiersWithSpecifier:(PSSpecifier *)specifier;
- (void)initSC;
@end

@interface VPNBundleController (iOS9)
- (void)setVPNActive:(BOOL)active;
@end
