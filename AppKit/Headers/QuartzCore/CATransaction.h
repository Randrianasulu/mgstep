/*
   CATransaction.h

   Graphics animation

   Copyright (C) 2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    May 2020

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CATransaction
#define _mGSTEP_H_CATransaction

#include <Foundation/NSObject.h>


@interface CATransaction : NSObject

+ (BOOL) disableActions;
+ (void) setDisableActions:(BOOL)flag;

@end

@interface CATransaction (NotImplemented)

+ (void) begin;
+ (void) commit;
+ (void) flush;
+ (void) lock;
+ (void) unlock;

+ (CFTimeInterval) animationDuration;
+ (void) setAnimationDuration:(CFTimeInterval)duration;

@end

#endif /* _mGSTEP_H_CATransaction */
