/* 
   NSFormatter.h

   Text formatting classes

   Copyright (C) 2000-2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:	January 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSFormatter
#define _mGSTEP_H_NSFormatter

#include <Foundation/NSObject.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSDate.h>

@class NSString;
@class NSAttributedString;
@class NSMutableDictionary;
@class NSDictionary;
@class NSLocale;


@interface NSFormatter : NSObject  <NSCopying, NSCoding>

- (NSString*) stringForObjectValue:(id)anObject;	// cell object to string
- (NSString*) editingStringForObjectValue:(id)anObject;

- (NSAttributedString*) attributedStringForObjectValue:(id)anObject
								 withDefaultAttributes:(NSDictionary*)attr;

- (BOOL) getObjectValue:(id*)anObject				// convert string to
			  forString:(NSString*)string			// formatted cell object
			  errorDescription:(NSString**)error;

- (BOOL) isPartialStringValid:(NSString*)partialString
			 newEditingString:(NSString**)newString
			 errorDescription:(NSString**)error;
@end


typedef enum {
	NSDateFormatterNoStyle     = 0,
	NSDateFormatterShortStyle  = 1,
	NSDateFormatterMediumStyle = 2,
	NSDateFormatterLongStyle   = 3,
	NSDateFormatterFullStyle   = 4
} NSDateFormatterStyle;


@interface NSDateFormatter : NSFormatter
{
	NSMutableDictionary *_attributes;
//  NSUInteger _counter;

// 	CFDateFormatterRef _formatter;
//    UDateFormat *_df;
	  NSLocale *_locale;						// CFLocaleRef
//    CFDateFormatterStyle _timeStyle;
//    CFDateFormatterStyle _dateStyle;
//    CFStringRef _format;
}

- (NSString *) stringFromDate:(NSDate *)date;
- (NSDate *) dateFromString:(NSString *)string;

- (NSLocale *) locale;
- (void) setLocale:(NSLocale *)locale;

- (NSString *) dateFormat;
- (void) setDateFormat:(NSString *)string;

@end


@interface NSDateFormatter  (NotImplemented)

- (BOOL) generatesCalendarDates;
- (void) setGeneratesCalendarDates:(BOOL)flag;

- (NSDateFormatterStyle) dateStyle;
- (void) setDateStyle:(NSDateFormatterStyle)style;

- (NSDateFormatterStyle) timeStyle;
- (void) setTimeStyle:(NSDateFormatterStyle)style;

@end

/* ****************************************************************************

	Format string syntax is defined in Unicode Technical Standard 35

	http://unicode.org/reports/tr35/tr35-10.html#Number_Format_Patterns

	#,##0.00;0;(#,##0.00)  positive_pattern ; zero_pattern ; negative_pattern

	Use # or 0 to specify a number (zero pad).  Grouping separator ',' and
	decimal separator '.' are replaced by locale equivalent in output string.

	NSNumber *num2 = [NSNumber numberWithDouble:-55.28];
	[fmt setNumberStyle: NSNumberFormatterDecimalStyle];
	[fmt setNegativeFormat: @"(0.00)"];						// (55.28)

	// maximum 2 fractional digits with no padding
	12.3456  using  0.##  ==>  12.35
	1.5      using  0.##  ==>  1.5

	// maximum 2 fractional digits with zero padding
	12.3456  using  0.00  ==>  12.35
	1.5      using  0.00  ==>  1.50

	// thousands separator
	1500     using #,##0.00  ==> 1,500.00

** ***************************************************************************/

typedef enum {
	NSNumberFormatterNoStyle         = 0,
	NSNumberFormatterDecimalStyle    = 1,
	NSNumberFormatterCurrencyStyle   = 2,
	NSNumberFormatterPercentStyle    = 3,
	NSNumberFormatterScientificStyle = 4,
	NSNumberFormatterSpellOutStyle   = 5
} NSNumberFormatterStyle;

typedef enum {
	NSNumberFormatterPadBeforePrefix = 0,
	NSNumberFormatterPadAfterPrefix  = 1,
	NSNumberFormatterPadBeforeSuffix = 2,
	NSNumberFormatterPadAfterSuffix  = 3
} NSNumberFormatterPadPosition;

typedef enum {
	NSNumberFormatterRoundCeiling  = 0,
	NSNumberFormatterRoundFloor    = 1,
	NSNumberFormatterRoundDown     = 2,
	NSNumberFormatterRoundUp       = 3,
	NSNumberFormatterRoundHalfEven = 4,
	NSNumberFormatterRoundHalfDown = 5,
	NSNumberFormatterRoundHalfUp   = 6
} NSNumberFormatterRoundingMode;


