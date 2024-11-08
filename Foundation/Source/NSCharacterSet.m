/*
   NSCharacterSet.m

   Character set manipulation object.

   Copyright (C) 1995, 1996, 1997, 1998 Free Software Foundation, Inc.

   Author:	Adam Fedor <fedor@boulder.colorado.edu>
   Date:	Apr 1995
   mGSTEP:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Nov 2005

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSException.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSData.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSBundle.h>

#define GET_SHARED(b,c)		((__charsetCache[c]) ? __charsetCache[c] : \
							([self _charSet: b index: c]))

#define UNICODE_SIZE	65536
#define BITMAP_SIZE		UNICODE_SIZE/8

#ifndef SETBIT
  #define SETBIT(a,i)     ((a) |= 1 << (i))
  #define CLRBIT(a,i)     ((a) &= ~(1 << (i)))
  #define ISSET(a,i)      ((((a) & (1 << (i)))) > 0) ? YES : NO;
#endif


static NSCharacterSet *__charsetCache[12] = {0};
static NSLock *__cacheLock = nil;


@interface NSCharacterSet (HiddenConcreteCharacterSet)

- (id) _initWithBitmap:(NSData *)bitmap;

@end


@interface _BitmapCharSet : NSCharacterSet
{
    char _data[BITMAP_SIZE];
}
@end


@interface _MutableBitmapCharSet : NSMutableCharacterSet
{
    char _data[BITMAP_SIZE];
}
@end

/* ****************************************************************************

 		NSCharacterSet 

** ***************************************************************************/

@implementation NSCharacterSet

+ (void) initialize
{
	if (!__cacheLock)
		__cacheLock = [NSLock new];
}

+ (id) alloc									// Default class for alloc
{
	return NSAllocateObject([_BitmapCharSet self]);
}

+ (NSCharacterSet *) _charSet:(NSString *)setname index:(int)number
{
	[__cacheLock lock];							// Create standard char sets

	if (__charsetCache[number] == nil)
		{
		NSCharacterSet *set = nil;
		NSString *p = @"Foundation/CharacterSets";
		NSString *sysPath;
		NSBundle *b = [NSBundle systemBundle];
		NSData *d;

		NS_DURING								// Search the system path
			sysPath = [b pathForResource:setname ofType:@"dat" inDirectory: p];
			if (sysPath && [sysPath length] != 0)
				{
				NS_DURING						// Load the character set file
					d = [NSData dataWithContentsOfFile: sysPath];
					set = [self characterSetWithBitmapRepresentation: d];
				NS_HANDLER
					NSLog(@"Unable to read NSCharacterSet file %@",sysPath);
					set = nil;
				NS_ENDHANDLER
				}
												// If we didn't load a set then
			if (!set)							// raise an exception 
				[NSException raise:NSGenericException
							 format:@"Could not find bitmap file %@", setname];
			else								// Else cache the set
				__charsetCache[number] = [set retain];
		NS_HANDLER
			[__cacheLock unlock];
			[localException raise];				// quiet warnings about `set'
			abort (); 							// clobbered by longjmp.
		NS_ENDHANDLER
		}

	[__cacheLock unlock];

	return __charsetCache[number];
}

+ (id) alphanumericCharacterSet
{
	return GET_SHARED(@"alphanumericCharSet", 0);
}

+ (id) controlCharacterSet
{
	return GET_SHARED(@"controlCharSet", 1);
}

+ (id) decimalDigitCharacterSet
{
	return GET_SHARED(@"decimalCharSet", 2);
}

+ (id) decomposableCharacterSet
{
	NSLog(@"Warning: Decomposable set not yet fully specified");
	return GET_SHARED(@"decomposableCharSet", 3);
}

+ (id) illegalCharacterSet
{
	NSLog(@"Warning: Illegal set not yet fully specified\n");
	return GET_SHARED(@"illegalCharSet", 4);
}

