/*
   NSJSONSerialization.h

   JSON serialization of Foundation objects

   Copyright (C) 2015 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	October 2015

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSJSONSerialization
#define _mGSTEP_H_NSJSONSerialization

#include <Foundation/NSObject.h>

@class NSData;
@class NSError;


typedef enum _NSJSONReadingOptions {
	NSJSONReadingMutableContainers = 1,		// emit mutable arrays/dictionarys
	NSJSONReadingMutableLeaves     = 2,		// emit mutable strings/numbers
	NSJSONReadingAllowFragments    = 4		// allow any top-level object type
} NSJSONReadingOptions;

typedef enum _NSJSONWritingOptions {
	NSJSONWritingPrettyPrinted     = 1,
} NSJSONWritingOptions;



@interface NSJSONSerialization : NSObject
{
	id _object;
}

+ (id) JSONObjectWithData:(NSData *)data
				  options:(NSJSONReadingOptions)options
				  error:(NSError **)error;

+ (NSData *) dataWithJSONObject:(id)object
						options:(NSJSONWritingOptions)options
						error:(NSError **)error;

/* ****************************************************************************

	isValidJSONObject:

	Valid JSON objects must be an NSArray or NSDictionary at the top-level
	and contain only NSString, NSNull, NSNumber (and not NaN or infinite),
	NSArray or NSDictionary (with string keys) objects.

** ***************************************************************************/

+ (BOOL) isValidJSONObject:(id)object;


#if 0  /* not implemented */
+ (NSInteger) writeJSONObject:(id)object
					 toStream:(NSOutputStream *)stream
					 options:(NSJSONWritingOptions)options
					 error:(NSError **)error;

+ (id) JSONObjectWithStream:(NSInputStream *)stream
					options:(NSJSONReadingOptions)options
					error:(NSError **)error;
#endif

@end

#endif  /* _mGSTEP_H_NSJSONSerialization */
