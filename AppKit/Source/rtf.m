/*
   rtf.m

   Parse RTF data

   Copyright (C) 2001 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Oct 2001

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSException.h>

#include <ctype.h>

// RTF parser return codes

#define ecOK 				0
#define ecStackUnderflow    1       // Unmatched '}'
#define ecStackOverflow     2       // Too many '{'
#define ecUnmatchedBrace    3       // RTF ended during an open group.
#define ecInvalidHex        4       // invalid hex character found in data
#define ecBadTable          5       // RTF table (sym or prop) invalid
#define ecAssertion         6       // Assertion failure
#define ecEndOfFile         7       // End of file reached while reading RTF

typedef struct char_prop
{
    char fBold;
    char fUnderline;
    char fItalic;
} CHP;                  // Character Properties

typedef enum { justL, justR, justC, justF } JUST;

typedef struct para_prop
{
    int xaLeft;                 // left indent in twips
    int xaRight;                // right indent in twips
    int xaFirst;                // first line indent in twips
    JUST just;                  // justification
} PAP;                  // Paragraph Properties

typedef enum { sbkNon, sbkCol, sbkEvn, sbkOdd, sbkPg } SBK;
typedef enum { pgDec, pgURom, pgLRom, pgULtr, pgLLtr } PGN;

typedef struct sect_prop
{
    int cCols;                  // number of columns
    SBK sbk;                    // section break type
    int xaPgn;                  // x position of page number in twips
    int yaPgn;                  // y position of page number in twips
    PGN pgnFormat;              // how the page number is formatted
} SEP;                  // Section Properties

typedef struct doc_prop
{
    int xaPage;                 // page width in twips
    int yaPage;                 // page height in twips
    int xaLeft;                 // left margin in twips
    int yaTop;                  // top margin in twips
    int xaRight;                // right margin in twips
    int yaBottom;               // bottom margin in twips
    int pgnStart;               // starting page number in twips
    char fFacingp;              // facing pages enabled?
    char fLandscape;            // landscape or portrait??
} DOP;                  // Document Properties

typedef enum { rdsNorm, rdsSkip } RDS;              // RTF Destination State
typedef enum { risNorm, risBin, risHex } RIS;       // RTF Internal State

								// Property types
typedef enum {
	ipropBold,	   ipropItalic,    ipropUnderline, ipropLeftInd,
	ipropRightInd, ipropFirstInd,  ipropCols,      ipropPgnX,
	ipropPgnY,	   ipropXaPage,    ipropYaPage,    ipropXaLeft,
	ipropXaRight,  ipropYaTop,     ipropYaBottom,  ipropPgnStart,
	ipropSbk,      ipropPgnFormat, ipropFacingp,   ipropLandscape,
	ipropJust,     ipropPard,      ipropPlain,     ipropSectd, ipropMax
} IPROP;

typedef enum { actnSpec, actnByte, actnWord } ACTN;
typedef enum { propChp, propPap, propSep, propDop } PROPTYPE;

typedef struct propmod
{
    ACTN actn;              // size of value
    PROPTYPE prop;          // structure containing value
    int offset;				// offset of value from base of structure
} PROP;

typedef enum { ipfnBin, ipfnHex, ipfnSkipDest } IPFN;
typedef enum { idestPict, idestSkip } IDEST;
typedef enum { kwdChar, kwdDest, kwdProp, kwdSpec, kwdColor } KWD;

typedef struct symbol
{
    char *szKeyword;        	// RTF keyword
    int dflt;					// default value to use
    BOOL fPassDflt;         	// true to use default value from this table
    KWD kwd;					// base action to take
    int idx;					// index into property table if kwd == kwdProp
                            	//  | into destination table if kwd == kwdDest
} SYM;							//   | character to print if kwd == kwdChar

typedef struct pStateSave       // RTF property save structure
{
    struct pStateSave *pNext;   // next saved
    CHP chp;
    PAP pap;
    SEP sep;
    DOP dop;
    RDS rds;
    RIS ris;

} pState;

typedef struct _ParseRTF		// RTF parser internal state
{
	BOOL fSkipDestIfUnk;
    pState _cur;

    char *buf;
	pState *_pState;
    int _pStateStackDepth;

	long lParam;
	long cbBin;

} ParseRTF;


// RTF parser tables

// Property descriptions
PROP rgprop [ipropMax] = {
    actnByte,   propChp,    offsetof(CHP, fBold),       // ipropBold
    actnByte,   propChp,    offsetof(CHP, fItalic),     // ipropItalic
    actnByte,   propChp,    offsetof(CHP, fUnderline),  // ipropUnderline
    actnWord,   propPap,    offsetof(PAP, xaLeft),      // ipropLeftInd
    actnWord,   propPap,    offsetof(PAP, xaRight),     // ipropRightInd
    actnWord,   propPap,    offsetof(PAP, xaFirst),     // ipropFirstInd
    actnWord,   propSep,    offsetof(SEP, cCols),       // ipropCols
    actnWord,   propSep,    offsetof(SEP, xaPgn),       // ipropPgnX
    actnWord,   propSep,    offsetof(SEP, yaPgn),       // ipropPgnY
    actnWord,   propDop,    offsetof(DOP, xaPage),      // ipropXaPage
    actnWord,   propDop,    offsetof(DOP, yaPage),      // ipropYaPage
    actnWord,   propDop,    offsetof(DOP, xaLeft),      // ipropXaLeft
    actnWord,   propDop,    offsetof(DOP, xaRight),     // ipropXaRight
    actnWord,   propDop,    offsetof(DOP, yaTop),       // ipropYaTop
    actnWord,   propDop,    offsetof(DOP, yaBottom),    // ipropYaBottom
    actnWord,   propDop,    offsetof(DOP, pgnStart),    // ipropPgnStart
    actnByte,   propSep,    offsetof(SEP, sbk),         // ipropSbk
    actnByte,   propSep,    offsetof(SEP, pgnFormat),   // ipropPgnFormat
    actnByte,   propDop,    offsetof(DOP, fFacingp),    // ipropFacingp
    actnByte,   propDop,    offsetof(DOP, fLandscape),  // ipropLandscape
    actnByte,   propPap,    offsetof(PAP, just),        // ipropJust
    actnSpec,   propPap,    0,                          // ipropPard
    actnSpec,   propChp,    0,                          // ipropPlain
    actnSpec,   propSep,    0,                          // ipropSectd
};

// Keyword descriptions
SYM rgsymRtf[] = {
//  keyword   default   fPassDeflt  kwd         idx
    "b",        1,      NO,			kwdProp,    ipropBold,
//    "cb",       0,      NO,			kwdColor,    0,
//    "cf",       0,      NO,			kwdColor,    1,
    "u",        1,      NO,			kwdProp,    ipropUnderline,
    "i",        1,      NO,			kwdProp,    ipropItalic,
    "li",       0,      NO,			kwdProp,    ipropLeftInd,
    "ri",       0,      NO,			kwdProp,    ipropRightInd,
    "fi",       0,      NO,			kwdProp,    ipropFirstInd,
    "cols",     1,      NO,			kwdProp,    ipropCols,
    "sbknone",  sbkNon, YES,		kwdProp,    ipropSbk,
    "sbkcol",   sbkCol, YES,		kwdProp,    ipropSbk,
    "sbkeven",  sbkEvn, YES,		kwdProp,    ipropSbk,
    "sbkodd",   sbkOdd, YES,		kwdProp,    ipropSbk,
    "sbkpage",  sbkPg,  YES,		kwdProp,    ipropSbk,
    "pgnx",     0,      NO,			kwdProp,    ipropPgnX,
    "pgny",     0,      NO,			kwdProp,    ipropPgnY,
    "pgndec",   pgDec,  YES,		kwdProp,    ipropPgnFormat,
    "pgnucrm",  pgURom, YES,		kwdProp,    ipropPgnFormat,
    "pgnlcrm",  pgLRom, YES,		kwdProp,    ipropPgnFormat,
    "pgnucltr", pgULtr, YES,		kwdProp,    ipropPgnFormat,
    "pgnlcltr", pgLLtr, YES,		kwdProp,    ipropPgnFormat,
    "qc",       justC,  YES,		kwdProp,    ipropJust,
    "ql",       justL,  YES,		kwdProp,    ipropJust,
    "qr",       justR,  YES,		kwdProp,    ipropJust,
    "qj",       justF,  YES,		kwdProp,    ipropJust,
    "paperw",   12240,  NO,			kwdProp,    ipropXaPage,
    "paperh",   15480,  NO,			kwdProp,    ipropYaPage,
    "margl",    1800,   NO,			kwdProp,    ipropXaLeft,
    "margr",    1800,   NO,			kwdProp,    ipropXaRight,
    "margt",    1440,   NO,			kwdProp,    ipropYaTop,
    "margb",    1440,   NO,			kwdProp,    ipropYaBottom,
    "pgnstart", 1,      YES,		kwdProp,    ipropPgnStart,
    "facingp",  1,      YES,		kwdProp,    ipropFacingp,
    "landscape",1,      YES,		kwdProp,    ipropLandscape,
    "par",      0,      NO,			kwdChar,    0x0a,
    "\0x0a",    0,      NO,			kwdChar,    '\n',
    "\n",    	0,      NO,			kwdChar,    '\n',
    "\0x0d",    0,      NO,			kwdChar,    '\r',
    "tab",      0,      NO,			kwdChar,    '\t',
    "ldblquote",0,      NO,			kwdChar,    '"',
    "rdblquote",0,      NO,			kwdChar,    '"',
    "bin",      0,      NO,			kwdSpec,    ipfnBin,
    "*",        0,      NO,			kwdSpec,    ipfnSkipDest,
    "'",        0,      NO,			kwdSpec,    ipfnHex,
    "author",   0,      NO,			kwdDest,    idestSkip,
    "buptim",   0,      NO,			kwdDest,    idestSkip,
    "colortbl", 0,      NO,			kwdDest,    idestSkip,  // FIX ME parse rgb
    "comment",  0,      NO,			kwdDest,    idestSkip,
    "creatim",  0,      NO,			kwdDest,    idestSkip,
    "doccomm",  0,      NO,			kwdDest,    idestSkip,
    "fonttbl",  0,      NO,			kwdDest,    idestSkip,
    "footer",   0,      NO,			kwdDest,    idestSkip,
    "footerf",  0,      NO,			kwdDest,    idestSkip,
    "footerl",  0,      NO,			kwdDest,    idestSkip,
    "footerr",  0,      NO,			kwdDest,    idestSkip,
    "footnote", 0,      NO,			kwdDest,    idestSkip,
    "ftncn",    0,      NO,			kwdDest,    idestSkip,
    "ftnsep",   0,      NO,			kwdDest,    idestSkip,
    "ftnsepc",  0,      NO,			kwdDest,    idestSkip,
    "header",   0,      NO,			kwdDest,    idestSkip,
    "headerf",  0,      NO,			kwdDest,    idestSkip,
    "headerl",  0,      NO,			kwdDest,    idestSkip,
    "headerr",  0,      NO,			kwdDest,    idestSkip,
    "info",     0,      NO,			kwdDest,    idestSkip,
    "keywords", 0,      NO,			kwdDest,    idestSkip,
    "operator", 0,      NO,			kwdDest,    idestSkip,
    "pict",     0,      NO,			kwdDest,    idestSkip,
    "printim",  0,      NO,			kwdDest,    idestSkip,
    "private1", 0,      NO,			kwdDest,    idestSkip,
    "revtim",   0,      NO,			kwdDest,    idestSkip,
    "rxe",      0,      NO,			kwdDest,    idestSkip,
    "stylesheet",0,     NO,			kwdDest,    idestSkip,
    "subject",  0,      NO,			kwdDest,    idestSkip,
    "tc",       0,      NO,			kwdDest,    idestSkip,
    "title",    0,      NO,			kwdDest,    idestSkip,
    "txe",      0,      NO,			kwdDest,    idestSkip,
    "xe",       0,      NO,			kwdDest,    idestSkip,
    "{",        0,      NO,			kwdChar,    '{',
    "}",        0,      NO,			kwdChar,    '}',
    "\\",       0,      NO,			kwdChar,    '\\'
};

int isymMax = sizeof(rgsymRtf) / sizeof(SYM);


static void
_RouteParsedRTFChar(int ch, ParseRTF *state)
{
    if (state->_cur.ris == risBin && --state->cbBin <= 0)
        state->_cur.ris = risNorm;		// Route the character to the
										// appropriate destination stream
    switch (state->_cur.rds)
		{
		case rdsNorm:	// Output char. Properties are valid at this point.
			{
			int len = strlen(state->buf);
			state->buf[len++] = ch;
			state->buf[len] = '\0';
			}
//    		putchar(ch);

		case rdsSkip:					// Toss this character.
		default:						// handle other destinations
			break;
		}
}

/* ****************************************************************************

	_SetRTFProperty

	Set the property identified by _iprop_ to the value _val_.

** ***************************************************************************/

