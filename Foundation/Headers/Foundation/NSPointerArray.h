/*
   NSPointerArray.h

   Ordered collection of pointers which can be NULL

   Copyright (C) 2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	May 2018

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSPointerArray
#define _mGSTEP_H_NSPointerArray

#include <Foundation/NSObject.h>

@class NSArray;


typedef enum _NSPointerFunctionsOptions {

    NSPointerFunctionsStrongMemory		= (0UL << 0),			// default
    NSPointerFunctionsOpaqueMemory		= (2UL << 0),
    NSPointerFunctionsMallocMemory		= (3UL << 0),
//  NSPointerFunctionsMachVirtualMemory = (4UL << 0),
//  NSPointerFunctionsWeakMemory		= (5UL << 0),
	
    NSPointerFunctionsObjectPersonality	       = (0UL << 8),	// default
    NSPointerFunctionsOpaquePersonality        = (1UL << 8),
    NSPointerFunctionsObjectPointerPersonality = (2UL << 8),
    NSPointerFunctionsCStringPersonality       = (3UL << 8),
    NSPointerFunctionsStructPersonality        = (4UL << 8),
    NSPointerFunctionsIntegerPersonality       = (5UL << 8),

    NSPointerFunctionsCopyIn			= (1UL << 16),

} NSPointerFunctionsOptions;

/* ****************************************************************************

	NSPointerFunctions

	Memory and Personality options are mutually exclusive (select one of each)

	-- Memory --
    Strong		strong write-barrier to back store, use GC memory on copy-in,
				when used with objects will retain/release if no GC
    Opaque
    Malloc		free() called on removal, calloc() on copy-in
    Weak		weak read, write barriers appropriate for ARC or GC

	-- Personality --
	Object		 -hash AND -isEqual, object description
	Opaque		 shifted pointer hash AND direct equality (==)
	ObjectPointer shifted ptr hash AND direct equality (==), object description
	CString		 cString hash AND strcmp equality, UTF-8 or ASCII description
	Struct		 memory hash AND memcmp (via caller defined/set size function)
	Integer		 unshifted value as hash AND direct equality (==)

	-- Hint --
	CopyIn		 memory acquire function allocs and copies items on input


	examples:
	
	-- non-owned cstrings:
		NSPointerFunctionsOpaqueMemory | NSPointerFunctionsCStringPersonality
	-- owned cstrings:
		NSPointerFunctionsOpaqueMemory | NSPointerFunctionsCStringPersonality
									   | NSPointerFunctionsCopyIn
	-- non-owned pointers:
		NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality
	-- store long ints != 0:
		NSPointerFunctionsOpaqueMemory | NSPointerFunctionsIntegerPersonality
	-- store strongly held objects:  (e.g. retain, release, ARC)
		NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPersonality

** ***************************************************************************/


@interface NSPointerFunctions : NSObject  <NSCopying>
{
	NSPointerFunctionsOptions _options;

	void (*_relinquish)(const void *item, NSUInteger (*size)(const void *item));
	void *(*_acquire)(const void *src,    NSUInteger (*size)(const void *item),
						BOOL shouldCopy);
	NSUInteger (*_size)(const void *item);

	NSString  *(*_describe)(const void *item);		// for hash and map tables
	NSUInteger (*_hash)(const void *item, NSUInteger (*size)(const void *item));
	BOOL       (*_isEqual)(const void *item1, const void*item2,
							NSUInteger (*size)(const void *item));

  //  GC requires that read and write barrier functions be used when pointers
  //  are from GC memory. Flags to set weak/strong pointers in a GC environment
  //  using such a barrier are deprecated in OSX and missing here.
}

+ (id) pointerFunctionsWithOptions:(NSPointerFunctionsOptions)options;

- (id) initWithOptions:(NSPointerFunctionsOptions)options;

- (void) setSizeFunction:(NSUInteger (*)(const void *))sizeFunction;
- (void) setAcquireFunction:(void *(*)(const void *,
							NSUInteger (*)(const void *), BOOL))acquireFunction;
- (void) setRelinquishFunction:(void (*)(const void *,
							   NSUInteger (*)(const void *)))relinquishFunction;
@end

/* ****************************************************************************

	NSPointerArray

	* Can store NULLs which are 'counted' and can be inserted or deleted
	* Count of array can be set directly.
	
** ***************************************************************************/

@interface NSPointerArray : NSObject  <NSCopying, NSCoding> // NSFastEnumeration
{
	NSPointerFunctions *_functions;
	NSUInteger _capacity;
	NSUInteger _count;
	void **_contents;
}

+ (id) pointerArrayWithOptions:(NSPointerFunctionsOptions)options;
+ (id) pointerArrayWithPointerFunctions:(NSPointerFunctions *)functions;

- (id) initWithOptions:(NSPointerFunctionsOptions)options;
- (id) initWithPointerFunctions:(NSPointerFunctions *)functions;

- (NSPointerFunctions *) pointerFunctions;		// object with in-use functions

- (void *) pointerAtIndex:(NSUInteger)index;

- (void) addPointer:(void *)ptr;
- (void) removePointerAtIndex:(NSUInteger)index;
- (void) insertPointer:(void *)ptr atIndex:(NSUInteger)index;

- (void) replacePointerAtIndex:(NSUInteger)index withPointer:(void *)ptr;

- (void) compact;
- (void) setCount:(NSUInteger)count;
- (NSUInteger) count;

@end


@interface NSPointerArray (NSPointerArrayConveniences_NotImplemented)

+ (id) strongObjectsPointerArray;
+ (id) weakObjectsPointerArray;

- (NSArray *) allObjects;

@end

#endif  /* _mGSTEP_H_NSPointerArray */
