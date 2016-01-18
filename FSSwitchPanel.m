#import "FSSwitchPanel+Internal.h"
#import "FSSwitchMainPanel.h"
#import "FSSwitchService.h"
#import "FSSwitchDataSource.h"
#import "NSBundle+Flipswitch.h"
#import "FSSwitchButton.h"
#import "ControlStateVariants.h"
#import "Internal.h"
#import "ModifiedTime.h"

#import <dlfcn.h>
#import <sys/stat.h>
#import <unistd.h>
#import <sys/mman.h>
#import <objc/message.h>
#import <UIKit/UIKit.h>
#import <libkern/OSAtomic.h>
#import <QuartzCore/QuartzCore.h>
#import <sys/types.h>
#import <fcntl.h>
#import <CoreFoundation/CFUserNotification.h>

#define ROCKETBOOTSTRAP_LOAD_DYNAMIC
#import "LightMessaging/LightMessaging.h"

static LMConnection connection = {
	MACH_PORT_NULL,
	kFSSwitchServiceName
};

NSString * const FSSwitchPanelSwitchesChangedNotification = @"FSSwitchPanelSwitchesChangedNotification";

NSString * const FSSwitchPanelSwitchStateChangedNotification = @"FSSwitchPanelSwitchStateChangedNotification";
NSString * const FSSwitchPanelSwitchIdentifierKey = @"switchIdentifier";

NSString * const FSSwitchPanelSwitchWillOpenURLNotification = @"FSSwitchPanelSwitchWillOpenURLNotification";


static FSSwitchPanel *_switchManager;
static NSMutableDictionary *_cachedSwitchImages;
static volatile OSSpinLock _lock;
static long int _pageSize;
static NSMutableDictionary *_fileDescriptors;

static BOOL scaleIsSupported(void)
{
	return [UIImage respondsToSelector:@selector(imageWithCGImage:scale:orientation:)];
}

@implementation FSSwitchPanel

static UIImage *FlipSwitchUnmappedImageWithContentsOfFile(NSString *filePath, CGFloat requestedScale)
{
	if (!scaleIsSupported() || (requestedScale == [UIScreen mainScreen].scale)) {
		return [UIImage imageWithContentsOfFile:filePath];
	}
	CGFloat scale = 1.0f;
	NSString *strippedFileName = [[filePath lastPathComponent] stringByDeletingPathExtension];
	if ([strippedFileName hasSuffix:@"x"]) {
		NSRange entireRange = NSMakeRange(0, [strippedFileName length]);
		NSRange range = [strippedFileName rangeOfString:@"@" options:NSBackwardsSearch | NSLiteralSearch range:entireRange];
		if (range.location != NSNotFound) {
			range.location += 1;
			range.length = entireRange.length - 1 - range.location;
			scale = [[strippedFileName substringWithRange:range] floatValue] ?: 1.0f;
		}
	}
	UIImage *result = [UIImage imageWithData:[NSData dataWithContentsOfFile:filePath]];
	if (result) {
		result = [UIImage imageWithCGImage:result.CGImage scale:scale orientation:result.imageOrientation];
	}
	return result;
}

static void SwitchesChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	[[NSNotificationCenter defaultCenter] postNotificationName:FSSwitchPanelSwitchesChangedNotification object:_switchManager userInfo:nil];
}

static void SwitchStateChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	NSDictionary *newUserInfo;
	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWay(&connection, FSSwitchServiceMessageGetPendingNotificationUserInfo, NULL, 0, &responseBuffer))
		newUserInfo = nil;
	else
		newUserInfo = LMResponseConsumePropertyList(&responseBuffer);
	[[NSNotificationCenter defaultCenter] postNotificationName:FSSwitchPanelSwitchStateChangedNotification object:_switchManager userInfo:newUserInfo];
}

static void WillOpenURLCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	NSDictionary *newUserInfo;
	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWay(&connection, FSSwitchServiceMessageGetPendingNotificationUserInfo, NULL, 0, &responseBuffer))
		newUserInfo = nil;
	else
		newUserInfo = LMResponseConsumePropertyList(&responseBuffer);
	[[NSNotificationCenter defaultCenter] postNotificationName:FSSwitchPanelSwitchWillOpenURLNotification object:_switchManager userInfo:newUserInfo];
}

__attribute__((constructor))
static void constructor(void)
{
	if (objc_getClass("SpringBoard")) {
		dlopen("/Library/Flipswitch/libFlipswitchSpringBoard.dylib", RTLD_LAZY);
	}
}

