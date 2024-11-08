/*
   NSScreen.h

   Display screen management.

   Copyright (C) 1998 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    June 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSScreen
#define _mGSTEP_H_NSScreen

#include <Foundation/NSObject.h>
#include <AppKit/NSGraphics.h>

@class NSArray;
@class NSDictionary;


@interface NSScreen : NSObject
{
	NSRect _frame;
	NSWindowDepth _depth;
}

+ (NSScreen *) mainScreen;
+ (NSScreen *) deepestScreen;
+ (NSArray *) screens;

- (NSRect) frame;
- (NSWindowDepth) depth;
- (NSDictionary *) deviceDescription;

//- (NSRect) convertRectToBacking:(NSRect)r;
//- (NSRect) convertRectFromBacking:(NSRect)r;

@end

#endif /* _mGSTEP_H_NSScreen */
