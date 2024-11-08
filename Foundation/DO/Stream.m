/*
   Stream.m

   Objective-C byte stream

   Copyright (C) 1994, 1995, 1996 Free Software Foundation, Inc.

   Author:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date:	July 1994

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>

#include "Stream.h"
#include "_NSPortCoder.h"

#include <Foundation/NSString.h>
#include <Foundation/NSData.h>
#include <Foundation/NSException.h>


#define FORMAT_VERSION 0
#define DEFAULT_MEMORY_STREAM_SIZE 64


static BOOL __debug_memory_stream = NO;
static int __debug_binary_coder = 0;


@implementation Stream

- (int) writeByte:(unsigned char)b	  { return [self writeBytes:&b length:1];}
- (int) readByte:(unsigned char*)b    { return [self readBytes:b length:1]; }

- (int) writeFormat:(NSString*)format, ...
{
	int ret;
	va_list ap;

	va_start(ap, format);
	ret = [self writeFormat: format arguments: ap];
	va_end(ap);
	
	return ret;
}

@end /* Stream */

/* ****************************************************************************

	MemoryStream

** ***************************************************************************/

#include <limits.h>
#include <ctype.h>
#include <stdio.h>

#ifdef	__GNUC__
  #define HAVE_LONGLONG
  #define LONGLONG	long long
  #define CONST const
  #define LONG_DOUBLE long double
#else
  #define LONGLONG	long
  #define CONST
#endif

#ifdef	HAVE_LONGLONG					// use `L' modifier for `long long int'
  #define is_longlong	is_long_double
#else
  #define is_longlong	0
#endif

		// inchar()	((c = getc(s)) == EOF ? EOF : (++read_in, c))
#define inchar()  ((c = (*inchar_func)(stream)) == EOF ? EOF : (++read_in, c))
		// conv_error()	return ((c == EOF || ungetc(c, s)), done)
#define	conv_error() return ((c == EOF || ((*unchar_func)(stream,c), c)), done)
#define input_error()	return (done == 0 ? EOF : done)

#define STRING_ARG \
			if (do_assign) \
			{ \
				if (malloc_string) \
			{ \
				/* The string is to be stored in a malloc'd buffer.  */ \
				strptr = va_arg (arg, char **); \
				if (strptr == NULL) \
				conv_error (); \
				/* Allocate an initial buffer.  */ \
				strsize = 100; \
				*strptr = str = malloc (strsize); \
			} \
				else \
			str = va_arg (arg, char *); \
				if (str == NULL) \
			conv_error (); \
			}

#define	STRING_ADD_CHAR(c) \
				if (do_assign) \
				{ \
					*str++ = c; \
					if (malloc_string && str == *strptr + strsize) \
					{ \
						/* Enlarge the buffer.  */ \
						str = realloc (*strptr, strsize * 2); \
						if (str == NULL) \
					{ \
						/* Can't allocate that much.  Last-ditch effort.  */\
						str = realloc (*strptr, strsize + 1); \
						if (str == NULL) \
						{ \
							/* Terminate the string and stop converting, so at least we don't swallow any input.  */  \
							(*strptr)[strsize] = '\0'; \
							++done; \
							conv_error (); \
						} \
						else \
						{ \
							*strptr = str; \
							str += strsize; \
							++strsize; \
						} \
					} \
						else \
					{ \
						*strptr = str; \
						str += strsize; \
						strsize *= 2; \
					} \
					} \
				}

											// Read formatted input from STREAM