static int
_SetRTFProperty(IPROP iprop, int val, ParseRTF *state)
{
	char *pb;

    if (state->_cur.rds == rdsSkip)     // If we're skipping text,
        return ecOK;                    // don't do anything.

    switch (rgprop[iprop].prop)
		{
		case propDop:	pb = (char *)&state->_cur.dop;	break;
		case propSep:	pb = (char *)&state->_cur.sep;	break;
		case propPap:	pb = (char *)&state->_cur.pap;	break;
		case propChp:	pb = (char *)&state->_cur.chp;	break;
		default:
			if (rgprop[iprop].actn != actnSpec)
				return ecBadTable;
			break;
		}

    switch (rgprop[iprop].actn)
		{
		case actnByte:
			pb[rgprop[iprop].offset] = (unsigned char) val;
			break;
		case actnWord:
			(*(int *) (pb+rgprop[iprop].offset)) = val;
			break;
		case actnSpec:					// Set a property that requires
			switch (iprop)				// code to evaluate
				{
				case ipropPard:		memset(&state->_cur.pap, 0, sizeof(state->_cur.pap));	break;
				case ipropPlain:	memset(&state->_cur.chp, 0, sizeof(state->_cur.chp));	break;
				case ipropSectd:	memset(&state->_cur.sep, 0, sizeof(state->_cur.sep));	break;
				default:			
					return ecBadTable;
				}
			break;
		default:
			return ecBadTable;
		}

    return ecOK;
}

