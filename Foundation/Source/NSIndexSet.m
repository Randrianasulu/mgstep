/*
   NSIndexSet.m

   Efficiently store sorted integer range sets

   Copyright (C) 2009-2016 Free Software Foundation, Inc.

   Author:  Dr. H. Nikolaus Schaller
   Date: 	Nov 2005

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSIndexSet.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSString.h>



@implementation NSIndexSet

+ (id) indexSet
{
	return [[self new] autorelease];
}

+ (id) indexSetWithIndex:(NSUInteger)value
{
	return [[[self alloc] initWithIndex:value] autorelease];
}

+ (id) indexSetWithIndexesInRange:(NSRange)range
{
	return [[[self alloc] initWithIndexesInRange:range] autorelease];
}

- (id) initWithIndex:(NSUInteger)value
{
	return [self initWithIndexesInRange:NSMakeRange(value, 1)];
}

- (id) initWithIndexesInRange:(NSRange)range
{
	_iranges = (NSRange *)malloc(sizeof(_iranges[0]));
	_iranges[0] = range;
	_nranges = 1;

	return self;
}

- (id) initWithIndexSet:(NSIndexSet *)indexSet
{
	int size;

	_nranges = indexSet->_nranges;
	size = _nranges * sizeof(_iranges[0]);
	_iranges = (NSRange *)malloc(size);
	memcpy(_iranges, indexSet->_iranges, size);

	return self;
}

- (void) dealloc;
{
	if (_iranges)
		free(_iranges);
	[super dealloc];
}

- (id) copy		   { return [self retain]; }
- (id) mutableCopy { return [[NSMutableIndexSet alloc] initWithIndexSet:self]; }

- (NSUInteger) firstIndex
{
	return (_nranges == 0) ? NSNotFound : _iranges[0].location;
}

- (NSUInteger) lastIndex
{
	return (_nranges == 0) ? NSNotFound : NSMaxRange(_iranges[_nranges-1]) - 1;
}

- (NSUInteger) indexGreaterThanIndex:(NSUInteger)value
{
	NSUInteger i;

	for (i = 0; i < _nranges; i++)
		{
		if (_iranges[i].location > value)
			return _iranges[i].location;			// range segment beyond
		if (NSLocationInRange(value+1, _iranges[i]))
			return value+1;			// next index falls into this subrange
		}

	return NSNotFound;
}

- (NSUInteger) indexGreaterThanOrEqualToIndex:(NSUInteger)value
{
	NSUInteger i;

	for (i = 0; i < _nranges; i++)
		{
		if (_iranges[i].location > value)
			return _iranges[i].location;			// range segment is beyond
		if (NSLocationInRange(value, _iranges[i]))
			return value;							// falls into this subrange
		}

	return NSNotFound;
}

- (NSUInteger) indexLessThanIndex:(NSUInteger)value
{
	NSUInteger i = _nranges;

	while (i-- > 0)
		{
		if (NSMaxRange(_iranges[i]) <= value)
			return NSMaxRange(_iranges[i]) - 1;		// range segment before
		if (NSLocationInRange(value-1, _iranges[i]))
			return value-1;			// previous index falls into this subrange
		}

	return NSNotFound;
}

- (NSUInteger) indexLessThanOrEqualToIndex:(NSUInteger)value
{
	NSUInteger i = _nranges;

	while (i-- > 0)
		{
		if (NSMaxRange(_iranges[i]) <= value)
			return NSMaxRange(_iranges[i])-1;	// range segment before
		if (NSLocationInRange(value, _iranges[i]))
			return value;						// index falls in this subrange
		}

	return NSNotFound;
}

- (BOOL) containsIndex:(NSUInteger)value
{
	NSUInteger i;

	for (i = 0; i < _nranges; i++)
		if (NSLocationInRange(value, _iranges[i]))
			return YES;

	return NO;
}

- (BOOL) containsIndexesInRange:(NSRange)range
{
	NSUInteger i;	// we could even search faster by splitting the total set
					// of ranges in halves because they are sorted
	for (i = 0; i < _nranges; i++)
		if (NSEqualRanges(NSIntersectionRange(range, _iranges[i]), range))
			return YES;

	return NO;
}

- (BOOL) containsIndexes:(NSIndexSet *)indexSet
{
	NSUInteger i;					// contains ALL indexes of the other set

	for (i = 0; i < indexSet->_nranges; i++)
		if (![self containsIndexesInRange: indexSet->_iranges[i]])
			return NO;
	
	return YES;
}

- (BOOL) intersectsIndexesInRange:(NSRange)range
{
	NSUInteger i;

	for (i = 0; i < _nranges; i++)
		if (NSIntersectionRange(range, _iranges[i]).length != 0)
			return YES;

	return NO;
}

- (BOOL) isEqual:(id)indexSet
{
	return [indexSet isKindOfClass:isa] && [self isEqualToIndexSet:indexSet];
}

- (BOOL) isEqualToIndexSet:(NSIndexSet *)indexSet
{
	NSUInteger i;

	if (_nranges != indexSet->_nranges)
		return NO;
	for (i = 0; i < _nranges; i++)
		if (!NSEqualRanges(_iranges[i], indexSet->_iranges[i]))
			return NO;
	
	return YES;
}

- (NSUInteger) getIndexes:(NSUInteger *)buffer
				 maxCount:(NSUInteger)bufferSize
				 inIndexRange:(NSRangePointer)indexRange
{
	NSUInteger i;
	NSUInteger c0 = bufferSize;

	if (!indexRange)
		{ // unlimited
		for(i = 0; i < _nranges && bufferSize > 0; i++)
			{
			NSUInteger val = _iranges[i].location;
			NSUInteger last = NSMaxRange(_iranges[i]);

			while (val < last && bufferSize > 0)
				*buffer++ = val++, bufferSize--;
		}	}
	else
		{
		for(i = 0; i < _nranges && NSMaxRange(_iranges[i]) < indexRange->location; i++)
			; // find first relevant block
		for(; i<_nranges && bufferSize > 0; i++)
			{ // extract next index block
			NSUInteger val = _iranges[i].location;
			NSUInteger last = NSMaxRange(_iranges[i]);

			if (val < indexRange->location)
				val = indexRange->location;	// don't start before requested range
			if (last > NSMaxRange(*indexRange))
				last = NSMaxRange(*indexRange);	// limit to end of requested range
			if (last < val)
				break;	// already done and nothing more to add
			while (val < last && bufferSize > 0)
				*buffer++ = val++, bufferSize--;
			}
		// update indexRange
		}

	return c0 - bufferSize;			// number of entries copied
}

- (NSUInteger) countOfIndexesInRange:(NSRange)value
{
	NSUInteger i;
	NSUInteger count = 0;

	for(i = 0; i < _nranges; i++)
		count += NSIntersectionRange(value, _iranges[i]).length;

	return count;
}

- (NSUInteger) count
{
	if (!_count)									// cache value
		{
		NSUInteger i;

		_count = 1;
		for(i = 0; i < _nranges; i++)
			_count += _iranges[i].length;			// sum up
		}

	return _count-1;
}

- (NSUInteger) hash
{
	return (_count) ? _count : [self count];	// should be a good indicator
}

- (NSString *) description
{
	NSString *d = nil;
	NSUInteger i;

	if (_nranges == 0)
		return @"<empty>";

	d = [NSString stringWithFormat: @"Num ranges: %u, indexes: ", _nranges];

	for (i = 0; i < _nranges; i++)
		{
		BOOL a = (_iranges[i].length == 1);

		if (a)
			d = [d stringByAppendingFormat: @" %u", _iranges[i].location];
		else
			d = [d stringByAppendingFormat: @" %u-%u",
						_iranges[i].location, NSMaxRange(_iranges[i]) - 1];
		}

	return d;
}

- (id) initWithCoder:(NSCoder*)c
{
	if ((self = [super init]))
		{
		[c decodeValueOfObjCType:@encode(NSUInteger) at:&_nranges];
		_iranges = (NSRange *) malloc(_nranges*sizeof(_iranges[0]));
		[c decodeArrayOfObjCType:@encode(NSRange) count:_nranges at:_iranges];
		}

	return self;
}

- (void) encodeWithCoder:(NSCoder*)c
{
	[c encodeValueOfObjCType:@encode(NSUInteger) at:&_nranges];
	[c encodeArrayOfObjCType:@encode(NSRange) count:_nranges at:_iranges];
}

@end

/* ****************************************************************************

	NSMutableIndexSet

** ***************************************************************************/

