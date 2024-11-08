/*
   NSDistributedLock.h

   Restrict access to resources shared by multiple apps.

   Copyright (C) 1997 Free Software Foundation, Inc.

   Author:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date:    1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSDistributedLock
#define _mGSTEP_H_NSDistributedLock

#include <Foundation/NSObject.h>

@class NSString;
@class NSDate;

@interface NSDistributedLock : NSObject
{
    NSString *_lockPath;
    NSDate *_lockTime;
}

+ (NSDistributedLock*) lockWithPath:(NSString*)aPath;
- (NSDistributedLock*) initWithPath:(NSString*)aPath;

- (NSDate*) lockDate;
- (void) breakLock;
- (BOOL) tryLock;
- (void) unlock;

@end

#endif /* _mGSTEP_H_NSDistributedLock */
