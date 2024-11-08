/*
   NSLocale.m

   Cultural conventions class  (formats, currency, keyboard, ...)

   Copyright (C) 2016-2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	May 2016

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSLocale.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSFormatter.h>
#include <Foundation/NSArray.h>

#include <math.h>

#define FMT_OBJ(x)		[[lc->_overrides objectForKey:(x)] cString]


typedef struct  { @defs(NSLocale); } CFLocale;

struct _localeItem {  NSString *identifier;
					  NSString *currencyCode;
					  NSString *currencySymbol;
					  NSString *decimalSeparatorl;
					  NSString *groupingSeparator;
					  NSString *quoteBegin;
					  NSString *quoteEnd; };

static struct _localeItem __ltable[] = \
		{{ @"en_US", @"USD", @"$",   @".", @",", @"“",  @"”" },
		 { @"en_UK", @"GBP", @"£",   @".", @",", @"“",  @"”" },
		 { @"en_AU", @"AUD", @"$",   @".", @",", @"“",  @"”" },
		 { @"de_CH", @"CHF", @"CHF", @".", @"'", @"«",  @"»" },
		 { @"de_DE", @"EUR", @"€",   @",", @".", @"„",  @"“" },
		 { @"es_AR", @"ARS", @"$",   @",", @".", @"“",  @"”" },
		 { @"es_ES", @"EUR", @"€",   @",", @".", @"“",  @"”" },
		 { @"fr_FR", @"EUR", @"€",   @",", @" ", @"«",  @"»" },
		 { @"it_IT", @"EUR", @"€",   @",", @".", @"«",  @"»" },
		 { @"ja_JP", @"JPY", @"¥",   @".", @",", @"“",  @"”" },
		 { @"ko_KR", @"KRW", @"₩",   @".", @",", @"“",  @"”" },
		 { @"nl_NL", @"EUR", @"€",   @",", @".", @"“",  @"”" },
		 { @"pt_BR", @"BRL", @"R$",  @",", @".", @"“",  @"”" },
		 { @"pt_PT", @"EUR", @"€",   @",", @" ", @"«",  @"»" }};

#define LOCALE_TABLE_SIZE  (sizeof(__ltable) / sizeof(struct _localeItem))


NSString * const NSLocaleIdentifier = @"NSLocaleIdentifier";
NSString * const NSLocaleCountryCode = @"NSLocaleCountryCode";
NSString * const NSLocaleLanguageCode = @"NSLocaleLanguageCode";
NSString * const NSLocaleCurrencyCode = @"NS.currencyCode";
NSString * const NSLocaleCurrencySymbol = @"NS.currencySymbol";
NSString * const NSLocaleDecimalSeparator = @"NS.decimalSeparator";
NSString * const NSLocaleGroupingSeparator = @"NS.groupingSeparator";
NSString * const NSLocaleQuotationEndDelimiterKey = @"NSLocaleQuotationEndDelimiterKey";
NSString * const NSLocaleQuotationBeginDelimiterKey = @"NSLocaleQuotationBeginDelimiterKey";

static NSLocale *__currentLocale = nil;



@implementation NSLocale

+ (id) localeWithLocaleIdentifier:(NSString *)string
{
	return [[[self alloc] initWithLocaleIdentifier: string] autorelease];
}

+ (id) systemLocale							{ return [self currentLocale]; }

+ (id) currentLocale
{
	return (__currentLocale) ? __currentLocale
							 : [[NSLocale alloc] initWithLocaleIdentifier:nil];
}

+ (NSDictionary *) componentsFromLocaleIdentifier:(NSString *)s
{
	NSString *lg = [s substringWithRange: (NSRange){0,2}];
	NSString *cy = [s substringWithRange: (NSRange){3,2}];
	NSDictionary *d = nil;
	int i;

	for (i = 0; i < LOCALE_TABLE_SIZE; i++)
		if ([s isEqualToString: __ltable[i].identifier])
			{
			d = [[NSDictionary alloc] initWithObjectsAndKeys: \
					lg,								NSLocaleLanguageCode,
					__ltable[i].currencySymbol,		NSLocaleCurrencySymbol,
					__ltable[i].currencyCode, 		NSLocaleCurrencyCode,
					__ltable[i].decimalSeparatorl, 	NSLocaleDecimalSeparator,
					__ltable[i].groupingSeparator, 	NSLocaleGroupingSeparator,
					__ltable[i].quoteBegin,	NSLocaleQuotationBeginDelimiterKey,
					__ltable[i].quoteEnd, 	NSLocaleQuotationEndDelimiterKey,
					cy, 					NSLocaleCountryCode, nil];
			break;
			}

	if (d == nil)
		d = [[NSDictionary alloc] initWithObjectsAndKeys:
					lg, NSLocaleLanguageCode, cy, NSLocaleCountryCode,nil];

	return [d autorelease];
}

+ (NSArray *) availableLocaleIdentifiers;
{
	id identifiers[LOCALE_TABLE_SIZE];
	int i;

	for (i = 0; i < LOCALE_TABLE_SIZE; i++)
		identifiers[i] = __ltable[i].identifier;

	return [NSArray arrayWithObjects:identifiers count:LOCALE_TABLE_SIZE];
}

- (id) initWithLocaleIdentifier:(NSString *)string
{
	_identifier = (string) ? [string retain] : @"en_US";
	_cache = [[NSLocale componentsFromLocaleIdentifier: _identifier] retain];

	if (!__currentLocale)
		__currentLocale = self;

	return self;
}

- (void) dealloc
{
	[_cache release],		_cache = nil;
	[_overrides release],	_overrides = nil;
	[_identifier release],	_identifier = nil;

	[super dealloc];
}

static NSString *
_ObjectForKey( CFLocale *lc, id key)		// needed for stack allocd CFLocale
{
	id obj = (lc->_overrides) ? [lc->_overrides objectForKey: key] : nil;

	return (obj) ? obj : [lc->_cache objectForKey: key];
}

- (id) objectForKey:(id)key
{
	return _ObjectForKey((CFLocale *)self, key);
}

- (NSString *) displayNameForKey:(id)key value:(id)value
{
	return nil;	// e.g. en_US emits "French (France)" w/key NSLocaleIdentifier
}

- (NSString *) description					{ return [_cache description]; }
- (NSString *) localeIdentifier				{ return _identifier; }

- (id) copy									{ return self; }

- (id) initWithCoder:(NSCoder*)aDecoder		{ return self; }
- (void) encodeWithCoder:(NSCoder*)aCoder	{}

@end

/* ****************************************************************************

	Locale Format

** ***************************************************************************/