+ (void)initialize
{
	if (self == [FSSwitchPanel class]) {
		if (objc_getClass("SpringBoard")) {
			FSSwitchMainPanel *mainPanel = [[objc_getClass("FSSwitchMainPanel") alloc] init];
			_switchManager = mainPanel;
			if ([NSThread isMainThread]) {
				[mainPanel _loadBuiltInSwitches];
			} else {
				[mainPanel performSelectorOnMainThread:@selector(_loadBuiltInSwitches) withObject:nil waitUntilDone:NO];
			}
		} else {
			_switchManager = [[self alloc] init];
			CFNotificationCenterRef darwin = CFNotificationCenterGetDarwinNotifyCenter();
			CFNotificationCenterAddObserver(darwin, self, SwitchesChangedCallback, (CFStringRef)FSSwitchPanelSwitchesChangedNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
			CFNotificationCenterAddObserver(darwin, self, SwitchStateChangedCallback, (CFStringRef)FSSwitchPanelSwitchStateChangedNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
			CFNotificationCenterAddObserver(darwin, self, WillOpenURLCallback, (CFStringRef)FSSwitchPanelSwitchWillOpenURLNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
		}
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
	}
}

#ifdef DEBUG

+ (NSDictionary *)fileDescriptors
{
	OSSpinLockLock(&_lock);
	NSDictionary *fileDescriptors = [_fileDescriptors copy];
	OSSpinLockUnlock(&_lock);
	return [fileDescriptors autorelease];
}

#endif

+ (void)_didReceiveMemoryWarning
{
	OSSpinLockLock(&_lock);
	NSDictionary *cachedSwitchImages = _cachedSwitchImages;
	_cachedSwitchImages = nil;
	NSDictionary *fileDescriptors = _fileDescriptors;
	_fileDescriptors = nil;
	OSSpinLockUnlock(&_lock);
	[cachedSwitchImages release];
	for (NSNumber *number in [fileDescriptors allValues]) {
		close([number intValue]);
	}
	[fileDescriptors release];
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

static NSInteger DictionaryTextComparator(id a, id b, void *context)
{
	return [[(NSDictionary *)context objectForKey:a] localizedCaseInsensitiveCompare:[(NSDictionary *)context objectForKey:b]];
}

- (NSArray *)sortedSwitchIdentifiers
{
	NSMutableArray *switchIdentifiers = [[self.switchIdentifiers mutableCopy] autorelease];
	if (!switchIdentifiers) {
		return nil;
	}
	NSMutableDictionary *titles = [NSMutableDictionary dictionary];
	for (NSString *identifier in switchIdentifiers) {
		[titles setObject:[self titleForSwitchIdentifier:identifier] ?: @"" forKey:identifier];
	}
	[switchIdentifiers sortUsingFunction:DictionaryTextComparator context:titles];
	return switchIdentifiers;
}

- (NSString *)titleForSwitchIdentifier:(NSString *)switchIdentifier
{
	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWayPropertyList(&connection, FSSwitchServiceMessageGetTitleForIdentifier, switchIdentifier, &responseBuffer)) {
		return nil;
	}
	return LMResponseConsumePropertyList(&responseBuffer);
}

- (id)glyphImageDescriptorOfState:(FSSwitchState)switchState variant:(NSString *)variant size:(CGFloat)size scale:(CGFloat)scale forSwitchIdentifier:(NSString *)switchIdentifier
{
 	NSDictionary *args = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:switchIdentifier, [NSNumber numberWithFloat:size], [NSNumber numberWithFloat:scale], [NSNumber numberWithInteger:switchState], variant, nil] forKeys:[NSArray arrayWithObjects:@"switchIdentifier", @"size", @"scale", @"switchState", variant ? @"variant" : nil, nil]];

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

- (void)drawGlyphImageDescriptor:(id)descriptor toSize:(CGFloat)glyphSize atPosition:(CGPoint)position color:(CGColorRef)color blur:(CGFloat)blur inContext:(CGContextRef)context ofSize:(CGSize)contextSize scale:(CGFloat)scale
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
		} else if ((image = FlipSwitchUnmappedImageWithContentsOfFile(descriptor, scale))) {
			descriptor = image;
		}
	}
	if ([descriptor isKindOfClass:[UIImage class]]) {
		CGSize shadowOffset = CGSizeApplyAffineTransform(CGSizeMake(0.0f, contextSize.height), CGContextGetCTM(context));
		CGContextSetShadowWithColor(context, shadowOffset, blur, color);
		CGContextTranslateCTM(context, 0.0f, -contextSize.height);
		UIGraphicsPushContext(context);
		[descriptor drawInRect:CGRectMake(0.0f, 0.0f, glyphSize, glyphSize)];
		UIGraphicsPopContext();
	}
}

- (id)_layersKeyForSwitchState:(FSSwitchState)state controlState:(UIControlState)controlState usingLayerSet:(NSString *)layerSet inTemplate:(NSBundle *)template layers:(NSArray **)outLayers
{
	NSString *keyName = nil;
	id layers = [template objectForResolvedInfoDictionaryKey:@"layers" withLayerSet:layerSet switchState:state controlState:controlState resolvedKeyName:&keyName];
	if (outLayers)
		*outLayers = layers;
	return keyName;
}

- (NSString *)_glyphImageDescriptorOfState:(FSSwitchState)switchState variant:(NSString *)variant size:(CGFloat)size scale:(CGFloat)scale forSwitchIdentifier:(NSString *)switchIdentifier usingTemplate:(NSBundle *)template
{
	NSString *imageName;
	// Try {switch}-glyph-{state}
	imageName = [switchIdentifier stringByAppendingFormat:@"-glyph-%@", NSStringFromFSSwitchState(switchState)];
	NSUInteger closestSize;
	closestSize = [template imageSizeForFlipswitchImageName:imageName closestToSize:size inDirectory:nil];
	if (closestSize != NSNotFound)
		return [template imagePathForFlipswitchImageName:imageName imageSize:closestSize preferredScale:scale controlState:UIControlStateNormal inDirectory:nil];
	// Try {switch}-glyph
	imageName = [switchIdentifier stringByAppendingString:@"-glyph"];
	closestSize = [template imageSizeForFlipswitchImageName:imageName closestToSize:size inDirectory:nil];
	if (closestSize != NSNotFound)
		return [template imagePathForFlipswitchImageName:imageName imageSize:closestSize preferredScale:scale controlState:UIControlStateNormal inDirectory:nil];
	// Fallback from bundle
	return [self glyphImageDescriptorOfState:switchState variant:variant size:size scale:scale forSwitchIdentifier:switchIdentifier];
}

