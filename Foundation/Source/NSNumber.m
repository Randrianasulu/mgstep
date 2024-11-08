/*
   NSNumber.m

   Object encapsulation of numbers

   Copyright (C) 1993-2018 Free Software Foundation, Inc.

   Author:	Adam Fedor <fedor@boulder.colorado.edu>
   Date:	Mar 1995
   Rewrite:	Felipe A. Rodriguez <farz@mindspring.com>
   Date:	March 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSValue.h>
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSArchiver.h>


static NSNumber *__numberAllocator = nil;

static NSNumber *__TRUE = nil;
static NSNumber *__FALSE = nil;


@interface _NSNumber : NSNumber
{
	union {					// store most general representation of a number
    	BOOL b;
		char c;
		unsigned char uc;
		short s;
		unsigned short us;
		int i;
		unsigned int ui;
		long l;
		unsigned long ul;
		long long ll;
		unsigned long long ull;
    	float f;
    	double d;
	} data;
}
@end

@interface _FloatNumber     : _NSNumber		@end
@interface _DoubleNumber    : _NSNumber		@end
@interface _BoolNumber      : _NSNumber		@end
@interface _CharNumber      : _NSNumber		@end
@interface _UCharNumber     : _NSNumber		@end
@interface _ShortNumber     : _NSNumber		@end
@interface _UShortNumber    : _NSNumber		@end
@interface _IntNumber       : _NSNumber		@end
@interface _UIntNumber      : _NSNumber		@end
@interface _LongNumber      : _NSNumber		@end
@interface _ULongNumber     : _NSNumber		@end
@interface _LongLongNumber  : _NSNumber		@end
@interface _ULongLongNumber : _NSNumber		@end

@interface NSNumber (Private)

- (NSComparisonResult) _promotedCompare:(NSNumber*)other;

@end


@implementation _NSNumber

+ (id) alloc						  	{ return NSAllocateObject(self); }
- (void) dealloc						{ NSDeallocateObject(self); NO_WARN; }

- (BOOL) boolValue					  		 { return (data.b != 0); }
- (char) charValue					  		 { return data.c; }
- (short) shortValue						 { return data.s; }
- (int) intValue							 { return data.i; }
- (long) longValue							 { return data.l; }
- (long long) longLongValue					 { return data.ll; }
- (float) floatValue						 { return (float)data.l; }
- (double) doubleValue						 { return (double)data.ll; }
- (unsigned char) unsignedCharValue			 { return data.uc; }
- (unsigned short) unsignedShortValue		 { return data.us; }
- (unsigned int) unsignedIntValue			 { return data.ui; }
- (unsigned long) unsignedLongValue			 { return data.ul; }
- (unsigned long long) unsignedLongLongValue { return data.ull; }

- (void) getValue:(void *)value
{
    if (!value)
		[NSException raise:NSInvalidArgumentException format:@"NULL pointer"];

    memcpy(value, &data, objc_sizeof_type([self objCType]) );
}

- (void) encodeWithCoder:(NSCoder *)coder
{
	[coder encodeValueOfObjCType: [self objCType] at: &data];
}

- (id) initWithCoder:(NSCoder *)coder
{
	[coder decodeValueOfObjCType: [self objCType] at: &data];
	return self;
}

@end


@implementation NSNumber

+ (void) initialize
{
	if (!__numberAllocator && (self == [NSNumber class]))
		__numberAllocator = (NSNumber *)NSAllocateObject(self);
}

+ (id) alloc						{ return __numberAllocator; }

+ (NSValue *) value:(const void *)v withObjCType:(const char *)type
{
	switch (*type)
		{
		case _C_BOOL: return [self numberWithBool:*(BOOL *)v];
		case _C_CHR:  return [self numberWithChar:*(char *)v];
		case _C_UCHR: return [self numberWithUnsignedChar:*(unsigned char *)v];
		case _C_SHT:  return [self numberWithShort:*(short *)v];
		case _C_USHT: return [self numberWithUnsignedShort:*(unsigned short *)v];
		case _C_INT:  return [self numberWithInt:*(int *)v];
		case _C_UINT: return [self numberWithUnsignedInt:*(unsigned int *)v];
		case _C_LNG:  return [self numberWithLong:*(long *)v];
		case _C_ULNG: return [self numberWithUnsignedLong:*(unsigned long *)v];
		case _C_LNG_LNG: return [self numberWithLongLong:*(long long *)v];
		case _C_ULNG_LNG:
			return [self numberWithUnsignedLongLong:*(unsigned long long *)v];
		case _C_FLT:  return [self numberWithFloat:*(float *)v];
		case _C_DBL:  return [self numberWithDouble:*(double *)v];
		default:	  break;
		}

	[NSException raise:NSInvalidArgumentException format:@"Invalid objc type"];

    return nil;
}

+ (NSNumber *) numberWithBool:(BOOL)value
{
    return [[_BoolNumber alloc] initWithBool:value];
}

+ (NSNumber *) numberWithChar:(char)value
{
    return [[[_CharNumber alloc] initWithChar:value] autorelease];
}

+ (NSNumber *) numberWithDouble:(double)value
{
    return [[[_DoubleNumber alloc] initWithDouble:value] autorelease];
}

+ (NSNumber *) numberWithFloat:(float)value
{
    return [[[_FloatNumber alloc] initWithFloat:value]	autorelease];
}

+ (NSNumber *) numberWithInt:(int)value
{
    return [[[_IntNumber alloc] initWithInt:value] autorelease];
}

+ (NSNumber *) numberWithLong:(long)value
{
    return [[[_LongNumber alloc] initWithLong:value] autorelease];
}

+ (NSNumber *) numberWithLongLong:(long long)value
{
    return [[[_LongLongNumber alloc] initWithLongLong:value] autorelease];
}

+ (NSNumber *) numberWithShort:(short)value
{
    return [[[_ShortNumber alloc] initWithShort:value]	autorelease];
}

+ (NSNumber *) numberWithUnsignedChar:(unsigned char)value
{
    return [[[_UCharNumber alloc] initWithUnsignedChar:value] autorelease];
}

+ (NSNumber *) numberWithUnsignedInt:(unsigned int)value
{
    return [[[_UIntNumber alloc] initWithUnsignedInt:value] autorelease];
}

+ (NSNumber *) numberWithUnsignedShort:(unsigned short)value
{
	return [[[_UShortNumber alloc] initWithUnsignedShort:value] autorelease];
}

+ (NSNumber *) numberWithUnsignedLong:(unsigned long)value
{
    return [[[_ULongNumber alloc] initWithUnsignedLong:value] autorelease];
}

+ (NSNumber *) numberWithUnsignedLongLong:(unsigned long long)v
{
	return [[[_ULongLongNumber alloc] initWithUnsignedLongLong:v] autorelease];
}

- (id) initWithBool:(BOOL)value
{
    return [[_BoolNumber alloc] initWithBool:value];
}

- (id) initWithChar:(char)value
{
    return [[_CharNumber alloc] initWithChar:value];
}

- (id) initWithDouble:(double)value
{
    return [[_DoubleNumber alloc] initWithDouble:value];
}

- (id) initWithFloat:(float)value
{
    return [[_FloatNumber alloc] initWithFloat:value];
}

- (id) initWithInt:(int)value
{
    return [[_IntNumber alloc] initWithInt:value];
}

- (id) initWithLong:(long)value
{
    return [[_LongNumber alloc] initWithLong:value];
}

- (id) initWithLongLong:(long long)value
{
    return [[_LongLongNumber alloc] initWithLongLong:value];
}

- (id) initWithShort:(short)value
{
    return [[_ShortNumber alloc] initWithShort:value];
}

- (id) initWithUnsignedChar:(unsigned char)value
{
    return [[_UCharNumber alloc] initWithUnsignedChar:value];
}

- (id) initWithUnsignedInt:(unsigned int)value
{
    return [[_UIntNumber alloc] initWithUnsignedInt:value];
}

- (id) initWithUnsignedShort:(unsigned short)value
{
    return [[_UShortNumber alloc] initWithUnsignedShort:value];
}

- (id) initWithUnsignedLong:(unsigned long)value
{
    return [[_ULongNumber alloc] initWithUnsignedLong:value];
}

- (id) initWithUnsignedLongLong:(unsigned long long)value
{
    return [[_ULongLongNumber alloc] initWithUnsignedLongLong:value];
}

- (BOOL) isEqualToNumber:(NSNumber*)other
{
	return ([self compare: other] == NSOrderedSame) ? YES : NO;
}

- (BOOL) isEqual:(id)other
{
	if ([other isKindOfClass: [NSNumber class]])
		return [self isEqualToNumber: (NSNumber*)other];
	
	return [super isEqual: other];
}
							// Because of the rule that two numbers which are 
- (NSUInteger) hash			// the same according to [-isEqual:] must generate
{							// the same hash, we must generate the hash from
	union {					// the most general representation of the number.
    	double d;
    	unsigned char c[sizeof(double)];
	} val;
	NSUInteger hash = 0;
	int i;

	val.d = [self doubleValue];
	for (i = 0; i < sizeof(double); i++)
		hash += val.c[i];

	return hash;
}

- (NSString*) stringValue		{ return [self descriptionWithLocale: nil]; }
- (NSString*) description		{ return [self descriptionWithLocale: nil]; }
- (NSString*) descriptionWithLocale:(id)locale	{ return SUBCLASS }

@end


static int _conversionRank(const char *type)
{
    switch (*type)		// C Standard, subclause 6.3.1.1 [ISO/IEC 9899:2011]
		{
		case _C_BOOL:		return 0;
		case _C_UCHR:		return 1;
		case _C_CHR:		return 2;
		case _C_USHT:		return 3;
		case _C_SHT:		return 4;
		case _C_UINT:		return 5;
		case _C_INT:		return 6;
		case _C_ULNG:		return 7;
		case _C_LNG:		return 8;
		case _C_ULNG_LNG:	return 9;
		case _C_LNG_LNG:	return 10;
		case _C_FLT:		return 11;
		case _C_DBL:		return 12;
		default:			break;
		}

	return -1;			// undefined
}

static int _promotionRank(const char *type)
{
    switch (*type)
		{
		case _C_BOOL:		return 4;
		case _C_UCHR:		return 4;
		case _C_CHR:		return 4;
		case _C_USHT:		return 6;
		case _C_SHT:		return 6;
		case _C_UINT:		return 8;
		case _C_INT:		return 8;
		case _C_ULNG:		return 10;
		case _C_LNG:		return 10;
		case _C_ULNG_LNG:	return 12;
		case _C_LNG_LNG:	return 12;
		case _C_FLT:		return 12;
		case _C_DBL:		return 12;
		default:			break;
		}

	return -1;			// undefined
}

static NSComparisonResult
_compareNumbers(NSNumber *o, NSNumber *s, const char *ot, const char *st)
{
	int	k = _promotionRank(st);

    if (k <= _conversionRank(ot))
		switch([o compare: s])
			{
			case NSOrderedAscending:	return NSOrderedDescending;
			case NSOrderedDescending:	return NSOrderedAscending;
			default:					return NSOrderedSame;
			}

    if (k >= _promotionRank(ot))
		return [s _promotedCompare: o];

	switch([o _promotedCompare: s])
		{
		case NSOrderedAscending:	return NSOrderedDescending;
		case NSOrderedDescending:	return NSOrderedAscending;
		default:					return NSOrderedSame;
		}
}

static NSString *
_descriptionWithLocale(id locale, NSString *format, ...)
{
	va_list ap;
	NSString *s;

	va_start(ap, format);
	if (locale)
		s = [[NSString alloc] initWithFormat:format locale:locale arguments:ap];
	else
		s = [[NSString alloc] initWithFormat:format arguments:ap];
	va_end(ap);

	return [s autorelease];
}

/* ****************************************************************************

 		_BoolNumber

** ***************************************************************************/

