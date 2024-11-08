/*
   NSArray.m

   Ordered collection of objects.

   Copyright (C) 1995-2020 Free Software Foundation, Inc.

   Author:	Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date:	March 1995
   mGSTEP:	Felipe A. Rodriguez <far@illumenos.com>
   Date:	Mar 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSArray.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSString.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSException.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSIndexSet.h>

#define MAX_AUTO	1024
							// shell sort value for stride factor is not well
#define STRIDE_FACTOR 3		// understood 3 is a good choice (Sedgewick)


static Class __mutableArrayClass = Nil;
static Class __arrayClass = Nil;
static Class __stringClass = Nil;


/* ****************************************************************************

 		_NSArrayEnumerator, _NSReverseArrayEnumerator

** ***************************************************************************/

@interface _NSReverseArrayEnumerator : NSEnumerator
{
	id *_contents;
	id _array;
	NSInteger _index;
}
@end

@implementation _NSReverseArrayEnumerator

- (id) initWithArray:(NSArray*)anArray and:(id*)contents
{
	_contents = contents;
	_array = [anArray retain];
	_index = [_array count] - 1;
	
	return [self autorelease];
}

- (void) dealloc
{
	[_array release];
	[super dealloc];
}

- (NSArray *) allObjects
{
	NSArray *a = nil;

	if (_index >= 0)
		{
		NSUInteger n = ((_index + 1) * sizeof(id));
		NSUInteger i = 0;
		id o[ ((_index + 1) <= MAX_AUTO) ? (_index + 1) : 1 ];
		id *contents = o;

		if (n > sizeof(o) && !(contents = malloc(n)))
			[NSException raise:NSMallocException format:@"malloc failed"];

		while (_index >= 0)
			contents[i++] = _contents[_index--];

		a = [NSArray arrayWithObjects:contents count:i];

		if (contents != o)
			free (contents);
		}

	return a;
}

- (id) nextObject
{
	return (_index < 0) ? nil : _contents[_index--];
}

@end  /* _NSReverseArrayEnumerator */


@interface _NSArrayEnumerator : _NSReverseArrayEnumerator
{
	NSInteger _count;
}
@end

@implementation _NSArrayEnumerator

- (id) initWithArray:(NSArray*)anArray and:(id*)contents
{
	_contents = contents;
	_array = [anArray retain];
	_count = [_array count];

	return [self autorelease];
}

- (id) nextObject
{
	return (_index >= _count) ? nil : _contents[_index++];
}

- (id) previousObject
{
	return (_index <= 0) ? nil : _contents[--_index];
}

@end  /* _NSArrayEnumerator */

/* ****************************************************************************

 		NSArray 

** ***************************************************************************/

@implementation NSArray

+ (void) initialize
{
	if (self == (__arrayClass = [NSArray class]))
		{
		__mutableArrayClass = [NSMutableArray class];
		__stringClass = [NSString class];
		}
}

+ (id) array					{ return [[self new] autorelease]; }

+ (id) arrayWithArray:(NSArray*)array
{
	return [[[self alloc] initWithArray: array] autorelease];
}

+ (id) arrayWithContentsOfFile:(NSString*)path
{
	return [[[self alloc] initWithContentsOfFile: path] autorelease];
}

+ (id) arrayWithObject:(id)anObject
{
	if (anObject == nil)
		[NSException raise:NSInvalidArgumentException 
					 format:@"Tried to add nil"];

	return [[[self alloc] initWithObjects:&anObject count:1] autorelease];
}

+ (id) arrayWithObjects:(id*)objects count:(NSUInteger)count
{
	return [[[self alloc] initWithObjects: objects count: count] autorelease];
}

+ (id) arrayWithObjects:(id)firstObject, ...
{
	NSUInteger n, count = 0;
	id obj, array;
	va_list va;

    va_start(va, firstObject);
    for (obj = firstObject; obj; obj = va_arg(va, id), count++);
	va_end(va);

	id o[ (count <= MAX_AUTO) ? count : 1 ];
	id *objs = o;

	if ((n = (count * sizeof(id))) > sizeof(o) && !(objs = malloc(n)))
		[NSException raise:NSMallocException format:@"malloc failed"];

	va_start(va, firstObject);
	for (count = 0, obj = firstObject; obj; obj = va_arg(va,id))
		objs[count++] = obj;
	va_end(va);

    array = [[self alloc] initWithObjects:objs count:count];

	if (objs != o)
		free (objs);

	return [array autorelease];
}

