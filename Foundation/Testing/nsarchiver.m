#include <Foundation/NSArchiver.h>
#include <Foundation/NSString.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSSet.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSGeometry.h>

int main()
{
	id setIn, setOut;
	NSAutoreleasePool *pool;
	NSArchiver *arc;
	id una;
	id dec;
	id apl;
	NSArray *array;

//  [NSAutoreleasePool enableDoubleReleaseCheck:YES];
  
	pool = [[NSAutoreleasePool alloc] init];
														// Create Set of str's
	setOut = [[NSSet alloc] initWithObjects: @"apple", @"banana", @"carrot", 
											@"dal", @"escarole", @"fava", nil];

	printf("NSSet contents to be archived:\n");				// Display the set
		{
		id o, e = [setOut objectEnumerator];

		while ((o = [e nextObject]))
			printf("%s\n", [o cString]);    
		}

	arc = [[NSArchiver new] autorelease];
	printf("retainCount %d\n", [arc retainCount]);

	[arc retain];
//	printf("retainCount %d\n", [arc retainCount]);
	[arc release];

	printf("Writing NSSet to archive:\n");					
	[arc encodeRootObject: setOut];
	una = [NSUnarchiver alloc];
	[[una initForReadingWithData:(NSData*)[arc archiverData]] autorelease];
	dec = [una decodeObject];

	if ([dec isEqual: setOut] == NO)
		printf("**error: archive decoded is **NOT** equal to encoded\n");
	else
		printf("archive decoded is equal to encoded\n");

	printf("decoded description of archiver:\n%s",[[dec description] cString]);

	printf("\nWriting archive to file 'nsarchiver.dat'\n");					
	[NSArchiver archiveRootObject: setOut toFile: @"./nsarchiver.dat"];

	printf("Reading archive back from file 'nsarchiver.dat'\n");
		{
		id a, d;

		d = [[NSData alloc] initWithContentsOfFile:@"./nsarchiver.dat"];
		[d autorelease];
		a = [NSUnarchiver alloc];
		a = [[a initForReadingWithData:d] autorelease];
		setIn = [[a decodeObject] retain];
		}

//	setIn = [NSUnarchiver unarchiveObjectWithFile: @"./nsarchiver.dat"];

				// Display what we read, to make sure it matches what we wrote
	printf("Decoded archive contents:\n");
		{
		id o, e = [setIn objectEnumerator];
		while ((o = [e nextObject]))
			printf("%s\n", [o cString]);    
		}

	if ([setIn isEqual: setOut] == NO)
		printf("**error: Set decoded from file is **NOT** equal to encoded\n");
	else
		printf("PASSED: NSSet decoded from file is equal to encoded\n");

	arc = [[NSArchiver new] autorelease];
    array = [NSArray arrayWithObjects:
					[NSNumber numberWithBool: NO],
					[NSNumber numberWithChar: 'a'],
					[NSNumber numberWithUnsignedChar: 255],
					[NSNumber numberWithShort: -3],
					[NSNumber numberWithUnsignedShort: 4],
					[NSNumber numberWithInt: -5],
					[NSNumber numberWithUnsignedInt: 6],
					[NSNumber numberWithInt: -7],
					[NSNumber numberWithUnsignedInt: 8],
					[NSNumber numberWithFloat: 9.9],
					[NSNumber numberWithDouble: 10.10], nil];
	[arc encodeRootObject: array];
	una = [NSUnarchiver alloc];
	[[una initForReadingWithData:(NSData*)[arc archiverData]] autorelease];
	dec = [una decodeObject];
	if ([dec isEqual: array] == NO)
		printf("**Error: array archive decoded is **NOT** equal to encoded\n");
	else
		printf("PASSED: NSArray decoded is equal to encoded\n");

	printf("Array archive contents:\n");
		{
		id o, e = [array objectEnumerator];
		while ((o = [e nextObject]))
			printf("%s ", [[o description] cString]);
		}
	printf("\n");
	printf("Decoded array archive contents:\n");
		{
		id o, e = [dec objectEnumerator];
		while ((o = [e nextObject]))
			printf("%s ", [[o description] cString]);
		}
	printf("\n");


	arc = [[NSArchiver new] autorelease];
    array = [NSArray arrayWithObjects:
					[NSValue valueWithPoint: (NSPoint){2,4}],
					[NSValue valueWithRect: (NSRect){{3,5},{21,41}}],
					[NSValue valueWithSize: (NSSize){20,40}], nil];
	[arc encodeRootObject: array];
	una = [NSUnarchiver alloc];
	[[una initForReadingWithData:(NSData*)[arc archiverData]] autorelease];
	dec = [una decodeObject];
	if ([dec isEqual: array] == NO)
		printf("**Error: array archive decoded is **NOT** equal to encoded\n");
	else
		printf("PASSED: NSArray decoded is equal to encoded\n");

	printf("Array archive contents:\n");
		{
		id o, e = [array objectEnumerator];
		while ((o = [e nextObject]))
			printf("%s ", [[o description] cString]);
		}
	printf("\n");
	printf("Decoded array archive contents:\n");
		{
		id o, e = [dec objectEnumerator];
		while ((o = [e nextObject]))
			printf("%s ", [[o description] cString]);
		}
	printf("\n");


#if 0
					// Benchmark use of very lightwight archiving - a single
					// archiver/unarchiver pair using a single mutable data 
		{			// object to archive and unarchive many times.
		NSDate *start = [NSDate date];
		NSAutoreleasePool *pool = [NSAutoreleasePool new];
		int i;
		NSUnarchiver *u = nil;
		NSMutableData *d;
		NSArchiver *a;
		
		d = [NSMutableData data];
		a = [[NSArchiver alloc] initForWritingWithMutableData: d];
		
		[NSAutoreleasePool enableDoubleReleaseCheck:NO];
		for (i = 0; i < 10000; i++)
			{
			id	o;
		
			[a encodeRootObject: set];
			if (u == nil)
				u = [[NSUnarchiver alloc] initForReadingWithData: d];
			else
				[u resetUnarchiverWithData: d atIndex: 0];
	
			o = [u decodeObject];
			[d setLength: 0];
			[a resetArchiver];
			}
		[a release];
		[u release];
		[pool release];
		printf("Time: %f\n", -[start timeIntervalSinceNow]);
		}
#endif

	[setIn release];
	[pool release];										// Do the autorelease.
	printf("nsarchiver test complete\n");
  
	exit(0);
}
