#include <sys/stat.h>

static struct timespec GetFileModifiedTime(const char *path)
{
	struct stat temp;
	if (path != NULL)
		if (stat(path, &temp) == 0)
			return temp.st_mtimespec;
	struct timespec distantPast;
	distantPast.tv_sec = 0;
	distantPast.tv_nsec = 0;
	return distantPast;
}