/* ****************************************************************************

	_ParseSpecialRTFKeyword

	Evaluate an RTF control that needs special processing.

** ***************************************************************************/

static int
_ParseSpecialRTFKeyword(IPFN ipfn, ParseRTF *state)
{
    if (state->_cur.rds == rdsSkip && ipfn != ipfnBin)
        return ecOK;                        // if we're skipping and it's not
											// the \bin keyword ignore it.
    switch (ipfn)
		{
		case ipfnBin:
			state->_cur.ris = risBin;
			state->cbBin = state->lParam;
			break;
		case ipfnSkipDest:
			state->fSkipDestIfUnk = YES;
			break;
		case ipfnHex:
			state->_cur.ris = risHex;
			break;
		default:
			return ecBadTable;
		}

    return ecOK;
}

/* ****************************************************************************

	_TranslateRTFKeyword	(Step 3)

	Search rgsymRtf for szKeyword and evaluate it appropriately.

	szKeyword:	The RTF control to evaluate.
	param:		The parameter of the RTF control.
	fParam:		YES if control had a parameter(param is valid), NO otherwise.

** ***************************************************************************/

static int
_TranslateRTFKeyword(char *szKeyword, int param, BOOL fParam, ParseRTF *state)
{
	int isym;						// search for szKeyword in rgsymRtf

    for (isym = 0; isym < isymMax; isym++)
        if (strcmp(szKeyword, rgsymRtf[isym].szKeyword) == 0)
            break;

    if (isym == isymMax)            // control word not found
    	{
        if (state->fSkipDestIfUnk)         // if this is a new destination
            state->_cur.rds = rdsSkip;     // skip the destination
										   // else just discard it
        state->fSkipDestIfUnk = NO;
        return ecOK;
    	}
									// found it!  use kwd and idx to determine 
    state->fSkipDestIfUnk = NO;		// what to do with it.
    switch (rgsymRtf[isym].kwd)
		{
		case kwdProp:
			if (rgsymRtf[isym].fPassDflt || !fParam)
				param = rgsymRtf[isym].dflt;
			return _SetRTFProperty(rgsymRtf[isym].idx, param, state);

		case kwdChar:
			_RouteParsedRTFChar(rgsymRtf[isym].idx, state);
			return ecOK;

		case kwdDest:
			if (state->_cur.rds != rdsSkip)		// if not skipping text
				switch (rgsymRtf[isym].idx)		// Switch output destination
					{
					default:
						state->_cur.rds = rdsSkip;	// when in doubt, skip it
						break;
					}
			
			return ecOK;

		case kwdSpec:
			return _ParseSpecialRTFKeyword(rgsymRtf[isym].idx, state);

		default:
			break;
		}

    return ecBadTable;
}

