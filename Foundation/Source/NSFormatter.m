/*
   NSFormatter.m

   Data formatting classes

   Copyright (C) 2000-2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:	January 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSFormatter.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSLocale.h>
#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSBundle.h>


#define STRINGIFY(x)	@#x
#define KEY(x)			STRINGIFY(x)

#define SET(x)		[_attributes setObject:s forKey:KEY(NS.x)];
#define GET(x)		[_attributes objectForKey:KEY(NS.x)]

#define GEL(x)		_f.localizesFormat ? [_locale objectForKey:KEY(NS.x)] \
									   : [_attributes objectForKey:KEY(NS.x)];

#define SAN(x)		[_attributes setObject:n forKey:KEY(NS.x)];
#define GAN(x)		[_attributes objectForKey:KEY(NS.x)]


typedef struct  { @defs(NSLocale); } CFLocale;



@implementation NSFormatter

- (NSAttributedString*) attributedStringForObjectValue:(id)anObject
								 withDefaultAttributes:(NSDictionary*)attr
{
	return nil;
}

- (NSString *) stringForObjectValue:(id)anObject	{ return SUBCLASS; }

- (NSString *) editingStringForObjectValue:(id)anObject
{ 
	return [self stringForObjectValue: anObject]; 
}

- (BOOL) getObjectValue:(id*)anObject
			  forString:(NSString*)string
			  errorDescription:(NSString**)error	{ SUBCLASS return NO; }

- (BOOL) isPartialStringValid:(NSString*)partialString
			 newEditingString:(NSString**)newString
			 errorDescription:(NSString**)error
{
	*newString = nil;
	*error = nil;

	return YES;
}

- (id) copy											{ return SUBCLASS }
- (id) initWithCoder:(NSCoder*)aCoder				{ return SUBCLASS }
- (void) encodeWithCoder:(NSCoder*)aCoder			{ SUBCLASS }

@end

/* ****************************************************************************

	NSDateFormatter

** ***************************************************************************/

@implementation NSDateFormatter

- (id) init
{
	_locale = [[NSLocale currentLocale] retain];
	_attributes = [[[NSMutableDictionary alloc] initWithObjectsAndKeys: \
					@"%Y-%m-%d %H:%M:%S %z", @"NS.dateFormat", nil] retain];
	return self;
}

- (void) dealloc
{
	[_locale release],		_locale = nil;
	[_attributes release],	_attributes = nil;
	[super dealloc];
}

- (BOOL) getObjectValue:(id*)obj					// string to cell object
			  forString:(NSString*)s
			  errorDescription:(NSString**)error
{
	NSDate *d = [self dateFromString:s];

    if ((obj && (*obj = d)) || d)
		return YES;

	if (error)
		*error = NSLocalizedString(@"Conversion failed", @"Invalid string");

    return NO;
}

- (NSString *) stringFromDate:(NSDate *)date
{
	return [date descriptionWithLocale: _locale];
}

- (NSDate *) dateFromString:(NSString *)string	{ return nil; }

- (NSLocale *) locale							{ return _locale; }
- (void) setLocale:(NSLocale *)locale			{ ASSIGN(_locale, locale); }

- (NSString *) dateFormat						{ return GET(dateFormat); }
- (void) setDateFormat:(NSString *)s			{ SET(dateFormat); }

@end

/* ****************************************************************************

	NSNumberFormatter

** ***************************************************************************/

@implementation NSNumberFormatter

- (id) init
{
	_attributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys: \
							@"E",		@"NS.exponentSymbol",
							@"*",		@"NS.paddingCharacter",
							@"%",		@"NS.percentSymbol",
							@"(null)",	@"NS.zeroSymbol",
							@"NaN",		@"NS.notANumberSymbol",
							@"‰",		@"NS.perMillSymbol",
							@"∞",		@"NS.positiveInfinitySymbol",
							@"-∞",		@"NS.negativeInfinitySymbol",
							@"-",		@"NS.minusSign",
							@"+",		@"NS.plusSign",
							@"#;0;#",	@"NS.format", nil];
	_f.allowsFloats = YES;
	_f.localizesFormat = YES;
	_locale = [[NSLocale currentLocale] retain];

	return self;
}

- (void) dealloc
{
	[_locale release],		_locale = nil;
	[_attributes release],	_attributes = nil;
	[super dealloc];
}

- (BOOL) getObjectValue:(id*)obj					// string to cell object
			  forString:(NSString*)s
			  errorDescription:(NSString**)error
{
	NSNumber *n = [self numberFromString:s];

    if ((obj && (*obj = n)) || n)
		return YES;

	if (error)
		*error = NSLocalizedString(@"Conversion failed", @"Invalid string");

    return NO;
}

