#import "FSSwitchPanel.h"
#import "FSSwitchMainPanel.h"
#import "FSSwitchService.h"
#import "FSSwitch.h"
#import "NSBundle+Flipswitch.h"
#import "FSSwitchButton.h"
#import "ControlStateVariants.h"

#import <dlfcn.h>
#import <UIKit/UIKit2.h>
#import "LightMessaging/LightMessaging.h"

static LMConnection connection = {
	MACH_PORT_NULL,
	kFSSwitchServiceName
};

NSString * const FSSwitchPanelSwitchsChangedNotification = @"FSSwitchPanelSwitchsChangedNotification";

NSString * const FSSwitchPanelSwitchStateChangedNotification = @"FSSwitchPanelSwitchStateChangedNotification";
NSString * const FSSwitchPanelSwitchIdentifierKey = @"switchIdentifier";


static FSSwitchPanel *_switchManager;
static NSMutableDictionary *_cachedSwitchImages;

@implementation FSSwitchPanel

static void SwitchsChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	[[NSNotificationCenter defaultCenter] postNotificationName:FSSwitchPanelSwitchsChangedNotification object:_switchManager userInfo:nil];
}

+ (void)initialize
{
	if (self == [FSSwitchPanel class]) {
		if (objc_getClass("SpringBoard")) {
			_switchManager = [[FSSwitchMainPanel alloc] init];
		} else {
			_switchManager = [[self alloc] init];
			CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), self, SwitchsChangedCallback, (CFStringRef)FSSwitchPanelSwitchsChangedNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
		}
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
	}
}

+ (void)_didReceiveMemoryWarning
{
	[_cachedSwitchImages release];
	_cachedSwitchImages = nil;
}

+ (FSSwitchPanel *)sharedPanel
{
    return _switchManager;
}

- (NSArray *)switchIdentifiers
{
	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWay(&connection, FSSwitchServiceMessageGetIdentifiers, NULL, 0, &responseBuffer)) {
		return nil;
	}
	return LMResponseConsumePropertyList(&responseBuffer);
}

- (NSString *)titleForSwitchIdentifier:(NSString *)switchIdentifier
{
	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWayPropertyList(&connection, FSSwitchServiceMessageGetTitleForIdentifier, switchIdentifier, &responseBuffer)) {
		return nil;
	}
	return LMResponseConsumePropertyList(&responseBuffer);
}

- (BOOL)shouldShowSwitchIdentifier:(NSString *)switchIdentifier
{
	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWayPropertyList(&connection, FSSwitchServiceMessageShouldSwitchBeShown, switchIdentifier, &responseBuffer)) {
		return NO;
	}
	return LMResponseConsumeInteger(&responseBuffer);
}

- (id)glyphImageDescriptorOfState:(FSSwitchState)switchState size:(CGFloat)size scale:(CGFloat)scale forSwitchIdentifier:(NSString *)switchIdentifier
{
 	NSDictionary *args = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:switchIdentifier, [NSNumber numberWithFloat:size], [NSNumber numberWithFloat:scale], [NSNumber numberWithInteger:switchState], nil] forKeys:[NSArray arrayWithObjects:@"switchIdentifier", @"size", @"scale", @"switchState", nil]];

	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWayPropertyList(&connection, FSSwitchServiceMessageGetImageDescriptorForSwitch, args, &responseBuffer)) {
		return nil;
	}
	return LMResponseConsumePropertyList(&responseBuffer);
}

static UIColor *ColorWithHexString(NSString *stringToConvert)
{
	NSString *noHashString = [stringToConvert stringByReplacingOccurrencesOfString:@"#" withString:@""]; // remove the #
	NSScanner *scanner = [NSScanner scannerWithString:noHashString];
	[scanner setCharactersToBeSkipped:[NSCharacterSet symbolCharacterSet]]; // remove + and $

	unsigned hex;
	if (![scanner scanHexInt:&hex]) return nil;
	int r = (hex >> 16) & 0xFF;
	int g = (hex >> 8) & 0xFF;
	int b = (hex) & 0xFF;

	return [UIColor colorWithRed:r / 255.0f green:g / 255.0f blue:b / 255.0f alpha:1.0f];
}

