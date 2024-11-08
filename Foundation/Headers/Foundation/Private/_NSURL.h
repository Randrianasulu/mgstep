/*
   _NSURL.h

   CFURL / NSURL internal utilities

   Copyright (C) 2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:	Nov 2020

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

enum {
	ALPHA    = 1,
	DELIM    = 2,
	HEXDIGIT = 4,
	PATH     = 8,
	SCHEME   = 16
};

static const unsigned char __URLValidCharacters[128] = {
    /* nul   0 */   0,
    /* soh   1 */   0,
    /* stx   2 */   0,
    /* etx   3 */   0,
    /* eot   4 */   0,
    /* enq   5 */   0,
    /* ack   6 */   0,
    /* bel   7 */   0,
    /* bs    8 */   0,
    /* ht    9 */   0,
    /* nl   10 */   0,
    /* vt   11 */   0,
    /* np   12 */   0,
    /* cr   13 */   0,
    /* so   14 */   0,
    /* si   15 */   0,
    /* dle  16 */   0,
    /* dc1  17 */   0,
    /* dc2  18 */   0,
    /* dc3  19 */   0,
    /* dc4  20 */   0,
    /* nak  21 */   0,
    /* syn  22 */   0,
    /* etb  23 */   0,
    /* can  24 */   0,
    /* em   25 */   0,
    /* sub  26 */   0,
    /* esc  27 */   0,
    /* fs   28 */   0,
    /* gs   29 */   0,
    /* rs   30 */   0,
    /* us   31 */   0,
    /* sp   32 */   0,
    /* '!'  33 */   PATH ,
    /* '"'  34 */   0,
    /* '#'  35 */   DELIM,
    /* '$'  36 */   PATH ,
    /* '%'  37 */   0,
    /* '&'  38 */   PATH ,
    /* '''  39 */   PATH ,
    /* '('  40 */   PATH ,
    /* ')'  41 */   PATH ,
    /* '*'  42 */   PATH ,
    /* '+'  43 */   PATH | SCHEME ,
    /* ','  44 */   PATH ,
    /* '-'  45 */   PATH | SCHEME ,
    /* '.'  46 */   PATH | SCHEME ,
    /* '/'  47 */   PATH ,
    /* '0'  48 */   HEXDIGIT | PATH | SCHEME ,
    /* '1'  49 */   HEXDIGIT | PATH | SCHEME ,
    /* '2'  50 */   HEXDIGIT | PATH | SCHEME ,
    /* '3'  51 */   HEXDIGIT | PATH | SCHEME ,
    /* '4'  52 */   HEXDIGIT | PATH | SCHEME ,
    /* '5'  53 */   HEXDIGIT | PATH | SCHEME ,
    /* '6'  54 */   HEXDIGIT | PATH | SCHEME ,
    /* '7'  55 */   HEXDIGIT | PATH | SCHEME ,
    /* '8'  56 */   HEXDIGIT | PATH | SCHEME ,
    /* '9'  57 */   HEXDIGIT | PATH | SCHEME ,
    /* ':'  58 */   DELIM ,
    /* ';'  59 */   DELIM ,
    /* '<'  60 */   0,
    /* '='  61 */   PATH ,
    /* '>'  62 */   0,
    /* '?'  63 */   DELIM ,
    /* '@'  64 */   DELIM ,
    /* 'A'  65 */   ALPHA | HEXDIGIT | PATH | SCHEME ,
    /* 'B'  66 */   ALPHA | HEXDIGIT | PATH | SCHEME ,
    /* 'C'  67 */   ALPHA | HEXDIGIT | PATH | SCHEME ,
    /* 'D'  68 */   ALPHA | HEXDIGIT | PATH | SCHEME ,
    /* 'E'  69 */   ALPHA | HEXDIGIT | PATH | SCHEME ,
    /* 'F'  70 */   ALPHA | HEXDIGIT | PATH | SCHEME ,
    /* 'G'  71 */   ALPHA | PATH | SCHEME ,
    /* 'H'  72 */   ALPHA | PATH | SCHEME ,
    /* 'I'  73 */   ALPHA | PATH | SCHEME ,
    /* 'J'  74 */   ALPHA | PATH | SCHEME ,
    /* 'K'  75 */   ALPHA | PATH | SCHEME ,
    /* 'L'  76 */   ALPHA | PATH | SCHEME ,
    /* 'M'  77 */   ALPHA | PATH | SCHEME ,
    /* 'N'  78 */   ALPHA | PATH | SCHEME ,
    /* 'O'  79 */   ALPHA | PATH | SCHEME ,
    /* 'P'  80 */   ALPHA | PATH | SCHEME ,
    /* 'Q'  81 */   ALPHA | PATH | SCHEME ,
    /* 'R'  82 */   ALPHA | PATH | SCHEME ,
    /* 'S'  83 */   ALPHA | PATH | SCHEME ,
    /* 'T'  84 */   ALPHA | PATH | SCHEME ,
    /* 'U'  85 */   ALPHA | PATH | SCHEME ,
    /* 'V'  86 */   ALPHA | PATH | SCHEME ,
    /* 'W'  87 */   ALPHA | PATH | SCHEME ,
    /* 'X'  88 */   ALPHA | PATH | SCHEME ,
    /* 'Y'  89 */   ALPHA | PATH | SCHEME ,
    /* 'Z'  90 */   ALPHA | PATH | SCHEME ,
    /* '['  91 */   DELIM,
    /* '\'  92 */   0,
    /* ']'  93 */   DELIM,
    /* '^'  94 */   0,
    /* '_'  95 */   PATH ,
    /* '`'  96 */   0,
    /* 'a'  97 */   ALPHA | HEXDIGIT | PATH | SCHEME ,
    /* 'b'  98 */   ALPHA | HEXDIGIT | PATH | SCHEME ,
    /* 'c'  99 */   ALPHA | HEXDIGIT | PATH | SCHEME ,
    /* 'd' 100 */   ALPHA | HEXDIGIT | PATH | SCHEME ,
    /* 'e' 101 */   ALPHA | HEXDIGIT | PATH | SCHEME ,
    /* 'f' 102 */   ALPHA | HEXDIGIT | PATH | SCHEME ,
    /* 'g' 103 */   ALPHA | PATH | SCHEME ,
    /* 'h' 104 */   ALPHA | PATH | SCHEME ,
    /* 'i' 105 */   ALPHA | PATH | SCHEME ,
    /* 'j' 106 */   ALPHA | PATH | SCHEME ,
    /* 'k' 107 */   ALPHA | PATH | SCHEME ,
    /* 'l' 108 */   ALPHA | PATH | SCHEME ,
    /* 'm' 109 */   ALPHA | PATH | SCHEME ,
    /* 'n' 110 */   ALPHA | PATH | SCHEME ,
    /* 'o' 111 */   ALPHA | PATH | SCHEME ,
    /* 'p' 112 */   ALPHA | PATH | SCHEME ,
    /* 'q' 113 */   ALPHA | PATH | SCHEME ,
    /* 'r' 114 */   ALPHA | PATH | SCHEME ,
    /* 's' 115 */   ALPHA | PATH | SCHEME ,
    /* 't' 116 */   ALPHA | PATH | SCHEME ,
    /* 'u' 117 */   ALPHA | PATH | SCHEME ,
    /* 'v' 118 */   ALPHA | PATH | SCHEME ,
    /* 'w' 119 */   ALPHA | PATH | SCHEME ,
    /* 'x' 120 */   ALPHA | PATH | SCHEME ,
    /* 'y' 121 */   ALPHA | PATH | SCHEME ,
    /* 'z' 122 */   ALPHA | PATH | SCHEME ,
    /* '{' 123 */   0,
    /* '|' 124 */   0,
    /* '}' 125 */   0,
    /* '~' 126 */   PATH ,
    /* del 127 */   0,
};