int											// according to the format string
o_vscanf( void *stream,						// using the argument list in ARGPTR
		  int (*inchar_func)(MemoryStream *),
		  void (*unchar_func)(MemoryStream *, int),
		  const char *format, va_list arg)	// Return the number of assignments
{											// made, or -1 for an input error.
	register CONST char *f = format;
	register char fc;						// Current character of the format.
	register size_t done = 0;				// Assignments done.
	register size_t read_in = 0;			// Chars read in.
	register int c;							// Last char read.
	register int do_assign;					// Whether to do an assignment.
	register int width;						// Maximum field width.

	char is_short, is_long, is_long_double;	// Type modifiers.
	int malloc_string;						// Args are char ** to be filled in
											// Status for reading F-P nums.
	char got_dot, got_e;
											// If a [...] is a [^...].
	char not_in;
											// Base for integral numbers.
	int base;
											// Signedness for integral numbers.
	int number_signed;
											// Integral holding variables.
	long int num;
	unsigned long int unum;
											// Floating-point holding variable.
	LONG_DOUBLE fp_num;
											// Character-buffer pointer.
	register char *str, **strptr;
	size_t strsize;
											// Workspace.
	char work[200];
	char *w;								// Pointer into WORK.
	wchar_t decimal = '.';					// Decimal point character.

	c = inchar();

	while (*f != '\0')						// Run through the format string.
		{
		if (!isascii(*f))
			{								// Non-ASCII, may be a multibyte.
			int len = mblen(f, strlen(f));

			if (len > 0)
				{
				while (len-- > 0)
					if (c == EOF)
						input_error();
					else 
						if (c == *f++)
							(void) inchar();
						else
							conv_error();
				continue;
			}	}

		fc = *f++;
		if (fc != '%')
			{								// Characters other than format 
			if (c == EOF)					// specs must just match.
	    		input_error();
			if (isspace(fc))
	    		{	// Whitespace characters match any amount of whitespace.
				while (isspace (c))
					inchar ();
				continue;
				}
			else 
				if (c == fc)
					(void) inchar();
				else
					conv_error();
			continue;
			}

		if (*f == '*')				// Check for the assignment-suppressant.
			{
			do_assign = 0;
			++f;
			}
		else
			do_assign = 1;

		width = 0;							// Find the maximum field width.
		while (isdigit(*f))
			{
			width *= 10;
			width += *f++ - '0';
			}
		if (width == 0)
			width = -1;
											// Check for type modifiers.
		is_short = is_long = is_long_double = malloc_string = 0;
		while (*f == 'h' || *f == 'l' || *f == 'L' || *f == 'a')
			switch (*f++)
				{
				case 'h':					// int's are short int's.
					is_short = 1;
					break;
				case 'l':
					if (is_long)			// A double `l' is equiv to an `L'
						is_longlong = 1;
					else					// int's are long int's.
						is_long = 1;
					break;
				case 'L':					// double's are long double's, and 
											// int's are long long int's.
					is_long_double = 1;
					break;
				case 'a':		// String conversions (%s, %[) take a `char **'
								// arg and fill it in with a malloc'd pointer.
					malloc_string = 1;
					break;
				}

		if (*f == '\0')						// End of the format string?
			conv_error();

		w = work;							// Find the conversion specifier.
		fc = *f++;
		if (fc != '[' && fc != 'c' && fc != 'n')		// Eat whitespace.
			while (isspace(c))
				(void) inchar();

		switch (fc)
			{
			case '%':	/* Must match a literal '%'.  */
				if (c != fc)
					conv_error();
				break;
		
			case 'n':	/* Answer number of assignments done.  */
				if (do_assign)
					*va_arg(arg, int *) = read_in;
				break;
		
			case 'c':	/* Match characters.  */
				if (do_assign)
					{
					str = va_arg (arg, char *);
					if (str == NULL)
						conv_error ();
					}
		
				if (c == EOF)
					input_error();
		
				if (width == -1)
					width = 1;
		
				if (do_assign)
					{
					do
						*str++ = c;
					while (inchar() != EOF && --width > 0);
					}
				else
					while (inchar() != EOF && width > 0)
						--width;
		
				if (do_assign)
					++done;
		
				break;
		
			case 's':		/* Read a string.  */
				STRING_ARG;
		
				if (c == EOF)
					input_error ();
		
				do {
					if (isspace (c))
						break;
					STRING_ADD_CHAR (c);
				} while (inchar () != EOF && (width <= 0 || --width > 0));
		
				if (do_assign)
					{
					*str = '\0';
					++done;
					}
				break;
		
			case 'x':	/* Hexadecimal integer.  */
			case 'X':	/* Ditto.  */ 
				base = 16;
				number_signed = 0;
				goto number;
		
			case 'o':	/* Octal integer.  */
				base = 8;
				number_signed = 0;
				goto number;
		
			case 'u':	/* Unsigned decimal integer.  */
				base = 10;
				number_signed = 0;
				goto number;
		
			case 'd':	/* Signed decimal integer.  */
				base = 10;
				number_signed = 1;
				goto number;
		
			case 'i':	/* Generic number.  */
				base = 0;
				number_signed = 1;
number:
				if (c == EOF)
					input_error();
		
				if (c == '-' || c == '+')				/* Check for a sign. */
					{
					*w++ = c;
					if (width > 0)
						--width;
					(void) inchar();
					}
		
				if (c == '0')		/* Look for a leading indication of base. */
					{
					if (width > 0)
						--width;
					*w++ = '0';

					(void) inchar();

					if (tolower(c) == 'x')
						{
						if (base == 0)
							base = 16;
						if (base == 16)
							{
							if (width > 0)
								--width;
							(void) inchar();
							}
						}
					else if (base == 0)
						base = 8;
					}
		
				if (base == 0)
					base = 10;
		
				/* Read the number into WORK.  */
				do {
					if (base == 16 ? !isxdigit(c) : (!isdigit(c) || c - '0' >= base))
						break;
					*w++ = c;
					if (width > 0)
						--width;
				} while (inchar() != EOF && width != 0);
		
				if (w == work || (w - work == 1 && (work[0] == '+' || work[0] == '-')))
				/* There was on number.  */
				conv_error();
		
				/* Convert the number.  */
				*w = '\0';
				if (number_signed)
					num = strtol (work, &w, base);
				else
#if HAVE_STRTOUL
				unum = strtoul (work, &w, base);
#else
				unum = (unsigned long) strtol (work, &w, base);
#endif
				if (w == work)
					conv_error ();
		
				if (do_assign)
					{
					if (! number_signed)
						{
						if (is_longlong)
							*va_arg (arg, unsigned LONGLONG int *) = unum;
						else if (is_long)
							*va_arg (arg, unsigned long int *) = unum;
						else if (is_short)
							*va_arg (arg, unsigned short int *) = (unsigned short int) unum;
						else
							*va_arg(arg, unsigned int *) = (unsigned int) unum;
						}
					else
						{
						if (is_longlong)
							*va_arg(arg, LONGLONG int *) = num;
						else if (is_long)
							*va_arg(arg, long int *) = num;
						else if (is_short)
							*va_arg(arg, short int *) = (short int) num;
						else
							*va_arg(arg, int *) = (int) num;
						}
					++done;
					}
				break;
		
			case 'e':	/* Floating-point numbers.  */
			case 'E':
			case 'f':
			case 'g':
			case 'G':
				if (c == EOF)
					input_error();
		
				if (c == '-' || c == '+')				/* Check for a sign. */
				{
					*w++ = c;
					if (inchar() == EOF)
				/* EOF is only an input error before we read any chars.  */
				conv_error();
					if (width > 0)
				--width;
				}
		
				got_dot = got_e = 0;
				do {
					if (isdigit(c))
				*w++ = c;
					else if (got_e && w[-1] == 'e' && (c == '-' || c == '+'))
				*w++ = c;
					else if (!got_e && tolower(c) == 'e')
				{
					*w++ = 'e';
					got_e = got_dot = 1;
				}
					else if (c == decimal && !got_dot)
				{
					*w++ = c;
					got_dot = 1;
				}
					else
				break;
					if (width > 0)
				--width;
				} while (inchar() != EOF && width != 0);
		
				if (w == work)
					conv_error();
				if (w[-1] == '-' || w[-1] == '+' || w[-1] == 'e')
					conv_error();
		
#ifndef MIB_HACKS
				/* Convert the number.  */
				*w = '\0';
				fp_num = strtod(work, &w);
				if (w == work)
					conv_error();
		
				if (do_assign)
					{
					if (is_long_double)
						*va_arg(arg, LONG_DOUBLE *) = fp_num;
					else if (is_long)
						*va_arg(arg, double *) = (double) fp_num;
					else
						*va_arg(arg, float *) = (float) fp_num;
					++done;
					}
				break;
#endif /* MIB_HACKS */
		
			case '[':	/* Character class.  */
				STRING_ARG;
		
				if (c == EOF)
					input_error();
		
				if (*f == '^')
					{
					++f;
					not_in = 1;
					}
				else
					not_in = 0;
		
				while ((fc = *f++) != '\0' && fc != ']')
				{
					if (fc == '-' && *f != '\0' && *f != ']' &&
					w > work && w[-1] <= *f)
				/* Add all characters from the one before the '-'
					up to (but not including) the next format char.  */
				for (fc = w[-1] + 1; fc < *f; ++fc)
					*w++ = fc;
					else
				/* Add the character to the list.  */
				*w++ = fc;
				}
				if (fc == '\0')
				conv_error();
		
				*w = '\0';
				unum = read_in;
				do {
					if ((strchr (work, c) == NULL) != not_in)
				break;
					STRING_ADD_CHAR (c);
					if (width > 0)
				--width;
				} while (inchar () != EOF && width != 0);
				if (read_in == unum)
				conv_error ();
		
				if (do_assign)
				{
					*str = '\0';
					++done;
				}
				break;
		
			case 'p':	/* Generic pointer.  */
				base = 16;
				/* A PTR must be the same size as a `long int'.  */
				is_long = 1;
				goto number;
			}
		}

	conv_error();
}
									// A pretty stupid implementation based 
