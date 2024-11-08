/*
   NSString.m

   String classes.

   Copyright (C) 1995-2021 Free Software Foundation, Inc.

   Author:	Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date:	January 1995
   Unicode: Stevo Crvenkovski <stevo@btinternet.com>
   Date:	February 1997
   Update:	Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date:	October 1998
   mGSTEP:	Felipe A. Rodriguez <far@illumenos.com>
   Date:	Mar 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFString.h>

#include <Foundation/NSString.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSException.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSData.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/Private/unicode.h>

#include <sys/stat.h>

#define HASH_STR_LENGTH		63
#define MAXDEC 				18


static Class __nsStringClass;				// Abstract superclass
static Class __constantStringClass;
static Class __uStrClass;					// unichar strings
static Class __mutableUStringClass;
static Class __cStringClass;				// cStrings 
static Class __mutableCStringClass;

static NSUInteger (*__sHashImp)();

static unichar __pathSepChar = (unichar)'/';
static NSCharacterSet *__pathSep = nil;


/* ****************************************************************************

 		_CSequence		(composite) Character Sequence

** ***************************************************************************/

@interface _CSequence : NSObject
{
	unichar *_uniChars;
	NSUInteger _count;
	BOOL _normalized;
}

+ (_CSequence *) sequenceWithString:(NSString*)aString range:(NSRange)aRange;

- (_CSequence *) decomposeAndOrder;
- (_CSequence *) lowercase;
- (BOOL) isEqual:(_CSequence *)aSequence;
- (NSComparisonResult) compare:(_CSequence *)aSequence;

@end

@implementation _CSequence

+ (_CSequence *) sequenceWithString:(NSString *)aString range:(NSRange)r
{
	NSUInteger stringLength = [aString length];
	_CSequence *sq;

	if (r.location > stringLength)
		[NSException raise: NSRangeException format:@"Invalid location."];
	if (r.length > (stringLength - r.location))
		[NSException raise:NSRangeException format:@"Invalid location+length"];

	sq = [self alloc];
	sq->_uniChars = malloc ((r.length+1) * sizeof(unichar));
	[aString getCharacters:sq->_uniChars range: r];
	sq->_uniChars[r.length] = (unichar)0;
	sq->_count = r.length;

	return [sq autorelease];
}

- (void) dealloc
{
	free(_uniChars), 	_uniChars = NULL;

	[super dealloc];
}

- (_CSequence *) decomposeAndOrder
{
	if (_count)											// decompose sequence
		{
		unichar source[((_count * MAXDEC+1) * sizeof(unichar))];
		unichar target[((_count * MAXDEC+1) * sizeof(unichar))];
		unichar *spoint = source;
		unichar *tpoint = target;
		unichar *dpoint;
		BOOL notdone;
		NSUInteger len;

		memcpy(source, _uniChars, 2*_count);
		source[_count] = (unichar)(0);

		do {
			notdone = NO;
			do {
				if(!(dpoint = uni_is_decomp(*spoint)))
					*tpoint++ = *spoint;
				else
					{
					while(*dpoint)
						*tpoint++ = *dpoint++;
					notdone = YES;
				}	}
			while(*spoint++);
		
			*tpoint = (unichar)0;  								// needed ?
			memcpy(source, target, 2 * (_count * MAXDEC +1));
			tpoint = target;
			spoint = source;
			} 
		while(notdone);

		len = uslen(source);
		_uniChars = realloc (_uniChars, (len+1) * sizeof(unichar));
		memcpy(_uniChars, source, 2*(len+1));
		_uniChars[len] = (unichar)0;
		_count = len;

		do {											// order sequence
			NSUInteger count = 1;
			unichar *first = _uniChars;
			unichar *second = first+1;
			unichar tmp;

			for(notdone = NO; count < _count; count++)
				{
				if(uni_cop(*second))
					{
					if(uni_cop(*first) > uni_cop(*second))
						{
						tmp = *first;
						*first = *second;
						*second = tmp;
						notdone = YES;
						}
					if(uni_cop(*first) == uni_cop(*second))
						if(*first > *second)
							{
							tmp = *first;
							*first = *second;
							*second = tmp;
							notdone = YES;
					}		}
				first++;
				second++;
			}	}
		while(notdone);

		_normalized = YES;
		}

	return self;
}

- (_CSequence*) lowercase
{
	_CSequence *sq = [_CSequence alloc];
	NSUInteger count;

	sq->_uniChars = malloc ((_count+1) * sizeof(unichar));
	for(count = 0; count < _count; count++)
		sq->_uniChars[count] = uni_tolower(_uniChars[count]);
	sq->_uniChars[_count] = (unichar)0;
	sq->_count = _count;

	return [sq autorelease];
}

- (BOOL) isEqual:(_CSequence*)aSequence
{
	return [self compare:aSequence] == NSOrderedSame;
}

- (NSComparisonResult) compare:(_CSequence*)aSequence
{
	NSUInteger i, end;									// Inefficient
 
	if (!_normalized)
		[self decomposeAndOrder];
	if (!aSequence->_normalized)
		[aSequence decomposeAndOrder];					// determine shortest
														// sequence's end
	end = (_count < aSequence->_count) ? _count : aSequence->_count;

	for (i = 0; i < end; i ++)
		{
		if (_uniChars[i] < aSequence->_uniChars[i]) 
			return NSOrderedAscending;
		if (_uniChars[i] > aSequence->_uniChars[i]) 
			return NSOrderedDescending;
		}

	if(_count < aSequence->_count)
		return NSOrderedAscending;

	return (_count > aSequence->_count) ? NSOrderedDescending : NSOrderedSame;
}

@end

/* ****************************************************************************

 		NSString

** ***************************************************************************/

static char *
_AllocCString( char *content, NSUInteger size, const char *bytes)
{
    if ((content = realloc(content, size+1)) && bytes)
		memcpy(content, bytes, size), content[size] = '\0';

    return content;
}


@implementation NSString

+ (void) initialize
{
	if (self == [NSString class])
		{
		__nsStringClass = self;
  		__constantStringClass = [NSConstantString class];
		__uStrClass = [_NSUString class];
		__cStringClass = [_NSCString class];
		__mutableUStringClass = [_NSMutableUString class];
		__mutableCStringClass = [_NSMutableCString class];
											// Cache method implementations
		__sHashImp = (NSUInteger (*)())
				[self instanceMethodForSelector: @selector(hash)];
#if defined(__WIN32__) || defined(_WIN32)
		__pathSep = [NSCharacterSet characterSetWithCharactersInString:@"/\\"];
		__pathSepChar = (unichar)0x005c;
#else
		__pathSep = [NSCharacterSet characterSetWithCharactersInString: @"/"];
#endif
		[__pathSep retain];
		}
}

+ (id) alloc						{ return NSAllocateObject(__uStrClass); }
+ (id) string						{ return [[self new] autorelease]; }

+ (id) stringWithString:(NSString*)aString
{
	return [[[self alloc] initWithString: aString] autorelease];
}

+ (id) stringWithCharacters:(const unichar*)chars length:(NSUInteger)length
{
	return [[[self alloc] initWithCharacters:chars length:length] autorelease];
}

+ (id) stringWithUTF8String:(const char*)bytes
{
	return [[[_NSUString alloc] initWithUTF8String:bytes] autorelease];
}

+ (id) stringWithCString:(const char*)bytes
{
	return [[[_NSCString alloc] initWithCString:bytes] autorelease];
}

+ (id) stringWithCString:(const char*)bytes length:(NSUInteger)len
{
	return [[[_NSCString alloc] initWithCString:bytes length:len] autorelease];
}

+ (id) stringWithContentsOfFile:(NSString *)path
{
	return [[[self alloc] initWithContentsOfFile: path] autorelease];
}

+ (id) stringWithFormat:(NSString*)format,...
{
	va_list ap;
	id r;

	va_start(ap, format);
	r = [[[self alloc] initWithFormat:format arguments:ap] autorelease];
	va_end(ap);

	return r;
}

+ (id) stringWithFormat:(NSString*)format arguments:(va_list)args
{
	return [[[self alloc] initWithFormat:format arguments:args] autorelease];
}

+ (NSString *) localizedNameOfStringEncoding:(NSStringEncoding)e
{													// s/b path to localizable
	id b = [NSBundle bundleWithPath:@"/"];			// strings file.  Until we
	id n = (id)CFStringGetNameOfEncoding(e);		// have it, just make sure
													// bundle is initialized.
	return [b localizedStringForKey:n value:n table:nil];
}

+ (NSStringEncoding) defaultCStringEncoding
{
	return CFStringGetSystemEncoding();
}

+ (const NSStringEncoding *) availableStringEncodings
{
	return CFStringGetListOfAvailableEncodings();
}

- (id) initWithCString:(const char*)byteString length:(NSUInteger)length
{
	return [self initWithCStringNoCopy: _AllocCString(NULL, length, byteString)
				 length:length
				 freeWhenDone:YES];
}

- (id) initWithCString:(const char*)byteString
{
	NSUInteger length = (byteString ? strlen(byteString) : 0);
	char *s = _AllocCString(NULL, length, byteString);

	return [self initWithCStringNoCopy:s length:length freeWhenDone:YES];
}

- (id) initWithUTF8String:(const char *)byteString
{
	NSUInteger i, j, k, length = (byteString ? strlen(byteString) : 0);
	UInt32 ucs4;
	unichar	*p, *s;

	for (i = 0, k = 0; i < length; i += j, k++)
		if ((j = _UTF8toUCS4(&((byteString)[i]), &ucs4, length - i)) < 1)
			return _NSInitError(self, @"UTF8 conversion failed");

	s = p = malloc(sizeof(unichar) * (k = MAX(1,k)));
	for (i = 0; i < length; i += j)
		{
		j = _UTF8toUCS4(&((byteString)[i]), &ucs4, length - i);
		*p++ = ucs4;				// FIX ME truncs unicode > 16bits
		}

	return [self initWithCharactersNoCopy:s length:k freeWhenDone:YES];
}

- (id) initWithString:(NSString*)string
{
	NSUInteger l = [string length];
	unichar	*s = malloc(sizeof(unichar) * l);

	[string getCharacters:s];

	return [self initWithCharactersNoCopy:s length:l freeWhenDone:YES];
}

- (id) initWithCharacters:(const unichar*)chars length:(NSUInteger)length
{
	unichar	*s = malloc(sizeof(unichar)*length);

	if (chars)
		memcpy(s, chars, sizeof(unichar) * length);

	return [self initWithCharactersNoCopy:s length:length freeWhenDone:YES];
}

- (id) initWithFormat:(NSString*)format,...
{
	va_list ap;

	va_start(ap, format);
	self = [self initWithFormat:format arguments:ap];
	va_end(ap);

	return self;
}