- (void)drawGlyphImageDescriptor:(id)descriptor toSize:(CGFloat)glyphSize atPosition:(CGPoint)position color:(CGColorRef)color blur:(CGFloat)blur inContext:(CGContextRef)context ofSize:(CGSize)contextSize
{
	CGContextTranslateCTM(context, position.x, position.y);
	if ([descriptor isKindOfClass:[NSString class]]) {
		UIImage *image;
		if ([descriptor hasSuffix:@".pdf"]) {
			CGPDFDocumentRef pdf = CGPDFDocumentCreateWithURL((CFURLRef)[NSURL fileURLWithPath:descriptor]);
			if (pdf) {
				CGContextTranslateCTM(context, 0.0f, contextSize.height);
				CGContextScaleCTM(context, 1.0f, -1.0f);
				CGContextTranslateCTM(context, 0, -glyphSize);
				CGPDFPageRef firstPage = CGPDFDocumentGetPage(pdf, 1);
				CGRect rect = CGPDFPageGetBoxRect(firstPage, kCGPDFCropBox);
				CGFloat scale = rect.size.height / glyphSize;
				CGContextScaleCTM(context, glyphSize / rect.size.width, glyphSize / rect.size.height);
				CGContextTranslateCTM(context, -rect.origin.x, -rect.origin.y);
				// Shadows are always in the current CTM. whiskey. tango. foxtrot.
				CGContextSetShadowWithColor(context, CGSizeMake(0.0f, contextSize.height * scale), blur * scale, color);
				CGContextDrawPDFPage(context, firstPage);
				CGPDFDocumentRelease(pdf);
			}
		} else if ((image = [UIImage imageWithContentsOfFile:descriptor])) {
			descriptor = image;
		}
	}
	if ([descriptor isKindOfClass:[UIImage class]]) {
		CGContextSetShadowWithColor(context, CGSizeMake(0.0f, contextSize.height), blur, color);
		CGContextTranslateCTM(context, 0.0f, -contextSize.height);
		[descriptor drawInRect:CGRectMake(0.0f, 0.0f, glyphSize, glyphSize)];
	}
}

- (id)_layersKeyForSwitchState:(FSSwitchState)state controlState:(UIControlState)controlState usingTemplate:(NSBundle *)template layers:(NSArray **)outLayers
{
	NSString *stateName = [@"layers-" stringByAppendingString:NSStringFromFSSwitchState(state)];
	for (size_t i = 0; i < sizeof(ControlStateVariantMasks) / sizeof(*ControlStateVariantMasks); i++) {
		UIControlState newState = controlState & ControlStateVariantMasks[i];
		NSString *key = ControlStateVariantApply(stateName, newState);
		NSArray *layers = [template objectForInfoDictionaryKey:key];
		if (layers) {
			if (outLayers)
				*outLayers = layers;
			return key;
		}
	}
	for (size_t i = 0; i < sizeof(ControlStateVariantMasks) / sizeof(*ControlStateVariantMasks); i++) {
		UIControlState newState = controlState & ControlStateVariantMasks[i];
		NSString *key = ControlStateVariantApply(@"layers", newState);
		NSArray *layers = [template objectForInfoDictionaryKey:key];
		if (layers) {
			if (outLayers)
				*outLayers = layers;
			return key;
		}
	}
	return nil;
}

