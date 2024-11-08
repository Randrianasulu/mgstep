/*
   NSObject.m

   Root object class

   Copyright (C) 1994-2021 Free Software Foundation, Inc.

   Author:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date:	August 1994
   Rewrite: Felipe A. Rodriguez <far@illumenos.com>
   Date: 	October 2015

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObject.h>
#include <Foundation/Protocol.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSInvocation.h>


static id  __releaseClass = nil;		// Class responsible for autorelease
static IMP __releaseIMP = 0;

extern IMP  __objcMessageForwarding(id receiver, SEL sel);
extern void __initBridgeClass(void);


@implementation NSObject

+ (void) initialize
{
	if (self == [NSObject class])
		{
		__releaseClass = [NSAutoreleasePool class];
      	__releaseIMP = [__releaseClass methodForSelector:@selector(addObject:)];
#ifdef __GNU_LIBOBJC__							// set runtime forwarding hook
		__objc_msg_forward2 = __objcMessageForwarding;
#endif
#ifdef __USE_LIBOBJC2__
		__objc_msg_forward3 = __objcMessageForwarding;
#endif
		__initBridgeClass();					// Bridge Obj-C <--> C
		}
}

+ (void) setVersion:(int)aVersion
{
	if (aVersion < 0)
		[self error:"%s +setVersion: may not set a negative version", 
			  object_get_class_name(self)];
	class_set_version(self, aVersion);
}

+ (id) alloc						{ return NSAllocateObject(self); }
+ (id) new							{ return [[self alloc] init]; }
+ (int) version						{ return class_get_version(self); }
+ (Class) class						{ return self; }
- (Class) class						{ return object_get_class(self); }
+ (Class) superclass				{ return class_get_super_class(self); }
#ifdef NEW_RUNTIME
- (Class) superclass				{ return class_getSuperclass(object_getClass(self)); }
#else
- (Class) superclass				{ return object_get_super_class(self); }
#endif
- (void) dealloc					{ NSDeallocateObject(self); }
- (id) init							{ return self; }
- (id) self							{ return self; }
- (id) copy							{ return [self retain]; }
- (id) mutableCopy					{ return SUBCLASS }

- (NSString*) description
{
	return [NSString stringWithCString: object_get_class_name(self)];
}

+ (NSString*) description
{
	return [NSString stringWithCString: class_get_class_name(self)];
}

+ (BOOL) instancesRespondToSelector:(SEL)aSelector
{
#ifndef NEW_RUNTIME
	return (class_get_instance_method(self, aSelector) != METHOD_NULL);
#else
	return class_respondsToSelector(self, aSelector);
#endif
}

+ (BOOL) conformsToProtocol:(Protocol*)aProtocol
{
#ifdef NEW_RUNTIME	// GCC 4.6+
	Class c;

	for (c = self; c != Nil; c = class_get_super_class(c))
		if (class_conformsToProtocol(c, aProtocol))
			return YES;
#else					// pre GCC 4.6 implementation
	size_t i;
	struct objc_protocol_list *proto_list = ((Class)self)->protocols;
	id parent;

	for (; proto_list; proto_list = proto_list->next)
		for (i = 0; i < proto_list->count; i++)
			if ([proto_list->list[i] conformsTo: aProtocol])
				return YES;

	if ((parent = [self superclass]))
		return [parent conformsToProtocol: aProtocol];
#endif

	return NO;
}

- (BOOL) conformsToProtocol:(Protocol*)aProtocol
{
	return [[self class] conformsToProtocol: aProtocol];
}

#ifndef NEW_RUNTIME
+ (IMP) instanceMethodForSelector:(SEL)aSelector
{
	return (IMP)method_get_imp(class_get_instance_method(self, aSelector));
}
  
- (IMP) methodForSelector:(SEL)aSelector
{
	return (IMP)(method_get_imp(object_is_instance(self)
                         ? class_get_instance_method(self->isa, aSelector)
                         : class_get_class_method(self->isa, aSelector)));
}
#else
IMP method_get_imp(Method method);

+ (IMP) instanceMethodForSelector:(SEL)aSelector
{
	return class_getMethodImplementation(self, aSelector);
//	return (IMP)method_getImplementation(class_getInstanceMethod(self, aSelector));
//	return (IMP)method_get_imp(class_getInstanceMethod(self, aSelector));
}
  
- (IMP) methodForSelector:(SEL)aSelector
{
//	return objc_msg_lookup(self, aSelector);
	return class_getMethodImplementation(object_getClass(self), aSelector);
//	return (IMP)(method_get_imp(object_is_instance(self)
//                         ? class_getInstanceMethod(self->isa, aSelector)
//                         : class_getClassMethod(self->isa, aSelector)));
}
#endif

- (id) awakeAfterUsingCoder:(NSCoder*)aDecoder			{ return self; }
- (id) replacementObjectForCoder:(NSCoder*)anEncoder	{ return self; }
- (id) initWithCoder:(NSCoder*)aDecoder					{ return self; }
- (void) encodeWithCoder:(NSCoder*)aCoder				{ return; }
- (Class) classForArchiver				{ return [self classForCoder]; }
- (Class) classForCoder					{ return [self class]; }

- (id) replacementObjectForArchiver:(NSArchiver*)anArchiver
{
	return [self replacementObjectForCoder: (NSCoder*)anArchiver];
}

+ (id) autorelease					{ return self; }
+ (id) retain						{ return self; }
+ (oneway void) release				{ return; }
+ (NSUInteger) retainCount			{ return ULONG_MAX; }
- (NSUInteger) retainCount			{ return NSExtraRefCount(self); }

- (id) autorelease
{
	(*__releaseIMP)(__releaseClass, @selector(addObject:), self);
	return self;
}

- (oneway void) release
{
	if (NSDecrementExtraRefCountWasZero(self))
		[self dealloc];
}

- (id) retain
{
	NSIncrementExtraRefCount(self);			// ((obj_t)(self))[-1].retained++;
	return self;
}

- (BOOL) isKindOfClass:(Class)aClass
{
	return _classIsKindOfClass(self->isa, aClass);
}

- (NSUInteger) hash							{ return PTR2LONG(self); }
- (BOOL) isEqual:(id)anObject				{ return (self == anObject); }
- (BOOL) isMemberOfClass:(Class)cls			{ return self->isa == cls; }
- (BOOL) isProxy							{ return NO; }

/* ****************************************************************************

	Dynamic method resolving is invoked prior to the forwarding mechanism.  
	Can be used to dynamically add and provide an IMP for the given selector.

** ***************************************************************************/

