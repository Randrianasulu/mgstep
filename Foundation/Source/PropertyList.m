/*
   PropertyList.m

   Property List parsing functions.

   Copyright (C) 1998 Free Software Foundation, Inc.

   Author:	Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date:	October 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSData.h>
#include <Foundation/NSException.h>
#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>

#define inrange(ch,min,max)  ((ch)>=(min) && (ch)<=(max))
#define char2num(ch)  inrange(ch,'0','9') ? ((ch)-0x30) : (inrange(ch,'a','f') \
										  ? ((ch)-0x57) : ((ch)-0x37))

typedef	struct {
	const unichar *ptr;
	unsigned end;
	unsigned pos;
	unsigned lin;
	NSString *err;
} pldata;


static SEL __charIsMem = NULL;
static NSCharacterSet *__hexDgts = nil;
static NSCharacterSet *__quotes = nil;
static NSCharacterSet *__whitespce = nil;

static BOOL (*__whitespceIMP)(id, SEL, unichar) = 0;
static BOOL (*__hexDgtsIMP)(id, SEL, unichar) = 0;
static BOOL (*__quotesIMP)(id, SEL, unichar) = 0;


static void
init_plparser (void)
{									// " \t\r\n\f\b"
	__whitespce = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	[__whitespce retain];
	__charIsMem = @selector(characterIsMember:);
	__whitespceIMP = (BOOL(*)(id,SEL,unichar))
						[__whitespce methodForSelector: __charIsMem];
	__hexDgts = [NSCharacterSet characterSetWithCharactersInString:
				@"0123456789abcdef"];
	[__hexDgts retain];
	__hexDgtsIMP = (BOOL(*)(id,SEL,unichar)) [__hexDgts
						methodForSelector: @selector(characterIsMember:)];

	__quotes = [NSMutableCharacterSet characterSetWithCharactersInString:
	@"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz$./_"];
	[(NSMutableCharacterSet *)__quotes invert];
	__quotes = [__quotes copy];
	__quotesIMP = (BOOL(*)(id,SEL,unichar)) [__quotes
						methodForSelector: @selector(characterIsMember:)];
}

static BOOL
skipSpace(pldata *pld)
{
	unichar c;						// Property list parsing - skip whitespace
									// track line count and regard objective-c
	while (pld->pos < pld->end)		// style comments as whitespace.  Returns 
		{							// YES if there is any non-whitespace text 
		c = pld->ptr[pld->pos];		// remaining.

		if ((*__whitespceIMP)(__whitespce, __charIsMem, c) == NO)
			{
			if (c == '/' && pld->pos < pld->end - 1)
				{				// Check for comments beginning '//' or '/*'
				if (pld->ptr[pld->pos + 1] == '/')
					{
					pld->pos += 2;
					while (pld->pos < pld->end)
						{
						c = pld->ptr[pld->pos];
						if (c == '\n')
							break;
						pld->pos++;
						}
					if (pld->pos >= pld->end)
						{
						pld->err = @"reached end of string in comment";
						return NO;
					}	}
				else 
					if (pld->ptr[pld->pos + 1] == '*')
						{
						pld->pos += 2;
						while (pld->pos < pld->end)
							{
							c = pld->ptr[pld->pos];
							if (c == '\n')
								pld->lin++;
							else 
								if (c == '*' && pld->pos < pld->end - 1
										&& pld->ptr[pld->pos+1] == '/')
									{
									pld->pos++; /* Skip past '*'	*/
									break;
									}
							pld->pos++;
							}
						if (pld->pos >= pld->end)
							{
							pld->err = @"reached end of string in comment";
							return NO;
						}	}
					else
						return YES;
				}
			else
				return YES;
			}
		if (c == '\n')
			pld->lin++;
		pld->pos++;
		}
	pld->err = @"reached end of string";

	return NO;
}

