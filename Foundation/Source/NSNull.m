/*
   NSNull.m

   Null object class

   Copyright (C) 2009 Free Software Foundation, Inc.

   mGSTEP:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	Sep 2009

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSNull.h>
#include <Foundation/NSString.h>


static NSNull *__sharedNULL = nil;


@implementation NSNull

+ (void) initialize
{
	if (!__sharedNULL)
		__sharedNULL = [NSNull new];
}

+ (NSNull *) null							{ return __sharedNULL; }

- (NSString*) description					{ return @"null"; }

- (void) dealloc							{ NO_WARN; }
- (oneway void) release						{}
- (id) autorelease							{ return self; }
- (id) retain								{ return self; }
- (id) copy									{ return self; }

- (id) initWithCoder:(NSCoder*)aDecoder		{ return self; }
- (void) encodeWithCoder:(NSCoder*)aCoder	{}

@end