- (NSString *)_cacheKeyForSwitchState:(FSSwitchState)state controlState:(UIControlState)controlState scale:(CGFloat)scale forSwitchIdentifier:(NSString *)switchIdentifier usingLayerSet:(NSString *)layerSet inTemplate:(NSBundle *)template layers:(NSArray **)outLayers prerenderedFileName:(NSString **)outImageFileName
{
	NSString *prefix = layerSet ? [layerSet stringByAppendingFormat:@"-%@", switchIdentifier] : switchIdentifier;
	NSString *imagePath = [template imagePathForFlipswitchImageName:[prefix stringByAppendingFormat:@"-prerendered-%@", NSStringFromFSSwitchState(state)] imageSize:0 preferredScale:scale controlState:controlState inDirectory:nil];
	if (!imagePath)
		imagePath = [template imagePathForFlipswitchImageName:[prefix stringByAppendingString:@"-prerendered"] imageSize:0 preferredScale:scale controlState:controlState inDirectory:nil];
	if (imagePath) {
		if (outLayers)
			*outLayers = nil;
		if (outImageFileName)
			*outImageFileName = imagePath;
		return imagePath;
	}
	NSArray *layers;
	NSString *layersKey = [self _layersKeyForSwitchState:state controlState:controlState usingLayerSet:layerSet inTemplate:template layers:&layers];
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
			NSString *toggleState = [layer objectForKey:@"state"];
			NSString *variant = [layer objectForKey:@"variant"];
			id descriptor = [self _glyphImageDescriptorOfState:toggleState ? FSSwitchStateFromNSString(toggleState) : state variant:variant size:glyphSize scale:scale forSwitchIdentifier:switchIdentifier usingTemplate:template];
			[keys addObject:descriptor ?: @""];
			NSString *fileName = [layer objectForKey:@"fileName"];
			if (fileName) {
				NSString *fullPath = [template imagePathForFlipswitchImageName:fileName imageSize:0 preferredScale:scale controlState:controlState inDirectory:nil];
				[keys addObject:fullPath ?: @""];
			}
		}
	}
	NSString *renderingMode = [template objectForResolvedInfoDictionaryKey:@"renderingMode" withLayerSet:layerSet switchState:state controlState:controlState resolvedKeyName:NULL];
	if (renderingMode && [UIImage instancesRespondToSelector:@selector(imageWithRenderingMode:)]) {
		[keys addObject:renderingMode];
	}
	if (outLayers)
		*outLayers = layers;
	if (outImageFileName)
		*outImageFileName = nil;
	NSString *result = MD5OfData([NSPropertyListSerialization dataFromPropertyList:keys format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL]);
	[keys release];
	return result;
}

static CGBlendMode CGBlendModeForString(NSString *blendMode)
{
	if (!blendMode || [blendMode isEqual:@"normal"])
		return kCGBlendModeNormal;
	if ([blendMode isEqual:@"multiply"])
		return kCGBlendModeMultiply;
	if ([blendMode isEqual:@"screen"])
		return kCGBlendModeScreen;
	if ([blendMode isEqual:@"overlay"])
		return kCGBlendModeOverlay;
	if ([blendMode isEqual:@"darken"])
		return kCGBlendModeDarken;
	if ([blendMode isEqual:@"lighten"])
		return kCGBlendModeLighten;
	if ([blendMode isEqual:@"color-dodge"])
		return kCGBlendModeColorDodge;
	if ([blendMode isEqual:@"color-burn"])
		return kCGBlendModeColorBurn;
	if ([blendMode isEqual:@"soft-light"])
		return kCGBlendModeSoftLight;
	if ([blendMode isEqual:@"hard-light"])
		return kCGBlendModeHardLight;
	if ([blendMode isEqual:@"difference"])
		return kCGBlendModeDifference;
	if ([blendMode isEqual:@"exclusion"])
		return kCGBlendModeExclusion;
	if ([blendMode isEqual:@"hue"])
		return kCGBlendModeHue;
	if ([blendMode isEqual:@"saturation"])
		return kCGBlendModeSaturation;
	if ([blendMode isEqual:@"color"])
		return kCGBlendModeColor;
	if ([blendMode isEqual:@"luminosity"])
		return kCGBlendModeLuminosity;
	if ([blendMode isEqual:@"clear"])
		return kCGBlendModeClear;
	if ([blendMode isEqual:@"copy"])
		return kCGBlendModeCopy;
	if ([blendMode isEqual:@"source-in"])
		return kCGBlendModeSourceIn;
	if ([blendMode isEqual:@"source-out"])
		return kCGBlendModeSourceOut;
	if ([blendMode isEqual:@"source-atop"])
		return kCGBlendModeSourceAtop;
	if ([blendMode isEqual:@"destination-over"])
		return kCGBlendModeDestinationOver;
	if ([blendMode isEqual:@"destination-in"])
		return kCGBlendModeDestinationIn;
	if ([blendMode isEqual:@"destination-out"])
		return kCGBlendModeDestinationOut;
	if ([blendMode isEqual:@"destination-atop"])
		return kCGBlendModeDestinationAtop;
	if ([blendMode isEqual:@"xor"])
		return kCGBlendModeXOR;
	if ([blendMode isEqual:@"plus-darker"])
		return kCGBlendModePlusDarker;
	if ([blendMode isEqual:@"plus-lighter"])
		return kCGBlendModePlusLighter;
	return kCGBlendModeNormal;
}