@implementation MemoryStream		// on realloc(), but it works for now.

+ (MemoryStream*) streamWithData:(id)d
{
	return [[(MemoryStream*)[MemoryStream alloc] initWithData:d] autorelease];
}

- (id) initWithCapacity:(unsigned)capacity prefix:(unsigned)p
{
	if ((self = [super init]))
		{
		if ((_data = [[NSMutableData alloc] initWithCapacity: capacity]))
			{
			[_data setLength: capacity];
			prefix = p;
			isMutable = YES;
			if ([_data length] < prefix)
				[_data setLength: prefix];

			return self;
		}	}

	return _NSInitError(self, @"unable to initWithCapacity:prefix:");
}

- (id) initWithData:(id)anObject
{
	if ((self = [super init]))
    	{
     	 if (anObject && [anObject isKindOfClass:[NSData class]])
			{
			_data = [anObject retain];
			if ([_data isKindOfClass:[NSMutableData class]])
				isMutable = YES;
			_eof = [_data length];
			position = 0;
			prefix = 0;

			return self;
		}	}

	return _NSInitError(self, @"unable to initWithData:");
}

- (void) dealloc
{
	[_data release];
	[super dealloc];
}

- (void) encodeWithCoder:(id)anEncoder		{ NIMP }
+ (id) newWithCoder:(id)aDecoder			{ NIMP return self; }

- (int) writeBytes:(const void*)b length:(int)l
{
	if (isMutable)
		{
		unsigned size = [_data _capacity];

		if (prefix+position+l > size)
			{
			size = MAX(prefix+position+l, size*2);
			[_data _setCapacity: size];
			}
		if (position + prefix + l > [_data length])
			[_data setLength: position+prefix+l];
		memcpy([_data mutableBytes] + prefix + position, b, l);
		position += l;
		if (position > _eof)
			_eof = position;

		return l;
		}

	return 0;
}

- (int) readBytes:(void*)b length:(int)l
{
	if (position+l > _eof)
		l = _eof - position;
	memcpy(b, [_data bytes]+prefix+position, l);
	position += l;

	return l;
}

- (int) writeFormat:(NSString*)format arguments:(va_list)arg
{ 
	unsigned size;
	int ret;

	if (!isMutable)
		return 0;		// xxx Using this ugliness we at least let ourselves 
						// safely print formatted strings up to 128 bytes long.
						// It's digusting, though, and we need to fix it. 
						// Using GNU stdio streams would do the trick. 
	size = [_data _capacity];
	if (size - (prefix + position) < 128)
		size = MAX(size+128, size*2);
	[_data setLength: size];
  
	ret = vsprintf([_data mutableBytes]+prefix+position, [format cString],arg);
	position += ret;
					// ** Make sure we didn't overrun our buffer.  As per above 
					// kludge, this would happen if we happen to have more than
					// 128 bytes left in the buffer and we try to write a 
					// string longer than the num bytes left in the buffer.
	NSAssert(prefix + position <= [_data capacity], @"buffer overrun");
	if (position > _eof)
		_eof = position;
	[_data setLength:_eof + prefix];
	if (__debug_memory_stream)
		{
		*(char*)([_data mutableBytes]+prefix+position) = '\0';
		fprintf(stderr, "%s\n", (char*)[_data mutableBytes]+prefix);
		}

	return ret;
}

static int inchar_f(MemoryStream *s)
{
	if (s->prefix + s->position >= [s->_data length])
		return EOF;

	return (int) ((char*)[s->_data bytes])[s->prefix + s->position++];
}

static void unchar_f(MemoryStream *s, int c)
{
	if (s->position > 0)
		s->position--;
	if (s->isMutable)
		((char*)[s->_data mutableBytes])[s->prefix + s->position] = (char)c;
}

- (int) readFormat:(NSString*)format, ...
{
	int ret;
	va_list ap;

	va_start(ap, format);
	ret = o_vscanf(self, inchar_f, unchar_f, [format cString], ap);
	va_end(ap);
	
	return ret;
}

- (unsigned) streamEofPosition			{ return _eof; }

@end /* MemoryStream */

