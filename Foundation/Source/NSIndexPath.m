/*
   NSIndexPath.m

   List of indexes that traverse a tree of nested arrays

   Copyright (C) 2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Feb 2018

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSIndexPath.h>
#include <Foundation/NSException.h>
#include <Foundation/NSCoder.h>



@implementation NSIndexPath

+ (id) indexPathWithIndex:(NSUInteger)index
{
	return [[[self alloc] initWithIndexes:&index length:1] autorelease];
}

+ (id) indexPathWithIndexes:(const NSUInteger *)indexes length:(NSUInteger)ln
{
	return [[[self alloc] initWithIndexes:indexes length:ln] autorelease];
}

- (id) initWithIndexes:(const NSUInteger *)indexes length:(NSUInteger)ln
{
	NSUInteger i;

    if ( (indexes == NULL && ln > 0) || (indexes != NULL && ln == 0) )
		[NSException raise:NSInvalidArgumentException format:@"invalid args"];
	if ( ln > 0 && !(_indexes = malloc(ln * sizeof(NSUInteger))) )
		[NSException raise: NSMallocException format:@"malloc failed"];

    _length = ln;
    for (i = 0; i < _length; i++)
        _indexes[i] = indexes[i];

	return self;
}

- (id) initWithIndex:(NSUInteger)index
{
	return [self initWithIndexes:&index length:1];
}

- (id) init
{
	return [self initWithIndexes:NULL length:0];
}

- (void) dealloc
{
    if (_indexes)
        free(_indexes);

    [super dealloc];
}

- (NSIndexPath *) indexPathByAddingIndex:(NSUInteger)index
{
    NSIndexPath *ip = [[[self class] alloc] init];
    NSUInteger *ix = (NSUInteger *)malloc((_length + 1) * sizeof(NSUInteger));

    memcpy(ix, _indexes, _length * sizeof(NSUInteger));

    ix[_length] = index;
	ip->_indexes = ix;
	ip->_length = _length + 1;

    return [ip autorelease];
}

- (NSIndexPath *) indexPathByRemovingLastIndex
{
    NSIndexPath *ip = [[self class] alloc];
	
	if (_length > 1)
		ip = [ip initWithIndexes:_indexes length:_length - 1];
	else
		ip = [ip init];

	return [ip autorelease];
}

- (NSUInteger) indexAtPosition:(NSUInteger)position
{
    return (position >= _length) ? NSNotFound : _indexes[position];
}

- (void) getIndexes:(NSUInteger *)indexes
{
	memcpy(indexes, _indexes, _length * sizeof(NSUInteger));
}

- (void) getIndexes:(NSUInteger *)indexes range:(NSRange)r
{
	memcpy(indexes, _indexes + r.location, r.length * sizeof(NSUInteger));
}

- (NSComparisonResult) compare:(NSIndexPath *)otherObject
{
	if (otherObject != self)					// nil other is undefined
		{
		NSUInteger ol = [otherObject length];
		NSUInteger i, len = MIN(_length, ol);

		for (i = 0; i < len; i++)
			{
			NSUInteger ix = [self indexAtPosition:i];
			NSUInteger ixo = [otherObject indexAtPosition:i];

			if (ix < ixo)
				return NSOrderedAscending;  // -1L
			if (ix > ixo)
				return NSOrderedDescending; // 1L
			}

		if (_length < ol)
			return NSOrderedAscending;
		if (_length > ol)
			return NSOrderedDescending;
		}

    return NSOrderedSame;  // 0L
}

- (id) copy										{ return [self retain]; }
- (NSUInteger) length							{ return _length; }

- (NSUInteger) hash
{
	NSUInteger i, h = 0;

    for (i = 0; i < _length; i++)
        h += (_indexes[i] << (1 << (i % 8)));

    return h;
}

- (BOOL) isEqual:(id)other
{
	if (other == self)
    	return YES;
    if (other && [other isKindOfClass:[NSIndexPath class]])
		if (_length == [other length])
			return ([self compare:other] == NSOrderedSame);

    return NO;
}

- (NSString *) description;
{
	NSString *s = @"";
	NSUInteger i;

	if (_length)
		s = [NSString stringWithFormat:@"%u", _indexes[0]];
    for (i = 1; i < _length; i++)
		s = [s stringByAppendingFormat:@".%u", _indexes[i]];

	return s;
}

- (void) encodeWithCoder:(NSCoder *)coder
{
	NSUInteger i;

	[coder encodeValueOfObjCType: @encode(NSUInteger) at: &_length];
    for (i = 0; i < _length; i++)
		[coder encodeValueOfObjCType: @encode(NSUInteger) at: &_indexes[i]];
}

- (id) initWithCoder:(NSCoder *)coder
{
	NSUInteger i;

	[coder decodeValueOfObjCType: @encode(NSUInteger) at: &_length];
	if ( _length > 0 && !(_indexes = malloc(_length * sizeof(NSUInteger))) )
		[NSException raise: NSMallocException format:@"malloc failed"];
    for (i = 0; i < _length; i++)
		[coder decodeValueOfObjCType: @encode(NSUInteger) at: &_indexes[i]];

	return self;
}

@end  /* NSIndexPath */


@implementation NSIndexPath  (AppKit_UIKit)

+ (NSIndexPath *) indexPathForItem:(NSInteger)item inSection:(NSInteger)sector
{
    NSUInteger ix[] = {sector, item};

    return [[[self alloc] initWithIndexes:ix length:2] autorelease];
}

+ (NSIndexPath *) indexPathForRow:(NSInteger)row inSection:(NSInteger)sector
{
    NSUInteger ix[] = {sector, row};

    return [[[self alloc] initWithIndexes:ix length:2] autorelease];
}

- (NSInteger) section				{ return [self indexAtPosition:0]; }
- (NSInteger) item					{ return [self indexAtPosition:1]; }
- (NSInteger) row					{ return [self indexAtPosition:1]; }

@end  /* AppKit_UIKit */
