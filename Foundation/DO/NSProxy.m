/*
   NSProxy.m

   Abstract class of objects that act as stand-ins for other objects

   Copyright (C) 1997 Free Software Foundation, Inc.

   Author:	Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date:	August 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSProxy.h>
#include <Foundation/NSInvocation.h>
#include <Foundation/NSMethodSignature.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSException.h>



@implementation NSProxy

+ (id) alloc					{ return (NSProxy*) NSAllocateObject(self); }
+ (id) autorelease				{ return self; }
+ (id) retain					{ return self; }
+ (void) release				{ }
+ (Class) superclass			{ return class_get_super_class(self); }
+ (Class) class					{ return self; }
+ (void) load					{ }

+ (NSString*) description
{
	return [NSString stringWithFormat: @"<%s>", object_get_class_name(self)];
}

+ (BOOL) respondsToSelector:(SEL)aSelector
{
	return (class_get_class_method(self, aSelector) != METHOD_NULL);
}

+ (NSUInteger) retainCount		{ return ULONG_MAX; }
- (NSUInteger) retainCount		{ return _retain_count + 1; }
- (id) init						{ return self; }
- (id) self						{ return self; }
#ifdef NEW_RUNTIME
- (Class) superclass	{ return class_getSuperclass(object_getClass(self)); }
#else
- (Class) superclass			{ return object_get_super_class(self); }
#endif
- (Class) class					{ return object_get_class(self); }
- (void) dealloc				{ NSDeallocateObject((NSObject*)self); }

- (id) autorelease
{
	[NSAutoreleasePool addObject:self];
	return self;
}

- (void) release
{
	if (_retain_count-- == 0)
		[self dealloc];
}

- (id) retain
{
	_retain_count++;
	return self;
}

- (BOOL) conformsToProtocol:(Protocol*)aProtocol
{
NSInvocation *inv;
NSMethodSignature *sig;
BOOL result;

	sig = [self methodSignatureForSelector:@selector(conformsToProtocol:)];
	inv = [NSInvocation invocationWithMethodSignature:sig];
	[inv setSelector:@selector(conformsToProtocol:)];
	[inv setArgument:aProtocol atIndex:2];
	[self forwardInvocation:inv];
	[inv getReturnValue: &result];

	return result;
}

- (NSString*) description
{
	return [NSString stringWithFormat: @"<%s %lx>",
						object_get_class_name(self), (unsigned long)self];
}

- (void) forwardInvocation:(NSInvocation*)anInvocation
{
	[NSException raise: NSInvalidArgumentException
			   format:@"NSProxy should not implement '%s'",sel_get_name(_cmd)];
}

- (NSUInteger) hash							{ return PTR2LONG(self); }
- (BOOL) isEqual:(id)anObject				{ return (self == anObject); }
- (BOOL) isMemberOfClass:(Class)aClass		{ return(self->isa == aClass); }
- (BOOL) isProxy							{ return YES; }

- (BOOL) isKindOfClass:(Class)aClass
{
	return _classIsKindOfClass(self->isa, aClass);
}

- (id) notImplemented:(SEL)aSel
{
	[NSException raise: NSGenericException
				 format: @"NSProxy notImplemented %s", sel_get_name(aSel)];
	return self;
}

- (NSMethodSignature*) methodSignatureForSelector:(SEL)aSelector
{
	[NSException raise: NSInvalidArgumentException 
		format: @"NSProxy should not implement 'methodSignatureForSelector:'"];

	return nil;
}

- (id) performSelector:(SEL)aSelector
{
IMP msg = objc_msg_lookup(self, aSelector);

	if (!msg)
		{
		[NSException raise: NSGenericException 
					 format: @"invalid selector passed to %s",
						sel_get_name(_cmd)];
		return nil;
		}
	return (*msg)(self, aSelector);
}

- (id) performSelector:(SEL)aSelector withObject:(id)anObject
{
IMP msg = objc_msg_lookup(self, aSelector);

	if (!msg)
		{
		[NSException raise: NSGenericException
					 format: @"invalid selector passed to %s",
								sel_get_name(_cmd)];
		return nil;
		}
	return (*msg)(self, aSelector, anObject);
}

- (id) performSelector:(SEL)aSelector
			withObject:(id)anObject
			withObject:(id)anotherObject
{
IMP msg = objc_msg_lookup(self, aSelector);

	if (!msg)
		{
		[NSException raise: NSGenericException
					 format: @"invalid selector passed to %s",
							sel_get_name(_cmd)];
		return nil;
		}
	return (*msg)(self, aSelector, anObject, anotherObject);
}

- (BOOL) respondsToSelector:(SEL)aSelector
{
NSInvocation *inv;
NSMethodSignature *sig;
BOOL result;
	
	sig = [self methodSignatureForSelector:@selector(respondsToSelector:)];
	inv = [NSInvocation invocationWithMethodSignature:sig];
	[inv setSelector:@selector(respondsToSelector:)];
	[inv setArgument:(void*)aSelector atIndex:2];
	[self forwardInvocation:inv];
	[inv getReturnValue: &result];

	return result;
}

@end