@implementation _BoolNumber

+ (id) alloc
{
	if (__TRUE == nil)
		{
		__TRUE = NSAllocateObject(self);
		((_BoolNumber *)__TRUE)->data.b = YES;
		__FALSE = NSAllocateObject(self);
		}

	return __TRUE;
}

- (id) initWithBool:(BOOL)value
{
	return (value) ? __TRUE : __FALSE;
}

- (void) dealloc						{ NO_WARN; }		// duo singletons
- (const char *) objCType				{ return @encode(BOOL); }

- (NSComparisonResult) _promotedCompare:(NSNumber*)other
{
	short v0 = [self shortValue];
	short v1 = [other shortValue];

    if (v0 == v1)
		return NSOrderedSame;

	return (v0 < v1) ?  NSOrderedAscending : NSOrderedDescending;
}

- (NSComparisonResult) compare:(NSNumber *)other
{
	int	s = _conversionRank(@encode(BOOL));
	const char *ot = [other objCType];

    if (s == _conversionRank(ot) || s >= _promotionRank(ot))
		{
        BOOL a = [other boolValue];
    
        if (data.b == a)
    	    return NSOrderedSame;

		return (data.b < a) ? NSOrderedAscending : NSOrderedDescending;
		}

	return _compareNumbers(other, self, ot, @encode(BOOL));
}