static inline id
parseQuotedString(pldata *pld)
{
	unsigned start = ++pld->pos;
	unsigned escaped = 0;
	unsigned shrink = 0;
	BOOL hex = NO;
	NSString *obj;

	while (pld->pos < pld->end)
		{
		unichar c = pld->ptr[pld->pos];

		if (escaped)
			{
			if (escaped == 1 && c == '0')
				{
				escaped = 2;
				hex = NO;
				}
			else 
				if (escaped > 1)
					{
	      			if (escaped == 2 && c == 'x')
						{
						hex = YES;
						shrink++;
						escaped++;
						}
					else 
						if (hex && (*__hexDgtsIMP)(__hexDgts, __charIsMem, c))
							{
							shrink++;
							escaped++;
							}
						else 
							if (c >= '0' && c <= '7')
								{
								shrink++;
								escaped++;
								}
							else
								escaped = 0;
					}
				else
					escaped = 0;
			}
		else
			{
			if (c == '\\')
				{
				escaped = 1;
				shrink++;
				}
			else 
				if (c == '"')
					break;
			}
		pld->pos++;
		}

	if (pld->pos >= pld->end)
		{
		pld->err = @"reached end of string while parsing quoted string";
		return nil;
		}

	if (pld->pos - start - shrink == 0)
		obj = @"";
	else
		{
		unichar	chars[pld->pos - start - shrink];
		unsigned j;
		unsigned k;
	
		escaped = 0;
		hex = NO;
		for (j = start, k = 0; j < pld->pos; j++)
			{
			unichar c = pld->ptr[j];

			if (escaped)
				{
				if (escaped == 1 && c == '0')
					{
					chars[k] = 0;
					hex = NO;
					escaped++;
					}
				else 
					if (escaped > 1)
						{
						if (escaped == 2 && c == 'x')
							{
							hex = YES;
							escaped++;
							}
						else 
							if(hex && (*__hexDgtsIMP)(__hexDgts,__charIsMem,c))
								{
								chars[k] <<= 4;
								chars[k] |= char2num(c);
								escaped++;
								}
							else 
								if (c >= '0' && c <= '7')
									{
									chars[k] <<= 3;
									chars[k] |= (c - '0');
									escaped++;
									}
								else
									{
									escaped = 0;
									chars[++k] = c;
									k++;
									}
					}
				else
					{
					escaped = 0;
					switch (c)
						{
						case 'a' : chars[k] = '\a'; break;
						case 'b' : chars[k] = '\b'; break;
						case 't' : chars[k] = '\t'; break;
						case 'r' : chars[k] = '\r'; break;
						case 'n' : chars[k] = '\n'; break;
						case 'v' : chars[k] = '\v'; break;
						case 'f' : chars[k] = '\f'; break;
						default  : chars[k] = c; break;
						}
					k++;
					}
				}
			else
				{
				chars[k] = c;
				if (c == '\\')
					escaped = 1;
				else
					k++;
			}	}

		obj = [NSString stringWithCharacters:chars 
						length:pld->pos - start - shrink];
		}
	pld->pos++;

	return obj;
}

static inline id
parseUnquotedString(pldata *pld)
{
	unsigned start = pld->pos;

	while (pld->pos < pld->end)
		{
		if ((*__quotesIMP)(__quotes, __charIsMem, pld->ptr[pld->pos]) == YES)
			break;
		pld->pos++;
		}

	return [NSString stringWithCharacters:&pld->ptr[start] 
					 length:pld->pos-start];
}

id
_ParsePropertyList(pldata *pld)
{
	if (!__whitespce)
		init_plparser ();

	if (skipSpace(pld) == NO)
		return nil;

	switch (pld->ptr[pld->pos])
		{
		case '{':
			{
	  		NSMutableDictionary *dict;

	  		pld->pos++;
			if (pld->ptr[pld->pos] == '{')	  // found rect str not a new dict
				{
				unsigned int start = --pld->pos;

	  			while (skipSpace(pld) == YES && pld->ptr[pld->pos] != ';')
					{
	  				pld->pos++;
					if (pld->pos >= pld->end)
						{
						pld->err = @"unexpected end of string when parsing rect";
						return @"";
						}
					}

				return [NSString stringWithCharacters: &pld->ptr[start]
								 length: pld->pos - start];
				}

	  		dict = [NSMutableDictionary dictionaryWithCapacity: 0];
	  		while (skipSpace(pld) == YES && pld->ptr[pld->pos] != '}')
	    		{
	      		id key = _ParsePropertyList(pld);
	      		id val;

				if (key == nil)
					return nil;
				if (skipSpace(pld) == NO)
					return nil;
				if (pld->ptr[pld->pos] != '=')
					{
					pld->err = @"PL unexpected char (wanted '=')";
		  			return nil;
					}
	      		pld->pos++;
				val = _ParsePropertyList(pld);
	      		if (val == nil)
					return nil;
	      		if (skipSpace(pld) == NO)
					return nil;

	      		if (pld->ptr[pld->pos] == ';')
					pld->pos++;
	     		 else if (pld->ptr[pld->pos] != '}')
					{
					pld->err = @"PL unexpected char (wanted ';' or '}')";
					return nil;
					}
				[dict setObject: val forKey: key];
				}
	  		if (pld->pos >= pld->end)
				{
				pld->err = @"unexpected end of string when parsing dictionary";
				return nil;
				}
			pld->pos++;

			return dict;
			}

		case '(':
			{
			NSMutableArray *array = [NSMutableArray arrayWithCapacity: 0];

			pld->pos++;
			while (skipSpace(pld) == YES && pld->ptr[pld->pos] != ')')
				{
				id val = _ParsePropertyList(pld);
	
				if (val == nil)
					return nil;
				if (skipSpace(pld) == NO)
					return nil;
				if (pld->ptr[pld->pos] == ',')
					pld->pos++;
				else 
					if (pld->ptr[pld->pos] != ')')
						{
						pld->err =@"GSPPL unexpected char (wanted ',' or ')')";
						return nil;
						}
				[array addObject: val];
				}
			if (pld->pos >= pld->end)
				{
				pld->err = @"unexpected end of string when parsing array";
				return nil;
				}
			pld->pos++;

			return array;
			}

		case '<':
			{
			NSMutableData *data = [NSMutableData dataWithCapacity: 0];
			unsigned max = pld->end - 1;
			unsigned char buf[BUFSIZ];
			unsigned len = 0;
	
//			pld->pos++;
			while (++pld->pos < max && skipSpace(pld) == YES && pld->ptr[pld->pos] != '>')
				{
				while (pld->pos < max
				&& (*__hexDgtsIMP)(__hexDgts, __charIsMem, pld->ptr[pld->pos])
				&& (*__hexDgtsIMP)(__hexDgts,__charIsMem,pld->ptr[pld->pos+1]))
					{
					unsigned char byte = (char2num(pld->ptr[pld->pos])) << 4;
	
					pld->pos++;
					byte |= char2num(pld->ptr[pld->pos]);
					pld->pos++;
					buf[len++] = byte;
					if (len > sizeof(buf))
						{
						[data appendBytes: buf length: len];
						len = 0;
				}	}	}

			if (pld->pos >= pld->end)
				{
				pld->err = @"unexpected end of string when parsing data";
				return nil;
				}
			if (pld->ptr[pld->pos] != '>')
				{
				pld->err = @"unexpected character in string";
				return nil;
				}
			if (len > 0)
				[data appendBytes: buf length: len];
			pld->pos++;

			return data;
			}
	
		case '"':
			return parseQuotedString(pld);
	
		default:
			return parseUnquotedString(pld);
		}
}

