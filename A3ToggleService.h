#define kA3ToggleServiceName "a3api.togglecomm"

typedef enum {
	A3ToggleServiceMessageGetIdentifiers = 0,
	A3ToggleServiceMessageGetTitleForIdentifier = 1,
	A3ToggleServiceMessageGetStateForIdentifier = 2,
	A3ToggleServiceMessageSetStateForIdentifier = 3,
	A3ToggleServiceMessageGetImageDescriptorForToggle = 4,
	A3ToggleServiceMessageApplyActionForIdentifier = 5,
	A3ToggleServiceMessageHasAlternateActionForIdentifier = 6,
	A3ToggleServiceMessageApplyAlternateActionForIdentifier = 7,
} A3ToggleServiceMessage;
