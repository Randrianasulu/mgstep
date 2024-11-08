/*
	encoding.h  --  map uchar code to font glyph
	
	Private font char encoding tables
*/

#ifndef _Font_H_Encoding
#define _Font_H_Encoding

typedef struct {
    UInt16 bmp;								// Basic Multilingual Plane uchar
    UInt16 index;							// font glyph index
} FontGlyph;

typedef struct {
    const FontGlyph *items;
    int num_entries;
} FontMap;

typedef struct {
    FT_Encoding    encoding;
    const FontMap *map;
    UInt32         max;
} FontDecode;


static const FontGlyph AppleRoman_Map[] = {
    { 0x0020, 0x20 }, /* SPACE */
    { 0x0021, 0x21 }, /* EXCLAMATION MARK */
    { 0x0022, 0x22 }, /* QUOTATION MARK */
    { 0x0023, 0x23 }, /* NUMBER SIGN */
    { 0x0024, 0x24 }, /* DOLLAR SIGN */
    { 0x0025, 0x25 }, /* PERCENT SIGN */
    { 0x0026, 0x26 }, /* AMPERSAND */
    { 0x0027, 0x27 }, /* APOSTROPHE */
    { 0x0028, 0x28 }, /* LEFT PARENTHESIS */
    { 0x0029, 0x29 }, /* RIGHT PARENTHESIS */
    { 0x002A, 0x2A }, /* ASTERISK */
    { 0x002B, 0x2B }, /* PLUS SIGN */
    { 0x002C, 0x2C }, /* COMMA */
    { 0x002D, 0x2D }, /* HYPHEN-MINUS */
    { 0x002E, 0x2E }, /* FULL STOP */
    { 0x002F, 0x2F }, /* SOLIDUS */
    { 0x0030, 0x30 }, /* DIGIT ZERO */
    { 0x0031, 0x31 }, /* DIGIT ONE */
    { 0x0032, 0x32 }, /* DIGIT TWO */
    { 0x0033, 0x33 }, /* DIGIT THREE */
    { 0x0034, 0x34 }, /* DIGIT FOUR */
    { 0x0035, 0x35 }, /* DIGIT FIVE */
    { 0x0036, 0x36 }, /* DIGIT SIX */
    { 0x0037, 0x37 }, /* DIGIT SEVEN */
    { 0x0038, 0x38 }, /* DIGIT EIGHT */
    { 0x0039, 0x39 }, /* DIGIT NINE */
    { 0x003A, 0x3A }, /* COLON */
    { 0x003B, 0x3B }, /* SEMICOLON */
    { 0x003C, 0x3C }, /* LESS-THAN SIGN */
    { 0x003D, 0x3D }, /* EQUALS SIGN */
    { 0x003E, 0x3E }, /* GREATER-THAN SIGN */
    { 0x003F, 0x3F }, /* QUESTION MARK */
    { 0x0040, 0x40 }, /* COMMERCIAL AT */
    { 0x0041, 0x41 }, /* LATIN CAPITAL LETTER A */
    { 0x0042, 0x42 }, /* LATIN CAPITAL LETTER B */
    { 0x0043, 0x43 }, /* LATIN CAPITAL LETTER C */
    { 0x0044, 0x44 }, /* LATIN CAPITAL LETTER D */
    { 0x0045, 0x45 }, /* LATIN CAPITAL LETTER E */
    { 0x0046, 0x46 }, /* LATIN CAPITAL LETTER F */
    { 0x0047, 0x47 }, /* LATIN CAPITAL LETTER G */
    { 0x0048, 0x48 }, /* LATIN CAPITAL LETTER H */
    { 0x0049, 0x49 }, /* LATIN CAPITAL LETTER I */
    { 0x004A, 0x4A }, /* LATIN CAPITAL LETTER J */
    { 0x004B, 0x4B }, /* LATIN CAPITAL LETTER K */
    { 0x004C, 0x4C }, /* LATIN CAPITAL LETTER L */
    { 0x004D, 0x4D }, /* LATIN CAPITAL LETTER M */
    { 0x004E, 0x4E }, /* LATIN CAPITAL LETTER N */
    { 0x004F, 0x4F }, /* LATIN CAPITAL LETTER O */
    { 0x0050, 0x50 }, /* LATIN CAPITAL LETTER P */
    { 0x0051, 0x51 }, /* LATIN CAPITAL LETTER Q */
    { 0x0052, 0x52 }, /* LATIN CAPITAL LETTER R */
    { 0x0053, 0x53 }, /* LATIN CAPITAL LETTER S */
    { 0x0054, 0x54 }, /* LATIN CAPITAL LETTER T */
    { 0x0055, 0x55 }, /* LATIN CAPITAL LETTER U */
    { 0x0056, 0x56 }, /* LATIN CAPITAL LETTER V */
    { 0x0057, 0x57 }, /* LATIN CAPITAL LETTER W */
    { 0x0058, 0x58 }, /* LATIN CAPITAL LETTER X */
    { 0x0059, 0x59 }, /* LATIN CAPITAL LETTER Y */
    { 0x005A, 0x5A }, /* LATIN CAPITAL LETTER Z */
    { 0x005B, 0x5B }, /* LEFT SQUARE BRACKET */
    { 0x005C, 0x5C }, /* REVERSE SOLIDUS */
    { 0x005D, 0x5D }, /* RIGHT SQUARE BRACKET */
    { 0x005E, 0x5E }, /* CIRCUMFLEX ACCENT */
    { 0x005F, 0x5F }, /* LOW LINE */
    { 0x0060, 0x60 }, /* GRAVE ACCENT */
    { 0x0061, 0x61 }, /* LATIN SMALL LETTER A */
    { 0x0062, 0x62 }, /* LATIN SMALL LETTER B */
    { 0x0063, 0x63 }, /* LATIN SMALL LETTER C */
    { 0x0064, 0x64 }, /* LATIN SMALL LETTER D */
    { 0x0065, 0x65 }, /* LATIN SMALL LETTER E */
    { 0x0066, 0x66 }, /* LATIN SMALL LETTER F */
    { 0x0067, 0x67 }, /* LATIN SMALL LETTER G */
    { 0x0068, 0x68 }, /* LATIN SMALL LETTER H */
    { 0x0069, 0x69 }, /* LATIN SMALL LETTER I */
    { 0x006A, 0x6A }, /* LATIN SMALL LETTER J */
    { 0x006B, 0x6B }, /* LATIN SMALL LETTER K */
    { 0x006C, 0x6C }, /* LATIN SMALL LETTER L */
    { 0x006D, 0x6D }, /* LATIN SMALL LETTER M */
    { 0x006E, 0x6E }, /* LATIN SMALL LETTER N */
    { 0x006F, 0x6F }, /* LATIN SMALL LETTER O */
    { 0x0070, 0x70 }, /* LATIN SMALL LETTER P */
    { 0x0071, 0x71 }, /* LATIN SMALL LETTER Q */
    { 0x0072, 0x72 }, /* LATIN SMALL LETTER R */
    { 0x0073, 0x73 }, /* LATIN SMALL LETTER S */
    { 0x0074, 0x74 }, /* LATIN SMALL LETTER T */
    { 0x0075, 0x75 }, /* LATIN SMALL LETTER U */
    { 0x0076, 0x76 }, /* LATIN SMALL LETTER V */
    { 0x0077, 0x77 }, /* LATIN SMALL LETTER W */
    { 0x0078, 0x78 }, /* LATIN SMALL LETTER X */
    { 0x0079, 0x79 }, /* LATIN SMALL LETTER Y */
    { 0x007A, 0x7A }, /* LATIN SMALL LETTER Z */
    { 0x007B, 0x7B }, /* LEFT CURLY BRACKET */
    { 0x007C, 0x7C }, /* VERTICAL LINE */
    { 0x007D, 0x7D }, /* RIGHT CURLY BRACKET */
    { 0x007E, 0x7E }, /* TILDE */
    { 0x00A0, 0xCA }, /* NO-BREAK SPACE */
    { 0x00A1, 0xC1 }, /* INVERTED EXCLAMATION MARK */
    { 0x00A2, 0xA2 }, /* CENT SIGN */
    { 0x00A3, 0xA3 }, /* POUND SIGN */
    { 0x00A5, 0xB4 }, /* YEN SIGN */
    { 0x00A7, 0xA4 }, /* SECTION SIGN */
    { 0x00A8, 0xAC }, /* DIAERESIS */
    { 0x00A9, 0xA9 }, /* COPYRIGHT SIGN */
    { 0x00AA, 0xBB }, /* FEMININE ORDINAL INDICATOR */
    { 0x00AB, 0xC7 }, /* LEFT-POINTING DOUBLE ANGLE QUOTATION MARK */
    { 0x00AC, 0xC2 }, /* NOT SIGN */
    { 0x00AE, 0xA8 }, /* REGISTERED SIGN */
    { 0x00AF, 0xF8 }, /* MACRON */
    { 0x00B0, 0xA1 }, /* DEGREE SIGN */
    { 0x00B1, 0xB1 }, /* PLUS-MINUS SIGN */
    { 0x00B4, 0xAB }, /* ACUTE ACCENT */
    { 0x00B5, 0xB5 }, /* MICRO SIGN */
    { 0x00B6, 0xA6 }, /* PILCROW SIGN */
    { 0x00B7, 0xE1 }, /* MIDDLE DOT */
    { 0x00B8, 0xFC }, /* CEDILLA */
    { 0x00BA, 0xBC }, /* MASCULINE ORDINAL INDICATOR */
    { 0x00BB, 0xC8 }, /* RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK */
    { 0x00BF, 0xC0 }, /* INVERTED QUESTION MARK */
    { 0x00C0, 0xCB }, /* LATIN CAPITAL LETTER A WITH GRAVE */
    { 0x00C1, 0xE7 }, /* LATIN CAPITAL LETTER A WITH ACUTE */
    { 0x00C2, 0xE5 }, /* LATIN CAPITAL LETTER A WITH CIRCUMFLEX */
    { 0x00C3, 0xCC }, /* LATIN CAPITAL LETTER A WITH TILDE */
    { 0x00C4, 0x80 }, /* LATIN CAPITAL LETTER A WITH DIAERESIS */
    { 0x00C5, 0x81 }, /* LATIN CAPITAL LETTER A WITH RING ABOVE */
    { 0x00C6, 0xAE }, /* LATIN CAPITAL LETTER AE */
    { 0x00C7, 0x82 }, /* LATIN CAPITAL LETTER C WITH CEDILLA */
    { 0x00C8, 0xE9 }, /* LATIN CAPITAL LETTER E WITH GRAVE */
    { 0x00C9, 0x83 }, /* LATIN CAPITAL LETTER E WITH ACUTE */
    { 0x00CA, 0xE6 }, /* LATIN CAPITAL LETTER E WITH CIRCUMFLEX */
    { 0x00CB, 0xE8 }, /* LATIN CAPITAL LETTER E WITH DIAERESIS */
    { 0x00CC, 0xED }, /* LATIN CAPITAL LETTER I WITH GRAVE */
    { 0x00CD, 0xEA }, /* LATIN CAPITAL LETTER I WITH ACUTE */
    { 0x00CE, 0xEB }, /* LATIN CAPITAL LETTER I WITH CIRCUMFLEX */
    { 0x00CF, 0xEC }, /* LATIN CAPITAL LETTER I WITH DIAERESIS */
    { 0x00D1, 0x84 }, /* LATIN CAPITAL LETTER N WITH TILDE */
    { 0x00D2, 0xF1 }, /* LATIN CAPITAL LETTER O WITH GRAVE */
    { 0x00D3, 0xEE }, /* LATIN CAPITAL LETTER O WITH ACUTE */
    { 0x00D4, 0xEF }, /* LATIN CAPITAL LETTER O WITH CIRCUMFLEX */
    { 0x00D5, 0xCD }, /* LATIN CAPITAL LETTER O WITH TILDE */
    { 0x00D6, 0x85 }, /* LATIN CAPITAL LETTER O WITH DIAERESIS */
    { 0x00D8, 0xAF }, /* LATIN CAPITAL LETTER O WITH STROKE */
    { 0x00D9, 0xF4 }, /* LATIN CAPITAL LETTER U WITH GRAVE */
    { 0x00DA, 0xF2 }, /* LATIN CAPITAL LETTER U WITH ACUTE */
    { 0x00DB, 0xF3 }, /* LATIN CAPITAL LETTER U WITH CIRCUMFLEX */
    { 0x00DC, 0x86 }, /* LATIN CAPITAL LETTER U WITH DIAERESIS */
    { 0x00DF, 0xA7 }, /* LATIN SMALL LETTER SHARP S */
    { 0x00E0, 0x88 }, /* LATIN SMALL LETTER A WITH GRAVE */
    { 0x00E1, 0x87 }, /* LATIN SMALL LETTER A WITH ACUTE */
    { 0x00E2, 0x89 }, /* LATIN SMALL LETTER A WITH CIRCUMFLEX */
    { 0x00E3, 0x8B }, /* LATIN SMALL LETTER A WITH TILDE */
    { 0x00E4, 0x8A }, /* LATIN SMALL LETTER A WITH DIAERESIS */
    { 0x00E5, 0x8C }, /* LATIN SMALL LETTER A WITH RING ABOVE */
    { 0x00E6, 0xBE }, /* LATIN SMALL LETTER AE */
    { 0x00E7, 0x8D }, /* LATIN SMALL LETTER C WITH CEDILLA */
    { 0x00E8, 0x8F }, /* LATIN SMALL LETTER E WITH GRAVE */
    { 0x00E9, 0x8E }, /* LATIN SMALL LETTER E WITH ACUTE */
    { 0x00EA, 0x90 }, /* LATIN SMALL LETTER E WITH CIRCUMFLEX */
    { 0x00EB, 0x91 }, /* LATIN SMALL LETTER E WITH DIAERESIS */
    { 0x00EC, 0x93 }, /* LATIN SMALL LETTER I WITH GRAVE */
    { 0x00ED, 0x92 }, /* LATIN SMALL LETTER I WITH ACUTE */
    { 0x00EE, 0x94 }, /* LATIN SMALL LETTER I WITH CIRCUMFLEX */
    { 0x00EF, 0x95 }, /* LATIN SMALL LETTER I WITH DIAERESIS */
    { 0x00F1, 0x96 }, /* LATIN SMALL LETTER N WITH TILDE */
    { 0x00F2, 0x98 }, /* LATIN SMALL LETTER O WITH GRAVE */
    { 0x00F3, 0x97 }, /* LATIN SMALL LETTER O WITH ACUTE */
    { 0x00F4, 0x99 }, /* LATIN SMALL LETTER O WITH CIRCUMFLEX */
    { 0x00F5, 0x9B }, /* LATIN SMALL LETTER O WITH TILDE */
    { 0x00F6, 0x9A }, /* LATIN SMALL LETTER O WITH DIAERESIS */
    { 0x00F7, 0xD6 }, /* DIVISION SIGN */
    { 0x00F8, 0xBF }, /* LATIN SMALL LETTER O WITH STROKE */
    { 0x00F9, 0x9D }, /* LATIN SMALL LETTER U WITH GRAVE */
    { 0x00FA, 0x9C }, /* LATIN SMALL LETTER U WITH ACUTE */
    { 0x00FB, 0x9E }, /* LATIN SMALL LETTER U WITH CIRCUMFLEX */
    { 0x00FC, 0x9F }, /* LATIN SMALL LETTER U WITH DIAERESIS */
    { 0x00FF, 0xD8 }, /* LATIN SMALL LETTER Y WITH DIAERESIS */
    { 0x0131, 0xF5 }, /* LATIN SMALL LETTER DOTLESS I */
    { 0x0152, 0xCE }, /* LATIN CAPITAL LIGATURE OE */
    { 0x0153, 0xCF }, /* LATIN SMALL LIGATURE OE */
    { 0x0178, 0xD9 }, /* LATIN CAPITAL LETTER Y WITH DIAERESIS */
    { 0x0192, 0xC4 }, /* LATIN SMALL LETTER F WITH HOOK */
    { 0x02C6, 0xF6 }, /* MODIFIER LETTER CIRCUMFLEX ACCENT */
    { 0x02C7, 0xFF }, /* CARON */
    { 0x02D8, 0xF9 }, /* BREVE */
    { 0x02D9, 0xFA }, /* DOT ABOVE */
    { 0x02DA, 0xFB }, /* RING ABOVE */
    { 0x02DB, 0xFE }, /* OGONEK */
    { 0x02DC, 0xF7 }, /* SMALL TILDE */
    { 0x02DD, 0xFD }, /* DOUBLE ACUTE ACCENT */
    { 0x03A9, 0xBD }, /* GREEK CAPITAL LETTER OMEGA */
    { 0x03C0, 0xB9 }, /* GREEK SMALL LETTER PI */
    { 0x2013, 0xD0 }, /* EN DASH */
    { 0x2014, 0xD1 }, /* EM DASH */
    { 0x2018, 0xD4 }, /* LEFT SINGLE QUOTATION MARK */
    { 0x2019, 0xD5 }, /* RIGHT SINGLE QUOTATION MARK */
    { 0x201A, 0xE2 }, /* SINGLE LOW-9 QUOTATION MARK */
    { 0x201C, 0xD2 }, /* LEFT DOUBLE QUOTATION MARK */
    { 0x201D, 0xD3 }, /* RIGHT DOUBLE QUOTATION MARK */
    { 0x201E, 0xE3 }, /* DOUBLE LOW-9 QUOTATION MARK */
    { 0x2020, 0xA0 }, /* DAGGER */
    { 0x2021, 0xE0 }, /* DOUBLE DAGGER */
    { 0x2022, 0xA5 }, /* BULLET */
    { 0x2026, 0xC9 }, /* HORIZONTAL ELLIPSIS */
    { 0x2030, 0xE4 }, /* PER MILLE SIGN */
    { 0x2039, 0xDC }, /* SINGLE LEFT-POINTING ANGLE QUOTATION MARK */
    { 0x203A, 0xDD }, /* SINGLE RIGHT-POINTING ANGLE QUOTATION MARK */
    { 0x2044, 0xDA }, /* FRACTION SLASH */
    { 0x20AC, 0xDB }, /* EURO SIGN */
    { 0x2122, 0xAA }, /* TRADE MARK SIGN */
    { 0x2202, 0xB6 }, /* PARTIAL DIFFERENTIAL */
    { 0x2206, 0xC6 }, /* INCREMENT */
    { 0x220F, 0xB8 }, /* N-ARY PRODUCT */
    { 0x2211, 0xB7 }, /* N-ARY SUMMATION */
    { 0x221A, 0xC3 }, /* SQUARE ROOT */
    { 0x221E, 0xB0 }, /* INFINITY */
    { 0x222B, 0xBA }, /* INTEGRAL */
    { 0x2248, 0xC5 }, /* ALMOST EQUAL TO */
    { 0x2260, 0xAD }, /* NOT EQUAL TO */
    { 0x2264, 0xB2 }, /* LESS-THAN OR EQUAL TO */
    { 0x2265, 0xB3 }, /* GREATER-THAN OR EQUAL TO */
    { 0x25CA, 0xD7 }, /* LOZENGE */
    { 0xF8FF, 0xF0 }, /* Apple logo */
    { 0xFB01, 0xDE }, /* LATIN SMALL LIGATURE FI */
    { 0xFB02, 0xDF }, /* LATIN SMALL LIGATURE FL */
};

