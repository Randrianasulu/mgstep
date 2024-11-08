/*
   NSNull.h

   Null object class

   Copyright (C) 2009 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	October 2009

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSNull
#define _mGSTEP_H_NSNull

#include <Foundation/NSObject.h>


@interface NSNull : NSObject  <NSCopying, NSCoding>

+ (NSNull *) null;

@end

#endif  /* _mGSTEP_H_NSNull */