+ (BOOL) resolveClassMethod:(SEL)sel		{ return NO; }
+ (BOOL) resolveInstanceMethod:(SEL)sel		{ return NO; }

- (BOOL) respondsToSelector:(SEL)aSelector
{
#ifdef NEW_RUNTIME
	Class cls = object_getClass(self);

	if (class_respondsToSelector(cls, aSelector))
		return YES;

	if (class_isMetaClass(cls))  				// also called by runtime
		return [(Class)self resolveClassMethod: aSelector];

	return [cls resolveInstanceMethod: aSelector];
#else
	if (CLS_ISCLASS(((Class)self)->class_pointer))
		return (class_get_instance_method(self->isa, aSelector) != METHOD_NULL);

	return (class_get_class_method(self->isa, aSelector) != METHOD_NULL);
#endif
}

- (void) doesNotRecognizeSelector:(SEL)aSelector
{
#ifdef NEW_RUNTIME
	[self error:"%s does not recognize %s",
				object_getClassName(self), sel_getName(aSelector)];
#else
	[self error:"%s does not recognize %s",
				object_get_class_name(self), sel_get_name(aSelector)];
#endif
}
					// implemented by subclasses to actually do something
- (void) forwardInvocation:(NSInvocation*)anInvocation
{
	[self doesNotRecognizeSelector:[anInvocation selector]];
}

- (id) performSelector:(SEL)aSelector
{
	IMP msg = objc_msg_lookup(self, aSelector);

	if (!msg)
		return [self error:"invalid selector passed to %s",sel_get_name(_cmd)];

	return (*msg)(self, aSelector);
}

- (id) performSelector:(SEL)aSelector withObject:(id)anObject
{
	IMP msg = objc_msg_lookup(self, aSelector);

	if (!msg)
		return [self error:"invalid selector passed to %s",sel_get_name(_cmd)];

	return (*msg)(self, aSelector, anObject);
}

- (id) performSelector:(SEL)aSelector withObject:(id)obj1 withObject:(id)obj2
{
	IMP msg = objc_msg_lookup(self, aSelector);

	if (!msg)
		return [self error:"invalid selector passed to %s",sel_get_name(_cmd)];

	return (*msg)(self, aSelector, obj1, obj2);
}

