/*
   NSSet.h

   Unordered collection of unique objects

   Copyright (C) 2005 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Nov 2005

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSSet
#define _mGSTEP_H_NSSet

#include <Foundation/NSObject.h>
#include <Foundation/NSMapTable.h>

@class NSString;
@class NSArray;
@class NSDictionary;
@class NSEnumerator;


@interface NSSet : NSObject  <NSCoding, NSCopying, NSMutableCopying>

+ (id) alloc;
+ (id) set;
+ (id) setWithArray:(NSArray*)array;
+ (id) setWithObject:(id)anObject;
+ (id) setWithObjects:(id)firstObj,...;
+ (id) setWithObjects:(id*)objects count:(NSUInteger)count;
+ (id) setWithSet:(NSSet*)aSet;

- (id) initWithArray:(NSArray*)array;
- (id) initWithObjects:(id)firstObj,...;
- (id) initWithObject:(id)firstObj arglist:(va_list)arglist;
- (id) initWithSet:(NSSet*)set copyItems:(BOOL)flag;
- (id) initWithSet:(NSSet*)set;

- (NSArray*) allObjects;							// Querying the Set
- (id) anyObject;
- (BOOL) containsObject:(id)anObject;

- (void) makeObjectsPerformSelector:(SEL)aSelector;	// Send message to elements
- (void) makeObjectsPerformSelector:(SEL)aSelector withObject:(id)anObject;

- (BOOL) intersectsSet:(NSSet*)otherSet;			// Comparing Sets
- (BOOL) isEqualToSet:(NSSet*)otherSet;
- (BOOL) isSubsetOfSet:(NSSet*)otherSet;

- (NSString*) description;							// Describe the Set
- (NSString*) descriptionWithLocale:(id)locale;
- (NSString*) descriptionWithLocale:(id)locale indent:(unsigned int)level;

@end


@interface NSSet (ConcreteSet)

- (id) initWithObjects:(id*)objects count:(NSUInteger)count;

- (NSUInteger) count;
- (id) member:(id)anObject;
- (NSEnumerator*) objectEnumerator;

@end


@interface NSMutableSet : NSSet

+ (id) setWithCapacity:(NSUInteger)numItems;

- (void) addObjectsFromArray:(NSArray*)array;
- (void) unionSet:(NSSet*)other;
- (void) setSet:(NSSet*)other;

- (void) intersectSet:(NSSet*)other;
- (void) minusSet:(NSSet*)other;

@end


@interface NSMutableSet (ConcreteMutableSet)

- (id) initWithCapacity:(NSUInteger)numItems;

- (void) addObject:(id)object;
- (void) removeObject:(id)object;
- (void) removeAllObjects;

@end


@interface NSCountedSet : NSMutableSet
{
	NSMapTable *_table;
}

- (id) initWithObjects:(id*)objects count:(NSUInteger)count;
- (id) initWithSet:(NSSet*)set copyItems:(BOOL)flag;

- (void) addObject:(id)object;						// Add and remove entries
- (void) removeObject:(id)object;
- (void) removeAllObjects;

- (NSUInteger) countForObject:(id)anObject;			// Query the NSCountedSet

@end

#endif /* _mGSTEP_H_NSSet */
