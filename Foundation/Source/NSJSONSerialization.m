/*
   NSJSONSerialization.m

   JSON serialization of Foundation objects

   Copyright (C) 2015 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	October 2015

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSJSONSerialization.h>
#include <Foundation/NSData.h>
#include <Foundation/NSString.h>
#include <Foundation/NSError.h>
#include <Foundation/NSNull.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSException.h>
#include <Foundation/NSScanner.h>
#include <Foundation/NSCharacterSet.h>
#include <math.h>

#define PP_INDENT  4



@implementation NSObject  (SerializeJSON)

- (BOOL) _isValidJSONObject							{ return NO; }
- (id) _encodeJSON:(NSMutableData*)data
			indent:(int)level						{ return nil; }
@end


@implementation NSString  (SerializeJSON)

- (BOOL) _isValidJSONObject							{ return YES; }

- (id) _encodeJSON:(NSMutableData*)data indent:(int)level
{
    NSString *s = [NSString stringWithFormat:@"\"%@\"", self];

	[data appendData: [s dataUsingEncoding: NSASCIIStringEncoding]];

    return self;
}

@end

@implementation NSNull  (SerializeJSON)

- (BOOL) _isValidJSONObject							{ return YES; }

- (id) _encodeJSON:(NSMutableData*)data indent:(int)level
{
	[data appendBytes:"null" length:4];

    return self;
}

@end


@implementation NSNumber  (SerializeJSON)

- (BOOL) _isValidJSONObject							{ return YES; }

- (id) _encodeJSON:(NSMutableData*)data indent:(int)level
{
	if (strncmp([self objCType], @encode(BOOL), 1) == 0)
		{
		if ([self boolValue])
			[data appendBytes:"true" length:4];
		else
			[data appendBytes:"false" length:5];
		}
	else
		{
		NSString *s = [self description];

		[data appendData: [s dataUsingEncoding: NSASCIIStringEncoding]];
		}

    return self;
}

@end

@implementation NSArray  (SerializeJSON)

- (BOOL) _isValidJSONObject
{
	NSUInteger i = _count;

	while (i-- > 0)
		if (![_contents[i] _isValidJSONObject])
			return NO;

	return YES;
}

- (id) _encodeJSON:(NSMutableData*)data indent:(int)level
{
	NSUInteger i;
	char sepa[64] = {',',0};
	char open[64] = {'[',0};
	char close[64] = {']',0};
	
	if (level && level < 10)
		{
		level += 1;
		memcpy(open,"[\n", 2);
		memset(open+2,' ', PP_INDENT * level);
//		memcpy(close,"]\n", 2);
//		memset(close+2,' ', PP_INDENT * level);
		memcpy(sepa,",\n", 2);
		memset(sepa+2,' ', PP_INDENT * level);
		}

	[data appendBytes:open length:strlen(open)];

	for (i = 0 ; i < _count; i++)
		{
		if (i)
			[data appendBytes:sepa length:strlen(sepa)];
		if (![_contents[i] _encodeJSON:data indent:level])
			return nil;
		}

	if (level)
		{
		memset(sepa, 0, 64);
		memset(sepa+1,' ', PP_INDENT * (level-1));
		sepa[0] = '\n';
		[data appendBytes:sepa length:strlen(sepa)];
		}
	[data appendBytes:close length:strlen(close)];

    return self;
}

@end

@implementation NSDictionary  (SerializeJSON)

- (BOOL) _isValidJSONObject
{
	id key, keys = [self keyEnumerator];

	while ((key = [keys nextObject]))
		if (![key _isValidJSONObject] || ![[self objectForKey:key] _isValidJSONObject])
			return NO;

	return YES;
}

- (id) _encodeJSON:(NSMutableData*)data indent:(int)level
{
	NSUInteger j = 0;
	id key, keys = [self keyEnumerator];
	char sepa[64] = {',',0};
	char open[64] = {'{',0};
	char close[64] = {'}',0};
	char *d = ":";
	
	if (level && level < 10)
		{
		level += 1;
		memcpy(open,"{\n", 2);
		memset(open+2,' ', PP_INDENT * level);
		memcpy(close,"}\n", 2);
//		memset(close+2,' ', PP_INDENT * level);
		memcpy(sepa,",\n", 2);
		memset(sepa+2,' ', PP_INDENT * level);
		d = " : ";
		}

	[data appendBytes:open length:strlen(open)];

    while ((key = [keys nextObject]))
		{
		if (j++)
			[data appendBytes:sepa length:strlen(sepa)];
		[key _encodeJSON:data indent:level];
		[data appendBytes:d length:strlen(d)];
		[[self objectForKey:key] _encodeJSON:data indent:level];
		}

	if (level > 2)
		{
		memset(sepa, 0, 64);
		memset(sepa+1,' ', PP_INDENT * (level-1));
		sepa[0] = '\n';
		[data appendBytes:sepa length:strlen(sepa)];
		}
	[data appendBytes:close length:strlen(close)];

    return self;
}

@end

/* ****************************************************************************

	isUnicodeDataUTF8()

		00 00 00 xx  UTF-32BE		encoding detection per RFC 4627
		00 xx 00 xx  UTF-16BE
		xx 00 00 00  UTF-32LE
		xx 00 xx 00  UTF-16LE
		xx xx xx xx  UTF-8

** ***************************************************************************/

