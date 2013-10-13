#define REQUIRE_MAIN_THREAD(class) do { \
	if (![NSThread isMainThread]) \
		[NSException raise:NSInternalInconsistencyException format:@"-[" #class " %s] must be called from the main thread!", sel_getName(_cmd)]; \
} while(0)
