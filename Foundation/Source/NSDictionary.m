/*
   NSDictionary.m

   Collection of objects associated with unique keys

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author:  Mircea Oancea <mircea@jupiter.elcom.pub.ro>
   mGSTEP:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Nov 2005

   This file is part of the mGSTEP Library and is provided under the 
   terms of the libFoundation BSD type license (See the Readme file).
*/

#include <Foundation/NSDictionary.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSData.h>
#include <Foundation/NSString.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSException.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSException.h>
#include <Foundation/NSPropertyList.h>

#define MAX_AUTO	1024


static Class __NSDictionary;
static Class __NSMutableDictionary;


@interface _NSDictionary : NSDictionary
{
    NSMapTable *_table;
}
@end

@implementation _NSDictionary
@end


@interface _NSMutableDictionary : NSMutableDictionary
{
    NSMapTable *_table;
}
@end

typedef struct  { @defs(_NSDictionary); } CFDictionary;

/* ****************************************************************************

	NSDictionary Enumerators

** ***************************************************************************/

@interface NSDictionaryObjectEnumerator : NSObject
{
    NSDictionary *_dict;
    NSEnumerator *_keys;
}

+ (id) enumeratorWithDictionary:(NSDictionary*)dict;
- (id) nextObject;

@end

@implementation NSDictionaryObjectEnumerator

+ (id) enumeratorWithDictionary:(NSDictionary*)dict
{
	NSDictionaryObjectEnumerator *e = [self new];

    e->_dict = [dict retain];
    e->_keys = [[dict keyEnumerator] retain];

    return [e autorelease];
}

- (void) dealloc
{
    [_dict release];
    [_keys release];
    [super dealloc];
}

- (id) nextObject			{ return [_dict objectForKey:[_keys nextObject]]; }

@end /* NSDictionaryObjectEnumerator */


@interface _NSDictionaryKeyEnumerator : NSObject
{
    NSDictionary *_dict;
    NSMapEnumerator	_enumerator;
}

+ (id) enumeratorWithDictionary:(NSDictionary*)dict;
- (id) nextObject;

@end

@implementation _NSDictionaryKeyEnumerator

+ (id) enumeratorWithDictionary:(NSDictionary*)dict
{
	_NSDictionaryKeyEnumerator *e = [self new];

    e->_dict = [dict retain];
    e->_enumerator = NSEnumerateMapTable(((CFDictionary*)dict)->_table);

    return [e autorelease];
}

- (void) dealloc
{
    [_dict release];
    [super dealloc];
}

- (id) nextObject
{
	id key, value;

    return NSNextMapEnumeratorPair(&_enumerator, (void**)&key, 
									(void**)&value) == YES ? key : nil;
}

@end /* _NSDictionaryKeyEnumerator */

/* ****************************************************************************

	NSDictionary

** ***************************************************************************/

@implementation NSDictionary

+ (void) initialize
{
	if (self == [NSDictionary class])
		{
		__NSDictionary = [_NSDictionary class];
		__NSMutableDictionary = [_NSMutableDictionary class];
		}
}

+ (id) alloc					{ return NSAllocateObject(__NSDictionary); }

+ (id) dictionary
{
    return [[[self alloc] initWithDictionary:nil] autorelease];
}

+ (id) dictionaryWithContentsOfFile:(NSString*)path
{
	return [[NSString stringWithContentsOfFile:path] propertyList];
}

+ (id) dictionaryWithObjects:(NSArray*)objects forKeys:(NSArray*)keys
{
    return [[[self alloc] initWithObjects:objects forKeys:keys] autorelease];
}

+ (id) dictionaryWithObjects:(id *)o forKeys:(id *)keys count:(NSUInteger)c
{
    return [[[self alloc] initWithObjects:o forKeys:keys count:c] autorelease];
}

+ (id) dictionaryWithObjectsAndKeys:(id)firstObject, ...
{
	NSInteger count;
	id obj, *k, *v, d;
	va_list va;
	
    va_start(va, firstObject);
    for (count = 1, obj = firstObject; obj; obj = va_arg(va, id), count++) 
		if (!va_arg(va,id))
			[NSException raise: NSInvalidArgumentException
						 format: @"Tried to add nil key to dictionary"];
	va_end(va);

	if (!(k = malloc(sizeof(id) * count)) || !(v = malloc(sizeof(id) * count)))
		[NSException raise:NSMallocException format:@"malloc failed"];
	
	va_start(va, firstObject);
	for (count = 0, obj = firstObject; obj; obj = va_arg(va, id)) 
		{
		k[count] = va_arg(va, id);
		v[count++] = obj;
		}
	va_end(va);

    d = [[self alloc] initWithObjects:v forKeys:k count:count];

    free(k);
    free(v);

    return [d autorelease];
}

