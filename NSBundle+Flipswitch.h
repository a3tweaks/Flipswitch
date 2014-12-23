#import <UIKit/UIKit.h>
#import "FSSwitchState.h"

#import <CommonCrypto/CommonDigest.h>

static inline NSString *MD5OfData(NSData *data)
{
	unsigned char digest[16];
	CC_MD5((unsigned char *)data.bytes, data.length, digest);
	return [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
		digest[0], digest[1], digest[2], digest[3],
		digest[4], digest[5], digest[6], digest[7],
		digest[8], digest[9], digest[10], digest[11],
		digest[12], digest[13], digest[14], digest[15]
	];
}

@interface NSBundle (Flipswitch)
@property (nonatomic, readonly) NSBundle *flipswitchThemedBundle;
@property (nonatomic, readonly) NSDictionary *flipswitchThemedInfoDictionary;
@property (nonatomic, readonly) NSString *flipswitchImageCacheBasePath;

- (NSUInteger)imageSizeForFlipswitchImageName:(NSString *)glyphName closestToSize:(CGFloat)sourceSize inDirectory:(NSString *)directory;

- (NSString *)imagePathForFlipswitchImageName:(NSString *)imageName imageSize:(NSUInteger)imageSize preferredScale:(CGFloat)preferredScale controlState:(UIControlState)controlState inDirectory:(NSString *)directory;
- (NSString *)imagePathForFlipswitchImageName:(NSString *)imageName imageSize:(NSUInteger)imageSize preferredScale:(CGFloat)preferredScale controlState:(UIControlState)controlState inDirectory:(NSString *)directory loadedControlState:(UIControlState *)outImageControlState;

- (id)objectForResolvedInfoDictionaryKey:(NSString *)name withLayerSet:(NSString *)layerSet switchState:(FSSwitchState)state controlState:(UIControlState)controlState resolvedKeyName:(NSString **)outKeyName;
@end