- (id) initWithFormat:(NSString*)format arguments:(va_list)arg_list
{
	const char *format_cp = [format cString];		// Change this when we have 
	int format_len = strlen (format_cp);			// non-CString classes
	char format_cp_copy[format_len+1];
	char *format_to_go = format_cp_copy;
	char *at_pos;				// points to a location inside format_cp_copy
	unsigned len;
	unsigned printed_len = 0;
	int wr;
	int bufSize = 8000 + format_len;		// FIX ME max str args size hardcode
	char *buf = malloc(bufSize);

    strcpy (format_cp_copy, format_cp);		// make local copy for tmp editing
								
	while ((at_pos = strstr (format_to_go, "%@")))	// Loop once for each `%@'
		{											// in the format string
		const char *cstring;
		char *formatter_pos; 						// Position for formatter.
		va_list args_cpy;

			// If there is a "%%@", then do the right thing: print it literally
		if ((*(at_pos-1) == '%') && at_pos != format_cp_copy)
			continue;

		*at_pos = '\0';		// tmp terminate the string before the `%@'
		len = bufSize - printed_len;

		va_copy(args_cpy, arg_list);	// Print the part before the '%@'
		if ((wr = vsnprintf (buf+printed_len, len, format_to_go, args_cpy)) < 0)
			{
			fprintf(stderr,"NSString initWithFormat: vsnprintf err (%d)\n", wr);
			[NSException raise: NSGenericException format:@"vsnprintf error"];
			}
		va_end(args_cpy);
		printed_len += wr;
										// Skip arguments used in last vsprint
		while ((formatter_pos = strchr(format_to_go, '%')))	 
			{
			char *spec_pos; 			// Position of conversion specifier

			if (*(formatter_pos+1) == '%')
				{
				format_to_go = formatter_pos+2;
				continue;
				}							
											// Format specifiers K&R C 2nd ed.
			spec_pos = strpbrk(formatter_pos+1, "dioxXucsfeEgGpn\0");
			switch (*spec_pos)
				{
				case 'd': case 'i': case 'o':
				case 'x': case 'X': case 'u': case 'c':
					va_arg(arg_list, int);
					break;
				case 's':
					if (*(spec_pos - 1) == '*')
						va_arg(arg_list, int*);
					va_arg(arg_list, char*);
					break;
				case 'f': case 'e': case 'E': case 'g': case 'G':
					va_arg(arg_list, double);
					break;
				case 'p':
					va_arg(arg_list, void*);
					break;
				case 'n':
					va_arg(arg_list, int*);
					break;
				case '\0':							// Make sure loop exits on 
					spec_pos--;						// next iteration
					break;
				}
			format_to_go = spec_pos+1;
			}								// Get a C-string from the String
											// object, and print it
		if (!(cstring = [[(id) va_arg (arg_list, id) description] cString]))
			cstring = "<null string>";
		len = strlen (cstring); 

		if ((printed_len + len + format_len + 2048) > bufSize)
			{
			bufSize = printed_len + format_len + len + 4096;
			buf = realloc(buf, bufSize);
			}

		strcat (buf+printed_len, cstring);
		printed_len += len;
		format_to_go = at_pos + 2;					// Skip over this `%@', and
		}											// look for another one.

	len = bufSize - printed_len;	// Print remaining string after last `%@'
    if ((wr = vsnprintf (buf+printed_len, len, format_to_go, arg_list)) < 0)
		{
		fprintf(stderr,"NSString initWithFormat: vsnprintf err (%d)\n", wr);
		[NSException raise: NSGenericException format:@"vsnprintf error"];
		}
	printed_len += wr;

	if(printed_len > bufSize)						// Raise an exception if we
		{											// overran the buffer.
		fprintf(stderr,"NSString initWithFormat: buf = %d, len = %d\n", 
				bufSize, printed_len);
		[NSException raise: NSRangeException format:@"printed_len > bufSize"];
		}

	buf = realloc(buf, printed_len+1);
	buf[printed_len] = '\0';

    return [self initWithCStringNoCopy:buf length:printed_len freeWhenDone:1];
}

- (id) initWithData:(NSData*)data encoding:(NSStringEncoding)encoding
{
	NSUInteger len = [data length];
	NSUInteger count;
	unichar *u;
	const unsigned char *b;

	if ((encoding == NSASCIIStringEncoding)
			|| (encoding == NSUTF8StringEncoding)
			|| (encoding == NSISOLatin1StringEncoding)
			|| (encoding == NSWindowsCP1252StringEncoding)
			|| (encoding == NSISOLatin2StringEncoding)
			|| (encoding == NSMacOSRomanStringEncoding)
			|| (encoding == NSNEXTSTEPStringEncoding)
			|| (encoding == NSNonLossyASCIIStringEncoding))
		{
		char *s = calloc(1,len+1);

		[data getBytes:s length:len];

		return [self initWithCStringNoCopy:s length:len freeWhenDone:YES];
		}

	u = malloc(sizeof(unichar)*(len+1));
	b = [data bytes];
	if (encoding == NSUnicodeStringEncoding)
		{
		if ((b[0] == 0xFE) && (b[1] == 0xFF))
			for(count = 2; count < (len-1); count += 2)
				u[count/2 - 1] = 256 * b[count] + b[count+1];
		else
			for(count = 2; count < (len-1); count += 2)
				u[count/2 -1] = 256 * b[count+1] + b[count];
		count = count/2 -1;
		}
	else
		count = encode_strtoustr(u, b, len, encoding);

	return [self initWithCharactersNoCopy:u length:count freeWhenDone:YES];
}

- (id) initWithContentsOfFile:(NSString*)path
{
	id d = [NSData dataWithContentsOfFile: path];
	const unsigned char *t = [d bytes];
	NSStringEncoding e;

	if (d == nil || [d length] <= 2)
		return _NSInitError(self, @"Failed to open file %@", path);

	if(t && (((t[0]==0xFF) && (t[1]==0xFE)) || ((t[1]==0xFF) && (t[0]==0xFE))))
		e = NSUnicodeStringEncoding;			// FIX ME a BOM is optional
	else
		e = [NSString defaultCStringEncoding];

	return [self initWithData:d encoding:e];
}

- (id) mutableCopy
{
	return [[__mutableUStringClass alloc] initWithString:self];
}

- (id) copy											{ return [self retain]; }
- (NSUInteger) length								{ return _count; }
- (NSString*) description							{ return self; }
- (const char *) cString							{ return _cString; }
- (const char *) UTF8String							{ return _cString; }

- (const char *) cStringUsingEncoding:(NSStringEncoding)e
{
	return (e == NSISOLatin1StringEncoding || e == NSASCIIStringEncoding)
			? [self cString] : [self UTF8String];
}

- (NSString*) stringByAppendingFormat:(NSString*)format,...
{
	va_list ap;
	NSString *s;

	va_start(ap, format);
	s = [NSString stringWithFormat:format arguments:ap];
	s = [self stringByAppendingString: s];
	va_end(ap);

	return s;
}

- (NSString*) stringByAppendingString:(NSString*)aString
{
	NSUInteger otherLength = [aString length];
	unichar *s = malloc((_count + otherLength) * sizeof(unichar));

	[self getCharacters:s];
	[aString getCharacters: s + _count];

	return [[[[self class] alloc] initWithCharactersNoCopy: s
								  length: _count + otherLength 
								  freeWhenDone: YES] autorelease];
}

- (NSArray*) componentsSeparatedByString:(NSString*)separator
{														// Dividing a String 
	NSRange search = {0, _count};						// into Substrings
	NSMutableArray *array = [NSMutableArray array];
	NSRange found = [self rangeOfString:separator options:2 range:search];

	while (found.length)
		{
		search.length = found.location - search.location;
		[array addObject: [self substringWithRange: search]];
		search.location = NSMaxRange(found);
		search.length = _count - search.location;
		found = [self rangeOfString:separator options:0 range:search];
		}
														// Add the last search 
	if (search.length)									// string range
		[array addObject: [self substringWithRange: search]];
	
	return array;
}

- (NSString*) substringFromIndex:(NSUInteger)index
{
	return [self substringWithRange:((NSRange){index, _count - index})];
}

- (NSString*) substringWithRange:(NSRange)aRange
{
	unichar *buf;

	if (NSMaxRange(aRange) > _count)
		[NSException raise:NSRangeException format:@"Invalid location+length"];

	if(!(buf = malloc(sizeof(unichar) * aRange.length)))
		[NSException raise: NSMallocException format: @"Unable to allocate"];
	[self getCharacters:buf range:aRange];

	return [[[[self class] alloc] initWithCharactersNoCopy: buf
								  length: aRange.length
								  freeWhenDone: YES] autorelease];
}

- (NSString*) substringToIndex:(NSUInteger)index
{
	return [self substringWithRange:((NSRange){0, index})];
}

- (NSRange) rangeOfCharacterFromSet:(NSCharacterSet*)s
{														 
	return [self rangeOfCharacterFromSet:s options:0 range:(NSRange){0,_count}];
}

- (NSRange) rangeOfCharacterFromSet:(NSCharacterSet*)s options:(unsigned int)m
{
	return [self rangeOfCharacterFromSet:s options:m range:(NSRange){0,_count}];
}

- (NSRange) rangeOfCharacterFromSet:(NSCharacterSet*)aSet
							options:(unsigned int)mask
							range:(NSRange)aRange
{
	NSUInteger i = _count, start, stop, step;
	NSRange range = {0, 0};
	unichar (*cImp)(id, SEL, NSUInteger) = (unichar(*)(id,SEL,NSUInteger)) 
    				[self methodForSelector: @selector(characterAtIndex:)];
	BOOL (*mImp)(id, SEL, unichar) = (BOOL(*)(id,SEL,unichar))
					[aSet methodForSelector: @selector(characterIsMember:)];

	if (aRange.location > i)
		[NSException raise: NSRangeException format:@"Invalid location."];
	if (aRange.length > (i - aRange.location))
		[NSException raise:NSRangeException format:@"Invalid location+length"];

	if ((mask & NSBackwardsSearch) == NSBackwardsSearch)
		{
		start = NSMaxRange(aRange) - 1; 
		stop = aRange.location - 1; 
		step = -1;
		}
	else
		{
		start = aRange.location; 
		stop = NSMaxRange(aRange); 
		step = 1;
		}

	for (i = start; i != stop; i += step)
		{
		unichar letter = (unichar)(*cImp)(self,@selector(characterAtIndex:),i);

		if ((*mImp)(aSet, @selector(characterIsMember:), letter))
			{
			range = (NSRange){i, 1};
			break;
		}	}

	return range;
}

- (NSRange) rangeOfString:(NSString*)string
{
	return [self rangeOfString:string options:2 range:(NSRange){0, _count}];
}

- (NSRange) rangeOfString:(NSString*)string options:(unsigned int)mask
{
	return [self rangeOfString:string options:mask range:(NSRange){0, _count}];
}

