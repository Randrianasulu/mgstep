/*
   NSUtilities.m

   Copyright (C) 1996-2020 Free Software Foundation, Inc.

   Author:	Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date:	August 1994

   NSLog
   Author:	Adam Fedor <fedor@boulder.colorado.edu>
   Date:	November 1996

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSEnumerator.h>


#if !defined(__WIN32__) && !defined(_WIN32)
  #include <pwd.h>								// for getpwnam()
#else
  #define getpagesize vm_page_size
#endif

#if __linux__
  #include <sys/sysinfo.h>
#endif

#if __mach__
  #include <mach.h>
#endif

#if defined(__SOLARIS__) || defined(__svr4__)
  #define getpagesize() sysconf(_SC_PAGESIZE)
#endif


static unsigned __pageSize = 0;					// Cached size of a memory page


/* ****************************************************************************

		NSEnumerator  (abstract)

** ***************************************************************************/

@implementation NSEnumerator

- (id) nextObject							{ return SUBCLASS }
- (NSArray *) allObjects					{ return SUBCLASS }

@end

/* ****************************************************************************

		NSRange functions

** ***************************************************************************/

NSRange
NSUnionRange (NSRange a, NSRange b)
{
	NSRange range;

	range.location = MIN(a.location, b.location);
    range.length = MAX(NSMaxRange(a), NSMaxRange(b)) - range.location;

    return range;
}

NSRange
NSIntersectionRange (NSRange a, NSRange b)
{
	NSRange range;

    if (NSMaxRange(a) < b.location || NSMaxRange(b) < a.location)
		return NSMakeRange(0, 0);

    range.location = MAX(a.location, b.location);
	range.length = MIN(NSMaxRange(a),NSMaxRange(b)) - range.location;

    return range;
}

NSString *
NSStringFromRange(NSRange r)
{
    return [NSString stringWithFormat:@"{%d, %d}", r.location, r.length];
}

NSRange
_NSAbsoluteRange(NSInteger a1, NSInteger a2)
{
	if (a1 < 0)
		a1 = 0;
	if (a2 < 0)
		a2 = 0;

	return (a1 < a2) ? NSMakeRange(a1, a2 - a1) : NSMakeRange(a2, a1 - a2);
}

/* ****************************************************************************

		NSUser functions

** ***************************************************************************/

NSString *
NSUserName (void)							// return user's login name
{
#if defined(__WIN32__) || defined(_WIN32)
	char buf[1024];
	DWORD n = 1024;
											// GetUserName function returns the 
	if (GetUserName(buf, &n))				// current user name
		return [NSString stringWithCString: buf];

	return [NSString stringWithCString: ""];
#endif
	struct passwd *pw;
											// get effective user id
	if ((pw = getpwuid(geteuid())) && pw->pw_name && *pw->pw_name != '\0')
		return [NSString stringWithCString: pw->pw_name];

//	if (getenv("LOGNAME"))
//		return [NSString stringWithCString: getenv("LOGNAME")];

	return nil;
}

NSString *
NSHomeDirectory (void)
{
	return NSHomeDirectoryForUser( NSUserName() );
}

NSString *
NSHomeDirectoryForUser (NSString *login_name)	// home dir for login name
{
#if !defined(__WIN32__) && !defined(_WIN32)
	struct passwd *pw = getpwnam ([login_name cString]);

	return [NSString stringWithCString: pw->pw_dir];
#else

	char buf[1024], *nb;		// The environment variable HOMEPATH holds the
	DWORD n;					// home directory for the user on Windows NT;
	NSString *s;				// Win95 has no concept of home.

	n = GetEnvironmentVariable("HOMEPATH", buf, 1024);
	if (n > 1024)
		{				// Buffer not big enough, so dynamically allocate it
		nb = (char *)objc_malloc(sizeof(char)*(n+1));
		n = GetEnvironmentVariable("HOMEPATH", nb, n+1);
		nb[n] = '\0';
		s = [NSString stringWithCString: nb];
		free(nb);

		return s;
		}
	else
		{						// null terminate it and return the string 
		buf[n] = '\0';
		return [NSString stringWithCString: buf];
		}
#endif
}

