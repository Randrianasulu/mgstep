/*
   NSTextView.h

   NSText subclass that displays the glyphs laid out in one NSTextContainer.

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Daniel Bðhringer <boehring@biomed.ruhr-uni-bochum.de>
   Date: August 1998
   mGSTEP: Felipe A. Rodriguez <far@illumenos.com>

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSTextView
#define _mGSTEP_H_NSTextView

#include <AppKit/NSText.h>
#include <AppKit/NSTextAttachment.h>

@class NSTextContainer;
@class NSTextStorage;
@class NSLayoutManager;
@class NSRulerView;
@class NSRulerMarker;


typedef enum _NSSelectionGranularity {	
	NSSelectByCharacter = 0,
    NSSelectByWord      = 1,
    NSSelectByParagraph = 2,
} NSSelectionGranularity;

typedef enum _NSSelectionAffinity {	
	NSSelectionAffinityUpstream   = 0,
    NSSelectionAffinityDownstream = 1,
} NSSelectionAffinity;



@interface NSTextView : NSText  // <NSTextInputClient>
{	
	NSTextStorage *_textStorage;
	NSTextContainer *_textContainer;
	NSLayoutManager *_layoutManager;
	NSSelectionAffinity _selectionAffinity;
	NSSelectionGranularity _selectionGranularity;
	NSSize _textContainerInset;
	NSPoint _textContainerOrigin;
	NSView *_headerView;
}

+ (void) registerForServices;			// sent each time a view is initialized

- (id) initWithFrame:(NSRect)frameRect				// Designated Initializer
	   textContainer:(NSTextContainer *)container;	// container may be nil

- (id) initWithFrame:(NSRect)frameRect;  // creates text network (textStorage, layoutManager, and a container).

- (NSTextContainer*) textContainer;
- (void) setTextContainer:(NSTextContainer*)container;
    // The set method should not be called directly, but you might want to override it.  Gets or sets the text container for this view.  Setting the text container marks the view as needing display.  The text container calls the set method from its setTextView: method.

- (void) replaceTextContainer:(NSTextContainer *)newContainer;
    // This method should be used instead of the primitive -setTextContainer: if you need to replace a view's text container with a new one leaving the rest of the web intact.  This method deals with all the work of making sure the view doesn't get deallocated and removing the old container from the layoutManager and replacing it with the new one.

- (void) setTextContainerInset:(NSSize)inset;
- (NSSize) textContainerInset;
    // The textContianerInset determines the padding that the view provides around the container.  The container's origin will be inset by this amount from the bounds point {0,0} and padding will be left to the right and below the container of the same amount.  This inset affects the view sizing in response to new layout and is used by the rectangular text containers when they track the view's frame dimensions.

- (NSPoint) textContainerOrigin;
- (void) invalidateTextContainerOrigin;
    // The container's origin in the view is determined from the current usage of the container, the container inset, and the view size.  textContainerOrigin returns this point.  invalidateTextContainerOrigin is sent automatically whenever something changes that causes the origin to possibly move.  You usually do not need to call invalidate yourself. 

- (NSLayoutManager *) layoutManager;
- (NSTextStorage *) textStorage;

//- (void) insertText:(id)insertString; // Entry point for text insertion from keys.

- (void) setConstrainedFrameSize:(NSSize)desiredSize;

- (void) setAlignment:(NSTextAlignment)alignment range:(NSRange)range;

- (void) turnOffKerning:(id)sender;					// Font menu commands
- (void) tightenKerning:(id)sender;
- (void) loosenKerning:(id)sender;
- (void) useStandardKerning:(id)sender;
- (void) turnOffLigatures:(id)sender;
- (void) useStandardLigatures:(id)sender;
- (void) useAllLigatures:(id)sender;
- (void) raiseBaseline:(id)sender;
- (void) lowerBaseline:(id)sender;
													// Ruler support
- (void) rulerView:(NSRulerView *)ruler didMoveMarker:(NSRulerMarker *)marker;
- (void) rulerView:(NSRulerView *)ruler didRemoveMarker:(NSRulerMarker *)mk;
- (void) rulerView:(NSRulerView *)ruler didAddMarker:(NSRulerMarker *)marker;
- (BOOL) rulerView:(NSRulerView *)ruler shouldMoveMarker:(NSRulerMarker *)mk;
- (BOOL) rulerView:(NSRulerView *)ruler shouldAddMarker:(NSRulerMarker *)mk;
- (BOOL) rulerView:(NSRulerView *)ruler shouldRemoveMarker:(NSRulerMarker *)mk;
- (float) rulerView:(NSRulerView *)ruler
		  willMoveMarker:(NSRulerMarker *)marker 
		  toLocation:(float)location;
- (float) rulerView:(NSRulerView *)ruler 
		  willAddMarker:(NSRulerMarker *)marker 
		  atLocation:(float)location;
- (void) rulerView:(NSRulerView *)ruler handleMouseDown:(NSEvent *)event;

- (void) updateRuler;
- (void) updateFontPanel;

- (NSArray *) acceptableDragTypes;

- (void) setNeedsDisplayInRect:(NSRect)rect avoidAdditionalLayout:(BOOL)flag;

@end

/* ****************************************************************************

	Restrict acceptable types of pasted data.  Similar to NSResponder's
	"paste:", but more appropriate for "Paste As" submenu commands.
 
** ***************************************************************************/