static void								// Save RTF info into a linked
_PushRTFState(ParseRTF *state)			// list stack of pState structures
{
	pState *psaveNew = malloc(sizeof(pState));

    if (!psaveNew)
		[NSException raise: NSMallocException format:@"malloc failed"];

    psaveNew->pNext = state->_pState;
    psaveNew->chp = state->_cur.chp;
    psaveNew->pap = state->_cur.pap;
    psaveNew->sep = state->_cur.sep;
    psaveNew->dop = state->_cur.dop;
    psaveNew->rds = state->_cur.rds;
    psaveNew->ris = state->_cur.ris;
    state->_cur.ris = risNorm;
    state->_pState = psaveNew;
    state->_pStateStackDepth++;
}

static void								// Pop RTF doc info from top of pState
_PopRTFState(ParseRTF *state)			// list stack if ending a destination
{
	pState *psaveOld;

    if (!state->_pState)
		[NSException raise: NSGenericException format:@"RTF stack underflow"];

//  if (rds != _pState->rds)		// destination specified by rds is
										// about to close. cleanup if needed
    state->_cur.chp = state->_pState->chp;
    state->_cur.pap = state->_pState->pap;
    state->_cur.sep = state->_pState->sep;
    state->_cur.dop = state->_pState->dop;
    state->_cur.rds = state->_pState->rds;
    state->_cur.ris = state->_pState->ris;

    psaveOld = state->_pState;
    state->_pState = state->_pState->pNext;
    state->_pStateStackDepth--;
    free(psaveOld);
}