- (id) initWithObjects:(id)firstObject, ...
{
	id obj;
	va_list va;
	NSUInteger count = 0;
    
    va_start(va, firstObject);
    for (obj = firstObject; obj; obj = va_arg(va, id), count++);
	va_end(va);

	if ((_contents = malloc(sizeof(id) * ((count > 0) ? count : 1))) == NULL)
		[NSException raise: NSMallocException format:@"malloc failed"];

	va_start(va, firstObject);
	for (count = 0, obj = firstObject; obj; obj = va_arg(va, id))
		_contents[_count++] = [obj retain];
	va_end(va);

	return self;
}

- (id) init						{ return [self initWithObjects: 0 count: 0]; }

- (id) initWithObjects:(id*)objects count:(NSUInteger)count
{													// designated initializer
	if ((_contents = malloc(sizeof(id) * ((count == 0) ? 1 : count))) == NULL)
		[NSException raise: NSMallocException format:@"malloc failed"];

	for (; _count < count; _count++)
		if ((_contents[_count] = [objects[_count] retain]) == nil)
			[NSException raise: NSInvalidArgumentException
						 format: @"Tried to add nil"];
	return self;
}

- (id) initWithArray:(NSArray*)a
{
    return [self initWithObjects:a->_contents count:a->_count];
}

- (id) initWithContentsOfFile:(NSString*)path
{
	NSString *s = [[NSString alloc] initWithContentsOfFile:path];
	id result;

	if ((s) && ([(result = [s propertyList]) isKindOfClass:__arrayClass]))
		return [self initWithArray: result];

	NSLog(@"Contents of file does not contain an array");
	[self dealloc];

	return nil;
}

- (void) dealloc
{
	while(_count--)
		[_contents[_count] release];
	if (_contents)
		free(_contents),	_contents = NULL;

	[super dealloc];
}

- (NSUInteger) count					{ return _count; }
- (NSUInteger) hash						{ return _count; }

- (id) lastObject
{
	return (_count <= 0) ? nil : _contents[_count-1];
}

- (id) objectAtIndex:(NSUInteger)index
{
	if (index >= _count)
		{
		if(index == 0 && _count == 0)
			return nil;

		[NSException raise:NSRangeException format:@"Index out of bounds"];
		}

	return _contents[index];
}

- (void) encodeWithCoder:(NSCoder*)aCoder
{
	[aCoder encodeValueOfObjCType: @encode(NSUInteger) at: &_count];

	if (_count > 0)
		[aCoder encodeArrayOfObjCType:@encode(id) count:_count at:_contents];
}

- (id) initWithCoder:(NSCoder*)aCoder
{
	[aCoder decodeValueOfObjCType: @encode(NSUInteger) at: &_count];

	if ((_contents = calloc(MAX(_count,1), sizeof(id))) == NULL)
		[NSException raise:NSMallocException format:@"Unable to malloc array"];

	if (_count > 0)
		[aCoder decodeArrayOfObjCType:@encode(id) count:_count at:_contents];

	return self;
}

- (id) copy														// NSCopying
{
	id o[ (_count <= MAX_AUTO) ? _count : 1 ];
	id w[ (_count <= MAX_AUTO) ? _count : 1 ];
	id *old = o;
	id *new = w;
	id na;
	BOOL needCopy = NO;
	NSUInteger i, n = _count * sizeof(id);

	if (n > sizeof(o) && (!(old = malloc(n)) || !(new = malloc(n))))
		[NSException raise:NSMallocException format:@"malloc failed"];

	[self getObjects: old];
	for (i = 0; i < _count; i++)
		{
		new[i] = [old[i] copy];
		if (new[i] != old[i])
			needCopy = YES;
		}

	if (needCopy || [self isKindOfClass: __mutableArrayClass])
		{												// deep copy required
		if (_count > 0)
			na = [[[self class] alloc] initWithObjects:new count:_count];
		else
			na = [[[self class] alloc] init];
		}
	else
		na = [self retain];

	for (i = 0; i < _count; i++)
		[new[i] release];
	if (new != w)
		free (new);
	if (old != o)
		free (old);

	return na;
}