/* ****************************************************************************

	CStream

** ***************************************************************************/

id CStreamSignatureMalformedException = @"CStreamSignatureMalformedException";
id CStreamSignatureMismatchException  = @"CStreamSignatureMismatchException";

@implementation CStream

- (void) writeSignature									// Signature methods.
{
	[_stream writeFormat: SIGNATURE_FORMAT_STRING,		// string should not 
						  PACKAGE_NAME,					// contain newlines.
						  PORT_CODER_FORMAT_VERSION,
						  object_get_class_name(self),
						  format_version];
}

+ (void) readSignatureFromStream:s
					getClassname:(char *)name
					formatVersion:(int*)version
{
	char package_name[64];
	int major_version;
	int got = [s readFormat: SIGNATURE_FORMAT_STRING,
							 &(package_name[0]),
							 &major_version,
							 name, version];
	if (got != 4)
		[NSException raise:CStreamSignatureMalformedException
					 format: @"CStream found a malformed signature"];
}

- (id) _initForReadingFromPostSignatureStream:(id <Streaming>)s
							withFormatVersion:(int)version
{												// designated init reading
	_stream = [s retain];
	format_version = version;

	return self;
}

+ (id) cStreamReadingFromStream:(id <Streaming>)s
{
	char name[128];								// Maximum class name length.
	int version;
	id new_cstream;

	[self readSignatureFromStream:s getClassname:name formatVersion:&version];
	new_cstream = [[objc_lookup_class(name) alloc] 
						_initForReadingFromPostSignatureStream: s
						withFormatVersion: version];
	return [new_cstream autorelease];
}

- (id) initForWritingToStream:(id <Streaming>)s withFormatVersion:(int)version
{												// designated init writing
	_stream = [s retain];
	format_version = version;
	[self writeSignature];

	return self;
}

- (id) initForWritingToStream:(id <Streaming>)s
{
	return [self initForWritingToStream: s
				 withFormatVersion: [[self class] defaultFormatVersion]];
}
											// Encoding/decoding indentation
- (void) encodeWithName:(NSString*)name
		 valuesOfCTypes:(const char *)types, ...
{
	va_list ap;

	[self encodeName: name];
	va_start (ap, types);
	while (*types)
		{
		[self encodeValueOfCType: types at: va_arg(ap, void*) withName: NULL];
		types = objc_skip_typespec (types);
		}
	va_end (ap);
}

- (void) decodeWithName:(NSString**)name
		 valuesOfCTypes:(const char *)types, ...
{
	va_list ap;

	[self decodeName: name];
	va_start (ap, types);
	while (*types)
		{
		[self decodeValueOfCType: types at: va_arg (ap, void*) withName: NULL];
		types = objc_skip_typespec (types);
		}
	va_end (ap);
}

- (void) encodeIndent								{}
- (void) encodeUnindent								{}
- (void) decodeIndent								{}
- (void) decodeUnindent								{}
- (void) encodeName:(NSString*) n					{}
- (void) decodeName:(NSString**) name				{}
											// Access to the underlying stream.
- (id <Streaming>) stream							{ return _stream; }

- (void) dealloc
{
	[_stream release];
	[super dealloc];
}

@end /* CStream */

/* ****************************************************************************

	TextCStream

** ***************************************************************************/

@interface TextCStream : CStream
@end

@implementation TextCStream

+ (int) defaultFormatVersion			{ return PORT_CODER_FORMAT_VERSION; }

- (id) initForWritingToStream:(id <Streaming>)s
{
	return [self initForWritingToStream: self
				 withFormatVersion: [[self class] defaultFormatVersion]];
}

- (int) writeFormat:(NSString*)format arguments:(va_list)arg
{
	return vfprintf(stderr, [format cString], arg);
}

- (void) encodeValueOfCType:(const char*)type 
						 at:(const void*)d 
						 withName:(NSString*)name;
{
	if (!type)
		[NSException raise:NSInvalidArgumentException format:@"type is NULL"];

	NSAssert(*type != '@', @"tried to encode an \"ObjC\" type");
	NSAssert(*type != '^', @"tried to encode an \"ObjC\" type");
	NSAssert(*type != ':', @"tried to encode an \"ObjC\" type");

	if (!name || [name length] == 0)
		name = @"Anonymous";
	switch (*type)
		{
		case _C_LNG:
			[_stream writeFormat:@"%*s<%s> (long) = %ld\n", 
				indentation, "", [name cString], *(long*)d];
			break;
		case _C_ULNG:
			[_stream writeFormat:@"%*s<%s> (unsigned long) = %lu\n", 
				indentation, "", [name cString], *(unsigned long*)d];
			break;
		case _C_LNG_LNG:
			[_stream writeFormat:@"%*s<%s> (long long) = %ld\n", 
				indentation, "", [name cString], *(long long*)d];
			break;
		case _C_ULNG_LNG:
			[_stream writeFormat:@"%*s<%s> (unsigned long long) = %lu\n", 
				indentation, "", [name cString], *(unsigned long long*)d];
			break;
		case _C_INT:
			[_stream writeFormat:@"%*s<%s> (int) = %d\n", 
				indentation, "", [name cString], *(int*)d];
			break;
		case _C_UINT:
			[_stream writeFormat:@"%*s<%s> (unsigned int) = %u\n", 
				indentation, "", [name cString], *(unsigned int*)d];
			break;
		case _C_SHT:
			[_stream writeFormat:@"%*s<%s> (short) = %d\n", 
				indentation, "", [name cString], (int)*(short*)d];
			break;
		case _C_USHT:
			[_stream writeFormat:@"%*s<%s> (unsigned short) = %u\n", 
				indentation, "", [name cString],
				(unsigned)*(unsigned short*)d];
			break;
		case _C_CHR:
			[_stream writeFormat:@"%*s<%s> (char) = %c (0x%x)\n", 
				indentation, "", [name cString],
				*(char*)d, (unsigned)*(char*)d];
			break;
		case _C_UCHR:
			[_stream writeFormat:@"%*s<%s> (unsigned char) = 0x%x\n", 
				indentation, "", [name cString],
				(unsigned)*(unsigned char*)d];
			break;
		case _C_FLT:
			[_stream writeFormat:@"%*s<%s> (float) = %g\n",
				indentation, "", [name cString], *(float*)d];
			break;
		case _C_DBL:
			[_stream writeFormat:@"%*s<%s> (double) = %g\n",
				indentation, "", [name cString], *(double*)d];
			break;
		case _C_CHARPTR:
			[_stream writeFormat:@"%*s<%s> (char*) = \"%s\"\n", 
				indentation, "", [name cString], *(char**)d];
			break;
		case _C_ARY_B:
			{
			int len = atoi (type+1);	/* xxx why +1 ? */
			int offset;
			char *dc = (char*)d;
	
			while (isdigit(*++type));
			offset = objc_sizeof_type(type);
			[self encodeName:name];
			[self encodeIndent];
			while (len-- > 0)
				{		// Change this so we don't re-write type info every time.
				[self encodeValueOfCType:type at:dc withName:@"array element"];
				dc += offset;
				}
			[self encodeUnindent];
			break; 
			}
		case _C_STRUCT_B:
			{
			int acc_size = 0;
			int align;
		
			while (*type != _C_STRUCT_E && *type++ != '='); /* skip "<name>=" */
				[self encodeName:name];
			[self encodeIndent];
			while (*type != _C_STRUCT_E)
				{
				align = objc_alignof_type (type); /* pad to alignment */
				acc_size = ROUND (acc_size, align);
				[self encodeValueOfCType:type 
					  at:((char*)d)+acc_size 
					  withName:@"structure component"];
				acc_size += objc_sizeof_type (type); /* add component size */
				type = objc_skip_typespec (type); /* skip component */
				}
			[self encodeUnindent];
			break;
			}
		case _C_PTR:
			[NSException raise: NSGenericException
						 format: @"Cannot encode pointers"];
			break;
		default:
			[NSException raise: NSGenericException
						 format: @"type %s not implemented", type];
		}
}
											// Encoding/decoding indentation 
