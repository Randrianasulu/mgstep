/*
   unicode.h

   Support functions for Unicode implementation

   Copyright (C) 1997 Free Software Foundation, Inc.

   Author:	Stevo Crvenkovski <stevo@btinternet.com>
   Date:	March 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_Unicode
#define _mGSTEP_H_Unicode

extern int _UTF8toUCS4 (const UInt8 *src, UInt32 *ucs4, int len);

extern int UStrToCStr(char *s2, unichar *u1, int size);

extern unichar ByteToUChar(char c);
extern char    UCharToByte(unichar u);

extern unichar encode_chartouni(unsigned char c, NSStringEncoding enc);
extern char    encode_unitochar(unichar u, NSStringEncoding enc);

int uslen (unichar *u);

unichar uni_tolower(unichar ch);
unichar uni_toupper(unichar ch);

unsigned char uni_cop(unichar u);
BOOL uni_isnonsp(unichar u);
unichar *uni_is_decomp(unichar u);

int encode_strtoustr(unichar *u1,
					 const unsigned char *s1,
					 int size,
					 NSStringEncoding e);

#endif /* _mGSTEP_H_Unicode */
