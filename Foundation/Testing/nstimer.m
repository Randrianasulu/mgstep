#include <Foundation/NSRunLoop.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSString.h>
#include <Foundation/NSAutoreleasePool.h>


NSTimeInterval startTime;

@interface TestDouble : NSObject
+ (double) testDouble;
- (double) testDoubleInstance;
- (void) fireTarget:(id)sender;
@end
@implementation TestDouble

+ (double) testDouble				{ return 12345678912345.0; }
- (double) testDoubleInstance		{ return 92345678912345.0; }

- (void) fireTarget:(id)sender
{
static int count = 0;
float timeGoneBy =[[sender fireDate] timeIntervalSinceReferenceDate]-startTime;

 	printf ("fire date is %f\n", timeGoneBy);
	if(count++ >= 2)
		[sender invalidate];
}

- (id) performAfterDelay:(NSString *)string
{
float timeGoneBy =[[NSDate date] timeIntervalSinceReferenceDate]-startTime;

	printf ("perform after delay %f '%s'\n", timeGoneBy,[string cString]);

//	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[NSObject cancelPreviousPerformRequestsWithTarget:self
			  selector:@selector(performAfterDelay:)
			  object: @"as time goes by"];

	return self;
}

@end

double test_double ()
{
  return 92345678912345.0;
}

void say_count ()
{
  static int count = 0;
  printf ("Timer fired %d times\n", ++count);
}

int main()
{
NSAutoreleasePool *arp = [NSAutoreleasePool new], *pool;
volatile double foo, bar;
//  id inv = [[VoidFunctionInvocation alloc] initWithVoidFunction: say_count];
id o;
id d;
  
	foo = [TestDouble testDouble];
	printf ("TestDouble is %f\n", foo);
	foo = [TestDouble testDouble];
	printf ("TestDouble 2 is %f\n", foo);
	o = [[TestDouble alloc] init];
	bar = [o testDoubleInstance];
	printf ("testDouble is %f\n", bar);
	
	foo = test_double ();
	printf ("test_double is %f\n", foo);
	
	d = [NSDate date];
	//	startTime = [[NSDate date] timeIntervalSinceNow];
	startTime = [d timeIntervalSinceReferenceDate];
	printf ("time interval since referecne date %f\n", startTime);
	
	//  [NSTimer scheduledTimerWithTimeInterval: 3.0
	//	   invocation: inv
	//	   repeats: YES];
	[NSTimer scheduledTimerWithTimeInterval: 3.0
			target: o
			selector: @selector(fireTarget:)
			userInfo: nil
			repeats: YES];
	
	pool = [NSAutoreleasePool new];
	[o performSelector: @selector(performAfterDelay:) 
			withObject: @"as time goes by" 
			afterDelay: 1.0];
	[o performSelector: @selector(performAfterDelay:)
			withObject: @"as time goes by" 
			afterDelay: 2.0];
	[pool release];
	
	[[NSRunLoop currentRunLoop] run];
	[arp release];
	printf("nstimer test complete\n");
	exit (0);
}