static const FontMap AppleRoman = {
    AppleRoman_Map,
    sizeof (AppleRoman_Map) / sizeof (AppleRoman_Map[0])
};

static const FontGlyph AdobeSymbol_Map[] = {
    { 0x0020, 0x20 }, /* SPACE	# space */
    { 0x0021, 0x21 }, /* EXCLAMATION MARK	# exclam */
    { 0x0023, 0x23 }, /* NUMBER SIGN	# numbersign */
    { 0x0025, 0x25 }, /* PERCENT SIGN	# percent */
    { 0x0026, 0x26 }, /* AMPERSAND	# ampersand */
    { 0x0028, 0x28 }, /* LEFT PARENTHESIS	# parenleft */
    { 0x0029, 0x29 }, /* RIGHT PARENTHESIS	# parenright */
    { 0x002B, 0x2B }, /* PLUS SIGN	# plus */
    { 0x002C, 0x2C }, /* COMMA	# comma */
    { 0x002E, 0x2E }, /* FULL STOP	# period */
    { 0x002F, 0x2F }, /* SOLIDUS	# slash */
    { 0x0030, 0x30 }, /* DIGIT ZERO	# zero */
    { 0x0031, 0x31 }, /* DIGIT ONE	# one */
    { 0x0032, 0x32 }, /* DIGIT TWO	# two */
    { 0x0033, 0x33 }, /* DIGIT THREE	# three */
    { 0x0034, 0x34 }, /* DIGIT FOUR	# four */
    { 0x0035, 0x35 }, /* DIGIT FIVE	# five */
    { 0x0036, 0x36 }, /* DIGIT SIX	# six */
    { 0x0037, 0x37 }, /* DIGIT SEVEN	# seven */
    { 0x0038, 0x38 }, /* DIGIT EIGHT	# eight */
    { 0x0039, 0x39 }, /* DIGIT NINE	# nine */
    { 0x003A, 0x3A }, /* COLON	# colon */
    { 0x003B, 0x3B }, /* SEMICOLON	# semicolon */
    { 0x003C, 0x3C }, /* LESS-THAN SIGN	# less */
    { 0x003D, 0x3D }, /* EQUALS SIGN	# equal */
    { 0x003E, 0x3E }, /* GREATER-THAN SIGN	# greater */
    { 0x003F, 0x3F }, /* QUESTION MARK	# question */
    { 0x005B, 0x5B }, /* LEFT SQUARE BRACKET	# bracketleft */
    { 0x005D, 0x5D }, /* RIGHT SQUARE BRACKET	# bracketright */
    { 0x005F, 0x5F }, /* LOW LINE	# underscore */
    { 0x007B, 0x7B }, /* LEFT CURLY BRACKET	# braceleft */
    { 0x007C, 0x7C }, /* VERTICAL LINE	# bar */
    { 0x007D, 0x7D }, /* RIGHT CURLY BRACKET	# braceright */
    { 0x00A0, 0x20 }, /* NO-BREAK SPACE	# space */
    { 0x00AC, 0xD8 }, /* NOT SIGN	# logicalnot */
    { 0x00B0, 0xB0 }, /* DEGREE SIGN	# degree */
    { 0x00B1, 0xB1 }, /* PLUS-MINUS SIGN	# plusminus */
    { 0x00B5, 0x6D }, /* MICRO SIGN	# mu */
    { 0x00D7, 0xB4 }, /* MULTIPLICATION SIGN	# multiply */
    { 0x00F7, 0xB8 }, /* DIVISION SIGN	# divide */
    { 0x0192, 0xA6 }, /* LATIN SMALL LETTER F WITH HOOK	# florin */
    { 0x0391, 0x41 }, /* GREEK CAPITAL LETTER ALPHA	# Alpha */
    { 0x0392, 0x42 }, /* GREEK CAPITAL LETTER BETA	# Beta */
    { 0x0393, 0x47 }, /* GREEK CAPITAL LETTER GAMMA	# Gamma */
    { 0x0394, 0x44 }, /* GREEK CAPITAL LETTER DELTA	# Delta */
    { 0x0395, 0x45 }, /* GREEK CAPITAL LETTER EPSILON	# Epsilon */
    { 0x0396, 0x5A }, /* GREEK CAPITAL LETTER ZETA	# Zeta */
    { 0x0397, 0x48 }, /* GREEK CAPITAL LETTER ETA	# Eta */
    { 0x0398, 0x51 }, /* GREEK CAPITAL LETTER THETA	# Theta */
    { 0x0399, 0x49 }, /* GREEK CAPITAL LETTER IOTA	# Iota */
    { 0x039A, 0x4B }, /* GREEK CAPITAL LETTER KAPPA	# Kappa */
    { 0x039B, 0x4C }, /* GREEK CAPITAL LETTER LAMDA	# Lambda */
    { 0x039C, 0x4D }, /* GREEK CAPITAL LETTER MU	# Mu */
    { 0x039D, 0x4E }, /* GREEK CAPITAL LETTER NU	# Nu */
    { 0x039E, 0x58 }, /* GREEK CAPITAL LETTER XI	# Xi */
    { 0x039F, 0x4F }, /* GREEK CAPITAL LETTER OMICRON	# Omicron */
    { 0x03A0, 0x50 }, /* GREEK CAPITAL LETTER PI	# Pi */
    { 0x03A1, 0x52 }, /* GREEK CAPITAL LETTER RHO	# Rho */
    { 0x03A3, 0x53 }, /* GREEK CAPITAL LETTER SIGMA	# Sigma */
    { 0x03A4, 0x54 }, /* GREEK CAPITAL LETTER TAU	# Tau */
    { 0x03A5, 0x55 }, /* GREEK CAPITAL LETTER UPSILON	# Upsilon */
    { 0x03A6, 0x46 }, /* GREEK CAPITAL LETTER PHI	# Phi */
    { 0x03A7, 0x43 }, /* GREEK CAPITAL LETTER CHI	# Chi */
    { 0x03A8, 0x59 }, /* GREEK CAPITAL LETTER PSI	# Psi */
    { 0x03A9, 0x57 }, /* GREEK CAPITAL LETTER OMEGA	# Omega */
    { 0x03B1, 0x61 }, /* GREEK SMALL LETTER ALPHA	# alpha */
    { 0x03B2, 0x62 }, /* GREEK SMALL LETTER BETA	# beta */
    { 0x03B3, 0x67 }, /* GREEK SMALL LETTER GAMMA	# gamma */
    { 0x03B4, 0x64 }, /* GREEK SMALL LETTER DELTA	# delta */
    { 0x03B5, 0x65 }, /* GREEK SMALL LETTER EPSILON	# epsilon */
    { 0x03B6, 0x7A }, /* GREEK SMALL LETTER ZETA	# zeta */
    { 0x03B7, 0x68 }, /* GREEK SMALL LETTER ETA	# eta */
    { 0x03B8, 0x71 }, /* GREEK SMALL LETTER THETA	# theta */
    { 0x03B9, 0x69 }, /* GREEK SMALL LETTER IOTA	# iota */
    { 0x03BA, 0x6B }, /* GREEK SMALL LETTER KAPPA	# kappa */
    { 0x03BB, 0x6C }, /* GREEK SMALL LETTER LAMDA	# lambda */
    { 0x03BC, 0x6D }, /* GREEK SMALL LETTER MU	# mu */
    { 0x03BD, 0x6E }, /* GREEK SMALL LETTER NU	# nu */
    { 0x03BE, 0x78 }, /* GREEK SMALL LETTER XI	# xi */
    { 0x03BF, 0x6F }, /* GREEK SMALL LETTER OMICRON	# omicron */
    { 0x03C0, 0x70 }, /* GREEK SMALL LETTER PI	# pi */
    { 0x03C1, 0x72 }, /* GREEK SMALL LETTER RHO	# rho */
    { 0x03C2, 0x56 }, /* GREEK SMALL LETTER FINAL SIGMA	# sigma1 */
    { 0x03C3, 0x73 }, /* GREEK SMALL LETTER SIGMA	# sigma */
    { 0x03C4, 0x74 }, /* GREEK SMALL LETTER TAU	# tau */
    { 0x03C5, 0x75 }, /* GREEK SMALL LETTER UPSILON	# upsilon */
    { 0x03C6, 0x66 }, /* GREEK SMALL LETTER PHI	# phi */
    { 0x03C7, 0x63 }, /* GREEK SMALL LETTER CHI	# chi */
    { 0x03C8, 0x79 }, /* GREEK SMALL LETTER PSI	# psi */
    { 0x03C9, 0x77 }, /* GREEK SMALL LETTER OMEGA	# omega */
    { 0x03D1, 0x4A }, /* GREEK THETA SYMBOL	# theta1 */
    { 0x03D2, 0xA1 }, /* GREEK UPSILON WITH HOOK SYMBOL	# Upsilon1 */
    { 0x03D5, 0x6A }, /* GREEK PHI SYMBOL	# phi1 */
    { 0x03D6, 0x76 }, /* GREEK PI SYMBOL	# omega1 */
    { 0x2022, 0xB7 }, /* BULLET	# bullet */
    { 0x2026, 0xBC }, /* HORIZONTAL ELLIPSIS	# ellipsis */
    { 0x2032, 0xA2 }, /* PRIME	# minute */
    { 0x2033, 0xB2 }, /* DOUBLE PRIME	# second */
    { 0x2044, 0xA4 }, /* FRACTION SLASH	# fraction */
    { 0x20AC, 0xA0 }, /* EURO SIGN	# Euro */
    { 0x2111, 0xC1 }, /* BLACK-LETTER CAPITAL I	# Ifraktur */
    { 0x2118, 0xC3 }, /* SCRIPT CAPITAL P	# weierstrass */
    { 0x211C, 0xC2 }, /* BLACK-LETTER CAPITAL R	# Rfraktur */
    { 0x2126, 0x57 }, /* OHM SIGN	# Omega */
    { 0x2135, 0xC0 }, /* ALEF SYMBOL	# aleph */
    { 0x2190, 0xAC }, /* LEFTWARDS ARROW	# arrowleft */
    { 0x2191, 0xAD }, /* UPWARDS ARROW	# arrowup */
    { 0x2192, 0xAE }, /* RIGHTWARDS ARROW	# arrowright */
    { 0x2193, 0xAF }, /* DOWNWARDS ARROW	# arrowdown */
    { 0x2194, 0xAB }, /* LEFT RIGHT ARROW	# arrowboth */
    { 0x21B5, 0xBF }, /* DOWNWARDS ARROW WITH CORNER LEFTWARDS	# carriagereturn */
    { 0x21D0, 0xDC }, /* LEFTWARDS DOUBLE ARROW	# arrowdblleft */
    { 0x21D1, 0xDD }, /* UPWARDS DOUBLE ARROW	# arrowdblup */
    { 0x21D2, 0xDE }, /* RIGHTWARDS DOUBLE ARROW	# arrowdblright */
    { 0x21D3, 0xDF }, /* DOWNWARDS DOUBLE ARROW	# arrowdbldown */
    { 0x21D4, 0xDB }, /* LEFT RIGHT DOUBLE ARROW	# arrowdblboth */
    { 0x2200, 0x22 }, /* FOR ALL	# universal */
    { 0x2202, 0xB6 }, /* PARTIAL DIFFERENTIAL	# partialdiff */
    { 0x2203, 0x24 }, /* THERE EXISTS	# existential */
    { 0x2205, 0xC6 }, /* EMPTY SET	# emptyset */
    { 0x2206, 0x44 }, /* INCREMENT	# Delta */
    { 0x2207, 0xD1 }, /* NABLA	# gradient */
    { 0x2208, 0xCE }, /* ELEMENT OF	# element */
    { 0x2209, 0xCF }, /* NOT AN ELEMENT OF	# notelement */
    { 0x220B, 0x27 }, /* CONTAINS AS MEMBER	# suchthat */
    { 0x220F, 0xD5 }, /* N-ARY PRODUCT	# product */
    { 0x2211, 0xE5 }, /* N-ARY SUMMATION	# summation */
    { 0x2212, 0x2D }, /* MINUS SIGN	# minus */
    { 0x2215, 0xA4 }, /* DIVISION SLASH	# fraction */
    { 0x2217, 0x2A }, /* ASTERISK OPERATOR	# asteriskmath */
    { 0x221A, 0xD6 }, /* SQUARE ROOT	# radical */
    { 0x221D, 0xB5 }, /* PROPORTIONAL TO	# proportional */
    { 0x221E, 0xA5 }, /* INFINITY	# infinity */
    { 0x2220, 0xD0 }, /* ANGLE	# angle */
    { 0x2227, 0xD9 }, /* LOGICAL AND	# logicaland */
    { 0x2228, 0xDA }, /* LOGICAL OR	# logicalor */
    { 0x2229, 0xC7 }, /* INTERSECTION	# intersection */
    { 0x222A, 0xC8 }, /* UNION	# union */
    { 0x222B, 0xF2 }, /* INTEGRAL	# integral */
    { 0x2234, 0x5C }, /* THEREFORE	# therefore */
    { 0x223C, 0x7E }, /* TILDE OPERATOR	# similar */
    { 0x2245, 0x40 }, /* APPROXIMATELY EQUAL TO	# congruent */
    { 0x2248, 0xBB }, /* ALMOST EQUAL TO	# approxequal */
    { 0x2260, 0xB9 }, /* NOT EQUAL TO	# notequal */
    { 0x2261, 0xBA }, /* IDENTICAL TO	# equivalence */
    { 0x2264, 0xA3 }, /* LESS-THAN OR EQUAL TO	# lessequal */
    { 0x2265, 0xB3 }, /* GREATER-THAN OR EQUAL TO	# greaterequal */
    { 0x2282, 0xCC }, /* SUBSET OF	# propersubset */
    { 0x2283, 0xC9 }, /* SUPERSET OF	# propersuperset */
    { 0x2284, 0xCB }, /* NOT A SUBSET OF	# notsubset */
    { 0x2286, 0xCD }, /* SUBSET OF OR EQUAL TO	# reflexsubset */
    { 0x2287, 0xCA }, /* SUPERSET OF OR EQUAL TO	# reflexsuperset */
    { 0x2295, 0xC5 }, /* CIRCLED PLUS	# circleplus */
    { 0x2297, 0xC4 }, /* CIRCLED TIMES	# circlemultiply */
    { 0x22A5, 0x5E }, /* UP TACK	# perpendicular */
    { 0x22C5, 0xD7 }, /* DOT OPERATOR	# dotmath */
    { 0x2320, 0xF3 }, /* TOP HALF INTEGRAL	# integraltp */
    { 0x2321, 0xF5 }, /* BOTTOM HALF INTEGRAL	# integralbt */
    { 0x2329, 0xE1 }, /* LEFT-POINTING ANGLE BRACKET	# angleleft */
    { 0x232A, 0xF1 }, /* RIGHT-POINTING ANGLE BRACKET	# angleright */
    { 0x25CA, 0xE0 }, /* LOZENGE	# lozenge */
    { 0x2660, 0xAA }, /* BLACK SPADE SUIT	# spade */
    { 0x2663, 0xA7 }, /* BLACK CLUB SUIT	# club */
    { 0x2665, 0xA9 }, /* BLACK HEART SUIT	# heart */
    { 0x2666, 0xA8 }, /* BLACK DIAMOND SUIT	# diamond */
    { 0xF6D9, 0xD3 }, /* COPYRIGHT SIGN SERIF	# copyrightserif (CUS) */
    { 0xF6DA, 0xD2 }, /* REGISTERED SIGN SERIF	# registerserif (CUS) */
    { 0xF6DB, 0xD4 }, /* TRADE MARK SIGN SERIF	# trademarkserif (CUS) */
    { 0xF8E5, 0x60 }, /* RADICAL EXTENDER	# radicalex (CUS) */
    { 0xF8E6, 0xBD }, /* VERTICAL ARROW EXTENDER	# arrowvertex (CUS) */
    { 0xF8E7, 0xBE }, /* HORIZONTAL ARROW EXTENDER	# arrowhorizex (CUS) */
    { 0xF8E8, 0xE2 }, /* REGISTERED SIGN SANS SERIF	# registersans (CUS) */
    { 0xF8E9, 0xE3 }, /* COPYRIGHT SIGN SANS SERIF	# copyrightsans (CUS) */
    { 0xF8EA, 0xE4 }, /* TRADE MARK SIGN SANS SERIF	# trademarksans (CUS) */
    { 0xF8EB, 0xE6 }, /* LEFT PAREN TOP	# parenlefttp (CUS) */
    { 0xF8EC, 0xE7 }, /* LEFT PAREN EXTENDER	# parenleftex (CUS) */
    { 0xF8ED, 0xE8 }, /* LEFT PAREN BOTTOM	# parenleftbt (CUS) */
    { 0xF8EE, 0xE9 }, /* LEFT SQUARE BRACKET TOP	# bracketlefttp (CUS) */
    { 0xF8EF, 0xEA }, /* LEFT SQUARE BRACKET EXTENDER	# bracketleftex (CUS) */
    { 0xF8F0, 0xEB }, /* LEFT SQUARE BRACKET BOTTOM	# bracketleftbt (CUS) */
    { 0xF8F1, 0xEC }, /* LEFT CURLY BRACKET TOP	# bracelefttp (CUS) */
    { 0xF8F2, 0xED }, /* LEFT CURLY BRACKET MID	# braceleftmid (CUS) */
    { 0xF8F3, 0xEE }, /* LEFT CURLY BRACKET BOTTOM	# braceleftbt (CUS) */
    { 0xF8F4, 0xEF }, /* CURLY BRACKET EXTENDER	# braceex (CUS) */
    { 0xF8F5, 0xF4 }, /* INTEGRAL EXTENDER	# integralex (CUS) */
    { 0xF8F6, 0xF6 }, /* RIGHT PAREN TOP	# parenrighttp (CUS) */
    { 0xF8F7, 0xF7 }, /* RIGHT PAREN EXTENDER	# parenrightex (CUS) */
    { 0xF8F8, 0xF8 }, /* RIGHT PAREN BOTTOM	# parenrightbt (CUS) */
    { 0xF8F9, 0xF9 }, /* RIGHT SQUARE BRACKET TOP	# bracketrighttp (CUS) */
    { 0xF8FA, 0xFA }, /* RIGHT SQUARE BRACKET EXTENDER	# bracketrightex (CUS) */
    { 0xF8FB, 0xFB }, /* RIGHT SQUARE BRACKET BOTTOM	# bracketrightbt (CUS) */
    { 0xF8FC, 0xFC }, /* RIGHT CURLY BRACKET TOP	# bracerighttp (CUS) */
    { 0xF8FD, 0xFD }, /* RIGHT CURLY BRACKET MID	# bracerightmid (CUS) */
    { 0xF8FE, 0xFE }, /* RIGHT CURLY BRACKET BOTTOM	# bracerightbt (CUS) */
};