inline BOOL isALPHA(UniChar ch)
{
    return (ch <= 127) ? ((__URLValidCharacters[ch] & ALPHA) != 0) : false;
}

inline BOOL isDELIM(UniChar ch)
{
    return (ch <= 127) ? ((__URLValidCharacters[ch] & DELIM) != 0) : false;
}

inline BOOL isHEXDIGIT(UniChar ch)
{
    return (ch <= 127) ? ((__URLValidCharacters[ch] & HEXDIGIT) != 0) : false;
}

inline BOOL isPATH(UniChar ch)
{
    return (ch <= 127) ? ((__URLValidCharacters[ch] & PATH) != 0) : false;
}

inline BOOL isSCHEME(UniChar ch)
{
    return (ch <= 127) ? ((__URLValidCharacters[ch] & SCHEME) != 0) : false;
}


enum {
	OTHER      = 0,			// s/b percent encoded
	RESERVED   = 1,			// s/b percent encoded if included for other uses
	UNRESERVED = 2
};

static const unsigned char __RFC3986Characters[128] = {
    /* nul   0 */   0,
    /* soh   1 */   0,
    /* stx   2 */   0,
    /* etx   3 */   0,
    /* eot   4 */   0,
    /* enq   5 */   0,
    /* ack   6 */   0,
    /* bel   7 */   0,
    /* bs    8 */   0,
    /* ht    9 */   0,
    /* nl   10 */   0,
    /* vt   11 */   0,
    /* np   12 */   0,
    /* cr   13 */   0,
    /* so   14 */   0,
    /* si   15 */   0,
    /* dle  16 */   0,
    /* dc1  17 */   0,
    /* dc2  18 */   0,
    /* dc3  19 */   0,
    /* dc4  20 */   0,
    /* nak  21 */   0,
    /* syn  22 */   0,
    /* etb  23 */   0,
    /* can  24 */   0,
    /* em   25 */   0,
    /* sub  26 */   0,
    /* esc  27 */   0,
    /* fs   28 */   0,
    /* gs   29 */   0,
    /* rs   30 */   0,
    /* us   31 */   0,
    /* sp   32 */   0,
    /* '!'  33 */   RESERVED ,
    /* '"'  34 */   0,
    /* '#'  35 */   RESERVED ,
    /* '$'  36 */   RESERVED ,
    /* '%'  37 */   0,						// encoding delim
    /* '&'  38 */   RESERVED ,
    /* '''  39 */   RESERVED ,
    /* '('  40 */   RESERVED ,
    /* ')'  41 */   RESERVED ,
    /* '*'  42 */   RESERVED ,
    /* '+'  43 */   RESERVED ,
    /* ','  44 */   RESERVED ,
    /* '-'  45 */   UNRESERVED ,
    /* '.'  46 */   UNRESERVED ,
    /* '/'  47 */   RESERVED ,
    /* '0'  48 */   UNRESERVED ,
    /* '1'  49 */   UNRESERVED ,
    /* '2'  50 */   UNRESERVED ,
    /* '3'  51 */   UNRESERVED ,
    /* '4'  52 */   UNRESERVED ,
    /* '5'  53 */   UNRESERVED ,
    /* '6'  54 */   UNRESERVED ,
    /* '7'  55 */   UNRESERVED ,
    /* '8'  56 */   UNRESERVED ,
    /* '9'  57 */   UNRESERVED ,
    /* ':'  58 */   RESERVED ,
    /* ';'  59 */   RESERVED ,
    /* '<'  60 */   0,
    /* '='  61 */   RESERVED ,
    /* '>'  62 */   0,
    /* '?'  63 */   RESERVED ,
    /* '@'  64 */   RESERVED ,
    /* 'A'  65 */   UNRESERVED ,
    /* 'B'  66 */   UNRESERVED ,
    /* 'C'  67 */   UNRESERVED ,
    /* 'D'  68 */   UNRESERVED ,
    /* 'E'  69 */   UNRESERVED ,
    /* 'F'  70 */   UNRESERVED ,
    /* 'G'  71 */   UNRESERVED ,
    /* 'H'  72 */   UNRESERVED ,
    /* 'I'  73 */   UNRESERVED ,
    /* 'J'  74 */   UNRESERVED ,
    /* 'K'  75 */   UNRESERVED ,
    /* 'L'  76 */   UNRESERVED ,
    /* 'M'  77 */   UNRESERVED ,
    /* 'N'  78 */   UNRESERVED ,
    /* 'O'  79 */   UNRESERVED ,
    /* 'P'  80 */   UNRESERVED ,
    /* 'Q'  81 */   UNRESERVED ,
    /* 'R'  82 */   UNRESERVED ,
    /* 'S'  83 */   UNRESERVED ,
    /* 'T'  84 */   UNRESERVED ,
    /* 'U'  85 */   UNRESERVED ,
    /* 'V'  86 */   UNRESERVED ,
    /* 'W'  87 */   UNRESERVED ,
    /* 'X'  88 */   UNRESERVED ,
    /* 'Y'  89 */   UNRESERVED ,
    /* 'Z'  90 */   UNRESERVED ,
    /* '['  91 */   RESERVED ,
    /* '\'  92 */   0,
    /* ']'  93 */   RESERVED ,
    /* '^'  94 */   0,
    /* '_'  95 */   UNRESERVED ,
    /* '`'  96 */   0,
    /* 'a'  97 */   UNRESERVED ,
    /* 'b'  98 */   UNRESERVED ,
    /* 'c'  99 */   UNRESERVED ,
    /* 'd' 100 */   UNRESERVED ,
    /* 'e' 101 */   UNRESERVED ,
    /* 'f' 102 */   UNRESERVED ,
    /* 'g' 103 */   UNRESERVED ,
    /* 'h' 104 */   UNRESERVED ,
    /* 'i' 105 */   UNRESERVED ,
    /* 'j' 106 */   UNRESERVED ,
    /* 'k' 107 */   UNRESERVED ,
    /* 'l' 108 */   UNRESERVED ,
    /* 'm' 109 */   UNRESERVED ,
    /* 'n' 110 */   UNRESERVED ,
    /* 'o' 111 */   UNRESERVED ,
    /* 'p' 112 */   UNRESERVED ,
    /* 'q' 113 */   UNRESERVED ,
    /* 'r' 114 */   UNRESERVED ,
    /* 's' 115 */   UNRESERVED ,
    /* 't' 116 */   UNRESERVED ,
    /* 'u' 117 */   UNRESERVED ,
    /* 'v' 118 */   UNRESERVED ,
    /* 'w' 119 */   UNRESERVED ,
    /* 'x' 120 */   UNRESERVED ,
    /* 'y' 121 */   UNRESERVED ,
    /* 'z' 122 */   UNRESERVED ,
    /* '{' 123 */   0,
    /* '|' 124 */   0,
    /* '}' 125 */   0,
    /* '~' 126 */   UNRESERVED ,
    /* del 127 */   0,
};


inline BOOL isRESERVED(UniChar ch)
{
    return (ch <= 127) ? ((__RFC3986Characters[ch] & RESERVED) != 0) : false;
}