static const char *
FormatSuffix(const char *fmt, BOOL negative, CFLocale *lc)
{
	NSString *key = (negative) ? @"NS.negativeSuffix" : @"NS.positiveSuffix";
	const char *sf = [[lc->_overrides objectForKey:key] cString];
	const char *fp;

	if (!sf)
		{
		for (fp = fmt + strlen(fmt); fp > fmt; fp--)
			if (*fp == '#' || *fp == '0' || *fp == '@' || *fp == '.')
				break;
		sf = ++fp;
		}

	return sf;
}

static const char *
GroupSeparator(const char *fmt)
{
	for (; *fmt != '\0' && *fmt != ';'; fmt++)
		if (*fmt == ',')
			return fmt;

	return NULL;	// FIX ME || _ObjectForKey(lc, @"NS.hasThousandSeparators")
}

static unsigned int
AddMinusSign(char *str, CFLocale *lc)
{
	const char *w = (w = FMT_OBJ(@"NS.minusSign")) ? w : "-";
	unsigned int l = MIN(strlen(w), 80);
		
	strncpy(str, w, l);

	return l;
}

static unsigned int
AddCurrencySymbol(char *str, CFLocale *lc)
{
	const char *w = [_ObjectForKey(lc, NSLocaleCurrencySymbol) cString];
	unsigned int l = MIN(strlen(w), 80);
		
	strncpy(str, w, l);

	return l;
}