+ (id) dictionaryWithDictionary:(NSDictionary*)aDict
{
    return [[[self alloc] initWithDictionary:aDict] autorelease];
}

+ (id) dictionaryWithObject:(id)o forKey:(id)k
{
    return [[[self alloc] initWithObjects:&o forKeys:&k count:1] autorelease];
}

- (id) initWithContentsOfFile:(NSString*)fileName
{
	NSPropertyListReadOptions opts;
	NSPropertyListFormat fmt = 0;
	NSError *err = nil;
	id d, blob;

	DBLog(@"initWithContentsOfFile: %@", fileName);

	if (!(blob = [NSData dataWithContentsOfFile:fileName]))
		return _NSInitError(self, @"Failed to open file %@", fileName);

	opts = ([self class] == __NSDictionary) ? NSPropertyListImmutable
											: NSPropertyListMutableContainers;
	d = [NSPropertyListSerialization propertyListWithData: blob
									 options: opts
									 format:  &fmt
									 error:   &err];
	if (!d)
		[NSException raise: NSParseErrorException
					 format:@"NSDictionary %@ for file %@", err, fileName];
	if (![d isKindOfClass:__NSMutableDictionary])
		[NSException raise: NSParseErrorException
					 format: @"%@ does not contain a %@ property list",
							fileName, NSStringFromClass([self class])];

	if (fmt == NSPropertyListOpenStepFormat)
		{
		[self autorelease];

		return [d retain];
		}

	return [self initWithDictionary:d];
}

- (id) initWithDictionary:(NSDictionary*)dictionary copyItems:(BOOL)doCopy
{
	NSEnumerator *ke = [dictionary keyEnumerator];
	NSUInteger count = [dictionary count];
	id key, *k, *v;

	if (!(k = malloc(sizeof(id) * count)) || !(v = malloc(sizeof(id) * count)))
		[NSException raise:NSMallocException format:@"malloc failed"];

	if (doCopy)
		for (count = 0; (key = [ke nextObject]); count++)
			{
			k[count] = [[key copy] autorelease];
			v[count] = [dictionary objectForKey:key];
			v[count] = [[v[count] copy] autorelease];
			}
	else
		for (count = 0; (key = [ke nextObject]); count++)
			{
			k[count] = key;
			v[count] = [dictionary objectForKey:key];
			}
	
    [self initWithObjects:v forKeys:k count:count];
    
    free(k);
    free(v);

    return self;
}

- (id) initWithDictionary:(NSDictionary*)dictionary
{
	CFDictionary *a = (CFDictionary *)self;
	id key, keys = [dictionary keyEnumerator];

    a->_table = NSCreateMapTable(NSObjectMapKeyCallBacks,
								 NSObjectMapValueCallBacks, 
								 ([dictionary count] * 4) / 3);
	    
    while ((key = [keys nextObject]))
		NSMapInsert(a->_table, key, [dictionary objectForKey:key]);
    
    return self;
}

- (id) initWithObjectsAndKeys:(id)firstObject, ...
{
	id obj, *k, *v;
	va_list va;
	NSInteger count;
    
    va_start(va, firstObject);
    for (count = 1, obj = firstObject; obj; obj = va_arg(va, id), count++) 
		if (!va_arg(va, id))
			[NSException raise: NSInvalidArgumentException
						 format: @"Tried to add nil key to dictionary"];
	va_end(va);

	if (!(k = malloc(sizeof(id) * count)) || !(v = malloc(sizeof(id) * count)))
		[NSException raise:NSMallocException format:@"malloc failed"];
	
	va_start(va, firstObject);
	for (count = 0, obj = firstObject; obj; obj = va_arg(va, id)) 
		{
		k[count] = va_arg(va, id);
		v[count++] = obj;
		}
	va_end(va);

    [self initWithObjects:v forKeys:k count:count];

    free(k);
    free(v);

    return self;
}

