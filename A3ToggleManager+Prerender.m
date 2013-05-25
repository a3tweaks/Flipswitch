#import "A3ToggleManager+Prerender.h"

@implementation A3ToggleManager (Prerender)

- (void)prerenderImagesOfToggleState:(A3ToggleState)state controlState:(UIControlState)controlState scale:(CGFloat)scale usingTemplate:(NSBundle *)template toPath:(NSString *)outputPath withFilenameSuffix:(NSString *)suffix
{
	suffix = [NSString stringWithFormat:@"-prerendered%@.png", suffix ?: @""];
	for (NSString *toggleIdentifier in self.toggleIdentifiers) {
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		UIImage *image = [self imageOfToggleState:state controlState:controlState scale:scale forToggleIdentifier:toggleIdentifier usingTemplate:template];
		if (image) {
			NSString *fileName = [outputPath stringByAppendingPathComponent:[toggleIdentifier stringByAppendingString:suffix]];
			[UIImagePNGRepresentation(image) writeToFile:fileName atomically:YES];
		}
		[pool drain];
	}
}

@end
