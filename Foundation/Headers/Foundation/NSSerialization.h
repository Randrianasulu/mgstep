/*
   NSSerialization.h

   Protocol for NSSerialization  (deprecated by NSPropertyList)

   Copyright (C) 1995 Free Software Foundation, Inc.

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSSerialization
#define _mGSTEP_H_NSSerialization

@class NSData, NSMutableData;


@protocol NSObjCTypeSerializationCallBack

- (void) deserializeObjectAt:(id*)object
				  ofObjCType:(const char *)type
				  fromData:(NSData*)data
				  atCursor:(NSUInteger*)cursor;
- (void) serializeObjectAt:(id*)object
				ofObjCType:(const char *)type
				intoData:(NSMutableData*)data;
@end

#endif /* _mGSTEP_H_NSSerialization */
