/*
   NSError.m

   Error reporting class

   Copyright (C) 2009-2016 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	Nov 2009

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSError.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSCoder.h>


NSString *NSCocoaErrorDomain = @"NSCocoaErrorDomain";
NSString *NSPOSIXErrorDomain = @"NSPOSIXErrorDomain";

NSString *NSLocalizedDescriptionKey = @"NSLocalizedDescriptionKey";
NSString *NSUnderlyingErrorKey      = @"NSUnderlyingErrorKey";


NSError * _NSError(NSString *domain, int code, NSString *message)
{
	NSString *dom = (domain) ? domain : NSCocoaErrorDomain;
	NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys: \
								message, NSLocalizedDescriptionKey, nil];
	
	return [NSError errorWithDomain:dom code:code userInfo:d];
}


@implementation NSError

+ (id) errorWithDomain:(NSString *)dm code:(int)c userInfo:(NSDictionary *)ui
{
	return [[[NSError alloc] initWithDomain:dm code:c userInfo:ui] autorelease];
}

- (id) initWithDomain:(NSString *)dm code:(int)c userInfo:(NSDictionary *)ui
{
	if (dm == nil)
		{
		NSLog(@"Invalid error domain\n");
		[self release];

		return nil;
		}

	_code = c;
	_domain = dm;
	_userInfo = [ui retain];

	return self;
}

- (void) dealloc;
{
	[_userInfo release];

	[super dealloc];
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"%@ error: (%d) %@", _domain, _code,
						[_userInfo objectForKey: NSLocalizedDescriptionKey]];
}

- (NSString *) localizedDescription
{
	return [_userInfo objectForKey: NSLocalizedDescriptionKey];
}

- (int) code								{ return _code; }
- (NSString *) domain						{ return _domain; }
- (NSDictionary *) userInfo					{ return _userInfo; }

- (id) copy
{
	return [NSError errorWithDomain:_domain code:_code userInfo:_userInfo];
}

- (id) initWithCoder:(NSCoder*)decoder
{
	[decoder decodeValueOfObjCType:@encode(int) at:&_code];

	return [self initWithDomain:[decoder decodeObject]
				 code:_code
				 userInfo:[decoder decodeObject]];
}

- (void) encodeWithCoder:(NSCoder*)coder
{
	[coder encodeValueOfObjCType:@encode(int) at:&_code];
	[coder encodeObject:_domain];
	[coder encodeObject:_userInfo];
}

@end