- (NSString *) descriptionWithLocale:(id)locale
{
	return _descriptionWithLocale( locale, @"%d", (data.b != 0));
}

- (id) initWithCoder:(NSCoder *)coder
{
	unsigned long value;

	[coder decodeValueOfObjCType: @encode(BOOL) at: &value];

	return (value & 0x1) ? __TRUE : __FALSE;
}

@end

/* ****************************************************************************

 		_UCharNumber

** ***************************************************************************/

@implementation _UCharNumber

- (id) initWithUnsignedChar:(unsigned char)value
{
	data.ul = value;

    return self;
}

- (const char *) objCType				{ return @encode(unsigned char); }

- (NSComparisonResult) _promotedCompare:(NSNumber*)other
{
	short v0 = [self shortValue];
	short v1 = [other shortValue];

    if (v0 == v1)
		return NSOrderedSame;

	return (v0 < v1) ?  NSOrderedAscending : NSOrderedDescending;
}

- (NSComparisonResult) compare:(NSNumber *)other
{
	int	s = _conversionRank(@encode(unsigned char));
	const char *ot = [other objCType];

    if (s == _conversionRank(ot) || s >= _promotionRank(ot))
		{
        unsigned char a = [other unsignedCharValue];
    
        if (data.uc == a)
    	    return NSOrderedSame;

		return (data.uc < a) ? NSOrderedAscending : NSOrderedDescending;
		}

	return _compareNumbers(other, self, ot, @encode(unsigned char));
}

