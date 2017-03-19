#include_next <UIKit/UIKit.h>
extern UIApplication *UIApp;

@class SBSApplicationShortcutItem;

@interface UIHandleApplicationShortcutAction : NSObject
- (id)initWithSBSShortcutItem:(SBSApplicationShortcutItem *)shortcutItem;
@end