- (NSRange) rangeOfString:(NSString *) aString
				  options:(unsigned int) mask
				  range:(NSRange) aRange
{
	NSUInteger strLength;
	NSUInteger maxRange = NSMaxRange(aRange);

	if (maxRange > _count)
		[NSException raise:NSRangeException format:@"Invalid location+length"];

	if ((strLength = [aString length]) > aRange.length || strLength == 0)
		return (NSRange){0, 0};

	switch (mask)
		{
		case 3:
		case 11:
			{						// search forward case insensitive literal
			NSUInteger si = aRange.location;
			NSUInteger ei = (mask & NSAnchoredSearch) ? si : maxRange - strLength;
			unichar firstChar = [aString characterAtIndex:0];
			
			for (;;)
				{
				NSUInteger i = 1;
				unichar mc = [self characterAtIndex:si];
				unichar sc = firstChar;
			
				for (;;)
					{
					if ((mc != sc) && (uni_tolower(mc) != uni_tolower(sc)))
						break;
					if (i == strLength)
						return (NSRange){si, strLength};
					mc = [self characterAtIndex:si + i];
					sc = [aString characterAtIndex:i];
					i++;
					}
				if (si == ei)
					break;
				si++;
			}	}
			break;

		case 7:
		case 15:
			{						// search backward case insensitive literal
			NSUInteger si = maxRange - strLength;
			NSUInteger ei = (mask & NSAnchoredSearch) ? si : aRange.location;
			unichar firstChar = [aString characterAtIndex:0];
			
			for (;;)
				{
				NSUInteger i = 1;
				unichar mc = [self characterAtIndex:si];
				unichar sc = firstChar;
			
				for (;;)
					{
					if ((mc != sc) && (uni_tolower(mc) != uni_tolower(sc)))
						break;
					if (i == strLength)
						return (NSRange){si, strLength};
					mc = [self characterAtIndex:si + i];
					sc = [aString characterAtIndex:i];
					i++;
					}
				if (si == ei)
					break;
				si--;
			}	}
			break;

		case 2:
		case 10:
			{										// search forward literal
			NSUInteger si = aRange.location;
			NSUInteger ei = (mask & NSAnchoredSearch) ? si : maxRange - strLength;
			unichar (*a)(id, SEL, NSUInteger);		// get an IMP for aString's
			unichar (*b)(id, SEL, NSUInteger);		// method and one for self
			unichar firstChar;

			a = (unichar(*)(id,SEL,NSUInteger))
					[aString methodForSelector: @selector(characterAtIndex:)];
			b = (unichar(*)(id,SEL,NSUInteger))
					[self methodForSelector: @selector(characterAtIndex:)];
			firstChar = (*a)(aString, @selector(characterAtIndex:), 0);
			
			for (;;)
				{
				NSUInteger i = 1;
				unichar mc = (*b)(self, @selector(characterAtIndex:),si);
				unichar sc = firstChar;
			
				for (;;)
					{
					if (mc != sc)
						break;
					if (i == strLength)
						return (NSRange){si, strLength};
					mc = (*b)(self, @selector(characterAtIndex:),si + i);
					sc = (*a)(aString, @selector(characterAtIndex:), i);
					i++;
					}
				if (si == ei)
					break;
				si++;
			}	}
			break;

		case 6:
		case 14:
			{										// search backward literal
			NSUInteger si = maxRange - strLength;
			NSUInteger ei = (mask & NSAnchoredSearch) ? si : aRange.location;
			unichar firstChar = [aString characterAtIndex:0];
		
			for (;;)
				{
				NSUInteger i = 1;
				unichar mc = [self characterAtIndex:si];
				unichar sc = firstChar;
		
				for (;;)
					{
					if (mc != sc)
						break;
					if (i == strLength)
						return (NSRange){si, strLength};
					mc = [self characterAtIndex:si + i];
					sc = [aString characterAtIndex:i];
					i++;
					}
				if (si == ei)
					break;
				si--;
			}	}
			break;

		case 1:
		case 9:
			{								// search forward case insensitive
			NSUInteger strBaseLength = [aString _baseLength];
			NSUInteger si = aRange.location;
			NSUInteger ei = (mask & NSAnchoredSearch) ? si : maxRange - strBaseLength;
			NSRange r = [aString rangeOfComposedCharacterSequenceAtIndex: 0];
			_CSequence *firstCharSeq = [_CSequence sequenceWithString: aString range: r];
		
			for (;;)
				{
				NSRange s;
				NSRange m = [self rangeOfComposedCharacterSequenceAtIndex:si];
				NSUInteger cm = 1;
				NSUInteger cs = 1;
				_CSequence *sc = firstCharSeq;
				_CSequence *mc = [_CSequence sequenceWithString:self range:m];
		
				for (;;)
					{
					if (!([mc compare:sc] == NSOrderedSame)
							&& !([[mc lowercase] compare: [sc lowercase]] == NSOrderedSame))
						break;
					if (cs >= strLength)
						return (NSRange){si, cm};
					m = [self rangeOfComposedCharacterSequenceAtIndex: si + cm];
					mc = [_CSequence sequenceWithString: self range: m];
					s = [aString rangeOfComposedCharacterSequenceAtIndex:cs];
					sc = [_CSequence sequenceWithString:aString range:s];
					cm += m.length;
					cs += s.length;
					}  
				if (si >= ei)
					break;
				m = [self rangeOfComposedCharacterSequenceAtIndex: si];
				si += m.length;
			}	} 
			break;

		case 5:
		case 13:
			{								// search backward case insensitive
			NSUInteger strBaseLength = [aString _baseLength];
			NSUInteger si = maxRange - strBaseLength;
			NSUInteger ei = (mask & NSAnchoredSearch) ? si : aRange.location;
			NSRange r = [aString rangeOfComposedCharacterSequenceAtIndex: 0];
			id firstCharSeq = [_CSequence sequenceWithString:aString range:r];
		
			for (;;)
				{
				NSRange s;
				NSRange m = [self rangeOfComposedCharacterSequenceAtIndex:si];
				NSUInteger cm = 1;
				NSUInteger cs = 1;
				_CSequence *sc = firstCharSeq;
				_CSequence *mc = [_CSequence sequenceWithString:self range:m];

				for (;;)
					{
					if (!([mc compare:sc] == NSOrderedSame)
							&& !([[mc lowercase] compare: [sc lowercase]] == NSOrderedSame))
						break;
					if (cs >= strLength)
						return (NSRange){si, cm};
					m = [self rangeOfComposedCharacterSequenceAtIndex: si + cm];
					mc = [_CSequence sequenceWithString: self range: m];
					s = [aString rangeOfComposedCharacterSequenceAtIndex:cs];
					sc = [_CSequence sequenceWithString:aString range:s];
					cm += m.length;
					cs += s.length;
					}  
				if (si <= ei)
					break;
				si--;
				while(uni_isnonsp([self characterAtIndex:si]) && (si>0))
					si--;
			}	} 
			break;

		case 4:
		case 12:
			{												// search backward
			NSUInteger strBaseLength = [aString _baseLength];
			NSUInteger si = maxRange - strBaseLength;
			NSUInteger ei = (mask & NSAnchoredSearch) ? si : aRange.location;
			NSRange r = [aString rangeOfComposedCharacterSequenceAtIndex: 0];
			_CSequence *firstCharSeq = [_CSequence sequenceWithString:aString range:r];
		
			for (;;)
				{
				NSRange s;
				NSRange m = [self rangeOfComposedCharacterSequenceAtIndex:si];
				NSUInteger cm = 1;
				NSUInteger cs = 1;
				_CSequence *sc = firstCharSeq;
				_CSequence *mc = [_CSequence sequenceWithString:self range:m];

				for (;;)
					{
					if (!([mc compare:sc] == NSOrderedSame))
						break;
					if (cs >= strLength)
						return (NSRange){si, cm};
					m = [self rangeOfComposedCharacterSequenceAtIndex: si + cm];
					mc = [_CSequence sequenceWithString:self range: m];
					s = [aString rangeOfComposedCharacterSequenceAtIndex: cs];
					sc = [_CSequence sequenceWithString:aString range:s];
					cm += m.length;
					cs += s.length;
					}  
				if (si <= ei)
					break;
				si--;
				while(uni_isnonsp([self characterAtIndex: si]) && (si > 0))
					si--;
			}	} 
			break;

		case 0:
		case 8:
		default:
			{												// search forward
			NSUInteger strBaseLength = [aString _baseLength];
			NSUInteger si = aRange.location;
			NSUInteger ei = (mask & NSAnchoredSearch) ? si : maxRange - strBaseLength;
			NSRange r = [aString rangeOfComposedCharacterSequenceAtIndex:0];
			_CSequence *firstCharSeq = [_CSequence sequenceWithString:aString range:r];

			for (;;)
				{
				NSRange s;
				NSRange m = [self rangeOfComposedCharacterSequenceAtIndex:si];
				NSUInteger cm = 1;
				NSUInteger cs = 1;
				_CSequence *sc = firstCharSeq;
				_CSequence *mc = [_CSequence sequenceWithString:self range:m];
		
				for (;;)
					{
					if (!([mc compare:sc] == NSOrderedSame))
						break;
					if (cs >= strLength)
						return (NSRange){si, cm};
					m = [self rangeOfComposedCharacterSequenceAtIndex: si + cm];
					mc = [_CSequence sequenceWithString: self range: m];
					s = [aString rangeOfComposedCharacterSequenceAtIndex:cs];
					sc = [_CSequence sequenceWithString:aString range:s];
					cm += m.length;
					cs += s.length;
					}  
				if (si >= ei)
					break;
				m = [self rangeOfComposedCharacterSequenceAtIndex: si];
				si += m.length;
			}	}
			break;
		}

	return (NSRange){0,0};
}

- (NSRange) rangeOfComposedCharacterSequenceAtIndex:(NSUInteger)anIndex
{								
	NSUInteger end, start = anIndex;					// Determining Composed 
														// Character Sequences
	while (uni_isnonsp([self characterAtIndex: start]) && start > 0)
		start--;
	end = start+1;
	if (end < _count)
		while((end < _count) && uni_isnonsp([self characterAtIndex:end]))
			end++;

	return (NSRange){start, end - start};
}

- (NSComparisonResult) compare:(NSString*)cs
{
	return [self compare:cs options:0];				// Comparing Strings
}

- (NSComparisonResult) compare:(NSString*)cs options:(NSStringCompareOptions)mk
{
	return [self compare:cs options:mk range:((NSRange){0, _count})];
}

- (NSComparisonResult) compare:(NSString*)aString
					   options:(NSStringCompareOptions)mask
					   range:(NSRange)aRange
{								// FIX ME Should implement full POSIX.2 collate
	NSUInteger s2len;

	if (NSMaxRange(aRange) > _count)
		[NSException raise:NSRangeException format:@"Invalid location+length"];

	if (aRange.length == 0)
		return NSOrderedSame;
	if (((_count - aRange.location == 0) && (![aString length])))
		return NSOrderedSame;
	if (!_count)
		return NSOrderedAscending;
	if (!(s2len = [aString length]))
		return NSOrderedDescending;

	if (mask & NSLiteralSearch)
		{
		NSUInteger i, end;
		NSUInteger s1len = aRange.length;
		unichar s1[s1len+1];
		unichar s2[s2len+1];

		[self getCharacters:s1 range: aRange];
		s1[s1len] = (unichar)0;
		[aString getCharacters:s2];
		s2[s2len] = (unichar)0;
		end = s1len + 1;
		if (s2len < s1len)
			end = s2len+1;

		if (mask & NSCaseInsensitiveSearch)
			{
			for (i = 0; i < end; i++)
				{
				int c1 = uni_tolower(s1[i]);
				int c2 = uni_tolower(s2[i]);

				if (c1 < c2) 
					return NSOrderedAscending;
				if (c1 > c2) 
					return NSOrderedDescending;
			}	}
		else
			{
			for (i = 0; i < end; i++)
				{
				if (s1[i] < s2[i]) 
					return NSOrderedAscending;
				if (s1[i] > s2[i]) 
					return NSOrderedDescending;
			}	}

		if (s1len > s2len)
			return NSOrderedDescending;

		return (s1len < s2len) ? NSOrderedAscending : NSOrderedSame;
		}
	else
		{												// if NSLiteralSearch
		NSUInteger end = NSMaxRange(aRange);
		NSUInteger myCount = aRange.location;
		NSUInteger sCnt = aRange.location;
		NSRange m, s;
		_CSequence *strSeq;
		_CSequence *mySeq;
		NSComparisonResult result;

		while (myCount < end)
			{
			if (sCnt >= s2len)
      			return NSOrderedDescending;
    		if (myCount >= _count)
      			return NSOrderedAscending;
    		m = [self rangeOfComposedCharacterSequenceAtIndex:  myCount];
			myCount += m.length;
			s = [aString rangeOfComposedCharacterSequenceAtIndex:sCnt];
			sCnt += s.length;
			mySeq = [_CSequence sequenceWithString: self range: m];
			strSeq = [_CSequence sequenceWithString: aString range: s];
			if (mask & NSCaseInsensitiveSearch)
				result = [[mySeq lowercase] compare: [strSeq lowercase]];
			else
				result = [mySeq compare: strSeq];
			if (result != NSOrderedSame)
				return result;
			} 

		return (sCnt < s2len) ? NSOrderedAscending : NSOrderedSame;
		}  
}

