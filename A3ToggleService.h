#define kA3ToggleServiceName "a3api.togglecomm"

typedef enum {
	A3ToggleServiceMessageGetIdentifiers = 0,
	A3ToggleServiceMessageGetNameForIdentifier = 1,
	A3ToggleServiceMessageGetStateForIdentifier = 2,
	A3ToggleServiceMessageSetStateForIdentifier = 3,
} A3ToggleServiceMessage;