static unsigned int
AddPrefix(char *p, const char *pf, BOOL noPrefix, BOOL neg, CFLocale *lc)
{
	int j, m = 0;
	
	for (j = 0; *(pf+j) != '\0'; j++)					// apply prefix
		{
		if (*(pf+j) == '\302' && *(pf+j+1) == '\244')	// ¤
			{
			if (neg && *(pf+2) == '#' || *(pf+2) == '0' || *(pf+2) == '@')
				m += AddMinusSign(p+m, lc);
			m += AddCurrencySymbol(p+m, lc);
			j++;
			}
		else if (noPrefix && (*(pf+j) == '#' || *(pf+j) == '0' || *(pf+j) == '@'))
			break;
		else
			*(p+m++) = *(pf+j);
		}

	return m;
}

static void PrintOverrides(CFLocale *lc)
{
	NSUInteger i, count = [lc->_overrides count];
	id keys[count];
	id objs[count];
	
	[lc->_overrides getObjects:objs andKeys:keys];
//	printf("Dict w/objs,keys %s\n", [[lc->_overrides description] cString]);
	for (i = 0; i < count; i++)
		printf("KEY %s  VALUE %s\n", [keys[i] cString], [objs[i] cString]);
}

static void
FormatLong(char *p, long x, CFLocale *lc)
{
	NSString *key = (x < 0) ? @"NS.negativePrefix" : @"NS.positivePrefix";
	const char *pf = [[lc->_overrides objectForKey:key] cString];
	const char *f = [[lc->_overrides objectForKey:@"NS.format"] cString];
	const char *nf = NULL;
	const char *sf;
	const char *gp = NULL;
	int i, k, m = 0, t = 0;
	unsigned long n, z = 0;
	unsigned long p10 = 0;
	BOOL noPrefix = !(pf);

	if (!f)
		f = "0";
	else if (GroupSeparator(f))
		gp = [_ObjectForKey(lc, @"NS.groupingSeparator") cString];
	if (x < 0)
		{
		if (!pf && (nf = FMT_OBJ(@"NS.negativeFormat")))
			pf = nf;
		else
			nf = (nf = strstr(f, ";0;")) ? nf + 3 : f;
		}
	if (!pf)
		pf = f;
	sf = FormatSuffix(f, (x < 0), lc);
													// apply prefix
	m = AddPrefix(p, pf, noPrefix, (x < 0), lc);

	if ((x < 0) && m == 0 && (*f == '#' || *f == '0' || *f == '@'))
		m = AddMinusSign(p, lc);					// negative w/o a prefix

	if (x < 0)
		x = abs(x);
	n = x;

	for (i = 0; n > 0; i++)							// count digits
		n /= 10;

	if (x == 0)
		strcpy(p, "0"), k = m + 1;
	else
		for (k = m, i--; i >= 0 ; k++, t++)
			{
			if ( gp && t > 0 && !((i+1) % 3))
				*(p+k++) = *gp;
			p10 = (p10 == 0) ? pow(10, i) : p10 / 10;
			n = (int)(x / p10) - z;
			*(p+k) = '0' + n;
			z = z * 10;
			z += n * 10;
			i--;
			}
													// apply suffix
	for (; sf && (sf < sf + strlen(sf)); sf++, k++)
		*(p+k) = *sf;

	*(p+k) = '\0';									// Null terminate string
}