- (id) mutableCopy											// NSMutableCopying
{															// a shallow copy 
	return [[__mutableArrayClass alloc] initWithArray:self];
}

- (NSArray *) arrayByAddingObject:(id)anObject
{
	NSUInteger c = _count + 1;
	id objects[c];

	[self getObjects: objects];
	objects[_count] = anObject;

	return [[[NSArray alloc] initWithObjects:objects count: c] autorelease];
}

- (NSArray *) arrayByAddingObjectsFromArray:(NSArray*)anotherArray
{
	NSUInteger c = _count + [anotherArray count];
	id objects[c];

	[self getObjects: objects];
	[anotherArray getObjects: &objects[_count]];

    return [NSArray arrayWithObjects: objects count: c];
}

- (NSArray *) objectsAtIndexes:(NSIndexSet *)indexSet
{
	NSUInteger ix = NSNotFound;
    id ra = nil;

	if (indexSet == nil)
		[NSException raise:NSInvalidArgumentException format:@"No index set"];
	else
		{
		ra = [NSMutableArray array];
		ix = [indexSet firstIndex];
		}

	while (ix != NSNotFound)
		{
        if (ix >= _count)
			{
			[NSException raise:NSRangeException format:@"Index out of bounds"];
            return nil;
        	}
        [ra addObject: _contents[ix]];
        ix = [indexSet indexGreaterThanIndex:ix];
		}

    return ra;
}

- (void) getObjects:(id*)aBuffer
{
	memcpy(aBuffer, _contents, _count * sizeof(id*));
}

- (void) getObjects:(id*)aBuffer range:(NSRange)r
{
	if (NSMaxRange(r) > _count)
		[NSException raise: NSRangeException format: @"Range out of bounds"];
	memcpy(aBuffer, _contents + r.location, r.length * sizeof(id*));
}

- (NSUInteger) countByEnumeratingWithState:(NSFastEnumerationState *)state
								   objects:(id [])stackbuf
								     count:(NSUInteger)stackbufLength
{
    NSUInteger count = 0;

	if (state->state == 0)
		state->mutationsPtr = &state->extra[0];			// ignore mutations
    if (state->state < _count)
		{
        state->state = count = _count;
        state->itemsPtr = (__typeof__(state->itemsPtr))_contents;
		}

    return count;
}

- (NSUInteger) indexOfObjectIdenticalTo:(id)anObject
{
	NSUInteger i;

	for (i = 0; i < _count; i++)
		if (anObject == _contents[i])
			return i;

	return NSNotFound;
}

- (NSUInteger) indexOfObjectIdenticalTo:(id)anObject inRange:(NSRange)aRange
{
	NSUInteger e = MIN(NSMaxRange(aRange), _count);
	NSUInteger i;

	for (i = aRange.location; i < e; i++)
		if (anObject == _contents[i])
			return i;

	return NSNotFound;
}

- (NSUInteger) indexOfObject:(id)anObject
{
	NSUInteger i;

	if (anObject == nil)
		return NSNotFound;

	if (_count > 8)							// For large arrays, speed things 
		{									// up a bit by caching the method.
		SEL	sel = @selector(isEqual:);
		BOOL (*imp)(id,SEL,id);

		imp = (BOOL (*)(id,SEL,id))[anObject methodForSelector: sel];

		for (i = 0; i < _count; i++)
			if ((*imp)(anObject, sel, _contents[i]))
				return i;
		}
	else
		{
		for (i = 0; i < _count; i++)
			if ([anObject isEqual: _contents[i]])
				return i;
		}

	return NSNotFound;
}

- (NSUInteger) indexOfObject:(id)anObject inRange:(NSRange)aRange
{
	NSUInteger e = MIN(NSMaxRange(aRange), _count);
	NSUInteger i;

	for (i = aRange.location; i < e; i++)
		if (anObject == _contents[i] || [_contents[i] isEqual: anObject])
			return i;

	return NSNotFound;
}

- (BOOL) containsObject:(id)anObject
{
	return ([self indexOfObject:anObject] != NSNotFound);
}

- (BOOL) isEqual:(id)anObject
{
	if ([anObject isKindOfClass:__arrayClass])
		return [self isEqualToArray:anObject];

	return NO;
}