+ (NSMethodSignature*) instanceMethodSignatureForSelector:(SEL)sel
{
#ifdef NEW_RUNTIME
	Method m = class_getInstanceMethod (object_getClass(self), sel);
	const char *types = method_getTypeEncoding (m);
//	const char *types = sel_getTypeEncoding (sel);
#else
	struct objc_method *m = class_get_instance_method(self, sel);
	const char *types = (m) ? m->method_types : NULL;
#endif

	if (!types)
		return (NSMethodSignature*)nil;

    return [NSMethodSignature signatureWithObjCTypes: types];
}

- (NSMethodSignature*) methodSignatureForSelector:(SEL)sel
{
#ifdef NEW_RUNTIME
	Method m;
	const char *types;

	if (object_is_instance(self))
		m = class_getInstanceMethod (object_getClass(self), sel);
	else
		m = class_getClassMethod (object_getClass(self), sel);

	if (!(types = method_getTypeEncoding (m)))
		return (NSMethodSignature*)nil;

    return [NSMethodSignature signatureWithObjCTypes: types];

#else
	struct objc_method *m = (object_is_instance(self) 
						? class_get_instance_method(self->isa, sel)
						: class_get_class_method(self->isa, sel));

    return (m) ? [NSMethodSignature signatureWithObjCTypes:m->method_types]
			   : (NSMethodSignature*)nil;
#endif
}

@end



@implementation NSObject (NeXTSTEP)					// NeXTSTEP Object class 
													// compatibility & misc
void
objc_verror(id object, int code, const char* fmt, va_list ap)
{
	BOOL result = NO;								// Trigger an objc error

  /* Call the error handler if its there Otherwise print to stderr */
//	if (_objc_error_handler)
//		result = (*_objc_error_handler)(object, code, fmt, ap);
//	else
		vfprintf (stderr, fmt, ap);

	if (result)										// Continue if the error 
		return;										// handler says its ok
													// Otherwise abort program
	abort();
}

- (id) error:(const char *)aString, ...
{
	char format[] = "error: %s (%s)\n%s\n";
	int a = strlen((char*)format);
	int b = strlen((char*)object_get_class_name(self));
	char fmt[(a + b + ((aString != NULL) ? strlen((char*)aString) : 0) + 8)];
	va_list ap;

	sprintf(fmt, format, object_get_class_name(self),
						 object_is_instance(self) ? "instance" : "class",
						 (aString != NULL) ? aString : "");
	va_start(ap, aString);
	objc_verror (self, 0, fmt, ap);					// What should `code' 
	va_end(ap);										// argument be?  Current 0.

	return nil;
}

- (BOOL) respondsTo:(SEL)aSel	{ return [self respondsToSelector: aSel]; }
- (IMP) methodFor:(SEL)aSel		{ return [self methodForSelector:aSel]; }

- (id) notImplemented:(SEL)aSel
{
	return [self error:"method %s not implemented", sel_get_name(aSel)];
}

- (id) shouldNotImplement:(SEL)aSel
{
	return [self error:"%s should not implement %s", 
	             object_get_class_name(self), sel_get_name(aSel)];
}

- (id) doesNotRecognize:(SEL)aSel
{
	[self doesNotRecognizeSelector: aSel];
	return nil;
}

#ifdef NEW_RUNTIME

+ (void) poseAsClass:(Class)aClass	{ NIMP; }

- (BOOL) isClass	// If obj is a class, the meta class is returned; if obj
{					// is a meta class, the root meta class is returned
	return class_isMetaClass( object_getClass(self) );
}
#else
- (BOOL) isClass					{ return object_is_class(self); }
+ (void) poseAsClass:(Class)aClass	{ class_pose_as(self, aClass); }
#endif

- (BOOL) isMetaClass				{ return NO; }
- (BOOL) isInstance					{ return object_is_instance(self); }

- (BOOL) isMemberOfClassNamed:(const char *)name
{
	return (name && !strcmp(class_get_class_name(self->isa), name));
}

- (Class) transmuteClassTo:(Class)aClassObject
{
#ifdef NEW_RUNTIME
	return object_setClass(self, aClassObject);
#else
	Class old_isa = nil;	// Change the class of object to be class_.
							// Return the previous class of object.
	if (object_is_instance(self) && (class_is_class(aClassObject)))
		{
		old_isa = isa;
		isa = aClassObject;
		}

	return old_isa;
#endif
}

- (id) subclassResponsibility:(SEL)aSel
{
	return [self error:"subclass should override %s", sel_get_name(aSel)];
}

- (NSComparisonResult) compare:(id)anObject
{
	if ([self isEqual:anObject])
		return 0;

	return ((id)self > anObject) ? 1 : -1;
}

- (id) copyWithZone:(id)zone				{ return [self retain]; }
- (id) zone									{ return nil; }

@end
