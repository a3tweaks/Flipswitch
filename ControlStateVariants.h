#import <UIKit/UIKit.h>

// Used to mask off bits of UIControlState until the closest matching resource is found
// Start with the most specific resource variant and then remove bits until finally the "generic" resource is used
__attribute__((unused))
static UIControlState ControlStateVariantMasks[] = {
	~UIControlStateNormal, // Exact match
	~UIControlStateDisabled,
	~(UIControlStateDisabled | UIControlStateHighlighted),
	~(UIControlStateDisabled | UIControlStateHighlighted | UIControlStateSelected),
	UIControlStateNormal // Generic match
};

static inline NSString *ControlStateVariantApply(NSString *name, UIControlState controlState) {
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
