/*
   NSScanner.m

   String parsing class

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Eric Norum <eric@skatter.usask.ca>
   Date: 1996

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSScanner.h>
#include <Foundation/NSException.h>
#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSDictionary.h>

#include <float.h>
#include <math.h>
#include <ctype.h>		// FIXME: May go away once I figure out Unicode


@implementation NSScanner
												// Create and return a scanner 
+ (id) scannerWithString:(NSString *)aString	// that scans aString.
{
	return [[[self alloc] initWithString: aString] autorelease];
}

+ (id) localizedScannerWithString:(NSString*)locale			{ NIMP return nil; }

- (id) initWithString:(NSString *)aString		// Initialize a newly-allocated 
{												// scanner to scan aString.
	[super init];

	_string = [aString copy];
	_length = [_string length];
	_skip = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	[_skip retain];

	return self;
}

- (void) dealloc
{
	[_string release];
	[locale release];
	[_skip release];

	[nSet release];
	[iSet release];

	[super dealloc];
}
								// Returns YES if no more characters remain to
- (BOOL) isAtEnd				// be scanned or if all characters remaining
{								// to be scanned are to be skipped.
	BOOL ret;					// Returns NO if there are chars left to scan.
	NSUInteger save_scanLocation;

	if (_scan.location >= _length)
		return YES;

	save_scanLocation = _scan.location;
	for (;_scan.location < _length; _scan.location++)
		if (![_skip characterIsMember:[_string characterAtIndex:_scan.location]])
			break;
	ret = (_scan.location >= _length);
	_scan.location = save_scanLocation;

	return ret;
}

/* ****************************************************************************

	private actual scanInt: performs all except for the initial skip.  This
	method may move the scan location even if a valid integer is not scanned.
	Based on the strtol code from the GNU C library. A little simpler since we
	deal only with base 10.
	
	FIX ME: I don't use decimalDigitCharacterSet since it includes many more
	characters than the ASCII digits.  I don't know how to convert those other
	characters, so I ignore them for now.  For the same reason, I don't try to
	support all the possible Unicode plus and minus chars.

** ***************************************************************************/

- (BOOL) _scanInt:(int*)value
{
	unsigned int num = 0;
	BOOL negative = NO;
	BOOL overflow = NO;
	BOOL got_digits = NO;
	const unsigned int limit = UINT_MAX / 10;

	switch ([_string characterAtIndex:_scan.location])	// Check for sign
		{
		case '+':
			_scan.location++;
			break;
		case '-':
			negative = YES;
			_scan.location++;
			break;
		}

	while (_scan.location < _length)					// Process digits
		{
		unichar digit = [_string characterAtIndex: _scan.location];
		if ((digit < '0') || (digit > '9'))
			break;
		if (!overflow) 
			{
			if (num >= limit)
				overflow = YES;
			else
				num = num * 10 + (digit - '0');
			}
		_scan.location++;
		got_digits = YES;
		}

	if (!got_digits)
		return NO;

	if (value)									// Save the result
		{
		if (overflow || (num > (negative ? (unsigned)INT_MIN : (unsigned)INT_MAX)))
			*value = negative ? INT_MIN : INT_MAX;
		else 
			*value = (negative) ? -num : num;
		}

	return YES;
}

- (BOOL) scanInt:(int*)value					// Scan an int into value
{
	NSUInteger saveScanLocation = _scan.location;

	for (;_scan.location < _length; _scan.location++)
		if (![_skip characterIsMember: [_string characterAtIndex:_scan.location]])
			break;
	if ((_scan.location < _length) && [self _scanInt: value])
		return YES;

	_scan.location = saveScanLocation;

	return NO;
}												// Scan a long long int into 
												// value. Same as scanInt, 