#define ALWAYS_USE_SLOW_PATH 1

- (void)_renderImageOfLayers:(NSArray *)layers switchState:(FSSwitchState)state controlState:(UIControlState)controlState size:(CGSize)size scale:(CGFloat)scale forSwitchIdentifier:(NSString *)switchIdentifier usingTemplate:(NSBundle *)template
{
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
		CGBlendMode blendMode = CGBlendModeForString([layer objectForKey:@"blendMode"]);
		if (!type || [type isEqualToString:@"image"]) {
			NSString *fileName = [layer objectForKey:@"fileName"];
			if (fileName) {
				NSString *fullPath = [template imagePathForFlipswitchImageName:fileName imageSize:0 preferredScale:scale controlState:controlState inDirectory:nil];
				UIImage *image = FlipSwitchUnmappedImageWithContentsOfFile(fullPath, scale);
				[image drawAtPoint:position blendMode:blendMode alpha:alpha];
			}
		} else if ([type isEqualToString:@"glyph"]) {
			CGFloat blur = [[layer objectForKey:@"blur"] floatValue];
			CGFloat glyphSize = [[layer objectForKey:@"size"] floatValue];
			NSString *toggleState = [layer objectForKey:@"state"];
			NSString *variant = [layer objectForKey:@"variant"];
			id descriptor = [self _glyphImageDescriptorOfState:toggleState ? FSSwitchStateFromNSString(toggleState) : state variant:variant size:glyphSize scale:scale forSwitchIdentifier:switchIdentifier usingTemplate:template];
			NSString *fileName = [layer objectForKey:@"fileName"];
			BOOL hasCutout = [[layer objectForKey:@"cutout"] boolValue];
			if (hasCutout) {
				CGFloat cutoutX = [[layer objectForKey:@"cutoutX"] floatValue];
				CGFloat cutoutY = [[layer objectForKey:@"cutoutY"] floatValue];
				CGFloat cutoutBlur = [[layer objectForKey:@"cutoutBlur"] floatValue];
				if (!maskData)
					maskData = malloc(maskWidth * maskHeight);
				memset(maskData, '\0', maskWidth * maskHeight);
				CGContextRef maskContext = CGBitmapContextCreate(maskData, maskWidth, maskHeight, 8, maskWidth, NULL, (CGBitmapInfo)kCGImageAlphaOnly);
				CGContextScaleCTM(maskContext, scale, scale);
				CGContextSetBlendMode(maskContext, kCGBlendModeCopy);
				[self drawGlyphImageDescriptor:descriptor toSize:glyphSize atPosition:CGPointMake(position.x + cutoutX, position.y + cutoutY) color:[UIColor whiteColor].CGColor blur:cutoutBlur inContext:maskContext ofSize:size scale:scale];
				CGContextRelease(maskContext);
				CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData((CFDataRef)[NSData dataWithBytesNoCopy:maskData length:maskWidth * maskHeight freeWhenDone:NO]);
				CGImageRef maskImage = CGImageMaskCreate(maskWidth, maskHeight, 8, 8, maskWidth, dataProvider, NULL, TRUE);
				CGDataProviderRelease(dataProvider);
				CGContextClipToMask(context, CGRectMake(0.0f, 0.0f, size.width, size.height + size.height), maskImage);
				CGImageRelease(maskImage);
			}
			UIImage *image = nil;
			if (fileName && (image = FlipSwitchUnmappedImageWithContentsOfFile([template imagePathForFlipswitchImageName:fileName imageSize:0 preferredScale:scale controlState:controlState inDirectory:nil], scale))) {
#if ALWAYS_USE_SLOW_PATH
			}
#endif
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
				CGContextRef maskContext = CGBitmapContextCreate(localMaskData, maskWidth, maskHeight, 8, maskWidth, NULL, (CGBitmapInfo)kCGImageAlphaOnly);
				CGContextSetBlendMode(maskContext, kCGBlendModeCopy);
				CGContextScaleCTM(maskContext, scale, scale);
				[self drawGlyphImageDescriptor:descriptor toSize:glyphSize atPosition:position color:[UIColor whiteColor].CGColor blur:blur inContext:maskContext ofSize:size scale:scale];
				CGImageRef maskImage = CGBitmapContextCreateImage(maskContext);
				CGContextRelease(maskContext);
				CGContextClipToMask(context, CGRectMake(0.0f, 0.0f, size.width, size.height + size.height), maskImage);
				CGImageRelease(maskImage);
				CGRect drawRect = CGRectMake(position.x - blur, position.y - blur, glyphSize + blur + blur, glyphSize + blur + blur);
#if ALWAYS_USE_SLOW_PATH
			if (image) {
#endif
				[image drawInRect:drawRect blendMode:blendMode alpha:alpha];
#if ALWAYS_USE_SLOW_PATH
			} else {
				UIColor *color = [(ColorWithHexString([layer objectForKey:@"color"]) ?: [UIColor blackColor]) colorWithAlphaComponent:alpha];
				[color setFill];
				UIRectFillUsingBlendMode(drawRect, blendMode);
#else
			} else {
				// Fast path for a solid color
				CGColorRef color = [(ColorWithHexString([layer objectForKey:@"color"]) ?: [UIColor blackColor]) colorWithAlphaComponent:alpha].CGColor;
				[self drawGlyphImageDescriptor:descriptor toSize:glyphSize atPosition:position color:color blur:blur inContext:context ofSize:size scale:scale];
#endif
			}
		}
		CGContextRestoreGState(context);
	}
	if (maskData)
		free(maskData);
	if (secondMaskData)
		free(secondMaskData);
}

