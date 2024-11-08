/*
   NSTypesetter.m

   Typesetter and string drawing categories

   Copyright (C) 1998-2017 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Aug 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>

#include <CoreGraphics/CoreGraphics.h>
#include <CoreGraphics/Private/_CGFont.h>

#include <AppKit/NSTypesetter.h>
#include <AppKit/NSText.h>
#include <AppKit/NSAttributedString.h>
#include <AppKit/NSStringDrawing.h>
#include <AppKit/NSColor.h>

										// by default tabs are measured as one
#define TABWIDTH 	4					// char, define default tab width of 4

#define CONTEXT		((CGContextRef)_CGContext())
#define ISFLIPPED	((CGContext *) _CGContext())->_gs->isFlipped
#define TAB_SIZE	((CGContext *) _CGContext())->_gs->tabSize
#define FONT		((CGContext *) _CGContext())->_gs->font
#define COLOR		((CGContext *) _CGContext())->_gs->stroke.color
#define ASCENDER	((CGContext *) _CGContext())->_gs->ascender
#define DESCENDER	((CGContext *) _CGContext())->_gs->descender


// class variables
static NSTypesetter *__sharedTypesetter = nil;

static BOOL __calcDrawInfo = NO;

static NSDictionary *__lastAttrs = nil;
static NSColor *__textColor;
static NSFont *__font;


/* ****************************************************************************

	_LineLayoutInfo		-- FIX ME s/b NSLayoutManager and NSTextContainer
 
** ***************************************************************************/

static void
_SetTextAttributes(NSDictionary *a)
{
	if (a != __lastAttrs)
		{
		__lastAttrs = a;
		DBLog (@"XRStringDrawing dictionary changed.");
		if (!(__textColor = [a objectForKey: NSForegroundColorAttributeName]))
			{	 												
			__textColor = [NSColor blackColor];				// default color
			NSLog (@"XRStringDrawing drawAtPoint: text color not specified.");
			}
															
		if (!(__font = [a objectForKey: NSFontAttributeName]))
			__font = [NSFont userFontOfSize:12];			// default font
		}

	if (__textColor != COLOR)
		[__textColor set];
	if (__font != FONT)
		[__font set];
}

typedef enum
{							// do not use 0 in order to secure calls to nil!
	LineLayoutTextType      = 1,
	LineLayoutParagraphType = 2

} _LineLayoutInfo_t;


@interface _LineLayoutInfo : NSObject
{	
	NSRange charRange;
	NSRect lineRect;
	unsigned type;
	NSString *string;
}

- (NSRange) charRange;
- (NSRect) lineRect;
- (unsigned) type;
- (NSString*) string;

@end


@implementation _LineLayoutInfo

+ (void) initialize
{
	if (!__sharedTypesetter)
		__sharedTypesetter = [NSTypesetter new];
}

+ (void) calcDrawInfo						{ __calcDrawInfo = YES; }

+ (_LineLayoutInfo *) lineLayoutWithRange:(NSRange) aRange
									 rect:(NSRect) aRect
									 type:(unsigned) aType
{	
	_LineLayoutInfo *ret = [[[_LineLayoutInfo alloc] init] autorelease];

//	NSLog(@" lineLayoutWithRange");
	ret->charRange = aRange;
	ret->lineRect = aRect;
	ret->type = aType;

	return ret;
}

- (void) drawPlainLine:(NSString*)aSring withAttributes:(NSDictionary*)attr
{
	if (type == LineLayoutParagraphType)
		return;												// e.g. for nl

//	[[aSring substringWithRange:charRange] drawAtPoint:lineRect.origin
//										   withAttributes:attr];

	string = aSring;
	_SetTextAttributes(attr);
	[__sharedTypesetter layoutCharactersInRange:charRange
						forLayoutManager:(NSLayoutManager*)self
						maximumNumberOfLineFragments:NSUIntegerMax];
}

- (void) drawRTFLine:(NSMutableAttributedString*)rtfContent
{
	if (type == LineLayoutParagraphType)
		return;												// e.g. for nl

	NSRange cr = {0, charRange.location};
	NSPoint origin = lineRect.origin;
	NSPoint point = lineRect.origin;
	NSString *s = [rtfContent string];

	for(; NSMaxRange(cr) < NSMaxRange(charRange);)	// draw all "runs"
		{	
		NSDictionary *attr = [rtfContent attributesAtIndex:NSMaxRange(cr)
										 longestEffectiveRange:&cr
										 inRange:charRange];
		NSString *substring = [s substringWithRange:cr];

	string = s;
///	string = substring;
	_SetTextAttributes(attr);
	lineRect.origin = point;
	[__sharedTypesetter layoutCharactersInRange:charRange
						forLayoutManager:(NSLayoutManager*)self
						maximumNumberOfLineFragments:NSUIntegerMax];

///		[substring drawAtPoint:point withAttributes: a];
		point.x += [substring sizeWithAttributes: attr].width;
		}

	lineRect.origin = origin;
}