/* ****************************************************************************

	_ParseRTFKeyword	(Step 2)

	get a control word (and its associated value) and
	call _TranslateRTFKeyword to dispatch the control.

** ***************************************************************************/

static const char *
_ParseRTFKeyword (const char *f, ParseRTF *state)
{
	int ch, rc, param = 0;
	char fParam = NO, fNeg = NO;
	char *pch;
	char szKeyword[30] = "";
	char szParameter[20] = "";

    if (!*f || (ch = *f++) == '\0')
		[NSException raise: NSGenericException format:@"RTF unexpected EOF"];

    if (!isalpha(ch))           				// control symbol; no delimiter
		{
        szKeyword[0] = (char) ch;
        szKeyword[1] = '\0';
		}
	else
		{
		for (pch = szKeyword; *f && isalpha(ch); (ch = *f++))
			*pch++ = (char) ch;
		*pch = '\0';
		if (ch == '-')
			{
			fNeg  = YES;
			if (!*f || (ch = *f++) == '\0')
				[NSException raise: NSGenericException
							 format:@"RTF unexpected EOF"];
			}
		if (isdigit(ch))
			{								// a digit after the control means 
			fParam = YES;					// we have a parameter
			for (pch = szParameter; *f && isdigit(ch); (ch = *f++))
				*pch++ = (char) ch;
			*pch = '\0';
			param = atoi(szParameter);
			if (fNeg)
				param = -param;
			state->lParam = atol(szParameter);
			if (fNeg)
				param = -param;
			}
		if (ch != ' ')
			f--;
//			*f--;
		}

	if ((rc = _TranslateRTFKeyword(szKeyword, param, fParam, state)) != ecOK)
		[NSException raise: NSGenericException 
					 format: @"_ParseRTFKeyword() failed: %d\n", rc];
    return f;
}

/* ****************************************************************************

	_ParseRTF	(Step 1)

	Isolate RTF keywords and send them to _ParseRTFKeyword;
	Push and pop state at the start and end of RTF groups;
	Send text to _RouteParsedRTFChar for further processing.

** ***************************************************************************/

int
_ParseRTF (const char *f, char *outBuf)
{
	ParseRTF state = {0};
	int cNibble = 2, b = 0;

	state.buf = outBuf;

	while(*f)
    	{
		int ch = *f++;

        if (state._pStateStackDepth < 0)
            return ecStackUnderflow;

        if (state._cur.ris == risBin)				// if we're parsing binary
			_RouteParsedRTFChar(ch, &state);		// data, handle it directly
        else
			{
            switch (ch)
				{
				case '{':	_PushRTFState(&state);				break;
				case '}':	_PopRTFState(&state);				break;
				case '\\':	f = _ParseRTFKeyword(f, &state);	break;

				default:
					if (state._cur.ris == risNorm)
						_RouteParsedRTFChar(ch, &state);
					else
						{               		// parsing hex data
						if (state._cur.ris != risHex)
							return ecAssertion;
						b = b << 4;
						if (isdigit(ch))
							b += (char) ch - '0';
						else
							{
							if (islower(ch))
								{
								if (ch < 'a' || ch > 'f')
									return ecInvalidHex;
								b += (char) ch - 'a';
								}
							else
								{
								if (ch < 'A' || ch > 'F')
									return ecInvalidHex;
								b += (char) ch - 'A';
							}	}

						cNibble--;
						if (!cNibble)
							{
							_RouteParsedRTFChar(ch, &state);
							cNibble = 2;
							b = 0;
							state._cur.ris = risNorm;
						}	}

				case '\n':
				case '\r':          			// cr and lf are noise chars
					break;
    	}	}	}

    if (state._pStateStackDepth < 0)
        return ecStackUnderflow;
    if (state._pStateStackDepth > 0)
        return ecUnmatchedBrace;

    return ecOK;
}