@interface NSNumberFormatter : NSFormatter
{
	NSMutableDictionary *_attributes;
//	NSUInteger _counter;
//	NSRecursiveLock *_lock;					// thread safe on OSX > 10.9

//  CFNumberFormatterRef _formatter
//    UNumberFormat *_nf;
      NSLocale *_locale;					// CFLocaleRef
//    NSNumberFormatterStyle _style;		// CFNumberFormatterStyle
//    CFStringRef _format;
//    CFStringRef _defformat;
//    CFStringRef _compformat;
//    CFNumberRef _multiplier;
//    CFStringRef _zeroSym;
//    Boolean _isLenient;
//    Boolean _userSetMultiplier;
//    Boolean _usesCharacterDirection;

	struct __FormatterFlags {
		NSNumberFormatterStyle style:3;
		NSNumberFormatterRoundingMode roundingMode:3;
		NSNumberFormatterPadPosition paddingPosition:2;
		unsigned int allowsFloats:1;
		unsigned int userSetMultiplier:1;
		unsigned int hasThousandSeparators:1;
		unsigned int usesGroupingSeparator:1;
		unsigned int alwaysShowsDecimalSeparator:1;
		unsigned int generatesDecimalNumbers:1;
		unsigned int usesSignificantDigits:1;
		unsigned int localizesFormat:1;
		unsigned int reserved:16;
	} _f;
}

- (NSString *) stringFromNumber:(NSNumber *)number;
- (NSNumber *) numberFromString:(NSString *)string;

- (NSLocale *) locale;
- (void) setLocale:(NSLocale *)locale;

- (BOOL) allowsFloats;
- (void) setAllowsFloats:(BOOL)flag;

- (NSString *) positiveFormat;
- (NSString *) negativeFormat;

- (void) setPositiveFormat:(NSString *)format;
- (void) setNegativeFormat:(NSString *)format;	// alter Positive prefix/suffix

- (void) setNumberStyle:(NSNumberFormatterStyle)style;
- (NSNumberFormatterStyle) numberStyle;

- (NSString *) positiveInfinitySymbol;
- (NSString *) negativeInfinitySymbol;

- (void) setPositiveInfinitySymbol:(NSString *)string;
- (void) setNegativeInfinitySymbol:(NSString *)string;

- (NSString *) nilSymbol;
- (NSString *) zeroSymbol;
- (NSString *) notANumberSymbol;

- (void) setNilSymbol:(NSString *)string;
- (void) setZeroSymbol:(NSString *)string;
- (void) setNotANumberSymbol:(NSString *)string;

- (NSString *) positivePrefix;
- (NSString *) positiveSuffix;
- (NSString *) negativePrefix;
- (NSString *) negativeSuffix;

- (void) setPositivePrefix:(NSString *)string;
- (void) setPositiveSuffix:(NSString *)string;
- (void) setNegativePrefix:(NSString *)string;
- (void) setNegativeSuffix:(NSString *)string;

- (NSString *) currencyCode;
- (NSString *) currencySymbol;
- (NSString *) percentSymbol;
- (NSString *) perMillSymbol;
- (NSString *) minusSign;
- (NSString *) plusSign;
- (NSString *) exponentSymbol;

- (void) setCurrencyCode:(NSString *)string;
- (void) setCurrencySymbol:(NSString *)string;
- (void) setPercentSymbol:(NSString *)string;
- (void) setPerMillSymbol:(NSString *)string;
- (void) setMinusSign:(NSString *)string;
- (void) setPlusSign:(NSString *)string;
- (void) setExponentSymbol:(NSString *)string;
												// specify significant digits
- (BOOL) usesSignificantDigits;					// with Sig* methods ignoring
- (void) setUsesSignificantDigits:(BOOL)flag;	// default Frac/Int methods
- (void) setMinimumSignificantDigits:(NSUInteger)number;
- (void) setMaximumSignificantDigits:(NSUInteger)number;
- (NSUInteger) minimumSignificantDigits;		// 1 default
- (NSUInteger) maximumSignificantDigits;		// 6

- (NSNumber *) minimum;							// min/max numbers allowed as
- (NSNumber *) maximum;							// input

- (void) setMinimum:(NSNumber *)min;
- (void) setMaximum:(NSNumber *)max;

- (NSUInteger) minimumIntegerDigits;			// default min/max digits
- (NSUInteger) maximumIntegerDigits;
- (NSUInteger) minimumFractionDigits;
- (NSUInteger) maximumFractionDigits;

- (void) setMinimumIntegerDigits:(NSUInteger)number;
- (void) setMaximumIntegerDigits:(NSUInteger)number;
- (void) setMinimumFractionDigits:(NSUInteger)number;
- (void) setMaximumFractionDigits:(NSUInteger)number;

- (NSUInteger) groupingSize;
- (void) setGroupingSize:(NSUInteger)groupSize;

- (NSNumber *) multiplier;
- (void) setMultiplier:(NSNumber *)number;

