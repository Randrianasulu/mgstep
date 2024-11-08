/*
   CAMediaTiming.h

   Graphics drawing layer

   Copyright (C) 2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    May 2020

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CAMediaTiming
#define _mGSTEP_H_CAMediaTiming

#include <Foundation/NSObject.h>
#include <CoreFoundation/CoreFoundation.h>


@protocol CAMediaTiming

- (BOOL) autoreverses;
- (NSString *) fillMode;

- (CFTimeInterval) beginTime;
- (CFTimeInterval) duration;
- (CFTimeInterval) repeatDuration;
- (CFTimeInterval) timeOffset;

@end

extern NSString * const kCAFillModeForwards;
extern NSString * const kCAFillModeBackwards;
extern NSString * const kCAFillModeRemoved;
extern NSString * const kCAFillModeBoth;

#endif /* _mGSTEP_H_CAMediaTiming */