static void
FormatFloat(char *p, double x, CFLocale *lc)
{
	NSString *key = (x < 0) ? @"NS.negativePrefix" : @"NS.positivePrefix";
	const char *pf = [[lc->_overrides objectForKey:key] cString];
	const char *f = [[lc->_overrides objectForKey:@"NS.format"] cString];
	const char *nf = NULL;
	const char *sf;
	const char *rp = NULL;
	const char *gp = NULL;
	int n, i, k, m = 0, t = 0, z = 0;
	BOOL noPrefix = !(pf);

	if (!f)
		f = "###0.##";
	else if (GroupSeparator(f))
		gp = [_ObjectForKey(lc, @"NS.groupingSeparator") cString];
	if (x < 0)
		{
		if (!pf && (nf = FMT_OBJ(@"NS.negativeFormat")))
			pf = nf;
		else
			nf = (nf = strstr(f, ";0;")) ? nf + 3 : f;
		}
	if (!pf)
		pf = f;
	sf = FormatSuffix(f, (x < 0), lc);

	m = AddPrefix(p, pf, noPrefix, (x < 0), lc);	// apply prefix

	if ((x < 0) && m == 0 && (*f == '#' || *f == '0' || *f == '@'))
		m = AddMinusSign(p, lc);					// negative w/o a prefix

	if (x < 0)
		x = fabs(x);
	n = (int)x;

	for (i = 0; n > 0; i++)					// count digits to decimal point
		{
		x /= 10;
		n = (int)x;
		}

	x *= 10;
	n = (int)x;
	x = x-n;

	if (n == 0)
		strcpy(p, "0.00"), k = m + 4;
	else
	for (k = m; (n > 0); k++, t++)
		{
		if ( !rp && k == i + m + z)
			{
			if ((rp = strchr(f, '.')))
				{
				*(p+k) = *[_ObjectForKey(lc, @"NS.decimalSeparator") cString];
				for (rp++; (*rp == '#' || *rp == '0' || *rp == '@'); z++, rp++);
				}
			else
				break;
			}
		else if ( gp && t > 0 && t < i && !((i - t) % 3))
			{
			*(p+k) = *gp;
			z++;
			}
		else if ( k > i + m + z)
			break;
		else
			{
			*(p+k) = '0' + n;
			x *= 10;
			n = (int)x;
			x = x-n;
			}
		}
													// apply suffix
	for (; sf && (sf < sf + strlen(sf)); sf++, k++)
		*(p+k) = *sf;

	*(p+k) = '\0';									// Null terminate string
}

static int
_mformat(char *str, size_t len, id locale, const char *fmt, va_list ap)
{
	char *start = str;
	char *fmt_p; 						// Position within format

	while ((fmt_p = strchr(fmt, '%')))
		{
		char *spec_pos; 				// Position of conversion specifier
		long argvl;
		double argf;

		if (fmt_p > fmt + 1)			// copy chars in between fmt specifiers
			{
			strncpy(str, fmt, fmt_p - fmt);
			str += (fmt_p - fmt);
			}
		if (*(fmt_p+1) == '%')
			{
			fmt = fmt_p+2;
			continue;
			}
										// Format specifiers K&R C 2nd ed.
		spec_pos = strpbrk(fmt_p+1, "dioxXucsfeEgGpn\0");
		switch (*spec_pos)
			{
			case 'd': case 'i': case 'o':
			case 'x': case 'X': case 'u': case 'c':
				argvl = va_arg(ap, long);
				FormatLong(str, argvl, (CFLocale *)locale);
				break;
			case 's':
				if (*(spec_pos - 1) == '*')
					va_arg(ap, int*);
				va_arg(ap, char*);				// FIX ME localize strings
				break;
			case 'f': case 'e': case 'E': case 'g': case 'G':
				argf = va_arg(ap, double);
				FormatFloat(str, argf, (CFLocale *)locale);
				break;
			case 'p':
				va_arg(ap, void*);
				break;
			case 'n':
				va_arg(ap, int*);
				break;
			case '\0':							// Make sure loop exits on 
				spec_pos--;						// next iteration
				break;
			}
		fmt = spec_pos+1;
		str += strlen(str);
		}								// Get a C-string from the String

	if (strlen(fmt))					// copy trailing chars in fmt specifier
		strncpy(str, fmt, MIN(strlen(fmt) + 1, len - strlen(str)));

	return strlen(start);
}

/* ****************************************************************************

	NSString  -- locale variants

** ***************************************************************************/

@implementation NSString  (LocalizedStrings)

+ (id) localizedStringWithFormat:(NSString*)format, ...
{
	NSString *s;
	id locale = [NSLocale currentLocale];
	va_list ap;

	va_start(ap, format);
	s = [[NSString alloc] initWithFormat:format locale:locale arguments:ap];
	va_end(ap);

	return [s autorelease];
}

- (id) initWithFormat:(NSString*)format locale:(id)locale, ...
{
	NSString *s;
	va_list ap;

	va_start(ap, locale);
	s = [[NSString alloc] initWithFormat:format locale:locale arguments:ap];
	va_end(ap);

	return [s autorelease];
}

