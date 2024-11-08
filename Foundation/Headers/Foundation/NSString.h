/*
   NSString.h

   String classes.

   Copyright (C) 1995-2018 Free Software Foundation, Inc.

   Author:	Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date:	1995

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSString
#define _mGSTEP_H_NSString

#include <Foundation/NSObject.h>
#include <Foundation/NSRange.h>

#define NSMaximumStringLength	(INT_MAX-1)

@class NSArray;
@class NSCharacterSet;
@class NSData;
@class NSDictionary;
@class NSMutableString;


typedef unsigned short unichar;

typedef enum
{
	NSCaseInsensitiveSearch = 1,
	NSLiteralSearch			= 2,
	NSBackwardsSearch		= 4,
	NSAnchoredSearch		= 8

} NSStringCompareOptions;


typedef enum _NSStringEncoding				// encoding type 0 is undefined
{
	NSASCIIStringEncoding 			= 1,	// 0...127
	NSNEXTSTEPStringEncoding 		= 2,
	NSJapaneseEUCStringEncoding 	= 3,
	NSUTF8StringEncoding 			= 4,
	NSISOLatin1StringEncoding 		= 5,
	NSSymbolStringEncoding 			= 6,
	NSNonLossyASCIIStringEncoding 	= 7,	// 7-bit ASCII to rep all unichars
	NSShiftJISStringEncoding 		= 8,
	NSISOLatin2StringEncoding 		= 9,
	NSUnicodeStringEncoding 		= 10,
	NSWindowsCP1251StringEncoding 	= 11,	// Cyrillic
	NSWindowsCP1252StringEncoding 	= 12,	// WinLatin1
	NSWindowsCP1253StringEncoding 	= 13,	// Greek
	NSWindowsCP1254StringEncoding 	= 14,	// Turkish
	NSWindowsCP1250StringEncoding 	= 15,	// Windows Latin 2
	NSISO2022JPStringEncoding 		= 21,	// Japanese
	NSMacOSRomanStringEncoding		= 30,

    NSUTF16StringEncoding             = NSUnicodeStringEncoding,
    NSUTF16BigEndianStringEncoding    = 0x90000100,
	NSUTF16LittleEndianStringEncoding = 0x94000100,

    NSUTF32StringEncoding             = 0x8c000100,
    NSUTF32BigEndianStringEncoding    = 0x98000100,
    NSUTF32LittleEndianStringEncoding = 0x9c000100

} NSStringEncoding;



@interface NSString : NSObject  <NSCoding, NSCopying, NSMutableCopying>
{
    char *_cString;
    NSUInteger _count;
}

+ (id) string;
+ (id) stringWithContentsOfFile:(NSString *)path;
+ (id) stringWithCharacters:(const unichar*)chars length:(NSUInteger)length;
+ (id) stringWithFormat:(NSString*)format,...;
+ (id) stringWithFormat:(NSString*)format arguments:(va_list)args;
+ (id) stringWithString:(NSString*)aString;
+ (id) stringWithUTF8String:(const char*)CByteString;

+ (NSStringEncoding) defaultCStringEncoding;
+ (NSStringEncoding*) availableStringEncodings;
+ (NSString*) localizedNameOfStringEncoding:(NSStringEncoding)encoding;

- (NSUInteger) length;
														// Combine Strings
- (NSString*) stringByAppendingFormat:(NSString*)format,...;
- (NSString*) stringByAppendingString:(NSString*)aString;
														// Divide to substrings
- (NSArray*) componentsSeparatedByString:(NSString*)separator;
- (NSString*) substringFromIndex:(NSUInteger)index;
- (NSString*) substringWithRange:(NSRange)aRange;
- (NSString*) substringToIndex:(NSUInteger)index;
														// Search char ranges
- (NSRange) rangeOfCharacterFromSet:(NSCharacterSet*)aSet;
- (NSRange) rangeOfCharacterFromSet:(NSCharacterSet*)aSet
							options:(unsigned int)mask;
- (NSRange) rangeOfCharacterFromSet:(NSCharacterSet*)aSet
							options:(unsigned int)mask
							range:(NSRange)aRange;
- (NSRange) rangeOfString:(NSString*)searchStr;
- (NSRange) rangeOfString:(NSString*)searchStr options:(unsigned int)mask;
- (NSRange) rangeOfString:(NSString*)searchStr
				  options:(unsigned int)mask
				  range:(NSRange)aRange;
									// Determining Composed Character Sequences
- (NSRange) rangeOfComposedCharacterSequenceAtIndex:(NSUInteger)anIndex;

- (NSComparisonResult) compare:(NSString*)aString;		// Comparing Strings
- (NSComparisonResult) compare:(NSString*)aString	
					   options:(NSStringCompareOptions)mask;
- (NSComparisonResult) compare:(NSString*)aString
					   options:(NSStringCompareOptions)mask
					   range:(NSRange)aRange;
- (NSComparisonResult) caseInsensitiveCompare:(NSString*)aString;

- (BOOL) hasPrefix:(NSString*)aString;
- (BOOL) hasSuffix:(NSString*)aString;
														// Shared Prefix
- (NSString*) commonPrefixWithString:(NSString*)aString
							 options:(unsigned int)mask;

- (NSString*) capitalizedString;						// Changing Case
- (NSString*) lowercaseString;
- (NSString*) uppercaseString;

- (NSString*) stringByTrimmingCharactersInSet:(NSCharacterSet *)set;

- (const char*) UTF8String;				// null terminated UTF8 representation
- (const char*) cString;
- (const char*) cStringUsingEncoding:(NSStringEncoding)e;

- (void) getCString:(char*)buffer;
- (void) getCString:(char*)buffer maxLength:(NSUInteger)maxLength;
- (void) getCString:(char*)buffer
		  maxLength:(NSUInteger)maxLength
		  range:(NSRange)aRange
		  remainingRange:(NSRange*)leftoverRange;
										// YES if [y,Y,t,T or 1-9], ignores
- (BOOL) boolValue;						// leading white space, zeroes and +/-
- (int) intValue;
- (float) floatValue;
- (double) doubleValue;
- (long long) longLongValue;
- (NSInteger) integerValue;
														// String Encodings
- (BOOL) canBeConvertedToEncoding:(NSStringEncoding)encoding;
- (NSData*) dataUsingEncoding:(NSStringEncoding)encoding;
- (NSData*) dataUsingEncoding:(NSStringEncoding)e allowLossyConversion:(BOOL)f;

- (NSString*) description;

- (BOOL) writeToFile:(NSString*)filename atomically:(BOOL)useAuxiliaryFile;
- (void) getLineStart:(NSUInteger *)startIndex
				  end:(NSUInteger *)lineEndIndex
				  contentsEnd:(NSUInteger *)contentsEndIndex
				  forRange:(NSRange)aRange;
- (NSRange) lineRangeForRange:(NSRange)aRange;

- (NSString *) stringByReplacingOccurrencesOfString:(NSString *)target
										 withString:(NSString *)replacement
										 options:(NSStringCompareOptions)options
										 range:(NSRange)searchRange;

	// same as above method w/whole str range and 0 options
- (NSString *) stringByReplacingOccurrencesOfString:(NSString *)target
										 withString:(NSString *)replacement;
@end


@interface NSString (NSStringPathExtensions)		// s/b in NSPathUtilities

+ (NSString*) pathWithComponents:(NSArray*)components;

- (NSArray*) pathComponents;
- (NSArray*) stringsByAppendingPaths:(NSArray*)paths;

- (const char *) fileSystemRepresentation;
- (BOOL) getFileSystemRepresentation:(char *)buffer maxLength:(NSUInteger)max;
- (BOOL) isAbsolutePath;

- (NSUInteger) completePathIntoString:(NSString**)outputName
						  caseSensitive:(BOOL)flag
						  matchesIntoArray:(NSArray**)outputArray
						  filterTypes:(NSArray*)filterTypes;

- (NSString*) lastPathComponent;
- (NSString*) pathExtension;						// rets empty str if none
- (NSString*) stringByAbbreviatingWithTildeInPath;
- (NSString*) stringByAppendingPathComponent:(NSString*)aString;
- (NSString*) stringByAppendingPathExtension:(NSString*)aString;
- (NSString*) stringByDeletingLastPathComponent;
- (NSString*) stringByDeletingPathExtension;
- (NSString*) stringByExpandingTildeInPath;
- (NSString*) stringByResolvingSymlinksInPath;
- (NSString*) stringByStandardizingPath;

@end


@interface NSString (DeprecatedString)					// OSX deprecated

+ (id) stringWithCString:(const char*)byteString length:(NSUInteger)length;
+ (id) stringWithCString:(const char*)byteString;
- (id) initWithCString:(const char*)byteString length:(NSUInteger)length;
- (id) initWithCString:(const char*)byteString;

- (id) initWithCStringNoCopy:(char*)byteString
					  length:(NSUInteger)length
					  freeWhenDone:(BOOL)flag;
@end


@interface NSString (ConcreteString)

//+ (id) stringWithCString:(const char*)byteString encoding:(NSStringEncoding)e;
//- (id) initWithCString:(const char*)byteString encoding:(NSStringEncoding)e;

- (id) initWithCharactersNoCopy:(unichar*)chars
						 length:(NSUInteger)length
						 freeWhenDone:(BOOL)flag;

- (id) initWithCharacters:(const unichar*)chars length:(NSUInteger)length;
- (id) initWithUTF8String:(const char*)utf8String;
- (id) initWithString:(NSString*)string;
- (id) initWithFormat:(NSString*)format,...;
- (id) initWithFormat:(NSString*)format arguments:(va_list)list;
- (id) initWithData:(NSData*)data encoding:(NSStringEncoding)encoding;
- (id) initWithContentsOfFile:(NSString*)path;

- (unichar) characterAtIndex:(NSUInteger)index;			// OPENSTEP primitive

- (BOOL) isEqual:(id)anObject;
- (BOOL) isEqualToString:(NSString*)aString;

- (NSUInteger) hash;
- (NSUInteger) cStringLength;

- (void) getCharacters:(unichar*)buffer;				// Access Characters
- (void) getCharacters:(unichar*)buffer range:(NSRange)aRange;

- (NSStringEncoding) fastestEncoding;
- (NSStringEncoding) smallestEncoding;

@end


@interface NSString (OSPropertyListString)			// OPENSTEP Property List

- (id) propertyList;
- (NSDictionary*) propertyListFromStringsFileFormat;

@end


@interface NSString (LocalizedStrings)

+ (id) localizedStringWithFormat:(NSString*)format, ...;
- (id) initWithFormat:(NSString*)format locale:(id)locale, ...;
- (id) initWithFormat:(NSString*)format locale:(id)locale arguments:(va_list)ap;

@end


@interface NSMutableString : NSString

+ (id) stringWithCapacity:(NSUInteger)capacity;

@end


@interface NSMutableString  (NSMutableStringExtensionMethods)

- (id) initWithCapacity:(NSUInteger)capacity;

- (void) insertString:(NSString*)aString atIndex:(NSUInteger)index;
- (void) deleteCharactersInRange:(NSRange)range;
- (void) appendFormat:(NSString*)format, ...;
- (void) appendString:(NSString*)aString;
- (void) setString:(NSString*)aString;

- (void) replaceCharactersInRange:(NSRange)range withString:(NSString*)aString;

- (NSUInteger) replaceOccurrencesOfString:(NSString *)target
							   withString:(NSString *)replacement
							   options:(NSStringCompareOptions)options
							   range:(NSRange)searchRange;
@end

/* ****************************************************************************

 		Private

** ***************************************************************************/

@interface _NSBaseCString : NSString
@end

												// compiler thinks that @"..." 
@interface NSConstantString : _NSBaseCString	// strings are NXConstantString
@end


@interface _NSCString : _NSBaseCString
{
	BOOL _dontFree;
	NSUInteger _hash;
}
@end


@interface _NSMutableCString : _NSCString
{
	NSUInteger _capacity;
}
@end


@interface _NSUString : NSString
{
	BOOL _dontFree;
	NSUInteger _hash;
	unichar *_uniChars;
}
@end


@interface _NSMutableUString : _NSUString
{
	NSUInteger _capacity;
}
@end


@interface NSString (DecomposedCharacters)

- (int) _baseLength;			// method for working with decomposed strings

@end


#ifndef __cplusplus
typedef struct  { @defs(_NSUString); } CFString;
#endif

#endif /* _mGSTEP_H_NSString */
