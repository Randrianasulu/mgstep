/*
   NSColorList.h

   Manage named lists of NSColors.

   Copyright (C) 1996-2017 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
   Date: 	1996
   Rewrite: Felipe A. Rodriguez <far@illumenos.com>

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSColorList
#define _mGSTEP_H_NSColorList

#include <Foundation/NSCoder.h>

@class NSString;
@class NSArray;
@class NSMutableArray;
@class NSDictionary;
@class NSMutableDictionary;
@class NSColor;


@interface NSColorList : NSObject  <NSCoding>
{
    NSString *_name;
    NSString *_fileName;

	NSMutableDictionary *_colorList;
    NSMutableArray *_keyArray;
    NSMutableArray *_colorArray;

	struct __ColorListFlags {
		unsigned int editable:1;
		unsigned int dirty:1;
		unsigned int reserved:6;
	} _cl;
}

- (id) initWithName:(NSString *)name;
- (id) initWithName:(NSString *)name fromFile:(NSString *)path;

+ (NSArray *) availableColorLists;							// all color lists

+ (NSColorList *) colorListNamed:(NSString *)name;			// named color list
- (NSString *) name;

- (NSArray *) allKeys;
- (NSColor *) colorWithKey:(NSString *)key;
- (void) insertColor:(NSColor *)color key:(NSString *)key atIndex:(unsigned)ix;
- (void) removeColorWithKey:(NSString *)key;
- (void) setColor:(NSColor *)aColor forKey:(NSString *)key;

- (BOOL) isEditable;

- (BOOL) writeToFile:(NSString *)path;						// archive
- (void) removeFile;

@end


extern NSString *NSColorListDidChangeNotification;			// Notifications

extern NSString *NSColorListNotEditableException;
extern NSString *NSColorListIOException;

#endif /* _mGSTEP_H_NSColorList */