- (BOOL) isEqualToArray:(NSArray*)otherArray
{
	NSUInteger i;
 
	if (_count != [otherArray count])
		return NO;

	for (i = 0; i < _count; i++)
		if (![_contents[i] isEqual: [otherArray objectAtIndex: i]])
			return NO;

	return YES;
}

- (void) makeObjectsPerformSelector:(SEL)aSelector
{
	NSUInteger i = _count;

	while (i-- > 0)
		[_contents[i] performSelector: aSelector];
}

- (void) makeObjectsPerformSelector:(SEL)aSelector withObject:argument
{
	NSUInteger i = _count;

	while (i-- > 0)
		[_contents[i] performSelector:aSelector withObject:argument];
}

static NSInteger _Compare(id elem1, id elem2, void *comparator)
{
    return (NSInteger)[elem1 performSelector:comparator withObject:elem2];
}

- (NSArray*) sortedArrayUsingSelector:(SEL)comparator
{
    return [self sortedArrayUsingFunction:_Compare context:(void*)comparator];
}

- (NSArray*) sortedArrayUsingFunction:(NSInteger(*)(id,id,void*))comparator
							  context:(void*)context
{
	SEL s = @selector(sortUsingFunction:context:);
	IMP im = [NSMutableArray instanceMethodForSelector: s];
	NSArray *sortedArray = [NSArray arrayWithArray: self];

	(*im)(sortedArray, s, comparator, context);

	return sortedArray;
}

- (NSData *) sortedArrayHint				{ return nil; }

- (NSArray*) sortedArrayUsingFunction:(NSInteger(*)(id,id,void*))comparator
							  context:(void*)context
							  hint:(NSData*)hint
{
    return [self sortedArrayUsingFunction:comparator context:context];
}

- (NSString *) componentsJoinedByString:(NSString*)separator
{
	NSUInteger i = _count;
	id s = (i) ? [NSMutableString stringWithString:[_contents[0] description]]
			   : [NSMutableString stringWithCapacity:2];
	
	for (i = 1; i < _count; i++)
		{
		[s appendString:separator];
		[s appendString:[_contents[i] description]];
		}

	return s;
}

- (NSArray *) pathsMatchingExtensions:(NSArray*)extensions
{
	NSMutableArray *a = [NSMutableArray arrayWithCapacity: 1];
	NSUInteger i;

	for (i = 0; i < _count; i++)
		if ([_contents[i] isKindOfClass: __stringClass])
			if ([extensions containsObject: [_contents[i] pathExtension]])
				[a addObject: _contents[i]];

	return a;
}

- (id) firstObjectCommonWithArray:(NSArray*)otherArray
{
	NSUInteger i;

	for (i = 0; i < _count; i++)
		if ([otherArray containsObject:_contents[i]])
			return _contents[i];

	return nil;
}

- (NSArray *) subarrayWithRange:(NSRange)range
{
	NSUInteger c = _count - 1;				// If array is empty or start is
	NSUInteger i = range.location, j;		// beyond end of array then return 
											// an empty array
	if ((_count == 0) || (range.location > c))
		return [NSArray array];

	j = NSMaxRange(range);							// Check if length extends			
	j = (j > c) ? c : j - 1;						// beyond end of array				

	return [NSArray arrayWithObjects: _contents+i count: j-i+1];
}

- (NSEnumerator *) objectEnumerator
{
	return [[_NSArrayEnumerator alloc] initWithArray:self and:_contents];
}

- (NSEnumerator *) reverseObjectEnumerator
{
	return [[_NSReverseArrayEnumerator alloc] initWithArray:self and:_contents];
}

- (NSString *) description
{
	return [self descriptionWithLocale:nil indent:0];
}

- (NSString *) descriptionWithLocale:(id)locale
{
	return [self descriptionWithLocale:locale indent:0];
}

