/*
   NSSet.m

   Unordered collection of unique objects

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author:  Mircea Oancea <mircea@jupiter.elcom.pub.ro>
   mGSTEP:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Nov 2005

   This file is part of the mGSTEP Library and is provided under the 
   terms of the libFoundation BSD type license (See the Readme file).
*/

#include <Foundation/NSSet.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSHashTable.h>

#define MAX_AUTO	1024


@interface _NSSet : NSSet
{
    NSHashTable *_table;
}
@end


@implementation _NSSet

- (void) dealloc
{
	NSFreeHashTable(_table);
    [super dealloc];
}

@end


@interface _NSMutableSet : NSMutableSet
{
    NSHashTable *_table;
}
@end

typedef struct		{ @defs(_NSSet); } CFSet;
typedef struct		{ @defs(NSCountedSet); } CFCountedSet;

/* ****************************************************************************

	NSSetEnumerator

** ***************************************************************************/

typedef enum {SHash, SMap} EnumMode;

@interface NSSetEnumerator : NSObject
{
    id _set;
    EnumMode _mode;
    union {
		NSMapEnumerator  map;
		NSHashEnumerator hash;
	} _enum;
}

- (id) initWithSet:(NSSet*)set mode:(EnumMode)mode;
- (id) nextObject;

@end


@implementation NSSetEnumerator

- (id) initWithSet:(NSSet*)set mode:(EnumMode)mode
{
    _set = [set retain];
    _mode = mode;
    if (_mode == SHash)
		_enum.hash = NSEnumerateHashTable(((CFSet *)set)->_table);
    else if (_mode == SMap)
		_enum.map = NSEnumerateMapTable(((CFCountedSet *)set)->_table);

    return self;
}

- (void) dealloc
{
    [_set release];
    [super dealloc];
}

- (id) nextObject
{
    if (_mode == SHash) 
		return (id)NSNextHashEnumeratorItem(&(_enum.hash));

    if (_mode == SMap) 
		{
		id key, value;

		if (NSNextMapEnumeratorPair(&(_enum.map), (void**)&key, (void**)&value) == YES)
			return key;
    	}

    return nil;
}

@end /* NSSetEnumerator */

/* ****************************************************************************

	NSSet

** ***************************************************************************/

@implementation NSSet

+ (id) alloc
{
	return NSAllocateObject([_NSSet class]);
}

+ (id) set
{
    return [[[self alloc] init] autorelease];
}

+ (id) setWithArray:(NSArray*)array
{
    return [[[self alloc] initWithArray:array] autorelease];
}

+ (id) setWithObject:(id)anObject
{
    return [[[self alloc] initWithObjects:anObject, nil] autorelease];
}

+ (id) setWithObjects:(id)firstObj, ...
{
	id set;
	va_list va;

    va_start(va, firstObj);
    set = [[[self alloc] initWithObject:firstObj arglist:va] autorelease];
    va_end(va);

    return set;
}

+ (id) setWithObjects:(id*)objects count:(NSUInteger)count
{
    return [[[self alloc] initWithObjects:objects count:count] autorelease];
}

+ (id) setWithSet:(NSSet*)aSet
{
    return [[[self alloc] initWithSet:aSet] autorelease];
}

- (id) init
{
	CFSet *a = (CFSet *)self;

    a->_table = NSCreateHashTable(NSObjectHashCallBacks, 0);

    return self;
}

- (id) initWithObjects:(id*)objects count:(NSUInteger)count
{
	CFSet *a = (CFSet *)self;
	NSUInteger i;

	a->_table = NSCreateHashTable(NSObjectHashCallBacks, count);
    for (i = 0; i < count; i++)
		NSHashInsert(a->_table, objects[i]);

    return self;
}

- (id) initWithSet:(NSSet *)set copyItems:(BOOL)flag
{
	CFSet *a = (CFSet *)self;
	id obj, en = [set objectEnumerator];

    a->_table = NSCreateHashTable(NSObjectHashCallBacks, [set count]);
    while((obj = [en nextObject]))
		NSHashInsert(a->_table, flag ? [obj copy] : obj);

    return self;
}

