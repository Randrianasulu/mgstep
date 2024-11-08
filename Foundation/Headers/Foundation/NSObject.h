/*
   NSObject.h

   Root object class interface

   Copyright (C) 1994-2021 Free Software Foundation, Inc.

   Author:	Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date:	August 1995

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSObject
#define _mGSTEP_H_NSObject

#include <Foundation/NSObjCRuntime.h>

@class NSArchiver;
@class NSCoder;
@class NSPortCoder;
@class NSMethodSignature;
@class NSString;
@class NSInvocation;
@class Protocol;


@protocol NSObject

- (Class) class;
- (Class) superclass;
- (BOOL) isEqual: anObject;
- (BOOL) isKindOfClass:(Class)aClass;
- (BOOL) isMemberOfClass:(Class)aClass;
- (BOOL) respondsToSelector:(SEL)aSelector;
- (BOOL) conformsToProtocol:(Protocol *)aProtocol;
- (BOOL) isProxy;
- (NSUInteger) hash;
- (id) self;
- (id) performSelector:(SEL)aSelector;
- (id) performSelector:(SEL)aSelector withObject:(id)anObject;
- (id) performSelector:(SEL)aSelector withObject:object1 withObject:object2;
- (id) retain;
- (id) autorelease;
- (oneway void) release;
- (NSUInteger) retainCount;
- (NSString *) description;

@end


@protocol NSCopying

- (id) copy;

@end


@protocol NSMutableCopying

- (id) mutableCopy;

@end


@protocol NSCoding

- (void) encodeWithCoder:(NSCoder*)aCoder;
- (id) initWithCoder:(NSCoder*)aDecoder;

@end


@interface NSObject  <NSObject, NSCoding>
{												
    Class isa;										// pointer to instance's 
}													// class structure

+ (void) initialize;

+ (Class) class;
+ (Class) superclass;

+ (id) alloc;
+ (id) new;

+ (void) setVersion:(int)aVersion;
+ (int) version;

+ (BOOL) instancesRespondToSelector:(SEL)aSelector;
+ (IMP) instanceMethodForSelector:(SEL)aSelector;
- (IMP) methodForSelector:(SEL)aSelector;

+ (NSString *) description;
- (NSString *) description;

- (id) init;
- (void) dealloc;

- (id) copy;
- (id) mutableCopy;

- (Class) classForArchiver;
- (id) replacementObjectForArchiver:(NSArchiver*)anEncoder;

- (Class) classForCoder;
- (id) awakeAfterUsingCoder:(NSCoder*)aDecoder;
- (id) replacementObjectForCoder:(NSCoder*)anEncoder;

- (void) doesNotRecognizeSelector:(SEL)aSelector;
- (void) forwardInvocation:(NSInvocation*)anInvocation;

@end


@interface NSObject (NeXTSTEP)

- (BOOL) respondsTo:(SEL)aSel;

- (id) error:(const char *)aString, ...;
- (id) notImplemented:(SEL)aSel;
- (id) shouldNotImplement:(SEL)aSel;
- (id) doesNotRecognize:(SEL)aSel;
- (id) subclassResponsibility:(SEL)aSel;
- (Class) transmuteClassTo:(Class)aClassObject;
- (NSComparisonResult) compare:(id)anObject;
+ (void) poseAsClass:(Class)aClass;

@end


@interface NSObject (DistributedObjects)

+ (NSMethodSignature*) instanceMethodSignatureForSelector:(SEL)aSelector;
- (NSMethodSignature*) methodSignatureForSelector:(SEL)aSelector;

@end


extern id NSAllocateObject(Class aClass);
extern id NSCopyObject(NSObject *object);
extern void NSDeallocateObject(NSObject *object);

NSUInteger NSExtraRefCount(id object);
void NSIncrementExtraRefCount(id object);
BOOL NSDecrementExtraRefCountWasZero(id object);

#endif /* _mGSTEP_H_NSObject */