- (BOOL) scanLongLong:(long long *)value		// except with different
{												// variable types and limits.
	unsigned long long num = 0;
	const unsigned long long limit = ULONG_LONG_MAX / 10;
	BOOL negative = NO;
	BOOL overflow = NO;
	BOOL got_digits = NO;
	NSUInteger saveScanLocation = _scan.location;

	for (;_scan.location < _length; _scan.location++)	// Skip whitespace
		if (![_skip characterIsMember:[_string characterAtIndex:_scan.location]])
			break;
	if ((_scan.location >= _length))
		{
		_scan.location = saveScanLocation;
		return NO;
		}

	switch ([_string characterAtIndex:_scan.location])	// Check for sign
		{
		case '+':
			_scan.location++;
			break;
		case '-':
			negative = YES;
			_scan.location++;
			break;
		}

	while (_scan.location < _length)					// Process digits
		{
		unichar digit = [_string characterAtIndex:_scan.location];

		if ((digit < '0') || (digit > '9'))
			{
			if (digit == '.')			// found a decimal point
				got_digits = NO;		// num is a float or double
			break;
			}
		if (!overflow) 
			{
			if (num >= limit)
				overflow = YES;
			else
				num = num * 10 + (digit - '0');
			}
		_scan.location++;
		got_digits = YES;
		}

	if (!got_digits)									// Save result
		{
		_scan.location = saveScanLocation;

		return NO;
		}

	if (value)
		{
		if (overflow || (num > (negative ? (unsigned long long) LONG_LONG_MIN
										 : (unsigned long long) LONG_LONG_MAX)))
			*value = negative ? LONG_LONG_MIN : LONG_LONG_MAX;
		else 
			*value = (negative) ? -num : num;
		}

	return YES;
}
										// Scan a double into value. Returns 
- (BOOL) scanDouble:(double *)value		// YES if a valid floating-point expr
{										// was scanned.  Returns NO otherwise.
	unichar decimal;					// On overflow, HUGE_VAL or -HUGE_VAL
	unichar c = 0;						// is put in value and YES is returned.
	double num = 0.0;					// On underflow, 0.0 is put into value
	long int exponent = 0;				// and YES is returned.  Based on the
	BOOL negative = NO;					// strtod code from the GNU C library.
	BOOL got_dot = NO;
	BOOL got_digit = NO;
	NSUInteger saveScanLocation = _scan.location;

	for (;_scan.location < _length; _scan.location++)	// Skip whitespace
		if (![_skip characterIsMember:[_string characterAtIndex:_scan.location]])
			break;
	if ((_scan.location >= _length))
		{
		_scan.location = saveScanLocation;
		return NO;
		}				// FIX ME: Should get decimal point character from
						// locale.  The problem is that I can't find anything 
						// in the OPENSTEP specification about the format of 
	decimal = '.';		// the locale dictionary.

	switch ([_string characterAtIndex:_scan.location])	// Check for sign
		{
		case '+':
			_scan.location++;
			break;
		case '-':
			negative = YES;
			_scan.location++;
			break;
		}

	while (_scan.location < _length)					// Process number
		{
		c = [_string characterAtIndex: _scan.location];
		if ((c >= '0') && (c <= '9'))
			{		// Ensure that number being accumulated will not overflow
			if (num >= (DBL_MAX / 10.000000001))
				++exponent;
			else
				{
				num = (num * 10.0) + (c - '0');
				got_digit = YES;
				}					// Keep track of the number of digits after 
									// the decimal point. If we just divided  
			if (got_dot)			// by 10 here, we would lose precision.
				--exponent;
			}
		else 
			if (!got_dot && (c == decimal))			// found the decimal point
				got_dot = YES;
			else				// Any other character terminates the number.
				break;
		_scan.location++;
		}

	if (!got_digit)
		{
		_scan.location = saveScanLocation;
        return NO;
      	}

	if ((_scan.location < _length) && ((c == 'e') || (c == 'E')))
		{								// Check for trailing exponent
        int exp;						// numbers like 1.23eFOO are rejected

        _scan.location++;
        if (![self _scanInt: &exp])
			{
			_scan.location = saveScanLocation;
			return NO;
			}

		if (num)						// Check for exponent overflow
			{
			if ((exponent > 0) && (exp > (LONG_MAX - exponent)))
				exponent = LONG_MAX;
			else if ((exponent < 0) && (exp < (LONG_MIN - exponent)))
				exponent = LONG_MIN;
			else
				exponent += exp;
		}	}

	if (value)
		{
		if (num && exponent)
			num *= pow(10.0, (double) exponent);	// pow adds .00000000000001
		*value = (negative) ? -num : num;
		}

	return YES;
}										 

