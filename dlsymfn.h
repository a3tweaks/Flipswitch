#include <dlfcn.h>

#if __has_include(<ptrauth.h>)
#include <ptrauth.h>
__attribute__((unused))
static inline void *dlsymfn(void *handle, const char *symbol) {
	void *result = dlsym(handle, symbol);
	if (result == NULL) {
		return NULL;
	}
	return ptrauth_sign_unauthenticated(ptrauth_strip(result, ptrauth_key_function_pointer), ptrauth_key_function_pointer, 0);
}
#else
#define dlsymfn dlsym
#endif
