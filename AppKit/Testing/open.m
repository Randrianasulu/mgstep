/*
   open.m

   Open files and directories

   Copyright (C) 2005 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:	April 2005

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#import <AppKit/AppKit.h>

#include <sys/types.h>
#include <unistd.h>
#include <errno.h>
#include <pwd.h>


void
usage(void)
{
	fprintf(stdout, "\nInvalid options, Usage:\n\n");
	fprintf(stdout, " open [-e | -a <application> ] <file> ...\n\n");
	fprintf(stdout, "  -a  Open with specified application\n");
	fprintf(stdout, "  -e  Open with Edit.app\n");
	fprintf(stdout, "  -u  Pose as user\n");
	fprintf(stdout, "  -v  Print version and exit\n");
	fprintf(stdout, "\n");
	exit(1);
}

void
open_with(NSString *app, NSArray *args)
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSWorkspace *ws = [NSWorkspace sharedWorkspace];
	int i, count = [args count];

	for (i = 0; i < count; i++)
		{
		NSString *p = [args objectAtIndex: i];
		NSString *t = nil;
		NSString *a = nil;

		NSLog(@"arg: '%@'", p);

		if (![p isAbsolutePath])
			p = [[fm currentDirectoryPath] stringByAppendingPathComponent: p];
		
		NSLog(@"path: '%@'", p);

		if(![ws getInfoForFile:p application:&a type:&t])
			{
			NSLog(@"No app found for path: '%@'", p);
			continue;
			}

		NS_DURING											// open or launch
			if (t == NSApplicationFileType)
				[ws launchApplication: p];
			else
				{
				if (t == NSDirectoryFileType && !app)
					[ws selectFile:nil inFileViewerRootedAtPath:p];
				else if (app)
					[ws openFile:p withApplication:app];
				else if (a)
					[ws openFile:p withApplication:a];
				else
					NSLog(@"No app handles: '%@'", p);
				}
		NS_HANDLER
			NSLog(@"%@", [localException reason]);
		NS_ENDHANDLER
		}
}

BOOL
set_user(NSString *user)
{
	struct passwd *pw = NULL;

    if ((pw = getpwnam([user cString])) != NULL)
		{
		endpwent();
	
		if ((setuid(pw->pw_uid) == 0))
			return YES;
		}

	fprintf(stderr,"Error posing as %s (%s)\n", [user cString], strerror(errno));

	return NO;
}


int
main(int argc, char **argv, char **env)
{
	extern int optind;
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	NSProcessInfo *pi = [NSProcessInfo processInfo];
	NSMutableArray *args = [[pi arguments] mutableCopy];
	NSString *app = nil;
	NSString *user = nil;
	int i = 0, c;

	while ((c = getopt(argc, argv, "a:eu:v")) != -1)
		switch (c)
			{
			case 'a':
				if (app)
					usage();
				i = [args indexOfObject: @"-a"];
              	if (optarg)
					{
					app = [[args objectAtIndex: i+1] retain];
					[args removeObjectAtIndex: i+1];
					}
				[args removeObjectAtIndex: i];
				break;
			case 'e':
				if (app)
					usage();
				[args removeObject: @"-e"];
				app = @"Edit";
				break;
			case 'u':
				i = [args indexOfObject: @"-u"];
              	if (optarg)
					user = [[args objectAtIndex: i+1] retain];
				else
					usage();
				[args removeObjectAtIndex: i+1];
				[args removeObjectAtIndex: i];
				break;
			default:
				usage();
			case 'v':
				fprintf(stdout, "mGSTEP open v0.5\n");
				exit(1);
			};

	if (optind >= argc)
		usage();

	if (!user || set_user(user))
		{
		[NSApplication sharedApplication];
		[args removeObjectAtIndex: 0];
		open_with(app, args);
		}
	
	[NSApp terminate:nil];
    [pool release];

	exit(0);
}
