/*
   NSProcessInfo.h

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <farz@mindspring.com>
   Date:	January 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSProcessInfo
#define _mGSTEP_H_NSProcessInfo

#include <Foundation/NSObject.h>

@class NSArray;
@class NSDictionary;
@class NSString;


@interface NSProcessInfo : NSObject
{
	NSString *_hostName;   
	NSString *_processName;
	NSString *_operatingSystem;				
	NSDictionary *_environment;
	NSArray *_arguments;
}

+ (NSProcessInfo*) processInfo;						// Shared NSProcessInfo

- (NSArray*) arguments;								// ProcessInfo accessors
- (NSDictionary*) environment;

- (NSString*) hostName;
- (NSString*) operatingSystem;
- (NSString*) processName;
- (NSString*) globallyUniqueString;

- (void) setProcessName:(NSString*)newName;			// Specify Process Name

@end

#endif /* _mGSTEP_H_NSProcessInfo */
