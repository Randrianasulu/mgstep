/*
   NSOrderedSet.h

   Ordered collection of unique objects

   Copyright (C) 2017 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    June 2017

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSOrderedSet
#define _mGSTEP_H_NSOrderedSet

#include <Foundation/NSObject.h>
#include <Foundation/NSArray.h>

@class NSString;
@class NSEnumerator;
@class NSIndexSet;

// ** ordered set is faster than testing objects in array for membership


@interface NSOrderedSet : NSObject  <NSCoding, NSCopying, NSMutableCopying>
{
	NSArray *_array;
	NSSet   *_set;
}

- (id) init;									// designated initializer

- (NSUInteger) count;
- (NSUInteger) indexOfObject:(id)object;
- (id) objectAtIndex:(NSUInteger)ix;

@end


@interface NSOrderedSet  (NSOrderedSetCreation)

+ (id) orderedSet;
+ (id) orderedSetWithObject:(id)object;
+ (id) orderedSetWithObjects:(const id [])objects count:(NSUInteger)c;
+ (id) orderedSetWithObjects:(id)firstObj, ...;

+ (id) orderedSetWithOrderedSet:(NSOrderedSet *)set;
+ (id) orderedSetWithOrderedSet:(NSOrderedSet *)set
						  range:(NSRange)r
						  copyItems:(BOOL)flag;
+ (id) orderedSetWithArray:(NSArray *)array;
+ (id) orderedSetWithArray:(NSArray *)array range:(NSRange)r copyItems:(BOOL)flag;

+ (id) orderedSetWithSet:(NSSet *)set;
+ (id) orderedSetWithSet:(NSSet *)set copyItems:(BOOL)flag;


- (id) initWithObjects:(const id [])objects count:(NSUInteger)c;
- (id) initWithObject:(id)object;
- (id) initWithObjects:(id)firstObj, ...;

- (id) initWithOrderedSet:(NSOrderedSet *)set;
- (id) initWithOrderedSet:(NSOrderedSet *)set copyItems:(BOOL)flag;
- (id) initWithOrderedSet:(NSOrderedSet *)set range:(NSRange)r copyItems:(BOOL)flag;

- (id) initWithArray:(NSArray *)array;
- (id) initWithArray:(NSArray *)set copyItems:(BOOL)flag;
- (id) initWithArray:(NSArray *)set range:(NSRange)range copyItems:(BOOL)flag;

- (id) initWithSet:(NSSet *)set;
- (id) initWithSet:(NSSet *)set copyItems:(BOOL)flag;

@end


@interface NSOrderedSet  (NSExtendedOrderedSet)		// FIX ME incomplete

- (id) firstObject;
- (id) lastObject;

- (void) getObjects:(id __unsafe_unretained [])objects range:(NSRange)range;
- (NSArray *) objectsAtIndexes:(NSIndexSet *)indexes;

- (BOOL) isEqualToOrderedSet:(NSOrderedSet *)other;

- (BOOL) containsObject:(id)object;
- (BOOL) intersectsOrderedSet:(NSOrderedSet *)other;
- (BOOL) intersectsSet:(NSSet *)set;

- (BOOL) isSubsetOfOrderedSet:(NSOrderedSet *)other;
- (BOOL) isSubsetOfSet:(NSSet *)set;

- (NSString *) description;

@end


@interface NSMutableOrderedSet : NSOrderedSet

+ (id) orderedSetWithCapacity:(NSUInteger)numItems;

- (id) initWithCapacity:(NSUInteger)numItems;		// designated initializer

- (void) replaceObjectAtIndex:(NSUInteger)ix withObject:(id)object;
- (void) insertObject:(id)object atIndex:(NSUInteger)ix;
- (void) removeObjectAtIndex:(NSUInteger)ix;

@end


@interface NSMutableOrderedSet (NSExtendedMutableOrderedSet)

- (void) addObject:(id)object;
- (void) addObjects:(const id [])objects count:(NSUInteger)count;
- (void) addObjectsFromArray:(NSArray *)array;

- (void) insertObjects:(NSArray *)objects atIndexes:(NSIndexSet *)indexes;

- (void) setObject:(id)object atIndex:(NSUInteger)ix;
- (void) setObject:(id)object atIndexedSubscript:(NSUInteger)ix;

- (void) exchangeObjectAtIndex:(NSUInteger)x1 withObjectAtIndex:(NSUInteger)x2;
- (void) moveObjectsAtIndexes:(NSIndexSet *)indexes toIndex:(NSUInteger)ix;

- (void) replaceObjectsInRange:(NSRange)range
					withObjects:(const id [])objects
					count:(NSUInteger)count;
- (void) replaceObjectsAtIndexes:(NSIndexSet *)indexes
					withObjects:(NSArray *)objects;

- (void) removeAllObjects;
- (void) removeObject:(id)object;
- (void) removeObjectsInRange:(NSRange)range;
- (void) removeObjectsInArray:(NSArray *)array;
- (void) removeObjectsAtIndexes:(NSIndexSet *)indexes;

- (void) intersectOrderedSet:(NSOrderedSet *)other;
- (void) minusOrderedSet:(NSOrderedSet *)other;
- (void) unionOrderedSet:(NSOrderedSet *)other;

- (void) intersectSet:(NSSet *)other;
- (void) minusSet:(NSSet *)other;
- (void) unionSet:(NSSet *)other;

@end

#endif /* _mGSTEP_H_NSOrderedSet */