- (id)_cacheKeyForSwitchState:(FSSwitchState)state controlState:(UIControlState)controlState scale:(CGFloat)scale forSwitchIdentifier:(NSString *)switchIdentifier usingTemplate:(NSBundle *)template layers:(NSArray **)outLayers prerenderedFileName:(NSString **)outImageFileName
{
	NSString *imagePath = [template imagePathForFlipswitchImageName:[switchIdentifier stringByAppendingFormat:@"-prerendered-%@", NSStringFromFSSwitchState(state)] imageSize:0 preferredScale:scale controlState:controlState inDirectory:nil];
	if (!imagePath)
		imagePath = [template imagePathForFlipswitchImageName:[switchIdentifier stringByAppendingString:@"-prerendered"] imageSize:0 preferredScale:scale controlState:controlState inDirectory:nil];
	if (imagePath) {
		if (outLayers)
			*outLayers = nil;
		if (outImageFileName)
			*outImageFileName = imagePath;
		return imagePath;
	}
	NSArray *layers;
	NSString *layersKey = [self _layersKeyForSwitchState:state controlState:controlState usingTemplate:template layers:&layers];
	if (!layersKey)
		return nil;
	NSMutableArray *keys = [[NSMutableArray alloc] initWithObjects:template.bundlePath, [NSNumber numberWithFloat:scale], layersKey, nil];
	for (NSDictionary *layer in layers) {
		NSString *type = [layer objectForKey:@"type"];
		if (!type || [type isEqualToString:@"image"]) {
			NSString *fileName = [layer objectForKey:@"fileName"];
			if (fileName) {
				NSString *fullPath = [template imagePathForFlipswitchImageName:fileName imageSize:0 preferredScale:scale controlState:controlState inDirectory:nil];
				[keys addObject:fullPath ?: @""];
			}
		} else if ([type isEqualToString:@"glyph"]) {
			CGFloat glyphSize = [[layer objectForKey:@"size"] floatValue];
			id descriptor = [self glyphImageDescriptorOfState:state size:glyphSize scale:scale forSwitchIdentifier:switchIdentifier];
			[keys addObject:descriptor ?: @""];
			NSString *fileName = [layer objectForKey:@"fileName"];
			if (fileName) {
				NSString *fullPath = [template imagePathForFlipswitchImageName:fileName imageSize:0 preferredScale:scale controlState:controlState inDirectory:nil];
				[keys addObject:fullPath ?: @""];
			}
		}
	}
	if (outLayers)
		*outLayers = layers;
	if (outImageFileName)
		*outImageFileName = nil;
	NSArray *result = [keys copy];
	[keys release];
	return [result autorelease];
}

