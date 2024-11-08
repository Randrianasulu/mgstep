/*
   NSObjCRuntime.m

   Obj-C runtime utilities 

   Copyright (C) 2015 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	October 2015

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <CoreFoundation/CFBase.h>

#include <Foundation/NSObject.h>
#include <Foundation/NSException.h>


static Class __CFBridgeClass = Nil;


/* ****************************************************************************

	Define a wrapper structure around each NSObject to store the reference
	count locally.  Required for legacy runtime compatibility.

** ***************************************************************************/

#define	UNP    sizeof(unp)
#define	ALIGN  __alignof__(double)

typedef struct obj_layout_unpadded
{									// Define a structure to hold data locally
    NSUInteger retained;			// before the start of each object
} unp;

									// Now wrap the other version to determine
struct obj_layout 					// what padding if any is required to get
{									// the alignment of the structure correct.
    NSUInteger retained;
    char padding[ALIGN - ((UNP % ALIGN) ? (UNP % ALIGN) : ALIGN)];
};

typedef	struct obj_layout *obj_t;



BOOL
NSDecrementExtraRefCountWasZero(id object) 			// reference count
{
	return (((obj_t)(object))[-1].retained-- == 0 ? YES : NO);
}

void
NSIncrementExtraRefCount(id object)
{
	((obj_t)(object))[-1].retained++;
}

NSUInteger
NSExtraRefCount(id object)
{
	return ((obj_t)(object))[-1].retained + 1;
}

inline id
NSAllocateObject(Class aClass)						// object allocation
{
	id new = nil;

	if (CLS_ISCLASS (aClass))
		{
		int size = aClass->instance_size + sizeof(struct obj_layout);		

		if ((new = malloc(size)) != NULL)
			{
			memset (new, 0, size);
			new = (id)&((obj_t)new)[1];
			new->class_pointer = aClass;
		}	}

	return new;
}

void
_CFBridgeInit(Class BridgeClass)
{
	__CFBridgeClass = BridgeClass;
}

void *
CFAllocatorAllocate (CFAllocatorRef a, CFIndex size, CFOptionFlags hint)
{
	id new = nil;

	if (size > 0)
		{
		size += sizeof(struct obj_layout) + __CFBridgeClass->instance_size;

		if ((new = malloc(size)) != NULL)
			{
			memset (new, 0, size);
			new = (id)&((obj_t)new)[1];
			new->class_pointer = __CFBridgeClass;
		}	}

	return new;
}

void *
CFAllocatorReallocate (CFAllocatorRef a, void *ptr, CFIndex size, CFOptionFlags h)
{
	obj_t o = &((obj_t)ptr)[-1];
	id new;

	if (size > 0)
		size += sizeof(struct obj_layout) + __CFBridgeClass->instance_size;

	if ((new = realloc(o, size)) != NULL)			// size 0 == free()
		{
		new = (id)&((obj_t)new)[1];
		new->class_pointer = __CFBridgeClass;
		}

	return new;
}

inline void
NSDeallocateObject(NSObject *anObject)				// object deallocation
{
	if (anObject != nil)
		{
		obj_t o = &((obj_t)anObject)[-1];

		((id)anObject)->class_pointer = (void*)0xdeadface;

		free(o);
		}
}

void
CFAllocatorDeallocate (CFAllocatorRef a, void *ptr)
{
	if (ptr != NULL)
		{
		obj_t o = &((obj_t)ptr)[-1];

		((id)ptr)->class_pointer = (void*)0xdeadface;

		free(o);
		}
}

id
NSCopyObject(NSObject *o)
{
	id c = NSAllocateObject(((id)o)->class_pointer);

	memcpy(c, o, ((id)o)->class_pointer->instance_size);

	return c;
}


#ifdef NEW_RUNTIME

BOOL
object_is_instance(id obj)
{
//	return (obj != nil) && CLS_ISCLASS(obj->class_pointer);
	return !class_isMetaClass(object_getClass(obj));
}
										// legacy GNU Objective-C Runtime API
const char *sel_get_name (SEL selector)
{
	if (selector == NULL)
		return 0;

	return sel_getName (selector);
}

BOOL
sel_types_match (const char *t1, const char *t2)
{											// Returns YES if t1 and t2 have
	if (!t1 || !t2)							// the same method types, but we 
		return NO;							// ignore the argframe layout

	while (*t1 && *t2)
		{
		if (*t1 == '+') 
			t1++;
		if (*t2 == '+') 
			t2++;
		while (isdigit(*t1)) 
			t1++;
		while (isdigit(*t2)) 
			t2++;

		if (!*t1 && !*t2)
			return YES;
		if (*t1 != *t2)
			return NO;
		t1++;
		t2++;
		}

	return NO;
}

#endif


NSString *
NSStringFromSelector(SEL aSelector)
{
	if (aSelector != (SEL)0)
		return [NSString stringWithFormat:@"%s", sel_get_name(aSelector)];

	return nil;
}

SEL
NSSelectorFromString(NSString *aSelectorName)
{
	if (aSelectorName != nil)
#ifdef NEW_RUNTIME				/* FIX ME old implementation should register */
		return sel_registerName([aSelectorName cString]);
#else
		return sel_get_uid([aSelectorName cString]);
//		return sel_get_any_uid([aSelectorName cString]);  // no register
#endif

	return (SEL)0;
}

Class
NSClassFromString(NSString *aClassName)
{
	if (aClassName != nil)
		return objc_lookup_class([aClassName cString]);

	return (Class)0;
}

NSString *
NSStringFromClass(Class aClass)
{
	if (aClass != (Class)0)
	   return [NSString stringWithCString:(char*)class_getName(aClass)];

	return nil;
}
