/*
   example.m

   Example services facility

   Copyright (C) 1998 Free Software Foundation, Inc.

   Author:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: November 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>
#include <Foundation/NSData.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSException.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSException.h>
#include <Foundation/NSTask.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSPasteboard.h>

#include <signal.h>


@interface ExampleServices : NSObject

- (void) openURL:(NSPasteboard*)bp
		 userData:(NSString*)ud
		 error:(NSString**)err;
- (void) tolower:(NSPasteboard*)bp
		 userData:(NSString*)ud
		 error:(NSString**)err;
- (void) toupper:(NSPasteboard*)bp
		 userData:(NSString*)ud
		 error:(NSString**)err;
@end


@implementation ExampleServices

- (void) openURL:(NSPasteboard*)pb 
		 userData:(NSString*)ud 
		 error:(NSString**)err
{
	NSString *url, *c;
	NSArray *args;
	NSArray *types = [pb types];

	if (![types containsObject: NSStringPboardType])
		{
		*err = @"No string type supplied on pasteboard";
		return;
		}

	if ((url = [pb stringForType: NSStringPboardType]) == nil)
		{
		*err = @"No string value supplied on pasteboard";
		return;
		}

//	c = [NSString stringWithFormat: @"firefox-bin \"-url %@\"", url];
	c = [NSString stringWithFormat: @"firefox -remote 'openURL(%@)'", url];
	args = [NSArray arrayWithObjects: @"-c", c, nil];
	[NSTask launchedTaskWithLaunchPath: @"/bin/sh" arguments: args];
}

- (void) tolower:(NSPasteboard*)pb
		 userData:(NSString*)ud
		 error:(NSString**)err
{
	NSString *in;
	NSString *out;
	NSArray *types = [pb types];

	if (![types containsObject: NSStringPboardType])
		{
		*err = @"No string type supplied on pasteboard";
		return;
		}

	if ((in = [pb stringForType: NSStringPboardType]) == nil)
		{
		*err = @"No string value supplied on pasteboard";
		return;
		}
	
	out = [in lowercaseString];
	types = [NSArray arrayWithObject: NSStringPboardType];
	[pb declareTypes: types owner: nil];
	[pb setString: out forType: NSStringPboardType];
}

- (void) toupper:(NSPasteboard*)pb
		 userData:(NSString*)ud
		 error:(NSString**)err
{
	NSString *in;
	NSString *out;
	NSArray *types = [pb types];

	if (![types containsObject: NSStringPboardType])
		{
		*err = @"No string type supplied on pasteboard";
		return;
		}

	if ((in = [pb stringForType: NSStringPboardType]) == nil)
		{
		*err = @"No string value supplied on pasteboard";
		return;
		}
	
	out = [in uppercaseString];
	types = [NSArray arrayWithObjects: NSStringPboardType,nil];
	[pb declareTypes: types owner: nil];
	[pb setString: out forType: NSStringPboardType];
}

@end

static int debug = 0;
static int verbose = 0;

static void
ihandler(int sig)
{
	abort();
}

static void
init(int argc, char** argv)
{
	const char *options = "Hdv";
	int sym, tty;

	while ((sym = getopt(argc, argv, options)) != -1)
		{
		switch(sym)
			{
			case 'H':
				printf("%s -[%s]\n", argv[0], options);
				printf("mGSTEP Services example server\n");
				printf("-H\tfor help\n");
				printf("-d\tavoid fork() to make debugging easy\n");
				exit(0);
	
			case 'd':
				debug++;
				break;
	
			case 'v':
				verbose++;
				break;
	
			default:
				printf("%s - mGSTEP Pasteboard server\n", argv[0]);
				printf("-H	for help\n");
				exit(0);
		}	}

	for (sym = 0; sym < 32; sym++)
		signal(sym, ihandler);

	signal(SIGPIPE, SIG_IGN);
	signal(SIGTTOU, SIG_IGN);
	signal(SIGTTIN, SIG_IGN);
	signal(SIGHUP, SIG_IGN);
	signal(SIGTERM, ihandler);

	if (debug == 0)
		{										// Now fork off child process 
		switch (fork())							// to run in background.
			{
			case -1:
				NSLog(@"gpbs - fork failed - bye.\n");
				exit(1);
	
			case 0:								// Try to run in background.
#ifdef NeXT
				setpgrp(0, getpid());
#else
				setsid();
#endif
				break;
	
			default:
				if (verbose)
					NSLog(@"Process backgrounded (running as daemon)\r\n");
				exit(0);
		}	}
}

int
main(int argc, char** argv)
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	ExampleServices *server;

	NSLog(@"Starting example server.\n");
	server = [ExampleServices new];

	init(argc, argv);

  // [NSObject enableDoubleReleaseCheck: YES];

	if (server == nil)
		{
		NSLog(@"Unable to create server object.\n");
		exit(1);
		}

	NSRegisterServicesProvider(server, @"ExampleServices");

	[[NSRunLoop currentRunLoop] run];

	NSLog(@"Exiting example server.\n");
	exit(0);
}