- (NSString *) stringForObjectValue:(id)anObject	// cell object to string
{
	if (!anObject)
		return [self zeroSymbol];
	if ([anObject isKindOfClass: [NSNumber class]])
		return [self stringFromNumber: anObject];

	return [anObject description];
}

- (NSString *) stringFromNumber:(NSNumber *)number
{
	CFLocale locale = {0};

	locale._cache = ((CFLocale *)_locale)->_cache;
	locale._overrides = _attributes;

	return [number descriptionWithLocale: (id)&locale];
}

- (NSNumber *) numberFromString:(NSString *)s
{
	NSCharacterSet *dg = [NSCharacterSet characterSetWithCharactersInString: @"0123456789#.,_-+"];
//	NSCharacterSet *ws = [NSCharacterSet whitespaceCharacterSet];
	BOOL isNegative = NO;
	NSRange r;

//	s = [s stringByTrimmingCharactersInSet: ws];
	r = [s rangeOfCharacterFromSet: dg];
	if (r.location && r.location != NSNotFound)			// have prefix/suffix
		{
		NSString *pp = GET(positivePrefix);
		NSString *ps = GET(positiveSuffix);
		NSString *np = GET(negativePrefix);
		NSString *ns = GET(negativeSuffix);

		NSCharacterSet *c = [NSCharacterSet characterSetWithCharactersInString: @"()"];

//		if (!np && [nfmt rangeOfCharacterFromSet: fc].location)
//		if ([s rangeOfString: np].length || [s rangeOfString: ns].length)
//			{
//			s = [s substringWithRange: NSMaxRange(np), ns.location - NSMaxRange(np)];
			isNegative = YES;
//			}
//		if (!pp && [pfmt rangeOfCharacterFromSet: fc].location)
//		if ([s rangeOfString: pp].length || [s rangeOfString: ps].length)
//			s = [s substringWithRange: NSMaxRange(pp), ps.location - NSMaxRange(pp)];

		s = [s stringByTrimmingCharactersInSet: c];
//		s = [s substringWithRange: r];					// trim prefix/suffix
		}

//	if (_f.usesGroupingSeparator)
		{
		NSString *group = [self groupingSeparator];

		if ([s rangeOfString: group].length)
			s = [s stringByReplacingOccurrencesOfString:group withString:@""];
		}
	if (_f.allowsFloats)
		{
		NSString *ds = [self decimalSeparator];

		if ([s rangeOfString: ds].length)
			{
//			NSUInteger minFD = GEN(minimumFractionDigits);
//			NSUInteger maxFD = GEN(maximumFractionDigits);
			NSRange dr;

			if (![ds isEqualToString: @"."])
				s = [s stringByReplacingOccurrencesOfString:ds withString:@"."];

//			dr = [s rangeOfString: @"." options: NSBackwardsSearch];

	// FIX ME restrict Integer / Fractional to format lengths
			r = [s rangeOfCharacterFromSet: dg];
			if (r.length < 1 || r.location != 0)
				return nil;
	
			if (_f.usesSignificantDigits && [self maximumSignificantDigits] > 7)
				return [NSNumber numberWithDouble: (isNegative ? -1 * [s doubleValue] : [s doubleValue])];

			return [NSNumber numberWithFloat: (isNegative ? -1 * [s floatValue] : [s floatValue])];
//			if (_f.generatesDecimalNumbers)		ignored, lacks NSDecimal
//			 return [NSDecimalNumber decimalNumberWithString:s locale:_locale];
			}
		}

	r = [s rangeOfCharacterFromSet: dg];		// FIX ME better # validation
	if (r.length < 1 || r.location != 0)
		return nil;

	return [NSNumber numberWithInt: [s intValue]];
}

- (NSLocale *) locale						{ return _locale; }
- (void) setLocale:(NSLocale *)locale		{ ASSIGN(_locale, locale); }
- (void) setUsesGroupingSeparator:(BOOL)f   { _f.usesGroupingSeparator = f; }
- (void) setHasThousandSeparators:(BOOL)f   { _f.hasThousandSeparators = f; }
- (void) setLocalizesFormat:(BOOL)flag		{ _f.localizesFormat = flag; }
- (BOOL) localizesFormat					{ return _f.localizesFormat; }
- (BOOL) hasThousandSeparators				{ return _f.hasThousandSeparators; }
- (BOOL) usesGroupingSeparator				{ return _f.usesGroupingSeparator; }
- (BOOL) alwaysShowsDecimalSeparator  { return _f.alwaysShowsDecimalSeparator; }
- (BOOL) generatesDecimalNumbers	  { return _f.generatesDecimalNumbers; }
- (BOOL) allowsFloats						{ return _f.allowsFloats; }
- (void) setAllowsFloats:(BOOL)flag			{ _f.allowsFloats = flag; }