+ (id) letterCharacterSet
{
	return GET_SHARED(@"lettercharCharSet", 5);
}

+ (id) lowercaseLetterCharacterSet
{
	return GET_SHARED(@"lowercaseCharSet", 6);
}

+ (id) nonBaseCharacterSet
{
	return GET_SHARED(@"nonbaseCharSet", 7);
}

+ (id) punctuationCharacterSet;
{
	return GET_SHARED(@"punctuationCharSet", 8);
}

+ (id) uppercaseLetterCharacterSet
{
	return GET_SHARED(@"uppercaseCharSet", 9);
}

+ (id) whitespaceAndNewlineCharacterSet
{
	return GET_SHARED(@"whitespaceAndNlCharSet", 10);
}

+ (id) whitespaceCharacterSet
{
	return GET_SHARED(@"whitespaceCharSet", 11);
}

+ (id) characterSetWithBitmapRepresentation:(NSData *)data
{
	return [[[_BitmapCharSet alloc] _initWithBitmap:data] autorelease];
}

+ (id) characterSetWithCharactersInString:(NSString *)aString
{
	NSMutableData *bitmap = [NSMutableData dataWithLength:BITMAP_SIZE];
	char *bytes = [bitmap mutableBytes];
	int i, length = [aString length];

	if (!aString)
		[NSException raise:NSInvalidArgumentException format:@"nil string"];
	
	for (i = 0; i < length; i++)
		{
		unichar c = [aString characterAtIndex:i];

		SETBIT(bytes[c/8], c % 8);
		}
	
	return [self characterSetWithBitmapRepresentation:bitmap];
}

+ (id) characterSetWithRange:(NSRange)aRange
{
	NSMutableData *bitmap = [NSMutableData dataWithLength:BITMAP_SIZE];
	char *bytes = (char *)[bitmap mutableBytes];
	int i;

	if (NSMaxRange(aRange) > UNICODE_SIZE)
		[NSException raise:NSInvalidArgumentException format:@"Invalid range"];
	
	for (i = aRange.location; i < NSMaxRange(aRange); i++)
		SETBIT(bytes[i/8], i % 8);
	
	return [self characterSetWithBitmapRepresentation:bitmap];
}

+ (id) characterSetWithContentsOfFile:(NSString *)aFile
{
	if ([[aFile pathExtension] isEqual: @"bitmap"])
		{
		NSData *bitmap = [NSData dataWithContentsOfFile: aFile];

		return [self characterSetWithBitmapRepresentation: bitmap];
		}

	return nil;
}

- (id) initWithCoder:(NSCoder*)aCoder
{
	return [self _initWithBitmap: [aCoder decodeObject]];
}

- (void) encodeWithCoder:(NSCoder*)aCoder
{
    [aCoder encodeObject: [self bitmapRepresentation]];
}

- (BOOL) isEqual:(id)anObject
{
	if (anObject == self)
		return YES;

	if ([anObject isKindOfClass:[NSCharacterSet class]])
		{
		unichar	i;

		for (i = 0; i <= 0xffff; i++)
			if ([self characterIsMember: i] != [anObject characterIsMember: i])
				return NO;

		return YES;
		}

	return NO;
}

- (NSCharacterSet *) invertedSet
{
	NSMutableData *bm = [[[self bitmapRepresentation] mutableCopy] autorelease];
	int i, length = [bm length];
	char *bytes = (char *)[bm mutableBytes];

	for (i = 0; i < length; i++)
		bytes[i] = ~bytes[i];
	
	return [[self class] characterSetWithBitmapRepresentation:bm];
}
												// NSCopying, NSMutableCopying
- (id) copy							{ return [self retain]; }

- (id) mutableCopy
{
	NSData *bitmap = [self bitmapRepresentation];

	return [[_MutableBitmapCharSet alloc] _initWithBitmap: bitmap];
}

@end /* NSCharacterSet */


@implementation _BitmapCharSet

