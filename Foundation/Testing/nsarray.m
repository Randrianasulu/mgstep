#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSString.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSIndexSet.h>
#include <stdlib.h>
#include <assert.h>

static int
compare(id elem1, id elem2, void *context)
{
	return (long)[elem1 performSelector:@selector(compare:) withObject:elem2];
}

void
print_array(char *msg, NSArray *a)
{
    id i, enumerator = [a objectEnumerator];
	
	if (msg)
		printf("%s\n", msg);
    while ((i = [enumerator nextObject]))
      printf("%s ", [[i description] cString]);
    printf("\n");
}


int
main()
{
	id a, b, c, d, e, f, g, h;			/* arrays */
	id enumerator;
	id i;
	id s = @"Hello World\n";
	id pool = [[NSAutoreleasePool alloc] init];
	id o1, o2, o3;
	unsigned int p;

//  [NSAutoreleasePool enableDoubleReleaseCheck:YES];

  o1 = [NSNumber numberWithInt:1];
  o2 = [NSNumber numberWithInt:2];
  o3 = [NSNumber numberWithInt:3];
    printf("Method: -arrayWithObject:\n");
  a = [[[NSArray arrayWithObject:o1] arrayByAddingObject:o2] arrayByAddingObject:o3];
  printf("%u,%u,%u\n", [o1 retainCount], [o2 retainCount], [o3 retainCount]);
  b = [[a copy] autorelease];
  printf("%u,%u,%u\n", [o1 retainCount], [o2 retainCount], [o3 retainCount]);
  c = [[b mutableCopy] autorelease];
  printf("%u,%u,%u\n", [o1 retainCount], [o2 retainCount], [o3 retainCount]);
  d = [[c copy] autorelease];
  printf("%u,%u,%u\n", [o1 retainCount], [o2 retainCount], [o3 retainCount]);

  // NSArray tests
  {
    // Class methods for allocating and initializing an array
    printf("Method: +array\n");
    a = [NSArray array];
    if ([a count] == 0)
      printf("Empty array count is zero\n");
    else
      printf("Error: empty array count is not zero\n");

    printf("Method: +arrayWithObject:\n    ");
    b = [NSArray arrayWithObject: s];
    printf("NSArray has count %d\n", [b count]);
    if ([b count] != 1)
      printf("Error: count != 1\n");

    printf("Method: +arrayWithObjects:...\n    ");
    c = [NSArray arrayWithObjects: 
		 [NSObject class],
		 [NSArray class],
		 [NSMutableArray class],
		 nil];
    printf("NSArray has count %d\n", [c count]);
    if ([c count] != 3)
      printf("Error: count != 3\n");
  }

  {
    // Instance methods for allocating and initializing an array
    printf("Method: -arrayByAddingObject:\n    ");
    d = [c arrayByAddingObject: s];
    printf("NSArray has count %d\n", [c count]);
    if ([d count] != 4)
      printf("Error: count != 4\n");

    printf("Method: -arrayByAddingObjectsFromArray:\n    ");
    e = [c arrayByAddingObjectsFromArray: b];
    printf("NSArray has count %d\n", [c count]);
    if ([e count] != 4)
      printf("Error: count != 4\n");
  }

  {
    // Querying the arra
    assert([c containsObject:[NSObject class]]);

    p = [e indexOfObject:@"Hello World\n"];
    if (p == NSNotFound)
      printf("Error: index of object not found\n");
    else
      printf("Index of object is %d\n", p);

    p = [e indexOfObjectIdenticalTo:s];
    if (p == NSNotFound)
      printf("Error: index of identical object not found\n");
    else
      printf("Index of identical object is %d\n", p);

    assert([c lastObject]);
    printf("Classname at index 2 is %s\n", 
			[[[c objectAtIndex:2] description] cString]);

	print_array("Forward enumeration", e);

    printf("Reverse enumeration\n");
    enumerator = [e reverseObjectEnumerator];
    while ((i = [enumerator nextObject]))
      printf("%s ", [[i description] cString]);
    printf("\n");
  }

  {
    // Sending messages to elements
    [c makeObjectsPerformSelector:@selector(description)];

    //[c makeObjectsPerformSelector:@selector(isEqual:) withObject:@"NSArray"];
  }

	{
    assert([d firstObjectCommonWithArray:e]);			// Comparing arrays

	if ([d isEqualToArray: d])
		printf("NSArray is equal to itself\n");
	else
		printf("Error: NSArray is not equal to itself\n");

	if ([d isEqualToArray: e])
		printf("NSArrays are equal\n");
	else
		printf("Error: NSArrays are not equal\n");
	}

	{
    NSRange r = NSMakeRange(0, 3);						// Deriving new arrays

    f = [NSMutableArray array];
    [f addObject: @"Lions"];
    [f addObject: @"Tigers"];
    [f addObject: @"Bears"];
    [f addObject: @"Penguins"];
    [f addObject: @"Giraffes"];

    enumerator = [f objectEnumerator];
    while ((i = [enumerator nextObject]))
      printf("%s ", [i cString]);
    printf("\n");

    printf("Method: -sortedArrayUsingSelector:\n");
    g = [f sortedArrayUsingSelector: @selector(compare:)];
    printf("Method: -sortedArrayUsingFunction:context:\n    ");
    h = [f sortedArrayUsingFunction: compare context: NULL];
    
    enumerator = [g objectEnumerator];
    while ((i = [enumerator nextObject]))
      printf("%s ", [i cString]);
    printf("\n");

    if (([g isEqualToArray: h]) && (![g isEqualToArray: f]))
      printf("Sorted arrays are correct\n");
    else
      printf("Error: Sorted arrays are not correct\n");

    printf("Method: -reverseObjectEnumerator  (remove 2 objs and list)\n    ");
    enumerator = [f reverseObjectEnumerator];
	[enumerator nextObject];
	[enumerator nextObject];
	print_array(NULL, [enumerator allObjects]);


    printf("Method: -subarrayWithRange:\n    ");
    f = [e subarrayWithRange: r];

    printf("NSArray has count %d\n", [f count]);
    if ([f count] != 3)
      printf("Error: count != 3\n");

	print_array(NULL, f);

    if ([f isEqualToArray: c])
      printf("Subarray is correct\n");
    else
      printf("Error: Subarray does not have correct elements\n");
  }

  {
    // Joining string elements
    printf("Method: -componentsJoinedByString:\n    ");
    i = [c componentsJoinedByString: @"/"];
    if ([i isEqual: @"NSObject/NSArray/NSMutableArray"])
      printf("%s is correct\n", [i cString]);
    else
      {
	printf("Error: %s is not correct\n", [i cString]);
	printf("Should be NSObject/NSArray/NSMutableArray\n");
      }
  }

  {
    // Creating a string description of the array
    /* What do the -description methods do?
       [e description]
       [e descriptionWithLocale:]
       [e descriptionWithLocale: indent:]
       */
  }

  // NSMutableArray tests
  printf("*** Start of NSMutableArray tests\n");
  {
    // Creating and initializing an NSMutableArray
    f = [NSMutableArray arrayWithCapacity: 10];
    assert(f);
    f = [[NSMutableArray alloc] initWithCapacity: 10];
    [f release];
    assert(f);

    f = [[NSMutableArray alloc] initWithObjects: @"one", @"two", @"three", @"four", nil];
	[f addObject: @"five"];
    assert([f count] == 5);
  }

  {
    // Adding objects
    f = [e mutableCopy];
    assert([f count]);

    printf("Method -addObject:[NSObject class]\n    ");
    [f addObject:[NSObject class]];
    printf("NSMutableArray has count %d\n", [f count]);
    if ([f count] != 5)
      printf("Error: count != 5\n");

    printf("Method -addObjectsFromArray:\n    ");
    [f addObjectsFromArray: c];

    printf("NSMutableArray has count %d\n", [f count]);
    if ([f count] != 8)
      printf("Error: count != 8\n");

	print_array(NULL, f);

    printf("Method -insertObject: [NSMutableArray class] atIndex: 2\n    ");
    [f insertObject: [NSMutableArray class] atIndex: 2];
	print_array(NULL, f);
  }

  g = [f mutableCopy];
  h = [f mutableCopy];

  {
    // Removing objects
    NSUInteger ind[] = {1, 0, 0, 4, 5, 6, 7};

    printf("Method -removeAllObjects\n");
    printf("Array count is %d\n", [h count]);
    [h removeAllObjects];
    printf("Array count is %d\n", [h count]);
    if ([h count] != 0)
      printf("Error: count != 0\n");

    h = [f mutableCopy];

    printf("Method -removeLastObject\n    ");
    [f removeLastObject];
	print_array(NULL, f);

    printf("Method -removeObject: [NSObject class]\n    ");
    [f removeObject: [NSObject class]];
	print_array(NULL, f);

    printf("Method -removeObjectIdenticalTo: [NSArray class]\n    ");
    [f removeObjectIdenticalTo: [NSArray class]];
	print_array(NULL, f);

    printf("Method -removeObjectAtIndex: 2\n    ");
    [f removeObjectAtIndex: 2];
	print_array(NULL, f);

printf("Method -removeObjectsFromIndices: {1, 0, 0, 4, 5, 6, 7} " "numIndices: 7\n");
	printf("Array before removal:  ");
	print_array(NULL, g);

    [g removeObjectsFromIndices: ind numIndices: 7];
    printf("Array after removal:  ");
	print_array(NULL, g);

    if ([f isEqualToArray: g])
      printf("Remove methods worked properly\n");
    else
      printf("Error: remove methods failed\n");

    printf("Method -removeObjectsInArray:\n");
    printf("Receiver array\n");
    enumerator = [h objectEnumerator];
    while ((i = [enumerator nextObject]))
      printf("%s ", [[i description] cString]);
    printf("\n");
 
	print_array("Removing objects in this array", c);
    [h removeObjectsInArray: c];

    printf("Array count is %d\n", [h count]);
    if ([h count] != 1)
      printf("Error: count != 1\n");

    printf("%s", [[h objectAtIndex: 0] cString]);
    if ([[h objectAtIndex: 0] isEqual: s])
      printf("-removeObjectsInArray: worked correctly\n");
    else
      printf("Error: object in array is not correct\n");
  }

  {
    // Replacing objects
    c = [[c mutableCopy] autorelease];
    printf("Method -replaceObjectAtIndex: 2 withObject:[NSString class]\n");
    [c replaceObjectAtIndex: 2 withObject:[NSString class]];
	print_array(NULL, c);

    printf("Method -setArray:\n");
    [h setArray: f];
	print_array(NULL, h);

    if ([h isEqualToArray: h])
      printf("-setArray worked properly\n");
    else
      printf("Error: array is incorrect\n");
  }


// test02
	{ // indexes are as before removeObjectsAtIndexes begins
	   NSMutableArray *has=[NSMutableArray arrayWithObjects: @"one", @"a", @"two", @"b", @"three", @"four", nil];
	   NSMutableIndexSet *idx=[NSMutableIndexSet indexSetWithIndex:1];
	   NSArray *wants;
		[idx addIndex:3];
	  [has removeObjectsAtIndexes:idx];
	  wants=[NSArray arrayWithObjects: @"one", @"two", @"three", @"four", nil];
    if ([has isEqualToArray: wants])
      printf("PASS:  removeObjectsAtIndexes:\n");
    else
      printf("FAIL:  removeObjectsAtIndexes:\n");
	//  XCTAssertEqualObjects(has, wants, @"has: %@", has);
	}


// test03
	{ // indexes are after inserting previous indexes
	NSMutableArray *has=[NSMutableArray arrayWithObjects: @"one", @"two", @"three", @"four", nil];
	 NSArray *add=[NSArray arrayWithObjects: @"a", @"b", nil];
	 NSArray *wants;
	  NSMutableIndexSet *idx=[NSMutableIndexSet indexSetWithIndex:1];
	  [idx addIndex:3];
	   [has insertObjects:add atIndexes:idx];
	   wants=[NSArray arrayWithObjects: @"one", @"a", @"two", @"b", @"three", @"four", nil];
    if ([has isEqualToArray: wants])
      printf("PASS:  insertObjects:atIndexes:\n");
    else
      printf("FAIL:  insertObjects:atIndexes:\n");
	//  XCTAssertEqualObjects(has, wants, @"has: %@", has);
	}


// test04
	{ // indexes may all append to end
	NSMutableArray *has=[NSMutableArray arrayWithObjects: @"one", @"two", @"three", @"four", nil];
	NSArray *add=[NSArray arrayWithObjects: @"a", @"b", nil];
	NSArray *wants;
	NSMutableIndexSet *idx=[NSMutableIndexSet indexSetWithIndex:5];
	[idx addIndex:4];
	[has insertObjects:add atIndexes:idx];
	wants=[NSArray arrayWithObjects: @"one", @"two", @"three", @"four", @"a", @"b", nil];
    if ([has isEqualToArray: wants])
      printf("PASS:  insertObjects:atIndexes: 2\n");
    else
      printf("FAIL:  insertObjects:atIndexes: 2\n");
	// XCTAssertEqualObjects(has, wants, @"has: %@", has);
	}


// test05
	{
	NSMutableArray *has=[NSMutableArray arrayWithObjects: @"one", @"two", @"three", @"four", nil];
	NSArray *gets, *wants;
	NSMutableIndexSet *idx=[NSMutableIndexSet indexSetWithIndex:1];

	[idx addIndex:3];
	gets=[has objectsAtIndexes:idx];
	wants=[NSArray arrayWithObjects: @"two", @"four", nil];
//	XCTAssertEqualObjects(gets, wants, @"has: %@", gets);
    if ([gets isEqualToArray: wants])
      printf("PASS:  objectsAtIndexes:\n");
    else
      printf("FAIL:  objectsAtIndexes:\n");
	}

  {
    // Sorting Elements
    //[ sortUsingFunction: context:];
    //[ sortUsingSelector:];
  }

  [pool release];
  printf("nsarray test complete\n");

  exit(0);
}
