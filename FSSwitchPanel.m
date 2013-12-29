#import "FSSwitchPanel+Internal.h"
#import "FSSwitchMainPanel.h"
#import "FSSwitchService.h"
#import "FSSwitchDataSource.h"
#import "NSBundle+Flipswitch.h"
#import "FSSwitchButton.h"
#import "ControlStateVariants.h"
#import "Internal.h"

#import <dlfcn.h>
#import <sys/stat.h>
#import <unistd.h>
#import <sys/mman.h>
#import <objc/message.h>
#import <UIKit/UIKit2.h>
#import <libkern/OSAtomic.h>
#import <CommonCrypto/CommonDigest.h>

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
static BOOL _scaleIsSupported;
static CGColorSpaceRef _sharedColorSpace;
static long int _pageSize;
static NSMutableDictionary *_fileDescriptors;

@implementation FSSwitchPanel

static UIImage *FlipSwitchUnmappedImageWithContentsOfFile(NSString *filePath, CGFloat requestedScale)
{
	if (!_scaleIsSupported || (requestedScale == [UIScreen mainScreen].scale)) {
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

+ (void)initialize
{
	if (self == [FSSwitchPanel class]) {
		_scaleIsSupported = [UIImage respondsToSelector:@selector(imageWithCGImage:scale:orientation:)];
		_sharedColorSpace = CGColorSpaceCreateDeviceRGB();
		_pageSize = sysconf(_SC_PAGESIZE);
		_fileDescriptors = [[NSMutableDictionary alloc] init];
		if (objc_getClass("SpringBoard")) {
			dlopen("/Library/Flipswitch/libFlipswitchSpringBoard.dylib", RTLD_LAZY);
			FSSwitchMainPanel *mainPanel = [[objc_getClass("FSSwitchMainPanel") alloc] init];
			_switchManager = mainPanel;
			[mainPanel _loadBuiltInSwitches];
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

+ (void)_didReceiveMemoryWarning
{
	OSSpinLockLock(&_lock);
	[_cachedSwitchImages release];
	_cachedSwitchImages = nil;
	OSSpinLockUnlock(&_lock);
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

- (NSString *)_glyphImageDescriptorOfState:(FSSwitchState)switchState size:(CGFloat)size scale:(CGFloat)scale forSwitchIdentifier:(NSString *)switchIdentifier usingTemplate:(NSBundle *)template
{
	NSString *imageName = [switchIdentifier stringByAppendingFormat:@"-glyph-%@", NSStringFromFSSwitchState(switchState)];
	NSUInteger closestSize;
	closestSize = [template imageSizeForFlipswitchImageName:imageName closestToSize:size inDirectory:nil];
	if (closestSize != NSNotFound)
		return [template imagePathForFlipswitchImageName:imageName imageSize:closestSize preferredScale:scale controlState:UIControlStateNormal inDirectory:nil];
	imageName = [switchIdentifier stringByAppendingString:@"-glyph"];
	closestSize = [template imageSizeForFlipswitchImageName:imageName closestToSize:size inDirectory:nil];
	if (closestSize != NSNotFound)
		return [template imagePathForFlipswitchImageName:imageName imageSize:closestSize preferredScale:scale controlState:UIControlStateNormal inDirectory:nil];
	return [self glyphImageDescriptorOfState:switchState size:size scale:scale forSwitchIdentifier:switchIdentifier];
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
			NSString *toggleState = [layer objectForKey:@"state"];
			id descriptor = [self _glyphImageDescriptorOfState:toggleState ? FSSwitchStateFromNSString(toggleState) : state size:glyphSize scale:scale forSwitchIdentifier:switchIdentifier usingTemplate:template];
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

static inline NSString *MD5OfString(NSString *string)
{
    return MD5OfData([string dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data]);
}

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
		if (!type || [type isEqualToString:@"image"]) {
			NSString *fileName = [layer objectForKey:@"fileName"];
			if (fileName) {
				NSString *fullPath = [template imagePathForFlipswitchImageName:fileName imageSize:0 preferredScale:scale controlState:controlState inDirectory:nil];
				UIImage *image = FlipSwitchUnmappedImageWithContentsOfFile(fullPath, scale);
				[image drawAtPoint:position blendMode:kCGBlendModeNormal alpha:alpha];
			}
		} else if ([type isEqualToString:@"glyph"]) {
			CGFloat blur = [[layer objectForKey:@"blur"] floatValue];
			CGFloat glyphSize = [[layer objectForKey:@"size"] floatValue];
			NSString *toggleState = [layer objectForKey:@"state"];
			id descriptor = [self _glyphImageDescriptorOfState:toggleState ? FSSwitchStateFromNSString(toggleState) : state size:glyphSize scale:scale forSwitchIdentifier:switchIdentifier usingTemplate:template];
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
			UIImage *image;
			if (fileName && (image = FlipSwitchUnmappedImageWithContentsOfFile([template imagePathForFlipswitchImageName:fileName imageSize:0 preferredScale:scale controlState:controlState inDirectory:nil], scale))) {
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
				[image drawInRect:CGRectMake(position.x - blur, position.y - blur, glyphSize + blur + blur, glyphSize + blur + blur) blendMode:kCGBlendModeNormal alpha:alpha];
			} else {
				// Fast path for a solid color
				CGContextSetAlpha(context, alpha);
				CGColorRef color = (ColorWithHexString([layer objectForKey:@"color"]) ?: [UIColor blackColor]).CGColor;
				[self drawGlyphImageDescriptor:descriptor toSize:glyphSize atPosition:position color:color blur:blur inContext:context ofSize:size scale:scale];
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

- (UIImage *)imageOfSwitchState:(FSSwitchState)state controlState:(UIControlState)controlState scale:(CGFloat)scale forSwitchIdentifier:(NSString *)switchIdentifier usingTemplate:(NSBundle *)template
{
	template = [template flipswitchThemedBundle];
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
	size_t rawWidth = _scaleIsSupported ? (size.width * scale) : size.width;
	size_t rawHeight = _scaleIsSupported ? (size.height * scale) : size.height;
	size_t rawSize = rawWidth * 4 * rawHeight;
	char *buffer;
	NSString *basePath = [@"/tmp/FlipswitchCache/" stringByAppendingString:MD5OfString([template bundlePath])];
	NSString *metadataPath = [basePath stringByAppendingString:@".plist"];
	NSString *binaryPath = [basePath stringByAppendingString:@".bin"];
	int fd;
	OSSpinLockLock(&_lock);
	NSNumber *fileDescriptor = [_fileDescriptors objectForKey:basePath];
	if (fileDescriptor) {
		OSSpinLockUnlock(&_lock);
		fd = [fileDescriptor intValue];
	} else {
		mkdir("/tmp/FlipswitchCache", 0777);
		fd = open([binaryPath UTF8String], O_RDWR | O_CREAT);
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
	NSString *keyName = MD5OfData([NSPropertyListSerialization dataFromPropertyList:cacheKey format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL]); 
	flock(fd, LOCK_EX);
	NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
	NSNumber *position = [metadata objectForKey:keyName];
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
		if (lseek(fd, mappingEnd, SEEK_SET) == -1)
			goto in_memory_fallback;
		char zero = 0;
		if (write(fd, &zero, 1) == -1)
			goto in_memory_fallback;
		if (lseek(fd, 0, SEEK_SET) == -1)
			goto in_memory_fallback;
		// Map it in
		buffer = mmap(NULL, mappingEnd - mappingStart, PROT_READ | PROT_WRITE, MAP_SHARED, fd, mappingStart);
		if (buffer == MAP_FAILED)
			goto in_memory_fallback;
		// Clear buffer
		memset(&buffer[positionOffset - mappingStart], 0, rawSize);
		// Draw image
		CGContextRef context = CGBitmapContextCreate(&buffer[positionOffset - mappingStart], rawWidth, rawHeight, 8, rawWidth * 4, _sharedColorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
		if (_scaleIsSupported) {
			CGContextScaleCTM(context, scale, -scale);
			CGContextTranslateCTM(context, 0.0f, -size.height);
		}
		UIGraphicsPushContext(context);
		[self _renderImageOfLayers:layers switchState:state controlState:controlState size:size scale:scale forSwitchIdentifier:switchIdentifier usingTemplate:template];
		UIGraphicsPopContext();
		CGContextFlush(context);
		// Sync
		msync(buffer, mappingEnd - mappingStart, MS_SYNC);
		// Write new metadata
		NSMutableDictionary *newMetadata = [metadata mutableCopy] ?: [[NSMutableDictionary alloc] init];
		[newMetadata setObject:newOffset forKey:keyName];
		[newMetadata setObject:[NSNumber numberWithUnsignedInteger:positionOffset + rawSize] forKey:@"end"];
		NSData *metadataData = [NSPropertyListSerialization dataFromPropertyList:newMetadata format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL];
		[newMetadata release];
		[metadataData writeToFile:metadataPath atomically:YES];
	}
	flock(fd, LOCK_UN);
	// Map it in
	buffer = mmap(NULL, mappingEnd - mappingStart, PROT_READ, MAP_SHARED, fd, mappingStart);
	if (buffer == MAP_FAILED)
		goto in_memory_fallback;
	CGDataProviderRef dataProvider = CGDataProviderCreateWithData(buffer, &buffer[positionOffset - mappingStart], rawSize, FlipSwitchMappingCGDataProviderReleaseDataCallback);
	CGImageRef cgResult = CGImageCreate(rawWidth, rawHeight, 8, 32, rawWidth * 4, _sharedColorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little, dataProvider, NULL, false, kCGRenderingIntentDefault);
	CGDataProviderRelease(dataProvider);
	if (_scaleIsSupported)
		result = [UIImage imageWithCGImage:cgResult scale:scale orientation:UIImageOrientationUp];
	else
		result = [UIImage imageWithCGImage:cgResult];
	CGImageRelease(cgResult);
cache_and_return_result:
	if (result) {
		if ([result respondsToSelector:@selector(imageWithRenderingMode:)])
			result = [result imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
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

- (UIImage *)imageOfSwitchState:(FSSwitchState)state controlState:(UIControlState)controlState forSwitchIdentifier:(NSString *)switchIdentifier usingTemplate:(NSBundle *)template
{
	CGFloat scale = [UIScreen instancesRespondToSelector:@selector(scale)] ? [UIScreen mainScreen].scale : 1.0f;
	return [self imageOfSwitchState:state controlState:controlState scale:scale forSwitchIdentifier:switchIdentifier usingTemplate:template];
}

- (BOOL)hasCachedImageOfSwitchState:(FSSwitchState)state controlState:(UIControlState)controlState scale:(CGFloat)scale forSwitchIdentifier:(NSString *)switchIdentifier usingTemplate:(NSBundle *)templateBundle
{
	templateBundle = [templateBundle flipswitchThemedBundle];
	id cacheKey = [self _cacheKeyForSwitchState:state controlState:controlState scale:scale forSwitchIdentifier:switchIdentifier usingTemplate:templateBundle layers:NULL prerenderedFileName:NULL];
	if (!cacheKey)
		return NO;
	OSSpinLockLock(&_lock);
	UIImage *result = [_cachedSwitchImages objectForKey:cacheKey];
	OSSpinLockUnlock(&_lock);
	if (result)
		return YES;
	NSString *basePath = [@"/tmp/FlipswitchCache/" stringByAppendingString:MD5OfString([templateBundle bundlePath])];
	NSString *metadataPath = [basePath stringByAppendingString:@".plist"];
	NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
	NSString *keyName = MD5OfData([NSPropertyListSerialization dataFromPropertyList:cacheKey format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL]); 
	NSNumber *position = [metadata objectForKey:keyName];
	return position != nil;
}

- (BOOL)hasCachedImageOfSwitchState:(FSSwitchState)state controlState:(UIControlState)controlState forSwitchIdentifier:(NSString *)switchIdentifier usingTemplate:(NSBundle *)templateBundle
{
	CGFloat scale = [UIScreen instancesRespondToSelector:@selector(scale)] ? [UIScreen mainScreen].scale : 1.0f;
	return [self hasCachedImageOfSwitchState:state controlState:controlState scale:scale forSwitchIdentifier:switchIdentifier usingTemplate:templateBundle];
}

- (UIButton *)buttonForSwitchIdentifier:(NSString *)switchIdentifier usingTemplate:(NSBundle *)template
{
	REQUIRE_MAIN_THREAD(FSSwitchPanel);
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
	REQUIRE_MAIN_THREAD(FSSwitchPanel);
	[[UIApplication sharedApplication] openURL:url];
}

- (BOOL)switchWithIdentifierIsEnabled:(NSString *)switchIdentifier
{
	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWayPropertyList(&connection, FSSwitchServiceMessageGetEnabledForIdentifier, switchIdentifier, &responseBuffer)) {
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

