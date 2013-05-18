#define kA3ToggleServiceName "a3api.togglecomm"

typedef enum {
	A3ToggleServiceMessageGetIdentifiers = 0,
	A3ToggleServiceMessageGetTitleForIdentifier = 1,
	A3ToggleServiceMessageGetStateForIdentifier = 2,
	A3ToggleServiceMessageSetStateForIdentifier = 3,
	A3ToggleServiceMessageGetImageIdentifierForToggle = 4,
} A3ToggleServiceMessage;