- (id) initWithFormat:(NSString*)format locale:(id)loc arguments:(va_list)alist
{
	const char *format_cp = [format cString];		// Change this when we have 
	int format_len = strlen (format_cp);			// non-CString classes
	char format_cp_copy[format_len+1];
	char *format_rem = format_cp_copy;
	unsigned len;
	unsigned printed_len = 0;
	int bufSize = 4096 + format_len;
	int wr;
	char *at_pos;				// points to a location inside format_cp_copy
	char *buf = malloc(bufSize);

    strcpy (format_cp_copy, format_cp);		// make local copy for tmp editing

	while ((at_pos = strstr (format_rem, "%@")))	// Loop once for each `%@'
		{											// in the format string
		const char *cstring;
		char *fmt_p; 								// Position for formatter
		va_list args_cpy;

			// If there is a "%%@", then do the right thing: print it literally
		if ((*(at_pos-1) == '%') && at_pos != format_cp_copy)
			continue;

		*at_pos = '\0';		// tmp terminate the string before the `%@'
		len = bufSize - printed_len;

		va_copy(args_cpy, alist);	// Print the part before the '%@'
//		printed_len += vsprintf (buf+printed_len, format_rem, args_cpy);
		if ((wr = vsnprintf (buf+printed_len, len, format_rem, args_cpy)) < 0)
			{
			fprintf(stderr,"NSString initWithFormat: vsnprintf err (%d)\n", wr);
//			[NSException raise: NSGenericException format:@"vsnprintf error"];
			}
		va_end(args_cpy);
		printed_len += wr;
										// Skip arguments used in last vsprint
		while ((fmt_p = strchr(format_rem, '%')))	 
			{
			char *spec_pos; 			// Position of conversion specifier

			if (*(fmt_p+1) == '%')
				{
				format_rem = fmt_p+2;
				continue;
				}							
											// Format specifiers K&R C 2nd ed.
			spec_pos = strpbrk(fmt_p+1, "dioxXucsfeEgGpn\0");
			switch (*spec_pos)
				{
				case 'd': case 'i': case 'o':
				case 'x': case 'X': case 'u': case 'c':
					va_arg(alist, int);
					break;
				case 's':
					if (*(spec_pos - 1) == '*')
						va_arg(alist, int*);
					va_arg(alist, char*);
					break;
				case 'f': case 'e': case 'E': case 'g': case 'G':
					va_arg(alist, double);
					break;
				case 'p':
					va_arg(alist, void*);
					break;
				case 'n':
					va_arg(alist, int*);
					break;
				case '\0':							// Make sure loop exits on 
					spec_pos--;						// next iteration
					break;
				}
			format_rem = spec_pos+1;
			}								// Get a C-string from the String
											// object, and print it
		if (!(cstring = [[(id) va_arg (alist, id) descriptionWithLocale:loc] cString]))
			cstring = "<null string>";
		len = strlen (cstring);

		if ((printed_len + len + format_len + 2048) > bufSize)
			{
			bufSize = printed_len + format_len + len + 4096;
			buf = realloc(buf, bufSize);
			}

		strcat (buf+printed_len, cstring);
		printed_len += len;
		format_rem = at_pos + 2;					// Skip over this `%@', and
		}											// look for another one.

//	printed_len += vsprintf (buf+printed_len, format_rem, alist);
	len = bufSize - printed_len;	// Print remaining string after last `%@'
    if ((wr = _mformat (buf+printed_len, len, loc, format_rem, alist)) < 0)
///    if ((wr = vsnprintf (buf+printed_len, len, format_rem, alist)) < 0)
		{
		fprintf(stderr,"NSString initWithFormat: _mprintf err (%d)\n", wr);
//		[NSException raise: NSGenericException format:@"vsnprintf error"];
		}
	printed_len += wr;

	if(printed_len > bufSize)						// Raise an exception if we
		{											// overran the buffer.
		fprintf(stderr,"NSString initWithFormat: buf = %d, len = %d\n", 
				bufSize, printed_len);
//		[NSException raise: NSRangeException format:@"printed_len > bufSize"];
		}

	buf = realloc(buf, printed_len+1);
	buf[printed_len] = '\0';

    return [self initWithCStringNoCopy:buf length:printed_len freeWhenDone:1];
}

@end