- (id) initWithArray:(NSArray*)array
{
	CFSet *a = (CFSet *)self;
	NSInteger i, count = [array count];

	a->_table = NSCreateHashTable(NSObjectHashCallBacks, count);
    for (i = 0; i < count; i++)
		NSHashInsert(a->_table, [array objectAtIndex:i]);

    return self;
}

- (id) initWithObjects:(id)firstObj, ...
{
	va_list va;

    va_start(va, firstObj);
    [self initWithObject:firstObj arglist:va];
    va_end(va);

    return self;
}

- (id) initWithObject:(id)firstObject arglist:(va_list)argList
{
	CFSet *a = (CFSet *)self;
	NSUInteger count = 0;
	id object;
	va_list va;
	
	va_copy(va, argList);
    for (object = firstObject; object; object = va_arg(va,id), count++);
	va_end(va);

	a->_table = NSCreateHashTable(NSObjectHashCallBacks, count);
    for (object = firstObject; object; object = va_arg(argList,id))
		NSHashInsert(a->_table, object);

    return self;
}

- (id) initWithSet:(NSSet*)aSet
{
    return [self initWithSet:aSet copyItems:NO];
}

- (NSArray *) allObjects
{
	NSUInteger i = 0;
	NSUInteger n = [self count];
	id o[ (n <= MAX_AUTO) ? n : 1 ];
	id *objs = o;
	id array, key, keys = [self objectEnumerator];

	if ((n = (n * sizeof(id))) > sizeof(o) && !(objs = malloc(n)))
		[NSException raise:NSMallocException format:@"malloc failed"];

    while ((key = [keys nextObject]))
		objs[i++] = key;

    array = [[[NSArray alloc] initWithObjects:objs count:i] autorelease];

	if (objs != o)
		free (objs);

    return array;
}

- (id) anyObject
{
    return [[self objectEnumerator] nextObject];
}

- (BOOL) containsObject:(id)anObject
{
    return [self member:anObject] ? YES : NO;
}

- (void) makeObjectsPerformSelector:(SEL)aSelector
{
	id key, keys = [self objectEnumerator];

    while ((key = [keys nextObject]))
		[key performSelector:aSelector];
}

- (void) makeObjectsPerformSelector:(SEL)aSelector withObject:(id)anObject
{
	id key, keys = [self objectEnumerator];

    while ((key = [keys nextObject]))
		[key performSelector:aSelector withObject:anObject];
}

- (BOOL) intersectsSet:(NSSet*)otherSet				// Comparing Sets
{
	id key, keys = [self objectEnumerator];

	if ([self count] == 0) 
		return NO;

    while ((key = [keys nextObject]))				// sets intersect if any
		if ([otherSet member: key])    				// element of self is also
			return YES;								// in the other set

    return NO;
}

- (BOOL) isEqualToSet:(NSSet*)otherSet
{
	id key, keys = [self objectEnumerator];

	if ([self count] != [otherSet count])
		return NO;
    
	while ((key = [keys nextObject]))
		if (![otherSet member: key])
			return NO;
    
	return YES;
}

- (BOOL) isSubsetOfSet:(NSSet*)otherSet
{
	id key, keys = [self objectEnumerator];

	if ([self count] > [otherSet count]) 			// subset must not exceed
		return NO;									// the size of other set

    while ((key = [keys nextObject]))				// all of our members must
		if (![otherSet member: key])				// exist in other set for
			return NO;								// self to be a subset

	return YES;
}
													// ret a String Description
- (NSString *) descriptionWithLocale:(id)locale
{
    return [self descriptionWithLocale:locale indent:0];
}

- (NSString *) description
{
    return [self descriptionWithLocale:nil indent:0];
}

