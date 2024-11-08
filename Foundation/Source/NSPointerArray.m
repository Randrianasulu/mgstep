/*
   NSPointerArray.m

   Ordered collection of pointers which can be NULL

   Copyright (C) 2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    May 2018

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSPointerArray.h>
#include <Foundation/NSException.h>
#include <Foundation/NSCoder.h>


#define PF_PTR			((_NSPointerFunctions *)_functions)
#define PF_COPY			((PF_PTR->_options & NSPointerFunctionsCopyIn) > 0)
#define ACQUIRE(x)		PF_PTR->_acquire(x, PF_PTR->_size, PF_COPY)
#define RELINQUISH(x)	PF_PTR->_relinquish(x, PF_PTR->_size)

typedef struct  { @defs(NSPointerFunctions); } _NSPointerFunctions;


static void *
_NSPointerArrayExtend( void *content, NSUInteger *size, NSUInteger extra)
{
	NSUInteger nsize = *size + extra;

	content = realloc(content, sizeof(void*) * nsize);
	memset(content + *size * sizeof(void*), 0, (nsize - *size) * sizeof(void*));
	*size = nsize;

    return content;
}


@implementation NSPointerArray

+ (id) pointerArrayWithOptions:(NSPointerFunctionsOptions)options
{
	return [[[self alloc] initWithOptions:options] autorelease];
}

+ (id) pointerArrayWithPointerFunctions:(NSPointerFunctions *)functions
{
	return [[[self alloc] initWithPointerFunctions:functions] autorelease];
}

- (id) initWithOptions:(NSPointerFunctionsOptions)options
{
	_contents = _NSPointerArrayExtend(_contents, &_capacity, 256);
	_functions = [[NSPointerFunctions alloc] initWithOptions:options];

	return self;
}

- (id) initWithPointerFunctions:(NSPointerFunctions *)functions
{
	_contents = _NSPointerArrayExtend(_contents, &_capacity, 256);
	_functions = [functions retain];

	return self;
}

- (id) init
{
	return [self initWithOptions: NSPointerFunctionsStrongMemory
								| NSPointerFunctionsObjectPersonality];
}

- (void) dealloc
{
	if (_contents)
		{
		NSUInteger i = MIN(_count, _capacity);

		while (i-- > 0)
			if (_contents[i] != NULL)
				RELINQUISH(_contents[i]),	_contents[i] = NULL;

		free(_contents);
		}
	[_functions release];

    [super dealloc];
}

- (id) copy
{
	return self;
}

- (NSPointerFunctions *) pointerFunctions
{
	return [_functions copy];
}

- (void *) pointerAtIndex:(NSUInteger)index
{
	if (index >= _count)
		[NSException raise:NSRangeException format:@"%d out of range", index];

	return (index >= _capacity) ? NULL : _contents[index];
}

- (void) addPointer:(void *)ptr
{
	if (_count >= _capacity)
		_contents = _NSPointerArrayExtend(_contents, &_capacity, _count * 2);
	_contents[_count] = ACQUIRE(ptr);
	_count++;
}

- (void) removePointerAtIndex:(NSUInteger)index
{
	if (index >= _count)
		[NSException raise:NSRangeException format:@"%d out of range", index];

	if (index < _capacity - 1)					// move allocd items down
		{
		NSUInteger shift = MIN(_capacity, _count) - 1 - index;

		if (_contents[index] != NULL)
			RELINQUISH(_contents[index]);

		memmove(&_contents[index], &_contents[index+1], shift * sizeof(void *));
		_contents[shift+index] = NULL;			// NULL hole at end
		}
	_count--;
}

- (void) insertPointer:(void *)ptr atIndex:(NSUInteger)index
{
	if (index >= _count)
		[NSException raise:NSRangeException format:@"%d out of range", index];

	if (_count + 1 >= _capacity)				// insert into new alloc
		_contents = _NSPointerArrayExtend(_contents, &_capacity, _count * 2);
												// slide content up, making hole
	memmove(&_contents[index+1], &_contents[index], (_count - index) * sizeof(void *));
	_contents[index] = ACQUIRE(ptr);
	_count++;
}

- (void) replacePointerAtIndex:(NSUInteger)index withPointer:(void *)ptr
{
	if (index >= _count)						// index must be < count
		[NSException raise:NSRangeException format:@"%d out of range", index];
	if (index >= _capacity)
		_contents =  _NSPointerArrayExtend(_contents, &_capacity, index * 2);
	if (_contents[index] != NULL)
		RELINQUISH(_contents[index]);
	_contents[index] = ACQUIRE(ptr);
}

- (void) compact
{
	NSUInteger count = (_capacity) ? MIN(_count, _capacity) - 1 : 0;
	NSUInteger i;

	for (i = 0; i < count; i++)
		if (_contents[i] == NULL)			// remove NULL entries
			{
			memmove(&_contents[i], &_contents[i+1], (count - i) * sizeof(void *));
			_count--;
			}
}

- (void) setCount:(NSUInteger)count			// set number of elements
{											// adds NULLs or removes items
	if (count < _count && _capacity > count)
		{
		NSUInteger i = _capacity;

		while (i-- > count)					// shrink allocd entries
			if (_contents[i] != NULL)
				RELINQUISH(_contents[i]),	_contents[i] = NULL;
		}									// FIX ME should we reduce array ?
	_count = count;
}

- (NSUInteger) count							{ return _count; }
- (void) encodeWithCoder:(NSCoder *)coder		{ }
- (id) initWithCoder:(NSCoder *)coder			{ return self; }

@end  /* NSPointerArray */

