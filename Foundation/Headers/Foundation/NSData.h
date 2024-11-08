/*
   NSData.h

   Byte storage wrapper classes

   Copyright (C) 1995-2020 Free Software Foundation, Inc.

   Author:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date:	1995
   mGSTEP:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	May 2005

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSData
#define _mGSTEP_H_NSData

#include <Foundation/NSObject.h>
#include <Foundation/NSRange.h>

@class NSError;
@class NSString;

typedef enum _NSDataReadingOptions {
	NSDataReadingMappedIfSafe = 1,		// map file if safe to do so
	NSDataReadingUncached     = 2,		// avoid kernel buffers if possible
	NSDataReadingMappedAlways = 4		// map file if possible
} NSDataReadingOptions;

typedef enum _NSDataWritingOptions {
	NSDataWritingAtomic                 = 1,
	NSDataWritingWithoutOverwriting     = 2,
	NSDataWritingFileProtectionNone     = 0x10000000,
	NSDataWritingFileProtectionComplete = 0x20000000,
	NSDataWritingFileProtectionMask     = 0xf0000000
} NSDataWritingOptions;

typedef enum _NSDataSearchOptions {
	NSDataSearchBackwards = 1,
	NSDataSearchAnchored  = 2
} NSDataSearchOptions;



@interface NSData : NSObject  <NSCoding, NSCopying, NSMutableCopying>

- (NSUInteger) length;
- (const void *) bytes;									// inner pointer

@end


@interface NSData  (ConcreteData)

+ (id) data;
+ (id) dataWithBytes:(const void*)bytes length:(NSUInteger)length;
+ (id) dataWithBytesNoCopy:(void*)bytes length:(NSUInteger)length;
+ (id) dataWithBytesNoCopy:(void*)b length:(NSUInteger)l freeWhenDone:(BOOL)f;
+ (id) dataWithContentsOfFile:(NSString*)path;
+ (id) dataWithContentsOfMappedFile:(NSString*)path;
+ (id) dataWithData:(NSData*)data;

+ (id) dataWithContentsOfFile:(NSString*)path
					  options:(NSDataReadingOptions)options
					  error:(NSError**)error;

- (id) initWithData:(NSData*)data;

//- (id) initWithContentsOfFile:(NSString*)path
//					  options:(NSDataReadingOptions)options
//					  error:(NSError**)error;

- (void) getBytes:(void*)buffer length:(NSUInteger)length;
- (void) getBytes:(void*)buffer range:(NSRange)aRange;
- (NSData *) subdataWithRange:(NSRange)aRange;

- (NSString *) description;

- (BOOL) isEqualToData:(NSData*)other;

- (BOOL) writeToFile:(NSString*)path atomically:(BOOL)useAuxiliaryFile;

- (BOOL) writeToFile:(NSString*)path
			 options:(NSDataWritingOptions)options
			 error:(NSError**)error;

- (id) initWithBytes:(const void*)bytes length:(NSUInteger)length;
- (id) initWithBytesNoCopy:(void*)bytes length:(NSUInteger)length;
- (id) initWithBytesNoCopy:(void*)b length:(NSUInteger)l freeWhenDone:(BOOL)f;
- (id) initWithContentsOfMappedFile:(NSString*)path;
- (id) initWithContentsOfFile:(NSString*)path;
//- (id) initWithContentsOfURL:(NSURL*)url;

//- (NSRange) rangeOfData:(NSData*)searchData
//				options:(NSDataSearchOptions)options
//				  range:(NSRange)searchRange

@end


@interface NSMutableData :  NSData

- (void) setLength:(NSUInteger)length;
- (void *) mutableBytes;

@end


@interface NSMutableData  (ConcreteMutableData)

+ (id) dataWithCapacity:(NSUInteger)numBytes;
+ (id) dataWithLength:(NSUInteger)length;

- (id) initWithCapacity:(NSUInteger)capacity;
- (id) initWithLength:(NSUInteger)length;

- (void) increaseLengthBy:(NSUInteger)extraLength;

- (void) appendBytes:(const void*)bytes length:(NSUInteger)length;
- (void) appendData:(NSData*)other;

- (void) replaceBytesInRange:(NSRange)aRange withBytes:(const void*)bytes;
- (void) resetBytesInRange:(NSRange)aRange;
- (void) setData:(NSData*)data;

@end


@interface NSData  (NSDeprecated)

- (id) initWithBase64String:(NSString *)string;
- (NSString *) base64String;

@end


@interface NSMutableData  (_NSExtensions)

- (NSUInteger) _capacity;
- (void) _setCapacity:(NSUInteger)newCapacity;

@end

#endif  /* _mGSTEP_H_NSData */