static uintptr_t ceil_to_page(uintptr_t value)
{
	return ((value + _pageSize - 1) / _pageSize) * _pageSize;
}

static uintptr_t floor_to_page(uintptr_t value)
{
	return (value / _pageSize) * _pageSize;
}

static void FlipSwitchMappingCGDataProviderReleaseDataCallback(void *info, const void *data, size_t size)
{
	munmap(info, ceil_to_page((uintptr_t)data - (uintptr_t)info + size));
}

- (UIImage *)imageOfSwitchState:(FSSwitchState)state controlState:(UIControlState)controlState scale:(CGFloat)scale forSwitchIdentifier:(NSString *)switchIdentifier usingLayerSet:(NSString *)layerSet inTemplate:(NSBundle *)template
{
	NSDictionary *infoDictionary = template.flipswitchThemedInfoDictionary;
	template = [template flipswitchThemedBundle];
	NSArray *layers;
	NSString *prerenderedImageName;
	NSString *cacheKey = [self _cacheKeyForSwitchState:state controlState:controlState scale:scale forSwitchIdentifier:switchIdentifier usingLayerSet:layerSet inTemplate:template layers:&layers prerenderedFileName:&prerenderedImageName];
	if (!cacheKey)
		return nil;
	CGSize size;
	size.width = [[infoDictionary objectForKey:@"width"] floatValue];
	if (size.width == 0.0f)
		return nil;
	size.height = [[infoDictionary objectForKey:@"height"] floatValue];
	if (size.height == 0.0f)
		return nil;
	OSSpinLockLock(&_lock);
	UIImage *result = [[_cachedSwitchImages objectForKey:cacheKey] retain];
	OSSpinLockUnlock(&_lock);
	if (result) {
		return [result autorelease];
	}
	if (prerenderedImageName) {
		result = FlipSwitchUnmappedImageWithContentsOfFile(prerenderedImageName, scale);
		goto cache_and_return_result;
	}
	BOOL supportsScale = scaleIsSupported();
	size_t rawWidth = supportsScale ? (size.width * scale) : size.width;
	size_t rawHeight = supportsScale ? (size.height * scale) : size.height;
	size_t rawSize = rawWidth * 4 * rawHeight;
	char *buffer;
	NSString *basePath = template.flipswitchImageCacheBasePath;
	NSString *metadataPath = [basePath stringByAppendingString:@".plist"];
	NSString *binaryPath = [basePath stringByAppendingString:@".bin"];
	int fd;
	OSSpinLockLock(&_lock);
	if (_pageSize == 0) {
		_pageSize = sysconf(_SC_PAGESIZE);
	}
	static CGColorSpaceRef _sharedColorSpace;
	if (!_sharedColorSpace) {
		_sharedColorSpace = CGColorSpaceCreateDeviceRGB();
	}
	if (!_fileDescriptors) {
		_fileDescriptors = [[NSMutableDictionary alloc] init];
	}
	NSNumber *fileDescriptor = [_fileDescriptors objectForKey:basePath];
	if (fileDescriptor) {
		fd = [fileDescriptor intValue];
		OSSpinLockUnlock(&_lock);
	} else {
		mkdir("/tmp/FlipswitchCache", 0777);
		fd = open([binaryPath UTF8String], O_RDWR | O_CREAT | O_CLOEXEC);
		if (fd == -1) {
in_memory_fallback:
			if (&UIGraphicsBeginImageContextWithOptions != NULL) {
				UIGraphicsBeginImageContextWithOptions(size, NO, scale);
			} else {
				UIGraphicsBeginImageContext(size);
				scale = 1.0f;
			}
			[self _renderImageOfLayers:layers switchState:state controlState:controlState size:size scale:scale forSwitchIdentifier:switchIdentifier usingTemplate:template];
			result = UIGraphicsGetImageFromCurrentImageContext();
			UIGraphicsEndImageContext();
			goto cache_and_return_result;
		}
		[_fileDescriptors setObject:[NSNumber numberWithInt:fd] forKey:basePath];
		OSSpinLockUnlock(&_lock);
		fchmod(fd, S_IRWXU | S_IRGRP | S_IROTH);		
	}
	int err;
	do {
		err = flock(fd, LOCK_EX);
	} while ((err == -1) && (errno == EINTR));
	if (err)
		goto in_memory_fallback;
	NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
	if (!fileDescriptor) {
		// Check for cases where the Info.plist or Theme.plist is modified and invalidate the cache if so
		struct timespec infoTimespec = GetFileModifiedTime([[template pathForResource:@"Info" ofType:@"plist"] UTF8String]);
		struct timespec themeTimespec = GetFileModifiedTime([[template pathForResource:@"Theme" ofType:@"plist"] UTF8String]);
		struct timespec bundleTimespec = (infoTimespec.tv_sec > themeTimespec.tv_sec) || ((infoTimespec.tv_sec == themeTimespec.tv_sec) && (infoTimespec.tv_nsec > themeTimespec.tv_nsec)) ? infoTimespec : themeTimespec;
		if ((bundleTimespec.tv_sec != [[metadata objectForKey:@"sec"] longLongValue]) || (bundleTimespec.tv_nsec != [[metadata objectForKey:@"nsec"] longLongValue])) {
			metadata = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLongLong:bundleTimespec.tv_sec], @"sec", [NSNumber numberWithLongLong:bundleTimespec.tv_nsec], @"nsec", nil];
		}
	}
	NSNumber *position = [metadata objectForKey:cacheKey];
	uintptr_t positionOffset;
	uintptr_t mappingStart;
	uintptr_t mappingEnd;
	if (position) {
		positionOffset = [position unsignedIntegerValue];
		mappingStart = floor_to_page(positionOffset);
		mappingEnd = ceil_to_page(positionOffset + rawSize);
	} else {
		// Find position for new image
		NSNumber *newOffset = [metadata objectForKey:@"end"] ?: [NSNumber numberWithUnsignedInteger:0];
		positionOffset = [newOffset unsignedIntegerValue];
		mappingStart = floor_to_page(positionOffset);
		mappingEnd = ceil_to_page(positionOffset + rawSize);
		// Make file larger to accomodate new buffer
		do {
			err = lseek(fd, mappingEnd, SEEK_SET);
		} while ((err == -1) && (errno == EINTR));
		if (err == -1) {
unlock_and_in_memory_fallback:
			do {
				err = flock(fd, LOCK_UN);
			} while((err == -1) && (errno == EINTR));
			goto in_memory_fallback;
		}
		char zero = 0;
		do {
			err = write(fd, &zero, 1);
		} while ((err == -1) && (errno == EINTR));
		if (err == -1)
			goto unlock_and_in_memory_fallback;
		do {
			err = lseek(fd, 0, SEEK_SET);
		} while ((err == -1) && (errno == EINTR));
		if (err == -1)
			goto unlock_and_in_memory_fallback;
		// Map it in
		buffer = mmap(NULL, mappingEnd - mappingStart, PROT_READ | PROT_WRITE, MAP_SHARED, fd, mappingStart);
		if (buffer == MAP_FAILED)
			goto unlock_and_in_memory_fallback;
		// Clear buffer
		memset(&buffer[positionOffset - mappingStart], 0, rawSize);
		// Draw image
		CGContextRef context = CGBitmapContextCreate(&buffer[positionOffset - mappingStart], rawWidth, rawHeight, 8, rawWidth * 4, _sharedColorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
		if (!context) {
			munmap(buffer, mappingEnd - mappingStart);
			goto unlock_and_in_memory_fallback;
		}
		//if (scaleIsSupported()) {
			CGContextScaleCTM(context, scale, -scale);
			CGContextTranslateCTM(context, 0.0f, -size.height);
		//}
		UIGraphicsPushContext(context);
		[self _renderImageOfLayers:layers switchState:state controlState:controlState size:size scale:scale forSwitchIdentifier:switchIdentifier usingTemplate:template];
		UIGraphicsPopContext();
		CGContextFlush(context);
		// Sync
		do {
			err = msync(buffer, mappingEnd - mappingStart, MS_SYNC);
		} while((err == -1) && (errno == EINTR));
		if (err)
			goto unlock_and_in_memory_fallback;
		// Write new metadata
		NSMutableDictionary *newMetadata = [metadata mutableCopy] ?: [[NSMutableDictionary alloc] init];
		[newMetadata setObject:newOffset forKey:cacheKey];
		[newMetadata setObject:[NSNumber numberWithUnsignedInteger:positionOffset + rawSize] forKey:@"end"];
		NSData *metadataData = [NSPropertyListSerialization dataFromPropertyList:newMetadata format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL];
		[newMetadata release];
		[metadataData writeToFile:metadataPath atomically:YES];
	}
	do {
		err = flock(fd, LOCK_UN);
	} while ((err == -1) && (errno == EINTR));
	// Map it in
	buffer = mmap(NULL, mappingEnd - mappingStart, PROT_READ, MAP_SHARED, fd, mappingStart);
	if (buffer == MAP_FAILED)
		goto in_memory_fallback;
	CGDataProviderRef dataProvider = CGDataProviderCreateWithData(buffer, &buffer[positionOffset - mappingStart], rawSize, FlipSwitchMappingCGDataProviderReleaseDataCallback);
	if (!dataProvider) {
		munmap(buffer, mappingEnd - mappingStart);
		goto in_memory_fallback;
	}
	CGImageRef cgResult = CGImageCreate(rawWidth, rawHeight, 8, 32, rawWidth * 4, _sharedColorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little, dataProvider, NULL, false, kCGRenderingIntentDefault);
	CGDataProviderRelease(dataProvider);
	if (!cgResult)
		goto in_memory_fallback;
	if (scaleIsSupported())
		result = [UIImage imageWithCGImage:cgResult scale:scale orientation:UIImageOrientationUp];
	else
		result = [UIImage imageWithCGImage:cgResult];
	CGImageRelease(cgResult);
cache_and_return_result:
	if (result) {
		if ([result respondsToSelector:@selector(imageWithRenderingMode:)]) {
			NSString *compositingFilter = [template objectForResolvedInfoDictionaryKey:@"renderingMode" withLayerSet:layerSet switchState:state controlState:controlState resolvedKeyName:NULL];
			UIImageRenderingMode renderingMode;
			if ([compositingFilter isEqualToString:@"auto"]) {
				renderingMode = UIImageRenderingModeAutomatic;
			} else if ([compositingFilter isEqualToString:@"template"]) {
				renderingMode = UIImageRenderingModeAlwaysTemplate;
			} else {
				renderingMode = UIImageRenderingModeAlwaysOriginal;
			}
			result = [result imageWithRenderingMode:renderingMode];
		}
		OSSpinLockLock(&_lock);
		if (!_cachedSwitchImages)
			_cachedSwitchImages = [[NSMutableDictionary alloc] init];
		else {
			UIImage *existingResult = [_cachedSwitchImages objectForKey:cacheKey];
			if (existingResult) {
				existingResult = [existingResult retain];
				OSSpinLockUnlock(&_lock);
				return [existingResult autorelease];
			}
		}
		[_cachedSwitchImages setObject:result forKey:cacheKey];
		OSSpinLockUnlock(&_lock);
	}
	return result;
}