- (NSString *) descriptionWithLocale:(id)locale
{
    return _descriptionWithLocale( locale, @"%uc", (unsigned char)data.uc);
}

@end

/* ****************************************************************************

 		_CharNumber

** ***************************************************************************/

@implementation _CharNumber

- (id) initWithChar:(char)value
{
	data.l = value;

    return self;
}

- (const char *) objCType				{ return @encode(char); }

- (NSComparisonResult) _promotedCompare:(NSNumber*)other
{
	short v0 = [self shortValue];
	short v1 = [other shortValue];

    if (v0 == v1)
		return NSOrderedSame;

	return (v0 < v1) ?  NSOrderedAscending : NSOrderedDescending;
}

- (NSComparisonResult) compare:(NSNumber *)other
{
	int	s = _conversionRank(@encode(char));
	const char *ot = [other objCType];

    if (s == _conversionRank(ot) || s >= _promotionRank(ot))
		{
        char a = [other charValue];
    
        if (data.c == a)
    	    return NSOrderedSame;

		return (data.c < a) ? NSOrderedAscending : NSOrderedDescending;
		}

	return _compareNumbers(other, self, ot, @encode(char));
}

- (NSString *) descriptionWithLocale:(id)locale
{
    return _descriptionWithLocale( locale, @"%c", data.c);
}

@end

/* ****************************************************************************

 		_UShortNumber

** ***************************************************************************/

@implementation _UShortNumber

- (id) initWithUnsignedShort:(unsigned short)value
{
	data.ul = value;

    return self;
}

- (const char *) objCType				{ return @encode(unsigned short); }

- (NSComparisonResult) _promotedCompare:(NSNumber*)other
{
	int	v0 = [self intValue];
	int	v1 = [other intValue];

    if (v0 == v1)
		return NSOrderedSame;

	return (v0 < v1) ?  NSOrderedAscending : NSOrderedDescending;
}

- (NSComparisonResult) compare:(NSNumber *)other
{
	int	s = _conversionRank(@encode(unsigned short));
	const char *ot = [other objCType];

    if (s == _conversionRank(ot) || s >= _promotionRank(ot))
		{
        unsigned short a = [other unsignedShortValue];
    
        if (data.us == a)
    	    return NSOrderedSame;

		return (data.us < a) ? NSOrderedAscending : NSOrderedDescending;
		}

	return _compareNumbers(other, self, ot, @encode(unsigned short));
}

- (NSString *) descriptionWithLocale:(id)locale
{
    return _descriptionWithLocale( locale, @"%hu", data.us);
}

@end

/* ****************************************************************************

 		_ShortNumber

** ***************************************************************************/

@implementation _ShortNumber

- (id) initWithShort:(short)value
{
	data.l = value;

    return self;
}

- (const char *) objCType				{ return @encode(short); }

- (NSComparisonResult) _promotedCompare:(NSNumber*)other
{
	int	v0 = [self intValue];
	int	v1 = [other intValue];

    if (v0 == v1)
		return NSOrderedSame;

	return (v0 < v1) ?  NSOrderedAscending : NSOrderedDescending;
}

- (NSComparisonResult) compare:(NSNumber *)other
{
	int	s = _conversionRank(@encode(short));
	const char *ot = [other objCType];

    if (s == _conversionRank(ot) || s >= _promotionRank(ot))
		{
        short a = [other shortValue];
    
        if (data.s == a)
    	    return NSOrderedSame;

		return (data.s < a) ? NSOrderedAscending : NSOrderedDescending;
		}

	return _compareNumbers(other, self, ot, @encode(short));
}