- (void) encodeIndent				
{
	[_stream writeFormat: @"%*s {\n", indentation, ""];
	indentation += 2;
}

- (void) encodeUnindent
{
	indentation -= 2;
	[_stream writeFormat: @"%*s }\n", indentation, ""];
}

- (void) encodeName:(NSString*)n
{
	if (n)
		[_stream writeFormat:@"%*s<%s>\n", indentation, "", [n cString]];
	else
		[_stream writeFormat:@"%*s<NULL>\n", indentation, ""];
}

@end /* TextCStream */

/* ****************************************************************************

	BinaryCStream

** ***************************************************************************/

#include <math.h>

#ifndef __WIN32__
  #if HAVE_VALUES_H
    #include <values.h>					// This gets BITSPERBYTE on Solaris
  #endif
#include <sys/types.h>
#include <netinet/in.h>					// for byte-conversion
#endif /* !__WIN32__ */

/* number of bytes used to encode the length of encoded _C_CHARPTR string */
#define NUM_BYTES_STRING_LENGTH 4

/* The value by which we multiply a float or double in order to bring
   mantissa digits to the left-hand-side of the decimal point, so that
   we can extract them by assigning the float or double to an int. */
#if !defined(BITSPERBYTE) && defined(NeXT)
#include <mach/vm_param.h>
#define BITSPERBYTE BYTE_SIZE
#elif !defined(BITSPERBYTE)
#define BITSPERBYTE 8		/* a safe guess? */
#endif

#define FLOAT_FACTOR ((double)(1 << ((sizeof(int)*BITSPERBYTE)-2)))

#define WRITE_SIGNED_TYPE0(_PTR, _TYPE, _CONV_FUNC)		\
      {								\
        _TYPE tmp;						\
	char buffer[1+sizeof(_TYPE)];				\
	buffer[0] = sizeof (_TYPE);				\
	if (*(_TYPE*)_PTR < 0)					\
	  {							\
	    buffer[0] |= 0x80;					\
	    tmp = _CONV_FUNC (- *(_TYPE*)_PTR);			\
            memcpy (buffer+1, &tmp, sizeof(_TYPE));		\
	  }							\
	else							\
	  {							\
	    tmp = _CONV_FUNC (*(_TYPE*)_PTR);			\
            memcpy (buffer+1, &tmp, sizeof(_TYPE));		\
	  }							\
	[_stream writeBytes: buffer length: 1+sizeof(_TYPE)];	\
      }

#define WRITE_SIGNED_TYPE1(_PTR, _TYPE, _CONV_FUNC)		\
      {								\
        _TYPE tmp;						\
	char buffer[sizeof(_TYPE)];				\
	if (*(_TYPE*)_PTR < 0)					\
	  {							\
	    tmp = _CONV_FUNC (- *(_TYPE*)_PTR);			\
            memcpy (buffer, &tmp, sizeof(_TYPE));		\
	    NSAssert(!(buffer[0] & 0x80), @"high bit set");	\
	    buffer[0] |= 0x80;					\
	  }							\
	else							\
	  {							\
	    tmp = _CONV_FUNC (*(_TYPE*)_PTR);			\
            memcpy (buffer, &tmp, sizeof(_TYPE));		\
	  }							\
	[_stream writeBytes: buffer length: sizeof(_TYPE)];	\
      }

#define WRITE_SIGNED_TYPE(_PTR, _TYPE, _CONV_FUNC) \
		{ \
		if (format_version == FORMAT_VERSION) \
			WRITE_SIGNED_TYPE0 (_PTR, _TYPE, _CONV_FUNC) \
		else \
			WRITE_SIGNED_TYPE1 (_PTR, _TYPE, _CONV_FUNC) \
		}