- (UIImage *)imageOfSwitchState:(FSSwitchState)state controlState:(UIControlState)controlState scale:(CGFloat)scale forSwitchIdentifier:(NSString *)switchIdentifier usingTemplate:(NSBundle *)template
{
	return [self imageOfSwitchState:state controlState:controlState scale:scale forSwitchIdentifier:switchIdentifier usingLayerSet:nil inTemplate:template];
}

- (UIImage *)imageOfSwitchState:(FSSwitchState)state controlState:(UIControlState)controlState forSwitchIdentifier:(NSString *)switchIdentifier usingTemplate:(NSBundle *)template
{
	return [self imageOfSwitchState:state controlState:controlState forSwitchIdentifier:switchIdentifier usingLayerSet:nil inTemplate:template];
}

- (UIImage *)imageOfSwitchState:(FSSwitchState)state controlState:(UIControlState)controlState forSwitchIdentifier:(NSString *)switchIdentifier usingLayerSet:(NSString *)layerSet inTemplate:(NSBundle *)template
{
	CGFloat scale = [UIScreen instancesRespondToSelector:@selector(scale)] ? [UIScreen mainScreen].scale : 1.0f;
	return [self imageOfSwitchState:state controlState:controlState scale:scale forSwitchIdentifier:switchIdentifier usingLayerSet:layerSet inTemplate:template];
}

