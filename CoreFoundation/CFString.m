/*
   CFString.m

   String functions for mini CF implementation

   Copyright (C) 2016 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	August 2016

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFString.h>

#include <Foundation/NSString.h>
#include <Foundation/Private/unicode.h>


const UInt16 __madMasks[]  = { 0x0000, 0xFEC0, 0xFFE0, 0xFFF0, 0xFFF8, 0xFFFC };
const UInt16 __badPrefix[] = { 0x0000, 0xC080, 0xE080, 0xF080, 0xF880, 0xFC80 };

NSStringEncoding __StringEncoding = NSISOLatin1StringEncoding;

/* ****************************************************************************

	Encoding

** ***************************************************************************/

typedef struct {
	NSStringEncoding enc;
	char *ename;
} _CFStringEncoding;

const _CFStringEncoding __encodings_table[] =
{
	{ NSASCIIStringEncoding,         "NSASCIIStringEncoding"},
	{ NSNEXTSTEPStringEncoding,      "NSNEXTSTEPStringEncoding"},
	{ NSJapaneseEUCStringEncoding,   "NSJapaneseEUCStringEncoding"},
	{ NSISOLatin1StringEncoding,     "NSISOLatin1StringEncoding"},
	{ NSUTF8StringEncoding,          "NSUTF8StringEncoding"},
	{ NSSymbolStringEncoding,        "NSSymbolStringEncoding"},
	{ NSNonLossyASCIIStringEncoding, "NSNonLossyASCIIStringEncoding"},
	{ NSShiftJISStringEncoding,      "NSShiftJISStringEncoding"},
	{ NSISOLatin2StringEncoding,     "NSISOLatin2StringEncoding"},
	{ NSWindowsCP1251StringEncoding, "NSWindowsCP1251StringEncoding"},
	{ NSWindowsCP1252StringEncoding, "NSWindowsCP1252StringEncoding"},
	{ NSWindowsCP1253StringEncoding, "NSWindowsCP1253StringEncoding"},
	{ NSWindowsCP1254StringEncoding, "NSWindowsCP1254StringEncoding"},
	{ NSWindowsCP1250StringEncoding, "NSWindowsCP1250StringEncoding"},
	{ NSISO2022JPStringEncoding,     "NSISO2022JPStringEncoding "},
	{ NSUnicodeStringEncoding,       "NSUnicodeStringEncoding"}
};

static NSStringEncoding __availableEncodings[] =
{
	NSASCIIStringEncoding,
	NSUTF8StringEncoding,
	NSNEXTSTEPStringEncoding,
	NSISOLatin1StringEncoding,
	NSUnicodeStringEncoding,

	kCFStringEncodingInvalidId
};


const CFStringEncoding *
CFStringGetListOfAvailableEncodings(void)
{
	return __availableEncodings;
}

UInt32
CFStringConvertEncodingToNSStringEncoding( CFStringEncoding e )
{
	return e;									// mini CF uses NS constants
}

NSStringEncoding 
CFStringGetSystemEncoding()
{
	char *encoding = getenv("MGSTEP_CSTRING_ENCODING");

	if (encoding)
		{
		unsigned c = 0;
		unsigned ts = sizeof(__encodings_table) / sizeof(_CFStringEncoding);

		while ((c < ts) && strcmp(__encodings_table[c].ename, encoding))
			c++;

		if( !(c == ts))
			{
			__StringEncoding = __encodings_table[c].enc;

	  		if ((__StringEncoding == NSUnicodeStringEncoding)
					|| (__StringEncoding == NSSymbolStringEncoding))
				{
				fprintf(stderr, "WARNING: %s - is not supported as the default \
						C string encoding.\n", encoding);
				fprintf(stderr, "NSISOLatin1StringEncoding set as default.\n");
				__StringEncoding = NSISOLatin1StringEncoding;
				}
			else 								// encoding should be supported
				{								// but is it implemented?
				NSStringEncoding *avail = [NSString availableStringEncodings];
				NSStringEncoding t = 0;

				for (c = 0; avail[c] != 0; c++)
					if (__StringEncoding == avail[c])
						{
						t = __StringEncoding;
						break;
						};

				if (!t)
					{
					fprintf(stderr, "WARNING: %s - not implemented", encoding);
		  			fprintf(stderr, "NSASCIIStringEncoding set as default.\n");
					__StringEncoding = NSASCIIStringEncoding;
			}	}	}
		else 											// encoding not found 
			{
			fprintf(stderr,"WARNING: %s - encoding not supported.\n",encoding);
			fprintf(stderr, "NSISOLatin1StringEncoding set as default.\n");
			__StringEncoding = NSISOLatin1StringEncoding;
		}	}

	return __StringEncoding;
}

