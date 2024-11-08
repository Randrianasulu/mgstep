#include <stdio.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSTimeZone.h>

int
main ()
{
id pool = [[NSAutoreleasePool alloc] init];

	printf("NSTimeZone tests\n");
	printf("time zones:\n%s\n",
		[[[NSTimeZone knownTimeZoneNames] description] cString]);
	printf("time zone for PST:\n%s\n",
		[[[[NSTimeZone abbreviationDictionary] objectForKey: @"PST"] description] cString]);
	printf("local time zone:\n%s\n", 
		[[[NSTimeZone localTimeZone] description] cString]);
	[pool release];
	printf("nstimezone test complete\n");

	return 0;
}
