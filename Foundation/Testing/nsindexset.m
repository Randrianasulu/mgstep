#include <stdio.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSIndexSet.h>

#define NONE        "\033[0m"
#define FRED        "\033[31;40m"


int
main ()
{
	id pool = [[NSAutoreleasePool alloc] init];
	NSIndexSet *s;
	NSMutableIndexSet *m;
	unsigned int i = 14;

	printf("NSIndexSet tests\n");
	printf("index set with index {5}:  %s\n",
		[[[NSIndexSet indexSetWithIndex: 5] description] cString]);
	s = [NSIndexSet indexSetWithIndexesInRange: (NSRange){5,6}];
	printf("index set with range {5-6}:  %s\n", [[s description] cString]);

	m = [s mutableCopy];
	[m addIndex: i++];
	[m addIndex: i++];
	[m addIndex: i++];
	printf("copy & add index 14,15,16:  %s\n", [[m description] cString]);
	[m removeIndex: 15];
	printf("copy & remove index 15:  %s\n", [[m description] cString]);
	[m addIndex: 20];
	printf("add index index 20:  %s\n", [[m description] cString]);
	[m addIndex: 15];
	printf("add index 15:  %s\n", [[m description] cString]);
	[m addIndexesInRange:(NSRange){15, 8}];
	printf("add indexes {15-8}:  %s\n", [[m description] cString]);
	[m removeIndex: 5];
	printf("head clip at 5:  %s\n", [[m description] cString]);
	[m removeIndex: 10];
	printf("tail clip index at 10:  %s\n", [[m description] cString]);
	[m removeIndexesInRange:(NSRange){7, 1}];
	printf("split index at 7:  %s\n", [[m description] cString]);
	if (!strstr([[m description] cString], "6 8-9 14-22"))
		printf(FRED "FAIL:  '%s' expected '6 8-9 14-22'\n" NONE, [[m description] cString]);

	m = [NSMutableIndexSet indexSetWithIndexesInRange: (NSRange){8,2}];
	printf("mutable index set with range {8-9}:  %s\n", [[m description] cString]);
	[m addIndexesInRange:(NSRange){7, 1}];
	printf("add index 7:  %s\n", [[m description] cString]);
	[m removeIndexesInRange:(NSRange){9, 1}];
	printf("tail clip index at 9:  %s\n", [[m description] cString]);
	[m addIndexesInRange:(NSRange){5, 2}];
	printf("add index {5-2}:  %s\n", [[m description] cString]);
	[m addIndexesInRange:(NSRange){3, 2}];
	printf("add index {3-2}:  %s\n", [[m description] cString]);
	[m addIndexesInRange:(NSRange){2, 1}];
	printf("add index 2:  %s\n", [[m description] cString]);
	[m addIndexesInRange:(NSRange){1, 1}];
	printf("add index 1:  %s\n", [[m description] cString]);
	[m addIndexesInRange:(NSRange){0, 1}];
	printf("add index 0:  %s\n", [[m description] cString]);
	if (!strstr([[m description] cString], "0-8"))
		printf(FRED "FAIL:  '%s' expected '0-8'\n" NONE, [[m description] cString]);

	[pool release];
	printf("nsindexset test complete\n");

	return 0;
}
