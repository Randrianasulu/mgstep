/*
   NSError.h

   Error reporting class

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	Oct 2009

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSError
#define _mGSTEP_H_NSError

#include <Foundation/NSObject.h>

@class NSDictionary;

extern NSString *NSPOSIXErrorDomain;
extern NSString *NSCocoaErrorDomain;			// domain for AppKit/Foundation

extern NSString *NSLocalizedDescriptionKey;		// userinfo key for str error
extern NSString *NSUnderlyingErrorKey;			// key for underlying nserror


@interface NSError : NSObject  <NSCopying, NSCoding>
{
	int _code;
	NSString *_domain;
	NSDictionary *_userInfo;
}

+ (id) errorWithDomain:(NSString *)d code:(int)c userInfo:(NSDictionary *)dict;
- (id) initWithDomain:(NSString *)d code:(int)c userInfo:(NSDictionary *)dict;

- (int) code;
- (NSString *) domain;
- (NSDictionary *) userInfo;

- (NSString *) localizedDescription;

@end


NSError * _NSError(NSString *domain, int code, NSString *message);

#endif  /* _mGSTEP_H_NSError */
