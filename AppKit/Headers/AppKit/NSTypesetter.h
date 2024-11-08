/*
   NSTypesetter.h

   Text typesetter class

   Copyright (C) 2017 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    June 2017

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSTypesetter
#define _mGSTEP_H_NSTypesetter

#include <Foundation/NSObject.h>

@class NSArray;
@class NSLayoutManager;
@class NSTextContainer;
@class NSTextStorage;
@class NSParagraphStyle;
@class NSAttributedString;


typedef enum {
	NSTypesetterZeroAdvancementAction = (1 << 0),  // glyphs flitered out from layout (notShownAttribute == YES)
	NSTypesetterWhitespaceAction      = (1 << 1),  // glyphs with width determined by -boundingBoxForControlGlyphAtIndex:forTextContainer:proposedLineFragment:glyphPosition:characterIndex: if the method is implemented; otherwise, same as NSTypesetterZeroAdvancementAction
	NSTypesetterHorizontalTabAction   = (1 << 2),  // tab character
	NSTypesetterLineBreakAction       = (1 << 3),  // line break
	NSTypesetterParagraphBreakAction  = (1 << 4),  // paragraph break (firstLineIndent will be used for following glyph)
	NSTypesetterContainerBreakAction  = (1 << 5)   // container break

} NSTypesetterControlCharacterAction;


@interface NSTypesetter : NSObject
{
	NSLayoutManager *_layoutManager;	// only valid within layoutGlyphsInLayoutManager:startingAtGlyphIndex:maxNumberOfLineFragments:nextGlyphIndex:
	NSTextStorage *_textStorage;		// nonretained
	NSTextContainer *_curContainer;
	NSParagraphStyle *_curParaStyle;
	NSInteger _typesetterBehavior;		// NSTypesetterBehavior
	NSRange curParaRange;
	NSRange _separatorCharacterRange;
	NSRange _paragraphGlyphRange;
	NSRange _separatorGlyphRange;
	CGFloat _lineFragmentPadding;
	NSUInteger _maxNumberOfLineFragments;
	BOOL _bidiProcessingEnabled;
	BOOL _usesFontLeading;
}

	// FIX ME most of the interface is missing

+ (id) sharedSystemTypesetter;

- (NSUInteger) layoutParagraphAtPoint:(NSPoint **)lineFragmentOrigin;

- (NSRange) layoutCharactersInRange:(NSRange)characterRange
				   forLayoutManager:(NSLayoutManager *)layoutManager
				   maximumNumberOfLineFragments:(NSUInteger)maxLineFragments;

- (NSArray *) textContainers;
- (NSTextContainer *) currentTextContainer;
- (NSLayoutManager *) layoutManager;

- (CGFloat) baselineOffsetInLayoutManager:(NSLayoutManager *)manager
							   glyphIndex:(NSUInteger)index;
//- (NSTypesetterBehavior) typesetterBehavior;
- (NSInteger) typesetterBehavior;

- (void) setAttributedString:(NSAttributedString *)as;

@end

#endif /* _mGSTEP_H_NSTypesetter */