- (NSString*) string								{ return string; }

- (unsigned) type							{ return type; }
- (NSRange) charRange 						{ return charRange; }
- (NSRect) lineRect 						{ return lineRect; }
- (void) setCharRange:(NSRange)aRange 		{ charRange = aRange; }
- (void) setLineRect:(NSRect)aRect			{ lineRect = aRect; }
- (void) setType:(unsigned)aType			{ type = aType; }

- (NSString*) description
{
	return [[NSDictionary dictionaryWithObjectsAndKeys: 
					NSStringFromRange(charRange), @"CharRange",
					NSStringFromRect(lineRect), @"LineRect", nil] description];
}

@end /* _LineLayoutInfo */

/* ****************************************************************************

	NSString  (NSStringDrawing)
 
** ***************************************************************************/

static NSDictionary *__lastAttr = nil;
static NSFont *__lastFont = nil;
static float __capHeight;
static float __tabSize;

@implementation NSString  (NSStringDrawing)

- (NSSize) sizeWithAttributes:(NSDictionary *)attrs
{
	const char *str = [self cString];
	float tabSumSize, widthSize, capHeight, tabSize;
	int i = 0, n = 0;
	int j = TABWIDTH - 1;
	NSFont *font;

	if ((attrs != __lastAttr))
		{
		if (!(__lastFont = [attrs objectForKey:NSFontAttributeName]))
			__lastFont = [NSFont userFontOfSize:12];
		__tabSize = [__lastFont widthOfString:@"\t"];
		__capHeight = [__lastFont capHeight];
		__lastAttr = attrs;
		}

	font = __lastFont;
	tabSize = __tabSize;
	capHeight = __capHeight;

	if (_count == 1 && (*str == '\t'))
		widthSize = (float)TABWIDTH * tabSize;
	else
		{
		while(*str != '\0')							// calc the additional size 
			{										// to be added for tabs.  
			if(*str == '\t')			
				{									// j is initialized to the 
				i += j;								// max number of spaces	
				j = TABWIDTH - 1;					// needed per tab.  it then
				}									// varies in order to align 
			else									// tabs to even multiples 
				{									// of TABWIDTH.
				j = j-- > 0 ? j : TABWIDTH - 1;
				if(*str == '\n')
					n++;
				}
			str++;
			};	

		tabSumSize = ((float)i * tabSize) - ((float)n * tabSize);
		widthSize = [font widthOfString:self] + tabSumSize;
		}						

//	fprintf(stderr," is = %f\n", widthSize);

	return (NSSize){widthSize, capHeight};
}

- (void) drawInRect:(NSRect)rect withAttributes:(NSDictionary*)attrs
{
	const char *s = [self cString];  // FIX ME draw glyphs not text str
	CGContextRef cx = CONTEXT;

	_SetTextAttributes(attrs);
	CGContextSaveGState(cx);
	CGContextClipToRect(cx, rect);
	CGContextShowTextAtPoint(cx, NSMinX(rect), NSMinY(rect), s, strlen(s));
	CGContextRestoreGState(cx);
}

- (void) drawAtPoint:(NSPoint)point withAttributes:(NSDictionary*)attrs
{
	const char *s = [self cString];  // FIX ME draw glyphs not text str
	CGContextRef cx = CONTEXT;

	_SetTextAttributes(attrs);
	if(ISFLIPPED)
		point.y += ASCENDER;
	CGContextSaveGState(cx);
	CGContextShowTextAtPoint(cx, point.x, point.y, s, strlen(s));
	CGContextRestoreGState(cx);
}

@end


@implementation NSAttributedString  (NSStringDrawing)

- (NSSize) size
{
	unsigned int length = [self length];
	NSRange effectiveRange = {0, 0};
	float sumOfCharacterRange = 0;
	float capHeight = 0.0;

	while (NSMaxRange(effectiveRange) < length) 
		{
		NSFont *font = (NSFont*)[self attribute:NSFontAttributeName
									  atIndex:NSMaxRange(effectiveRange) 
									  effectiveRange:&effectiveRange];
		id subString = [self attributedSubstringFromRange:effectiveRange];

		sumOfCharacterRange += [font widthOfString:subString];
		capHeight = MAX([font capHeight], capHeight);
		}
	
	return (NSSize){sumOfCharacterRange, capHeight};
}

