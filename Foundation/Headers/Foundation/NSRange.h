/*
   NSRange.h

   Functions to manipulate unsigned integer ranges

   Copyright (C) 1995, 1996 Free Software Foundation, Inc.

   Author:  Adam Fedor <fedor@boulder.colorado.edu>
   Date:	1995
   mGSTEP:	Felipe A. Rodriguez <farz@mindspring.com>
   Date:	Mar 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSRange
#define _mGSTEP_H_NSRange

#include <Foundation/NSObjCRuntime.h>

@class NSString;

typedef struct _NSRange NSRange;
typedef struct _NSRange *NSRangePointer;


struct _NSRange
{
	NSUInteger location;
	NSUInteger length;
};

static inline NSUInteger
NSMaxRange(NSRange r)
{
	return r.location + r.length;
}

static inline NSRange 
NSMakeRange(NSUInteger location, NSUInteger length) 
{
	return (NSRange){location, length};
}

static inline BOOL 
NSEqualRanges(NSRange r1, NSRange r2)
{
	return (r1.location == r2.location && r1.length == r2.length);
}

static inline BOOL 
NSLocationInRange(NSUInteger location, NSRange r)
{
	return (location >= r.location) && (location < NSMaxRange(r));
}

extern NSRange    _NSAbsoluteRange(NSInteger a1, NSInteger a2);
extern NSRange    NSUnionRange(NSRange r1, NSRange r2);
extern NSRange    NSIntersectionRange(NSRange r1, NSRange r2);
extern NSString * NSStringFromRange(NSRange range);

#endif /* _mGSTEP_H_NSRange */
