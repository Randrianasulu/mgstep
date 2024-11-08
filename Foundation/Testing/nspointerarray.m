#include <stdio.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSPointerArray.h>

#define NONE        "\033[0m"
#define FRED        "\033[31;40m"


int
main ()
{
	id pool = [[NSAutoreleasePool alloc] init];
	
	NSPointerArray *pa;
	char *ptrs[] = {"Sharona","Amanda","Brandy","Lola","Beth","Maria","Judy",
					"Candy","Barbie","Rhonda","Sara","Roseanna","Angie","Sue"};
	int i, count = sizeof(ptrs)/sizeof(char *);


	printf("NSPointerArray tests\n");

//	pa = [NSPointerArray pointerArrayWithOptions: NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPersonality];

	pa = [NSPointerArray pointerArrayWithOptions: NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality];

	for(i = 0; i < count; i++)
		[pa addPointer: ptrs[i]];
	printf("NSPointerArray count %d expected %d\n", [pa count], count);
	for(i = 0; i < count; i++)
		{
		char *p = (char *)[pa pointerAtIndex:i];

		if (!strcmp(ptrs[i], p))
			printf("%s ", p);
		else
			printf(FRED "FAIL:  '%s' expected '%s'\n" NONE, p, ptrs[i]);
		}
	printf("\n");
	[pa insertPointer:NULL atIndex:5];
	[pa insertPointer:NULL atIndex:5];
	printf("NSPointerArray count %d expected %d\n", [pa count], count+2);
	for(i = 0; i < count+2; i++)
		printf("%s ", (char *)[pa pointerAtIndex:i]);
	printf("\n");
	[pa removePointerAtIndex:5];
	for(i = 0; i < count+1; i++)
		printf("%s ", (char *)[pa pointerAtIndex:i]);
	printf("\n");
	[pa removePointerAtIndex:count];
	printf("NSPointerArray count %d expected %d\n", [pa count], count);
	for(i = 0; i < count; i++)
		printf("%s ", (char *)[pa pointerAtIndex:i]);
	printf("\n");
	[pa setCount:20];
	for(i = 0; i < 20; i++)
		printf("%s ", (char *)[pa pointerAtIndex:i]);
	printf("\n");
	[pa compact];
	for(i = 0; i < [pa count]; i++)
		printf("%s ", (char *)[pa pointerAtIndex:i]);

	printf("\n");

	printf("NSPointerArray test calloc/free\n");
	pa = [NSPointerArray pointerArrayWithOptions: NSPointerFunctionsMallocMemory | NSPointerFunctionsCStringPersonality];
	for(i = 0; i < 20; i++)
		[pa addPointer:"test C string"];
	[pa setCount:412];
	if (![pa pointerAtIndex:400])
		printf("PASS:  NULL non-alloc'd value\n");
	[pa removePointerAtIndex:400];
	[pa removePointerAtIndex:10];
	if ([pa count] == 410)
		printf("PASS:  NSPointerArray equals count expected %d\n", [pa count]);
	else
		printf(FRED "FAIL: NSPointerArray expected 410 (%d)\n", [pa count]);

	[pool release];
	printf("nspointerarray test complete\n");

	return 0;
}