- (id) initWithObjects:(NSArray*)objs forKeys:(NSArray*)keys
{
	CFDictionary *a = (CFDictionary *)self;
	NSUInteger i, count;

    if ((count = [objs count]) != [keys count])
		[NSException raise: NSInvalidArgumentException
					 format: @"initWithObjects:forKeys arg sizes not equal"];

    a->_table = NSCreateMapTable(NSObjectMapKeyCallBacks,
								 NSObjectMapValueCallBacks, (count * 4) / 3);
    for (i = 0; i < count; i++)
		NSMapInsert(a->_table, [keys objectAtIndex:i], [objs objectAtIndex:i]);

    return self;
}

- (id) initWithObjects:(id *)objects forKeys:(id *)keys count:(NSUInteger)count
{
	CFDictionary *a = (CFDictionary *)self;

    a->_table = NSCreateMapTable(NSObjectMapKeyCallBacks,
								 NSObjectMapValueCallBacks, (count * 4) / 3);
	while(count--)
		{
		if (!keys[count] || !objects[count])
			[NSException raise: NSInvalidArgumentException
						 format: @"Tried to add nil object to dictionary"];
		NSMapInsert(a->_table, keys[count], objects[count]);
		}

    return self;
}

- (id) init
{
	CFDictionary *a = (CFDictionary *)self;

    a->_table = NSCreateMapTable(NSObjectMapKeyCallBacks,
								 NSObjectMapValueCallBacks, 1);
    return self;
}

- (void) dealloc
{
    if (((CFDictionary*)self)->_table)
		NSFreeMapTable(((CFDictionary*)self)->_table);
    [super dealloc];
}

- (NSEnumerator *) keyEnumerator				// Accessing keys and values
{
    return [_NSDictionaryKeyEnumerator enumeratorWithDictionary:self];
}

- (id) objectForKey:(id)key
{
	return (NSObject*)NSMapGet(((CFDictionary*)self)->_table, key);
}

- (NSUInteger) count
{
	return NSCountMapTable(((CFDictionary*)self)->_table);
}

- (NSArray *) allKeys
{
	NSMapEnumerator e = NSEnumerateMapTable(((CFDictionary *)self)->_table);
	NSUInteger i = 0;
	NSUInteger n = [self count];
	id k[ (n <= MAX_AUTO) ? n : 1 ];
	id a, key, value, *keys = k;

	if ((n = (n * sizeof(id))) > sizeof(k) && !(keys = malloc(n)))
		[NSException raise:NSMallocException format:@"malloc failed"];

    while (NSNextMapEnumeratorPair(&e, (void**)&key, (void**)&value))
		keys[i++] = key;

	a = [[[NSArray alloc] initWithObjects:keys count:i] autorelease];

	if (keys != k)
		free (keys);

    return a;
}

- (NSArray *) keysSortedByValueUsingSelector:(SEL)sel
{
	return [[self allKeys] sortedArrayUsingSelector:sel];
}

- (NSArray *) allKeysForObject:(id)object
{
	NSMapEnumerator e = NSEnumerateMapTable(((CFDictionary*)self)->_table);
	NSUInteger i = 0;
	NSUInteger n = [self count];
	id k[ (n <= MAX_AUTO) ? n : 1 ];
	id key, value, *keys = k;
	id a = nil;

	if ((n = (n * sizeof(id))) > sizeof(k) && !(keys = malloc(n)))
		[NSException raise:NSMallocException format:@"malloc failed"];

    while (NSNextMapEnumeratorPair(&e, (void**)&key, (void**)&value))
		if ([value isEqual:object])
			keys[i++] = key;
	if (i)
		a = [[[NSArray alloc] initWithObjects:keys count:i] autorelease];

	if (keys != k)
		free (keys);

    return a;
}

- (NSArray *) allValues
{
	NSMapEnumerator e = NSEnumerateMapTable(((CFDictionary*)self)->_table);
	NSUInteger i = 0;
	NSUInteger n = [self count];
	id v[ (n <= MAX_AUTO) ? n : 1 ];
	id a, key, value, *values = v;

	if ((n = (n * sizeof(id))) > sizeof(v) && !(values = malloc(n)))
		[NSException raise:NSMallocException format:@"malloc failed"];

    while (NSNextMapEnumeratorPair(&e, (void**)&key, (void**)&value))
		values[i++] = value;

	a = [[[NSArray alloc] initWithObjects:values count:i] autorelease];

	if (values != v)
		free (values);

    return a;
}

