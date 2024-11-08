/*
   NSCoder.h

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
   Author: H.N.Schaller, Dec 2005 - API revised to be compatible to 10.4

   Author: Fabian Spillner <fabian.spillner@gmail.com>
   Date:   20. April 2008 - aligned with 10.5

   This file is part of the mGSTEP Library and is provided under the 
   terms of the libFoundation BSD type license (See the Readme file).
*/

#ifndef _mGSTEP_H_NSCoder
#define _mGSTEP_H_NSCoder

#include <Foundation/NSObject.h>
#include <Foundation/NSGeometry.h>

#include <sys/types.h>

@class NSData;


@interface NSCoder : NSObject
@end


@interface NSCoder (NSObject)

- (BOOL) allowsKeyedCoding;
- (BOOL) containsValueForKey:(NSString *)key;
														// Encoding Data
- (void) encodeArrayOfObjCType:(const char*)types	
						count:(unsigned)count	// FIX ME change to NS types in NSCoder, NSArchiver
						at:(const void*)array;
- (void) encodeBycopyObject:(id)anObject;
- (void) encodeConditionalObject:(id)anObject;
- (void) encodeDataObject:(NSData*)data;
- (void) encodeObject:(id)anObject;
- (void) encodePropertyList:(id)aPropertyList;
- (void) encodeRootObject:(id)rootObject;
- (void) encodeValueOfObjCType:(const char*)type at:(const void*)address;
- (void) encodeValuesOfObjCTypes:(const char*)types, ...;

- (void) encodeObject:(id)val forKey:(NSString *)key;
- (void) encodeBool:(BOOL)val forKey:(NSString *)key;
- (void) encodeBytes:(const unsigned char *)ptr		// (const uint8_t *)
			  length:(NSUInteger)len
			  forKey:(NSString *) key;
- (void) encodeConditionalObject:(id)obj forKey:(NSString *)key;
- (void) encodeDouble:(double)val forKey:(NSString *) key;
- (void) encodeFloat:(float)val forKey:(NSString *) key;
- (void) encodeInt32:(int32_t)val forKey:(NSString *) key;
- (void) encodeInt64:(int64_t)intv forKey:(NSString *) key;
- (void) encodeInt:(int)intv forKey:(NSString *) key;
- (void) encodeInteger:(NSInteger)intv forKey:(NSString *) key;

- (void) encodePoint:(NSPoint)point;					// Encoding geometry
- (void) encodeSize:(NSSize)size;
- (void) encodeRect:(NSRect)rect;

- (void) encodePoint:(NSPoint)point forKey:(NSString *)key;
- (void) encodeRect:(NSRect)rect forKey:(NSString *)key;
- (void) encodeSize:(NSSize)size forKey:(NSString *)key;
														// Decoding Data
- (void) decodeArrayOfObjCType:(const char*)types
						 count:(NSUInteger)count
						 at:(void*)address;
- (NSData*) decodeDataObject;
- (id) decodeObject;
- (id) decodePropertyList;
- (void) decodeValueOfObjCType:(const char*)type at:(void*)address;
- (void) decodeValuesOfObjCTypes:(const char*)types, ...;

- (id) decodeObjectForKey:(NSString *)key;
- (BOOL) decodeBoolForKey:(NSString *)key;
- (int) decodeIntForKey:(NSString *)key;
- (float) decodeFloatForKey:(NSString *)key;
- (double) decodeDoubleForKey:(NSString *)key;
- (int32_t) decodeInt32ForKey:(NSString *)key;
- (int64_t) decodeInt64ForKey:(NSString *)key;
- (NSInteger) decodeIntegerForKey:(NSString *)key;

- (NSPoint) decodePoint;								// Decoding geometry
- (NSSize) decodeSize;
- (NSRect) decodeRect;

- (NSRect) decodeRectForKey:(NSString *)key;
- (NSSize) decodeSizeForKey:(NSString *)key;
- (NSPoint) decodePointForKey:(NSString *)key;

- (NSUInteger) systemVersion;
- (NSUInteger) versionForClassName:(NSString*)className;

@end

#endif /* _mGSTEP_H_NSCoder */
