/*
   Alert.m

   Show an alert panel

   Copyright (C) 2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:	June 2020

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#import <AppKit/AppKit.h>


@interface Controller : NSObject
@end


@implementation Controller

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSArray *args = [[NSProcessInfo processInfo] arguments];
	NSString *msg = @"Some message text";
	NSString *defalt = @"Default";
	NSString *alt = nil;	// @"Alternate";
	NSString *other = nil;	// @"Other";
	NSString *title = @"Alert Panel";
	NSUInteger i, count = [args count] - 1;
	int result;

	if ((i = [args indexOfObject: @"-d"]) != NSNotFound && i < count)
    	defalt = [args objectAtIndex: i+1];

	if ((i = [args indexOfObject: @"-a"]) != NSNotFound && i < count)
    	alt = [args objectAtIndex: i+1];

	if ((i = [args indexOfObject: @"-o"]) != NSNotFound && i < count)
    	other = [args objectAtIndex: i+1];

	if ((i = [args indexOfObject: @"-m"]) != NSNotFound && i < count)
    	msg = [args objectAtIndex: i+1];

	if ((i = [args indexOfObject: @"-t"]) != NSNotFound && i < count)
		title = [args objectAtIndex: i+1];

	result = NSRunAlertPanel(title, msg, defalt, alt, other);
	switch (result)
		{
		case NSAlertDefaultReturn:	 NSLog (@"NSAlertDefaultReturn:");	 break;
		case NSAlertAlternateReturn: NSLog (@"NSAlertAlternateReturn:"); break;
		case NSAlertOtherReturn:	 NSLog (@"NSAlertOtherReturn:");     break;
		case NSAlertErrorReturn:	 NSLog (@"NSAlertErrorReturn:");     break;
		}

	switch (result)
		{
		case NSAlertDefaultReturn:	 result = 1; 	break;
		case NSAlertAlternateReturn: result = 2; 	break;
		case NSAlertOtherReturn:	 result = 3;	break;
		}

	exit(result);
}

- (id) init
{
	[[NSApplication sharedApplication] setDelegate: self];

	return self;
}

@end /* Controller */


void
usage(void)
{
	fprintf(stdout, "\nInvalid options, Usage:\n\n");
	fprintf(stdout, " Alert.app [adomtv]\n\n");
	fprintf(stdout, "  -d  Default button title,   exit = 1\n");
	fprintf(stdout, "  -a  Alternate button title, exit = 2\n");
	fprintf(stdout, "  -o  Other button title,     exit = 3\n");
	fprintf(stdout, "  -m  Alert panel message\n");
	fprintf(stdout, "  -t  Alert panel title\n");
	fprintf(stdout, "  -v  Print version and exit\n");
	fprintf(stdout, "\n");
	exit(1);
}

int
main(int argc, char **argv, char **env)
{
	extern int optind;
	int c;

	while ((c = getopt(argc, argv, "a:d:o:t:m:v")) != -1)
		switch (c)
			{
			case 'a':
			case 'd':
			case 'o':
			case 't':
			case 'm':
              	if (!optarg)
					usage();
				break;
			default:
				usage();
			case 'v':
				fprintf(stdout, "mGSTEP Alert v0.2\n");
				exit(1);
			};

	return NSApplicationMain(argc, (const char **)argv);
}
