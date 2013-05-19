#import "A3ToggleManager.h"
#import "A3ToggleManagerMain.h"
#import "A3ToggleService.h"
#import "A3Toggle.h"

#import <dlfcn.h>
#import <UIKit/UIKit2.h>
#import "LightMessaging/LightMessaging.h"

static LMConnection connection = {
	MACH_PORT_NULL,
	kA3ToggleServiceName
};

NSString * const A3ToggleManagerTogglesChangedNotification = @"A3ToggleManagerTogglesChangedNotification";

NSString * const A3ToggleManagerToggleStateChangedNotification = @"A3ToggleManagerToggleStateChangedNotification";
NSString * const A3ToggleManagerToggleIdentifierKey = @"toggleIdentifier";


static A3ToggleManager *_toggleManager;

@implementation A3ToggleManager

static void TogglesChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	[[NSNotificationCenter defaultCenter] postNotificationName:A3ToggleManagerTogglesChangedNotification object:_toggleManager userInfo:nil];
}

+ (void)initialize
{
	if (self == [A3ToggleManager class]) {
		if (objc_getClass("SpringBoard")) {
			_toggleManager = [[A3ToggleManagerMain alloc] init];
		} else {
			_toggleManager = [[self alloc] init];
			CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), self, TogglesChangedCallback, (CFStringRef)A3ToggleManagerTogglesChangedNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
		}
	}
}

+ (A3ToggleManager *)sharedToggleManager
{
    return _toggleManager;
}

- (NSArray *)toggleIdentifiers
{
	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWay(&connection, A3ToggleServiceMessageGetIdentifiers, NULL, 0, &responseBuffer)) {
		return nil;
	}
	return LMResponseConsumePropertyList(&responseBuffer);
}

- (NSString *)titleForToggleIdentifier:(NSString *)toggleIdentifier
{
	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWayPropertyList(&connection, A3ToggleServiceMessageGetTitleForIdentifier, toggleIdentifier, &responseBuffer)) {
		return nil;
	}
	return LMResponseConsumePropertyList(&responseBuffer);
}

- (id)glyphImageIdentifierForToggleIdentifier:(NSString *)toggleIdentifier controlState:(UIControlState)controlState size:(CGFloat)size scale:(CGFloat)scale
{
 	NSDictionary *args = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:toggleIdentifier, [NSNumber numberWithFloat:size], [NSNumber numberWithFloat:scale], [NSNumber numberWithInteger:controlState], nil] forKeys:[NSArray arrayWithObjects:@"toggleIdentifier", @"size", @"scale", @"controlState", nil]];

	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWayPropertyList(&connection, A3ToggleServiceMessageGetImageIdentifierForToggle, args, &responseBuffer)) {
		return nil;
	}
	return LMResponseConsumePropertyList(&responseBuffer);
}

- (UIImage *)toggleImageForToggleIdentifier:(NSString *)toggleIdentifier controlState:(UIControlState)controlState scale:(CGFloat)scale usingTemplateBundle:(NSBundle *)template
{
	CGSize size;
	size.width = [[template objectForInfoDictionaryKey:@"width"] floatValue];
	if (size.width == 0.0f)
		return nil;
	size.height = [[template objectForInfoDictionaryKey:@"height"] floatValue];
	if (size.height == 0.0f)
		return nil;
	if (&UIGraphicsBeginImageContextWithOptions != NULL) {
		UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
	} else {
		UIGraphicsBeginImageContext(size);
	}
	CGContextRef context = UIGraphicsGetCurrentContext();
	for (NSDictionary *layer in [template objectForInfoDictionaryKey:@"layers"]) {
		CGPoint position = CGPointMake([[layer objectForKey:@"x"] floatValue], [[layer objectForKey:@"y"] floatValue]);
		NSString *type = [layer objectForKey:@"type"];
		if (!type || [type isEqualToString:@"image"]) {
			NSString *fileName = [layer objectForKey:@"fileName"];
			if (fileName) {
				UIImage *image = [UIImage imageNamed:fileName inBundle:template];
				[image drawAtPoint:position];
			}
		} else if ([type isEqualToString:@"glyph"]) {
			CGFloat glyphSize = [[layer objectForKey:@"size"] floatValue];
			id identifier = [self glyphImageIdentifierForToggleIdentifier:toggleIdentifier controlState:controlState size:glyphSize scale:scale];
			if ([identifier isKindOfClass:[NSString class]]) {
				UIImage *image;
				if ([identifier hasSuffix:@".pdf"]) {
					CGPDFDocumentRef pdf = CGPDFDocumentCreateWithURL((CFURLRef)[NSURL fileURLWithPath:identifier]);
					if (pdf) {
						CGPDFPageRef firstPage = CGPDFDocumentGetPage(pdf, 1);
						CGRect rect = CGPDFPageGetBoxRect(firstPage, kCGPDFCropBox);
						CGContextScaleCTM(context, 1.0f, -1.0f);
						CGContextTranslateCTM(context, 0, -size.height);
						CGContextScaleCTM(context, glyphSize / rect.size.width, glyphSize / rect.size.height);
						CGContextTranslateCTM(context, -rect.origin.x, -rect.origin.y);
						CGContextDrawPDFPage(context, firstPage);
						CGPDFDocumentRelease(pdf);
					} else {
						NSLog(@"PDF failed!");
					}
				} else if ((image = [UIImage imageWithContentsOfFile:identifier])) {
					identifier = image;
				}
			}
			if ([identifier isKindOfClass:[UIImage class]]) {
				[identifier drawInRect:(CGRect){ position, (CGSize){ glyphSize, glyphSize } }];
			}
		}
	}
	UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return result;
}

