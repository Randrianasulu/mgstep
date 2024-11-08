/* 
   diningPhilosophers.h

   Five hungry philosophers testing locks and threads
   This program loops indefinitely.

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
   Date: 1996
   
   This file is part of the mGSTEP Foundation Library.

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/ 

#include <Foundation/NSLock.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSAutoreleasePool.h>

// Conditions
#define NO_FOOD 1
#define FOOD_SERVED 2

// NSLocks ... umm I mean forks
id forks[5];


@interface Philosopher : NSObject			// A class of hungry philosophers
{
	int chair;
}

- (void) sitAtChair:(int)position;
- (int) chair;

@end

@implementation Philosopher

- (void) sitAtChair:(int)position
{
int i;

	chair = position;									// Sit down
									
	while (1)						// Its a constant battle to feed yourself
		{
		for(i = 0;i < 100000 * (chair + 1); ++i);	// Wait until we are hungry

		[forks[chair] lockWhenCondition:FOOD_SERVED];	// Get fork to our left

		if(![forks[(chair + 1) % 5] tryLockWhenCondition:FOOD_SERVED])
			{
			[forks[chair] unlock];					// Drop fork to our left

			printf("Philosopher %d cannot eat without right fork %d\n", chair, (chair + 1) % 5);
			continue;
			}

		printf("Philosopher %d can start eating.\n", chair);	// Start eating

		for (i = 0;i < 100000; ++i)
			if ((i % 10000) == 0)
				printf("Philosopher %d is eating.\n", chair);

		printf("Philosopher %d is done eating.\n", chair);		// Done eating

		[forks[chair] unlock];						// Drop fork to our left
		[forks[(chair + 1) % 5] unlock];			// Drop fork to our right
		}

	[NSThread exit];						// We never get here, but this is 
}											// what we should do

- (int) chair
{
	return chair;
}

@end


int main()
{
NSAutoreleasePool *arp = [NSAutoreleasePool new];
int i;
id p[5];

	// Create the locks
	for (i = 0;i < 5; ++i)
		{
		forks[i] = [[NSConditionLock alloc] initWithCondition:NO_FOOD];
		[forks[i] lock];
		}

	// Create the philosophers
	for (i = 0;i < 5; ++i)
		p[i] = [[Philosopher alloc] init];

	// Have them sit at the table
	for (i = 0;i < 5; ++i)
		[NSThread detachNewThreadSelector:@selector(sitAtChair:)
				  toTarget:p[i] 
				  withObject: (id)i];

	// Now let them all eat
	for (i = 0;i < 5; ++i)
		[forks[i] unlockWithCondition:FOOD_SERVED];
	
	while (1);
}

