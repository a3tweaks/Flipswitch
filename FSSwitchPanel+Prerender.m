#import "FSSwitchPanel+Prerender.h"

@implementation FSSwitchPanel (Prerender)

- (void)prerenderImagesOfSwitchState:(FSSwitchState)state controlState:(UIControlState)controlState scale:(CGFloat)scale usingTemplate:(NSBundle *)template toPath:(NSString *)outputPath withFilenameSuffix:(NSString *)suffix
{
	suffix = [NSString stringWithFormat:@"-prerendered%@.png", suffix ?: @""];
	for (NSString *switchIdentifier in self.switchIdentifiers) {
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		UIImage *image = [self imageOfSwitchState:state controlState:controlState scale:scale forSwitchIdentifier:switchIdentifier usingTemplate:template];
		if (image) {
			NSString *fileName = [outputPath stringByAppendingPathComponent:[switchIdentifier stringByAppendingString:suffix]];
			[UIImagePNGRepresentation(image) writeToFile:fileName atomically:YES];
		}
		[pool drain];
	}
}

@end