@implementation NSMutableIndexSet

- (id) initWithIndex:(NSUInteger)value
{
	if (self = [super initWithIndex:value])
		_capacity = _nranges;

	return self;
}

- (id) initWithIndexesInRange:(NSRange)range
{
	if (self = [super initWithIndexesInRange:range])
		_capacity = _nranges;

	return self;
}

- (id) initWithIndexSet:(NSIndexSet *)indexSet;
{
	if (self = [super initWithIndexSet:indexSet])
		_capacity = _nranges;

	return self;
}

- (id) copy
{
	return [[NSIndexSet alloc] initWithIndexSet:self];
}

- (void) addIndexesInRange:(NSRange)range
{
	NSUInteger i;

	DBLog(@"addIndexesInRange: %@", NSStringFromRange(range));

	for (i = 0; i < _nranges; i++)
		{
		NSRange head = (NSRange){range.location, range.length + 1}; // head join
		NSRange r = (NSRange){_iranges[i].location, _iranges[i].length+1};

		if (NSIntersectionRange(head, r).length != 0)  // tests for head or tail join
			{
			_iranges[i] = NSUnionRange(range, _iranges[i]);	// expand existing range
			_count = 0;										// recache

			r = (NSRange){_iranges[i].location, _iranges[i].length+1};

			while (i+1 < _nranges && NSIntersectionRange(r, _iranges[i+1]).length != 0)
				{
				int shift = sizeof(_iranges[0])*(_nranges-i-2);
						// merge with all following ranges that are now covered
				_iranges[i] = NSUnionRange(_iranges[i], _iranges[i+1]);	// extend as/if necessary
#if 0
				NSLog(@"memmove(%d, %d, %d) of %d", i+1, i+2, _nranges-i-2, _nranges);
#endif
				if (shift > 0)
					memmove(&_iranges[i+1], &_iranges[i+2], shift);	// delete range that has been merged
				_nranges--;	// one less!
				}

			return;
			}

		if (NSMaxRange(range) < _iranges[i].location)	// assumes ascending order
			break;	// should have been inserted here
		}

	if (_nranges == _capacity)
		{
		int newSize = sizeof(_iranges[0])*(_capacity=2*_capacity+5);

		DBLog(@"increase capacity (%d)", _capacity);
		_iranges = (NSRange *)realloc(_iranges, newSize);
		}

	memmove(&_iranges[i+1], &_iranges[i], sizeof(_iranges[0])*(_nranges-i));
	_iranges[i] = range;
	_count = 0;		// recache
	_nranges++;
}

