#import <Foundation/Foundation.h>

static NSString *userStringFromAction(CFIndex value)
{
	switch (value) {
		case 0:
			return @"Respring";
		case 1:
			return @"Restart";
		case 2:
			return @"Power Off";
		case 3:
			return @"Safe Mode";
		case 4:
			return @"Do Nothing";
		default:
			return nil;
	}
}
