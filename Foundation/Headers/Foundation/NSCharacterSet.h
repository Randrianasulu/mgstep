/*
   NSCharacterSet.h

   Interface to character set manipulation class

   Copyright (C) 1995 Free Software Foundation, Inc.

   Author:	Adam Fedor <fedor@boulder.colorado.edu>
   Date:	1995

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSCharacterSet
#define _mGSTEP_H_NSCharacterSet

#include <Foundation/NSString.h>

@class NSData;


@interface NSCharacterSet : NSObject  <NSCoding, NSCopying, NSMutableCopying>

+ (id) alphanumericCharacterSet;				// standard character sets
+ (id) controlCharacterSet;
+ (id) decimalDigitCharacterSet;
+ (id) decomposableCharacterSet;
+ (id) illegalCharacterSet;
+ (id) letterCharacterSet;
+ (id) lowercaseLetterCharacterSet;
+ (id) nonBaseCharacterSet;
+ (id) punctuationCharacterSet;
+ (id) uppercaseLetterCharacterSet;
+ (id) whitespaceAndNewlineCharacterSet;
+ (id) whitespaceCharacterSet;
												// custom character sets
+ (id) characterSetWithBitmapRepresentation:(NSData *)data;
+ (id) characterSetWithCharactersInString:(NSString *)aString;
+ (id) characterSetWithRange:(NSRange)aRange;
+ (id) characterSetWithContentsOfFile:(NSString*)file;

- (NSCharacterSet *) invertedSet;

@end

/* ****************************************************************************

	Bitmap representation of a character set is a byte array of 2^16 bits
	(8192 bytes). The value of the bit at position n represents the presence
	in the character set of the character with decimal Unicode value n. 

	To add a character with decimal Unicode value n to a bitmap representation:

		unsigned char bitmapRep[8192];
		bitmapRep[n >> 3] |= (((unsigned int)1) << (n & 7));

	To remove the character:

		bitmapRep[n >> 3] &= ~(((unsigned int)1) << (n & 7));

	To test for the presence of a decimal Unicode char with value n:
  
		unsigned char bitmapRep[8192];
		if (bitmapRep[n >> 3] & (((unsigned int)1) << (n & 7)))
			{  Character is present  }

** ***************************************************************************/

@interface NSCharacterSet (ConcreteCharacterSet)

- (NSData *) bitmapRepresentation;
- (BOOL) characterIsMember:(unichar)aCharacter;

@end


@interface NSMutableCharacterSet : NSCharacterSet <NSCopying, NSMutableCopying>
@end

@interface NSMutableCharacterSet (ConcreteCharacterSet)

- (void) addCharactersInRange:(NSRange)aRange;
- (void) addCharactersInString:(NSString *)aString;
- (void) formUnionWithCharacterSet:(NSCharacterSet *)otherSet;
- (void) formIntersectionWithCharacterSet:(NSCharacterSet *)otherSet;
- (void) removeCharactersInRange:(NSRange)aRange;
- (void) removeCharactersInString:(NSString *)aString;
- (void) invert;

@end

#endif /* _mGSTEP_H_NSCharacterSet */