- (BOOL)hasCachedImageOfSwitchState:(FSSwitchState)state controlState:(UIControlState)controlState scale:(CGFloat)scale forSwitchIdentifier:(NSString *)switchIdentifier usingLayerSet:(NSString *)layerSet inTemplate:(NSBundle *)templateBundle
{
	templateBundle = [templateBundle flipswitchThemedBundle];
	id cacheKey = [self _cacheKeyForSwitchState:state controlState:controlState scale:scale forSwitchIdentifier:switchIdentifier usingLayerSet:layerSet inTemplate:templateBundle layers:NULL prerenderedFileName:NULL];
	if (!cacheKey)
		return NO;
	OSSpinLockLock(&_lock);
	UIImage *result = [_cachedSwitchImages objectForKey:cacheKey];
	OSSpinLockUnlock(&_lock);
	if (result)
		return YES;
	NSString *basePath = templateBundle.flipswitchImageCacheBasePath;
	NSString *metadataPath = [basePath stringByAppendingString:@".plist"];
	NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
	NSNumber *position = [metadata objectForKey:cacheKey];
	return position != nil;
}

- (BOOL)hasCachedImageOfSwitchState:(FSSwitchState)state controlState:(UIControlState)controlState scale:(CGFloat)scale forSwitchIdentifier:(NSString *)switchIdentifier usingTemplate:(NSBundle *)templateBundle
{
	return [self hasCachedImageOfSwitchState:state controlState:controlState scale:scale forSwitchIdentifier:switchIdentifier usingLayerSet:nil inTemplate:templateBundle];
}

- (BOOL)hasCachedImageOfSwitchState:(FSSwitchState)state controlState:(UIControlState)controlState forSwitchIdentifier:(NSString *)switchIdentifier usingTemplate:(NSBundle *)templateBundle
{
	return [self hasCachedImageOfSwitchState:state controlState:controlState forSwitchIdentifier:switchIdentifier usingLayerSet:nil inTemplate:templateBundle];
}

- (BOOL)hasCachedImageOfSwitchState:(FSSwitchState)state controlState:(UIControlState)controlState forSwitchIdentifier:(NSString *)switchIdentifier usingLayerSet:(NSString *)layerSet inTemplate:(NSBundle *)templateBundle
{
	CGFloat scale = [UIScreen instancesRespondToSelector:@selector(scale)] ? [UIScreen mainScreen].scale : 1.0f;
	return [self hasCachedImageOfSwitchState:state controlState:controlState scale:scale forSwitchIdentifier:switchIdentifier usingLayerSet:layerSet inTemplate:templateBundle];
}

- (UIButton *)buttonForSwitchIdentifier:(NSString *)switchIdentifier usingTemplate:(NSBundle *)template
{
	REQUIRE_MAIN_THREAD(FSSwitchPanel);
	return [[[_FSSwitchButton alloc] initWithSwitchIdentifier:switchIdentifier template:template] autorelease];
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
	LMConnectionSendOneWayData(&connection, FSSwitchServiceMessageOpenURLAsAlternateAction, (CFDataRef)[NSPropertyListSerialization dataFromPropertyList:[url absoluteString] format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL]);
}