#define READ_SIGNED_TYPE0(_PTR, _TYPE, _CONV_FUNC)		\
      {								\
	char sign, size;					\
	[_stream readByte: &size];				\
	sign = size & 0x80;					\
	size &= ~0x80;						\
	{							\
	  char buffer[size];					\
	  int read_size;					\
	  read_size = [_stream readBytes: buffer length: size];	\
	  NSAssert (read_size == size, @"expected more input");	\
	  NSAssert (size == sizeof(_TYPE), @"inconsistent size");\
	  *(unsigned _TYPE*)_PTR =				\
	    _CONV_FUNC (*(unsigned _TYPE*)buffer);		\
	  if (sign)						\
	    *(_TYPE*)_PTR = - *(_TYPE*)_PTR;			\
	}							\
      }

#define READ_SIGNED_TYPE1(_PTR, _TYPE, _CONV_FUNC)		\
      {								\
	int size = _sizeof_ ## _TYPE;				\
	char buffer[size];					\
	int read_size;						\
        int sign;						\
	read_size = [_stream readBytes: buffer length: size];	\
	NSAssert (read_size == size, @"expected more input");	\
	/* xxx Remove this next requirement eventually */	\
	NSAssert (size == sizeof(_TYPE), @"inconsistent size");	\
        sign = buffer[0] & 0x80;				\
        buffer[0] &= ~0x80;					\
	*(unsigned _TYPE*)_PTR =				\
	  _CONV_FUNC (*(unsigned _TYPE*)buffer);		\
	if (sign)						\
	  *(_TYPE*)_PTR = - *(_TYPE*)_PTR;			\
      }

#define READ_SIGNED_TYPE(_PTR, _TYPE, _CONV_FUNC)		\
      {								\
	if (format_version == FORMAT_VERSION)	\
	  READ_SIGNED_TYPE0 (_PTR, _TYPE, _CONV_FUNC)		\
	else							\
	  READ_SIGNED_TYPE1 (_PTR, _TYPE, _CONV_FUNC)		\
      }

/* Reading and writing unsigned scalar types. */

#define WRITE_UNSIGNED_TYPE0(_PTR, _TYPE, _CONV_FUNC)		\
      {								\
        _TYPE tmp;						\
	char buffer[1+sizeof(_TYPE)];				\
	buffer[0] = sizeof (_TYPE);				\
        tmp = _CONV_FUNC (*(_TYPE*)_PTR);			\
	memcpy (buffer+1, &tmp, sizeof(_TYPE));			\
	[_stream writeBytes: buffer length: (1+sizeof(_TYPE))];	\
      }

#define WRITE_UNSIGNED_TYPE1(_PTR, _TYPE, _CONV_FUNC)			\
      {									\
        unsigned _TYPE tmp;						\
	char buffer[sizeof(unsigned _TYPE)];				\
        tmp = _CONV_FUNC (*(unsigned _TYPE*)_PTR);			\
	memcpy (buffer, &tmp, sizeof(unsigned _TYPE));			\
	[_stream writeBytes: buffer length: (sizeof(unsigned _TYPE))];	\
      }

#define WRITE_UNSIGNED_TYPE(_PTR, _TYPE, _CONV_FUNC)		\
      {								\
	if (format_version == FORMAT_VERSION)	\
	  WRITE_UNSIGNED_TYPE0 (_PTR, _TYPE, _CONV_FUNC)	\
	else							\
	  WRITE_UNSIGNED_TYPE1 (_PTR, _TYPE, _CONV_FUNC)	\
      }

#define READ_UNSIGNED_TYPE0(_PTR, _TYPE, _CONV_FUNC)		\
      {								\
	char size;						\
	[_stream readByte: &size];				\
	{							\
	  char buffer[size];					\
	  int read_size;					\
	  read_size = [_stream readBytes: buffer length: size];	\
	  NSAssert (read_size == size, @"expected more input");	\
	  NSAssert (size == sizeof(_TYPE), @"inconsistent size");\
	  *(_TYPE*)_PTR =					\
	    _CONV_FUNC (*(_TYPE*)buffer);			\
	}							\
      }

#define READ_UNSIGNED_TYPE1(_PTR, _TYPE, _CONV_FUNC)		\
      {								\
        int size = _sizeof_ ## _TYPE;				\
	char buffer[size];					\
	int read_size;						\
	read_size = [_stream readBytes: buffer length: size];	\
	NSAssert (read_size == size, @"expected more input");	\
	/* xxx Remove this next requirement eventually */	\
	NSAssert (size == sizeof(_TYPE), @"inconsistent size");	\
	*(unsigned _TYPE*)_PTR =				\
	  _CONV_FUNC (*(unsigned _TYPE*)buffer);		\
      }

#define READ_UNSIGNED_TYPE(_PTR, _TYPE, _CONV_FUNC) \
		{ \
		if (format_version == FORMAT_VERSION) \
			READ_UNSIGNED_TYPE0 (_PTR, _TYPE, _CONV_FUNC) \
		else \
			READ_UNSIGNED_TYPE1 (_PTR, _TYPE, _CONV_FUNC) \
		}

@implementation BinaryCStream

+ (void) initialize
{											// Make sure that we don't overrun 
	if (self == [BinaryCStream class])		// memory when reading _C_CHARPTR.
   		NSAssert (sizeof(unsigned) >= NUM_BYTES_STRING_LENGTH, 
					@"_C_CHARPTR overruns memory");
}

+ (void) _setDebugging:(BOOL)f				{ __debug_binary_coder = f; }

+ (TextCStream *) debugStderrCoder
{
	static id c = nil;

	return (c) ? c : (c = [[TextCStream alloc] initForWritingToStream:nil]);
}
										// designated initializer for reading
- _initForReadingFromPostSignatureStream:(id <Streaming>)s
					   withFormatVersion:(int)version
{
	[super _initForReadingFromPostSignatureStream: s
		   withFormatVersion: version];
	if (version > FORMAT_VERSION)
		{								// Read the C-type sizes to expect.
		[s readByte: &_sizeof_long];
		[s readByte: &_sizeof_int];
		[s readByte: &_sizeof_short];
		[s readByte: &_sizeof_char];
		}

	return self;
}
										// designated initializer for writing.
