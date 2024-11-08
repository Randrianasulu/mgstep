/*
   NSText.h

   The text object

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
   Date:	1996
   Author:  Felipe A. Rodriguez <far@ix.netcom.com>
   Date:	July 1998
   Author:  Daniel Bðhringer <boehring@biomed.ruhr-uni-bochum.de>
   Date:	August 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSText
#define _mGSTEP_H_NSText

#include <Foundation/NSRange.h>

#include <AppKit/NSView.h>
#include <AppKit/NSSpellProtocol.h>
#include <AppKit/NSStringDrawing.h>

@class NSString;
@class NSData;
@class NSNotification;
@class NSMutableDictionary;
@class NSColor;
@class NSFont;


typedef enum _NSTextAlignment {
	NSLeftTextAlignment		 = 0,
	NSRightTextAlignment	 = 1,
	NSCenterTextAlignment	 = 2,
	NSJustifiedTextAlignment = 3,
	NSNaturalTextAlignment	 = 4
} NSTextAlignment;

enum {
	NSIllegalTextMovement = 0,
	NSReturnTextMovement  = 0x10,
	NSTabTextMovement	  = 0x11,
	NSBacktabTextMovement = 0x12,
	NSLeftTextMovement	  = 0x13,
	NSRightTextMovement	  = 0x14,
	NSUpTextMovement	  = 0x15,
	NSDownTextMovement	  = 0x16,
	NSCancelTextMovement  = 0x17
};	 	

enum {
	NSParagraphSeparatorCharacter = 0x2029,
	NSLineSeparatorCharacter      = 0x2028,
	NSTabCharacter                = 0x0009,
	NSBackTabCharacter            = 0x0019,
	NSFormFeedCharacter           = 0x000c,
	NSNewlineCharacter            = 0x000a,
	NSCarriageReturnCharacter     = 0x000d,
	NSEnterCharacter              = 0x0003,
	NSBackspaceCharacter          = 0x0008,
	NSDeleteCharacter             = 0x007f
};	 	

extern NSString *NSTextMovement;


@interface NSText : NSView  <NSChangeSpelling,NSIgnoreMisspelledWords,NSCoding>
{											
	id _delegate;
	NSColor *_backgroundColor;
	NSColor *_insertionPointColor;
	NSColor *_textColor;
	NSFont *_font;
	NSRange _selectedRange;
	
	NSMutableString *plainContent;								// content
	NSMutableAttributedString *rtfContent;
	NSMutableDictionary *_typingAttributes;

	NSCharacterSet *selectionWordGranularitySet;
	NSCharacterSet *selectionParagraphGranularitySet;
	id _lineLayoutInformation;
	float _cursorX;							// column-stable cursor up/down
	int spellCheckerDocumentTag;

	NSSize _inset;
	NSSize _minSize;
	NSSize _maxSize;

	struct __TextFlags {
		unsigned int isRichText:1;
		unsigned int importsGraphics:1;
		unsigned int usesFontPanel:1;
		unsigned int horzResizable:1;
		unsigned int vertResizable:1;
		unsigned int editable:1;
		unsigned int selectable:1;
		unsigned int fieldEditor:1;
		unsigned int drawsBackground:1;
		unsigned int disableDisplay:1;
		unsigned int caretVisible:1;
		unsigned int rulerVisible:1;
		unsigned int headerVisible:1;
		unsigned int secure:1;
		unsigned int smartInsertDeleteEnabled:1;
		NSTextAlignment alignment:3;
		unsigned int isFirstResponder:1;
		unsigned int reserved:13;
	} _tx;
}

//- (void) replaceCharactersInRange:(NSRange)range withString:(NSString *)str;
//- (void) replaceCharactersInRange:(NSRange)range withRTF:(NSData *)rtfData;
//- (void) replaceCharactersInRange:(NSRange)range withRTFD:(NSData *)rtfdData;
- (void) replaceRange:(NSRange)range withString:(NSString*)aString;
- (void) replaceRange:(NSRange)range withRTF:(NSData *)rtfData;
- (void) replaceRange:(NSRange)range withRTFD:(NSData *)rtfdData;

- (NSData*) RTFDFromRange:(NSRange)range;
- (NSData*) RTFFromRange:(NSRange)range;
- (void) setString:(NSString *)string;
- (NSString*) string;

- (NSTextAlignment) alignment;							// Global attributes
- (BOOL) drawsBackground;
- (BOOL) importsGraphics;
- (BOOL) isEditable;
- (BOOL) isRichText;
- (BOOL) isSelectable;
- (void) setAlignment:(NSTextAlignment)mode;
- (void) setDrawsBackground:(BOOL)flag;
- (void) setEditable:(BOOL)flag;
- (void) setImportsGraphics:(BOOL)flag;
- (void) setRichText:(BOOL)flag;
- (void) setSelectable:(BOOL)flag;

- (NSColor*) backgroundColor;							// Font and Color
- (void) setBackgroundColor:(NSColor*)color;
- (void) setTextColor:(NSColor*)color;
- (void) setTextColor:(NSColor*)color range:(NSRange)range;
- (void) setColor:(NSColor*)color ofRange:(NSRange)range;
- (NSColor*) textColor;
- (NSFont*) font;
- (void) setFont:(NSFont*)obj;
- (void) setFont:(NSFont*)font ofRange:(NSRange)range;
- (void) changeFont:(id)sender;
- (void) setUsesFontPanel:(BOOL)flag;
- (BOOL) usesFontPanel;

- (NSRange) selectedRange;								// Selection
- (void) setSelectedRange:(NSRange)range;

- (BOOL) isHorizontallyResizable;						// Frame Rectangle
- (BOOL) isVerticallyResizable;
- (NSSize) maxSize;
- (NSSize) minSize;
- (void) setHorizontallyResizable:(BOOL)flag;
- (void) setMaxSize:(NSSize)newMaxSize;
- (void) setMinSize:(NSSize)newMinSize;
- (void) setVerticallyResizable:(BOOL)flag;
- (void) sizeToFit;

- (void) alignCenter:(id)sender;						// Editing Commands
- (void) alignLeft:(id)sender;
- (void) alignRight:(id)sender;
- (void) copy:(id)sender;
- (void) copyFont:(id)sender;
- (void) copyRuler:(id)sender;
- (void) cut:(id)sender;
- (void) delete:(id)sender;
- (void) paste:(id)sender;
- (void) pasteFont:(id)sender;
- (void) pasteRuler:(id)sender;
- (void) selectAll:(id)sender;
- (void) subscript:(id)sender;
- (void) superscript:(id)sender;
- (void) underline:(id)sender;
- (void) unscript:(id)sender;

- (BOOL) isRulerVisible;								// Ruler
- (void) toggleRuler:(id)sender;

- (void) checkSpelling:(id)sender;						// Spelling
- (void) showGuessPanel:(id)sender;

- (void) scrollRangeToVisible:(NSRange)range;			// Scrolling

- (BOOL) readRTFDFromFile:(NSString *)path;				// Read / Write RTFD
- (BOOL) writeRTFDToFile:(NSString *)path atomically:(BOOL)flag;

- (BOOL) isFieldEditor;
- (void) setFieldEditor:(BOOL)flag;						// Field Editor

- (id) delegate;
- (void) setDelegate:anObject;							// Delegate

@end

											// NSTextView methods are here only
@interface NSText (NSTextView)				// informally (extension)

- (int) spellCheckerDocumentTag;
											// user keyboard text entry point,
- (void) insertText:(id)insertString;		// an NSString or NSAttributedString
											// (if isRichText)
- (NSMutableDictionary *) typingAttributes;
- (void) setTypingAttributes:(NSDictionary *)attrs;

- (BOOL) shouldDrawInsertionPoint;

- (NSArray*) acceptableDragTypes;
- (void) updateDragTypeRegistration;

@end

											// NSLayoutManager methods are here
@interface NSText (NSLayoutManager)			// only informally (extension)

- (NSUInteger) characterIndexForPoint:(NSPoint)point;
- (NSRect) rectForCharacterIndex:(NSUInteger)index;
- (NSRect) boundingRectForLineRange:(NSRange)lineRange;
- (NSRange) characterRangeForBoundingRect:(NSRect)bounds;
- (NSRange) lineRangeForRect:(NSRect) aRect;

@end


@interface NSText (PrivateExtensions_DoNotUse)

- (NSUInteger) textLength;
				// return value is guaranteed to be a NSAttributedString
				// even if data contains only NSString
+ (NSAttributedString*) attributedStringForData:(NSData*)aData;
+ (NSData*) dataForAttributedString:(NSAttributedString*)aString;

// Get and Set Contents (low level: no selection handling, relayout or display)
//
- (void) replaceRange:(NSRange)r withAttributedString:(NSAttributedString*)as;

	// private (never invoke, never subclass)
- (void) _drawRectNoSelection:(NSRect)rect;
- (void) _drawCaretInRect:(NSRect)rect turnedOn:(BOOL)flag;
- (unsigned) lineLayoutIndexForPoint:(NSPoint)point;

	// returns count of lines actually updated (e.g. drawing optimization)
- (int) _rebuildLineLayoutFromLine:(int) aLine;
	// override for special layout of plain text
- (int) _rebuildPlainLineLayoutFromLine:(int) aLine 
								  delta:(int) insertionDelta 
							 actualLine:(int) insertionLine;
	// ditto for rich text
- (int) _rebuildRTFLineLayoutFromLine:(int) aLine 
								delta:(int) insertionDelta 
						   actualLine:(int) insertionLine;
	// ret val is identical to the real line number (plus counted newline char)
- (int) lineLayoutIndexForCharacterIndex:(unsigned) anIndex;		
- (void) _displayLineRange:(NSRange) redrawLineRange;
	// low level, override but never invoke (use _displayLineRange:)
- (void) _drawRichLinesInLineRange:(NSRange) aRange;
	// low level, override but never invoke (use _displayLineRange:)
- (void) _drawPlainLinesInLineRange:(NSRange) aRange;

- (void) setSelectionWordGranularitySet:(NSCharacterSet*) aSet;
- (void) setSelectionParagraphGranularitySet:(NSCharacterSet*) aSet;

@end


@interface NSObject (NSTextDelegate)

- (BOOL) textShouldBeginEditing:(NSText*)textObject;		// YES means do it
- (BOOL) textShouldEndEditing:(NSText*)textObject;
- (void) textDidBeginEditing:(NSNotification*)notification;
- (void) textDidEndEditing:(NSNotification*)notification;
				// Any keyDown or paste which changes the contents causes this
- (void) textDidChange:(NSNotification*)notification;

@end

extern NSString *NSTextDidBeginEditingNotification;			// Notifications
extern NSString *NSTextDidEndEditingNotification;
extern NSString *NSTextDidChangeNotification;

#endif /* _mGSTEP_H_NSText */