- (NSString *) descriptionWithLocale:(id)locale
{
    return _descriptionWithLocale( locale, @"%hd", data.s);
}

@end

/* ****************************************************************************

 		_UIntNumber

** ***************************************************************************/

@implementation _UIntNumber

- (id) initWithUnsignedInt:(unsigned int)value
{
	data.ul = value;					// free room upgrade

    return self;
}

- (const char *) objCType				{ return @encode(unsigned int); }

- (NSComparisonResult) _promotedCompare:(NSNumber*)other
{
	long v0 = [self longValue];
	long v1 = [other longValue];

    if (v0 == v1)
		return NSOrderedSame;

	return (v0 < v1) ?  NSOrderedAscending : NSOrderedDescending;
}

- (NSComparisonResult) compare:(NSNumber *)other
{
	int	s = _conversionRank(@encode(unsigned int));
	const char *ot = [other objCType];

    if (s == _conversionRank(ot) || s >= _promotionRank(ot))
		{
        unsigned int a = [other unsignedIntValue];
    
        if (data.ui == a)
    	    return NSOrderedSame;

		return (data.ui < a) ? NSOrderedAscending : NSOrderedDescending;
		}

	return _compareNumbers(other, self, ot, @encode(unsigned int));
}

- (NSString *) descriptionWithLocale:(id)locale
{
    return _descriptionWithLocale( locale, @"%u", data.ui);
}

@end

/* ****************************************************************************

 		_IntNumber

** ***************************************************************************/

@implementation _IntNumber

- (id) initWithInt:(int)value
{
	data.l = value;						// free room upgrade

    return self;
}

- (const char *) objCType				{ return @encode(int); }

- (NSComparisonResult) _promotedCompare:(NSNumber*)other
{
	long v0 = [self longValue];
	long v1 = [other longValue];

    if (v0 == v1)
		return NSOrderedSame;

	return (v0 < v1) ?  NSOrderedAscending : NSOrderedDescending;
}

- (NSComparisonResult) compare:(NSNumber *)other
{
	int	s = _conversionRank(@encode(int));
	const char *ot = [other objCType];

    if (s == _conversionRank(ot) || s >= _promotionRank(ot))
		{
        int a = [other intValue];
    
        if (data.i == a)
    	    return NSOrderedSame;

		return (data.i < a) ? NSOrderedAscending : NSOrderedDescending;
		}

	return _compareNumbers(other, self, ot, @encode(int));
}

- (NSString *) descriptionWithLocale:(id)locale
{
	return _descriptionWithLocale( locale, @"%d", data.i);
}

@end

/* ****************************************************************************

 		_ULongNumber

** ***************************************************************************/

@implementation _ULongNumber

- (id) initWithUnsignedLong:(unsigned long)value
{
	data.ul = value;

    return self;
}

- (const char *) objCType				{ return @encode(unsigned long); }

- (NSComparisonResult) _promotedCompare:(NSNumber*)other
{
	long long v0 = [self longLongValue];
	long long v1 = [other longLongValue];

    if (v0 == v1)
		return NSOrderedSame;

	return (v0 < v1) ?  NSOrderedAscending : NSOrderedDescending;
}

- (NSComparisonResult) compare:(NSNumber *)other
{
	int	s = _conversionRank(@encode(unsigned long));
	const char *ot = [other objCType];

    if (s == _conversionRank(ot) || s >= _promotionRank(ot))
		{
        unsigned long a = [other unsignedLongValue];
    
        if (data.ul == a)
    	    return NSOrderedSame;

		return (data.ul < a) ? NSOrderedAscending : NSOrderedDescending;
		}

	return _compareNumbers(other, self, ot, @encode(unsigned long));
}

- (NSString *) descriptionWithLocale:(id)locale
{
    return _descriptionWithLocale( locale, @"%lu", data.ul);
}

@end

/* ****************************************************************************

 		_LongNumber

** ***************************************************************************/

@implementation _LongNumber

- (id) initWithLong:(long)value
{
	data.l = value;

    return self;
}

- (const char *) objCType				{ return @encode(long); }

- (NSComparisonResult) _promotedCompare:(NSNumber*)other
{
	long long v0 = [self longLongValue];
	long long v1 = [other longLongValue];

    if (v0 == v1)
		return NSOrderedSame;

	return (v0 < v1) ?  NSOrderedAscending : NSOrderedDescending;
}

