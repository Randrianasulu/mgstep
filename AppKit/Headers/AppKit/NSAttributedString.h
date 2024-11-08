/* 
   NSAttributedString.h

   AppKit extensions to NSAttributedString

   Copyright (C) 2001 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@pcmagic.net>
   Date:    Oct 2001
   
   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/ 

#ifndef _mGSTEP_H_NSAttributedStringAdditions
#define _mGSTEP_H_NSAttributedStringAdditions

#include <Foundation/NSAttributedString.h>
#include <AppKit/NSFontManager.h>

@class NSFileWrapper;


extern NSString *NSLinkAttributeName;
extern NSString *NSCursorAttributeName;

/* ****************************************************************************

	RTF/D init methods return a dictionary by ref describing doc
	attributes if dict param is not NULL.

	RTF/D create methods can take an optional dict describing doc wide 
	attributes to write out.  Current attributes are @"PaperSize", 
	@"LeftMargin", @"RightMargin", @"TopMargin", @"BottomMargin", and 
	@"HyphenationFactor".  
	First of these is an NSSize (NSValue) others are floats (NSNumber). 

** ***************************************************************************/

@interface NSAttributedString (NSAttributedStringAdditions)

- (id) initWithRTF:(NSData *)data documentAttributes:(NSDictionary **)dict;
- (id) initWithRTFD:(NSData *)data documentAttributes:(NSDictionary **)dict;
- (id) initWithPath:(NSString *)path documentAttributes:(NSDictionary **)dict;
- (id) initWithRTFDFileWrapper:(NSFileWrapper *)wrapper
			documentAttributes:(NSDictionary **)dict;

- (NSData *) RTFFromRange:(NSRange)range documentAttributes:(NSDictionary *)d;
- (NSData *) RTFDFromRange:(NSRange)range documentAttributes:(NSDictionary *)d;
- (NSFileWrapper *) RTFDFileWrapperFromRange:(NSRange)range 
						  documentAttributes:(NSDictionary *)dict;

- (NSDictionary *) fontAttributesInRange:(NSRange)range;	// filter attribs
- (NSDictionary *) rulerAttributesInRange:(NSRange)range;

- (BOOL) containsAttachments;
					// return first char to go on the next line or NSNotFound
					// if the speciefied range does not contain a line break
- (unsigned) lineBreakBeforeIndex:(unsigned)location
					  withinRange:(NSRange)aRange;
- (NSRange) doubleClickAtIndex:(unsigned)location;
- (unsigned) nextWordFromIndex:(unsigned)location forward:(BOOL)isForward;

@end


@interface NSMutableAttributedString (NSMutableAttributedStringAdditions)

- (void) superscriptRange:(NSRange)range;
- (void) subscriptRange:(NSRange)range;
- (void) unscriptRange:(NSRange)range; 			// Undo previous superscripting
- (void) applyFontTraits:(NSFontTraitMask)traitMask range:(NSRange)range;
- (void) setAlignment:(NSTextAlignment)alignment range:(NSRange)range;

					// Methods (not automagically called) to "fix" attributes
					// after changes are made.  Range is specified in terms of 
					// the final string.
- (void) fixAttributesInRange:(NSRange)range;		// master fix method
- (void) fixFontAttributeInRange:(NSRange)range;
- (void) fixParagraphStyleAttributeInRange:(NSRange)range;
- (void) fixAttachmentAttributeInRange:(NSRange)range;

@end

#endif /* _mGSTEP_H_NSAttributedStringAdditions */