@interface NSTextView (NSPasteboard)

- (void) pasteAsPlainText:(id)sender;
- (void) pasteAsRichText:(id)sender;

@end

/* ****************************************************************************

	Methods shared by all of the NSTextViews of a single NSLayoutManager.
	Many are overrides of NSText or NSResponder methods.
 
** ***************************************************************************/

@interface NSText (NSSharing)			// s/b in NSTextView but is in NSText

- (NSRange) selectionRangeForProposedRange:(NSRange)proposedCharRange
							   granularity:(NSSelectionGranularity)granularity;
@end


@interface NSTextView (NSSharing)

- (NSSelectionAffinity) selectionAffinity;
- (NSSelectionGranularity) selectionGranularity;
- (void) setSelectionGranularity:(NSSelectionGranularity)granularity;

- (void) setSelectedRange:(NSRange)charRange				// Text selection
				 affinity:(NSSelectionAffinity)affinity 
				 stillSelecting:(BOOL)stillSelectingFlag;

- (void) setSelectedTextAttributes:(NSDictionary *)attributeDictionary;
- (NSDictionary *) selectedTextAttributes;

- (void) setInsertionPointColor:(NSColor *)color;
- (NSColor *) insertionPointColor;

- (void) updateInsertionPointStateAndRestartTimer:(BOOL)restartFlag;
												// temp attributes applied to
- (NSDictionary *) markedTextAttributes;		// selected text
- (void) setMarkedTextAttributes:(NSDictionary *)attributeDictionary;
- (void) setTypingAttributes:(NSDictionary *)attrs;
- (NSDictionary*) typingAttributes;

- (void) setRulerVisible:(BOOL)flag;
- (BOOL) usesRuler;
- (void) setUsesRuler:(BOOL)flag;

- (int) spellCheckerDocumentTag;

- (BOOL) shouldChangeTextInRange:(NSRange)affectedCharRange
			   replacementString:(NSString *)replacementString;
- (void) didChangeText;

- (NSRange) rangeForUserTextChange;
- (NSRange) rangeForUserCharacterAttributeChange;
- (NSRange) rangeForUserParagraphAttributeChange;

@end


@interface NSTextView (NSTextChecking)

- (NSRange) smartDeleteRangeForProposedRange:(NSRange)proposedCharRange;
- (BOOL) smartInsertDeleteEnabled;
- (void) setSmartInsertDeleteEnabled:(BOOL)flag;
- (void) smartInsertForString:(NSString *)pasteString 
			   replacingRange:(NSRange)charRangeToReplace 
			   beforeString:(NSString **)beforeString 
			   afterString:(NSString **)afterString;
@end


@interface NSObject (NSTextViewDelegate)		// Note all delegation messages
												// come from the first textView
- (void) textView:(NSTextView *)textView 
		 clickedOnCell:(id <NSTextAttachmentCell>)cell 
		 inRect:(NSRect)cellFrame;

- (void) textView:(NSTextView *)textView 
		 doubleClickedOnCell:(id <NSTextAttachmentCell>)cell 
		 inRect:(NSRect)cellFrame;

- (void) textView:(NSTextView *)view 
		 draggedCell:(id <NSTextAttachmentCell>)cell 
		 inRect:(NSRect)rect event:(NSEvent *)event;

- (NSRange) textView:(NSTextView *)textView 
			willChangeSelectionFromCharacterRange:(NSRange)oldSelectedCharRange 
			toCharacterRange:(NSRange)newSelectedCharRange;

- (void) textViewDidChangeSelection:(NSNotification *)notification;

	// replacementString is what will replace the affectedCharRange if chars
	// are changing or nil if only attributes are changing.  Not called if
	// "textView:shouldChangeTextInRanges:replacementStrings:" is implemented
- (BOOL) textView:(NSTextView *)textView
		 shouldChangeTextInRange:(NSRange)affectedCharRange 
		 replacementString:(NSString *)replacementString;
- (BOOL) textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSel;

@end

													// Mark text
@protocol NSTextInputClient							// not implemented

- (NSRange) markedRange;
- (void) unmarkText;

@end

extern NSString *NSTextViewDidChangeSelectionNotification;

#endif /* _mGSTEP_H_NSTextView */
