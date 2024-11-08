/*
   NSIndexPath.h

   List of indexes that traverse a tree of nested arrays

   Copyright (C) 2017 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    June 2017

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSIndexPath
#define _mGSTEP_H_NSIndexPath

#include <Foundation/NSObject.h>
#include <Foundation/NSRange.h>


@interface NSIndexPath : NSObject  <NSCoding, NSCopying>
{
	NSUInteger *_indexes;
	NSUInteger _length;
}

+ (id) indexPathWithIndex:(NSUInteger)index;
+ (id) indexPathWithIndexes:(const NSUInteger *)indexes length:(NSUInteger)ln;

- (id) init;									// designated initializer
- (id) initWithIndexes:(const NSUInteger *)indexes length:(NSUInteger)ln;
- (id) initWithIndex:(NSUInteger)index;

- (NSIndexPath *) indexPathByAddingIndex:(NSUInteger)index;
- (NSIndexPath *) indexPathByRemovingLastIndex;

- (NSUInteger) indexAtPosition:(NSUInteger)position;
- (NSUInteger) length;

- (void) getIndexes:(NSUInteger *)indexes;
- (void) getIndexes:(NSUInteger *)indexes range:(NSRange)r;

- (NSComparisonResult) compare:(NSIndexPath *)otherObject;

@end


@interface NSIndexPath  (AppKit_UIKit)

+ (NSIndexPath *) indexPathForItem:(NSInteger)item inSection:(NSInteger)sector;
+ (NSIndexPath *) indexPathForRow:(NSInteger)row inSection:(NSInteger)sector;

- (NSInteger) section;
- (NSInteger) item;						// item in section of collection view
- (NSInteger) row;						// row in section of table view

@end

#endif /* _mGSTEP_H_NSIndexPath */
