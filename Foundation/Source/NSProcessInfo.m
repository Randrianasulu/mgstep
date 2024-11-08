/*
   NSProcessInfo.m

   Manage process specific information.

   Copyright (C) 1999-2020 free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:	January 1999

   Portions derived from Georg Tuparev's implementation of
   NSProcessInfo and from Mircea Oancea's implementation.

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSString.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSException.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSFileManager.h>


extern char **environ;

static NSProcessInfo *__processInfo = nil;

static char **__argv = NULL;
static char **__env = NULL;
static int __argc = 0;



@implementation NSProcessInfo

+ (void) initialize
{
	__processInfo = [[NSProcessInfo alloc] init];
}

+ (NSProcessInfo *) processInfo				{ return __processInfo; }

- (id) init
{
	char host[1024] = {0};
	int i, count;
	id *argStr = malloc (__argc * sizeof(id));
	id *keys;
	id *vals;

	NSAssert(__argc >= 1, @"process args not initialized");
														// Get the process name
    _processName = [[[NSString alloc] initWithCString:__argv[0]] autorelease];
    _processName = [[_processName lastPathComponent] retain];

	for (i = 0; i < __argc; i++)						// Copy argument list
	    argStr[i] = [[[NSString alloc] initWithCString:__argv[i]] autorelease];

	_arguments = [[NSArray alloc] initWithObjects:argStr count:__argc];
	free (argStr);

    for (count = 0; __env[count]; count++);				// Count eviron vars
	keys = calloc (1, (count + 1) * sizeof(id));
	vals = calloc (1, (count + 1) * sizeof(id));

	for (i = 0; i < count; i++)							// Copy environment vars
		{
	    char *cp;
	    char *p = strdup(__env[i]);

	    for (cp = p; *cp != '=' && *cp; cp++);			// skip until '='
		*cp = '\0';
	    vals[i] = [[NSString alloc] initWithCString:(cp + 1)];
	    keys[i] = [[NSString alloc] initWithCString:p];
	    free (p);
		}
							// dynamically determine mGSTEP system bundle path
	if (!getenv("MGSTEP_ROOT"))
		{
		NSFileManager *fm = [NSFileManager defaultManager];
		char *root = NULL;
		BOOL isDir;
		NSString *p = nil;

		for (i = 0; i < (__argc - 1) && !root; i++)
			if (strcmp (__argv[i], "-mgstep") == 0)		// search command line
				if ((root = __argv[i+1]))
					p = [[NSString alloc] initWithCString:root];

		if (!p || ![fm fileExistsAtPath:p isDirectory:&isDir] || !isDir)
			{
			NSString *paths[] = {@"/usr/local/mGSTEP", @"/usr/mgstep", NULL};

			p = nil;
			for (i = 0; paths[i]; i++) 					// search common places
				if ([fm fileExistsAtPath:paths[i] isDirectory:&isDir] && isDir) 
					p = paths[i];
			}

		if (!p)
			{
			NSString *a, *b, *c, *d, *e, *fmt = @"%@%@%@%@%@";

			a = @"\n\nMGSTEP_ROOT is not defined in the environment or on the";
			b = @"\ncommand line and the mgstep system files were not found\n";
			c = @"in the default paths /usr/mgstep or /usr/local/mGSTEP\n";
			d = @"Define it on the command line with: '-mgstep /myPath'\n";
			e = @"or in the environment via: 'export MGSTEP_ROOT=/myPath'\n";
			[NSException raise: NSGenericException format: fmt,a,b,c,d,e];
			}
		keys[count] = @"MGSTEP_ROOT";
		vals[count] = p;
		count++;
		}

	_environment = [[NSDictionary alloc] initWithObjects:vals
										 forKeys:keys
										 count:count];
	free (keys);
	free (vals);

    gethostname(host, 1023);
    _hostName = [[NSString alloc] initWithCString:host];

	return self;
}

- (NSArray *) arguments						{ return _arguments; }
- (NSDictionary *) environment				{ return _environment; }
- (NSString *) hostName						{ return _hostName; }
- (NSString *) operatingSystem				{ return _operatingSystem; }
- (NSString *) processName					{ return _processName; }

- (NSString *) globallyUniqueString
{
	return [NSString stringWithFormat:@"%s:%d:[%s]", [_hostName cString], 
						(int)getpid(), [[[NSDate date] description] cString]];
}

- (void) setProcessName:(NSString *)pName
{
    if (pName && [pName length])
		{
		[_processName autorelease];
		_processName = [pName copy];
		}
}
															// disable release
- (id) autorelease							{ return self; }
- (id) retain								{ return self; }
- (oneway void) release						{ return; }

@end


int
_init_process(int argc, char **argv, char **env)			// called by main()
{															// obj-c hook
	__argc = argc;
	__argv = argv;
	__env = (!env) ? environ : env;

	return 0;
}