- (NSUInteger) hash
{
	if (_count)
		{
		unichar *p, *target, *spoint, *tpoint;
		unichar *dpoint, *first, *second, tmp;
		NSUInteger ret = 0, char_count = 0;
		NSUInteger count, len2;
		BOOL notdone;
		NSUInteger len = (_count > HASH_STR_LENGTH) ? HASH_STR_LENGTH : _count;
		unichar *source = alloca(sizeof(unichar) * (len * MAXDEC +1));

		[self getCharacters: source range:(NSRange){0, len}];
		source[len] = (unichar)0;
																// decompose
		target = alloca(sizeof(unichar) * (len * MAXDEC +1));
		spoint = source;
		tpoint = target;
		do {
			notdone = NO;
			do {
				if(!(dpoint = uni_is_decomp(*spoint)))
					*tpoint++ = *spoint;
				else
					{
					while(*dpoint)
						*tpoint++ = *dpoint++;
					notdone = YES;
				}	}
			while(*spoint++);

			*tpoint = (unichar)0;
			memcpy(source, target, 2 * (len * MAXDEC +1));
			tpoint = target;
			spoint = source;
			} 
		while(notdone);
																	// order
		if((len2 = uslen(source)) > 1)
			do {
				notdone = NO;
				first = source;
				second = first+1;
				for(count = 1; count < len2; count++)
					{
					if(uni_cop(*second))
						{
						if(uni_cop(*first) > uni_cop(*second))
							{
							tmp = *first;
							*first = *second;
							*second = tmp;
							notdone = YES;
							}
						if(uni_cop(*first) == uni_cop(*second))
							if(*first > *second)
								{
								tmp = *first;
								*first = *second;
								*second = tmp;
								notdone = YES;
						}		}
					first++;
					second++;
				}	}
			while(notdone);

		p = source;

		while (*p && char_count++ < HASH_STR_LENGTH)
			ret = (ret << 5) + ret + *p++;
		if (ret == 0)				// The hash caching in our concrete string
			ret = 0xffffffff;		// classes uses zero to denote an empty
		return ret;					// cache value, so we MUST NOT return a 
		}							// hash of zero.

	return 0xfffffffe;				// Hash for an empty string.
}

- (BOOL) hasPrefix:(NSString*)aString
{
	NSRange range = [self rangeOfString:aString];

	return ((range.location == 0) && (range.length != 0));
}

- (BOOL) hasSuffix:(NSString*)aString
{
	NSRange range = [self rangeOfString:aString options:NSBackwardsSearch];

	return (range.length > 0 && range.location == (_count - [aString length]));
}

- (NSString*) commonPrefixWithString:(NSString*)aString options:(unsigned int)o
{
	_CSequence *mySeq;								// Getting a Shared Prefix
	_CSequence *strSeq;
	NSUInteger strLength = [aString length];
	NSUInteger mi = 0, si = 0;
	NSRange m, s;

	if(o & NSLiteralSearch)
		{
		NSUInteger prefix_len = 0;
		unichar a1[_count+1];
		unichar *s1 = a1;
		unichar a2[strLength+1];
		unichar *s2 = a2;
		unichar *w, *u = s1;

		[self getCharacters:s1];
		s1[_count] = (unichar)0;
		[aString getCharacters:s2];
		s2[[aString length]] = (unichar)0;
		u = s1;
		w = s2;

		if(o & NSCaseInsensitiveSearch)
			while (*s1 && *s2 && (uni_tolower(*s1) == uni_tolower(*s2)))
				{
				s1++;
				s2++;
				prefix_len++;
				}
		else
			while (*s1 && *s2 && (*s1 == *s2))	     
				{
				s1++;
				s2++;
				prefix_len++;
				}

		return [NSString stringWithCharacters:u length:prefix_len];
		}

	if(!_count)
		return self;
	if(!strLength)
		return aString;

	if(o & NSCaseInsensitiveSearch)
		{
		while((mi < _count) && (si < strLength))
			{
			if (uni_tolower([self characterAtIndex: mi])
					== uni_tolower([aString characterAtIndex: si]))
				{
				mi++;
				si++;
				}
			else
				{
				m = [self rangeOfComposedCharacterSequenceAtIndex: mi];
				s = [aString rangeOfComposedCharacterSequenceAtIndex:si];
				if((m.length < 2) || (s.length < 2))
					return [self substringWithRange:(NSRange){0, mi}];

				mySeq = [_CSequence sequenceWithString:self range:m];
				strSeq = [_CSequence sequenceWithString:aString range:s];

				if(![[mySeq lowercase] isEqual:[strSeq lowercase]])
					return [self substringWithRange:NSMakeRange(0,mi)];

				mi += m.length;
				si += s.length;
		}	}	}
	else
		while((mi < _count) && (si < strLength))
			{
			if([self characterAtIndex:mi] == [aString characterAtIndex:si])
				{
				mi++;
				si++;
				}
			else
				{
				m = [self rangeOfComposedCharacterSequenceAtIndex: mi];
				s = [aString rangeOfComposedCharacterSequenceAtIndex: si];
	
				if((m.length < 2) || (s.length < 2))
					return [self substringWithRange:(NSRange){0, mi}];
	
				mySeq = [_CSequence sequenceWithString: self range: m];
				strSeq = [_CSequence sequenceWithString:aString range:s];
				if(![mySeq isEqual: strSeq])
					return [self substringWithRange:(NSRange){0, mi}];
	
				mi += m.length;
				si += s.length;
			}	}

	return [self substringWithRange:(NSRange){0, mi}];
}

- (NSRange) lineRangeForRange:(NSRange)aRange
{
	NSUInteger s, e;

	[self getLineStart:&s end:&e contentsEnd:NULL forRange:aRange];

	return (NSRange){s, e - s};
}

- (void) getLineStart:(NSUInteger *)startIndex
				  end:(NSUInteger *)lineEndIndex
				  contentsEnd:(NSUInteger *)contentsEndIndex
				  forRange:(NSRange)aRange
{
	unichar thischar;
	NSUInteger start = aRange.location;
	NSUInteger end = NSMaxRange(aRange);
	BOOL done = NO;

	if (end > _count)
		[NSException raise:NSRangeException format:@"Invalid location+length"];

	if(startIndex)
		{
		if (start > 0)
			{
			start--;

			while(start > 0)
				{
				switch((thischar = [self characterAtIndex:start]))
					{
					case (unichar)0x000A:
					case (unichar)0x000D:
					case (unichar)0x2028:
					case (unichar)0x2029:
						done = YES;
						break;
					default:
						start--;
						break;
					}
				if(done)
					break;
				}
	
			if(start == 0)
				{
				switch(thischar = [self characterAtIndex:start])
					{
					case (unichar)0x000A:
					case (unichar)0x000D:
					case (unichar)0x2028:
					case (unichar)0x2029:
						start++;
					default:
						break;
				}	}
			else
				start++;
			}

		*startIndex = start;
		}

	if(lineEndIndex || contentsEndIndex)
		{
		done = NO;

		while(end < _count)
			{
			switch(thischar = [self characterAtIndex:end])
				{
				case (unichar)0x000A:
				case (unichar)0x000D:
				case (unichar)0x2028:
				case (unichar)0x2029:
					done = YES;
				default:
					break;
				};
			end++;
			if(done)
				break;
			};

		if (lineEndIndex)
			{
			if(end < _count)
				{
				if([self characterAtIndex:end] == (unichar)0x000D
						&& [self characterAtIndex:end+1] == (unichar)0x000A)
					*lineEndIndex = end+1;
				else  
					*lineEndIndex = end;
				}
			else
				*lineEndIndex = end;
			}
											// Assume last line is terminated
		if(contentsEndIndex)				// as OS docs do not specify. 
			*contentsEndIndex = (end < _count) ? end-1 : end;
		}
}
											// FIX ME There is more than this 
- (NSString*) capitalizedString				// to Unicode word capitalization 
{											// but this will work in most cases
	unichar *s = malloc(sizeof(unichar)*(_count+1));
	NSUInteger count = 0;
	BOOL found = YES;
	NSCharacterSet *ws = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	BOOL (*wsIMP)(id, SEL, unichar) = (BOOL(*)(id,SEL,unichar))
						 [ws methodForSelector: @selector(characterIsMember:)];

	[self getCharacters:s];
	s[_count] = (unichar)0;
	while (count < _count)
		{
		if ((*wsIMP)(ws, @selector(characterIsMember:), s[count]))
			{
			count++;
			found = YES;
			while ((*wsIMP)(ws, @selector(characterIsMember:), s[count])
					&& (count < _count))
				count++;
			}
		if (found)
			{
			s[count] = uni_toupper(s[count]);
			count++;
			}
		else
			{
			while (!(*wsIMP)(ws, @selector(characterIsMember:), s[count]) 
					&& (count < _count))
				{
				s[count] = uni_tolower(s[count]);
				count++;
			}	}

		found = NO;
		};

	return [[[NSString alloc] initWithCharactersNoCopy:s 
							  length:_count 
							  freeWhenDone: YES] autorelease];
}

- (NSString*) lowercaseString
{
	unichar *s = malloc(sizeof(unichar)*(_count+1));
	NSUInteger count;

	for(count = 0; count < _count; count++)
		s[count] = uni_tolower([self characterAtIndex:count]);

	return [[[[self class] alloc] initWithCharactersNoCopy: s
								  length: _count
								  freeWhenDone: YES] autorelease];
}

- (NSString*) uppercaseString;
{
	unichar *s = malloc(sizeof(unichar)*(_count+1));
	NSUInteger count;

	for(count = 0; count < _count; count++)
		s[count] = uni_toupper([self characterAtIndex:count]);

	return [[[[self class] alloc] initWithCharactersNoCopy: s
								  length: _count
								  freeWhenDone: YES] autorelease];
}

- (NSString*) stringByTrimmingCharactersInSet:(NSCharacterSet *)set
{
	NSUInteger s, e;			// remove whitespace, etc from edges of str

	for (s = 0, e = _count; s < e; s++)
		if(![set characterIsMember:[self characterAtIndex:s]])
			break;

	for (; e > s; e--)
		if(![set characterIsMember:[self characterAtIndex:e-1]])
			break;

	return [self substringWithRange:NSMakeRange(s, e-s)];
}

