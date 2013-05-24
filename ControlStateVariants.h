#import <UIKit/UIKit.h>

static inline NSString *ApplyControlStateVariantToName(NSString *name, UIControlState controlState) {
	if (!controlState)
		return name;
	NSMutableString *result = [[name mutableCopy] autorelease];
	if (controlState & UIControlStateSelected)
		[result appendString:@"-selected"];
	if (controlState & UIControlStateHighlighted)
		[result appendString:@"-down"];
	if (controlState & UIControlStateDisabled)
		[result appendString:@"-disabled"];
	return result;
}