- (id) initForWritingToStream:(id <Streaming>)s withFormatVersion:(int)version
{
	[super initForWritingToStream:s withFormatVersion:version];
	if (version > FORMAT_VERSION)
		{
		[s writeByte: sizeof (long)];
		[s writeByte: sizeof (int)];
		[s writeByte: sizeof (short)];
		[s writeByte: sizeof (char)];
		}

	return self;
}
												// Encoding/decoding C values
- (void) encodeValueOfCType:(const char*)type	 
						 at:(const void*)d 
						 withName:(NSString*)name
{
	if (!type)
		[NSException raise:NSInvalidArgumentException format:@"type is NULL"];

				// Make sure we're not being asked to encode an "ObjC" type.
	NSAssert(*type != '@', @"tried to encode an \"ObjC\" type");
	NSAssert(*type != '^', @"tried to encode an \"ObjC\" type");
	NSAssert(*type != ':', @"tried to encode an \"ObjC\" type");
	
	if (__debug_binary_coder)
		[[[self class] debugStderrCoder] encodeValueOfCType: type
										 at: d
										 withName: name];
	[_stream writeByte: *type];

	switch (*type)
		{
		case _C_CHARPTR:
			{
			unsigned length = strlen (*(char**)d);
			unsigned nlength = htonl (length);

			[_stream writeBytes: &nlength length: NUM_BYTES_STRING_LENGTH];
			[_stream writeBytes: *(char**)d length: length];
			break;
			}

		case _C_CHR:
		case _C_UCHR:
			[_stream writeByte: *(unsigned char*)d];
			break;
									// Reading and writing signed scalar types.
		case _C_SHT:
			WRITE_SIGNED_TYPE (d, short, htons);
			break;
		case _C_USHT:
			WRITE_UNSIGNED_TYPE (d, short, htons);
			break;
	
		case _C_INT:
			WRITE_SIGNED_TYPE (d, int, htonl);
			break;
		case _C_UINT:
			WRITE_UNSIGNED_TYPE (d, int, htonl);
			break;
	
		case _C_LNG:
			WRITE_SIGNED_TYPE (d, long, htonl);
			break;
		case _C_ULNG:
			WRITE_UNSIGNED_TYPE (d, long, htonl);
			break;

		case _C_LNG_LNG:
			WRITE_SIGNED_TYPE (d, long long, htonl);
			break;
		case _C_ULNG_LNG:
			WRITE_UNSIGNED_TYPE (d, long long, htonl);
			break;

    /* xxx The handling of floats and doubles could be improved.
       e.g. I should account for varying sizeof(int) vs sizeof(double). */

		case _C_FLT:
			{
			float fvalue;
			double value;
			int exponent, mantissa;
			short exponent_encoded;
		
			memcpy (&fvalue, d, sizeof (float));
			value = fvalue;
			/* Get the exponent */
			value = frexp (value, &exponent);
			exponent_encoded = exponent;
			NSParameterAssert (exponent_encoded == exponent);
			/* Get the mantissa. */
			value *= FLOAT_FACTOR;
			mantissa = value;
			NSAssert (value - mantissa == 0,
				@"mantissa and value should be the same");
			/* Encode the value as its two integer components. */
			WRITE_SIGNED_TYPE (&exponent_encoded, short, htons);
			WRITE_SIGNED_TYPE (&mantissa, int, htonl);
			break;
			}

		case _C_DBL:
			{
			double value;
			int exponent, mantissa1, mantissa2;
			short exponent_encoded;
		
			memcpy (&value, d, sizeof (double));
			/* Get the exponent */
			value = frexp (value, &exponent);
			exponent_encoded = exponent;
			NSParameterAssert (exponent_encoded == exponent);
			/* Get the first part of the mantissa. */
			value *= FLOAT_FACTOR;
			mantissa1 = value;
			value -= mantissa1;
			value *= FLOAT_FACTOR;
			mantissa2 = value;
			NSAssert (value - mantissa2 == 0,
				@"mantissa2 and value should be the same");
			/* Encode the value as its three integer components. */
			WRITE_SIGNED_TYPE (&exponent_encoded, short, htons);
			WRITE_SIGNED_TYPE (&mantissa1, int, htonl);
			WRITE_SIGNED_TYPE (&mantissa2, int, htonl);
			break;
			}

		case _C_ARY_B:
			{
			int len = atoi (type+1);	/* xxx why +1 ? */
			int offset;
			char *dc = (char*)d;
		
			while (isdigit(*++type));
				offset = objc_sizeof_type(type);
			[self encodeName:name];
			[self encodeIndent];
			while (len-- > 0)
				{
				/* Change this so we don't re-write type info every time. */
				/* xxx We should be able to encode arrays "ObjC" types also! */
				[self encodeValueOfCType:type at:dc withName:@"array element"];
				dc += offset;
				}
			[self encodeUnindent];
			break; 
			}
		case _C_STRUCT_B:
			{
			int acc_size = 0;
			int align;
		
			while (*type != _C_STRUCT_E && *type++ != '='); // skip "<name>="
			[self encodeName:name];
			[self encodeIndent];
			while (*type != _C_STRUCT_E)
				{
				align = objc_alignof_type (type);			// pad to alignment
				acc_size = ROUND (acc_size, align);
				// We should be able to encode structs "ObjC" types also!
				[self encodeValueOfCType:type 
					  at:((char*)d)+acc_size 
					  withName:@"structure component"];
				acc_size += objc_sizeof_type (type); /* add component size */
				type = objc_skip_typespec (type);	/* skip component */
				}
			[self encodeUnindent];
			break;
			}
		default:
			[NSException raise: NSGenericException 
						 format: @"Unrecognized type %s", type];
		}
}

