/*
   NSHost.h

   Host properties abstraction class

   Copyright (C) 1996-2019 Free Software Foundation, Inc.

   Author:	Luke Howard <lukeh@xedoc.com.au> 
   Date:	1996

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSHost
#define _mGSTEP_H_NSHost

#include <Foundation/NSObject.h>

@class NSString;
@class NSArray;
@class NSMutableArray;


@interface NSHost : NSObject
{
	NSMutableArray *_names;
	NSMutableArray *_addresses;
}
									// Addresses are in "Dotted Decimal"
+ (NSHost *) currentHost;			// notation such as: @"192.42.172.1"
+ (NSHost *) hostWithName:(NSString*)name;
+ (NSHost *) hostWithAddress:(NSString*)address;
									// Compare hosts, hosts are equal if they
									// share at least one address
- (BOOL) isEqualToHost:(NSHost*)aHost;
									// return one name (arbitrarily chosen) 
- (NSString*) name;					// if a host has several.
- (NSArray *) names;
									// return one address (arbitrarily) if a
- (NSString*) address;				// host has several.
- (NSArray *) addresses;

@end

#endif /* _mGSTEP_H_NSHost */