/* ****************************************************************************

	NSPointerFunctions

** ***************************************************************************/

static NSUInteger
size(const void *item)
{
    return sizeof(void *);
}

static NSUInteger
sizeCString(const void *item)
{
    return strlen((char *)item) + 1;
}

static NSUInteger
hash(const void *item, NSUInteger (*size)(const void *item))
{
    return (size) ? size(item) : 0;
}

static NSUInteger
hashCString(const void *item, NSUInteger (*size)(const void *item))
{
	NSUInteger hash = 5381;
    int c;

    while ((c = *(char *)item++))					// dbj2, Dan Bernstein
		hash = ((hash << 5) + hash) + c;			// hash * 33 + c

    return hash;
}

static NSUInteger
hashObject(const void *item, NSUInteger (*size)(const void *item))
{
    return [(id)item hash];
}

static BOOL
isEqual(const void *p1, const void *p2, NSUInteger (*size)(const void *item))
{
    return p1 == p2 ? YES : NO;
}

static BOOL
isEqualCString(const void *o1, const void *o2, NSUInteger (*size)(const void *))
{
    return (strcmp((char *)o1, (char *)o2) == 0);
}

static BOOL
isEqualObject(const void *o1, const void *o2, NSUInteger (*size)(const void *))
{
    return [(id)o1 isEqual:(id)o2];
}

static BOOL
isEqualStruct(const void *o1, const void *o2, NSUInteger (*size)(const void *))
{
    return (memcmp(o1, o2, size(o1)) == 0);
}

static NSString *
describe(const void *item)
{
    return [NSString stringWithFormat:@"%x", item];
}

static NSString *
describeCString(const void *item)
{
    return [NSString stringWithFormat:@"%s", (char *)item];
}

static NSString *
describeObject(const void *item)
{
    return [(id)item description];
}

static NSString *
describeStruct(const void *item)
{
    return [NSString stringWithFormat:@"%x (%d)", item, size(item)];
}

static void *
acquire(const void *src, NSUInteger (*size)(const void *), BOOL copy)
{
    return (void *)src;
}

static void *
acquireMemory(const void *src, NSUInteger (*size)(const void *), BOOL copy)
{
	if (copy && src != NULL)
		{
		NSUInteger s = size(src);
		void *m = calloc(1, s);

		memcpy(m, src, s);

		return m;
		}

    return (void *)src;
}

static void *
acquireObject(const void *src, NSUInteger (*size)(const void *), BOOL copy)
{
    return (copy) ? [(id)src copy] : [(id)src retain];
}

static void
relinquish(const void *item, NSUInteger (*size)(const void *))
{
}

static void
relinquishMemory(const void *item, NSUInteger (*size)(const void *))
{
	if (item)
		free((void *)item);
}

static void
relinquishObject(const void *item, NSUInteger (*size)(const void *))
{
	[(id)item release];
}


@implementation NSPointerFunctions

+ (id) pointerFunctionsWithOptions:(NSPointerFunctionsOptions)options
{
	return [[[self alloc] initWithOptions:options] autorelease];
}

- (id) initWithOptions:(NSPointerFunctionsOptions)options
{
	NSPointerFunctionsOptions mask = NSPointerFunctionsMallocMemory;

	_options = options;
															// Memory options
	if ((_options & mask) == NSPointerFunctionsOpaqueMemory)
		{
		_acquire = acquire;
		_relinquish = relinquish;
		}
	else if ((_options & mask) == NSPointerFunctionsMallocMemory)
		{
		_acquire = acquireMemory;
		_relinquish = relinquishMemory;
		_options |= NSPointerFunctionsCopyIn;				// implicit ?
		}
	else	// NSPointerFunctionsStrongMemory
		{
		_acquire = acquireObject;							// Strong default
		_relinquish = relinquishObject;
		}
															// ptr Personality
	mask = NSPointerFunctionsIntegerPersonality
		 | NSPointerFunctionsObjectPointerPersonality;
	if ((_options & mask) == NSPointerFunctionsOpaquePersonality)
		{
		_describe = describe;				// for use by hash and map tables
		_isEqual = isEqual;
		_hash = hash;
		_size = size;
		}
	else if ((_options & mask) == NSPointerFunctionsObjectPointerPersonality)
		{
		}
	else if ((_options & mask) == NSPointerFunctionsCStringPersonality)
		{
		_describe = describeCString;
		_isEqual = isEqualCString;
		_hash = hashCString;
		_size = sizeCString;
		}
	else if ((_options & mask) == NSPointerFunctionsIntegerPersonality)
		{
		}
	else if ((_options & mask) == NSPointerFunctionsStructPersonality)
		{
		_describe = describeStruct;
		_isEqual = isEqualStruct;
//		_size = sizeStruct;					// requires external function
		}
	else	// NSPointerFunctionsObjectPersonality
		{
		_describe = describeObject;							// Object default
		_isEqual = isEqualObject;
		_hash = hashObject;
		}

	return self;
}

- (id) copy
{
	return self;
}

- (void) setSizeFunction:(NSUInteger (*)(const void *))sizeFunction
{
	_size = sizeFunction;
}

- (void) setAcquireFunction:(void * (*)(const void *,
							NSUInteger (*)(const void *), BOOL))acquireFunction
{
	_acquire = acquireFunction;
}

- (void) setRelinquishFunction:(void (*)(const void *,
							   NSUInteger (*)(const void *)))relinquishFunction
{
	_relinquish = relinquishFunction;
}

@end  /* NSPointerFunctions */