- (NSComparisonResult) compare:(NSNumber *)other
{
	int	s = _conversionRank(@encode(long));
	const char *ot = [other objCType];

    if (s == _conversionRank(ot) || s >= _promotionRank(ot))
		{
        long a = [other longValue];
    
        if (data.l == a)
    	    return NSOrderedSame;

		return (data.l < a) ? NSOrderedAscending : NSOrderedDescending;
		}

	return _compareNumbers(other, self, ot, @encode(long));
}

- (NSString *) descriptionWithLocale:(id)locale
{
    return _descriptionWithLocale( locale, @"%ld", data.l);
}

@end

/* ****************************************************************************

 		_ULongLongNumber

** ***************************************************************************/

@implementation _ULongLongNumber

- (id) initWithUnsignedLongLong:(unsigned long long)value
{
	data.ull = value;

    return self;
}

- (const char *) objCType				{ return @encode(unsigned long long); }

- (NSComparisonResult) _promotedCompare:(NSNumber*)other
{
	double v0 = [self doubleValue];
	double v1 = [other doubleValue];

    if (v0 == v1)
		return NSOrderedSame;

	return (v0 < v1) ?  NSOrderedAscending : NSOrderedDescending;
}

- (NSComparisonResult) compare:(NSNumber *)other
{
	int	s = _conversionRank(@encode(unsigned long long));
	const char *ot = [other objCType];

    if (s == _conversionRank(ot) || s >= _promotionRank(ot))
		{
        unsigned long long a = [other unsignedLongLongValue];
    
        if (data.ull == a)
    	    return NSOrderedSame;

		return (data.ull < a) ? NSOrderedAscending : NSOrderedDescending;
		}

	return _compareNumbers(other, self, ot, @encode(unsigned long long));
}

- (NSString *) descriptionWithLocale:(id)locale
{
	return _descriptionWithLocale( locale, @"%llu", data.ull);
}

@end

/* ****************************************************************************

 		_LongLongNumber

** ***************************************************************************/

@implementation _LongLongNumber

- (id) initWithLongLong:(long long)value
{
	data.ll = value;

    return self;
}

- (const char *) objCType				{ return @encode(long long); }

- (NSComparisonResult) _promotedCompare:(NSNumber*)other
{
	double v0 = [self doubleValue];
	double v1 = [other doubleValue];

    if (v0 == v1)
		return NSOrderedSame;

	return (v0 < v1) ?  NSOrderedAscending : NSOrderedDescending;
}

- (NSComparisonResult) compare:(NSNumber *)other
{
	int	s = _conversionRank(@encode(long long));
	const char *ot = [other objCType];

    if (s == _conversionRank(ot) || s >= _promotionRank(ot))
		{
        long long a = [other longLongValue];
    
        if (data.ll == a)
    	    return NSOrderedSame;

		return (data.ll < a) ? NSOrderedAscending : NSOrderedDescending;
		}

	return _compareNumbers(other, self, ot, @encode(long long));
}

- (NSString *) descriptionWithLocale:(id)locale
{
	return _descriptionWithLocale( locale, @"%lld", data.ll);
}

@end

/* ****************************************************************************

 		_FloatNumber

** ***************************************************************************/

@implementation _FloatNumber

- (id) initWithFloat:(float)value
{
	data.f = value;

    return self;
}

- (const char *) objCType				{ return @encode(float); }

- (BOOL) boolValue					    { return (data.f != 0); }
- (char) charValue					  	{ return (char)data.f; }
- (short) shortValue				  	{ return (short)data.f; }
- (int) intValue					  	{ return (int)data.f; }
- (long) longValue					  	{ return (long)data.f; }
- (long long) longLongValue			  	{ return (long long)data.f; }
- (unsigned char) unsignedCharValue		{ return (unsigned char)data.f; }
- (unsigned short) unsignedShortValue	{ return (unsigned short)data.f; }
- (unsigned int) unsignedIntValue		{ return (unsigned int)data.f; }
- (unsigned long) unsignedLongValue		{ return (unsigned long)data.f; }
- (unsigned long long) unsignedLongLongValue
									  	{ return (unsigned long long)data.f; }
- (float) floatValue					{ return data.f; }
- (double) doubleValue					{ return (double)data.f; }

- (NSComparisonResult) _promotedCompare:(NSNumber*)other
{
	double v0 = [self doubleValue];
	double v1 = [other doubleValue];

    if (v0 == v1)
		return NSOrderedSame;

	return (v0 < v1) ?  NSOrderedAscending : NSOrderedDescending;
}