- (void) decodeValueOfCType:(const char*)type
						 at:(void*)d 
						 withName:(NSString **)namePtr
{
	char encoded_type;

	if (!type)
		[NSException raise:NSInvalidArgumentException format:@"type is NULL"];

	NSAssert(*type != '@', @"tried to decode an \"ObjC\" type");
	NSAssert(*type != '^', @"tried to decode an \"ObjC\" type");
	NSAssert(*type != ':', @"tried to decode an \"ObjC\" type");

	[_stream readByte: &encoded_type];
	if (encoded_type != *type && !((encoded_type=='c' || encoded_type=='C') 
			&& (*type=='c' || *type=='C')))
		[NSException raise: NSGenericException
					 format: @"Expected type \"%c\", got type \"%c\"",
							*type, encoded_type];

	switch (encoded_type)
		{
		case _C_CHARPTR:
			{
			unsigned length;
			unsigned read_count = [_stream readBytes: &length
										   length: NUM_BYTES_STRING_LENGTH];
			NSAssert2 (read_count == NUM_BYTES_STRING_LENGTH,
					@"expected %d bytes of input, got %d",
					NUM_BYTES_STRING_LENGTH,read_count);
			length = ntohl (length);
			*(char**)d = malloc ((length+1) * sizeof(char));
			read_count = [_stream readBytes: *(char**)d length: length];
			NSAssert2 (read_count == length,
					@"expected %d bytes of input, got %d",length,read_count);
			(*(char**)d)[length] = '\0';
//				Autorelease the newly malloc'ed pointer?  Grep for (*free)
//				to see the places the may have to be changed
//			[NSData dataWithBytesNoCopy: *(void**)d length: length+1];
			break;
			}

		case _C_CHR:
		case _C_UCHR:
			[_stream readByte: (unsigned char*)d];
			break;
		
		case _C_SHT:
			READ_SIGNED_TYPE (d, short, ntohs);
			break;

		case _C_USHT:
			READ_UNSIGNED_TYPE (d, short, ntohs);
			break;
		
		case _C_INT:
			READ_SIGNED_TYPE (d, int, ntohl);
			break;

		case _C_UINT:
			READ_UNSIGNED_TYPE (d, int, ntohl);
			break;
		
		case _C_LNG:
			READ_SIGNED_TYPE (d, long, ntohl);
			break;

		case _C_ULNG:
			READ_UNSIGNED_TYPE (d, long, ntohl);
			break;
		
		case _C_LNG_LNG:
			READ_SIGNED_TYPE (d, long, ntohl);
			break;

		case _C_ULNG_LNG:
			READ_UNSIGNED_TYPE (d, long, ntohl);
			break;

		case _C_FLT:
			{
			short exponent;
			int mantissa;
			double value;
			float fvalue;
			
			/* Decode the exponent and mantissa. */
			READ_SIGNED_TYPE (&exponent, short, ntohs);
			READ_SIGNED_TYPE (&mantissa, int, ntohl);
			/* Assemble them into a double */
			value = mantissa / FLOAT_FACTOR;
			value = ldexp (value, exponent);
			/* Put the double into the requested memory location as a float */
			fvalue = value;
			memcpy (d, &fvalue, sizeof (float));
			break;
			}
		
		case _C_DBL:
			{
			short exponent;
			int mantissa1, mantissa2;
			double value;
			
			/* Decode the exponent and the two pieces of the mantissa. */
			READ_SIGNED_TYPE (&exponent, short, ntohs);
			READ_SIGNED_TYPE (&mantissa1, int, ntohl);
			READ_SIGNED_TYPE (&mantissa2, int, ntohl);
			/* Assemble them into a double */
			value = ((mantissa2 / FLOAT_FACTOR) + mantissa1) / FLOAT_FACTOR;
			value = ldexp (value, exponent);
			/* Put the double into the requested memory location. */
			memcpy (d, &value, sizeof (double));
			break;
			}
		
		case _C_ARY_B:
			{			// Do we need to allocate space, just like _C_CHARPTR ?
			int len = atoi(type+1);
			int offset;
			char *dc = (char*)d;

			[self decodeName:namePtr];
			[self decodeIndent];
			while (isdigit(*++type));
				offset = objc_sizeof_type(type);
			while (len-- > 0)
				{
				[self decodeValueOfCType:type at:dc withName:namePtr];
				dc += offset;
				}
			[self decodeUnindent];
			break; 
			}

		case _C_STRUCT_B:
			{			// Do we need to allocate space just like char* ?  No.
			int acc_size = 0;
			int align;
			const char *save_type = type;
			
			while (*type != _C_STRUCT_E && *type++ != '='); // skip "<name>="
				[self decodeName:namePtr];
			[self decodeIndent];		/* xxx insert [self decodeName:] */
			while (*type != _C_STRUCT_E)
				{
				align = objc_alignof_type (type); /* pad to alignment */
				acc_size = ROUND (acc_size, align);
				[self decodeValueOfCType:type 
					  at:((char*)d)+acc_size 
					  withName:namePtr];
				acc_size += objc_sizeof_type (type); /* add component size */
				type = objc_skip_typespec (type); /* skip component */
				}
			type = save_type;
			[self decodeUnindent];
			break;
			}

		default:
			[NSException raise: NSGenericException 
						 format: @"Unrecognized Type %s", type];
		}

	if (__debug_binary_coder)
		[[[self class] debugStderrCoder] encodeValueOfCType:type
										 at:d
										 withName:@"decoding unnamed"];
}

+ (int) defaultFormatVersion			{ return PORT_CODER_FORMAT_VERSION; }

- (void) encodeName:(NSString*)name			// Encoding and decoding names.
{
	if (__debug_binary_coder)
		[[[self class] debugStderrCoder] encodeName:name];
}

- (void) decodeName:(NSString**)n
{
	if (n)
		*n = nil;
}

@end /* BinaryCStream */
