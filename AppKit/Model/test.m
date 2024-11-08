
#include <AppKit/AppKit.h>
#include <AppKit/NSNibLoading.h>

#import "Controller.h"


int
main(int argc, char **argv, char** env)
{
	id pool = [NSAutoreleasePool new];
	NSProcessInfo *processInfo = [NSProcessInfo processInfo];
	NSArray *arguments = [processInfo arguments];

	if ([arguments count] != 2)
		{
		printf("usage: %s <mib-file>\n", [[processInfo processName] cString]);
		printf ("	*specify an absolute path\n");
		exit (1);
		}

	fprintf (stderr,"starting mib test...\n");
	[NSApplication sharedApplication];

	if (![NSBundle loadNibNamed:[arguments objectAtIndex:1]
				   owner:[Controller new]])
		{
		printf ("Cannot load Interface Modeller file!\n");
		exit (1);
		}
												// make NIB windows visible
	[NSApp makeWindowsPerform:@selector(orderFront:) inOrder:NO];
	[[NSApplication sharedApplication] run];
	printf ("exiting...\n");
	
	[pool release];
	exit (0);
}