- (NSComparisonResult) compare:(NSNumber *)other
{
	int	s = _conversionRank(@encode(float));
	const char *ot = [other objCType];

    if (s == _conversionRank(ot) || s >= _promotionRank(ot))
		{
        float a = [other floatValue];
    
        if (data.f == a)
    	    return NSOrderedSame;

		return (data.f < a) ? NSOrderedAscending : NSOrderedDescending;
		}

	return _compareNumbers(other, self, ot, @encode(float));
}

- (NSString *) descriptionWithLocale:(id)locale
{
    return _descriptionWithLocale( locale, @"%f", data.f);
}

@end

/* ****************************************************************************

 		_DoubleNumber

** ***************************************************************************/

@implementation _DoubleNumber

- (id) initWithDouble:(double)value
{
	data.d = value;

    return self;
}

- (const char *) objCType				{ return @encode(double); }

- (BOOL) boolValue					    { return (data.d != 0); }
- (char) charValue					  	{ return (char)data.d; }
- (short) shortValue				  	{ return (short)data.d; }
- (int) intValue					  	{ return (int)data.d; }
- (long) longValue					  	{ return (long)data.d; }
- (long long) longLongValue			  	{ return (long long)data.d; }
- (unsigned char) unsignedCharValue		{ return (unsigned char)data.d; }
- (unsigned short) unsignedShortValue	{ return (unsigned short)data.d; }
- (unsigned int) unsignedIntValue		{ return (unsigned int)data.d; }
- (unsigned long) unsignedLongValue		{ return (unsigned long)data.d; }
- (unsigned long long) unsignedLongLongValue
									  	{ return (unsigned long long)data.d; }
- (float) floatValue					{ return (float)data.d; }
- (double) doubleValue					{ return data.d; }

- (NSComparisonResult) _promotedCompare:(NSNumber*)other
{
	double v0 = [self doubleValue];
	double v1 = [other doubleValue];

    if (v0 == v1)
		return NSOrderedSame;

	return (v0 < v1) ?  NSOrderedAscending : NSOrderedDescending;
}

- (NSComparisonResult) compare:(NSNumber *)other
{
	int	s = _conversionRank(@encode(double));
	const char *ot = [other objCType];

    if (s == _conversionRank(ot) || s >= _promotionRank(ot))
		{
        double a = [other doubleValue];
    
        if (data.d == a)
    	    return NSOrderedSame;

		return (data.d < a) ? NSOrderedAscending : NSOrderedDescending;
		}

	return _compareNumbers(other, self, ot, @encode(double));
}

- (NSString *) descriptionWithLocale:(id)locale
{
    return _descriptionWithLocale( locale, @"%g", data.d);
}

@end

/* ****************************************************************************

		NSValue

** ***************************************************************************/

@interface _NSValue : NSValue
{
	union {
		id o;
		void *ptr;
		NSPoint p;
		NSSize s;
		NSRect r;
	} data;
}
@end

@interface _NonretainedObjectValue 	: _NSValue		@end
@interface _PointerValue			: _NSValue		@end
@interface _PointValue				: _NSValue		@end
@interface _RectValue				: _NSValue		@end
@interface _SizeValue				: _NSValue		@end


@implementation _NSValue

- (void) getValue:(void *)value
{
    if (!value)
		[NSException raise:NSInvalidArgumentException format:@"NULL pointer"];

    memcpy(value, &data, objc_sizeof_type([self objCType]) );
}

- (void) encodeWithCoder:(NSCoder *)coder
{
	[coder encodeValueOfObjCType: [self objCType] at: &data];
}

- (id) initWithCoder:(NSCoder *)coder
{
	[coder decodeValueOfObjCType: [self objCType] at: &data];
	return self;
}

@end


@implementation NSValue

+ (NSValue *) value:(const void *)value withObjCType:(const char *)type
{										
	if (!value || !type)
		return _NSLogError(@"Can't create NSValue with NULL value or type");

	if (strcmp(@encode(id), type) == 0)
    	return [self valueWithNonretainedObject:(id)value];
	if (strcmp(@encode(NSPoint), type) == 0)
		return [self valueWithPoint: *(NSPoint *)value];
	if (strcmp(@encode(void *), type) == 0)
    	return [self valueWithPointer:value];
	if (strcmp(@encode(NSRect), type) == 0)
    	return [self valueWithRect: *(NSRect *)value];
	if (strcmp(@encode(NSSize), type) == 0)
		return [self valueWithSize: *(NSSize *)value];
    
    return [NSNumber value:value withObjCType:type];
}
		
+ (NSValue *) valueWithBytes:(const void *)value objCType:(const char *)type
{										
    return [self value:value withObjCType:type];
}