- (NSString *) stringByReplacingOccurrencesOfString:(NSString *)s
										 withString:(NSString *)new
											options:(NSStringCompareOptions)mask
											  range:(NSRange)r
{
	NSMutableString *m = [[self mutableCopy] autorelease];

	[m replaceOccurrencesOfString:s withString:new options:mask range:r];

	return m;
}

- (NSString *) stringByReplacingOccurrencesOfString:(NSString *)s
										 withString:(NSString *)n
{
	return [self stringByReplacingOccurrencesOfString:s
				 withString:n
				 options:0
				 range:NSMakeRange(0, [self length])];
}

- (void) getCString:(char*)buffer
{
	[self getCString:buffer maxLength:NSMaximumStringLength];
}

- (void) getCString:(char*)buffer maxLength:(NSUInteger)maxLength
{
	NSRange r = {0, _count};

	[self getCString:buffer maxLength:maxLength range:r remainingRange:NULL];
}

- (void) getCString:(char*)buffer
		  maxLength:(NSUInteger)maxLength
		  range:(NSRange)r
		  remainingRange:(NSRange*)leftoverRange
{								// FIX ME adjust range for composite sequence
	NSUInteger c = 0;
	NSUInteger len = [self cStringLength];

	if (r.location > len)
		[NSException raise: NSRangeException format:@"Invalid location."];
	if (r.length > (len - r.location))
		[NSException raise:NSRangeException format:@"Invalid location+length"];

	if (maxLength < r.length)
		{
		len = maxLength;
		if (leftoverRange)
			{
			leftoverRange->location = 0;
			leftoverRange->length = 0;
		}	}
	else
		{
		len = r.length;
		if (leftoverRange)
			{
			leftoverRange->location = r.location + maxLength;
			leftoverRange->length = r.length - maxLength;
		}	}

	while(c < len)
		{
		buffer[c] = UCharToByte([self characterAtIndex: r.location + c]);
		c++;
		}

	buffer[len] = '\0';
}

- (BOOL) boolValue
{
	const char *s = [self cString];

	while (isspace(*s))
		s++;

	return (*s == 't' || *s == 'T' || *s == 'y' || *s == 'Y' || atoi(s) != 0);
}

- (double) doubleValue			{ return atof([self cString]); }
- (float) floatValue			{ return (float) atof([self cString]); }
- (int) intValue				{ return atoi([self cString]); }
- (long long) longLongValue		{ return atol([self cString]); }
- (NSInteger) integerValue		{ return atol([self cString]); }

- (BOOL) canBeConvertedToEncoding:(NSStringEncoding)encoding  // FIX ME can hit NIMP, inefficient
{
	return [self dataUsingEncoding:encoding allowLossyConversion:NO] ? YES: NO;
}

- (NSData*) dataUsingEncoding:(NSStringEncoding)encoding
{
	return [self dataUsingEncoding:encoding allowLossyConversion:NO];
}

- (NSData*) dataUsingEncoding:(NSStringEncoding)encoding
			allowLossyConversion:(BOOL)flag
{														// FIX ME incomplete
	if ((encoding == NSASCIIStringEncoding)
			|| (encoding == NSUTF8StringEncoding)
			|| (encoding == NSISOLatin1StringEncoding)
			|| (encoding == NSNEXTSTEPStringEncoding)
			|| (encoding == NSNonLossyASCIIStringEncoding)
			|| (encoding == NSSymbolStringEncoding))
		{
		unsigned char *buf = (unsigned char*)malloc(_count);
		unsigned char t;
		NSUInteger i;

		if (!flag)
			{
			for (i = 0; i < _count; i++)
				{
				if ((t = encode_unitochar([self characterAtIndex:i],encoding)))
					buf[i] = t;
				else
					{
					free(buf);
					return nil;
			}	}	}
		else 												// lossy conversion
			{
			for (i = 0; i < _count; i++)
				{
				if ((t = encode_unitochar([self characterAtIndex:i],encoding)))
		  			buf[i] = t;				// should handle decomposed chars
	      		else						// OpenStep docs are unclear on
		  			buf[i] = '*';			// what to do if there is no simple
	    	}	}							// replacement for character

		return [NSData dataWithBytesNoCopy:buf length:i];
		}

	if (encoding == NSUnicodeStringEncoding)
		{
		unichar *buf = (unichar*)malloc(2 * _count +2);
		NSUInteger i;

		buf[0] = 0xFEFF;
		for (i = 0; i < _count; i++)
			buf[i+1] = [self characterAtIndex: i];

		return [NSData dataWithBytesNoCopy:buf length: 2 * _count +2];
		}

	return NIMP;										// EUC
}

- (int) _baseLength					{ return (int)_count; }
- (NSUInteger) cStringLength		{ return _count; }

- (NSComparisonResult) caseInsensitiveCompare:(NSString*)aString
{
	return [self compare:aString 
				 options:NSCaseInsensitiveSearch 
				 range:((NSRange){0, _count})];
}

- (BOOL) writeToFile:(NSString*)filename atomically:(BOOL)useAuxiliaryFile
{
	id d;

	if (!(d = [self dataUsingEncoding: CFStringGetSystemEncoding()]))
		d = [self dataUsingEncoding: NSUnicodeStringEncoding];

	return [d writeToFile:filename atomically:useAuxiliaryFile];
}

- (void) encodeWithCoder:(NSCoder*)anEncoder		{ SUBCLASS }
- (id) initWithCoder:(NSCoder*)aDecoder				{ SUBCLASS return nil; }
- (id) replacementObjectForPortCoder:(NSPortCoder*)coder	{ return self; }
- (Class) classForArchiver							{ return [self class]; }
- (Class) classForCoder								{ return [self class]; }

@end /* NSString */


@implementation NSString (NSStringPathExtensions)		// NSPathUtilities

+ (NSString *) pathWithComponents:(NSArray*)components
{
	NSString *s = [components objectAtIndex: 0];
	NSUInteger i;

	for (i = 1; i < [components count]; i++)
		s = [s stringByAppendingPathComponent: [components objectAtIndex: i]];

    return s;
}
											// string for passing to OS calls
- (const char*) fileSystemRepresentation			{ return [self cString]; }

- (BOOL) getFileSystemRepresentation:(char*)buffer maxLength:(NSUInteger)size
{
	const char *ptr = [self cString];		// replace path sep chars '.' '/' ?

	if (buffer != NULL && size > strlen(ptr))
		{
		strcpy(buffer, ptr);
		return YES;
		}

	return NO;
}

- (BOOL) isAbsolutePath
{
    return (_count > 0 && [self characterAtIndex: 0] == (unichar)'/');
}

- (NSArray*) pathComponents
{
	NSMutableArray *a = [[self componentsSeparatedByString: @"/"] mutableCopy];
	NSArray *r;

    if ([a count] > 0) 			// If the path began with a '/' then the first 
		{						// path component must be a '/' rather than an
		NSInteger i;			// empty string so that our output could be fed
								// into [+pathWithComponents:]
		if ([[a objectAtIndex: 0] length] == 0)
			[a replaceObjectAtIndex: 0 withObject: @"/"];
													// Empty path components 
		for (i = [a count] - 2; i > 0; i--) 		// (except a trailing one) 
			{										// must be removed.
			if ([[a objectAtIndex: i] length] == 0) 
				[a removeObjectAtIndex: i];
		}	}

    r = [a copy];
    [a release];

	return [r autorelease];
}

- (NSArray*) stringsByAppendingPaths:(NSArray*)paths
{
	NSMutableArray *a = [[NSMutableArray alloc] initWithCapacity:[paths count]];
	NSArray *r;
	NSUInteger i;

    for (i = 0; i < [paths count]; i++) 
		{
		NSString *s = [paths objectAtIndex: i];

		while ([s isAbsolutePath]) 
			s = [s substringFromIndex: 1];

		[a addObject: [self stringByAppendingPathComponent: s]];
		}
	r = [a copy];
	[a release];

    return [r autorelease];
}

- (NSUInteger) completePathIntoString:(NSString**)outputName
						  caseSensitive:(BOOL)flag
						  matchesIntoArray:(NSArray**)outputArray
						  filterTypes:(NSArray*)filterTypes
{
	NSString *base_path = [self stringByDeletingLastPathComponent];
	NSString *lc = [self lastPathComponent];
	NSString *tp;
	NSDirectoryEnumerator *e;					
	NSMutableArray *op;
	int match_count = 0;
											// Manipulating File System Paths
	if (outputArray != 0)
		op = (NSMutableArray*)[NSMutableArray array];
	if (outputName != NULL) 
		*outputName = nil;
	if ([base_path length] == 0) 
		base_path = @".";

	e = [[NSFileManager defaultManager] enumeratorAtPath: base_path];
	while (tp = [e nextObject], tp)
		{													// Prefix matching
		if (flag)
			{ 												// Case sensitive 
			if (NO == [tp hasPrefix: lc])
				continue;
			}
		else if (NO == [[tp uppercaseString] hasPrefix: [lc uppercaseString]])
			continue;
														// Extensions filtering
		if (filterTypes)
			if (NO == [filterTypes containsObject: [tp pathExtension]])
				continue;
														// Found a completion
		match_count++;
		if (outputArray != NULL)
			[op addObject: tp];
      
		if ((outputName != NULL) && ((*outputName == nil)
				|| (([*outputName length] < [tp length]))))
			*outputName = tp;
		}
	if (outputArray != NULL)
		*outputArray = [[op copy] autorelease];

	return match_count;
}

- (NSString *) lastPathComponent
{
	NSRange r = [self rangeOfCharacterFromSet:__pathSep options:NSBackwardsSearch];

	if (r.length == 0)						// return a string containing the
		return [[self copy] autorelease];	// portion of reciever following
											// the last '/'. If last char is'/'
	if (r.location == (_count - 1))			// then return the prev sub string
		{									// delimited by '/'.  returns '/'
		if (r.location == 0)				// if recv contains only '/'
			return [[self copy] autorelease]; // **return per apple doc != @""

		return [[self substringToIndex:r.location] lastPathComponent];
		}

	return [self substringFromIndex:r.location + 1];
}

- (NSString *) pathExtension
{
	NSRange range = [self rangeOfString:@"." options: NSBackwardsSearch];
	NSRange r;
												// interpret reciever as a path
	if (range.length == 0)						// and return the portion after
		return @"";								// the last '.' or a NULL str
												// eg '.tiff' from '/me/a.tiff'
	r = [self rangeOfCharacterFromSet: __pathSep options: NSBackwardsSearch];
	if (r.length > 0 && range.location < r.location)
		return @"";

	return [self substringFromIndex:range.location + 1];
}

- (NSString *) stringByAppendingPathComponent:(NSString *)aString
{
	NSRange r;
	NSString *ns = self;		// form new path string by appending aString

	if ([aString length] == 0)
		return [[self copy] autorelease];

	r = [aString rangeOfString:@"./"];		// do not append leading dot
	if (r.length != 0 && r.location == 0)
		aString = [aString substringFromIndex: 1];
											// do not append leading path sep
	r = [aString rangeOfCharacterFromSet: __pathSep];
	if (r.length != 0 && r.location == 0)
		aString = [aString substringFromIndex: 1];

	r = [self rangeOfCharacterFromSet:__pathSep options:NSBackwardsSearch];
	if ((r.length == 0 || r.location != _count - 1) && _count > 0)
		ns = [self stringByAppendingString: @"/"];

	return [ns stringByAppendingString: aString];
}