static BOOL
_isUnicodeDataUTF8(const char *bytes, unsigned int length)
{
	if (length >= 4)
		{
		unsigned short bom = (unsigned short)(bytes[0] | (bytes[1] << 8));
		unsigned int nulls;
		
		if (bom == 0xfeff || (bom == 0xfffe && length >= 6)) // skip BOM
			bytes += 2;

		nulls = (unsigned int)(bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24));
		if ( !(nulls & 0xffffff00) 							// UTF-32BE
				|| !(nulls & 0xff00ff00)					// UTF-16BE
				|| !(nulls & 0x00ffffff)					// UTF-32LE
				|| !(nulls & 0x00ff00ff) )					// UTF-16LE
			return NO;			// FIX ME discrepancy between nulls and bom ?
		}

	return YES;												// UTF-8
}

@interface NSScanner (NSPropertyList)

- (NSString *) _propertyListScanQuotedString;

- (id) _scanLeafWithOptions:(NSJSONReadingOptions)opts error:(NSError **)error;
- (id) _scanArrayWithOptions:(NSJSONReadingOptions)opt error:(NSError **)error;
- (id) _scanDictionaryWithOptions:(NSJSONReadingOptions)options
							error:(NSError **)error;
@end

@implementation NSScanner  (DeserializeJSON)

static NSCharacterSet *__numbers = nil;	// @"0123456789Ee.-+"

- (NSString *) _scanNumberString
{
	NSString *str;
	if(!__numbers)
		__numbers=[[NSCharacterSet characterSetWithCharactersInString:@"0123456789Ee.-+"] retain];
	if([self scanCharactersFromSet:__numbers intoString:&str])
		return str;	// at least one

	return nil;
}

/* ****************************************************************************

	leaf can be of any JSON type  (order scan by likelihood of each type):

	dict {}, array [], number 0123456789 true false, null, string " "

** ***************************************************************************/

- (id) _scanLeafWithOptions:(NSJSONReadingOptions)options
					  error:(NSError **)error
{
	id leaf = nil;
	long long lval = 0;
	double dval = 0;

	if ([self scanString:@"\"" intoString:NULL])		// quoted string
		{
		leaf = [self _propertyListScanQuotedString];
		}
	else if ([self scanLongLong: &lval])
		{
		leaf = [NSNumber numberWithLong: lval];
		}
	else if ([self scanDouble: &dval])
		{
		dval = floor(dval * 100000000) / 100000000; 	// limit precision to
		leaf = [NSNumber numberWithDouble: dval];		// 8 decimal places
		}
//	else if (leaf = [self _scanNumberString])
//		{
//		leaf = [NSNumber numberWithLong: [leaf intValue]];
//		}
	if([self scanString:@"{" intoString:NULL])			// dictionary
		{
		leaf = [self _scanDictionaryWithOptions:options error:error];
		}
	else if([self scanString:@"[" intoString:NULL])		// array
		{
		leaf = [self _scanArrayWithOptions:options error:error];
		}
	else if ([self scanString:@"true" intoString:NULL])
		{
		leaf = [NSNumber numberWithBool: YES];
		}
	else if ([self scanString:@"false" intoString:NULL])
		{
		leaf = [NSNumber numberWithBool: NO];
		}
	else if ([self scanString:@"null" intoString:NULL])
		{
		leaf = [NSNull null];
		}

	leaf && [self scanString:@"," intoString:NULL];		// comma at end
					// if no comma we are AT END of leaves
	return leaf;
}