- (BOOL) scanFloat:(float*)value		// Scan a float into value. Returns YES
{										// if a valid floating-point expression 
	double num;							// was scanned.  Returns NO otherwise.
  										// On overflow, HUGE_VAL or -HUGE_VAL
	if (value == NULL)					// is put in value and YES is returned.
		return [self scanDouble:NULL];	// On underflow, 0.0 is put into value
										// and YES is returned.
	if ([self scanDouble:&num])
		{
		*value = num;
		return YES;
		}

	return NO;
}

/* ****************************************************************************

	Scan as long as characters from aSet are encountered. Returns YES if
	any characters were scanned.  Returns NO if no chars were scanned.
	If value is non-NULL, and any characters were scanned, a string
	containing the scanned characters is returned by reference in value.

** ***************************************************************************/

- (BOOL) scanCharactersFromSet:(NSCharacterSet *)set
					intoString:(NSString **)value
{
	NSUInteger saveScanLocation = _scan.location;

	for (;_scan.location < _length; _scan.location++)	// Skip whitespace
		if (![_skip characterIsMember:[_string characterAtIndex:_scan.location]])
			break;

	if ((_scan.location < _length))
		{
		NSUInteger start = _scan.location;

		for (;_scan.location < _length; _scan.location++)
			if (![set characterIsMember:[_string characterAtIndex:_scan.location]])
				break;

		if (_scan.location > start)
			{
			if (value)
				{
				NSRange range = {start, (_scan.location - start)};

				*value = [_string substringWithRange: range];
				}

			return YES;
		}	}

	_scan.location = saveScanLocation;

	return NO;
}

/* ****************************************************************************

	Scan until a character from aSet is encountered. Returns YES if any
	characters were scanned.  Returns NO if no characters were scanned.
	If value is non-NULL, and any characters were scanned, a string
	containing the scanned characters is returned by reference in value.

** ***************************************************************************/

- (BOOL) scanUpToCharactersFromSet:(NSCharacterSet *)set
						intoString:(NSString **)value
{
	NSUInteger saveScanLocation = _scan.location;
	NSUInteger start;

	for (;_scan.location < _length; _scan.location++)		// Skip whitespace
		if (![_skip characterIsMember:[_string characterAtIndex:_scan.location]])
			break;

	if ((_scan.location >= _length))
		return NO;

	for (start = _scan.location; _scan.location < _length; _scan.location++)
		if([set characterIsMember:[_string characterAtIndex:_scan.location]])
			break;

	if (_scan.location == start)
		{
		_scan.location = saveScanLocation;
		return NO;
		}

	if (value)
		{
		NSRange range = {start, _scan.location - start};

		*value = [_string substringWithRange: range];
		}

	return YES;
}

/* ****************************************************************************

	Scans for aString. Returns YES if chars at the scan location match aString.
	Returns NO if the characters at the scan location do not match aString.
	If the characters at the scan location match aString. If value is non-NULL,
	and the characters at the scan location match aString, a string containing
	the matching string is returned by reference in value.

** ***************************************************************************/

- (BOOL) scanString:(NSString *)aString intoString:(NSString **)value
{
	NSRange range;
	NSUInteger saveScanLocation = _scan.location;
    
	for (;_scan.location < _length; _scan.location++)
		if (![_skip characterIsMember:[_string characterAtIndex:_scan.location]])
			break;

	range.location = _scan.location;
	range.length = [aString length];
	if (range.location + range.length > _length)
		return NO;
	range = [_string rangeOfString:aString
					options:_caseSensitive ? 0 : NSCaseInsensitiveSearch
					range:range];
	if (range.length == 0)
		{
		_scan.location = saveScanLocation;
		return NO;
		}
	if (value)
		*value = [_string substringWithRange:range];
	_scan.location += range.length;

	return YES;
}
												// Scans string until aString