- (NSString *) stringByAppendingPathExtension:(NSString*)aString
{
	NSRange r;
	NSString *ns = self;		// form new path string by appending extension

	if ([aString length] == 0)
		return [[self copy] autorelease];
	
	r = [aString rangeOfString:@"."];
	if (r.length != 0 && r.location == 0)
		aString = [aString substringFromIndex: 1];
	
	r = [self rangeOfString:@"." options:NSBackwardsSearch];
	if (r.length == 0 || r.location != _count - 1)
		ns = [self stringByAppendingString:@"."];
	
	return [ns stringByAppendingString:aString];
}

- (NSString *) stringByDeletingLastPathComponent
{
	NSRange r = [self rangeOfString: [self lastPathComponent]
							options: NSBackwardsSearch];
	if (r.length == 0)
		return [[self copy] autorelease];
	if (r.location == 0)
		return @"";

	return (r.location > 1) ? [self substringToIndex: r.location-1] : @"/";
}

- (NSString *) stringByDeletingPathExtension
{
	NSRange r = [self rangeOfString: [self pathExtension]
							options: NSBackwardsSearch];

	return (r.length != 0) ? [self substringToIndex:r.location-1]
						   : [[self copy] autorelease];
}

- (NSString *) stringByExpandingTildeInPath
{
	NSString *homedir;
	NSRange first_slash_range;
  
	if (_count == 0)
		return [[self copy] autorelease];
	if ([self characterAtIndex: 0] != 0x007E)
		return [[self copy] autorelease];
	
	first_slash_range = [self rangeOfString: @"/"];
	
	if (first_slash_range.location != 1)
		{							// It is of the form `~username/blah/...'
		NSUInteger uname_len;
		NSString *uname;
	
		if (first_slash_range.length != 0)
			uname_len = first_slash_range.length - 1;
		else						// It is actually of the form `~username' 
			uname_len = _count - 1;
		uname = [self substringWithRange:((NSRange){1, uname_len})];
		homedir = NSHomeDirectoryForUser (uname);
		}
	else									// It is of the form `~/blah/...'
		homedir = NSHomeDirectory();
	
	return [NSString stringWithFormat: @"%@%@", homedir, 
					 [self substringFromIndex: first_slash_range.location]];
}

- (NSString *) stringByAbbreviatingWithTildeInPath
{
	NSString *homedir = NSHomeDirectory();

	if (![self hasPrefix: homedir])
		return [[self copy] autorelease];

	return [NSString stringWithFormat: @"~%c%@", (char)__pathSepChar,
					 [self substringFromIndex: [homedir length] + 1]];
}

- (NSString *) stringByResolvingSymlinksInPath
{
	NSString *first_half = self, *second_half = @"";
	const int MAX_PATH_LEN = 1024;
	char tmp_buf[MAX_PATH_LEN];

	while (1)
		{
		const char *tmp_cpath = [first_half cString];
		struct stat tmp_stat;  
		int r;

		if (0 != lstat(tmp_cpath, &tmp_stat))  
			return self;
      
		if ((tmp_stat.st_mode & S_IFLNK)
				&& ((r = readlink(tmp_cpath, tmp_buf, MAX_PATH_LEN)) != -1))
			{						// first half is a path to a symbolic link.
			tmp_buf[r] = '\0'; 		// Make a C string
			second_half = [[NSString stringWithCString: tmp_buf]
				      		stringByAppendingPathComponent: second_half];
			first_half = [first_half stringByDeletingLastPathComponent];
			}
		else
			{						// second_half is an absolute path 
	  		if ([second_half hasPrefix: @"/"]) 
	    		return [second_half stringByResolvingSymlinksInPath];
								// first half is NOT a path to a symbolic link
	  		second_half = [[first_half lastPathComponent]
			  				stringByAppendingPathComponent: second_half];
	  		first_half = [first_half stringByDeletingLastPathComponent];
			}

		if ([first_half length] == 0) 						// BREAK CONDITION
			break;

		if ([first_half length] == 1
			 && [__pathSep characterIsMember: [first_half characterAtIndex:0]])
			{
			second_half = [@"/" stringByAppendingPathComponent: second_half];
			break;
		}	}

	return second_half;
}

- (NSString *) stringByStandardizingPath
{														// Expand `~' in path
	NSMutableString *s = [[self stringByExpandingTildeInPath] mutableCopy];
	NSRange search = {0, [s length]};
	NSRange found = [s rangeOfString:@"//" options:2 range:search];

	while (found.length)
		{
		[s deleteCharactersInRange: (NSRange){found.location, 1}];
		search.length = [s length];
		found = [s rangeOfString:@"//" options:0 range:search];
		}
															// Condense `/./' 
	found = [s rangeOfString:@"/./" options:2 range:search];
	while (found.length)
		{
		[s deleteCharactersInRange: (NSRange){found.location, 2}];
		search.length = [s length];
		found = [s rangeOfString:@"/./" options:0 range:search];
		}
															// Condense `/../' 
	found = [s rangeOfString:@"/../" options:2 range:search];
	while (found.length)
		{
		if (found.location > 0)
			{
			NSRange r = {0, found.location};

			found = [s rangeOfCharacterFromSet: __pathSep
					   options: NSBackwardsSearch
					   range: r];
			found.length = r.length - found.location + 3;	// Add the `/../' 
			[s deleteCharactersInRange: found];
			}
		else
			[s deleteCharactersInRange: (NSRange){found.location, 3}];
		search.length = [s length];
		found = [s rangeOfString:@"/../" options:0 range:search];
		}

	return s;
}

@end /* NSString (NSStringPathExtensions) */

/* ****************************************************************************

 		NSMutableString

** ***************************************************************************/

@implementation NSMutableString

+ (id) alloc			{ return NSAllocateObject(__mutableUStringClass); }

+ (id) stringWithCapacity:(NSUInteger)capacity
{
	return [[[self alloc] initWithCapacity:capacity] autorelease];
}

+ (id) stringWithCString:(const char*)byteString
{
	return [[[_NSMutableCString alloc] initWithCString:byteString] autorelease];
}

+ (id) stringWithCString:(const char*)byteString length:(NSUInteger)length
{
	return [[[_NSMutableCString alloc] initWithCString:byteString
									   length:length] autorelease];
}

@end /* NSMutableString */

/* ****************************************************************************

 		_NSUString

** ***************************************************************************/

@implementation _NSUString

+ (id) alloc						{ return NSAllocateObject(self); }

- (id) initWithCharactersNoCopy:(unichar*)chars
						 length:(NSUInteger)length
						 freeWhenDone:(BOOL)flag
{
	_count = length;
	_uniChars = chars;
	_dontFree = !flag;

    return self;
}

- (id) initWithCStringNoCopy:(char*)b length:(NSUInteger)l freeWhenDone:(BOOL)f
{
	[self release];

	return (id)[[_NSCString alloc] initWithCStringNoCopy: b
								   length: l
								   freeWhenDone: f];
}

- (void) dealloc
{
	if (!_dontFree)
		{
		if(_uniChars)
			free(_uniChars), _uniChars = NULL;
		if(_cString)
			free(_cString), _cString = NULL;
		}
	
	[super dealloc];
}

- (BOOL) isEqual:(id)obj
{
	Class c;

	if (obj == self)
		return YES;
	if ((obj != nil) && CLS_ISCLASS(((Class)obj)->class_pointer))
		c = ((Class)obj)->class_pointer;
	else
		return NO;

	if (c == __uStrClass || c == __mutableUStringClass)
		{
		if (_hash == 0)
			_hash = __sHashImp(self, @selector(hash));
		if (((_NSUString*)obj)->_hash == 0)
			((_NSUString*)obj)->_hash = __sHashImp(obj, @selector(hash));
		if (_hash != ((_NSUString*)obj)->_hash)
			return NO;
		}
	else
		if (c == __cStringClass || c == __mutableCStringClass
				|| c == __constantStringClass)
			{
			if (_hash == 0)
				_hash = __sHashImp(self, @selector(hash));
			if ((c != __constantStringClass) && (_hash != [obj hash]))
				return NO;
			if(_count != ((NSString *)obj)->_count)
				return NO;
			if(!_cString)
				[self cString];
			if(memcmp(_cString, ((NSString *)obj)->_cString, _count) != 0)
				return NO;
			return YES;
			}

	if (_classIsKindOfClass(c, __nsStringClass))
		return [self isEqualToString: obj];

	return NO;
}

- (BOOL) isEqualToString:(NSString*)aString
{
	NSUInteger mi = 0, si = 0;
	Class c;

	if (aString == self)
		return YES;
	if((aString != nil) && CLS_ISCLASS(((Class)aString)->class_pointer))
		c = ((Class)aString)->class_pointer;
	else
		return NO;

	if (_count != ((NSString *)aString)->_count)
		return NO;
	if (_count == 0)										// both are 0 len
		return YES;

	if (_hash == 0)
		_hash = __sHashImp(self, @selector(hash));
	if (c == __uStrClass || c == __mutableUStringClass)		// unichar string
		{
		if (((_NSUString*)aString)->_hash == 0)
			((_NSUString*)aString)->_hash = __sHashImp(aString,@selector(hash));
		if (_hash != ((_NSUString*)aString)->_hash)
			return NO;
		}
	else													// C char string
		{
		if ((c != __constantStringClass) && (_hash != [aString hash]))
			return NO;
		if(!_cString)
			[self cString];

		return (memcmp(_cString,((NSString *)aString)->_cString, _count) == 0);
		}

	while((mi < _count) && (si < ((NSString *)aString)->_count))
		{
		if([self characterAtIndex:mi] == [aString characterAtIndex:si])
			{
			mi++;
			si++;
			}
		else
			{
			NSRange m = [self rangeOfComposedCharacterSequenceAtIndex:mi];
			NSRange s = [aString rangeOfComposedCharacterSequenceAtIndex:si];
			_CSequence *mySeq;
			_CSequence *strSeq;

			if((m.length < 2) || (s.length < 2))
				return NO;

			mySeq = [_CSequence sequenceWithString:self range:m];
			strSeq = [_CSequence sequenceWithString:aString range:s];

			if(![mySeq isEqual: strSeq])
				return NO;

			mi += m.length;
			si += s.length;
		}	}

	return ((mi == _count) && (si == ((NSString *)aString)->_count)) ? YES : NO;
}

- (NSUInteger) hash
{
	return _hash == 0 ? (_hash = __sHashImp(self,@selector(hash))) : _hash;
}

- (unichar) characterAtIndex:(NSUInteger)index
{
	if (index >= _count)
		[NSException raise:NSRangeException format: @"Invalid index %d", index];

	return _uniChars[index];
}

- (void) getCharacters:(unichar*)buffer
{
	memcpy(buffer, _uniChars, _count*2);
}

- (void) getCharacters:(unichar*)buffer range:(NSRange)aRange
{
	if (NSMaxRange(aRange) > _count)
		[NSException raise:NSRangeException format:@"Invalid location+length"];
	memcpy(buffer, _uniChars + aRange.location, aRange.length * 2);
}

