/*
   NSCoder.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>

   This file is part of the mGSTEP Library and is provided under the 
   terms of the libFoundation BSD type license (See the Readme file).
*/

#include <Foundation/NSCoder.h>


@implementation NSCoder

- (void) encodeArrayOfObjCType:(const char*)types
						 count:(unsigned)count
						 at:(const void*)array
{
	NSUInteger i, offset, item_size = objc_sizeof_type(types);
	IMP imp = [self methodForSelector:@selector(encodeValueOfObjCType:at:)];

    for(i = offset = 0; i < count; i++, offset += item_size) 
		{
        (*imp)(self, @selector(encodeValueOfObjCType:at:),
					types, (char*)array + offset);
		types = objc_skip_typespec(types);
		item_size = objc_sizeof_type(types);
		}
}

- (void) encodeBycopyObject:(id)aObject			{ [self encodeObject:aObject];}
- (void) encodeConditionalObject:(id)aObject	{ [self encodeObject:aObject];}
- (void) encodeDataObject:(NSData*)data			{ [self encodeObject:data]; }
- (void) encodeObject:(id)anObject				{ SUBCLASS }
- (void) encodePropertyList:(id)pList			{ [self encodeObject:pList]; }
- (void) encodeRootObject:(id)rootObj			{ [self encodeObject:rootObj]; }

- (void) encodeValueOfObjCType:(const char*)type
							at:(const void*)address			{ SUBCLASS }

- (void) encodeValuesOfObjCTypes:(const char*)types, ...
{
	va_list ap;
	IMP imp = [self methodForSelector:@selector(encodeValueOfObjCType:at:)];

    va_start(ap, types);
    for(; types && *types; types = objc_skip_typespec(types))
        (*imp)(self, @selector(encodeValueOfObjCType:at:),
		types, va_arg(ap, void*));
    va_end(ap);
}

- (void) encodePoint:(NSPoint)point
{
    [self encodeValueOfObjCType:@encode(NSPoint) at:&point];
}

- (void) encodeSize:(NSSize)size
{
    [self encodeValueOfObjCType:@encode(NSSize) at:&size];
}

- (void) encodeRect:(NSRect)rect
{
    [self encodeValueOfObjCType:@encode(NSRect) at:&rect];
}

- (void) decodeArrayOfObjCType:(const char*)types
						 count:(NSUInteger)count
						 at:(void*)address
{
	NSUInteger i, offset, item_size = objc_sizeof_type(types);
	IMP imp = [self methodForSelector:@selector(decodeValueOfObjCType:at:)];

    for(i = offset = 0; i < count; i++, offset += item_size) 
		{
        (*imp)(self, @selector(decodeValueOfObjCType:at:),
				types, (char*)address + offset);
		types = objc_skip_typespec(types);
		item_size = objc_sizeof_type(types);
		}
}

- (NSData*) decodeDataObject				{ return [self decodeObject]; }
- (id) decodeObject							{ return SUBCLASS }
- (id) decodePropertyList					{ return [self decodeObject]; }

- (void) decodeValueOfObjCType:(const char*)type
							at:(void*)address		{ SUBCLASS }

- (void) decodeValuesOfObjCTypes:(const char*)types, ...
{
	va_list ap;
	IMP imp = [self methodForSelector:@selector(decodeValueOfObjCType:at:)];

    va_start(ap, types);
    for(;types && *types; types = objc_skip_typespec(types))
        (*imp)(self, @selector(decodeValueOfObjCType:at:),
				types, va_arg(ap, void*));
    va_end(ap);
}

- (NSPoint) decodePoint
{
	NSPoint point;

    [self decodeValueOfObjCType:@encode(NSPoint) at:&point];

    return point;
}

- (NSSize) decodeSize
{
	NSSize size;

    [self decodeValueOfObjCType:@encode(NSSize) at:&size];

    return size;
}

- (NSRect) decodeRect
{
	NSRect rect;

    [self decodeValueOfObjCType:@encode(NSRect) at:&rect];

    return rect;
}

- (NSUInteger) systemVersion					{ return 106; }

- (NSUInteger) versionForClassName:(NSString*)className 	
{ 
	SUBCLASS return 0; 
}

@end /* NSCoder */