NSMutableDictionary *
_ParseStringFileFormatPropertyList(pldata *pld)
{
	NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity: 0];

	if (!__whitespce)
		init_plparser ();

	while (skipSpace(pld) == YES)
		{
		id key, val;

		if (pld->ptr[pld->pos] == '"')
			key = parseQuotedString(pld);
		else
			key = parseUnquotedString(pld);
		if (key == nil)
			return nil;
		if (skipSpace(pld) == NO)
			{
			pld->err = @"incomplete final entry (no semicolon?)";
			return nil;
			}
		if (pld->ptr[pld->pos] == ';')
			{
			pld->pos++;
			[d setObject: @"" forKey: key];
			}
		else 
			if (pld->ptr[pld->pos] == '=')
				{
				pld->pos++;
				if (skipSpace(pld) == NO)
					return nil;
				if (pld->ptr[pld->pos] == '"')
					val = parseQuotedString(pld);
				else
					val = parseUnquotedString(pld);
				if (val == nil)
					return nil;
				if (skipSpace(pld) == NO)
					{
					pld->err = @"missing final semicolon";
					return nil;
					}
				[d setObject: val forKey: key];
				if (pld->ptr[pld->pos] == ';')
					pld->pos++;
				else
					{
					pld->err = @"unexpected character (wanted ';')";
					return nil;
				}	}
			else
				{
				pld->err = @"unexpected character (wanted '=' or ';')";
				return nil;
		}		}

	return d;
}

/* ****************************************************************************

 		NSString  (OSPropertyListString)    OPENSTEP style Property Lists

** ***************************************************************************/

@implementation NSString  (OSPropertyListString)

- (id) propertyList
{
	unichar	chars[_count];
	pldata data;
	id pl;

	data.ptr = chars;
	data.pos = 0;
	data.end = _count;
	data.lin = 1;
	data.err = nil;
	
	[self getCharacters: chars];
	
	pl = _ParsePropertyList(&data);
	
	if (pl == nil && data.err != nil)
		[NSException raise: NSGenericException
					 format: @"%@ at line %u", data.err, data.lin];
	return pl;
}

- (NSDictionary*) propertyListFromStringsFileFormat
{
	unichar chars[_count];
	NSDictionary *d;
	pldata data;

	data.ptr = chars;
	data.pos = 0;
	data.end = _count;
	data.lin = 1;
	data.err = nil;
	
	[self getCharacters: chars];
	
	d = _ParseStringFileFormatPropertyList(&data);
	if (d == nil && data.err != nil)
		[NSException raise: NSGenericException
					 format: @"%@ at line %u", data.err, data.lin];
	return d;
}

@end