- (id) _initWithBitmap:(NSData *)bitmap				// Designated initializer
{
	if ((self = [super init]) && bitmap)
		[bitmap getBytes:_data length:BITMAP_SIZE];

	return self;
}

- (NSData *) bitmapRepresentation
{
	return [NSData dataWithBytes:_data length:BITMAP_SIZE];
}

- (BOOL) characterIsMember:(unichar)aCharacter
{
	return ISSET(_data[aCharacter/8], aCharacter % 8);
}

@end /* _BitmapCharSet */

/* ****************************************************************************

 		NSMutableCharacterSet 

** ***************************************************************************/

@implementation NSMutableCharacterSet

+ (id) alloc
{
	return NSAllocateObject([_MutableBitmapCharSet self]);
}

+ (id) characterSetWithBitmapRepresentation:(NSData *)data
{
	return [[[_MutableBitmapCharSet alloc] _initWithBitmap:data] autorelease];
}

- (id) copy										// NSCopying, NSMutableCopying
{
	NSData *bitmap = [self bitmapRepresentation];

	return [[_BitmapCharSet alloc] _initWithBitmap: bitmap];
}

- (id) mutableCopy					{ return [super mutableCopy]; }

@end /* NSMutableCharacterSet */


@implementation _MutableBitmapCharSet

- (id) _initWithBitmap:(NSData *)bitmap				// Designated initializer
{
	if ((self = [super init]) && bitmap)
		[bitmap getBytes:_data length:BITMAP_SIZE];

	return self;
}

- (NSData *) bitmapRepresentation
{
	return [NSData dataWithBytes:_data length:BITMAP_SIZE];
}

- (BOOL) characterIsMember:(unichar)aCharacter
{
	return ISSET(_data[aCharacter/8], aCharacter % 8);
}

- (void) addCharactersInRange:(NSRange)aRange
{
	int i;

	if (NSMaxRange(aRange) > UNICODE_SIZE)
		[NSException raise:NSInvalidArgumentException format:@"Invalid range"];

	for (i = aRange.location; i < NSMaxRange(aRange); i++)
		SETBIT(_data[i/8], i % 8);
}

- (void) addCharactersInString:(NSString *)aString
{
	int i, length = [aString length];

	if (!aString)
		[NSException raise:NSInvalidArgumentException format:@"nil string"];

	for (i = 0; i < length; i++)
		{
		unichar c = [aString characterAtIndex:i];

		SETBIT(_data[c/8], c % 8);
		}
}

- (void) formUnionWithCharacterSet:(NSCharacterSet *)otherSet
{
	const char *other_bytes = [[otherSet bitmapRepresentation] bytes];
	int i;

	for (i = 0; i < BITMAP_SIZE; i++)
		_data[i] |= other_bytes[i];
}

- (void) formIntersectionWithCharacterSet:(NSCharacterSet *)otherSet
{
	int i;
	const char *other_bytes = [[otherSet bitmapRepresentation] bytes];

	for (i = 0; i < BITMAP_SIZE; i++)
		_data[i] &= other_bytes[i];
}

- (void) removeCharactersInRange:(NSRange)aRange
{
	int i;

	if (NSMaxRange(aRange) > UNICODE_SIZE)
		[NSException raise:NSInvalidArgumentException format:@"Invalid range"];

	for (i = aRange.location; i < NSMaxRange(aRange); i++)
		CLRBIT(_data[i/8], i % 8);
}

- (void) removeCharactersInString:(NSString *)aString
{
	int i, length = [aString length];

	if (!aString)
		[NSException raise:NSInvalidArgumentException format:@"nil string"];

	for (i = 0; i < length; i++)
		{
		unichar c = [aString characterAtIndex:i];

		CLRBIT(_data[c/8], c % 8);
		}
}

- (void) invert
{
	int i;

	for (i = 0; i < BITMAP_SIZE; i++)
		_data[i] = ~_data[i];
}

@end /* _MutableBitmapCharSet */
