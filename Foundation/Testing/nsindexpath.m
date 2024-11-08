#include <stdio.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSIndexPath.h>

#define NONE        "\033[0m"
#define FRED        "\033[31;40m"


int
main ()
{
	id pool = [[NSAutoreleasePool alloc] init];

	NSIndexPath *ip;
	NSUInteger ix[] = {3,7,18,44,5,7,9};
	NSUInteger ix2[] = {7,3,18,44,5,7,9};
	NSUInteger len = sizeof(ix)/sizeof(NSUInteger);

	printf("NSIndexPath tests\n");

	ip = [NSIndexPath indexPathWithIndexes: ix length:len];

	if (!strstr([[ip description] cString], "3.7.18.44.5.7.9"))
		printf(FRED "FAIL:  '%s' expected '6 8-9 14-22'\n" NONE, [[ip description] cString]);
	else
		printf("index path from {3,7,18,44,5,7,9}:  %s\n", [[ip description] cString]);
	printf("index path hash of {3,7,18,44,5,7,9}:  %u\n", [ip hash]);
	ip = [NSIndexPath indexPathWithIndexes: ix2 length:len];
	printf("index path hash of {7,3,18,44,5,7,9}:  %u\n", [ip hash]);

	[pool release];
	printf("nsindexpath test complete\n");

	return 0;
}
