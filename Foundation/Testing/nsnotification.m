
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSNotificationQueue.h>
#include <Foundation/NSString.h>
#include <Foundation/NSAutoreleasePool.h>

@interface Observer : NSObject
- (void) gotNotificationFoo:(NSNotification*)not;
@end

@implementation Observer

- (void) gotNotificationFoo:(NSNotification*)not
{
  printf ("Got %s\n", [[not name] cString]);
}

- (void) gotNotificationFooNoObject:(NSNotification*)not
{
  printf ("Got %s without object\n", [[not name] cString]);
}

@end

id foo = @"NotificationTestFoo";
id fooQueue = @"NSNotificationFooQueue";

int main ()
{
	id o1 = [NSObject new];
	id observer1 = [Observer new];
	id arp = [NSAutoreleasePool new];
	NSNotification *n;

	[[NSNotificationCenter defaultCenter] 
		addObserver: observer1
		selector: @selector(gotNotificationFoo:)
		name: fooQueue
		object: o1];

	[[NSNotificationCenter defaultCenter] 
		addObserver: observer1
		selector: @selector(gotNotificationFoo:)
		name: foo
		object: o1];

  [[NSNotificationCenter defaultCenter]
    addObserver: observer1
    selector: @selector(gotNotificationFooNoObject:)
    name: foo
    object: nil];


  /* This will cause two messages to be printed, one for each request above. */
	[[NSNotificationCenter defaultCenter] postNotificationName:foo object:o1];

  /* This will cause one message to be printed. */
	[[NSNotificationCenter defaultCenter] postNotificationName:foo object:nil];

  
	printf("remove notification observer \n");
	[[NSNotificationCenter defaultCenter] removeObserver: observer1
										  name: nil
										  object: o1];

// This will cause message to be printed.
	[[NSNotificationCenter defaultCenter] postNotificationName:foo object:o1];

#if 1
	printf("add notification observer \n");
	[[NSNotificationCenter defaultCenter]
		addObserver: observer1
		selector: @selector(gotNotificationFoo:)
		name: fooQueue
		object: o1];
#endif
	printf("queue 2 NSPostASAP notifications\n");
	n = [NSNotification notificationWithName:fooQueue object:o1 userInfo:nil];
	[[NSNotificationQueue defaultQueue] enqueueNotification:n
							 postingStyle:NSPostASAP
							 coalesceMask:NSNotificationNoCoalescing
							 forModes:nil];
	n = [NSNotification notificationWithName:foo object:nil userInfo:nil];
	[[NSNotificationQueue defaultQueue] enqueueNotification:n
							 postingStyle:NSPostASAP];
	[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow:2]];

	printf("queue 3 notifications coalescing on name\n");
	[[NSNotificationQueue defaultQueue] enqueueNotification:n
							 postingStyle:NSPostASAP
							 coalesceMask:NSNotificationCoalescingOnName
							 forModes:nil];
	[[NSNotificationQueue defaultQueue] enqueueNotification:n
							 postingStyle:NSPostASAP
							 coalesceMask:NSNotificationCoalescingOnName
							 forModes:nil];
	[[NSNotificationQueue defaultQueue] enqueueNotification:n
							 postingStyle:NSPostASAP
							 coalesceMask:NSNotificationCoalescingOnName
							 forModes:nil];
	[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow:2]];

	printf("queue 3 notifications no coalescing on name\n");
	[[NSNotificationQueue defaultQueue] enqueueNotification:n
							 postingStyle:NSPostASAP
							 coalesceMask:NSNotificationNoCoalescing
							 forModes:nil];
	[[NSNotificationQueue defaultQueue] enqueueNotification:n
							 postingStyle:NSPostASAP
							 coalesceMask:NSNotificationNoCoalescing
							 forModes:nil];
	[[NSNotificationQueue defaultQueue] enqueueNotification:n
							 postingStyle:NSPostASAP
							 coalesceMask:NSNotificationNoCoalescing
							 forModes:nil];
	[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow:2]];

	printf("remove notification observer\n");
	[[NSNotificationCenter defaultCenter] removeObserver: observer1];

// This will cause no messages to be printed.
	[[NSNotificationCenter defaultCenter] postNotificationName:foo object:o1];

	[arp release];
	printf("nsnotification test complete\n");

	exit (0);
}