- (NSEnumerator *) objectEnumerator
{
    return [NSDictionaryObjectEnumerator enumeratorWithDictionary:self];
}

- (void) getObjects:(id *)objects andKeys:(id *)keys
{
	NSMapEnumerator e = NSEnumerateMapTable(((CFDictionary*)self)->_table);
	id key, value;

	while (NSNextMapEnumeratorPair(&e, (void**)&key, (void**)&value))
		*objects++ = value, *keys++ = key;
}

- (NSArray *) objectsForKeys:(NSArray*)keys notFoundMarker:(id)notFoundObj
{
	NSInteger count = [keys count];
	id *objs = malloc(sizeof(id)*count);
	id a, o;
    
    for (count--; count >= 0; count--) 
		{
		o = [self objectForKey:[keys objectAtIndex:count]];
		objs[count] = (o) ? o : notFoundObj;
		}
    
    a = [[[NSArray alloc] initWithObjects:objs count:count] autorelease];
    free(objs);

    return a;
}

- (BOOL) isEqualToDictionary:(NSDictionary*)other
{
	id keys, key;

    if ( other == self )
		return YES;
    if ([self count] != [other count] || other == nil)
		return NO;
    keys = [self keyEnumerator];
    while ((key = [keys nextObject]))
		if ([[self objectForKey:key] isEqual:[other objectForKey:key]] == NO)
	    	return NO;

    return YES;
}

- (NSString *) descriptionWithLocale:(id)locale indent:(unsigned int)indent
{
	id pool, key, value, keys, kd, vd;
	NSMutableString *desc, *indentation, *format;
	unsigned indent1 = indent + 4;
	NSEnumerator *e;
	const char *s;
	SEL sel;
	IMP imp;

    if(!([self count])) 
		return @"{}";

	desc = [NSMutableString stringWithCString:"{\n"];
	format = [NSString stringWithFormat:@"%%%dc", indent1];
	indentation = [NSString stringWithFormat: format, ' '];
	pool = [NSAutoreleasePool new];
	keys = [[self allKeys] sortedArrayUsingSelector:@selector(compare:)];
    e = [keys objectEnumerator];

    sel = @selector(appendString:);
    imp = [desc methodForSelector:sel];
    NSParameterAssert(imp);

    while((key = [e nextObject])) 
		{
		if ([key respondsToSelector:@selector(descriptionWithLocale:indent:)])
			kd = [key descriptionWithLocale:locale indent:indent1];
		else 
			if ([key respondsToSelector:@selector(descriptionWithLocale:)])
				kd = [key descriptionWithLocale:locale];
			else
				kd = [key description];
											// if str with whitespc add quotes
		if(strpbrk([kd cString], " %-\t") != NULL)
			kd = [NSString stringWithFormat: @"\"%@\"", kd];

		value = [self objectForKey:key];
		if([value respondsToSelector:@selector(descriptionWithLocale:indent:)])
			vd = [value descriptionWithLocale:locale indent:indent1];
		else 
			if ([value respondsToSelector:@selector(descriptionWithLocale:)])
				vd = [value descriptionWithLocale: locale];
			else
				vd = [value description];

		s = [vd cString];					// if str with whitespc add quotes
		if(*s != '{' && *s != '(' && *s != '<')
			if((strpbrk(s, " %-\t") != NULL))
				vd = [NSString stringWithFormat: @"\"%@\"", vd];

		(*imp)(desc, sel, indentation);		// append description to string rep
		(*imp)(desc, sel, kd);
		(*imp)(desc, sel, @" = ");
		(*imp)(desc, sel, vd);
		(*imp)(desc, sel, @";\n");
		}

	format = [NSString stringWithFormat:@"%%%dc}", indent];
    (*imp)(desc, sel, indent ? [NSMutableString stringWithFormat: format, ' ']
							 : [NSMutableString stringWithCString:"}"]);
    [pool release];

    return desc;
}