static const FontMap AdobeSymbol = {
    AdobeSymbol_Map,
    sizeof (AdobeSymbol_Map) / sizeof (AdobeSymbol_Map[0]),
};


static const FontGlyph VT100_Map[] = {				// DEC VT100 semi-graphics
    { 0x00a3, 0x7D },		// pound sign
    { 0x00b0, 0x66 },		// degree sign
    { 0x00b1, 0x67 },		// plus-minus sign
    { 0x00b7, 0x7E },		// middle dot
    { 0x03c0, 0x7B },		// greek small letter pi
    { 0x2260, 0x7C },		// not equal to
    { 0x2264, 0x79 },		// less-than or equal to
    { 0x2265, 0x7A },		// greater-than or equal to
    { 0x23BA, 0x6F },		// box drawings scan 1
    { 0x23BB, 0x70 },		// box drawings scan 3
    { 0x23BC, 0x72 },		// box drawings scan 7
    { 0x23BD, 0x73 },		// box drawings scan 9
    { 0x2409, 0x62 },		// symbol for horizontal tabulation
    { 0x240a, 0x65 },		// symbol for line feed
    { 0x240b, 0x69 },		// symbol for vertical tabulation
    { 0x240c, 0x63 },		// symbol for form feed
    { 0x240d, 0x64 },		// symbol for carriage return
    { 0x2424, 0x68 },		// plus-minus sign
    { 0x2500, 0x71 },		// box drawings light horizontal
    { 0x2502, 0x78 },		// box drawings light vertical
    { 0x250C, 0x6C },		// box drawings light down and right
    { 0x2510, 0x6B },		// box drawings light down and left
    { 0x2514, 0x6D },		// box drawings light up and right
    { 0x2518, 0x6A },		// box drawings light up and left
    { 0x251C, 0x74 },		// box drawings light vertical and right
    { 0x2524, 0x75 },		// box drawings light vertical and left
    { 0x252C, 0x77 },		// box drawings light down and horizontal
    { 0x2534, 0x76 },		// box drawings light up and horizontal
    { 0x253C, 0x6E },		// box drawings light vertical and horizontal
    { 0x2592, 0x61 },		// medium shade
    { 0x25ae, 0x5F },		// black vertical rectangle
    { 0x25c6, 0x60 }		// black diamond
};