- (BOOL) scanUpToString:(NSString *)aString 	// is encountered.  Return YES
			 intoString:(NSString **)value		// if chars were scanned, NO 
{												// otherwise.  If value is not  
	NSRange range;								// NULL, and any chars were
	NSRange found;								// scanned, return by reference
	NSUInteger saveScanLocation = _scan.location;	// in value a string containing
    											// the scanned characters
	for (;_scan.location < _length; _scan.location++)
		if (![_skip characterIsMember:[_string characterAtIndex:_scan.location]])
			break;

	range.location = _scan.location;
	range.length = _length - _scan.location;
	found = [_string rangeOfString:aString
					 options:_caseSensitive ? 0 : NSCaseInsensitiveSearch
					 range:range];
	if (found.length)
		range.length = found.location - _scan.location;
	if (range.length == 0)
		{
		_scan.location = saveScanLocation;
		return NO;
		}
	if (value)
		*value = [_string substringWithRange:range];
	_scan.location += range.length;

	return YES;
}
														// string being scanned
- (NSString *) string						{ return _string; }
- (NSUInteger) scanLocation					{ return _scan.location; }
- (void) setScanLocation:(NSUInteger)index	{ _scan.location = index; }
- (BOOL) caseSensitive						{ return _caseSensitive; }
- (void) setCaseSensitive:(BOOL)flag		{ _caseSensitive = flag; }
- (NSCharacterSet *) charactersToBeSkipped	{ return _skip; }

- (void) setCharactersToBeSkipped:(NSCharacterSet *)aSet	
{														// set characters to be
	[_skip release];									// ignored during scan
	_skip = [aSet copy];
}
											 
- (void) setLocale:(NSDictionary *)localeDictionary		// Set dict containing
{														// locale info used by
	locale = [localeDictionary retain];					// the scanner
}

- (NSDictionary *) locale					{ return locale; }
														
- (id) copy												// NSCopying protocol
{
	NSScanner *n = [[self class] alloc];

	[n initWithString: _string];
	[n setCharactersToBeSkipped: _skip];
	[n setLocale: locale];
	[n setScanLocation: _scan.location];
	[n setCaseSensitive: _caseSensitive];

	return n;
}

//
// for NSText FIX ME need to eliminate
//
+ (id) _scannerWithString:(NSString*)aString 
					 set:(NSCharacterSet*)aSet 
					 invertedSet:(NSCharacterSet*)anInvSet
{	
	NSScanner *ret = [[self alloc] init];

	ASSIGN(ret->_string, aString); 
	ret->stringLength = [aString length]; 
	ret->_scan = NSMakeRange(0, ret->stringLength);
	ASSIGN(ret->nSet, aSet); 
	ASSIGN(ret->iSet, anInvSet);

	return [ret autorelease];
}

- (NSRange) _scanCharactersInverted:(BOOL)inverted
{	
	NSRange range = NSMakeRange(_scan.location, 0);
	NSCharacterSet *currentSet = inverted ? iSet : nSet;
	NSCharacterSet *currentISet = inverted ? nSet : iSet;
	unichar c;

	if(_scan.location >= stringLength) 
		return range;

	c = [_string characterAtIndex:_scan.location];
	if ([currentSet characterIsMember: c])
		range = [_string rangeOfCharacterFromSet:currentSet 
						 options:0
						 range:_scan];
	if (range.length)
		{	
		NSRange iRange = range;
		unsigned maxOfRange = NSMaxRange(range);

		iRange = [_string rangeOfCharacterFromSet:currentISet 
						  options:0
						  range:_NSAbsoluteRange(maxOfRange, stringLength)];
		if(iRange.length)	
			range = _NSAbsoluteRange(range.location, iRange.location);
		else				
			range = _NSAbsoluteRange(range.location, stringLength);
		_scan = _NSAbsoluteRange(NSMaxRange(range),stringLength);
		}

	return range;
}

- (NSRange) _scanNonSetCharacters
{	
	return [self _scanCharactersInverted:YES];
}

- (NSRange) _scanSetCharacters	{ return [self _scanCharactersInverted:NO]; }
- (BOOL) _isAtEnd				{ return _scan.location >= stringLength; }

- (void) _setScanLocation:(unsigned)aLoc 
{ 
	_scan = _NSAbsoluteRange(aLoc, stringLength);
}

@end
