#import <UIKit/UIKit.h>

typedef enum {
	A3ToggleStateOff = 0,
	A3ToggleStateOn = 1,
	A3ToggleStateIndeterminate = -1
} A3ToggleState;

@protocol A3Toggle <NSObject>
@optional

- (A3ToggleState)stateForToggleIdentifier:(NSString *)toggleIdentifier;
// Gets the current state of the toggle.
// Must override if building a settings-like toggle.
// Return A3ToggleStateIndeterminate if toggle is loading
// By default returns A3ToggleStateIndeterminate

- (void)applyState:(A3ToggleState)newState forToggleIdentifier:(NSString *)toggleIdentifier;
// Sets the new state of the toggle
// Must override if building a settings-like toggle.
// By default calls through to applyActionForToggleIdentifier: if newState is different from the current state

- (void)applyActionForToggleIdentifier:(NSString *)toggleIdentifier;
// Runs the default action for the toggle.
// Must override if building an action-like toggle.
// By default calls through to applyState:forToggleIdentifier: if state is not indeterminate

- (NSString *)titleForToggleIdentifier:(NSString *)toggleIdentifier;
// Returns the localized title for the toggle.
// By default reads the CFBundleDisplayName out of the toggle's bundle.

- (id)glyphImageDescriptorForControlState:(UIControlState)controlState size:(CGFloat)size scale:(CGFloat)scale forToggleIdentifier:(NSString *)toggleIdentifier;
// Provide an image descriptor that best displays at the requested size and scale
// By default looks through the bundle to find a glyph image

- (NSBundle *)bundleForA3ToggleIdentifier:(NSString *)toggleIdentifier;
// Provides a bundle to look for localizations/images in
// By default returns the bundle for the current class

- (void)toggleWasRegisteredForIdentifier:(NSString *)toggleIdentifier;
// Called when toggle is first registered

- (void)toggleWasUnregisteredForIdentifier:(NSString *)toggleIdentifier;
// Called when toggle is unregistered

@end