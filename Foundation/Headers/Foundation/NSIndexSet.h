/*
   NSIndexSet.h

   Efficiently store sorted integer range sets

   Copyright (C) 2009 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	October 2009

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSIndexSet
#define _mGSTEP_H_NSIndexSet

#include <Foundation/NSObject.h>
#include <Foundation/NSRange.h>


@interface NSIndexSet : NSObject  <NSCopying, NSCoding, NSMutableCopying>
{
	NSRange *_iranges;
	NSUInteger _nranges;
	NSUInteger _count;
}

+ (id) indexSet;
+ (id) indexSetWithIndex:(NSUInteger)value;
+ (id) indexSetWithIndexesInRange:(NSRange)range;

- (id) initWithIndex:(NSUInteger)value;
- (id) initWithIndexesInRange:(NSRange)range;
- (id) initWithIndexSet:(NSIndexSet *)indexSet;

- (NSUInteger) firstIndex;
- (NSUInteger) lastIndex;

- (NSUInteger) indexGreaterThanIndex:(NSUInteger)value;
- (NSUInteger) indexLessThanIndex:(NSUInteger)value;

- (NSUInteger) indexGreaterThanOrEqualToIndex:(NSUInteger)value;
- (NSUInteger) indexLessThanOrEqualToIndex:(NSUInteger)value;

- (BOOL) containsIndex:(NSUInteger)value;
- (BOOL) containsIndexesInRange:(NSRange)range;
- (BOOL) containsIndexes:(NSIndexSet *)indexSet;
- (BOOL) intersectsIndexesInRange:(NSRange)range;
- (BOOL) isEqualToIndexSet:(NSIndexSet *)indexSet;

- (NSUInteger) getIndexes:(NSUInteger *)indexBuffer
				 maxCount:(NSUInteger)bufferSize
				 inIndexRange:(NSRangePointer)range;

- (NSUInteger) count;
- (NSUInteger) countOfIndexesInRange:(NSRange)value;

@end  /* NSIndexSet */


@interface NSMutableIndexSet : NSIndexSet
{
	NSUInteger _capacity;
}

- (void) addIndexes:(NSIndexSet *)indexSet;
- (void) removeIndexes:(NSIndexSet *)indexSet;
- (void) removeAllIndexes;

- (void) addIndex:(NSUInteger)value;
- (void) removeIndex:(NSUInteger)value;

- (void) addIndexesInRange:(NSRange)range;
- (void) removeIndexesInRange:(NSRange)range;

- (void) shiftIndexesStartingAtIndex:(NSUInteger)startIndex by:(int)delta;

@end  /* NSMutableIndexSet */

#endif  /* _mGSTEP_H_NSIndexSet */