@end

/* ****************************************************************************

	NSTypesetter

** ***************************************************************************/

@implementation NSTypesetter

+ (id) sharedSystemTypesetter
{
	return (__sharedTypesetter) ? __sharedTypesetter
								: (__sharedTypesetter = [NSTypesetter new]);
}

/* ****************************************************************************

	layoutParagraphAtPoint:(NSPoint **)lineFragmentOrigin

	Layout primitive method.  lineFragmentOrigin is a pointer to the upper left
	origin of the destination line fragment rect.  Its return value indicates
	the next origin.  Method returns the next glyph index.

** ***************************************************************************/

- (NSUInteger) layoutParagraphAtPoint:(NSPoint **)lineFragmentOrigin
{
	return 0;
}

/* ****************************************************************************

	Layout characters in characterRange for layoutManager. returns actual character range that the receiving NSTypesetter processed. The layout process can be interrupted when the number of line fragments exceeds maxNumLines, set to NSUIntegerMax for an infinite number of line fragments.

** ***************************************************************************/

- (NSRange) layoutCharactersInRange:(NSRange)characterRange
				   forLayoutManager:(NSLayoutManager *)layoutManager
				   maximumNumberOfLineFragments:(NSUInteger)maxLineFragments
{
//	NSPoint lineFragmentOrigin = [array[i] lineRect].origin;
//	NSPoint **lfs = &lineFragmentOrigin;

_LineLayoutInfo *ly = (_LineLayoutInfo *)layoutManager;

	NSPoint point = [ly lineRect].origin;
	NSString *line = [[ly string] substringWithRange:characterRange];
	const char *str = [line cString];
	const char *frag = str;


///	[self layoutParagraphAtPoint: lfs];

	if (__calcDrawInfo)		// calc Y margin as used by NSCell's drawInterior
		{
		NSRect frame = [((CGContext *) _CGContext())->_gs->focusView frame];
		float margin = 0;

		__calcDrawInfo = NO;
		if (NSHeight(frame) > (ASCENDER + DESCENDER) + 1)
			margin = floor((NSHeight(frame) - (ASCENDER + DESCENDER)) / 2);

		if (ISFLIPPED)
//			point.y = NSMaxY(frame) - DESCENDER - margin;
			point.y = NSHeight(frame) - DESCENDER - margin;
		else
			point.y = NSMinY(frame) + margin + DESCENDER;
		}
	else if(ISFLIPPED)					// not field editor role
		point.y += ASCENDER;

	while (*frag != '\0')
		{
		int strLength = frag - str;

		if (*frag == '\t')
			{
			float charToTabRatio = (float)strLength / (float)TABWIDTH;
			float adjTabSize;

			charToTabRatio = charToTabRatio - (floor(charToTabRatio));
			adjTabSize = (charToTabRatio == 0)
					   ? TAB_SIZE : TAB_SIZE - (TAB_SIZE * charToTabRatio);

			CGContextShowTextAtPoint(CONTEXT, point.x, point.y, str, strLength);
 			point.x += _CGTextWidth((CGFont *)FONT, str, strLength) + adjTabSize;
			str = frag+1;
			}
		else if ((*frag == '\r' || (*frag == '\n')) && (*str != '\0'))
			{
			CGContextShowTextAtPoint(CONTEXT, point.x, point.y, str, strLength);
 			point.x += _CGTextWidth((CGFont *)FONT, str, strLength);
			str = frag+1;
			}

		frag++;
		if ((*frag == '\0') && (*str != '\0'))
			CGContextShowTextAtPoint(CONTEXT, point.x, point.y, str, frag - str);
		}

	return characterRange;
}

- (NSArray *) textContainers							{ return nil; }
- (NSTextContainer *) currentTextContainer				{ return nil; }
- (NSLayoutManager *) layoutManager						{ return nil; }

- (void) setAttributedString:(NSAttributedString *)as
{
	_textStorage = (NSTextStorage *)as;
}

- (CGFloat) baselineOffsetInLayoutManager:(NSLayoutManager *)manager
							   glyphIndex:(NSUInteger)i	{ return 0.0; }
- (NSInteger) typesetterBehavior						{ return 0; }

@end
