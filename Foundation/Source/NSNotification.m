/*
   NSNotification.m

   Event messaging class

   Copyright (C) 1996-2016 Free Software Foundation, Inc.

   Author:	Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date:	March 1996

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSNotification.h>
#include <Foundation/NSString.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSDictionary.h>



@implementation NSNotification

+ (NSNotification *) notificationWithName:(NSString*)name
								   object:(id)object
								   userInfo:(NSDictionary*)info
{
	return [[[self alloc] initWithName: name 
						  object: object 
						  userInfo: info] autorelease];
}

+ (NSNotification *) notificationWithName:(NSString*)name object:object
{
	return [self notificationWithName:name object:object userInfo:nil];
}

- (id) initWithName:(NSString*)name object:object userInfo:(NSDictionary*)info
{
	_name = [name copy];							// designated initializer
	_object = [object retain];
	_info = [info retain];

	return self;
}

- (void) dealloc
{
	[_name release];
	[_object release];
	[_info release];
	[_registry release];

	[super dealloc];
}

- (NSString*) name						{ return _name; }
- (id) object							{ return _object; }
- (id) copy								{ return [self retain]; }
- (NSDictionary*) userInfo				{ return _info; }

- (void) encodeWithCoder:(NSCoder*)coder				// NSCoding protocol
{
    [coder encodeObject:_name];
    [coder encodeObject:_object];
    [coder encodeObject:_info];
}

- (id) initWithCoder:(NSCoder*)coder
{
    return [self initWithName:[coder decodeObject] 
				 object:[coder decodeObject] 
				 userInfo:[coder decodeObject]];
}

@end