- (void) addIndex:(NSUInteger)value
{
	[self addIndexesInRange:(NSRange){value, 1}];
}

- (void) addIndexes:(NSIndexSet *)indexSet
{
	NSUInteger i;

	for(i = 0; i < ((NSMutableIndexSet *)indexSet)->_nranges; i++)
		[self addIndexesInRange:((NSMutableIndexSet *)indexSet)->_iranges[i]];
}

- (void) removeIndexesInRange:(NSRange)range
{
	NSUInteger i;
	NSRange x;

	for (i = 0; i < _nranges; i++)
		{
//		if (_iranges[i].location > NSMaxRange(range) - 1)	// FIX ME must be ascending order
//			break;

		if (NSEqualRanges(range, _iranges[i]))		// range[i] == to range
			{
			if (_nranges > i+1)
				memmove(&_iranges[i], &_iranges[i+1], sizeof(_iranges[0])*(_nranges-i-1));
			_nranges--;
			_count = 0;
			break;
			}

		x = NSIntersectionRange(range, _iranges[i]);
		if (NSEqualRanges(x, _iranges[i]))			// range contains irange
			{
			if (_nranges > i+1)
				memmove(&_iranges[i], &_iranges[i+1], sizeof(_iranges[0])*(_nranges-i-1));
			_nranges--;
			_count = 0;
			}
//		else if ((itr = NSIntersectionRange(range, _iranges[i])).length)
		else if (x.length)							// irange contains some or
			{										// all of range
			_count = 0;
			if (x.location != _iranges[i].location)
//			if (NSEqualRanges(x, range))			// irange contains range
				{									// split irange
				NSUInteger irange_max = NSMaxRange(_iranges[i]);
				NSUInteger x_max = NSMaxRange(x);

				_iranges[i].length = range.location - _iranges[i].location;
				if (x_max < irange_max)
					[self addIndexesInRange: (NSRange){x_max, irange_max - x_max}];
				break;
				}
			else									// irange intersects at
				{									// head or tail of range
				if (_iranges[i].location > range.location)
					_iranges[i].location = NSMaxRange(x);	// tail overlap
				else
					_iranges[i].location += x.length;		// head overlap
				_iranges[i].length -= x.length;
				}
			}
		}
}

- (void) removeIndexes:(NSIndexSet *)indexSet
{
	NSUInteger i;

	for(i = 0; i < ((NSMutableIndexSet *)indexSet)->_nranges; i++)
		[self removeIndexesInRange:((NSMutableIndexSet *)indexSet)->_iranges[i]];
}

- (void) removeAllIndexes
{ 
	_nranges = 0;
	_count = 0;
}

- (void) removeIndex:(NSUInteger)value
{
	[self removeIndexesInRange:(NSRange){value, 1}];
}

- (void) shiftIndexesStartingAtIndex:(NSUInteger)startIndex by:(int)delta
{
	if (delta < 0)
		[self removeIndexesInRange:NSMakeRange(startIndex - delta, delta)];
	else
		[self addIndexesInRange:NSMakeRange(startIndex, delta)];
} 

@end  /* NSMutableIndexSet */