- (void) setNumberStyle:(NSNumberFormatterStyle)style
{
	if (_f.style != style)
		switch ((_f.style = style))
			{
			case NSNumberFormatterDecimalStyle:
							[self setFormat: @"0.##;0;0.##"];			break;
			case NSNumberFormatterCurrencyStyle:
							[self setFormat: @"#,##0.00;0;#,##0.00"];	break;
			default:		[self setFormat: @"#;0;#"];					break;
			}
}

- (NSNumberFormatterStyle) numberStyle			{ return _f.style; }
- (NSNumberFormatterRoundingMode) roundingMode	{ return _f.roundingMode; }
- (NSNumberFormatterPadPosition) paddingPosition{ return _f.paddingPosition; }

- (void) setRoundingMode:(NSNumberFormatterRoundingMode)mode
{
	_f.roundingMode = mode;
}

- (void) setPaddingPosition:(NSNumberFormatterPadPosition)position
{
	_f.paddingPosition = position;
}

- (void) setCurrencyCode:(NSString *)s			{ SET(currencyCode); }
- (void) setCurrencySymbol:(NSString *)s		{ SET(currencySymbol); }
- (void) setPercentSymbol:(NSString *)s			{ SET(percentSymbol); }

- (NSString *) currencyCode						{ return GEL(currencyCode); }
- (NSString *) currencySymbol					{ return GEL(currencySymbol); }
- (NSString *) percentSymbol					{ return GET(percentSymbol); }
- (NSString *) plusSign							{ return GET(plusSign); }
- (NSString *) minusSign						{ return GET(minusSign); }
- (NSString *) exponentSymbol					{ return GET(exponentSymbol); }
- (NSString *) notANumberSymbol					{ return GET(notANumberSymbol); }
- (NSString *) perMillSymbol					{ return GET(perMillSymbol); }
- (NSString *) nilSymbol						{ return GET(nilSymbol); }
- (NSString *) zeroSymbol						{ return GET(zeroSymbol); }

- (void) setPlusSign:(NSString *)s				{ SET(plusSign); }
- (void) setMinusSign:(NSString *)s				{ SET(minusSign); }
- (void) setExponentSymbol:(NSString *)s		{ SET(exponentSymbol); }
- (void) setNotANumberSymbol:(NSString *)s		{ SET(notANumberSymbol); }
- (void) setPerMillSymbol:(NSString *)s			{ SET(zeroSymbol); }
- (void) setNilSymbol:(NSString *)s				{ SET(nilSymbol); }
- (void) setZeroSymbol:(NSString *)s			{ SET(zeroSymbol); }

- (NSString *) groupingSeparator				{ return GEL(groupingSeparator); }
- (NSString *) thousandSeparator				{ return GET(thousandSeparator); }
- (NSString *) decimalSeparator					{ return GEL(decimalSeparator); }
- (NSString *) paddingCharacter					{ return GET(paddingCharacter); }

- (void) setGroupingSeparator:(NSString *)s		{ SET(groupingSeparator); }
- (void) setThousandSeparator:(NSString *)s		{ SET(thousandSeparator); }
- (void) setDecimalSeparator:(NSString *)s		{ SET(decimalSeparator); }
- (void) setPaddingCharacter:(NSString *)s		{ SET(paddingCharacter); }

- (void) setPositiveInfinitySymbol:(NSString*)s { SET(positiveInfinitySymbol); }
- (void) setNegativeInfinitySymbol:(NSString*)s { SET(negativeInfinitySymbol); }

- (NSString *) positiveInfinitySymbol	{ return GET(positiveInfinitySymbol); }
- (NSString *) negativeInfinitySymbol	{ return GET(negativeInfinitySymbol); }

#define SEN(x)			[_attributes setObject:[NSNumber numberWithUnsignedInt: n] forKey:KEY(NS.x)];
#define GEN(x)			[[_attributes objectForKey:KEY(NS.x)] unsignedIntValue]

- (void) setMinimumIntegerDigits:(NSUInteger)n	{ SEN(minimumIntegerDigits); }
- (void) setMaximumIntegerDigits:(NSUInteger)n	{ SEN(maximumIntegerDigits); }
- (void) setMinimumFractionDigits:(NSUInteger)n	{ SEN(minimumFractionDigits); }
- (void) setMaximumFractionDigits:(NSUInteger)n	{ SEN(maximumFractionDigits); }

