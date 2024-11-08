/*
   NSArray.h

   Ordered collection of objects.

   Copyright (C) 1995-2020 Free Software Foundation, Inc.

   Author:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date:	1995

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSArray
#define _mGSTEP_H_NSArray

#include <Foundation/NSObject.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSRange.h>

@class NSString;
@class NSData;
@class NSDictionary;
@class NSIndexSet;

@protocol _NSArrayProtocols
	<NSCoding, NSCopying, NSMutableCopying, NSFastEnumeration>
@end


@interface NSArray : NSObject  <_NSArrayProtocols>
{
	id *_contents;
	NSUInteger _count;
}

- (id) objectAtIndex:(NSUInteger)index;
- (NSUInteger) count;

@end

@interface NSArray  (NonCore)

+ (id) array;
+ (id) arrayWithArray:(NSArray*)array;
+ (id) arrayWithContentsOfFile:(NSString*)path;
+ (id) arrayWithObject:(id)anObject;
+ (id) arrayWithObjects:(id)firstObj, ...;
+ (id) arrayWithObjects:(id*)objects count:(NSUInteger)count;

- (id) initWithArray:(NSArray*)array;
- (id) initWithObjects:(id*)objects count:(NSUInteger)count;
- (id) initWithObjects:(id)firstObj, ...;
- (id) initWithContentsOfFile:(NSString*)path;

- (NSArray*) arrayByAddingObject:(id)anObject;
- (NSArray*) arrayByAddingObjectsFromArray:(NSArray*)anotherArray;
- (NSArray*) objectsAtIndexes:(NSIndexSet *)indexSet;

- (BOOL) containsObject:(id)anObject;
- (void) getObjects:(id*)objs;
- (void) getObjects:(id*)objs range:(NSRange)aRange;

- (NSUInteger) indexOfObject:(id)anObject;
- (NSUInteger) indexOfObject:(id)anObject inRange:(NSRange)aRange;
- (NSUInteger) indexOfObjectIdenticalTo:(id)anObject;
- (NSUInteger) indexOfObjectIdenticalTo:(id)anObject inRange:(NSRange)aRange;

- (id) lastObject;
- (id) firstObjectCommonWithArray:(NSArray*)otherArray;

- (BOOL) isEqualToArray:(NSArray*)otherArray;

- (void) makeObjectsPerformSelector:(SEL)aSelector;
- (void) makeObjectsPerformSelector:(SEL)aSelector withObject:(id)argument;

- (NSData*) sortedArrayHint;
- (NSArray*) sortedArrayUsingFunction:(NSInteger (*)(id, id, void*))comparator
							  context:(void*)context;
- (NSArray*) sortedArrayUsingFunction:(NSInteger (*)(id, id, void*))comparator
							  context:(void*)context
							  hint:(NSData*)hint;
- (NSArray*) sortedArrayUsingSelector:(SEL)comparator;
- (NSArray*) subarrayWithRange:(NSRange)range;

- (NSString*) componentsJoinedByString:(NSString*)separator;

- (NSEnumerator*) objectEnumerator;
- (NSEnumerator*) reverseObjectEnumerator;

- (NSString*) description;
- (NSString*) descriptionWithLocale:(id)locale;
- (NSString*) descriptionWithLocale:(id)locale indent:(unsigned int)level;

- (BOOL) writeToFile:(NSString*)path atomically:(BOOL)useAuxilliaryFile;

@end

@interface NSArray  (NSArrayPathExtensions)		// s/b in NSPathUtilities

- (NSArray*) pathsMatchingExtensions:(NSArray*)filterTypes;

@end



@interface NSMutableArray : NSArray
{
	NSUInteger _capacity;
}

- (id) initWithCapacity:(NSUInteger)numItems;
- (void) addObject:(id)anObject;
- (void) replaceObjectAtIndex:(NSUInteger)index withObject:(id)anObject;
- (void) insertObject:(id)anObject atIndex:(NSUInteger)index;
- (void) removeObjectAtIndex:(NSUInteger)index;

@end

@interface NSMutableArray  (NSExtendedMutableArray)

+ (id) arrayWithCapacity:(NSUInteger)numItems;
+ (id) initWithCapacity:(NSUInteger)numItems;

- (void) addObjectsFromArray:(NSArray*)otherArray;
- (void) replaceObjectsInRange:(NSRange)aRange
		  withObjectsFromArray:(NSArray*)anArray;
- (void) replaceObjectsInRange:(NSRange)aRange
		  withObjectsFromArray:(NSArray*)anArray
		  range:(NSRange)anotherRange;
- (void) setArray:(NSArray *)otherArray;

- (void) removeAllObjects;
- (void) removeLastObject;
- (void) removeObject:(id)anObject;
- (void) removeObject:(id)anObject inRange:(NSRange)aRange;
- (void) removeObjectIdenticalTo:(id)anObject;
- (void) removeObjectIdenticalTo:(id)anObject inRange:(NSRange)aRange;
- (void) removeObjectsInArray:(NSArray*)otherArray;
- (void) removeObjectsInRange:(NSRange)aRange;

- (void) removeObjectsAtIndexes:(NSIndexSet*)indexes;
- (void) insertObjects:(NSArray *)objects atIndexes:(NSIndexSet *)indexes;
- (void) replaceObjectsAtIndexes:(NSIndexSet *)idx withObjects:(NSArray *)array;

- (void) removeObjectsFromIndices:(NSUInteger *)indices		// OS X deprecated
					   numIndices:(NSUInteger)count;

- (void) sortUsingFunction:(NSInteger(*)(id,id,void*))compare
				   context:(void*)context;
- (void) sortUsingSelector:(SEL) aSelector;

@end

#endif /* _mGSTEP_H_NSArray */