/* ****************************************************************************

		NSLog

** ***************************************************************************/

static void
NSLogv (NSString *format, va_list args)
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	NSString *msg;
	NSCalendarDate *date = [NSCalendarDate calendarDate];
	NSString *d = [date descriptionWithCalendarFormat: @"%b %d %H:%M:%S"];
	NSString *n = [[NSProcessInfo processInfo] processName];

	NSString *pfx = [NSString stringWithFormat: @"%@ %@[%d]", d, n, getpid()];
											// Check if there is already a
	if (![format hasSuffix: @"\n"])			// newline at the end of the format
		format = [format stringByAppendingString: @"\n"];
	msg = [NSString stringWithFormat:format arguments:args];
	fprintf(stderr, "%s %s", [pfx cString], [msg cString]);
	[pool release];
}

void
NSLog (NSString *format, ...)
{
	va_list ap;

	va_start (ap, format);
	NSLogv (format, ap);
	va_end (ap);
}

id
_NSLogError (NSString *format, ...)
{
	va_list ap;

	va_start (ap, format);
	NSLogv (format, ap);
	va_end (ap);

	return nil;
}

id												// handle object init errors
_NSInitError (id errorObject, NSString *format, ...)
{
	va_list ap;

	if (errorObject)
		NSLog (@"*** error in %@ ***", [errorObject description]);
	va_start (ap, format);
	NSLogv (format, ap);
	va_end (ap);
	[errorObject release];

	return nil;
}

/* ****************************************************************************

		NSPageSize

** ***************************************************************************/

unsigned										// Return the number of bytes
NSPageSize (void)								// in a memory page.
{
	return (!__pageSize) ? (__pageSize = (unsigned)getpagesize()) : __pageSize;
}

unsigned									
NSLogPageSize (void)							// Return log base 2 of number
{												// of bytes in a memory page
	unsigned tmp_page_size = NSPageSize();
	unsigned log = 0;

	while (tmp_page_size >>= 1)
		log++;

	return log;
}

unsigned
NSRoundDownToMultipleOfPageSize (unsigned bytes)
{												// Round BYTES down to the 
	unsigned a = NSPageSize();					// nearest multiple of memory
												// page size.
	return (bytes / a) * a;
}
												// Round BYTES up to nearest 
unsigned										// multiple of the memory page
NSRoundUpToMultipleOfPageSize (unsigned bytes)	// size, and return it.
{
	unsigned a = NSPageSize();

	return ((bytes % a) ? ((bytes / a + 1) * a) : bytes);
}

unsigned
NSRealMemoryAvailable ()
{
#if __linux__
	struct sysinfo info;

	return ((sysinfo(&info)) != 0) ? 0 : (unsigned) info.freeram;
#else
	fprintf (stderr, "NSRealMemoryAvailable() not implemented.\n");
	return 0;
#endif
}

void *
NSAllocateMemoryPages (unsigned bytes)
{
	void *where;
#if __mach__
	kern_return_t r = vm_allocate (mach_task_self(), &where, (vm_size_t) bytes, 1);

	return (r != KERN_SUCCESS) ? NULL : where;
#else
	if ((where = malloc (bytes)) == NULL)
		return NULL;
	memset (where, 0, bytes);
	return where;
#endif
}

void
NSDeallocateMemoryPages (void *ptr, unsigned bytes)
{
#if __mach__
	vm_deallocate (mach_task_self (), ptr, bytes);
#else
	free (ptr);
#endif
}

void
NSCopyMemoryPages (const void *source, void *dest, unsigned bytes)
{
#if __mach__
	kern_return_t r = vm_copy (mach_task_self(), source, bytes, dest);

	NSParameterAssert (r == KERN_SUCCESS);
#else
	memcpy (dest, source, bytes);
#endif
}