- (UIImage *)toggleImageForToggleIdentifier:(NSString *)toggleIdentifier controlState:(UIControlState)controlState usingTemplateBundle:(NSBundle *)templateBundle;
{
	CGFloat scale = [UIScreen instancesRespondToSelector:@selector(scale)] ? [UIScreen mainScreen].scale : 1.0f;
	return [self toggleImageForToggleIdentifier:toggleIdentifier controlState:controlState scale:scale usingTemplateBundle:templateBundle];
}

- (A3ToggleState)toggleStateForToggleIdentifier:(NSString *)toggleIdentifier
{
	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWayPropertyList(&connection, A3ToggleServiceMessageGetStateForIdentifier, toggleIdentifier, &responseBuffer)) {
		return NO;
	}
	return LMResponseConsumeInteger(&responseBuffer);
}

- (void)applyActionForToggleIdentifier:(NSString *)toggleIdentifier
{
	LMConnectionSendOneWayData(&connection, A3ToggleServiceMessageApplyActionForIdentifier, (CFDataRef)[NSPropertyListSerialization dataFromPropertyList:toggleIdentifier format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL]);
}

- (void)setToggleState:(A3ToggleState)state onToggleIdentifier:(NSString *)toggleIdentifier
{
	NSArray *propertyList = [NSArray arrayWithObjects:[NSNumber numberWithBool:state], toggleIdentifier, nil];
	LMConnectionSendOneWayData(&connection, A3ToggleServiceMessageSetStateForIdentifier, (CFDataRef)[NSPropertyListSerialization dataFromPropertyList:propertyList format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL]);
}


- (BOOL)hasAlternateActionForToggleIdentifier:(NSString *)toggleIdentifier
{
	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWayPropertyList(&connection, A3ToggleServiceMessageHasAlternateActionForIdentifier, toggleIdentifier, &responseBuffer)) {
		return NO;
	}
	return LMResponseConsumeInteger(&responseBuffer);
}

- (void)applyAlternateActionForToggleIdentifier:(NSString *)toggleIdentifier
{
	LMConnectionSendOneWayData(&connection, A3ToggleServiceMessageApplyAlternateActionForIdentifier, (CFDataRef)[NSPropertyListSerialization dataFromPropertyList:toggleIdentifier format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL]);
}

@end

@implementation A3ToggleManager (SpringBoard)

- (void)registerToggle:(id<A3Toggle>)toggle forIdentifier:(NSString *)toggleIdentifier
{
	[NSException raise:NSInternalInconsistencyException format:@"Cannot register toggles outside of SpringBoard!"];
}

- (void)unregisterToggleIdentifier:(NSString *)toggleIdentifier;
{
	[NSException raise:NSInternalInconsistencyException format:@"Cannot unregister toggles outside of SpringBoard!"];
}

- (void)stateDidChangeForToggleIdentifier:(NSString *)toggleIdentifier
{
	[NSException raise:NSInternalInconsistencyException format:@"Cannot update toggle state from outside of SpringBoard!"];
}

@end