- (NSString *) descriptionWithLocale:(id)locale indent:(unsigned int)level
{
	NSAutoreleasePool *arp = [NSAutoreleasePool new];
	NSMutableString	*result;
	NSUInteger size;
	NSUInteger indentSize;
	NSUInteger indentBase;
	NSMutableString	*iBaseString;
	NSMutableString	*iSizeString;
	NSUInteger i, count = _count;			// FIX ME check stack allocation
	NSString *plists[count];
											// Indentation is at four space
    [self getObjects: plists];				// intervals using tab characters
										 	// to replace multiples of eight 
    indentBase = level << 2;				// spaces.
    count = indentBase >> 3;				// Calc size of strings needed
	indentBase = ((indentBase % 4) == 0) ? count : count + 4;

    iBaseString = [NSMutableString stringWithCapacity: indentBase];
    for (i = 1; i < count; i++) 
		[iBaseString appendString: @"\t"];

//    if (count != indentBase) 
//		[iBaseString appendString: @"    "];

    level++;
    indentSize = level << 2;
    count = indentSize >> 3;
	indentBase = ((indentBase % 4) == 0) ? count : count + 4;

    iSizeString = [NSMutableString stringWithCapacity: indentSize];
    for (i = 1; i < count; i++) 
		[iSizeString appendString: @"\t"];

//    if (count != indentSize) 
//		[iSizeString appendString: @"    "];

    size = 4 + indentBase;					// Basic size is - opening bracket, 
											// newline, closing bracket, 
    count = _count;							// indentation for the closing  
    for (i = 0; i < count; i++) 			// bracket, and a nul terminator.
		{
		id item = plists[i];
		const char *s;

		if (![item isKindOfClass: __stringClass]) 
			{ 
			if ([item respondsToSelector: @selector(descriptionWithLocale:indent:)])
				item = [item descriptionWithLocale: locale indent: level];
			else 
				{
				if([item respondsToSelector:@selector(descriptionWithLocale:)]) 
					item = [item descriptionWithLocale: locale];
				else 
					item = [item description];
			}	}

		s = [item cString];					// if str with whitespc add quotes
		if(*s != '{' && *s != '(' && *s != '<')
			if((strpbrk(s, " %-\t") != NULL))
				item = [NSString stringWithFormat:@"\"%@\"", item]; 

		plists[i] = item;
		size += [item length] + indentSize;

		if (i == count - 1) 
			size += 1;										// newline
		else 
			size += 2;										// ',' and newline
		}

    result = [[NSMutableString alloc] initWithCapacity: size];
    [result appendString: @"(\n"];
    for (i = 0; i < count; i++) 
		{
		[result appendString: iSizeString];
		[result appendString: plists[i]];
		if (i == count - 1) 
            [result appendString: @"\n"];
		else 
            [result appendString: @",\n"];
		}
    [result appendString: iBaseString];
    [result appendString: @")"];

    [arp release];

    return [result autorelease];
}

@end  /* NSArray */

/* ****************************************************************************

 		NSMutableArray 

** ***************************************************************************/

@implementation NSMutableArray

+ (id) arrayWithCapacity:(NSUInteger)numItems
{
	return [[[self alloc] initWithCapacity:numItems] autorelease];
}

- (id) init							{ return [self initWithCapacity:2]; }

- (id) initWithCapacity:(NSUInteger)capacity
{
	_capacity = (capacity == 0) ? 1 : capacity;
	if ((_contents = malloc(sizeof(id) * _capacity)) == NULL)
		[NSException raise:NSMallocException format:@"malloc failed"];

	return self;
}

- (id) initWithObjects:(id*)objects count:(NSUInteger)count
{
	_capacity = (count == 0) ? 1 : count;

	if ((_contents = malloc(sizeof(id) * _capacity)) == NULL)
		[NSException raise:NSMallocException format:@"malloc failed"];

	for (; _count < count; _count++)
		if ((_contents[_count] = [objects[_count] retain]) == nil)
			[NSException raise: NSInvalidArgumentException
						 format: @"Tried to add nil"];
	return self;
}

- (id) initWithCoder:(NSCoder*)aCoder
{
	self = [super initWithCoder: aCoder];
	_capacity = _count;

	return self;
}

- (void) addObject:(id)anObject
{
	if (anObject == nil)
		[NSException raise:NSInvalidArgumentException format:@"Can't add nil"];

	if (_count >= _capacity)
		{
		id *p;

		_capacity = 2 * _count;
		if ((p = realloc(_contents, _capacity * sizeof(id))) == NULL)
			[NSException raise: NSMallocException format: @"Unable to grow"];
		_contents = p;
		}

	_contents[_count] = [anObject retain];
	_count++;					// Do this AFTER we have retained the object.
}