- (UIImage *)imageOfSwitchState:(FSSwitchState)state controlState:(UIControlState)controlState scale:(CGFloat)scale forSwitchIdentifier:(NSString *)switchIdentifier usingTemplate:(NSBundle *)template
{
	CGSize size;
	size.width = [[template objectForInfoDictionaryKey:@"width"] floatValue];
	if (size.width == 0.0f)
		return nil;
	size.height = [[template objectForInfoDictionaryKey:@"height"] floatValue];
	if (size.height == 0.0f)
		return nil;
	NSArray *layers;
	NSString *prerenderedImageName;
	id cacheKey = [self _cacheKeyForSwitchState:state controlState:controlState scale:scale forSwitchIdentifier:switchIdentifier usingTemplate:template layers:&layers prerenderedFileName:&prerenderedImageName];
	if (!cacheKey)
		return nil;
	UIImage *result = [_cachedSwitchImages objectForKey:cacheKey];
	if (result)
		return result;
	if (prerenderedImageName) {
		result = [UIImage imageWithContentsOfFile:cacheKey];
		goto cache_and_return_result;
	}
	if (&UIGraphicsBeginImageContextWithOptions != NULL) {
		UIGraphicsBeginImageContextWithOptions(size, NO, scale);
	} else {
		UIGraphicsBeginImageContext(size);
		scale = 1.0f;
	}
	size_t maskWidth = size.width * scale;
	size_t maskHeight = size.height * scale * 2;
	void *maskData = NULL;
	void *secondMaskData = NULL;
	CGContextRef context = UIGraphicsGetCurrentContext();
	for (NSDictionary *layer in layers) {
		CGContextSaveGState(context);
		id temp = [layer objectForKey:@"opacity"];
		CGFloat alpha = temp ? [temp floatValue] : 1.0f;
		CGPoint position = CGPointMake([[layer objectForKey:@"x"] floatValue], [[layer objectForKey:@"y"] floatValue]);
		NSString *type = [layer objectForKey:@"type"];
		if (!type || [type isEqualToString:@"image"]) {
			NSString *fileName = [layer objectForKey:@"fileName"];
			if (fileName) {
				NSString *fullPath = [template imagePathForFlipswitchImageName:fileName imageSize:0 preferredScale:scale controlState:controlState inDirectory:nil];
				UIImage *image = [UIImage imageWithContentsOfFile:fullPath];
				[image drawAtPoint:position blendMode:kCGBlendModeNormal alpha:alpha];
			}
		} else if ([type isEqualToString:@"glyph"]) {
			CGContextSetAlpha(context, alpha);
			CGFloat blur = [[layer objectForKey:@"blur"] floatValue];
			CGFloat glyphSize = [[layer objectForKey:@"size"] floatValue];
			id descriptor = [self glyphImageDescriptorOfState:state size:glyphSize scale:scale forSwitchIdentifier:switchIdentifier];
			NSString *fileName = [layer objectForKey:@"fileName"];
			BOOL hasCutout = [[layer objectForKey:@"cutout"] boolValue];
			if (hasCutout) {
				CGFloat cutoutX = [[layer objectForKey:@"cutoutX"] floatValue];
				CGFloat cutoutY = [[layer objectForKey:@"cutoutY"] floatValue];
				CGFloat cutoutBlur = [[layer objectForKey:@"cutoutBlur"] floatValue];
				if (!maskData)
					maskData = malloc(maskWidth * maskHeight);
				memset(maskData, '\0', maskWidth * maskHeight);
				CGContextRef maskContext = CGBitmapContextCreate(maskData, maskWidth, maskHeight, 8, maskWidth, NULL, kCGImageAlphaOnly);
				CGContextScaleCTM(maskContext, scale, scale);
				CGContextSetBlendMode(maskContext, kCGBlendModeCopy);
				[self drawGlyphImageDescriptor:descriptor toSize:glyphSize atPosition:CGPointMake(position.x + cutoutX, position.y + cutoutY) color:[UIColor whiteColor].CGColor blur:cutoutBlur inContext:maskContext ofSize:size];
				CGContextRelease(maskContext);
				CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData((CFDataRef)[NSData dataWithBytesNoCopy:maskData length:maskWidth * maskHeight freeWhenDone:NO]);
				CGImageRef maskImage = CGImageMaskCreate(maskWidth, maskHeight, 8, 8, maskWidth, dataProvider, NULL, TRUE);
				CGDataProviderRelease(dataProvider);
				CGContextClipToMask(context, CGRectMake(0.0f, 0.0f, size.width, size.height + size.height), maskImage);
				CGImageRelease(maskImage);
			}
			UIImage *image;
			if (fileName && (image = [UIImage imageWithContentsOfFile:[template imagePathForFlipswitchImageName:fileName imageSize:0 preferredScale:scale controlState:controlState inDirectory:nil]])) {
				// Slow path to draw an image
				void *localMaskData;
				if (hasCutout) {
					if (!secondMaskData)
						secondMaskData = malloc(maskWidth * maskHeight);
					localMaskData = secondMaskData;
				} else {
					// Reuse a single buffer if possible
					if (!maskData)
						maskData = malloc(maskWidth * maskHeight);
					localMaskData = maskData;
				}
				memset(localMaskData, '\0', maskWidth * maskHeight);
				CGContextRef maskContext = CGBitmapContextCreate(localMaskData, maskWidth, maskHeight, 8, maskWidth, NULL, kCGImageAlphaOnly);
				CGContextSetBlendMode(maskContext, kCGBlendModeCopy);
				CGContextScaleCTM(maskContext, scale, scale);
				[self drawGlyphImageDescriptor:descriptor toSize:glyphSize atPosition:position color:[UIColor whiteColor].CGColor blur:blur inContext:maskContext ofSize:size];
				CGImageRef maskImage = CGBitmapContextCreateImage(maskContext);
				CGContextRelease(maskContext);
				CGContextClipToMask(context, CGRectMake(0.0f, 0.0f, size.width, size.height + size.height), maskImage);
				CGImageRelease(maskImage);
				[image drawInRect:CGRectMake(position.x - blur, position.y - blur, glyphSize + blur + blur, glyphSize + blur + blur)];
			} else {
				// Fast path for a solid color
				CGColorRef color = (ColorWithHexString([layer objectForKey:@"color"]) ?: [UIColor blackColor]).CGColor;
				[self drawGlyphImageDescriptor:descriptor toSize:glyphSize atPosition:position color:color blur:blur inContext:context ofSize:size];
			}
		}
		CGContextRestoreGState(context);
	}
	result = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	if (maskData)
		free(maskData);
	if (secondMaskData)
		free(secondMaskData);
cache_and_return_result:
	if (result) {
		if (!_cachedSwitchImages)
			_cachedSwitchImages = [[NSMutableDictionary alloc] init];
		[_cachedSwitchImages setObject:result forKey:cacheKey];
	}
	return result;
}