- (NSString *) descriptionWithLocale:(id)locale indent:(unsigned int)indent
{
	NSMutableString *description = [NSMutableString stringWithCString:"(\n"];
	unsigned int indent1 = indent + 4;
	NSString *fmt = [NSString stringWithFormat:@"%%%dc", indent1];
	NSMutableString *indentation = [NSString stringWithFormat: fmt, ' '];
	NSUInteger count = [self count];
	IMP imp = [description methodForSelector:@selector(appendString:)];

    if (count)
		{
		id pool = [NSAutoreleasePool new];
		id enumerator = [self objectEnumerator];
		id object = [enumerator nextObject];
		id stringRepresentation;

		if ([object respondsToSelector: @selector(descriptionWithLocale:indent:)])
	    	stringRepresentation = [object descriptionWithLocale:locale
										   indent:indent1];
		else 
			if ([object respondsToSelector:@selector(descriptionWithLocale:)])
				stringRepresentation = [object descriptionWithLocale:locale];
			else
				stringRepresentation = [object description];

		(*imp)(description, @selector(appendString:), indentation);
		(*imp)(description, @selector(appendString:), stringRepresentation);

		while((object = [enumerator nextObject]))
			{
			if ([object respondsToSelector: @selector(descriptionWithLocale:indent:)])
				stringRepresentation = [object descriptionWithLocale:locale
											   indent:indent1];
			else if ([object respondsToSelector:@selector(descriptionWithLocale:)])
				stringRepresentation = [object descriptionWithLocale:locale];
			else
				stringRepresentation = [object description];

			(*imp)(description, @selector(appendString:), @",\n");
			(*imp)(description, @selector(appendString:), indentation);
			(*imp)(description, @selector(appendString:), stringRepresentation);
			}

		[pool release];
		}

    (*imp)(description, @selector(appendString:), indent
		? [NSMutableString stringWithFormat: [NSString stringWithFormat:@"\n%%%dc)", indent], ' ']
		: [NSMutableString stringWithCString:"\n)"]);

    return description;
}

- (id) member:(id)anObject
{ 
	return (NSObject *)NSHashGet(((CFSet *)self)->_table, anObject);
}

- (NSEnumerator *) objectEnumerator
{
    return (NSEnumerator *)[[[NSSetEnumerator alloc] initWithSet:self
													 mode:SHash] autorelease];
}

- (NSUInteger) count
{
	return NSCountHashTable(((CFSet *)self)->_table);
}

- (NSUInteger) hash			{ return [self count]; }

- (BOOL) isEqual:(id)anObject
{
    if ([anObject isKindOfClass:[NSSet class]] == NO)
	    return NO;

    return [self isEqualToSet:anObject];
}
												// NSCopying, NSMutableCopying
- (id) copy					{ return [self retain]; }
- (id) mutableCopy			{ return [[NSMutableSet alloc] initWithSet:self]; }
- (Class) classForCoder		{ return [NSSet class]; }

- (void) encodeWithCoder:(NSCoder*)aCoder
{
	NSEnumerator *enumerator = [self objectEnumerator];
	NSUInteger count = [self count];
	id object;

    [aCoder encodeValueOfObjCType:@encode(NSUInteger) at:&count];
    while((object = [enumerator nextObject]))
		[aCoder encodeObject:object];
}

- (id) initWithCoder:(NSCoder*)aDecoder
{
	NSUInteger i, count;
	id *objects;

    [aDecoder decodeValueOfObjCType:@encode(NSUInteger) at:&count];
    objects = malloc(sizeof(id) * count);
    for(i = 0; i < count; i++)
		objects[i] = [aDecoder decodeObject];

    [self initWithObjects:objects count:count];
    free(objects);

    return self;
}

@end /* NSSet */

/* ****************************************************************************

	NSMutableSet

** ***************************************************************************/

@implementation NSMutableSet

+ (id) alloc
{
    return NSAllocateObject([_NSMutableSet class]);
}

+ (id) setWithCapacity:(NSUInteger)numItems
{
    return [[[[self class] alloc] initWithCapacity:numItems] autorelease];
}

- (void) addObjectsFromArray:(NSArray*)array
{
	NSUInteger i, n = [array count];

    for (i = 0; i < n; i++)
		[self addObject:[array objectAtIndex:i]];
}

