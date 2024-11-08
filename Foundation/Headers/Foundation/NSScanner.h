/*
   NSScanner.h

   Definitions for NSScanner class

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:	Eric Norum <eric@skatter.usask.ca>
   Date:	1996

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSScanner
#define _mGSTEP_H_NSScanner

#include <Foundation/NSObject.h>
#include <Foundation/NSRange.h>

@class NSDictionary;
@class NSCharacterSet;
@class NSString;


@interface NSScanner : NSObject  <NSCopying>
{
	NSString *_string;
	NSUInteger _length;
	NSCharacterSet *_skip;
	NSDictionary *locale;
	BOOL _caseSensitive;

	NSRange _scan;

	NSCharacterSet *nSet, *iSet;	// for NSText FIX ME need to eliminate
	NSUInteger stringLength;
}

+ (id) scannerWithString:(NSString *)aString;
+ (id) localizedScannerWithString:(NSString *)aString;

- (id) initWithString:(NSString *)aString;

- (NSString *) string;
- (NSUInteger) scanLocation;
- (void) setScanLocation:(NSUInteger)anIndex;
- (void) setCaseSensitive:(BOOL)flag;
- (BOOL) caseSensitive;
- (NSCharacterSet *) charactersToBeSkipped;
- (void) setCharactersToBeSkipped:(NSCharacterSet *)aSet;
- (NSDictionary *) locale;
- (void) setLocale:(NSDictionary *) localeDictionary;

- (BOOL) isAtEnd;
- (BOOL) scanInt:(int *)value;
- (BOOL) scanLongLong:(long long *)value;
- (BOOL) scanFloat:(float *)value;
- (BOOL) scanDouble:(double *)value;
- (BOOL) scanString:(NSString *)string intoString:(NSString **)value;
- (BOOL) scanCharactersFromSet:(NSCharacterSet *)aSet
					intoString:(NSString **)value;
- (BOOL) scanUpToString:(NSString *)string intoString:(NSString **)value;
- (BOOL) scanUpToCharactersFromSet:(NSCharacterSet *)aSet 
						intoString:(NSString **)value;
@end


@interface NSScanner  (NSTextPrivate)		// FIX ME need to eliminate

+ (id) _scannerWithString:(NSString*)aString
					  set:(NSCharacterSet*)aSet 
					  invertedSet:(NSCharacterSet*)anInvSet;
- (NSRange) _scanCharactersInverted:(BOOL) inverted;
- (NSRange) _scanSetCharacters;
- (NSRange) _scanNonSetCharacters;
- (BOOL) _isAtEnd;
- (void) _setScanLocation:(unsigned) aLoc;

@end

#endif /* _mGSTEP_H_NSScanner */