- (NSString *) descriptionInStringsFileFormat
{
	id key, value;
	NSEnumerator *enumerator;
	NSMutableString *description = [[NSMutableString new] autorelease];
	id pool = [NSAutoreleasePool new];
	NSMutableArray *keys = [[[self allKeys] mutableCopy] autorelease];

    [keys sortUsingSelector:@selector(compare:)];
    enumerator = [keys objectEnumerator];

    while((key = [enumerator nextObject])) 
		{
		value = [self objectForKey:key];

		[description appendString:key];
		[description appendString:@" = "];
		[description appendString:value];
		[description appendString:@";\n"];
		}
    [pool release];

    return description;
}

- (NSString *) descriptionWithLocale:(id)locale
{
    return [self descriptionWithLocale:locale indent:0];
}

- (NSString *) description
{
    return [self descriptionWithLocale:nil indent:0];
}

- (NSString *) stringRepresentation
{
    return [self descriptionWithLocale:nil indent:0];
}

- (BOOL) writeToFile:(NSString*)path atomically:(BOOL)useAuxiliaryFile
{
	return [[self description] writeToFile:path atomically:useAuxiliaryFile];
}

- (BOOL) isEqual:(id)anObject
{
	if ([anObject isKindOfClass:[NSDictionary class]] == NO)
		return NO;

    return [self isEqualToDictionary:anObject];
}

- (NSUInteger) hash					{ return [self count]; }
- (id) copy							{ return [self retain]; }

- (id) mutableCopy
{
    return [[NSMutableDictionary alloc] initWithDictionary:self];
}

- (Class) classForCoder				{ return [NSDictionary class]; }

- (void) encodeWithCoder:(NSCoder*)aCoder
{
	NSUInteger count = [self count];
	NSEnumerator *enumerator = [self keyEnumerator];
	id key, value;

    [aCoder encodeValueOfObjCType:@encode(NSUInteger) at:&count];
    while((key = [enumerator nextObject])) 
		{
		value = [self objectForKey:key];
		[aCoder encodeObject:key];
		[aCoder encodeObject:value];
		}
}

- (id) initWithCoder:(NSCoder*)aDecoder
{
	NSUInteger i, count;

    [aDecoder decodeValueOfObjCType:@encode(NSUInteger) at:&count];
	if(count > 0)
		{
		id *keys = malloc(sizeof(id) * count);
		id *values = malloc(sizeof(id) * count);
	
		for(i = 0; i < count; i++) 
			{
			keys[i] = [aDecoder decodeObject];
			values[i] = [aDecoder decodeObject];
			}
	
		[self initWithObjects:values forKeys:keys count:count];
	
		free(keys);
		free(values);
		}

    return self;
}

@end /* NSDictionary */

/* ****************************************************************************

	NSMutableDictionary, _NSMutableDictionary

** ***************************************************************************/

@implementation NSMutableDictionary

+ (id) alloc				{ return NSAllocateObject(__NSMutableDictionary); }

+ (id) dictionaryWithCapacity:(NSUInteger)numItems
{
    return [[[self alloc] initWithCapacity: numItems] autorelease];
}

- (id) init					{ return [self initWithCapacity:0]; }
- (Class) classForCoder		{ return [NSMutableDictionary class]; }

- (id) copy
{
    return [[NSDictionary alloc] initWithDictionary:self copyItems:YES];
}

- (void) setDictionary:(NSDictionary*)otherDictionary
{
    [self removeAllObjects];
    [self addEntriesFromDictionary:otherDictionary];
}

@end /* NSMutableDictionary */


@implementation _NSMutableDictionary

- (id) initWithCapacity:(NSUInteger)numItems
{
    _table = NSCreateMapTable(NSObjectMapKeyCallBacks,
							  NSObjectMapValueCallBacks, (numItems * 4) / 3);
    return self;
}

- (void) setObject:(id)anObject forKey:(id)aKey		// Modifying a dictionary
{
    if (!anObject || !aKey)
		[NSException raise: NSInvalidArgumentException
					 format: @"Tried to add nil object to dictionary"];
    NSMapInsert(_table, aKey, anObject);
}

- (void) addEntriesFromDictionary:(NSDictionary*)other
{
	id key, nodes = [other keyEnumerator];		// Add and Remove Entries

    while ((key = [nodes nextObject]))
		[self setObject:[other objectForKey:key] forKey:key];
}

- (void) removeObjectForKey:(id)aKey	{ NSMapRemove(_table, aKey); }
- (void) removeAllObjects				{ NSResetMapTable(_table); }

@end /* _NSMutableDictionary */
