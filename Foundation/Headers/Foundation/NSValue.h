/*
   NSValue.h

   Interface to NSNumber and NSValue

   Copyright (C) 2000 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@pcmagic.net>
   Date:    June 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSValue
#define _mGSTEP_H_NSValue

#include <Foundation/NSObject.h>
#include <Foundation/NSGeometry.h>

@class NSString;
@class NSDictionary;


@interface NSValue : NSObject  <NSCopying, NSCoding>

- (void) getValue:(void*)value;
- (const char*) objCType;

@end


@interface NSValue (NSValueCreation)

- (id) initWithBytes:(const void *)value
			objCType:(const char *)type;

+ (NSValue*) valueWithBytes:(const void *)value	objCType:(const char *)type;
+ (NSValue*) value:(const void*)value withObjCType:(const char*)type;

+ (NSValue*) valueWithNonretainedObject:(id)anObject;
+ (NSValue*) valueWithPointer:(const void*)pointer;
+ (NSValue*) valueWithPoint:(NSPoint)point;
+ (NSValue*) valueWithRect:(NSRect)rect;
+ (NSValue*) valueWithSize:(NSSize)size;

@end


@interface NSValue (NSValueExtensionMethods)

- (BOOL) isEqualToValue:(NSValue*)other;

- (id) nonretainedObjectValue;
- (void*) pointerValue;
- (NSRect) rectValue;
- (NSSize) sizeValue;
- (NSPoint) pointValue;

@end


@interface NSNumber : NSValue

+ (NSNumber*) numberWithBool:(BOOL)value; 
+ (NSNumber*) numberWithChar:(char)value;
+ (NSNumber*) numberWithDouble:(double)value;
+ (NSNumber*) numberWithFloat:(float)value;
+ (NSNumber*) numberWithInt:(int)value;
+ (NSNumber*) numberWithLong:(long)value;
+ (NSNumber*) numberWithLongLong:(long long)value;
+ (NSNumber*) numberWithShort:(short)value;
+ (NSNumber*) numberWithUnsignedChar:(unsigned char)value;
+ (NSNumber*) numberWithUnsignedInt:(unsigned int)value;
+ (NSNumber*) numberWithUnsignedLong:(unsigned long)value;
+ (NSNumber*) numberWithUnsignedLongLong:(unsigned long long)value;
+ (NSNumber*) numberWithUnsignedShort:(unsigned short)value;

- (id) initWithBool:(BOOL)value;
- (id) initWithChar:(char)value;
- (id) initWithShort:(short)value;
- (id) initWithInt:(int)value;
- (id) initWithLong:(long)value;
- (id) initWithLongLong:(long long)value;
- (id) initWithUnsignedChar:(unsigned char)value;
- (id) initWithUnsignedShort:(unsigned short)value;
- (id) initWithUnsignedInt:(unsigned int)value;
- (id) initWithUnsignedLong:(unsigned long)value;
- (id) initWithUnsignedLongLong:(unsigned long long)value;

- (id) initWithFloat:(float)value;
- (id) initWithDouble:(double)value;

- (NSString*) description;
- (NSString*) descriptionWithLocale:(id)locale;

- (BOOL) isEqualToNumber:(NSNumber*)otherNumber;

@end


@interface NSNumber (ConcreteNumber)

- (BOOL) boolValue;
- (char) charValue;
- (short) shortValue;
- (int) intValue;
- (long) longValue;
- (long long) longLongValue;
- (unsigned char) unsignedCharValue;
- (unsigned short) unsignedShortValue;
- (unsigned int) unsignedIntValue;
- (unsigned long) unsignedLongValue;
- (unsigned long long) unsignedLongLongValue;

- (float) floatValue;
- (double) doubleValue;

- (NSComparisonResult) compare:(NSNumber*)otherNumber;

- (NSString*) stringValue;

@end

#endif /* _mGSTEP_H_NSValue */
