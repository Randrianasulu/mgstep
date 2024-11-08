#import <Foundation/NSObject.h>
#import <Foundation/NSAutoreleasePool.h>

#include <stdio.h>
#include <sys/time.h>
#include <sys/resource.h>


@interface TList : NSObject  
{
  int list[100];          
  int size;
}

- (int) addEntry:(int) num;
- print;

@end

@implementation TList

- (void) dealloc
{
	[super dealloc];
}

- (id) autorelease
{
	return [super autorelease];
}

- (int) addEntry:(int) num
{
	list[size++] = num;
	return size;
}

- print
{
int i;

//	for (i = 0; i < size; ++i)
//		printf ("%i", list[i]);

	return self;                
}

@end



main()
{
	id list;
	id pool;
	struct rusage rusage;
	int i;

	fprintf(stderr," Starting nsauto...\n");

	fprintf(stderr," Creating autorelease pool.\n");
	pool = [NSAutoreleasePool new];

	fprintf(stderr," Adding 10000 list objects to autorelease pool.\n");
	for(i= 0; i < 10000; i++)
		{
		list = [[TList new] autorelease]; 
		[list addEntry: 5];    
		[list addEntry: 6];
		[list addEntry: 3];
		[list print];
		}
	fprintf(stderr,"\n Created and autoreleased 10000 List objects \n");
//	getrusage(RUSAGE_SELF, &rusage);
//	fprintf(stderr," Data seg Mem in use: %d \n", rusage.ru_idrss);
	fprintf(stderr," Releasing Pool\n");
    [pool release];


	fprintf(stderr," Creating autorelease pool.\n");
	pool = [NSAutoreleasePool new];
	fprintf(stderr," Adding 5000 list objects to autorelease pool.\n");
	for(i= 0; i < 5000; i++)
		{
		list = [[TList new] autorelease]; 
		[list addEntry: 5];    
		[list addEntry: 6];
		[list addEntry: 3];
		[list print];
		}
	fprintf(stderr,"\n Created and autoreleased 5000 List objects \n");
 	fprintf(stderr," Releasing Pool\n");
 	[pool release];

	printf("nsauto test complete\n");
	exit (0);
}