- (BOOL)switchWithIdentifierIsEnabled:(NSString *)switchIdentifier
{
	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWayPropertyList(&connection, FSSwitchServiceMessageGetEnabledForIdentifier, switchIdentifier, &responseBuffer)) {
		return NO;
	}
	return LMResponseConsumeInteger(&responseBuffer);
}

- (void)beginPrewarmingForSwitchIdentifier:(NSString *)switchIdentifier
{
	LMConnectionSendOneWayData(&connection, FSSwitchServiceMessageBeginPrewarmingForIdentifier, (CFDataRef)[NSPropertyListSerialization dataFromPropertyList:switchIdentifier format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL]);
}

- (void)cancelPrewarmingForSwitchIdentifier:(NSString *)switchIdentifier
{
	LMConnectionSendOneWayData(&connection, FSSwitchServiceMessageCancelPrewarmingForIdentifier, (CFDataRef)[NSPropertyListSerialization dataFromPropertyList:switchIdentifier format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL]);
}

- (NSString *)descriptionOfState:(FSSwitchState)state forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (!switchIdentifier)
		return nil;
	NSArray *request = [NSArray arrayWithObjects:switchIdentifier, [NSNumber numberWithInt:state], nil];
	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWayPropertyList(&connection, FSSwitchServiceMessageDescriptionOfStateForIdentifier, request, &responseBuffer)) {
		return nil;
	}
	return LMResponseConsumePropertyList(&responseBuffer);
}

- (Class <FSSwitchSettingsViewController>)settingsViewControllerClassForSwitchIdentifier:(NSString *)switchIdentifier
{
	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWayPropertyList(&connection, FSSwitchServiceMessageSettingsViewControllerForIdentifier, switchIdentifier, &responseBuffer)) {
		return Nil;
	}
	NSArray *result = LMResponseConsumePropertyList(&responseBuffer);
	if ([result isKindOfClass:[NSArray class]]) {
		switch ([result count]) {
			case 1: {
				NSString *className = [result objectAtIndex:0];
				if ([className isKindOfClass:[NSString class]]) {
					return NSClassFromString(className);
				}
				break;
			}
			case 2: {
				NSString *className = [result objectAtIndex:0];
				if ([className isKindOfClass:[NSString class]]) {
					NSString *imageName = [result objectAtIndex:1];
					if ([imageName isKindOfClass:[NSString class]]) {
						dlopen([imageName UTF8String], RTLD_LAZY);
						return NSClassFromString(className);
					}
				}
				break;
			}
		}
	}
	return Nil;
}

- (UIViewController <FSSwitchSettingsViewController> *)settingsViewControllerForSwitchIdentifier:(NSString *)switchIdentifier
{
	Class _class = [self settingsViewControllerClassForSwitchIdentifier:switchIdentifier];
	if (!_class)
		return nil;
	UIViewController <FSSwitchSettingsViewController> *result;
	if ([_class instancesRespondToSelector:@selector(initWithSwitchIdentifier:)])
		result = [[_class alloc] initWithSwitchIdentifier:switchIdentifier];
	else
		result = [[_class alloc] init];
	if (!result)
		return nil;
	UINavigationItem *item = result.navigationItem;
	if (![item.title length])
		item.title = [self titleForSwitchIdentifier:switchIdentifier];
	return [result autorelease];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<FSSwitchPanel: %p switchIdentifierCount=%ld>", self, (long)[self.switchIdentifiers count]];
}

- (BOOL)switchWithIdentifierIsSimpleAction:(NSString *)switchIdentifier
{
	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWayPropertyList(&connection, FSSwitchServiceMessageGetIsSimpleActionForIdentifier, switchIdentifier, &responseBuffer)) {
		return NO;
	}
	return LMResponseConsumeInteger(&responseBuffer);
}

@end

@implementation FSSwitchPanel (SpringBoard)

- (void)registerDataSource:(id<FSSwitchDataSource>)dataSource forSwitchIdentifier:(NSString *)switchIdentifier;
{
	[NSException raise:NSInternalInconsistencyException format:@"Cannot register switches outside of SpringBoard!"];
}

- (void)unregisterSwitchIdentifier:(NSString *)switchIdentifier;
{
	[NSException raise:NSInternalInconsistencyException format:@"Cannot unregister switches outside of SpringBoard!"];
}

- (void)stateDidChangeForSwitchIdentifier:(NSString *)switchIdentifier
{
	[NSException raise:NSInternalInconsistencyException format:@"Cannot update switch state from outside of SpringBoard!"];
}

@end

@implementation FSSwitchPanel (LayerEffects)

- (void)applyEffectsToLayer:(CALayer *)layer forSwitchState:(FSSwitchState)state controlState:(UIControlState)controlState usingLayerSet:(NSString *)layerSet inTemplate:(NSBundle *)templateBundle
{
	NSString *compositingFilter = [templateBundle objectForResolvedInfoDictionaryKey:@"compositingFilter" withLayerSet:layerSet switchState:state controlState:controlState resolvedKeyName:NULL];
	if (![compositingFilter length])
		compositingFilter = nil;
	layer.compositingFilter = compositingFilter;
}

- (void)applyEffectsToLayer:(CALayer *)layer forSwitchState:(FSSwitchState)state controlState:(UIControlState)controlState usingTemplate:(NSBundle *)templateBundle
{
	[self applyEffectsToLayer:layer forSwitchState:state controlState:controlState usingLayerSet:nil inTemplate:templateBundle];
}

@end