+ (NSValue *) valueWithNonretainedObject:(id)anObject
{
	_NonretainedObjectValue *v = [_NonretainedObjectValue alloc];

    return [[v initWithBytes:&anObject objCType:@encode(id)] autorelease];
}
	
+ (NSValue *) valueWithPoint:(NSPoint)point
{
	_PointValue *v = [_PointValue alloc];

    return [[v initWithBytes:&point objCType:@encode(NSPoint)] autorelease];
}
 
+ (NSValue *) valueWithPointer:(const void *)pointer
{
	_PointerValue *v = [_PointerValue alloc];

    return [[v initWithBytes:&pointer objCType:@encode(void *)] autorelease];
}

+ (NSValue *) valueWithRect:(NSRect)rect
{
	_RectValue *v = [_RectValue alloc];

    return [[v initWithBytes:&rect objCType:@encode(NSRect)] autorelease];
}

+ (NSValue *) valueWithSize:(NSSize)size
{
	_SizeValue *v = [_SizeValue alloc];

    return [[v initWithBytes:&size objCType:@encode(NSSize)] autorelease];
}

- (BOOL) isEqual:(id)other
{
    if ([other isKindOfClass: [self class]])
		return [self isEqualToValue: other];

    return NO;
}

- (id) copy									{ return [self retain]; }
- (const char *) objCType					{ SUBCLASS return NULL;}
- (void) getValue:(void *)value				{ SUBCLASS; }
- (id) initWithCoder:(NSCoder *)coder		{ SUBCLASS return nil;}
- (void) encodeWithCoder:(NSCoder *)coder	{ [super encodeWithCoder:coder]; }

@end /* NSValue */


@implementation _PointerValue

- (id) initWithBytes:(const void *)value objCType:(const char *)type
{
    memcpy(&data, value, objc_sizeof_type(type));

	return self;
}

- (BOOL) isEqualToValue:(NSValue*)v
{
    if ([v isKindOfClass: [self class]])
		return (data.ptr == [v pointerValue]) ? YES : NO;

    return NO;
}

- (void *) pointerValue						{ return data.ptr; }
- (const char *) objCType					{ return @encode(void *); }

- (NSString *) description
{
	return [NSString stringWithFormat: @"{pointer = %p;}", data.ptr];
}

@end /* _PointerValue */


@implementation _NonretainedObjectValue

- (id) initWithBytes:(const void *)value objCType:(const char *)type
{
    memcpy(&data, value, objc_sizeof_type(type));

	return self;
}

- (BOOL) isEqualToValue:(NSValue*)v
{
    if ([v isKindOfClass: [self class]])
		return [data.o isEqual: [v nonretainedObjectValue]];

    return NO;
}

- (id) nonretainedObjectValue				{ return data.o; }
- (const char *) objCType					{ return @encode(id); }

- (NSString *) description
{
	return [NSString stringWithFormat: @"{object = %@;}", [data.o description]];
}

@end /* _NonretainedObjectValue */


@implementation _PointValue

- (id) initWithBytes:(const void *)value objCType:(const char *)type
{
    memcpy(&data, value, objc_sizeof_type(type));

	return self;
}

- (BOOL) isEqualToValue:(NSValue*)v
{
    if ([v isKindOfClass: [self class]])
		return NSEqualPoints(data.p, [v pointValue]);

    return NO;
}

- (NSPoint) pointValue						{ return data.p; }
- (const char *) objCType					{ return @encode(NSPoint); }
- (NSString *) description					{ return NSStringFromPoint(data.p); }

@end /* _PointValue */


@implementation _RectValue

- (id) initWithBytes:(const void *)value objCType:(const char *)type
{
    memcpy(&data, value, objc_sizeof_type(type));

	return self;
}

- (BOOL) isEqualToValue:(NSValue*)v
{
    if ([v isKindOfClass: [self class]])
		return NSEqualRects(data.r, [v rectValue]);

    return NO;
}

- (NSRect) rectValue						{ return data.r; }
- (const char *) objCType					{ return @encode(NSRect); }
- (NSString *) description					{ return NSStringFromRect(data.r); }

@end /* _RectValue */


@implementation _SizeValue

- (id) initWithBytes:(const void *)value objCType:(const char *)type
{
    memcpy(&data, value, objc_sizeof_type(type));

	return self;
}

- (BOOL) isEqualToValue:(NSValue*)v
{
    if ([v isKindOfClass: [self class]])
		return NSEqualSizes(data.s, [v sizeValue]);

    return NO;
}

- (NSSize) sizeValue						{ return data.s; }
- (const char *) objCType					{ return @encode(NSSize); }
- (NSString *) description					{ return NSStringFromSize(data.s); }

@end /* _SizeValue */
