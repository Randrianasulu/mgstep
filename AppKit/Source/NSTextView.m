/*
   NSTextView.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Daniel Bðhringer <boehring@biomed.ruhr-uni-bochum.de>
   Date: August 1998
   mGSTEP: Felipe A. Rodriguez <far@illumenos.com>

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <AppKit/NSTextView.h>
#include <AppKit/NSPasteboard.h>
#include <AppKit/NSSpellChecker.h>
#include <AppKit/NSFontPanel.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSControl.h>
#include <AppKit/NSLayoutManager.h>
#include <AppKit/NSTextContainer.h>
#include <AppKit/NSTextStorage.h>
#include <AppKit/NSMenuItem.h>


#define NOTE(notice_name) 	NSText##notice_name##Notification


@implementation NSTextView

+ (void) registerForServices
{
}			// Registers send and return types for the Services facility

- (id) initWithFrame:(NSRect)frameRect textContainer:(NSTextContainer *)tc
{	
	[super initWithFrame:frameRect];

	if (tc) 										// container may be nil
		[self setTextContainer: tc];
	else
		{											// set up a new container
		}

	return self;
}							// This variant will create the text network  
							// (textStorage, layoutManager, and a container).
- (id) initWithFrame:(NSRect)frameRect
{	
	return [self initWithFrame:frameRect textContainer:nil];
}

- (void) dealloc
{
	[_headerView release];
    [super dealloc];
}

- (BOOL) validateMenuItem:(NSMenuItem *)aCell
{
    SEL action = [aCell action];

// 		Apple runtime has untyped selectors
//	if (action == @selector(cut:) || action == @selector(copy:))
	if (sel_eq (@selector(cut:), action) || sel_eq (@selector(copy:), action))
		if (_selectedRange.length == 0)
			return NO;

    return YES;
}

- (void) setTextContainer:(NSTextContainer *)container
{	
// The set method should not be called directly, but you might want to override it.  Gets or sets the text container for this view.  Setting the text container marks the view as needing display.  The text container calls the set method from its setTextView: method.
	ASSIGN(_textContainer, container);
}

- (NSTextContainer*) textContainer				{ return _textContainer; }

- (void) replaceTextContainer:(NSTextContainer *)newContainer
{	
// This method should be used instead of the primitive -setTextContainer: if you need to replace a view's text container with a new one leaving the rest of the web intact.  This method deals with all the work of making sure the view doesn't get deallocated and removing the old container from the layoutManager and replacing it with the new one.

	[self setTextContainer:newContainer];				// now do something to
}														// retain the web

// The textContianerInset determines the padding that the view provides around the container.  The container's origin will be inset by this amount from the bounds point {0,0} and padding will be left to the right and below the container of the same amount.  This inset affects the view sizing in response to new layout and is used by the rectangular text containers when they track the view's frame dimensions.

- (void) setTextContainerInset:(NSSize)inset	{ _inset = inset; }
- (NSSize) textContainerInset					{ return _inset; }

// The container's origin in the view is determined from the current usage of the container, the container inset, and the view size.  textContainerOrigin returns this point.  invalidateTextContainerOrigin is sent automatically whenever something changes that causes the origin to possibly move.  You usually do not need to call invalidate yourself. 

- (NSPoint) textContainerOrigin					{ return _textContainerOrigin; }
- (void) invalidateTextContainerOrigin			{}
- (NSLayoutManager*) layoutManager				{ return _layoutManager; }
- (NSTextStorage*) textStorage					{ return _textStorage; }

- (void) setConstrainedFrameSize:(NSSize)desiredSize
{	// Sets frame size of view to desiredSize constraint within min and max size.
}

- (void) setAlignment:(NSTextAlignment)alignment range:(NSRange)range
{	//complete the set of "range:" type set methods. to be equivalent to the
}	// set of non-range taking varieties.

- (void) pasteAsPlainText:sender
{
}
- (void) pasteAsRichText:sender
{
}
													// New Font menu commands 
- (void) turnOffKerning:(id)sender
{
}
- (void) tightenKerning:(id)sender
{
}
- (void) loosenKerning:(id)sender
{
}
- (void) useStandardKerning:(id)sender
{
}
- (void) turnOffLigatures:(id)sender
{
}
- (void) useStandardLigatures:(id)sender
{
}
- (void) useAllLigatures:(id)sender
{
}
- (void) raiseBaseline:(id)sender
{
}
- (void) lowerBaseline:(id)sender
{}
															// Ruler support 

- (void) rulerView:(NSRulerView *)ruler didMoveMarker:(NSRulerMarker *)marker
{
}
- (void) rulerView:(NSRulerView *)ruler didRemoveMarker:(NSRulerMarker *)marker
{
}
- (void) rulerView:(NSRulerView *)ruler didAddMarker:(NSRulerMarker *)marker
{
}
- (BOOL) rulerView:(NSRulerView *)ruler 
		 shouldMoveMarker:(NSRulerMarker *)marker
{
	return NO;
}

- (BOOL) rulerView:(NSRulerView *)ruler shouldAddMarker:(NSRulerMarker *)marker
{
	return NO;
}

- (float) rulerView:(NSRulerView *)ruler
		  willMoveMarker:(NSRulerMarker *)marker 
		  toLocation:(float)location
{
	return 0;
}

- (BOOL) rulerView:(NSRulerView *)ruler
		 shouldRemoveMarker:(NSRulerMarker *)marker
{
	return NO;
}

- (float) rulerView:(NSRulerView *)ruler
		  willAddMarker:(NSRulerMarker *)marker 
		  atLocation:(float)location
{
	return 0;
}
- (void) rulerView:(NSRulerView *)ruler handleMouseDown:(NSEvent *)event
{
}
													// Fine display control
- (void) setNeedsDisplayInRect:(NSRect)rect avoidAdditionalLayout:(BOOL)fla
{
}
												// Especially for subclassers
- (void) updateRuler
{
}
- (void) updateFontPanel
{
}

- (NSArray*) acceptableDragTypes
{	
	NSMutableArray *ret = [NSMutableArray arrayWithObject:NSStringPboardType];

	if([self isRichText])			
		[ret addObject:NSRTFPboardType];
	if([self importsGraphics])		
		[ret addObject:NSRTFDPboardType];

	return ret;
}

@end


@implementation NSTextView (NSSharing)

- (void) setSelectedRange:(NSRange)charRange
				 affinity:(NSSelectionAffinity)affinity 
				 stillSelecting:(BOOL)stillSelectingFlag
{
}

- (NSSelectionAffinity) selectionAffinity		{ return _selectionAffinity; }
- (NSSelectionGranularity) selectionGranularity { return _selectionGranularity; }

- (void) setSelectionGranularity:(NSSelectionGranularity)granularity
{	
	_selectionGranularity = granularity;
}

- (void) setSelectedTextAttributes:(NSDictionary *)attributeDictionary
{
}

- (NSDictionary*) selectedTextAttributes
{
	return nil;
}

- (void) setInsertionPointColor:(NSColor *)color
{	
	ASSIGN(_insertionPointColor, color);
}

- (NSColor *) insertionPointColor			{ return _insertionPointColor; }

- (void) updateInsertionPointStateAndRestartTimer:(BOOL)restartFlag
{
}

- (NSRange) markedRange
{
	return (NSRange){0,0};
}

- (void) setMarkedTextAttributes:(NSDictionary*)attributeDictionary
{
}

- (NSDictionary*) markedTextAttributes
{
	return nil;
}
													// Other NSTextView methods
- (void) setRulerVisible:(BOOL)flag
{
	_tx.rulerVisible = flag;
}

- (BOOL) usesRuler
{
	return NO;
}

- (void) setUsesRuler:(BOOL)flag
{
}

- (int) spellCheckerDocumentTag
{
	return 0;
}

- (NSDictionary*) typingAttributes
{
	return nil;
}

- (void) setTypingAttributes:(NSDictionary *)attrs
{
}

// Initiates a series of delegate messages (and general notifications) to determine whether modifications can be made to the receiver's text. If characters in the text string are being changed, replacementString contains the characters that will replace the characters in affectedCharRange. If only text attributes are being changed, replacementString is nil. This method checks with the delegate as needed using textShouldBeginEditing: and textView:shouldChangeTextInRange:replacementString:, returning YES to allow the change, and NO to prohibit it.

// This method must be invoked at the start of any sequence of user-initiated editing changes. If your subclass of NSTextView implements new methods that modify the text, make sure to invoke this method to determine whether the change should be made. If the change is allowed, complete the change by invoking the didChangeText method. See ªNotifying About Changes to the Textº in the class description for more information. If you can't determine the affected range or replacement string before beginning changes, pass (NSNotFound, 0) and nil for these values.

- (BOOL) shouldChangeTextInRange:(NSRange)affectedCharRange 
			   replacementString:(NSString *)replacementString
{
	return YES;
}

- (void) didChangeText
{						// FIX ME move layout change to endEditing ?
	int li = [self lineLayoutIndexForCharacterIndex:_selectedRange.location];

	[self _rebuildPlainLineLayoutFromLine:li delta:0 actualLine:li];
	[NSNotificationCenter post:NOTE(DidChange) object:self];
//	[self setNeedsDisplay:YES];
	[self _displayLineRange:(NSRange){li, 1}];
}

- (NSRange) rangeForUserTextChange
{
	return (NSRange){0,0};
}
- (NSRange) rangeForUserCharacterAttributeChange
{
	return (NSRange){0,0};
}
- (NSRange) rangeForUserParagraphAttributeChange
{
	return (NSRange){0,0};
}

- (BOOL) smartInsertDeleteEnabled		{ return _tx.smartInsertDeleteEnabled; }

- (void) setSmartInsertDeleteEnabled:(BOOL)flag		// if YES preserve proper
{													// space and punctuation
	_tx.smartInsertDeleteEnabled = flag;			// around selection 
}

- (NSRange) smartDeleteRangeForProposedRange:(NSRange)proposedCharRange
{
	return (NSRange){0,0};
}

- (void) smartInsertForString:(NSString *)pasteString 
			   replacingRange:(NSRange)charRangeToReplace 
			   beforeString:(NSString **)beforeString 
			   afterString:(NSString **)afterString
{
	if (!_tx.smartInsertDeleteEnabled || !pasteString)
		*beforeString = *afterString = nil;
}

@end