- (void) insertObject:(id)anObject atIndex:(NSUInteger)index
{
	NSUInteger i;

	if (!anObject)
		[NSException raise:NSInvalidArgumentException format:@"Can't insert nil"];

	if (index > _count)
		[NSException raise: NSRangeException 
					 format: @"insertObject:atIndex: %d out of range", index];

	if (_count >= _capacity)
		{
		id *p;

		_capacity = 2 * _count;
		if ((p = realloc(_contents, _capacity * sizeof(id))) == NULL)
			[NSException raise: NSMallocException format: @"Unable to grow"];
		_contents = p;
		}

	for (i = _count; i > index; i--)
		_contents[i] = _contents[i - 1];
											// Make sure the array is 'sane' so   
	_contents[index] = nil;					// that it can be dealloc'd safely
	_count++;								// by an autorelease pool if the 
	_contents[index] = [anObject retain];	// retain of anObject causes an
}											// exception.

- (void) replaceObjectAtIndex:(NSUInteger)index withObject:(id)anObject
{
	if (anObject == nil)
		[NSException raise:NSInvalidArgumentException format:@"Replace with nil"];

	if (index >= _count)
		[NSException raise: NSRangeException 
					 format: @"replaceObjectAtIndex: %d out of range", index];
	[anObject retain];
    [_contents[index] release];
    _contents[index] = anObject;
}

- (void) replaceObjectsInRange:(NSRange)aRange
		  withObjectsFromArray:(NSArray*)anArray
{
	id e, o;

	if (_count < NSMaxRange(aRange))
		[NSException raise: NSRangeException
					 format: @"Can't replace objects beyond end of array."];
	[self removeObjectsInRange: aRange];
	e = [anArray reverseObjectEnumerator];
	while ((o = [e nextObject]))
		[self insertObject: o atIndex: aRange.location];
}

- (void) replaceObjectsInRange:(NSRange)aRange
		  withObjectsFromArray:(NSArray*)anArray
		  range:(NSRange)anotherRange
{
	[self replaceObjectsInRange: aRange
		  withObjectsFromArray: [anArray subarrayWithRange: anotherRange]];
}

- (BOOL) writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile
{
	return [[self description] writeToFile:path atomically:useAuxiliaryFile];
}

- (void) removeLastObject
{
	if (_count == 0)
		[NSException raise: NSRangeException format: @"Array is empty."];

	_count--;
	[_contents[_count] release];
}

- (void) removeObjectIdenticalTo:(id)anObject inRange:(NSRange)aRange
{
	NSUInteger j, i = MIN(NSMaxRange(aRange), _count);
	id o;

	while (i-- > aRange.location)
		if ((o = _contents[i]) == anObject)
			{
			_count--;
			for (j = i; j < _count; j++)
				_contents[j] = _contents[j + 1];
			[o release];
			}
}

- (void) removeObjectIdenticalTo:(id)anObject
{
	NSUInteger j, i = _count;
	id o;

	while (i-- > 0)
		if ((o = _contents[i]) == anObject)
			{
			_count--;
			for (j = i; j < _count; j++)
				_contents[j] = _contents[j + 1];
			[o release];
			}
}

- (void) removeObject:(id)anObject inRange:(NSRange)aRange
{
	NSUInteger j, i = MIN(NSMaxRange(aRange), _count);
	id o;

	while (i-- > aRange.location)
		if ((o = _contents[i]) == anObject || [o isEqual: anObject])
			{
			_count--;
			for (j = i; j < _count; j++)
				_contents[j] = _contents[j + 1];
			[o release];
			}
}

- (void) removeObject:(id)anObject
{
	NSUInteger j, i = _count;
	id o;

	while (i-- > 0)
		if ((o = _contents[i]) == anObject || [o isEqual: anObject])
			{
			_count--;
			for (j = i; j < _count; j++)
				_contents[j] = _contents[j + 1];
			[o release];
			}
}

- (void) removeObjectAtIndex:(NSUInteger)index
{
	id o;

	if (index >= _count)
		[NSException raise: NSRangeException
					 format:@"removeObjectAtIndex: %d is out of range", index];

	o = _contents[index];
	_count--;
	for (; index < _count; index++)
		_contents[index] = _contents[index + 1];
	[o release];
}

- (void) removeAllObjects
{
	NSUInteger c = (_count <= 0) ? 0 : _count - 1;
	NSUInteger i = 0;

	while (i++ < c)
		[_contents[i] release];
	_count = 0;
}