- (id) _scanDictionaryWithOptions:(NSJSONReadingOptions)options
							error:(NSError **)error
{
	NSMutableDictionary *d = nil;

	while (![self isAtEnd])
		{
		if ([self scanString:@"\"" intoString:NULL])
			{
			NSString *key;
			id val;
			
			if (!(key = [self _propertyListScanQuotedString])
					|| ![self scanString:@":" intoString:NULL])
				{
				if (error)
					*error = _NSError(nil, -1, @"Invalid JSON dictionary key");
				return nil;		// invalid dictionary
				}

			if (!(val = [self _scanLeafWithOptions:options error:error]))
				{
				if (error)
					*error = _NSError(nil, -2, @"Invalid JSON dictionary leaf");
				return nil;		// invalid dictionary
				}

			if (!d)
				d = [[NSMutableDictionary new] autorelease];
			[d setObject:val forKey:key];
			}
		else if([self scanString:@"}" intoString:NULL])
			break;
		else
			{
			if (error)
				*error = _NSError(nil, -3, @"Invalid JSON dictionary");
			return nil;		// invalid dictionary
			}
		}

	if (!(options & NSJSONReadingMutableContainers) && d)
		d = [NSDictionary dictionaryWithDictionary: d];
		
	return d;
}

- (id) _scanArrayWithOptions:(NSJSONReadingOptions)options
					   error:(NSError **)error
{
	NSMutableArray *a = nil;
	id obj;

	while (![self isAtEnd])
		{						// find obj, can be dict, array, num or str.
		if ((obj = [self _scanLeafWithOptions:options error:error]))
			{
			if (!a)
				a = [[NSMutableArray new] autorelease];
			[a addObject:obj];
			}
		else if([self scanString:@"]" intoString:NULL])
			break;
		else
			{
			if (error)
				*error = _NSError(nil, -1, @"Invalid JSON array");
			return nil;			// invalid array
			}
		}

	if (!(options & NSJSONReadingMutableContainers) && a)
		a = [NSArray arrayWithArray: a];
		
	return a;
}

@end


@implementation NSJSONSerialization

+ (id) JSONObjectWithData:(NSData *)data
				  options:(NSJSONReadingOptions)options
				  error:(NSError **)error
{
	id topObject = nil;
	const char *bytes = [data bytes];
	NSUInteger length = [data length];
	NSString *s = [NSString alloc];
	NSScanner *sc;

	if (_isUnicodeDataUTF8(bytes, length))
		s = [[s initWithData:data encoding:NSUTF8StringEncoding] autorelease];
	else
		s = [[s initWithData:data encoding:NSUnicodeStringEncoding] autorelease];

	sc = [NSScanner scannerWithString: s];

	if([sc scanString:@"{" intoString:NULL])		// top-level dictionary
		{
		topObject = [sc _scanDictionaryWithOptions:options error:error];
		}
	else if([sc scanString:@"[" intoString:NULL])	// top-level array
		{
		topObject = [sc _scanArrayWithOptions:options error:error];
		}

	if (!topObject)
		[NSException raise:NSInvalidArgumentException
					 format: @"Top-level type is not JSON"];
	return topObject;
}

+ (NSData *) dataWithJSONObject:(id)object
						options:(NSJSONWritingOptions)opt
						error:(NSError **)error
{
    NSMutableData *d = nil;

	if (![object isKindOfClass:[NSDictionary class]]
			&& ![object isKindOfClass:[NSArray class]])
		{
		if (error)
			*error = _NSError(nil, -1, @"Top-level type is not JSON");

		[NSException raise:NSInvalidArgumentException
					 format: @"Top-level type is not JSON"];
		}
	else if (![object _encodeJSON:(d = [NSMutableData new]) indent:opt])
		{
		ASSIGN(d, nil);
		if (error)
			*error = _NSError(nil, -1, @"invalid JSON");
		}

	return d;
}

+ (BOOL) isValidJSONObject:(id)object
{
	return [object _isValidJSONObject];
}

@end
