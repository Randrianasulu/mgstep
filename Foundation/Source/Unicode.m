/*
   Unicode.m

   Support functions for Unicode implementation

   Copyright (C) 1997-2021 Free Software Foundation, Inc.

   Author:	Stevo Crvenkovski <stevo@btinternet.com>
   Date:	March 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>
#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFString.h>

#include <Foundation/Private/unicode/nextstep.h>
#include <Foundation/Private/unicode/caseconv.h>
#include <Foundation/Private/unicode/cyrillic.h>
#include <Foundation/Private/unicode/cop.h>
#include <Foundation/Private/unicode/decomp.h>


static BOOL __warning = NO;


unichar
encode_chartouni(unsigned char c, NSStringEncoding e)
{	
	switch (e)
		{
		case NSUTF8StringEncoding:
			if (c >= 128 && !__warning)		// an error if system encoding is
				{							// UTF8 and a UTF8 encoded C string
				__warning = YES;			// was ingested as single bytes
				NSLog(@"WARNING: UTF8 byte cannot be cast to unichar ******");
				}

		case NSASCIIStringEncoding:
		case NSNonLossyASCIIStringEncoding:
		case NSISOLatin1StringEncoding:
			return (unichar)(c);

		case NSNEXTSTEPStringEncoding:	// All that I could find in Next docs
			if (c < NeXT_conv_base)		// on NSNonLossyASCIIStringEncoding
				return (unichar)(c);

			return (NeXT_char_to_unichar_table[c - NeXT_conv_base]);

		case NSWindowsCP1251StringEncoding:
			if (c < Cyrillic_conv_base)
				return (unichar)(c);

			return (Cyrillic_char_to_uni_table[c - Cyrillic_conv_base]);
		}

	return (unichar)(0);
}

char
encode_unitochar(unichar u, NSStringEncoding e)
{
	int r, i = 0;

    switch (e)
		{
		case NSNonLossyASCIIStringEncoding:
		case NSASCIIStringEncoding:
			return (u < 128) ? (char)u : 0;

		case NSUTF8StringEncoding:
		case NSISOLatin1StringEncoding:
			return (u < 256) ? (char)u : 0;

		case NSNEXTSTEPStringEncoding:
			if (u < (unichar)NeXT_conv_base)
				return (char)u;

			while (((r = u - NeXT_unichar_to_char_table[i++].from) > 0)
					&& (i < NeXT_uni_to_char_table_size));

			return r ? 0 : NeXT_unichar_to_char_table[--i].to;

		case NSWindowsCP1251StringEncoding:
			if (u < (unichar)Cyrillic_conv_base)
				return (char)u;

			while (((r = u - Cyrillic_uni_to_char_table[i++].from) > 0)
					&& (i < Cyrillic_uni_to_char_table_size));

			return r ? 0 : Cyrillic_uni_to_char_table[--i].to;
		}

	return (unichar)(0);
}

int
encode_strtoustr(unichar *u1, const unsigned char *s1, int size, NSStringEncoding e)
{
	int cnt;

	for (cnt = 0; (cnt < size) && (s1[cnt] != 0); cnt++)
		u1[cnt] = encode_chartouni(s1[cnt], e);

	return cnt;
}

int
uslen (unichar *u)						// Be careful if you use this. Unicode
{										// arrays returned by -getCharacters
	int len = 0;						// methods are not zero terminated

	while (u[len] != 0)
		{
		if (u[++len] == 0)
			return len;
		++len;
		}

	return len;
}

unichar
uni_tolower(unichar ch)
{
	int r;
	int cnt = 0;

	while (((r = ch - t_tolower[cnt++][0]) > 0) && (cnt < t_len_tolower));
	
	return r ? ch : t_tolower[--cnt][1];
}

unichar
uni_toupper(unichar ch)
{
	int r;
	int cnt = 0;

	while (((r = ch - t_toupper[cnt++][0]) > 0) && (cnt < t_len_toupper));

	return r ? ch : t_toupper[--cnt][1];
 }

unsigned char
uni_cop(unichar u)
{
	if (u > (unichar)0x0080)						// no nonspacing in ascii
		{
		unichar last = uni_cop_table_size;
		unichar count = 0;
		unichar first = 0;
		unichar comp;
		BOOL notfound = YES;

		while (notfound && (first <= last))
			{
			if(!(first == last))
				{
				count = (first + last) / 2;
				comp = uni_cop_table[count].code;
		
				if(comp < u)
					first = count+1;
				else if(comp > u)
					last = count-1;
				else
					notfound = NO;
				}
			else  										// first == last
				{
				if (u == uni_cop_table[first].code)
					return uni_cop_table[first].cop;
		
				return 0;	
			}	}										// else while not found

		return (notfound) ? 0: uni_cop_table[count].cop;
		}

	return 0;											// u is ascii
}

BOOL
uni_isnonsp(unichar u)
{
	return (uni_cop(u)) ? YES : NO;
}

unichar *
uni_is_decomp(unichar u)
{
	if (u > (unichar)0x0080)  						// no composites in ascii
		{
		unichar count = 0, first = 0, last = uni_dec_table_size, comp;
		BOOL notfound = YES;

		while(notfound && (first <= last))
			{
			if(!(first == last))
				{
				count = (first + last) / 2;
				comp = uni_dec_table[count].code;

				if(comp < u)
					first = count+1;
				else if(comp > u)
					last = count-1;
				else
					notfound = NO;
				}
			else										// first == last
				{
				if(u == uni_dec_table[first].code)
					return uni_dec_table[first].decomp;

				return 0;
			}	}										// else while not found

		return (notfound) ? 0 : uni_dec_table[count].decomp;
		}

	return 0;											// u is ascii
}