- (void) addObjectsFromArray:(NSArray*)otherArray
{
	NSUInteger i, c = [otherArray count];

	for (i = 0; i < c; i++)
		[self addObject: [otherArray objectAtIndex: i]];
}

- (void) setArray:(NSArray *)otherArray
{
	[self removeAllObjects];
	[self addObjectsFromArray: otherArray];
}

- (void) removeObjectsAtIndexes:(NSIndexSet*)indexSet
{
	NSUInteger ix = NSNotFound;

	if (indexSet == nil)
		[NSException raise:NSInvalidArgumentException format:@"No index set"];
	else
		ix = [indexSet lastIndex];

	if (ix >= _count)
		[NSException raise:NSRangeException format:@"Index out of bounds"];

	while (ix != NSNotFound)
		{
		[self removeObjectAtIndex: ix];
        ix = [indexSet indexLessThanIndex:ix];
		}
}

- (void) insertObjects:(NSArray *)objects atIndexes:(NSIndexSet *)indexSet
{
	NSUInteger j, ix = NSNotFound;

	if (indexSet == nil)
		[NSException raise:NSInvalidArgumentException format:@"No index set"];
	else
		ix = [indexSet firstIndex];

	for (j = 0; ix != NSNotFound; j++)
		{
        if (ix > _count)
			[NSException raise:NSRangeException format:@"Index out of bounds"];
		[self insertObject:[objects objectAtIndex:j] atIndex:ix];
        ix = [indexSet indexGreaterThanIndex:ix];
		}
}

- (void) replaceObjectsAtIndexes:(NSIndexSet *)indexSet withObjects:(NSArray*)a
{
	NSUInteger j, ix = NSNotFound;

	if (indexSet == nil)
		[NSException raise:NSInvalidArgumentException format:@"No index set"];
	else
		ix = [indexSet firstIndex];

	for (j = 0; ix != NSNotFound; j++)
		{
        if (ix >= _count)
			[NSException raise:NSRangeException format:@"Index out of bounds"];
		[self replaceObjectAtIndex:ix withObject:[a objectAtIndex:j]];
        ix = [indexSet indexGreaterThanIndex:ix];
		}
}

- (void) removeObjectsFromIndices:(NSUInteger *)indices		// OS X deprecated
					   numIndices:(NSUInteger)count
{
	while (count--)
		[self removeObjectAtIndex:indices[count]];
}

- (void) removeObjectsInArray:(NSArray*)otherArray
{
	NSUInteger i, c = [otherArray count];

	for (i = 0; i < c; i++)
		[self removeObject:[otherArray objectAtIndex:i]];
}

- (void) removeObjectsInRange:(NSRange)aRange
{
	NSUInteger i = MIN(NSMaxRange(aRange), _count);

	while (i-- > aRange.location)
		[self removeObjectAtIndex: i];
}

- (void) sortUsingFunction:(NSInteger(*)(id,id,void*))compare context:(void*)cx
{
	NSUInteger c, d, stride = 1;					// Shell sort algorithm 
													// from SortingInAction
	while (stride <= _count)						// a NeXT example
		stride = stride * STRIDE_FACTOR + 1;

	while(stride > (STRIDE_FACTOR - 1)) 			// loop to sort for each 
		{											// value of stride
		stride = stride / STRIDE_FACTOR;
		for (c = stride; c < _count; c++) 
			{
			BOOL found = NO;

			if (stride > c)
				break;
			d = c - stride;
			while (!found) 							// move to left until the 
				{									// correct place is found
				id a = _contents[d + stride];
				id b = _contents[d];

				if ((*compare)(a, b, cx) == NSOrderedAscending)
					{
					_contents[d + stride] = b;		// swap values
					_contents[d] = a;
					if (stride > d)
						break;
					d -= stride;					// jump by stride factor
					}
				else 
					found = YES;
		}	}	}
}

static NSInteger _SelectorCompare(id elem1, id elem2, void *comparator)
{
    return (NSInteger)[elem1 performSelector:(SEL)comparator withObject:elem2];
}

- (void) sortUsingSelector:(SEL)comparator
{
    [self sortUsingFunction:_SelectorCompare context:(void*)comparator];
}

@end  /* NSMutableArray */