- (NSUInteger) minimumIntegerDigits		{ return GEN(minimumIntegerDigits); }
- (NSUInteger) maximumIntegerDigits		{ return GEN(maximumIntegerDigits); }
- (NSUInteger) minimumFractionDigits	{ return GEN(minimumFractionDigits); }
- (NSUInteger) maximumFractionDigits	{ return GEN(maximumFractionDigits); }

- (NSUInteger) groupingSize				{ return GEN(groupingSize); }
- (void) setGroupingSize:(NSUInteger)n	{ SEN(groupingSize); }

- (NSUInteger) formatWidth				{ return GEN(formatWidth); }
- (void) setFormatWidth:(NSUInteger)n	{ SEN(formatWidth); }

- (BOOL) usesSignificantDigits				{ return _f.usesSignificantDigits; }
- (void) setUsesSignificantDigits:(BOOL)f	{ _f.usesSignificantDigits = f; }

- (void) setMinimumSignificantDigits:(NSUInteger)n
{
	SEN(minimumSignificantDigits);
}

- (void) setMaximumSignificantDigits:(NSUInteger)n
{
	SEN(maximumSignificantDigits);
}

- (NSUInteger) minimumSignificantDigits
{
	NSNumber *n = nil;

	if (_f.usesSignificantDigits)
		n = [_attributes objectForKey:KEY(NS.minimumSignificantDigits)];

	return (n) ? [n unsignedIntValue] : ((_f.usesSignificantDigits) ? 1 : 0);
}

- (NSUInteger) maximumSignificantDigits
{
	NSNumber *n = nil;

	if (_f.usesSignificantDigits)
		n = [_attributes objectForKey:KEY(NS.maximumSignificantDigits)];

	return (n) ? [n unsignedIntValue] : ((_f.usesSignificantDigits) ? 6 : 0);
}

- (NSNumber *) multiplier					{ return GAN(multiplier); }
- (NSNumber *) roundingIncrement			{ return GAN(roundingIncrement); }

- (void) setMultiplier:(NSNumber *)n			{ SAN(multiplier); }
- (void) setRoundingIncrement:(NSNumber *)n 	{ SAN(roundingIncrement); }

- (NSNumber *) minimum							{ return GAN(minimum); }
- (NSNumber *) maximum							{ return GAN(maximum); }

- (void) setMinimum:(NSNumber *)n				{ SAN(minimum); }
- (void) setMaximum:(NSNumber *)n				{ SAN(maximum); }

- (void) setFormat:(NSString *)s
{
	if ([[s componentsSeparatedByString:@";"] count] != 3)
		NSLog(@"Invalid format string %@", s);
	else
		[_attributes setObject:s forKey:KEY(NS.format)];
}

- (void) setPositiveFormat:(NSString *)s
{
	id a = [GET(format) componentsSeparatedByString:@";"];

	[a replaceObjectAtIndex:0 withObject:s];
	[self setFormat:[a componentsJoinedByString:@";"]];
	[_attributes setObject:s forKey:KEY(NS.positiveFormat)];
}

- (void) setNegativeFormat:(NSString *)s
{
	id a = [GET(format) componentsSeparatedByString:@";"];

	[a replaceObjectAtIndex:2 withObject:s];
	[self setFormat:[a componentsJoinedByString:@";"]];
	[_attributes setObject:s forKey:KEY(NS.negativeFormat)];
}

- (NSString *) positiveFormat
{
	return [[GET(format) componentsSeparatedByString:@";"] objectAtIndex:0];
}

- (NSString *) negativeFormat
{
	return [[GET(format) componentsSeparatedByString:@";"] objectAtIndex:2];
}

- (NSString *) format							{ return GET(format); }
- (NSString *) positivePrefix					{ return GET(positivePrefix); }
- (NSString *) positiveSuffix					{ return GET(positiveSuffix); }
- (NSString *) negativePrefix					{ return GET(negativePrefix); }
- (NSString *) negativeSuffix					{ return GET(negativeSuffix); }

- (void) setPositivePrefix:(NSString *)s		{ SET(positivePrefix); }
- (void) setPositiveSuffix:(NSString *)s		{ SET(positiveSuffix); }
- (void) setNegativePrefix:(NSString *)s		{ SET(negativePrefix); }
- (void) setNegativeSuffix:(NSString *)s		{ SET(negativeSuffix); }

@end
