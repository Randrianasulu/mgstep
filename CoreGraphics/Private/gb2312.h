/*
	gb2312.h  --  map UCS-4 code point to font glyph

	Private font char encoding table for CJK GB2312
	Extracted from gb2312.1980-0.enc.gz file in X11 font encoding dir

	4E00 - 9FAF		CJK Unified Ideographs

	FIX ME incomplete
*/

#ifndef _GB2312_H_Encoding
#define _GB2312_H_Encoding

static const FontGlyph CJK_GB2312_Map[] = {
    { 0x5927, 0x3473 },
    { 0x6D3B, 0x3B6E },
    { 0x70B8, 0x5528 },
    { 0x7206, 0x312C },
    { 0x751f, 0x497A },
};

static const FontMap CJK_GB2312 = {
    CJK_GB2312_Map,
    sizeof (CJK_GB2312_Map) / sizeof (CJK_GB2312_Map[0]),
};

#endif /* _GB2312_H_Encoding */