CFStringRef
CFStringGetNameOfEncoding(CFStringEncoding e)
{
	char *r = "Unknown encoding";
	unsigned c = 0;
	unsigned ts = sizeof(__encodings_table) / sizeof(_CFStringEncoding);

	while ((c < ts) && !(__encodings_table[c].enc == e))
		c++;
	if ( !(c == ts))
		r = __encodings_table[c].ename;

	return (CFStringRef)[NSString stringWithCString: r];
}

int
_UTF8toUCS4 (const UInt8 *src, UInt32 *ucs4, int len)
{
    const UInt8 *sp = src;
    UInt8 c = *sp++;
    int seq;

    if (!(c & 0x80))		// 7-bit ASCII char (0xxx xxxx)
		{
		*ucs4 = c;
    	return 1;
		}					// 2 or more byte sequence

    if (!(c & 0x40))
		return -1;			// out of seq continuation byte (first byte < 0xc0)

    if (!(c & 0x20))		// (110x xxxx  10xxxxxx)
		{
		*ucs4 = c & 0x1f;
		seq = 1;
		}
    else if (!(c & 0x10))	// (1110 xxxx  10xxxxxx 10xxxxxx)
		{
		*ucs4 = c & 0xf;
		seq = 2;
		}
    else if (!(c & 0x08))	// (1111 0xxx  1x 2x 3x)
		{
		*ucs4 = c & 0x07;
		seq = 3;
		}
    else if (!(c & 0x04))	// (1111 10xx  1x 2x 3x 4x)
		{
		*ucs4 = c & 0x03;
		seq = 4;
		}
    else if (!(c & 0x02))	// (1111 110x  1x 2x 3x 4x 5x)
		{
		*ucs4 = c & 0x01;
		seq = 5;
		}
    else
		return -2;

    if (seq > --len)
		return -3;

	if ((__madMasks[seq] & ((c << 8) | *sp)) == __badPrefix[seq])
		return -4;			// overlong sequence

    while (seq--)
		{
		c = *sp++;
		
		if ((c & 0xc0) != 0x80)
			return -5;
		
		*ucs4 <<= 6;
		*ucs4 |= c & 0x3f;
		}

    return sp - src;
}

static int
_UCS2toUTF8 (const unichar *src, UInt8 *u8)
{
	unichar c = *src;

	if (0x80 > c)
		{
		u8[0] = c;							// 1 byte:   U+0000 - U+007F
		u8[1] = '\0';
		return 1;
		}

	if (0x800 > c)							// 2 bytes:  U+0080	- U+07FF
		{
		u8[1] = (0x80 | (c & 0x3F));
		u8[0] = (0xC0 | (c >> 6));
		u8[2] = '\0';
		return 2;
		}

	if (c < 0xD800 || (c > 0xE000 && c < 0xFFFF))
		{
		if (c == 0xFEFF || c == 0xFFFE)
			u8[0] = '\0';					// BE or LE BOM (UCS2, UTF16)
		else
			{								// 3 bytes:  U+0800 - U+FFFF
			u8[2] = (0x80 | (c & 0x3F));
			c = (c >> 6);
			u8[1] = (0x80 | (c & 0x3F));
			u8[0] = (0xE0 | (c >> 6));
			u8[3] = '\0';
			return 3;
			}
		}			// not UCS-2 within BMP (Basic Multilingual Plane)
					// unichar is UTF-16 (two 16-bit values) U+D800 to U+DFFF
	return 0;		// East Asian and Emoji, must parse Supplementary Planes
}