- (NSString*) substringWithRange:(NSRange)aRange
{											// Dividing Strings into Substrings
	if (NSMaxRange(aRange) > _count)
		[NSException raise:NSRangeException format:@"Invalid location+length"];

	return [[self class] stringWithCharacters: _uniChars + aRange.location
									   length: aRange.length];
}

- (const char *) cString								// Getting C Strings
{
	_cString = _AllocCString(_cString, _count, NULL);
	if (_count > 0)
		UStrToCStr(_cString, _uniChars, _count);		// lossy conversion
	_cString[_count] = '\0';

	return _cString;
}

- (const char *) UTF8String
{
	CFIndex size;
	CFString st = {0};
	CFRange r = {0, _count};
	CFStringRef s = (CFStringRef)&st;

	st._uniChars = _uniChars;
	st._count = _count;
	if (CFStringGetBytes(s, r, NSUTF8StringEncoding, 0, 0, NULL, 0, &size))
		_cString = _AllocCString(_cString, size, NULL);
	CFStringGetBytes(s, r, NSUTF8StringEncoding, 0, 0, _cString, size, NULL);

	return _cString;
}

- (NSStringEncoding) fastestEncoding	{ return NSUnicodeStringEncoding; }
- (NSStringEncoding) smallestEncoding	{ return NSUnicodeStringEncoding; }

- (int) _baseLength				// length ignoring decomposed unicode chars
{
	int count = 0;
	int blen = 0;

	while(count < _count)
		if(!uni_isnonsp([self characterAtIndex: count++]))
			blen++;

	return blen;
}

- (void) encodeWithCoder:(NSCoder*)aCoder				// NSCoding Protocol
{														
	[aCoder encodeValueOfObjCType: @encode(NSUInteger) at: &_count];
	if (_count > 0)
		[aCoder encodeArrayOfObjCType: @encode(unichar)
				count: _count
				at: _uniChars];
}

- (id) initWithCoder:(NSCoder*)aCoder
{
	[aCoder decodeValueOfObjCType: @encode(NSUInteger) at: &_count];
	if (_count)
		[aCoder decodeArrayOfObjCType: @encode(unichar)
				count: _count
				at: (_uniChars = malloc(sizeof(unichar)*_count))];

	return self;
}

@end /* _NSUString */

/* ****************************************************************************

 		_NSMutableUString

** ***************************************************************************/

@implementation _NSMutableUString

- (id) initWithCharactersNoCopy:(unichar*)chars
						 length:(NSUInteger)length
						 freeWhenDone:(BOOL)flag
{
	_count = _capacity = length;
	_uniChars = chars;
	_dontFree = !flag;

    return self;
}

- (id) initWithCapacity:(NSUInteger)capacity
{
	_count = 0;
	_capacity = (capacity < 2) ? 2 : capacity;
	_uniChars = malloc(sizeof(unichar) * _capacity);

    return self;
}

- (id) initWithCStringNoCopy:(char*)b length:(NSUInteger)l freeWhenDone:(BOOL)f
{
	[self release];

	return (id)[[_NSMutableCString alloc] initWithCStringNoCopy: b
								   		  length: l
								   		  freeWhenDone: f];
}

- (id) copy
{
	return [[_NSMutableUString alloc] initWithString:self];
}

- (void) deleteCharactersInRange:(NSRange)r
{
	_count -= r.length;
	memmove(_uniChars + r.location, _uniChars + NSMaxRange(r), 2 * (_count - r.location));
	_hash = 0;
}

- (void) replaceCharactersInRange:(NSRange)aRange withString:(NSString*)aString
{
	NSUInteger stringLength = (aString == nil) ? 0 : [aString length];
	NSInteger offset = stringLength - aRange.length;
	NSUInteger maxRange = NSMaxRange(aRange);

	if (maxRange > _count)
		[NSException raise:NSRangeException format:@"Invalid location+length"];
	
	if (_count + stringLength > _capacity + aRange.length)
		{
		_capacity += stringLength - aRange.length;
		if (_capacity < 2)
			_capacity = 2;
		_uniChars = realloc(_uniChars, sizeof(unichar)*_capacity);
		}

	if (offset != 0)
		{
		unichar *src = _uniChars + maxRange;
		memmove(src + offset,src,(_count - aRange.location - aRange.length)*2);
		}

	[aString getCharacters: &_uniChars[aRange.location]];
	_count += offset;
	_hash = 0;
}

- (NSUInteger) replaceOccurrencesOfString:(NSString *)target
							   withString:(NSString *)replace
								  options:(NSStringCompareOptions)opts
									range:(NSRange)searchRange
{
	NSRange	r = [self rangeOfString:target options:opts range:searchRange];
	NSUInteger i, rl = [replace length];

	for (i = 0; r.length > 0 && replace != nil; i++)
		{
		[self replaceCharactersInRange:r withString:replace];

		if ((opts & NSBackwardsSearch) == NSBackwardsSearch)
			searchRange.length = r.location - searchRange.location;
		else
			{
			NSUInteger end = NSMaxRange(searchRange) + rl - r.length;

			searchRange.location = r.location + rl;
			searchRange.length = end - searchRange.location;
			}

		r = [self rangeOfString:target options:opts range:searchRange];
		}

	return i;
}

- (void) insertString:(NSString*)aString atIndex:(NSUInteger)loc
{
	[self replaceCharactersInRange:(NSRange){loc, 0} withString:aString];
}

- (void) appendString:(NSString*)aString
{
	[self replaceCharactersInRange:(NSRange){_count, 0} withString:aString];
}

- (void) appendFormat:(NSString*)format, ...
{													
	va_list ap;
	id tmp;

	va_start(ap, format);
	tmp = [[NSString alloc] initWithFormat:format arguments:ap];
	va_end(ap);
	[self appendString:tmp];
	[tmp release];
}

- (void) setString:(NSString*)aString
{
	NSUInteger len = [aString length];

	if (_capacity < len)
		{
		_capacity = (len < 2) ? 2 : len;
		_uniChars = realloc(_uniChars, sizeof(unichar)*_capacity);
		}
	[aString getCharacters: _uniChars];
	_count = len;
	_hash = 0;
}

- (id) initWithCoder:(NSCoder*)aCoder
{
	NSUInteger cap;
  
	[aCoder decodeValueOfObjCType: @encode(NSUInteger) at: &cap];
	[self initWithCapacity:cap];
	if ((_count = cap) > 0)
		[aCoder decodeArrayOfObjCType: @encode(unichar)
				count: _count
				at: _uniChars];

	return self;
}

@end /* _NSMutableUString */

/* ****************************************************************************

 		_NSBaseCString

** ***************************************************************************/

@implementation _NSBaseCString

- (void) getCString:(char*)buffer
{
	memcpy(buffer, _cString, _count);
	buffer[_count] = '\0';
}

- (void) getCString:(char*)buffer maxLength:(NSUInteger)maxLength
{
	if (maxLength > _count)
		maxLength = _count;
	memcpy(buffer, _cString, maxLength);
	buffer[maxLength] = '\0';
}

- (void) getCString:(char*)buffer
		  maxLength:(NSUInteger)maxLength
		  range:(NSRange)aRange
		  remainingRange:(NSRange*)leftoverRange
{
	NSUInteger len;

	if (NSMaxRange(aRange) > _count)
		[NSException raise:NSRangeException format:@"Invalid location+length"];

	if (maxLength < aRange.length)
		{
		len = maxLength;
		if (leftoverRange)
			{
			leftoverRange->location = 0;
			leftoverRange->length = 0;
		}	}
	else
		{
		len = aRange.length;
		if (leftoverRange)
			{
			leftoverRange->location = aRange.location + maxLength;
			leftoverRange->length = aRange.length - maxLength;
		}	}
	
	memcpy(buffer, &_cString[aRange.location], len);
	buffer[len] = '\0';
}

- (unichar) characterAtIndex:(NSUInteger)index
{
	if (index >= _count)
		[NSException raise:NSRangeException format: @"Invalid index %d", index];

	return ByteToUChar(_cString[index]);
}

- (void) getCharacters:(unichar*)buffer
{
	NSUInteger i;

	for (i = 0; i < _count; i++)
		*buffer++ = ByteToUChar(((unsigned char *)_cString)[i]);
}

- (void) getCharacters:(unichar*)buffer range:(NSRange)r
{
	NSUInteger e, i;

	if ((e = NSMaxRange(r)) > _count)
		[NSException raise:NSRangeException format:@"Invalid location+length"];

	for (i = r.location; i < e; i++)
		*buffer++ = ByteToUChar(((unsigned char *)_cString)[i]);
}

- (NSString *) substringWithRange:(NSRange)r
{
	if (NSMaxRange(r) > _count)
		[NSException raise:NSRangeException format:@"Invalid location+length"];

	return [__cStringClass stringWithCString: _cString + r.location
									  length: r.length];
}

- (NSData*) dataUsingEncoding:(NSStringEncoding)encoding
			allowLossyConversion:(BOOL)flag
{
	if ((encoding == NSASCIIStringEncoding)
			|| (encoding == NSUTF8StringEncoding)
			|| (encoding == NSISOLatin1StringEncoding)
			|| (encoding == NSNEXTSTEPStringEncoding)
			|| (encoding == NSNonLossyASCIIStringEncoding)
			|| (encoding == NSSymbolStringEncoding))
		{
		unsigned char *buf = (unsigned char*)malloc(_count);

		memcpy(buf, (unsigned char*)_cString, _count);

		return [NSData dataWithBytesNoCopy:buf length:_count];
		}

	return [super dataUsingEncoding:encoding allowLossyConversion:flag];
}

- (void) encodeWithCoder:(NSCoder*)aCoder				// NSCoding protocol
{
	[aCoder encodeValueOfObjCType:@encode(NSUInteger) at:&_count];
	if (_count > 0)
		[aCoder encodeArrayOfObjCType:@encode(unsigned char) 
				count:_count
				at:_cString];
}

- (id) initWithCoder:(NSCoder*)aCoder
{
	[aCoder decodeValueOfObjCType:@encode(NSUInteger) at:&_count];
	if (_count > 0)
		{
		[aCoder decodeArrayOfObjCType:@encode(unsigned char) 
				count:_count
				at:(_cString = _AllocCString(NULL, _count, NULL))];
		_cString[_count] = '\0';
		}

	return self;
}

@end /* _NSBaseCString */

/* ****************************************************************************

 		_NSCString

** ***************************************************************************/

@implementation _NSCString

+ (id) alloc						{ return NSAllocateObject(self); }

- (id) initWithCStringNoCopy:(char*)byteString			// OPENSTEP designated 
					  length:(NSUInteger)length			// initializer
					  freeWhenDone:(BOOL)flag
{
	_count = length;					
	_cString = byteString;
	_dontFree = !flag;

	if (_cString[_count] != '\0')
		{
		NSLog(@"WARNING: init with C-string that is not NULL terminated *** ");
		_cString[_count] = '\0';
		}

	return self;
}

- (id) initWithCharactersNoCopy:(unichar*)chars
						 length:(NSUInteger)length
						 freeWhenDone:(BOOL)flag
{
	[self release];

	return (id)[[_NSUString alloc] initWithCharactersNoCopy: chars
								   length: length
								   freeWhenDone: flag];
}

- (id) initWithString:(NSString*)string
{
	NSUInteger length = [string cStringLength];
	char *buf = _AllocCString(NULL, length, NULL);

	[string getCString: buf];						// getCString appends null

    return [self initWithCStringNoCopy:buf length:length freeWhenDone:YES];
}

