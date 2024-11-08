#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSHost.h>

#include <stdio.h>

#define NONE        "\033[0m"
#define PGRN        "\033[32;40m"
#define FRED        "\033[31;40m"


int
main ()
{
	id pool = [[NSAutoreleasePool alloc] init];

	printf("NSHost tests\n");

	NSHost *h = [NSHost hostWithAddress: @"fe80::1"];
	if (!strcmp([[h address] cString], "fe80::1"))
		printf(PGRN "PASS: IPv6 address %s\n", NONE, [[h address] cString]);
	else
		printf(FRED "FAIL:  '%s' expected 'fe80::1'\n" NONE, [[h address] cString]);

	h = [NSHost hostWithAddress: @"127.0.0.1"];
	if (!strcmp([[h address] cString], "127.0.0.1"))
		printf(PGRN "PASS: IPv4 address %s\n", NONE, [[h address] cString]);
	else
		printf(FRED "FAIL:  '%s' expected '127.0.0.1'\n" NONE, [[h address] cString]);

	h = [NSHost hostWithName: @"www.google.com"];		// must be resolvable
	printf("host:  %s\n", [[h name] cString]);
	
	NSArray *a = [h addresses];
	NSUInteger i, count = [a count];
	for (i = 0; i < count; i++)
		printf("address [%d]:  %s\n", i, [[a objectAtIndex: i] cString]);

	NSHost *h2 = [NSHost hostWithAddress: [a objectAtIndex: 0]];
	if ([h isEqualToHost: h2])							// test reverse lookup
		printf(PGRN "PASS: equality test\n" NONE);
	else
		printf(FRED "FAIL:  '%s' not equal to '%s'\n" NONE, [[h address] cString], [[h2 address] cString]);

	[pool release];
	printf("nshost test complete\n");

	return 0;
}