/* ****************************************************************************

	CFStringGetBytes()
	
	Convert string characters in the specified range to the target encoding
	and return the number of chars consumed in the conversion.

	Places output in buffer if not NULL.  maxBufLength is the size of buffer
	in bytes and is ignored if buffer is NULL.  usedBufLen returns min needed
	buffer if not NULL.

	// FIX ME if string is already in target encoding return as-is
	// FIX ME add markers such as Unicode BOM when supported by target encoding
	// FIX ME incomplete, supports only UCS2 to UTF8 and ASCII/UTF8 to UTF32

** ***************************************************************************/

CFIndex											// chars consumed in conversion
CFStringGetBytes( CFStringRef string,
				  CFRange r,					// range of char in string
				  CFStringEncoding encoding,	// target encoding
				  unsigned char lossByte,
				  bool externalRepresentation,  // add Unicode BOM if possible
				  unsigned char *buffer,		// output buf
				  CFIndex maxBufLen,			// output buf max len in bytes
				  CFIndex *usedBufLen)			// size of output buf in bytes
{
	NSUInteger i = r.location;
	int j, k = 0;

	if (!string)
		return 0;

	if (encoding == NSUTF8StringEncoding)		// UCS-2 to UTF-8
		{
		const unichar *uchars = ((CFString *)string)->_uniChars;
		NSUInteger count = ((CFString *)string)->_count;

		UInt8 buf[4];
		UInt8 *u8 = (buffer) ? (UInt8 *)buffer : buf;
		UInt8 *end = (buffer) ? (UInt8 *)(buffer + maxBufLen) : u8 + 1;

		for (; r.length && i < count && u8 < end; i++, r.length--)
			{
			k += _UCS2toUTF8(&uchars[i], u8);

			if (buffer)
				u8 = buffer + k;
		}	}

	if (encoding == NSUTF32StringEncoding)		// ASCII or UTF-8 to UCS-4
		{
		const char *bytes = ((CFString *)string)->_cString;
		NSUInteger  count = ((CFString *)string)->_count;
		int inc = sizeof(UInt32);

		UInt32 ucs4;
		UInt32 *u4 = (buffer) ? (UInt32 *)buffer : &ucs4;
		UInt32 *end = (buffer) ? (UInt32 *)(buffer + maxBufLen) : u4 + 1;

		if (!((CFString *)string)->_cString)		// FIX ME ! UTF-16 support
			return 0;
//		if (buffer && (r.length > (maxBufLen / sizeof(UInt32))))
//			r.length = maxBufLen / sizeof(UInt32);

		for (; r.length && i < count && u4 < end; k += inc, i += j, r.length--)
			{
			if ((j = _UTF8toUCS4(&bytes[i], u4, count - i)) < 1)
				{
				if (!lossByte)					// lossy conversion verboten
					{
					if (usedBufLen)
						*usedBufLen = k;

					return i - r.location;
					}

				j = 1;
				*u4 = lossByte;
				}

			if (buffer)
				u4++;
		}	}

	if (usedBufLen)
		*usedBufLen = k;

	return i - r.location;
}

CFIndex
CFStringGetLength(CFStringRef s)
{
	return (CFIndex)[(NSString *)s length];
}

unichar
ByteToUChar(char c)
{
	return encode_chartouni(c, __StringEncoding);
}

char
UCharToByte(unichar u)
{
	unsigned char r;

	return (r = encode_unitochar(u, __StringEncoding)) ? r : '*';
}

int
UStrToCStr(char *s2, unichar *u1, int size)			// lossy conversion
{
	int c = 0;
	int a = 0;
	unsigned char r;

	switch (__StringEncoding)
		{
		case NSASCIIStringEncoding:
		case NSNonLossyASCIIStringEncoding:		a = 128;	break;
		case NSISOLatin1StringEncoding:			a = 256;	break;
		}

	if (!a)
		for (c = 0; (c < size) && (u1[c] != (unichar)0) ; c++)
			s2[c] = (r = encode_unitochar(u1[c], __StringEncoding)) ? r : '*';
	else
		for (c = 0; (c < size) && (u1[c] != (unichar)0) ; c++)
			s2[c] = (u1[c] < a) ? (char)u1[c] : '*';

	return c;
}
