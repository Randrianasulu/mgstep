/*
    Test NSValue, NSNumber, and related classes
*/

#include <stdio.h>

#include <Foundation/NSValue.h>
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>
#include <Foundation/NSGeometry.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSAutoreleasePool.h>


int main()
{
	NSPoint p;
	NSRect rect;
	NSValue *v1, *v2;
	NSNumber *n1, *n2, *n3, *n4, *n5;
	NSArray *a1, *a2;
	NSAutoreleasePool *arp = [NSAutoreleasePool new];

    // Numbers
    n1 = [NSNumber numberWithUnsignedShort:30];
    n2 = [NSNumber numberWithDouble:2.7];
    n3 = [NSNumber numberWithDouble:30];
    n4 = [NSNumber numberWithChar:111];
    n5 = [NSNumber numberWithChar:111];
    printf("Number(n1) as int %d  as float %f\n",
		[n1 intValue], [n1 floatValue]);
    printf("n1=%d times n2=%f as int (%d) = %d\n",
		[n1 intValue], [n2 floatValue], [n2 intValue], [n1 intValue] * [n2 intValue]);
    printf("n2 as string: %s\n", [[n2 stringValue] cString]);
    printf("n2 compare:n1 is %d\n", [n2 compare:n1]);
    printf("n1 compare:n2 is %d\n", [n1 compare:n2]);
    printf("n1 isEqual:n3 is %d\n", [n1 isEqual:n3]);
    printf("n4 isEqual:n5 is %d\n", [n4 isEqual:n5]);    

    a1 = [NSArray arrayWithObjects:
		      [NSNumber numberWithChar: 111],
		    [NSNumber numberWithUnsignedChar: 112],
		    [NSNumber numberWithShort: 121],
		    [NSNumber numberWithUnsignedShort: 122],
		    [NSNumber numberWithInt: 131],
		    [NSNumber numberWithUnsignedInt: 132],
		    [NSNumber numberWithInt: 141],
		    [NSNumber numberWithUnsignedInt: 142],
		    [NSNumber numberWithFloat: 151],
		    [NSNumber numberWithDouble: 152], nil];

    a2 = [NSArray arrayWithObjects:
		   [NSNumber numberWithChar: 111],
		   [NSNumber numberWithUnsignedChar: 112],
		   [NSNumber numberWithShort: 121],
		   [NSNumber numberWithUnsignedShort: 122],
		   [NSNumber numberWithInt: 131],
		   [NSNumber numberWithUnsignedInt: 132],
		   [NSNumber numberWithInt: 141],
		   [NSNumber numberWithUnsignedInt: 142],
		   [NSNumber numberWithFloat: 151],
		   [NSNumber numberWithDouble: 152], nil];

    printf("a1 isEqual:a2 is %d\n", [a1 isEqual:a2]);    
													// Test values, Geometry
    rect = NSMakeRect(1.0, 103.3, 40.0, 843.);
    rect = NSIntersectionRect(rect, NSMakeRect(20, 78., 89., 30));
    printf("Rect is %f %f %f %f\n", NSMinX(rect), NSMinY(rect), 
			NSMaxX(rect), NSMaxY(rect));
    v1 = [NSValue valueWithRect:rect];
    printf("Encoding for rect is %s\n", [v1 objCType]);
    rect = [v1 rectValue];
    printf("Rect is %f %f %f %f\n", NSMinX(rect), NSMinY(rect), 
			NSMaxX(rect), NSMaxY(rect));

	if([v1 isEqual:[NSValue valueWithRect:rect]])		// test comparison
		printf("value rect comparison 1 PASS\n");
	else
		printf("value rect comparison 1 **FAILED**\n");
	if([v1 isEqual:[NSValue valueWithRect:NSMakeRect(20, 78., 89., 30)]])
		printf("value rect comparison 2 **FAILED**\n");
	else
		printf("value rect comparison 2 PASS\n");
	if([v1 isEqual:[NSValue value:&rect withObjCType:@encode(NSRect)]])
		printf("value rect comparison 3 PASS\n");
	else
		printf("value rect comparison 3 **FAILED**\n");

    v2 = [NSValue valueWithPoint:NSMakePoint(3,4)];
    v1 = [NSValue valueWithNonretainedObject:v2];
    [[v1 nonretainedObjectValue] getValue:&p];
    printf("point is %f %f\n", p.x, p.y);

    printf("Try getting a null NSValue, should get a NSLog error message:\n");
    v2 = [NSValue value:NULL withObjCType:@encode(int)];

	{							// test int conversion to an unsigned int
	int si = -1;
	unsigned int ui = 1;

	printf("%d == ", si < ui);		// si converted to an unsigned int (bad)
	printf("%d\n", [[NSNumber numberWithInt: si] intValue]
					< [[NSNumber numberWithUnsignedInt: ui] unsignedIntValue]);
	printf("%d == ", si < (int)ui);	// force int comparison           (good)
	printf("%d\n", [[NSNumber numberWithInt: si] intValue]
				< (int)[[NSNumber numberWithUnsignedInt: ui] unsignedIntValue]);
	}
	{
	NSNumber *si = [NSNumber numberWithInt: -1];
	NSNumber *ui = [NSNumber numberWithUnsignedInt: 1];

	printf("Promoted compare -1 to 1  %s\n", ([si compare: ui] == NSOrderedAscending) ? "PASS" : "FAIL");
	}

	n2 = [NSNumber numberWithChar:-1];
    printf("  -1 as BOOL %i, int %d, long %ld, float %f ui %u ul %ul\n",
   			[n2 boolValue], [n2 intValue], [n2 longValue], [n2 floatValue],
			[n2 unsignedIntValue], [n2 unsignedLongValue]);
	n2 = [NSNumber numberWithShort:-1];
    printf("  -1 as BOOL %i, int %d, as float %f unsigned %u unsigned %ul\n",
   			[n2 boolValue], [n2 intValue], [n2 floatValue], [n2 unsignedIntValue],
			[n2 unsignedLongValue]);
	n2 = [NSNumber numberWithInt:-1];
    printf("  -1 as BOOL %i, int %d, as float %f unsigned %u\n",
   			[n2 boolValue], [n2 intValue], [n2 floatValue], [n2 unsignedIntValue]);
 	n2 = [NSNumber numberWithLong:-1];
    printf("  -1 as BOOL %i, int %d, long %ld, long long %lld float %f ui %u ul %ul\n",
   			[n2 boolValue], [n2 intValue], [n2 longValue], [n2 longLongValue],
			[n2 floatValue], [n2 unsignedIntValue], [n2 unsignedLongValue]);
	n2 = [NSNumber numberWithFloat:-1.0];
   printf("-1.0 as BOOL %i, int %d, as float %f double %f unsigned %u\n",
   			[n2 boolValue], [n2 intValue], [n2 floatValue],  [n2 doubleValue], [n2 unsignedIntValue]);
	n2 = [NSNumber numberWithDouble:-1.0];
   printf("-1.0 as BOOL %i, int %d, as float %f double %f unsigned %u\n",
   			[n2 boolValue], [n2 intValue], [n2 floatValue],  [n2 doubleValue], [n2 unsignedIntValue]);
 	n2 = [NSNumber numberWithFloat:0.0];
   printf(" 0.0 as BOOL %i, int %d, as float %f unsigned %u\n",
   			[n2 boolValue], [n2 intValue], [n2 floatValue], [n2 unsignedIntValue]);

	{
	NSNumber *a = [NSNumber numberWithBool:0];
	NSNumber *b = [NSNumber numberWithBool:0];
	NSNumber *c = [NSNumber numberWithBool:1];

	printf("Bool cache test 1 %s\n", (a == b) ? "PASS" : "FAIL");
	printf("Bool cache test 2 %s\n", (a != c) ? "PASS" : "FAIL");
	printf("Bool cache test 3 %s\n", ([a boolValue] == 0) ? "PASS" : "FAIL");
	printf("Bool cache test 4 %s\n", ([c boolValue] == 1) ? "PASS" : "FAIL");
	}

	[arp release];
	printf("values test complete\n");
	exit(0);
}