- (NSUInteger) formatWidth;
- (void) setFormatWidth:(NSUInteger)number;

- (NSString *) paddingCharacter;
- (void) setPaddingCharacter:(NSString *)string;

- (NSNumberFormatterPadPosition) paddingPosition;
- (void) setPaddingPosition:(NSNumberFormatterPadPosition)position;

- (NSNumberFormatterRoundingMode) roundingMode;
- (void) setRoundingMode:(NSNumberFormatterRoundingMode)mode;

- (NSNumber *) roundingIncrement;
- (void) setRoundingIncrement:(NSNumber *)number;

@end


@interface NSNumberFormatter  (NSNumberFormatterCompatibility)

- (BOOL) hasThousandSeparators;
- (BOOL) usesGroupingSeparator;
- (BOOL) alwaysShowsDecimalSeparator;
- (BOOL) generatesDecimalNumbers;

- (void) setHasThousandSeparators:(BOOL)flag;
- (void) setUsesGroupingSeparator:(BOOL)flag;
- (void) setAlwaysShowsDecimalSeparator:(BOOL)flag;
- (void) setGeneratesDecimalNumbers:(BOOL)flag;

- (NSString *) decimalSeparator;
- (NSString *) thousandSeparator;
- (NSString *) groupingSeparator;

- (void) setGroupingSeparator:(NSString *)separator;
- (void) setThousandSeparator:(NSString *)separator;
- (void) setDecimalSeparator:(NSString *)separator;

- (NSString *) format;
- (void) setFormat:(NSString *)format;

- (BOOL) localizesFormat;							// "$,." are localized w/o
- (void) setLocalizesFormat:(BOOL)flag;				// a currency conversion

- (NSAttributedString *) attributedStringForNil;
- (NSAttributedString *) attributedStringForZero;
- (NSAttributedString *) attributedStringForNotANumber;

- (void) setAttributedStringForNil:(NSAttributedString *)aString;
- (void) setAttributedStringForZero:(NSAttributedString *)aString;
- (void) setAttributedStringForNotANumber:(NSAttributedString *)aString;

@end



#if 0		// CF CFNumberFormatterRef keys  (extern const CFStringRef)
kCFNumberFormatterCurrencyCode;					// CFString
kCFNumberFormatterDecimalSeparator;				// CFString
kCFNumberFormatterCurrencyDecimalSeparator;		// CFString
kCFNumberFormatterAlwaysShowDecimalSeparator;	// CFBoolean
kCFNumberFormatterGroupingSeparator;			// CFString
kCFNumberFormatterUseGroupingSeparator;			// CFBoolean
kCFNumberFormatterPercentSymbol;				// CFString
kCFNumberFormatterZeroSymbol;					// CFString
kCFNumberFormatterNaNSymbol;					// CFString
kCFNumberFormatterInfinitySymbol;				// CFString
kCFNumberFormatterMinusSign;					// CFString
kCFNumberFormatterPlusSign;						// CFString
kCFNumberFormatterCurrencySymbol;				// CFString
kCFNumberFormatterExponentSymbol;				// CFString
kCFNumberFormatterMinIntegerDigits;				// CFNumber
kCFNumberFormatterMaxIntegerDigits;				// CFNumber
kCFNumberFormatterMinFractionDigits;			// CFNumber
kCFNumberFormatterMaxFractionDigits;			// CFNumber
kCFNumberFormatterGroupingSize;					// CFNumber
kCFNumberFormatterSecondaryGroupingSize;		// CFNumber
kCFNumberFormatterRoundingMode;					// CFNumber
kCFNumberFormatterRoundingIncrement;			// CFNumber
kCFNumberFormatterFormatWidth;					// CFNumber
kCFNumberFormatterPaddingPosition;				// CFNumber
kCFNumberFormatterPaddingCharacter;				// CFString
kCFNumberFormatterDefaultFormat;				// CFString
kCFNumberFormatterMultiplier;					// CFNumber
kCFNumberFormatterPositivePrefix;				// CFString
kCFNumberFormatterPositiveSuffix;				// CFString
kCFNumberFormatterNegativePrefix;				// CFString
kCFNumberFormatterNegativeSuffix;				// CFString
kCFNumberFormatterPerMillSymbol;				// CFString
kCFNumberFormatterInternationalCurrencySymbol;	// CFString
kCFNumberFormatterCurrencyGroupingSeparator;	// CFString
kCFNumberFormatterIsLenient;			 		// CFBoolean
kCFNumberFormatterUseSignificantDigits; 		// CFBoolean
kCFNumberFormatterMinSignificantDigits; 		// CFNumber
kCFNumberFormatterMaxSignificantDigits; 		// CFNumber
#endif

#endif /* _mGSTEP_H_NSFormatter */