- (void) unionSet:(NSSet*)other
{
	id key, keys = [other objectEnumerator];

    while ((key = [keys nextObject]))
		[self addObject:key];
}

- (void) setSet:(NSSet*)other
{
    [self removeAllObjects];
    [self unionSet:other];
}

- (void) intersectSet:(NSSet*)other						// Removing Objects
{
	id key, keys = [self objectEnumerator];

    while ((key = [keys nextObject]))
		if ([other containsObject:key] == NO)
			[self removeObject:key];
}

- (void) minusSet:(NSSet*)other
{
	id key, keys = [other objectEnumerator];

    while ((key = [keys nextObject]))
		[self removeObject:key];
}

- (id) copy
{
    return [[NSSet alloc] initWithSet:self copyItems:YES];
}

- (Class) classForCoder				{ return [NSMutableSet class]; }

@end /* NSMutableSet */


@implementation _NSMutableSet					

- (id) initWithCapacity:(NSUInteger)numItems
{
	_table = NSCreateHashTable(NSObjectHashCallBacks, numItems);

	return self;
}

- (void) dealloc
{
	NSFreeHashTable(_table);
    [super dealloc];
}

- (void) addObject:(id)object		{ NSHashInsert(_table, object); }
- (void) removeObject:(id)object	{ NSHashRemove(_table, object); }
- (void) removeAllObjects			{ NSResetHashTable(_table); }

@end /* _NSMutableSet */

/* ****************************************************************************

	NSCountedSet

	mutable set that can contain multiple instances of the same element

** ***************************************************************************/

@implementation NSCountedSet

+ (id) alloc						{ return NSAllocateObject(self); }
- (id) init							{ return [self initWithCapacity:0]; }

- (id) initWithObjects:(id*)objects count:(NSUInteger)count
{
	NSUInteger i;

    [self initWithCapacity:count];
    for (i = 0; i < count; i++)
		[self addObject:objects[i]];

    return self;
}

- (id) initWithSet:(NSSet *)set copyItems:(BOOL)flag
{
	id obj, en = [set objectEnumerator];

    [self initWithCapacity:[set count]];
    while((obj = [en nextObject]))
		[self addObject:flag ? [obj copy] : obj];

    return self;
}

- (id) initWithCapacity:(NSUInteger)numItems
{
	_table = NSCreateMapTable(NSObjectMapKeyCallBacks,
							  NSIntMapValueCallBacks,
							  numItems);
	return self;
}

- (void) dealloc
{
    NSFreeMapTable(_table);
    [super dealloc];
}

- (id) mutableCopy												// NSCopying
{
    return [[NSCountedSet alloc] initWithSet:self];
}

- (id) member:(id)anObject
{
	id k, v;

    return NSMapMember(_table,(void*)anObject,(void**)&k,(void**)&v) ? k : nil;
}

- (NSUInteger) countForObject:(id)anObject
{
    return (NSUInteger)NSMapGet(_table, anObject);
}

- (NSEnumerator *) objectEnumerator
{
    return (NSEnumerator *)[[[NSSetEnumerator alloc] initWithSet:self
													 mode:SMap] autorelease];
}

- (void) addObject:(id)obj
{
	NSMapInsert(_table, obj, (void*)((unsigned long)NSMapGet(_table, obj)+1));
}

- (void) removeObject:(id)object		{ NSMapRemove(_table, object); }
- (void) removeAllObjects				{ NSResetMapTable(_table); }
- (NSUInteger) count					{ return NSCountMapTable(_table); }

- (NSString *) descriptionWithLocale:(id)locale indent:(unsigned int)level;
{
	NSUInteger count = [self count];
	NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:count];
	NSEnumerator *enumerator = [self objectEnumerator];
	id key;
    
    while((key = [enumerator nextObject]))
		[d setObject:[NSNumber numberWithUnsignedInt:[self countForObject:key]]
			  forKey:key];
    
    return [d descriptionWithLocale:locale indent:level];
}

@end /* NSCountedSet */
