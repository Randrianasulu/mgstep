#import <Foundation/NSObject.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSThread.h>
#import <Foundation/NSDate.h>


main()
{
	fprintf(stderr," Starting nsthread...\n");

	id pool = [[NSAutoreleasePool alloc] init];
	NSTimeInterval startTime = [[NSDate date] timeIntervalSinceReferenceDate];
	NSDate *d = [NSDate dateWithTimeIntervalSinceNow: 3.0];

	[NSThread sleepUntilDate: d];

	float timeGoneBy = [[NSDate date] timeIntervalSinceReferenceDate] - startTime;

 	printf ("elapsed time is %f\n", timeGoneBy);

 	[pool release];

	printf("nsthread test complete\n");
	exit (0);
}