static const FontGlyph VT100_8859_1_Map[] = {
    { 0x2500, 0x12 },
    { 0x2502, 0x19 },
    { 0x250C, 0x0D },
    { 0x2510, 0x0C },
    { 0x2514, 0x0E },
    { 0x2518, 0x0B },
    { 0x251C, 0x15 },
    { 0x2524, 0x16 },
    { 0x252C, 0x18 },
    { 0x2534, 0x17 },
    { 0x253C, 0x0F },
    { 0x25C6, 0x01 }		// black diamond
};

static const FontMap VT100Graphics = {
    VT100_8859_1_Map,
    sizeof (VT100_8859_1_Map) / sizeof (VT100_8859_1_Map[0]),
};

#include "gb2312.h"


static const FontDecode __FontDecoders[] = {		// ordered by best encoding
    { FT_ENCODING_NONE,			0,				0             },
    { FT_ENCODING_UNICODE,		0,				(1 << 21) - 1 },
    { FT_ENCODING_APPLE_ROMAN,	&AppleRoman,	(1 << 16) - 1 },
    { FT_ENCODING_UNICODE,		&VT100Graphics,	(1 << 16) - 1 },
    { FT_ENCODING_MS_SYMBOL,	&AdobeSymbol,	(1 << 16) - 1 },
    { FT_ENCODING_GB2312,		&CJK_GB2312,	(1 << 21) - 1 },
};

#define NUM_DECODE  (sizeof (__FontDecoders) / sizeof (__FontDecoders[0]))

#endif /* _Font_H_Encoding */