- (UIImage *)imageOfSwitchState:(FSSwitchState)state controlState:(UIControlState)controlState forSwitchIdentifier:(NSString *)switchIdentifier usingTemplate:(NSBundle *)template
{
	CGFloat scale = [UIScreen instancesRespondToSelector:@selector(scale)] ? [UIScreen mainScreen].scale : 1.0f;
	return [self imageOfSwitchState:state controlState:controlState scale:scale forSwitchIdentifier:switchIdentifier usingTemplate:template];
}

- (UIButton *)buttonForSwitchIdentifier:(NSString *)switchIdentifier usingTemplate:(NSBundle *)template
{
	return [[[FSSwitchButton alloc] initWithSwitchIdentifier:switchIdentifier template:template] autorelease];
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWayPropertyList(&connection, FSSwitchServiceMessageGetStateForIdentifier, switchIdentifier, &responseBuffer)) {
		return NO;
	}
	return LMResponseConsumeInteger(&responseBuffer);
}

- (void)applyActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	LMConnectionSendOneWayData(&connection, FSSwitchServiceMessageApplyActionForIdentifier, (CFDataRef)[NSPropertyListSerialization dataFromPropertyList:switchIdentifier format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL]);
}

- (void)setState:(FSSwitchState)state forSwitchIdentifier:(NSString *)switchIdentifier
{
	NSArray *propertyList = [NSArray arrayWithObjects:[NSNumber numberWithBool:state], switchIdentifier, nil];
	LMConnectionSendOneWayData(&connection, FSSwitchServiceMessageSetStateForIdentifier, (CFDataRef)[NSPropertyListSerialization dataFromPropertyList:propertyList format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL]);
}


- (BOOL)hasAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWayPropertyList(&connection, FSSwitchServiceMessageHasAlternateActionForIdentifier, switchIdentifier, &responseBuffer)) {
		return NO;
	}
	return LMResponseConsumeInteger(&responseBuffer);
}

- (void)applyAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	LMConnectionSendOneWayData(&connection, FSSwitchServiceMessageApplyAlternateActionForIdentifier, (CFDataRef)[NSPropertyListSerialization dataFromPropertyList:switchIdentifier format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL]);
}

- (void)openURLAsAlternateAction:(NSURL *)url
{
	[[UIApplication sharedApplication] openURL:url];
}

@end

@implementation FSSwitchPanel (SpringBoard)

- (void)registerSwitch:(id<FSSwitch>)switchImplementation forIdentifier:(NSString *)switchIdentifier
{
	[NSException raise:NSInternalInconsistencyException format:@"Cannot register switchs outside of SpringBoard!"];
}

- (void)unregisterSwitchIdentifier:(NSString *)switchIdentifier;
{
	[NSException raise:NSInternalInconsistencyException format:@"Cannot unregister switchs outside of SpringBoard!"];
}

- (void)stateDidChangeForSwitchIdentifier:(NSString *)switchIdentifier
{
	[NSException raise:NSInternalInconsistencyException format:@"Cannot update switch state from outside of SpringBoard!"];
}

@end