- (void) dealloc
{
	if(_cString && !_dontFree)
		free(_cString), _cString = NULL;

	[super dealloc];
}

- (id) mutableCopy
{
	_NSMutableCString *m;

	if ((m = (_NSMutableCString*)NSAllocateObject(__mutableCStringClass)))
		{
		((_NSCString *)m)->_cString = _AllocCString(NULL, _count, _cString);
		((_NSCString *)m)->_count = _count;			// _capacity undefined (=0)
		((_NSCString *)m)->_hash = _hash;
		}

	return m;
}

- (NSUInteger) hash
{
	return _hash == 0 ? (_hash = __sHashImp(self, @selector(hash))) : _hash;
}

- (BOOL) isEqual:(id)obj
{
	if (obj == self)
		return YES;

    if ((obj != nil) && (CLS_ISCLASS(((Class)obj)->class_pointer))) 
		{
		Class c = ((Class)obj)->class_pointer;

		if (c == __cStringClass || c == __mutableCStringClass)
			{
			if (_count != ((NSString *)obj)->_count)
				return NO;
			if (memcmp(_cString, ((NSString *)obj)->_cString, _count) == 0)
				return YES;
			if (_hash == 0)
				_hash = __sHashImp(self, @selector(hash));
			if (((_NSCString*)obj)->_hash == 0)
				((_NSCString*)obj)->_hash = __sHashImp(obj,@selector(hash));
			if (_hash != ((_NSCString*)obj)->_hash)
				return NO;
			return YES;
			}
		else
			if(c == __constantStringClass) 
				{
				if(_count != ((NSString *)obj)->_count)
					return NO;
				if(memcmp(_cString, ((NSString *)obj)->_cString,_count) != 0)
					return NO;
				return YES;
				}
	
		if (_classIsKindOfClass(c, __nsStringClass))
			{
			if (!((NSString *)obj)->_cString)
				{										 
				if (((NSString *)obj)->_count > 0)
					[obj cString];				// if an object is a unichar
				else							// str but does not yet have a
					return NO;					// C str backing, create it
				}
			if (_count != ((NSString *)obj)->_count)
				return NO;
			if (memcmp(_cString, ((NSString *)obj)->_cString, _count) == 0)
				return YES;
		}	}

    return NO;
}

- (BOOL) isEqualToString:(NSString*)aString
{
	if (aString == self)
		return YES;

    if ((aString != nil) && (CLS_ISCLASS(((Class)aString)->class_pointer))) 
		{
		Class c = ((Class)aString)->class_pointer;

		if (_count != ((NSString *)aString)->_count)
			return NO;
		if (_count == 0)						// both are 0 len
			return YES;
		if (c == __cStringClass || c == __mutableCStringClass) 
			{
			_NSCString *other = (_NSCString*)aString;

			if (_hash == 0)
				_hash = __sHashImp(self, @selector(hash));
			if (other->_hash == 0)
				other->_hash = __sHashImp(aString, @selector(hash));
			if (_hash != other->_hash)
				return NO;
			}

		if (!((NSString *)aString)->_cString)	// a unichar string without a
			[aString cString];					// C str backing, generate it

		return (memcmp(_cString,((NSString *)aString)->_cString, _count) == 0);
		}

	return NO;
}

- (NSStringEncoding) fastestEncoding
{
	NSStringEncoding e = CFStringGetSystemEncoding();

    return ((e == NSASCIIStringEncoding) || (e == NSISOLatin1StringEncoding))
			? e : NSUTF8StringEncoding;
}

- (NSStringEncoding) smallestEncoding	{ return CFStringGetSystemEncoding(); }

@end /* _NSCString */

/* ****************************************************************************

 		_NSMutableCString

** ***************************************************************************/

@implementation _NSMutableCString

- (id) initWithCapacity:(NSUInteger)capacity
{													// designated initializer 
	_count = 0;										// for this class
	_capacity = capacity + 1;
	_cString = calloc(1, _capacity);

	return self;
}

- (id) initWithCharactersNoCopy:(unichar*)chars
						 length:(NSUInteger)length
						 freeWhenDone:(BOOL)flag
{
	[self release];

	return [[_NSMutableUString alloc] initWithCharactersNoCopy: chars
									  length: length
									  freeWhenDone: flag];
}

- (id) copy
{
	_NSCString *c = (_NSCString *)NSAllocateObject(__cStringClass);

	if (_hash && c)
		((_NSMutableCString *)c)->_hash = _hash;			// Same ivar layout
	c->_count = _count;
	c->_cString = _AllocCString(NULL, _count, _cString);

	return c;
}

- (void) deleteCharactersInRange:(NSRange)range
{
	NSUInteger mr = NSMaxRange(range);

	if (mr > _count || range.length == 0)
		[NSException raise: NSRangeException format:@"Invalid range."];

	if (_count - mr > 0)
		memmove(_cString + range.location, _cString + mr, _count - mr);
	_count -= range.length;
	_cString[_count] = '\0';
	_hash = 0;
}

- (void) replaceCharactersInRange:(NSRange)range withString:(NSString*)aString
{
	NSUInteger c = [aString cStringLength];
	NSUInteger s = (_count - range.length) + c;
	NSUInteger mr = NSMaxRange(range);
	char *t = _AllocCString(NULL, s, NULL);

	if(range.location > 0)									// copy self upto
		memcpy(t, _cString, range.location);				// index if needed
	[aString getCString: t + range.location];
	memcpy(t + range.location + c, _cString + mr, (_count - mr) + 1);
	free(_cString);
	_cString = t;
	_hash = 0;
	_count = s;
	_cString[_count] = '\0';
}

- (NSUInteger) replaceOccurrencesOfString:(NSString *)target
							   withString:(NSString *)replace
								  options:(NSStringCompareOptions)opts
									range:(NSRange)searchRange
{
	NSRange	r = [self rangeOfString:target options:opts range:searchRange];
	NSUInteger i, rl = [replace length];

	for (i = 0; r.length > 0 && replace != nil; i++)
		{
		[self replaceCharactersInRange:r withString:replace];

		if ((opts & NSBackwardsSearch) == NSBackwardsSearch)
			searchRange.length = r.location - searchRange.location;
		else
			{
			NSUInteger end = NSMaxRange(searchRange) + rl - r.length;

			searchRange.location = r.location + rl;
			searchRange.length = end - searchRange.location;
			}

		r = [self rangeOfString:target options:opts range:searchRange];
		}

	return i;
}

- (void) insertString:(NSString*)aString atIndex:(NSUInteger)index
{
	NSUInteger c = [aString cStringLength];
	char *t = _AllocCString(NULL, _count + c, NULL);

	if(index > 0)											// copy self upto
		memcpy(t, _cString, index);							// index if needed
	[aString getCString: t + index];
	memcpy(t + index + c, _cString + index, (_count - index) + 1);
	free(_cString);
	_cString = t;
	_hash = 0;
	_count += c;
	_cString[_count] = '\0';
}

- (void) appendString:(NSString*)aString
{
	if ((aString != nil) && (CLS_ISCLASS(((Class)aString)->class_pointer)))
		{
		Class c = ((Class)aString)->class_pointer;
		_NSMutableCString *other = nil;
		NSUInteger l;

		if (c == __cStringClass || c == __mutableCStringClass
				|| c == __constantStringClass)
			{
			other = (_NSMutableCString*)aString;
			l = other->_count;
			}
		else
			l = [aString cStringLength];

		if (_count + l >= _capacity)
			{
			_capacity = MAX(_capacity * 2, _count + l + 1);
			_cString = _AllocCString(_cString, _capacity, NULL);
			}

		if (other)
			memcpy(_cString + _count, other->_cString, l);
		else
			[aString getCString: _cString + _count];
		_count += l;
		_cString[_count] = '\0';
		_hash = 0;
		}
}

- (void) appendFormat:(NSString*)format, ...
{
	va_list ap;
	id tmp;

	va_start(ap, format);
	tmp = [[_NSCString alloc] initWithFormat:format arguments:ap];
	va_end(ap);

	[self appendString:tmp];
	[tmp release];
}

- (void) setString:(NSString*)aString
{
	NSUInteger length = [aString cStringLength];

	if (_capacity <= length)
		{
		_capacity = length + 1;
		_cString = _AllocCString(_cString, _capacity, NULL);
		}
	[aString getCString: _cString];
	_count = length;
	_hash = 0;
}

- (id) initWithCoder:(NSCoder*)aCoder
{
	NSUInteger cap;
  
	[aCoder decodeValueOfObjCType:@encode(NSUInteger) at:&cap];
	[self initWithCapacity:cap];
	if ((_count = cap) > 0)
		[aCoder decodeArrayOfObjCType: @encode(unsigned char) 
				count: _count
				at: _cString];
	_cString[_count] = '\0';

	return self;
}

@end /* _NSMutableCString */

/* ****************************************************************************

 		NSConstantString

** ***************************************************************************/

@implementation NSConstantString

	// If we pass an NSConstantString to another process or record it in an
	// archive and read it back, the new copy will never be deallocated -
	// causing a memory leak.  So we tell the system to use the super class.
- (Class) classForArchiver				{ return __cStringClass; }
- (Class) classForCoder					{ return __cStringClass; }
- (Class) classForPortCoder				{ return __cStringClass; }
- (void) dealloc						{ NO_WARN; }
- (oneway void) release					{ return; }
- (id) retain							{ return self; }
- (id) autorelease						{ return self; }
- (id) copy								{ return self; }
- (NSStringEncoding) fastestEncoding	{ return NSASCIIStringEncoding; }
- (NSStringEncoding) smallestEncoding	{ return NSASCIIStringEncoding; }

- (id) mutableCopy
{
	_NSMutableCString *m;

	if ((m = (_NSMutableCString*)NSAllocateObject(__mutableCStringClass)))
		{
		((NSConstantString *)m)->_cString = _AllocCString(NULL,_count,_cString);
		((NSConstantString *)m)->_count = _count;	// _capacity undefined (=0)
		}

	return m;
}

- (BOOL) isEqual:(id)obj
{
	if (obj == self)
		return YES;

    if ((obj != nil) && (CLS_ISCLASS(((Class)obj)->class_pointer))) 
		{
		Class c = ((Class)obj)->class_pointer;

		if (c != __cStringClass && c != __mutableCStringClass
				&& c != __constantStringClass
				&& !_classIsKindOfClass(c, __nsStringClass)) 
			return NO;

		if (_count != ((NSString *)obj)->_count)
			return NO;
		if (_count == 0)						// both are 0 len
			return YES;
		if (!((NSString *)obj)->_cString)		// a unichar string without a
			[obj cString];						// C str backing, generate it

		return (memcmp(_cString, ((NSString *)obj)->_cString, _count) == 0);
		}

    return NO;
}

- (BOOL) isEqualToString:(NSString*)aString
{
	if (aString == self)
		return YES;
	if (aString == nil || (_count != ((NSString *)aString)->_count))
		return NO;
	if (_count == 0)							// both are 0 len
		return YES;
	if (!((NSString *)aString)->_cString)		// a unichar string without a
		[aString cString];						// C str backing, generate it

	return (0 == memcmp(_cString, ((NSString *)aString)->_cString, _count));
}

@end /* NSConstantString */
