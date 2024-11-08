/*
   NSText.m

   The RTFD text class

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

#include <Foundation/NSString.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSArchiver.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSData.h>
#include <Foundation/NSRange.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSScanner.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSArray.h>

#include <AppKit/NSText.h>
#include <AppKit/NSTextView.h>
#include <AppKit/NSControl.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSCursor.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSFontPanel.h>
#include <AppKit/NSFont.h>
#include <AppKit/NSFontManager.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSPasteboard.h>
#include <AppKit/NSSpellChecker.h>
#include <AppKit/NSDragging.h>
#include <AppKit/NSClipView.h>

#include <math.h>


#define NOTE(n_name)	NSText##n_name##Notification

// Class variables
NSString *NSTextMovement = @"NSTextMovement";

static NSTimer *__caretBlinkTimer = nil;
static id __caretBlinkTimerOwner = nil;
static NSCursor *__textCursor = nil;
static int __escapeKey = 0;



/* ****************************************************************************

	_LineLayoutInfo
 
** ***************************************************************************/

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

+ (void) calcDrawInfo;

+ (_LineLayoutInfo *) lineLayoutWithRange:(NSRange) aRange 
									  rect:(NSRect) aRect 
									  type:(unsigned) aType;

- (void) drawPlainLine:(NSString*)aSring withAttributes:(NSDictionary*)attr;
- (void) drawRTFLine:(NSMutableAttributedString*)aString;

- (NSRange) charRange;
- (NSRect) lineRect;
- (unsigned) type;

- (void) setCharRange:(NSRange) aRange;
- (void) setLineRect:(NSRect) aRect;
- (void) setType:(unsigned) aType;
- (NSString*) description;

- (NSString*) string;

@end


@interface NSEnumerator (SeekableEnumerator)

- (id) previousObject;

@end /* NSEnumerator (SeekableEnumerator) */


@interface NSAttributedString (DrawingAddition)

- (NSSize) sizeRange:(NSRange)aRange;

@end

@implementation NSAttributedString (DrawingAddition)

- (NSSize) sizeRange:(NSRange)currRange
{
	NSRect retRect = NSZeroRect;
	NSRange lineRange = currRange;
	NSPoint currPoint;
	NSString *string = [self string];

	for(; NSMaxRange(currRange) < NSMaxRange(lineRange);)	// draw all "runs"
		{
		NSDictionary *attribs = [self attributesAtIndex:NSMaxRange(currRange) 
									  longestEffectiveRange:&currRange 
									  inRange:lineRange];
		NSString *substring = [string substringWithRange:currRange];
		NSRect sizeRect = NSZeroRect;

		sizeRect.size = [substring sizeWithAttributes:attribs];
		retRect = NSUnionRect(retRect, sizeRect);
		currPoint.x += sizeRect.size.width;
		}

	return retRect.size;
}

@end /* NSAttributedString (DrawingAddition) */

/* ****************************************************************************

	NSText
 
** ***************************************************************************/

@implementation NSText

+ (void) initialize
{
	if (self == [NSText class])
		{
		NSArray	*r = [NSArray arrayWithObjects: NSStringPboardType, nil];
		NSArray	*s = [NSArray arrayWithObjects: NSStringPboardType, nil];

		[NSApp registerServicesMenuSendTypes:s returnTypes:r];
		__textCursor = [[NSCursor IBeamCursor] retain];
		}
}

/* ****************************************************************************
 
	FIX ME a hack: rtf should be spit out here in order to be OS-compatible
	(NeXT OPENSTEP additions to NSAttributedString)

	- (NSData *)RTFDFromRange:(NSRange)range
				documentAttributes:(NSDictionary *)dict; and friends.

** ***************************************************************************/

+ (NSData*) dataForAttributedString:(NSAttributedString*)aString
{
	return [NSArchiver archivedDataWithRootObject:aString];
}

/* ****************************************************************************
 
	FIX ME a rtf parser should come in here in order to be OPENSTEP-compatible.
	return value is guaranteed to be a NSAttributedString
	even if data is only NSString

** ***************************************************************************/

+ (NSAttributedString*) attributedStringForData:(NSData*)aData
{
	id erg = [NSUnarchiver unarchiveObjectWithData:aData];

	if(![erg isKindOfClass:[NSAttributedString class]])
		return [[[NSAttributedString alloc] initWithString:erg] autorelease];

	return erg;
}

+ (NSString*) _newlineString			{ return @"\n"; }

- (id) init
{
	return [self initWithFrame:NSMakeRect(0,0,100,100)];
}

- (id) initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]))
		{
		NSCharacterSet *c;
		NSString *n;

		_tx.alignment = NSLeftTextAlignment;
		_tx.editable = YES;
		_inset.width = 5;
		[self setRichText:NO];					// sets up the contents object
		_tx.selectable = YES;
		_tx.vertResizable = YES;
		_tx.drawsBackground = YES;
		ASSIGN(_backgroundColor, [NSColor whiteColor]);
		ASSIGN(_textColor, [NSColor blackColor]);
		ASSIGN(_insertionPointColor, [NSColor redColor]);
		_font = [NSFont userFontOfSize:12];

		n = @" \n\t[]{}(),:;./=";
		c = [NSCharacterSet characterSetWithCharactersInString: n];
	//  [NSCharacterSet whitespaceCharacterSet];
		[self setSelectionWordGranularitySet:c];	

		n = [NSText _newlineString];
		c = [NSCharacterSet characterSetWithCharactersInString:n];
		[self setSelectionParagraphGranularitySet:c];

		_minSize = (NSSize){5, 15};
		_maxSize = (NSSize){HUGE,HUGE};

		[self setString:@""];
		[self setSelectedRange:NSMakeRange(0,0)];
		}

	return self;
}

- (void) dealloc 
{
	fprintf(stderr, "NSText dealloc: \n");
	[self unregisterDraggedTypes];
	_window = nil;
	[_backgroundColor release];
	[_textColor release];
	[_insertionPointColor release];
	[_font release];
	[plainContent release];
	[rtfContent release];
    [super dealloc];
}

- (NSDictionary*) defaultTypingAttributes
{
	static NSFont *lastFont = nil;
	static NSColor *textColor = nil;
	static NSDictionary *attrs = nil;

	if((!attrs) || lastFont != _font || textColor != _textColor)
		{
		if (attrs)
			[attrs autorelease];
		attrs = [NSDictionary dictionaryWithObjectsAndKeys:	_font,
						 				NSFontAttributeName, _textColor,
						 				NSForegroundColorAttributeName, nil];
		lastFont = _font;
		textColor = _textColor;
		[attrs retain];
		}

	return attrs;
}
														// enable and disable
- (id) validRequestorForSendType:(NSString*)sendType	// services menu items
					  returnType:(NSString*)returnType
{
	if ((!sendType || [sendType isEqual: NSStringPboardType]) 
			&& (!returnType || [returnType isEqual: NSStringPboardType]))
		{
		if ((_selectedRange.length || !sendType) 
				&& ([self isEditable] || !returnType))
			return self;
	    }

	return [super validRequestorForSendType:sendType returnType:returnType];
}

- (NSRange) selectionRangeForProposedRange:(NSRange)proposedCharRange 
							   granularity:(NSSelectionGranularity)granularity
{
	NSCharacterSet *set = nil;
	NSUInteger l = [self textLength];
	NSUInteger lastIndex = l - 1;
	NSUInteger lpos = MIN(lastIndex, proposedCharRange.location);
	NSUInteger rpos = NSMaxRange(proposedCharRange);
	NSString *string = [self string];
	BOOL rmemberstate, lmemberstate;

	if (!l)
		return NSMakeRange(0,0);

	switch (granularity)
		{
		case NSSelectByCharacter: 
			return NSIntersectionRange(proposedCharRange, NSMakeRange(0, l+1));

		case NSSelectByWord:
			{
			unichar c = [string characterAtIndex:lpos];
			unichar cb = 0, ob = [@"{" characterAtIndex:0];
			int openBraceCounter = 0;

			if (c == ob)
				cb = [@"}" characterAtIndex:0];
			else if (c == (ob = [@"[" characterAtIndex:0]))
				cb = [@"]" characterAtIndex:0];
			else if (c == (ob = [@"(" characterAtIndex:0]))
				cb = [@")" characterAtIndex:0];

			if(cb != 0)
				{
				while (rpos <= lastIndex)
					{
					if ((c = [string characterAtIndex:rpos]) == cb)
						{
						openBraceCounter--;
						if (openBraceCounter == 0)
							break;
						}
					else
						if (c == ob)
							openBraceCounter++;
					rpos++;
					}

				return _NSAbsoluteRange(lpos, MIN(rpos+1, lastIndex));
				}

			if (c == (ob = [@"}" characterAtIndex:0]))
				cb = [@"{" characterAtIndex:0];
			else if (c == (ob = [@"]" characterAtIndex:0]))
				cb = [@"[" characterAtIndex:0];
			else if (c == (ob = [@")" characterAtIndex:0]))
				cb = [@"(" characterAtIndex:0];

			if (cb != 0)
				{
				while (0 < rpos)
					{
					if ((c = [string characterAtIndex:rpos]) == cb)
						{
						openBraceCounter--;
						if (openBraceCounter == 0)
							break;
						}
					else
						if (c == ob)
							openBraceCounter++;
					rpos--;
					}

				return _NSAbsoluteRange(lpos+1, MIN(rpos, lastIndex));
			}	}
			set = selectionWordGranularitySet;
			break;

		case NSSelectByParagraph:
			set = selectionParagraphGranularitySet;
			break;
		}

	NSLog(@"rpos = %lu, lpos = %lu\n", rpos, lpos);
	{
	unichar comma = [@"," characterAtIndex:0];
	unichar period = [@"." characterAtIndex:0];
	unichar apostraphe = [@"'" characterAtIndex:0];
	unichar newline = [@"\n" characterAtIndex:0];
	BOOL numeric = NO;
	int rp = MIN(rpos, lastIndex);
	unichar uc = [string characterAtIndex:rp];
														// now work on set...
	lmemberstate = [set characterIsMember:[string characterAtIndex:lpos]];
	rmemberstate = [set characterIsMember:[string characterAtIndex: rp]];

	for (;(rpos <= lastIndex); rpos++)
		{
		unichar u = [string characterAtIndex:rpos];
		BOOL member = [set characterIsMember:u];

		if (!member)
			{
			if (!numeric)
				numeric = [[NSCharacterSet decimalDigitCharacterSet]
							characterIsMember: u];
			if (period == uc || comma == uc || apostraphe == uc)
				rmemberstate = NO;
			}
		else
			{
			if (numeric)
				{
				if (u == period || u == comma)
					continue;
				}
			else if (u == apostraphe)
				continue;
			}

		if (member != rmemberstate)
			break;
		}

	for (;(lpos); lpos--)
		{
		unichar u = [string characterAtIndex:lpos];
		BOOL member = [set characterIsMember:u];

		if (!member)
			{
			if (!numeric)
				numeric = [[NSCharacterSet decimalDigitCharacterSet] 
							characterIsMember: u];
			if (period == uc || comma == uc || apostraphe == uc)
				lmemberstate = NO;
			}
		else
			{
			if (numeric)
				{
				if (u == period || u == comma)
					continue;
				}
			else if (u == apostraphe)
				continue;
			else if (u == newline)
				lmemberstate = NO;
			}

		if (member != lmemberstate)
			break;
		}
	}

	if(lpos != 0)
		lpos++;

	return _NSAbsoluteRange(lpos, rpos);
}

- (void) replaceRange:(NSRange)r withAttributedString:(NSAttributedString*)as
{										// low level (no selection handling, 
	if(_tx.isRichText)					// relayout or display)
		return [rtfContent replaceCharactersInRange:r withAttributedString:as];

	return [plainContent replaceCharactersInRange:r withString:[as string]];
}

- (void) replaceRange:(NSRange)range withRTFD:(NSData *)rtfdData
{
	return [self replaceRange:range 
		withAttributedString:[[self class] attributedStringForData:rtfdData]];
}

- (void) replaceRange:(NSRange)range withRTF:(NSData*)rtfData
{
	[self replaceRange:range withRTFD:rtfData];
}

- (void) replaceRange:(NSRange)range withString:(NSString*)aString
{
	if(_tx.isRichText)
		return [rtfContent replaceCharactersInRange:range withString:aString];

	return [plainContent replaceCharactersInRange:range withString:aString];
}

- (NSData*) RTFDFromRange:(NSRange)range
{
	if(_tx.isRichText)
		return [[self class] dataForAttributedString:[rtfContent 
							 attributedSubstringFromRange:range]];
	return nil;
}

- (NSData*) RTFFromRange:(NSRange)range
{
	return [self RTFDFromRange:range];
}

- (void) _replaceTextStorage:(NSAttributedString *)string
{
	ASSIGN(rtfContent, string);
	ASSIGN(plainContent, nil);
	[_lineLayoutInformation autorelease];
	_lineLayoutInformation = nil;				// force complete re-layout
	_selectedRange = NSMakeRange(0,0);
                    [self setRichText:YES];
}

- (void) setString:(NSString *)string
{
	ASSIGN(plainContent, [NSMutableString stringWithString:string]);
	[_lineLayoutInformation autorelease];
	_lineLayoutInformation = nil;				// force complete re-layout
	_selectedRange = NSMakeRange(0,0);
	[self setRichText:NO];
}

- (NSString*) string
{
	return (_tx.isRichText) ? [rtfContent string] : plainContent;
}

- (NSTextAlignment) alignment				{ return _tx.alignment; }
- (void) setAlignment:(NSTextAlignment)mode	{ _tx.alignment = mode; }
- (void) setBackgroundColor:(NSColor*)color { ASSIGN(_backgroundColor,color); }
- (NSColor*) backgroundColor				{ return _backgroundColor; }
- (NSColor*) textColor						{ return _textColor; }
- (NSFont*) font							{ return _font; }
- (NSRange) selectedRange					{ return _selectedRange; }
- (void) setDrawsBackground:(BOOL)flag		{ _tx.drawsBackground = flag; }
- (void) setUsesFontPanel:(BOOL)flag		{ _tx.usesFontPanel = flag; }
- (BOOL) usesFontPanel						{ return _tx.usesFontPanel; }
- (BOOL) isRulerVisible						{ return _tx.rulerVisible; }
- (BOOL) importsGraphics					{ return _tx.importsGraphics; }
- (BOOL) isRichText							{ return _tx.isRichText; }
- (BOOL) drawsBackground					{ return _tx.drawsBackground; }
- (BOOL) isFlipped 							{ return YES; }
- (BOOL) isOpaque							{ return _tx.drawsBackground;}
- (BOOL) isSelectable						{ return _tx.selectable; }
- (BOOL) isEditable							{ return _tx.editable; }

- (void) setEditable:(BOOL)flag
{
	if ((_tx.editable = flag))
		_tx.selectable = YES;					// If we are editable then 
}												// we are selectable

- (void) setSelectable:(BOOL)flag
{
	if (!(_tx.selectable = flag)) 
		_tx.editable = NO;						// If we are not selectable 
}												// then we must not be editable

- (void) setImportsGraphics:(BOOL)flag
{
	_tx.importsGraphics = flag;
	[self updateDragTypeRegistration];
}

- (void) toggleRuler:(id)sender
{
	_tx.rulerVisible = !_tx.rulerVisible;
}

- (void) setRichText:(BOOL)flag
{
//	if(_tx.isRichText == flag)
//		return;

	if((_tx.isRichText = flag))
		{
		if(!rtfContent)
			{ 
			NSString *s = plainContent ? (NSString*)plainContent : @"";

			rtfContent = [NSMutableAttributedString alloc];
			[rtfContent initWithString:s 
						attributes:[self defaultTypingAttributes]];
			}
		[self _rebuildRTFLineLayoutFromLine:0 delta:0 actualLine:0];
		} 
	else
		{
		if(!plainContent) 
			{
			plainContent = [NSMutableString alloc];
			[plainContent initWithString:rtfContent ? [rtfContent string]:@""];
			}
		[self _rebuildPlainLineLayoutFromLine:0 delta:0 actualLine:0];
		}

	[self updateDragTypeRegistration];

	[self sizeToFit];
	[self display];
}

- (void) changeFont:(id)sender		// This action method changes the font of
{									// the selection for a rich text object, or
	if([self usesFontPanel])		// of all text for a plain text object. If
		{							// the receiver doesn't use the Font Panel,
		if(_tx.isRichText)			// however, this method does nothing.
			{
			NSRange selectedRange = _selectedRange;
			NSRange searchRange = selectedRange, foundRange;
			int maxSelRange;

			for(maxSelRange = NSMaxRange(selectedRange); 
					searchRange.location < maxSelRange;
					searchRange = NSMakeRange(NSMaxRange(foundRange), 
					maxSelRange - NSMaxRange(foundRange)))
				{
				NSFont *font = [rtfContent attribute:NSFontAttributeName 
										   atIndex:searchRange.location 
										   longestEffectiveRange:&foundRange 
										   inRange:searchRange];
				if(font)
					[self setFont:[sender convertFont:font] 
						  ofRange:foundRange];
			}	}
		else
			[self setFont:[sender convertFont:[[self defaultTypingAttributes] 
				  objectForKey:NSFontAttributeName]]];
		}
}

- (void) setSelectionWordGranularitySet:(NSCharacterSet*)aSet
{
	ASSIGN(selectionWordGranularitySet, aSet);
}

- (void) setSelectionParagraphGranularitySet:(NSCharacterSet*)aSet
{
	ASSIGN(selectionParagraphGranularitySet, aSet);
}

- (void) setTypingAttributes:(NSDictionary*)d
{
	if ([d isKindOfClass:[NSMutableDictionary class]])
		ASSIGN(_typingAttributes, (NSMutableDictionary*)d);
	else 
		{
		[_typingAttributes autorelease];
		_typingAttributes = [[NSMutableDictionary alloc] initWithDictionary:d];
		} 												// do not autorelease!
}

- (NSMutableDictionary *) typingAttributes
{
	if (!_typingAttributes)
		{
		NSDictionary *d = [self defaultTypingAttributes];

		return [NSMutableDictionary dictionaryWithDictionary:d];
		}

	return _typingAttributes;
}

- (void) setTextColor:(NSColor *)color range:(NSRange)range
{
	if(_tx.isRichText)
		{
		if(color) 
			[rtfContent addAttribute:NSForegroundColorAttributeName 
						value:color 
						range:range];
		} 
	else 
		{}
}

- (void) setColor:(NSColor*)color ofRange:(NSRange)range
{
	[self setTextColor:color range:range];
}

- (void) setFont:(NSFont*)obj			
{
	if(_font != obj)
		ASSIGN(_font, obj);
}

- (void) setFont:(NSFont*)font ofRange:(NSRange)range
{
	if(_tx.isRichText)
		{
		if(font)
			[rtfContent addAttribute:NSFontAttributeName
						value:font
						range:range];
		} 
	else 
		{}
}

- (void) setTextColor:(NSColor*)color
{
	if(_textColor != color)
		{
		ASSIGN(_textColor, color);
		if (!_tx.isRichText)
			[self setNeedsDisplay:YES];
		}
}

- (BOOL) shouldDrawInsertionPoint
{
	return (_selectedRange.length == 0) && [self isEditable];
}

- (void) _drawCaretInRect:(NSRect)rect turnedOn:(BOOL)flag
{
	if(flag)
		{
		[_insertionPointColor set];
		NSRectFill(rect);
		}
	else
		{
		[_backgroundColor set];		// redundant if _tx.drawsBackground but
		NSRectFill(rect);			// needed for cursor blink (e.g. Login)
		[self _drawRectNoSelection:rect];
		}
}

- (void) _blinkCaret:(id)sender
{
	static int blinkCounter = 0;
	BOOL didLock = NO;
	NSRect startRect;

	if (_window == nil)
		{
		if (__caretBlinkTimerOwner == self)
			{
			[__caretBlinkTimer invalidate];
			__caretBlinkTimer = __caretBlinkTimerOwner = nil;
			}
		return;
		}

	if ([NSView focusView] != self)
		{
		[self lockFocus];
		didLock = YES;
		}

	_tx.caretVisible = !(_tx.caretVisible);
	startRect = [self rectForCharacterIndex:_selectedRange.location];
	startRect.size.width = 1.0;

	[self _drawCaretInRect:startRect turnedOn:_tx.caretVisible];

	if(didLock)
		[self unlockFocus];

	[_window flushWindow];

	if(blinkCounter++ > 30)					// post periodic AppKit events to
		{									// flush the autorelease pool
		[NSApp postEvent:_NSAppKitEvent() atStart:NO];
		blinkCounter = 0;
		}
}

- (void) _startCaretBlinkTimer
{
	NSRunLoop *c = [NSRunLoop currentRunLoop];

	__caretBlinkTimer = [NSTimer timerWithTimeInterval: 0.7
								 target: self
								 selector: @selector(_blinkCaret:)
								 userInfo: nil
								 repeats: YES];

	[c addTimer:__caretBlinkTimer forMode:NSDefaultRunLoopMode];
	[c addTimer:__caretBlinkTimer forMode:NSModalPanelRunLoopMode];
	__caretBlinkTimerOwner = self;
}

- (void) _stopCaretBlinkTimer
{
	[__caretBlinkTimer invalidate];
	__caretBlinkTimer = __caretBlinkTimerOwner = nil;
	if (_tx.caretVisible)
		[self _blinkCaret:self];
}

- (void) _drawCaretAtIndex:(NSUInteger)index turnOn:(BOOL)flag
{
	NSRect startRect, r;

	if(flag && ([_window firstResponder] != self))		// we must be the first
		return;											// responder in order
														// to turn on the caret
	r = startRect = [self rectForCharacterIndex:index];
	startRect.size.width = 1.0;
	[self _drawCaretInRect:startRect turnedOn:flag];

	if (!flag)
		[self _drawRectNoSelection:r]; // fix blur arrow key move w/o scrolling

	if ((_tx.caretVisible = flag))
		{
		if (__caretBlinkTimer == nil)
			[self _startCaretBlinkTimer];
		}
	else
		{
		if (__caretBlinkTimerOwner == self && __caretBlinkTimer != nil)
			{
			[__caretBlinkTimer invalidate];
			__caretBlinkTimer = __caretBlinkTimerOwner = nil;
		}	}
}

- (void) _drawSelectionRangeNoCaret:(NSRange)aRange
{
	if(aRange.length)
		{
		NSRect start = [self rectForCharacterIndex:aRange.location];
		NSRect end = [self rectForCharacterIndex:NSMaxRange(aRange)];

		if(start.origin.y == end.origin.y)		// single line selection
			{
			NSHighlightRect(NSMakeRect(start.origin.x, start.origin.y,
							end.origin.x - start.origin.x, start.size.height));
			}
		else 									// two line selection
			if(start.origin.y == end.origin.y - end.size.height)
				{												// first line
				NSHighlightRect((NSMakeRect(start.origin.x, start.origin.y,
											_frame.size.width - start.origin.x,
											start.size.height)));
				NSHighlightRect(NSMakeRect(_inset.width, end.origin.y,
										   end.origin.x - _inset.width,
										   end.size.height));	// second line
				}
			else								// 3 Rects: multiline selection
				{												// first line
				NSHighlightRect(((NSMakeRect(start.origin.x, start.origin.y,
											_frame.size.width - start.origin.x,
											start.size.height))));
				NSHighlightRect(NSMakeRect(_inset.width, NSMaxY(start),
											_frame.size.width - _inset.width,
											end.origin.y - NSMaxY(start)));
				NSHighlightRect(NSMakeRect(_inset.width, end.origin.y,
										   end.origin.x - _inset.width,
										   end.size.height));	// last line
		}		}
}

- (void) _drawSelectionRange:(NSRange)aRange
{
	if(aRange.length)
		[self _drawSelectionRangeNoCaret:aRange];
	else
		[self _drawCaretAtIndex:aRange.location turnOn:YES];
}

- (void) setSelectedRange:(NSRange)range
{
	BOOL didLock = NO;

	if(!_window)
		{
		_selectedRange = range;

		return;
		}

	if([NSView focusView] != self)
		{
		[self lockFocus];
		didLock = YES;
		}

	if(_selectedRange.length == 0)						// remove old cursor
		[self _drawCaretAtIndex:_selectedRange.location turnOn:NO];
	else
		[self _drawSelectionRangeNoCaret:_selectedRange];

//	[NSNotificationCenter post:NOTE(ViewDidChangeSelection) object:self];

	_selectedRange = range;

	if([self usesFontPanel])							// update fontPanel
		{
		BOOL isMultiple = NO;
		NSFont *currentFont = nil;

		if(_tx.isRichText)
			{// if(are multiple fonts in selection) isMultiple=YES;
			// else currentFont=[rtfContent attribute:NSFontAttributeName atIndex:range.location longestEffectiveRange:NULL inRange:range]
			} 
		else 
			currentFont = [[self defaultTypingAttributes] 
							objectForKey:NSFontAttributeName];
		[[NSFontPanel sharedFontPanel] setPanelFont:currentFont 
									   isMultiple:isMultiple];
		}

	if(range.length)									// display
		{									// FIX ME disable caret timed entry
		[self _drawSelectionRangeNoCaret:range];
		} 
	else									// no selection
		{
		if(_tx.isRichText)
			{
			NSMutableDictionary *m;
			NSDictionary *d = [rtfContent attributesAtIndex:range.location 
										  effectiveRange:NULL];

			m = [NSMutableDictionary dictionaryWithDictionary:d];
			[self setTypingAttributes:m];
			}

		[_window flushWindow];
		[self _drawCaretAtIndex:range.location turnOn:YES];
		}
	[self scrollRangeToVisible:range];

	if(didLock)
		{
		[self unlockFocus];
		[_window flushWindow];
		}
}

- (NSSize) maxSize 							{ return _maxSize; }
- (NSSize) minSize							{ return _minSize; }
- (void) setMaxSize:(NSSize)newMaxSize		{ _maxSize = newMaxSize; }
- (void) setMinSize:(NSSize)newMinSize		{ _minSize = newMinSize; }
- (BOOL) isHorizontallyResizable			{ return _tx.horzResizable; }
- (BOOL) isVerticallyResizable				{ return _tx.vertResizable; }
- (void) setHorizontallyResizable:(BOOL)flg	{ _tx.horzResizable = flg; }
- (void) setVerticallyResizable:(BOOL)flag	{ _tx.vertResizable = flag; }

- (NSUInteger) textLength
{
	return (_tx.isRichText) ? [rtfContent length] : [plainContent length];
}

- (NSRect) boundingRectForLineRange:(NSRange)lineRange
{
	NSArray *linesToDraw = [_lineLayoutInformation subarrayWithRange:lineRange];
	NSEnumerator *lineEnum = [linesToDraw objectEnumerator];
	_LineLayoutInfo *currentInfo;
	NSRect r = NSZeroRect;

	for(;(currentInfo = [lineEnum nextObject]);)
		r = NSUnionRect(r, [currentInfo lineRect]);

	return r;
}

- (void) sizeToFit:(id)sender				{ [self sizeToFit]; }

- (void) sizeToFit
{
	NSRect current = [self frame];
	NSRect sizeToRect = current;

	if(_tx.fieldEditor)									// FIX ME ?
		if(![_superview isKindOfClass:[NSClipView class]])
			return;

	if(_tx.horzResizable && _lineLayoutInformation)
		{
		NSRange r = {0, [_lineLayoutInformation count]};

		NSWidth(sizeToRect) = NSWidth([self boundingRectForLineRange:r]);
		NSWidth(sizeToRect) = MAX(NSWidth(sizeToRect), _minSize.height);
		NSWidth(sizeToRect) = MIN(_maxSize.width, NSWidth(sizeToRect));
		}

	if(_tx.vertResizable && _lineLayoutInformation)
		{
		NSRect lastRect = [self rectForCharacterIndex: [self textLength]];
		float h = MAX(NSMaxY(lastRect), _minSize.height);

		NSHeight(sizeToRect) = MIN(_maxSize.height, h);
		}

	if(_tx.fieldEditor)									// FIX ME ?
		{
		float superViewWidth = NSWidth([_superview frame]);

		NSWidth(sizeToRect) = MAX(superViewWidth, NSWidth(sizeToRect));
		sizeToRect.size.width += 3;
		sizeToRect.size.height = MIN( NSHeight(_frame), NSHeight(sizeToRect));
		}

	if(!NSEqualSizes(current.size, sizeToRect.size))
		{
		if (NSHeight(current) > NSHeight(sizeToRect))	// shrinkage ?
			{
			NSMinY(current) = NSMaxY(sizeToRect);
			[_superview setNeedsDisplayInRect:current];
			}
		[self setFrameSize:sizeToRect.size];
		}
}

- (void) resizeWithOldSuperviewSize:(NSSize)oldSize		
{
	NSRect r = [_superview bounds];
//	NSLog(@"NSText resizeWithOldSuperviewSize");
	[super resizeWithOldSuperviewSize:oldSize];
	[self _rebuildLineLayoutFromLine:0];
	
	if (r.origin.y > 0 && r.size.height > oldSize.height)
		{
		if ((r.origin.y -= (r.size.height - oldSize.height)) < 0)
			r.origin.y = 0;
		[_superview setBoundsOrigin: r.origin];
		}
}

- (void) alignCenter:(id)sender								// Editing Commands
{
}

- (void) alignLeft:(id)sender
{
}

- (void) alignRight:(id)sender
{
}

- (void) selectAll:(id)sender
{
	[self setSelectedRange:NSMakeRange(0, [self textLength])];
}

- (void) subscript:(id)sender
{
}

- (void) superscript:(id)sender
{
}

- (void) underline:(id)sender
{
	if(_tx.isRichText)
		{
		BOOL doUnderline = YES;

		if([[rtfContent attribute:NSUnderlineStyleAttributeName 
						atIndex:_selectedRange.location 
						effectiveRange:NULL] intValue])	
			doUnderline = NO;

		if(_selectedRange.length)
			{
			[rtfContent addAttribute:NSUnderlineStyleAttributeName 
						value:[NSNumber numberWithInt:doUnderline] 
						range:_selectedRange];
			//[self _rebuildLineLayoutFromLine:lineIndex];
			//[self displayRect:NSUnionRect([[_lineLayoutInformation objectAtIndex:lineIndex] lineRect],[[_lineLayoutInformation lastObject] lineRect])];
			} 
		else 
			[[self typingAttributes] setObject:[NSNumber numberWithInt: doUnderline]
									 forKey: NSUnderlineStyleAttributeName];
		}
}

- (void) unscript:(id)sender
{
	if(_tx.isRichText)
		{
		if(_selectedRange.length)
			{
			[rtfContent removeAttribute:NSUnderlineStyleAttributeName 
						range:_selectedRange];
			//[self _rebuildLineLayoutFromLine:lineIndex];
			//[self displayRect:NSUnionRect([[_lineLayoutInformation objectAtIndex:lineIndex] lineRect],[[_lineLayoutInformation lastObject] lineRect])];
			} 
		else 
			[[self typingAttributes] removeObjectForKey:NSUnderlineStyleAttributeName];
		}
}

- (void) scrollRangeToVisible:(NSRange)range					// Scrolling
{
	NSRect startCharRect = [self rectForCharacterIndex:_selectedRange.location];
	NSRect rect;

	DBLog(@"scrollRangeToVisible");

	if (_tx.fieldEditor)
		{
		rect.origin.x = startCharRect.origin.x;
		rect.origin.y = 0;
		rect.size.width = 1.0;
		rect.size.height = startCharRect.size.height;
		DBLog (@"scrollRangeToVisible (%f, %f), (%f, %f)", rect.origin.x, 
					rect.origin.y, rect.size.width, rect.size.height);
		}
	else
		{
		NSRect end = [self rectForCharacterIndex:NSMaxRange(_selectedRange)];

		rect = NSUnionRect(startCharRect, end);
		if ((rect.size.width > _bounds.size.width)
				|| (rect.origin.y < 0) || (rect.size.height <= 0))
			{				// FIX ME should not occur unless text > bounds
			NSLog (@"Error scrollRangeToVisible (%f, %f), (%f, %f) %f",
					rect.origin.x, rect.origin.y, 
					rect.size.width, rect.size.height, _bounds.size.width);

			return;
		}	}

//	[self scrollRectToVisible:rect];
	if ([self scrollRectToVisible:rect] && _tx.fieldEditor)
		[self _drawRectNoSelection:[self visibleRect]]; // fix bold blur w/key scrolling
}

- (BOOL) readRTFDFromFile:(NSString *)path				// read / write RTFD
{
	NSData *d = [NSData dataWithContentsOfFile:path];
	id peek;

	if (d && (peek = [[self class] attributedStringForData: d]))
		{
		_tx.isRichText = YES;	
		[self updateDragTypeRegistration];
		[self replaceRange:NSMakeRange(0,[self textLength]) 
			  withAttributedString:peek];
		[self _rebuildLineLayoutFromLine:0];
		[self setNeedsDisplay:YES];

		return YES;
		}

	return NO;
}

- (BOOL) writeRTFDToFile:(NSString *)path atomically:(BOOL)flag
{
/*	if(_tx.isRichText)
		{
		NSFileWrapper *wrapper = [[[NSFileWrapper alloc] initRegularFileWithContents: [[self class] dataForAttributedString:rtfContent]] autorelease];

		return [wrapper writeToFile:path atomically:flag updateFilenames:YES];
		} 
*/
	return NO;
}

- (void) setFieldEditor:(BOOL)flag								// Field Editor
{ 
	_tx.horzResizable = YES;
	_tx.vertResizable = NO;
	_inset = (NSSize){2,1};
	_tx.fieldEditor = flag;
}

- (BOOL) isFieldEditor					{ return _tx.fieldEditor; }

- (int) lineLayoutIndexForCharacterIndex:(unsigned)anIndex
{
	NSEnumerator *lineEnum;
	_LineLayoutInfo *currentInfo;
	int lineLayoutCount;

	if(anIndex >= NSMaxRange([[_lineLayoutInformation lastObject] charRange])
			&& (lineLayoutCount = [_lineLayoutInformation count]))
		return lineLayoutCount - 1;

	lineEnum = [_lineLayoutInformation objectEnumerator];
	for(;(currentInfo = [lineEnum nextObject]);)
		{
		NSRange charRange = [currentInfo charRange];

		if(charRange.location <= anIndex && anIndex <= NSMaxRange(charRange) 
				- ([currentInfo type] == LineLayoutParagraphType ? 1 : 0))
			return [_lineLayoutInformation indexOfObject:currentInfo];
		}

	NSLog(@"NSText lineLayoutIndexForCharacterIndex: (%d) out of bounds!", anIndex);

	return 0;
}
										// FIX ME choose granularity according 
- (void) _moveCursorUp:(id)sender		// to keyboard modifier flags
{
	NSPoint p = [self rectForCharacterIndex: _selectedRange.location].origin;
	NSUInteger i;

	if(_selectedRange.length) 
		_cursorX = p.x;
	p = (NSPoint){_cursorX, MAX(0, p.y - 0.001)};
	i = [self characterIndexForPoint:p];
	[self setSelectedRange:[self selectionRangeForProposedRange:(NSRange){i,0}
								 granularity:NSSelectByCharacter]];
}

- (void) _moveCursorDown:(id)sender
{
	NSRect cursorRect = [self rectForCharacterIndex: _selectedRange.location];
	NSUInteger i;
	NSPoint p;

	if(_selectedRange.length) 
		_cursorX = cursorRect.origin.x;
	p = (NSPoint){_cursorX, NSMaxY(cursorRect) + 0.001};
	i = [self characterIndexForPoint:p];
	[self setSelectedRange:[self selectionRangeForProposedRange:(NSRange){i,0} 
								 granularity:NSSelectByCharacter]];
}

- (void) _moveCursorLeft:(id)sender
{
	NSUInteger i = _selectedRange.location - 1;

	[self setSelectedRange:[self selectionRangeForProposedRange:(NSRange){i,0} 
								 granularity:NSSelectByCharacter]];
	_cursorX = [self rectForCharacterIndex: _selectedRange.location].origin.x;
}

- (void) _moveCursorRight:(id)sender
{
	NSRange r = {MIN(NSMaxRange(_selectedRange) + 1, [self textLength]), 0};

	[self setSelectedRange:[self selectionRangeForProposedRange:r
								 granularity:NSSelectByCharacter]];
	_cursorX = [self rectForCharacterIndex: _selectedRange.location].origin.x;
}

- (void) mouseDown:(NSEvent *)event
{
	NSSelectionGranularity g;
	NSDate *distantFuture;
	NSRange chosenRange, prevChosenRange, proposedRange;
	NSUInteger startIndex;
	BOOL didDragging = NO;
	NSEventType type;
	NSEvent *lastMovementEvent = event;
	NSPoint point;

	if (!_tx.selectable)						// do not recognize mouse down
		return;									// if text is not selectable

	DBLog(@"Click count %d", [event clickCount]);
	switch([event clickCount])
		{
		default: g = NSSelectByCharacter;	break;
		case 2:  g = NSSelectByWord;		break;
		case 3:  g = NSSelectByParagraph;	break;
		}

	point = [self convertPoint:[event locationInWindow] fromView:nil];
	startIndex = [self characterIndexForPoint:point];
	proposedRange = NSMakeRange(startIndex,0);
	chosenRange = [self selectionRangeForProposedRange: proposedRange 
						granularity:g];
	prevChosenRange = chosenRange;
	distantFuture = [NSDate distantFuture];

	[self lockFocus];
											// clean up before doing dragging
	if (_selectedRange.length == 0) 		// remove old cursor
		[self _drawCaretAtIndex:_selectedRange.location turnOn:NO];
	else 
		[self _drawSelectionRangeNoCaret:_selectedRange];

	_tx.disableDisplay = YES;

	[NSEvent startPeriodicEventsAfterDelay:0.2 withPeriod:0.2];

	while ((type = [event type]) != NSLeftMouseUp && type != NSMouseMoved)				 
		{
		BOOL didScroll;

		if (type == NSPeriodic)
			didScroll = [self autoscroll:lastMovementEvent];
		else
			{
			lastMovementEvent = event;
			didScroll = NO;
			}

		if (type != NSPeriodic || didScroll)
			{
			point = [lastMovementEvent locationInWindow];
			point = [self convertPoint:point fromView:nil];
			proposedRange = _NSAbsoluteRange(
							[self characterIndexForPoint:point], startIndex);
			chosenRange = [self selectionRangeForProposedRange:proposedRange 
								granularity:g];
			}

		if(NSEqualRanges(prevChosenRange, chosenRange) && !didDragging && !didScroll)
			{
			[self _drawRectNoSelection:[self visibleRect]]; // fix bold blur highlight
			[self _drawSelectionRangeNoCaret:chosenRange];
			}
								// this  changes the selection without needing
		if(!didScroll)			// instance drawing (carefully thought out ;-)
			{
			[self _drawSelectionRangeNoCaret:_NSAbsoluteRange( 
					MIN(chosenRange.location, prevChosenRange.location),
					MAX(chosenRange.location, prevChosenRange.location))];
			[self _drawSelectionRangeNoCaret:_NSAbsoluteRange( 
					MIN(NSMaxRange(chosenRange),NSMaxRange(prevChosenRange)),
					MAX(NSMaxRange(chosenRange),NSMaxRange(prevChosenRange)))];
			}
		else
			{
			[self _drawRectNoSelection:[self visibleRect]];
			[self _drawSelectionRangeNoCaret:chosenRange];
			}

		[_window flushWindow];

		didDragging = YES;
		prevChosenRange = chosenRange;

		event = [NSApp nextEventMatchingMask:_NSTrackingLoopMask
					   untilDate:distantFuture 
					   inMode:NSEventTrackingRunLoopMode
					   dequeue:YES];
		}
	[NSEvent stopPeriodicEvents];

	_selectedRange = chosenRange;

	if(!didDragging) 
		[self _drawSelectionRange:chosenRange];
	else 
		if(chosenRange.length == 0)
			[self _drawCaretAtIndex:chosenRange.location turnOn:YES];

	_tx.disableDisplay = NO;
								  // remember for column stable cursor up/down
	_cursorX = [self rectForCharacterIndex:chosenRange.location].origin.x;	
	[self unlockFocus];
	[_window flushWindow];
}

- (void) _displayLineRange:(NSRange)redrawLineRange
{
	BOOL didLock = NO;
	int lc = [_lineLayoutInformation count];
	BOOL terminal_nl = NO;

	if(!_window)
		{
		NSLog(@"NSText _displayLineRange: not in a window\n");	 
		return;
		}

	if([NSView focusView] != self)
		{
		[self lockFocus]; 
		didLock = YES;
		}

	if(lc && !redrawLineRange.length && redrawLineRange.location == lc)
		{
		redrawLineRange.location--;
		redrawLineRange.length++;
		terminal_nl = YES;					// a terminating new line
		}

	if(lc && redrawLineRange.location < lc && redrawLineRange.length)
		{
		_LineLayoutInfo *li;
		NSRect displayRect, firstRect;
		int aMax;

		li = [_lineLayoutInformation objectAtIndex:redrawLineRange.location];
		firstRect = [li lineRect];

		if([li type] == LineLayoutParagraphType
				&& firstRect.origin.x > 0 && redrawLineRange.location)
			{
			redrawLineRange.location--;
			redrawLineRange.length++;
			}

		aMax = MAX(0,(int)NSMaxRange(redrawLineRange)-1);
//		displayRect = NSUnionRect([li lineRect],
if (firstRect.size.width == 0)
firstRect.size.width = 1;
		displayRect = NSUnionRect(firstRect,
					[[_lineLayoutInformation objectAtIndex:aMax] lineRect]);

		if(terminal_nl)
			displayRect = NSUnionRect(displayRect,
					[self rectForCharacterIndex: [self textLength]]);

		displayRect.size.width = _frame.size.width - displayRect.origin.x;
		if(_tx.drawsBackground)
			{
			[_backgroundColor set]; 
			NSRectFill(displayRect);
			}
		else
			[self displayRect:displayRect];

		if(_tx.isRichText)
			[self _drawRichLinesInLineRange:redrawLineRange];
		else
			[self _drawPlainLinesInLineRange:redrawLineRange];

		[self _drawSelectionRange:_selectedRange];
		}

//	if(_tx.drawsBackground)							// clean up the remaining
		{											// area under text of us
		float lowY = 0;
		NSRect iframe = [self frame];
		_LineLayoutInfo *lastObj = [_lineLayoutInformation lastObject];
	
		if((lc = [_lineLayoutInformation count]))	// FIX ME needed ?
			lowY = NSMaxY([lastObj lineRect]);

		if(!lc || (lowY < NSMaxY(iframe) 
				&& iframe.size.height <= [self minSize].height))
			{

		if(_tx.drawsBackground)						// clean up the remaining 
			{
			[_backgroundColor set];
			NSRectFill((NSRect){0,lowY,NSWidth(iframe), NSMaxY(iframe) -lowY});
			}
		else
			[self displayRect:(NSRect){0,lowY,NSWidth(iframe),
									   NSMaxY(iframe) -lowY}];

			if(!lc || [lastObj type] == LineLayoutParagraphType)
				[self _drawSelectionRange:_selectedRange];
		}	}

	if(didLock)
		{
		[self unlockFocus];
		[_window flushWindow];
		}
}
									// central text inserting method.  Handles 
- (void) insertText:(id)insertObj	// optimized redraw / cursor positioning)
{
	NSRange selectedRange = _selectedRange;
	NSRange redrawLineRange;
	int lineIndex = [self lineLayoutIndexForCharacterIndex:selectedRange.location]; 
	int origLineIndex = lineIndex, caretLineIndex = lineIndex;
	BOOL layoutIncomplete = YES;
	NSString *inString = nil;
	int lineCount = [_lineLayoutInformation count];

	if([insertObj isKindOfClass:[NSString class]]) 
		inString = insertObj;
	else											
		inString = [insertObj string];
							// speed optimization: newline insert: try patching 
							// change into layoutArray without actually laying  
							// out the whole document this is a "tour de force" 
							// but performance really counts here!
	if(lineIndex > 2 && [inString isEqualToString: [NSText _newlineString]]
			&& lineIndex < lineCount - 1 && !selectedRange.length)
		{
		_LineLayoutInfo *line = [_lineLayoutInformation objectAtIndex:lineIndex];
		_LineLayoutInfo *next = [_lineLayoutInformation objectAtIndex:lineIndex+1];
		_LineLayoutInfo *prev = [_lineLayoutInformation objectAtIndex:lineIndex-1];
		_LineLayoutInfo *pprev = [_lineLayoutInformation objectAtIndex:lineIndex-2];
		BOOL isLeftToPar = [next type] == LineLayoutParagraphType
						&& [next charRange].location == selectedRange.location;
		BOOL isRightToPar = ([prev type] == LineLayoutParagraphType) 
						&& ([line type] == LineLayoutParagraphType);
		BOOL isLeftToLine = (selectedRange.location ==[line charRange].location
						&& ([prev type] == LineLayoutParagraphType
						&& [pprev type] == LineLayoutParagraphType));

		if(isRightToPar || isLeftToPar || isLeftToLine)
			{
			int insertIndex = lineIndex;
			_LineLayoutInfo *templateInfo = nil, *ni;

			if(!isRightToPar && isLeftToPar)
				{
				templateInfo = next;
				insertIndex++;
				lineIndex += 2;
				}
			else if(isRightToPar)
				{
				templateInfo = line;
				lineIndex++;
				}
			else if(isLeftToLine)
				{
				templateInfo = prev;
				insertIndex--;
				}

			ni = [_LineLayoutInfo lineLayoutWithRange:[templateInfo charRange] 
								   rect:[templateInfo lineRect] 
								   type:[templateInfo type]];
			[_lineLayoutInformation insertObject:ni atIndex:insertIndex];

									// remodel copied paragraph object to be a 
									// normal one (not line-terminating)
			if(!isRightToPar && isLeftToPar)
				{
				_LineLayoutInfo *changeInfo;
				NSRect rect;

				changeInfo = [_lineLayoutInformation objectAtIndex:lineIndex];
				rect = [changeInfo lineRect];

				[changeInfo setLineRect:NSMakeRect(_inset.width,rect.origin.y, 
									[self frame].size.width,rect.size.height)];
				}

			{			// relocate (ylocation  and linerange) the lines below
			NSRange r = {lineIndex,[_lineLayoutInformation count] - lineIndex};
			NSArray *relocArray = [_lineLayoutInformation subarrayWithRange:r];
			NSEnumerator *relocEnum = [relocArray objectEnumerator];
			_LineLayoutInfo *currReloc;
			int	relocOffset = [inString length];
			NSDictionary *a = _tx.isRichText ? [self typingAttributes]
											 : [self defaultTypingAttributes];
			NSSize advance = [inString sizeWithAttributes: a];

			for(;(currReloc = [relocEnum nextObject]);)
				{
				NSRange range = [currReloc charRange];
				NSRect rect = [currReloc lineRect];
				NSRange aRange = {range.location + relocOffset, range.length};
				NSPoint p = {NSMinX(rect), NSMinY(rect) + advance.height};

				[currReloc setCharRange: aRange];
				[currReloc setLineRect: (NSRect){p,rect.size}];
			}	}

		layoutIncomplete = NO;
	}	}										// end: speed optimization

			// in case e.g a space is inserted and a word actually shortened:
			// redraw previous line to give it the chance to move up 
	if(lineCount && [(_LineLayoutInfo *)[_lineLayoutInformation objectAtIndex:origLineIndex] type] 
			!= LineLayoutParagraphType && origLineIndex 
			&& [(_LineLayoutInfo *)[_lineLayoutInformation objectAtIndex:origLineIndex-1] type] 
			!= LineLayoutParagraphType)
		origLineIndex--;

	redrawLineRange = _NSAbsoluteRange(origLineIndex, lineCount);

	if(_tx.isRichText)
		{
		NSDictionary *attributes; 
		NSAttributedString *a;

		attributes = [rtfContent attributesAtIndex:_selectedRange.location 
								 effectiveRange:NULL];

		if([insertObj isKindOfClass:[NSAttributedString class]])
			a = insertObj;
		else
			a = [[[NSAttributedString alloc] initWithString:inString 
							attributes:[self typingAttributes]] autorelease];

		[self replaceRange:_selectedRange withAttributedString:a];

		if(layoutIncomplete)
			redrawLineRange.length = [self _rebuildRTFLineLayoutFromLine:redrawLineRange.location delta:[inString length] - selectedRange.length actualLine:caretLineIndex];
		[self setTypingAttributes:attributes];
		} 
	else
		{
		if (lineCount)
			[self replaceRange:_selectedRange withString:inString];
		else
			ASSIGN(plainContent,[NSMutableString stringWithString:inString]);

		if(layoutIncomplete)
			redrawLineRange.length = [self _rebuildPlainLineLayoutFromLine: redrawLineRange.location delta:[inString length] - selectedRange.length actualLine:caretLineIndex];
		}

	[self sizeToFit];								// ScrollView interaction

	[self setSelectedRange:NSMakeRange(_selectedRange.location + [inString length],0)];	
				// move cursor FIX ME [self selectionRangeForProposedRange:]
				// remember x for row-stable cursor movements
	_cursorX = [self rectForCharacterIndex:_selectedRange.location].origin.x;

	redrawLineRange = NSIntersectionRange(redrawLineRange, 
							[self lineRangeForRect:[self visibleRect]]);
	[self _displayLineRange:redrawLineRange];
	[NSNotificationCenter post:NOTE(DidChange) object:self];
}

- (void) deleteRange:(NSRange)aRange backspace:(BOOL)flag
{
	int redrawLineIndex, caretLineIndex, firstLineIndex, lastLineIndex;
	int linePosition, lineLayoutCount, maxDeleteRange;
	NSRange	redrawLineRange;
	NSRange deleteRange;					// central text deletion/backspace 
	BOOL layoutIncomplete = YES;			// method (takes care of optimized
										// redraw / cursor positioning)
	if(!aRange.length && (!flag || !aRange.location)) 
		return;

	if(aRange.length) 
		{
		deleteRange = aRange;
		linePosition = deleteRange.location;
		maxDeleteRange = NSMaxRange(deleteRange);
		}
	else			  
		{
		deleteRange = NSMakeRange( MAX(0,aRange.location-1), 1);
		maxDeleteRange = linePosition = NSMaxRange(deleteRange); 
		}

	if(_tx.fieldEditor && flag) 
		{
		NSRect start = [self rectForCharacterIndex: deleteRange.location];
		NSRect endCharRect = [self rectForCharacterIndex: maxDeleteRange];

		[self lockFocus];
		[_backgroundColor set]; 
		NSRectFill(NSUnionRect(start, endCharRect));
		[_window flushWindow];
		[self unlockFocus];
		}

	firstLineIndex = [self lineLayoutIndexForCharacterIndex: linePosition];
	caretLineIndex = firstLineIndex;
	lastLineIndex = [self lineLayoutIndexForCharacterIndex: maxDeleteRange];
	redrawLineIndex = MAX(0,firstLineIndex - 1);		// since first word may 
														// move upward
	if(firstLineIndex && [(_LineLayoutInfo *)[_lineLayoutInformation objectAtIndex:
			firstLineIndex - 1] type] == LineLayoutParagraphType)
		{
		_LineLayoutInfo *upperInfo = [_lineLayoutInformation objectAtIndex: 
											firstLineIndex];
		_LineLayoutInfo *prevInfo = [_lineLayoutInformation objectAtIndex: 
											firstLineIndex - 1];

		if(linePosition > [upperInfo charRange].location)		 
			redrawLineIndex++;					// no danger of word moving up
		else 
			if([prevInfo lineRect].origin.x > 0)				 
				redrawLineIndex--;			// remove newline: skip 
											// paragraph-terminating infoObject
		redrawLineIndex = MAX(0, redrawLineIndex);
		}

	lineLayoutCount = [_lineLayoutInformation count];
	redrawLineIndex = MIN(redrawLineIndex, lineLayoutCount - 1);
	redrawLineRange = _NSAbsoluteRange(redrawLineIndex, lineLayoutCount);

	if(_tx.isRichText)
		{
		NSDictionary *attributes = [rtfContent attributesAtIndex: 
									deleteRange.location effectiveRange:NULL]; 

		[rtfContent deleteCharactersInRange:deleteRange];
		if(layoutIncomplete)
			redrawLineRange.length = [self _rebuildRTFLineLayoutFromLine:redrawLineRange.location delta:-deleteRange.length actualLine:caretLineIndex];
		[self setTypingAttributes:attributes];
		} 
	else
		{
		[plainContent deleteCharactersInRange:deleteRange];
		if(layoutIncomplete)
			redrawLineRange.length = [self _rebuildPlainLineLayoutFromLine:redrawLineRange.location delta: -deleteRange.length actualLine:caretLineIndex];
		}

	[self sizeToFit];			// ScrollView interaction

	[self setSelectedRange:NSMakeRange(deleteRange.location,0)];	
		// move cursor <!> [self selectionRangeForProposedRange:]
		// remember x for row-stable cursor movements
	_cursorX = [self rectForCharacterIndex:_selectedRange.location].origin.x;

	redrawLineRange = NSIntersectionRange(redrawLineRange, 
						[self lineRangeForRect:[self visibleRect]]);
	[self _displayLineRange:redrawLineRange];

	[NSNotificationCenter post:NOTE(DidChange) object:self];
}

- (BOOL) readSelectionFromPasteboard:(NSPasteboard*)pb
{
	NSArray *types = [pb types];
	NSString *string;
	NSRange range;

	if ([types containsObject: NSStringPboardType] == NO)
		return NO;

	string = [pb stringForType: NSStringPboardType];
	range = _selectedRange;
	[self deleteRange: range backspace: NO];
	[self insertText: string];
	range.length = [string length];
	[self setSelectedRange: range];
	
	return YES;
}

- (BOOL) writeSelectionToPasteboard:(NSPasteboard*)pb
							  types:(NSArray*)sendTypes
{
	NSArray *types;
	NSRange range;
	NSString *string;

	if ([sendTypes containsObject: NSStringPboardType] == NO)
		return NO;

	types = [NSArray arrayWithObjects: NSStringPboardType, nil];
	[pb declareTypes: types owner: nil];
	range = _selectedRange;
	string = [self string];
	string = [string substringWithRange: range];
	
	return [pb setString: string forType: NSStringPboardType];
}
					// FIX ME handle font and handle ruler pasteboard as well!
- (BOOL) performPasteOperation:(NSPasteboard *)pboard
{
	NSArray *pbArray = [NSArray arrayWithObject:NSColorPboardType];

	if([pboard availableTypeFromArray:pbArray])				// color accepting
		{
		NSColor	*color = [NSColor colorFromPasteboard:pboard];

		if(_tx.isRichText)
			[self setTextColor:color range:_selectedRange];
		else 
			[self setTextColor:color];

		return YES;
		}

	if([self importsGraphics])
		{
		NSArray *types = [NSArray arrayWithObjects:NSFileContentsPboardType, 
									NSRTFDPboardType, NSRTFPboardType, 
									NSStringPboardType, NSTIFFPboardType, nil];
		NSString *typeString = [pboard availableTypeFromArray:types];

		if([typeString isEqualToString:NSRTFDPboardType])
			{
			NSData *data = [pboard dataForType:NSRTFDPboardType];
			[self insertText:[[self class] attributedStringForData:data]];
			} 
		else 
			if([typeString isEqualToString:NSRTFPboardType])
				{
				NSData *data = [pboard dataForType:NSRTFPboardType];
				[self insertText:[[self class] attributedStringForData:data]];
				} 
			else 
				if([typeString isEqualToString:NSStringPboardType])
					{
					NSString *type = [pboard stringForType:NSStringPboardType];
					[self insertText:type];
					return YES;
		}			}
	else 
		if(_tx.isRichText)
			{
			NSArray *types = [NSArray arrayWithObjects:NSRTFPboardType, 
													   NSStringPboardType,nil];
			NSString *typeString = [pboard availableTypeFromArray:types];

			if([typeString isEqualToString:NSRTFPboardType])
				{
				NSData *data = [pboard dataForType:NSRTFPboardType];
				[self insertText:[[self class] attributedStringForData:data]];
				} 
			else 
				if([typeString isEqualToString:NSStringPboardType])
					{
					NSString *type = [pboard stringForType:NSStringPboardType];
					[self insertText:type];
					return YES;
			}		}
		else													// plain text
			{
			NSArray *types = [NSArray arrayWithObjects:NSStringPboardType,nil];
			NSString *typeString = [pboard availableTypeFromArray:types];

			if([typeString isEqualToString:NSStringPboardType])
				{
				[self insertText:[pboard stringForType:NSStringPboardType]];
				return YES;
			}	}

	return NO;
}

- (NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender		// Dragging
{
	return NSDragOperationGeneric;
}

- (NSDragOperation) draggingUpdated:(id <NSDraggingInfo>)sender
{
	return NSDragOperationGeneric;
}

- (void) draggingExited:(id <NSDraggingInfo>)sender
{
}

- (BOOL) prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	return YES;
}

- (BOOL) performDragOperation:(id <NSDraggingInfo>)sender
{
	return [self performPasteOperation:[sender draggingPasteboard]];
}

- (void) concludeDragOperation:(id <NSDraggingInfo>)sender
{
	[_window endEditingFor:self];
}

- (NSArray*) acceptableDragTypes
{
	NSMutableArray *r = [NSMutableArray arrayWithObjects:NSStringPboardType,
													   NSColorPboardType, nil];
	if(_tx.isRichText)			
		[r addObject:NSRTFPboardType];
	if([self importsGraphics])		
		[r addObject:NSRTFDPboardType];

	return r;
}

- (void) updateDragTypeRegistration
{
	[self registerForDraggedTypes:[self acceptableDragTypes]];
}

- (void) keyDown:(NSEvent *)event
{
	unsigned short keyCode;
	NSString *cs;

	if(!_tx.editable) 
		return;

	DBLog(@" NSText keyDown ");

	if((keyCode = [event keyCode]))
		{
		DBLog(@"keycode:%x", keyCode);

		switch(keyCode)
			{
			case NSUpArrowFunctionKey:
				[self _moveCursorUp:self];
				return;
			case NSDownArrowFunctionKey:
				[self _moveCursorDown:self];
				return;
			case NSLeftArrowFunctionKey:
				[self _moveCursorLeft:self];
				return;
			case NSRightArrowFunctionKey:
				[self _moveCursorRight:self];
				return;
			case NSBackspaceKey:
				[self deleteRange:_selectedRange backspace:YES];
				return;

			case 0x6d:	// ende-taste för debugging: enforce complete re-layout
				NSLog(@" NSText complete re-layout ");
				[_lineLayoutInformation autorelease]; 
				_lineLayoutInformation = nil;
				[self _rebuildLineLayoutFromLine:0];
				[self display];
				return;

			case 0x45:	// num-lock: debugging
				NSLog(@"%@", [_lineLayoutInformation description]);
				return;

			case 0x09:									// Tab
				if([self isFieldEditor])
					{
					__escapeKey = (([event modifierFlags] & NSShiftKeyMask))
								? NSBacktabTextMovement : NSTabTextMovement;
					[self resignFirstResponder];
					return;
					}
				break;

			case NSCarriageReturnKey:
				DBLog(@" NSText return keyDown \n");		
				if([self isFieldEditor])
					{
					__escapeKey = NSReturnTextMovement;
					[self resignFirstResponder];
					} 
				else
					[self insertText: [NSText _newlineString]];
				return;
		}	}

	if ((cs = [event characters]) && [cs length])
		{
		[self insertText:cs];
		[_window flushWindow];
		}
}

- (void) keyUp:(NSEvent *)event					{ }	// NSResponder overrides

- (BOOL) resignFirstResponder						// NSResponder overrides
{
	NSNotification *n;
	NSDictionary *d;
	NSNumber *key;

	if (![self isEditable] || !_tx.isFirstResponder)
		return YES;

	if (__caretBlinkTimer && !_selectedRange.length && ![_window isKeyWindow])
		[self _stopCaretBlinkTimer];

	if ([_delegate respondsToSelector:@selector(textShouldEndEditing:)]
			&& ![_delegate textShouldEndEditing:(NSText*)self])
		return NO;

	if (__caretBlinkTimer && [self shouldDrawInsertionPoint])
		[self _stopCaretBlinkTimer];

	key = [NSNumber numberWithInt:__escapeKey];
	__escapeKey = NSIllegalTextMovement;			// reset to default values
	_tx.secure = _tx.isFirstResponder = NO;
	d = [NSDictionary dictionaryWithObjectsAndKeys: key, NSTextMovement, nil];
	n = [NSNotification notificationWithName:NOTE(DidEndEditing)
									  object:self
									  userInfo:d];
	[[NSNotificationCenter defaultCenter] postNotification:n];

	return YES;
}

- (BOOL) acceptsFirstResponder					{ return _tx.selectable; }
- (BOOL) acceptsFirstMouse:(NSEvent *)event		{ return _tx.fieldEditor; }

- (BOOL) becomeFirstResponder
{
	if (![self isEditable])
		return NO;

	if ([_delegate respondsToSelector:@selector(textShouldBeginEditing:)]
			&& ![_delegate textShouldBeginEditing:(NSText*)self])
		return NO;

	if (__caretBlinkTimer)
		[self _stopCaretBlinkTimer];
	if (_selectedRange.length == 0)
		[self _startCaretBlinkTimer];
	_tx.isFirstResponder = YES;

	return YES;
}

- (NSRange) characterRangeForBoundingRect:(NSRect)bounds
{
	unsigned int length = (_tx.isRichText) ? [rtfContent length]
										   : [plainContent length];
	return NSMakeRange(0, length);						// FIX ME broken
}

- (NSUInteger) characterIndexForPoint:(NSPoint)point
{
	NSEnumerator *lineEnum;
	NSDictionary *attributes;
	_LineLayoutInfo *currentInfo;

	if(point.y >= NSMaxY([[_lineLayoutInformation lastObject] lineRect])) 
		return [self textLength];

	point.x = MAX(_inset.width, point.x); 
	point.y = MAX(0, point.y);

	attributes = [self defaultTypingAttributes];
	lineEnum = [_lineLayoutInformation objectEnumerator];
	for(;(currentInfo = [lineEnum nextObject]);)
		{
		NSRect rect = [currentInfo lineRect];

		if(NSMaxY(rect) >= point.y && rect.origin.y < point.y 
				&& rect.origin.x < point.x && point.x >= NSMaxX(rect)) 
			return NSMaxRange([currentInfo charRange]);

		if(NSPointInRect(point, rect))
			{
			NSRange range = [currentInfo charRange];
			int p, m = NSMaxRange(range);

			for(p = range.location; p <= m; p++)		
				{								// loop holds some optimization
				if(_tx.isRichText)				// potential (linear search)
					{							// must be done char wise
					NSRange r = {range.location, p - range.location};

					if([rtfContent sizeRange: r].width >= point.x) 
						return MAX(0, p - 1);
					} 
				else
					{
					NSRange r = {range.location, p - range.location};
					NSString *s = [plainContent substringWithRange: r];		
					float w = [s sizeWithAttributes:attributes].width;

					if(w >= point.x)
						return MAX(0, p - 1);
				}	}

			return range.location;
		}	}

	NSLog(@"NSText characterIndexForPoint: index not found!");

	return NSNotFound;
}

- (NSRect) rectForCharacterIndex:(NSUInteger)index
{													// rect to the end of line
	NSEnumerator *lineEnum;
	NSDictionary *attributes = [self defaultTypingAttributes];
	_LineLayoutInfo *ly;

	if (![_lineLayoutInformation count])
		{
		NSString *s = [NSText _newlineString];		// empty text object

		return NSMakeRect(_inset.width, 0, _frame.size.width, 
						  [s sizeWithAttributes:attributes].height);
		}

	ly = [_lineLayoutInformation lastObject];
	if (index >= NSMaxRange([ly charRange]))
		{
		NSRect rect = [ly lineRect];

		if (_tx.secure)
			{
			NSSize sz = [@"*" sizeWithAttributes:attributes];
			float x = rect.origin.x + (sz.width * [ly charRange].length);

			return (NSRect){x,NSMinY(rect),NSMaxX(rect)-x,NSHeight(rect)};
			}

		if ([ly type] == LineLayoutParagraphType)
			return NSMakeRect(_inset.width, NSMaxY(rect), _frame.size.width, 
								rect.size.height);

		return NSMakeRect(NSMaxX(rect), rect.origin.y, 
						 _frame.size.width - NSMaxX(rect), rect.size.height);
		}

	lineEnum = [_lineLayoutInformation objectEnumerator];
	while ((ly = [lineEnum nextObject]))
		{
		NSRange	range = [ly charRange];

		if (NSLocationInRange(index, range))
			{
			NSRect rect = [ly lineRect];

			if (_tx.secure)
				{
				NSRange r = _NSAbsoluteRange(range.location, index);	
				NSSize stringSize = [@"*" sizeWithAttributes:attributes];
				float x = rect.origin.x + (stringSize.width * r.length);

				return (NSRect){x,NSMinY(rect),NSMaxX(rect)-x,NSHeight(rect)};
				}
			if (_tx.isRichText)					// must be done char wise
				{
				NSRange r = _NSAbsoluteRange(range.location, index);	
				NSSize stringSize = [rtfContent sizeRange:r];
				float x = rect.origin.x + stringSize.width;

				return (NSRect){x,NSMinY(rect),NSMaxX(rect)-x,NSHeight(rect)};
				} 
			else
				{
				NSRange r = _NSAbsoluteRange(range.location, index);	
				NSString *s = [plainContent substringWithRange:r];
				NSSize stringSize = [s sizeWithAttributes:attributes];
				float x = rect.origin.x + stringSize.width;

				return (NSRect){x,NSMinY(rect),NSMaxX(rect)-x,NSHeight(rect)};
		}	}	}

	NSLog(@"NSText rectForCharacterIndex: rect not found!");

	return NSZeroRect;
}

- (unsigned) lineLayoutIndexForPoint:(NSPoint)point
{
	NSEnumerator *lineEnum;
	_LineLayoutInfo *currentInfo;
	NSDictionary *attributes;
	int lineLayoutCount;

	if(!(lineLayoutCount = [_lineLayoutInformation count])) 
		return 0;
	if(point.y >= NSMaxY([[_lineLayoutInformation lastObject] lineRect])) 
		return lineLayoutCount - 1;

	point.x = MAX(_inset.width, point.x); 
	point.y = MAX(0, point.y);

	attributes = [self defaultTypingAttributes];
	lineEnum = [_lineLayoutInformation objectEnumerator];
	while ((currentInfo = [lineEnum nextObject]))
		{
		NSRect rect = [currentInfo lineRect];
//	fprintf(stderr, ": rect (%1.2f, %1.2f), (%1.2f, %1.2f)\n",
//				rect.origin.x, rect.origin.y,
//				rect.size.width, rect.size.height);

		if(NSMaxY(rect) > point.y && rect.origin.y <= point.y 
				&& rect.origin.x < point.x && point.x >= NSMaxX(rect) )
			return [_lineLayoutInformation indexOfObject:currentInfo];

		if(NSMinY(rect) > point.y)
			break;

		if(NSPointInRect(point,rect))	// this loop holds some optimization 
			{							// potential (linear search)
			NSRange range = [currentInfo charRange];
			int p;

			for(p = range.location; p <= NSMaxRange(range); p++)		
				{						// FIX ME optimization potential?
				if(_tx.isRichText)		// must be done character wise
					{
					NSRange a = {range.location, p - range.location};

					if([rtfContent sizeRange:a].width >= point.x)
					 return [_lineLayoutInformation indexOfObject:currentInfo];
					} 
				else
					{
					NSRange a = {range.location, p - range.location};
					NSString *s = [plainContent substringWithRange: a];

					if([s sizeWithAttributes:attributes].width >= point.x) 
					 return [_lineLayoutInformation indexOfObject:currentInfo];
				}	}

			return [_lineLayoutInformation indexOfObject:currentInfo];
		}	}

	NSLog(@"NSText's lineLayoutIndexForPoint == 0");

	return 0;
}

- (void) _addNewlines:(NSRange) aRange 						// internal method
		 intoLayoutArray:(NSMutableArray*) anArray 
		 attributes:(NSDictionary*) attributes 
		 atPoint:(NSPoint*) p
		 width:(float) width 
		 characterIndex:(unsigned) startingLineCharIndex 
		 ghostEnumerator:(NSEnumerator*) prevArrayEnum
		 didShift:(BOOL*) didShift 
		 verticalDisplacement:(float*) verticalDisplacement
{
	NSSize advance = [[NSText _newlineString] sizeWithAttributes:attributes];
	int count = aRange.length, charIndex;
	_LineLayoutInfo *ghostInfo = nil;

	(*didShift) = NO;

	for(charIndex = aRange.location; --count >= 0; charIndex++)
		{
		NSRect currentLineRect = {p->x, p->y, width - p->x, advance.height};
		NSRange r = {startingLineCharIndex,1};

		[anArray addObject:[_LineLayoutInfo lineLayoutWithRange: r 
											 rect: currentLineRect
											 type: LineLayoutParagraphType]];
		if(_tx.isRichText)
			advance = [rtfContent sizeRange:NSMakeRange(charIndex,1)];

		startingLineCharIndex++;
		p->x = _inset.width;
		p->y += advance.height;

		if(prevArrayEnum && !(ghostInfo = [prevArrayEnum nextObject])) 
			prevArrayEnum = nil;

		if(ghostInfo && (LineLayoutParagraphType != [ghostInfo type]))
			{
			_LineLayoutInfo *prevInfo = [prevArrayEnum previousObject];

			prevArrayEnum = nil;
			ghostInfo = nil;
			(*didShift) = YES;
			(*verticalDisplacement) += p->y - [prevInfo lineRect].origin.y;
		}	}
}

static unsigned 
_RelocateLayoutArray( NSMutableArray *lineLayoutInformation,
					  NSArray *ghostArray,
					  int aLine,
					  int relocOffset,
					  int rebuildLineDrift,
					  float yReloc )
{							  	// lines actually updated (optimized drawing)
	unsigned ret = [lineLayoutInformation count] - aLine;
	NSRange r = _NSAbsoluteRange(MAX(0,ret+rebuildLineDrift),[ghostArray count]);
	NSArray *relocArray = [ghostArray subarrayWithRange: r];
	NSEnumerator *relocEnum;
	_LineLayoutInfo *currReloc;

	if(![relocArray count]) 
		return ret;

	for(relocEnum = [relocArray objectEnumerator]; 
			(currReloc = [relocEnum nextObject]);)
		{
		NSRange range = [currReloc charRange];
		NSRange aRange = {range.location + relocOffset, range.length};

		[currReloc setCharRange:aRange];
		if(yReloc)
			{
			NSRect rect = [currReloc lineRect];

			NSMinY(rect) += yReloc;
			[currReloc setLineRect:rect];
		}	}

	[lineLayoutInformation addObjectsFromArray:relocArray];

	return ret;
}
				// returns count of lines actually updated, only implemented 
				// for [self isVerticallyResizable] (but i think this is ok)  
				// FIX ME detachNewThreadSelector:selector
- (int) _rebuildPlainLineLayoutFromLine:(int)aLine 
								  delta:(int)insertionDelta 
							 actualLine:(int)insertionLineIndex
{
	NSDictionary *attributes = [self defaultTypingAttributes];
	NSPoint drawingPoint = {_inset.width, 0};
	NSScanner *parscanner;
	unsigned startingIndex = 0, currentLineIndex;
	_LineLayoutInfo *lastValidLineInfo = nil;
	NSArray *ghostArray = nil;						// for optimization detection
	NSEnumerator *prevArrayEnum = nil;
	NSCharacterSet *invSelectionWordGranularitySet = 
						[selectionWordGranularitySet invertedSet];
	NSCharacterSet *invSelectionParagraphGranularitySet = 
						[selectionParagraphGranularitySet invertedSet];
	NSString *parsedString;
	int lineDriftOffset = 0, rebuildLineDrift = 0;
	BOOL frameshiftCorrection = NO, nlDidShift = NO, enforceOpti = NO;
	float yDisplacement = 0;

	if(!_lineLayoutInformation)
		{
		if (![plainContent length])
			return 0;

		_lineLayoutInformation = [[NSMutableArray alloc] init];
		}
	else
		{				// remember old array for optimization purposes
		NSRange r = NSMakeRange(aLine,[_lineLayoutInformation count] - aLine);
		ghostArray = [_lineLayoutInformation subarrayWithRange: r];	

		prevArrayEnum = [ghostArray objectEnumerator];	
		}				// every time an obj is added to lineLayoutInformation
						// a nextObject has to be performed on prevArrayEnum!
	if(aLine)
		{
		lastValidLineInfo = [_lineLayoutInformation objectAtIndex: aLine-1];
		drawingPoint = [lastValidLineInfo lineRect].origin;
		drawingPoint.y += [lastValidLineInfo lineRect].size.height;
		startingIndex = NSMaxRange([lastValidLineInfo charRange]);
		}

	if([lastValidLineInfo type] == LineLayoutParagraphType)
		drawingPoint.x = _inset.width;

	if((((int)[_lineLayoutInformation count])-1) >= aLine)	
		{		// keep paragraph-terminating space on same line as paragraph
		NSRect anchor = [[_lineLayoutInformation objectAtIndex:aLine]lineRect];

		if(anchor.origin.x > drawingPoint.x 
			  && [lastValidLineInfo lineRect].origin.y == anchor.origin.y)
			drawingPoint = anchor.origin;
		}

	[_lineLayoutInformation removeObjectsInRange: NSMakeRange(aLine, 
									[_lineLayoutInformation count] - aLine)];
	currentLineIndex = aLine;
															// each paragraph
	parsedString = [plainContent substringFromIndex:startingIndex];
	parscanner = [NSScanner _scannerWithString: parsedString
							set: selectionParagraphGranularitySet 
							invertedSet:invSelectionParagraphGranularitySet];
	for(;![parscanner _isAtEnd];)
		{
		NSScanner *linescanner;
		NSString *paragraph;
		NSRange paragraphRange, leadingNlRange, trailingNlRange;
		unsigned startingParagraphIndex, startingLineCharIndex;
		BOOL isBuckled = NO, inBuckling = NO;

		startingParagraphIndex = [parscanner scanLocation] + startingIndex;
		startingLineCharIndex = startingParagraphIndex;
		leadingNlRange = [parscanner _scanSetCharacters];

		if(leadingNlRange.length)		// add the leading newlines of current 
			{							// paragraph if any (only first time)
			[self _addNewlines:leadingNlRange 
				  intoLayoutArray:_lineLayoutInformation 
				  attributes:attributes 
				  atPoint:&drawingPoint 
				  width:NSWidth(_frame)
				  characterIndex:startingLineCharIndex 
				  ghostEnumerator:prevArrayEnum
				  didShift:&nlDidShift 
				  verticalDisplacement:&yDisplacement];

			if(nlDidShift)
				{
				if(insertionDelta == 1)
					{
					frameshiftCorrection = YES;
					rebuildLineDrift--;
					} 
				else 
					if(insertionDelta == -1)
						{
						frameshiftCorrection = YES;
						rebuildLineDrift++;
						} 
					else 
						nlDidShift = NO;
				}

			startingLineCharIndex += leadingNlRange.length; 
			currentLineIndex += leadingNlRange.length;
			}

		paragraphRange = [parscanner _scanNonSetCharacters];
		trailingNlRange = [parscanner _scanSetCharacters];		// each line
		paragraph = [parsedString substringWithRange:paragraphRange];
		linescanner = [NSScanner _scannerWithString:paragraph
								set:selectionWordGranularitySet 
								invertedSet:invSelectionWordGranularitySet];
		for (;![linescanner _isAtEnd];)
			{
			NSRect currentLineRect = {{_inset.width, drawingPoint.y},{0,0}};
			NSSize adv = NSZeroSize;
				// starts with zero, do not confuse with startingLineCharIndex
			unsigned localLineStartIndex = [linescanner scanLocation];		

							// scan the individual words to the end of the line
			for(;![linescanner _isAtEnd]; drawingPoint.x += adv.width)
				{
				NSRange	currentStringRange;
				NSRange trailingSpacesRange, leadingSpacesRange;
				unsigned scannerPosition = [linescanner scanLocation];

															// snack next word
											// leading spaces: only first time
				leadingSpacesRange = [linescanner _scanSetCharacters];	
				currentStringRange = [linescanner _scanNonSetCharacters];
				trailingSpacesRange = [linescanner _scanSetCharacters];
				if (leadingSpacesRange.length) 
					currentStringRange = NSUnionRange (leadingSpacesRange, 
											currentStringRange);
				if(trailingSpacesRange.length) 
					currentStringRange = NSUnionRange(trailingSpacesRange, 
											currentStringRange);
	
												// evaluate size of current 
				if(_tx.isRichText)				// word and line so far
					adv = [rtfContent sizeRange: 
						NSMakeRange(currentStringRange.location + 
						startingLineCharIndex, currentStringRange.length)];
				else
					{
					NSString *s;

					s = [paragraph substringWithRange: currentStringRange];
					adv = [s sizeWithAttributes:attributes];
					}

				currentLineRect = NSUnionRect(currentLineRect, 
									(NSRect){drawingPoint, adv});

								// handle case where single word is broader 
								// than width (buckle word) FIX ME unfinished
				if(!_tx.horzResizable && adv.width >= NSWidth(_frame))
					{
					if(isBuckled)
						{
						NSSize currentSize = NSMakeSize(HUGE,0);
						unsigned lastVisibleCharIndex = startingLineCharIndex 
												+ currentStringRange.length;

						for(; currentSize.width >= NSWidth(_frame) 
							   && lastVisibleCharIndex > startingLineCharIndex; 
								lastVisibleCharIndex--)
							{
							NSRange r = _NSAbsoluteRange(
								startingLineCharIndex, lastVisibleCharIndex);

							if(_tx.isRichText)
								currentSize = [rtfContent sizeRange:r];
							else
								{
								NSString *e;

								e = [plainContent substringWithRange:r];
								currentSize =[e sizeWithAttributes:attributes];
							}	}
						isBuckled = NO; 
						inBuckling = YES;
						scannerPosition = localLineStartIndex + 
								(lastVisibleCharIndex - startingLineCharIndex);
						NSWidth(currentLineRect) = adv.width = NSWidth(_frame);
						} 
					else			// undo layout of extralarge word for now
						{
						isBuckled = YES;
						currentLineRect.size.width -= adv.width;
					}	}
													// end of line-> word wrap
				if(!_tx.horzResizable
						&& (NSWidth(currentLineRect) >= NSWidth(_frame)
							|| isBuckled))
					{
					_LineLayoutInfo *ghostInfo = nil, *thisInfo;
					NSRange r;
													// undo layout of last word
					[linescanner _setScanLocation:scannerPosition];	

					currentLineRect.origin.x = _inset.width; 
					currentLineRect.origin.y = drawingPoint.y;
					drawingPoint.y += currentLineRect.size.height; 
					drawingPoint.x = _inset.width;

					r = NSMakeRange(startingLineCharIndex,
									scannerPosition - localLineStartIndex);
					thisInfo = [_LineLayoutInfo lineLayoutWithRange: r
												 rect: currentLineRect 
												 type: LineLayoutTextType];
					[_lineLayoutInformation addObject:thisInfo];

					currentLineIndex++;
					startingLineCharIndex = NSMaxRange([thisInfo charRange]);

					ghostInfo = [prevArrayEnum nextObject];
					if(prevArrayEnum && !ghostInfo) 
						prevArrayEnum = nil;
									// optimization, (relayout only as many 
					if(ghostInfo)	// lines as necessary and patch the rest)
						{					
						if([ghostInfo type] != [thisInfo type])	
							{					  	 	// frameshift correction
							frameshiftCorrection = YES;
							if(insertionDelta == -1)	// deletition of newline
								{
								_LineLayoutInfo *nextObject;

								if(!(nextObject = [prevArrayEnum nextObject])) 
									prevArrayEnum = nil;
								else
									{
									if(nlDidShift && frameshiftCorrection)
										{		//	frameshiftCorrection = NO;
										} 
									else
										{
										lineDriftOffset += 
												([thisInfo charRange].length 
												- [ghostInfo charRange].length 
											  - [nextObject charRange].length);
										yDisplacement += 
												[thisInfo lineRect].origin.y 
											  - [nextObject lineRect].origin.y;
										rebuildLineDrift++;
							}	}	}	}
						else 
							lineDriftOffset += ([thisInfo charRange].length 
											- [ghostInfo charRange].length);

							// is it possible to simply patch layout changes 
							// into layout array instead of doing a time 
							// consuming re-layout of the whole doc?
						if((currentLineIndex-1 > insertionLineIndex 
								&& !inBuckling && !isBuckled) 
								&& (!(lineDriftOffset-insertionDelta) 
								|| (nlDidShift && !lineDriftOffset) 
								|| enforceOpti))
							{
							unsigned erg = _RelocateLayoutArray( 
											_lineLayoutInformation, ghostArray, 
											aLine, insertionDelta, 
											rebuildLineDrift, yDisplacement);
							// if y displacement: redisplay all remaining lines
							if(frameshiftCorrection) 
								erg = [_lineLayoutInformation count] - aLine;	
							else 
								if(currentLineIndex-1 == insertionLineIndex 
										&& ABS(insertionDelta) == 1)
									erg = 2;	// return 2: redisplay only 
												// this and previous line
							return erg;
						}	}							// end: optimization
				break;			// newline-induced premature lineending: flush
				} 
			else 
				if([linescanner _isAtEnd])
					{
					_LineLayoutInfo *thisInfo;
					NSRange r = {startingLineCharIndex, 0};
					float mw;

					if(!_tx.isRichText)
						{
						mw = [paragraph sizeWithAttributes:attributes].width;
							// calc of line width by word can lead to erroneous
							// value if tabs are involved correct for this
						if(mw < NSWidth(_frame))
							NSWidth(currentLineRect) = mw;
						}

					scannerPosition = [linescanner scanLocation];
					r.length = scannerPosition - localLineStartIndex;
					currentLineRect.origin.x = _inset.width;
if (_tx.fieldEditor)
currentLineRect.origin.y = _inset.height;
					thisInfo = [_LineLayoutInfo lineLayoutWithRange: r
												 rect: currentLineRect 
												 type: LineLayoutTextType];
					[_lineLayoutInformation addObject:thisInfo];
					currentLineIndex++;
					startingLineCharIndex = NSMaxRange([thisInfo charRange]);

							// check for optimization (lines after paragraph 
							// are unchanged and do not need redisplay/relayout
					if(prevArrayEnum)
						{
						_LineLayoutInfo *ghostInfo;

						if((ghostInfo = [prevArrayEnum nextObject]))
							{
							if([ghostInfo type] != [thisInfo type])	
								{	// frameshift correction for inserted nl
								frameshiftCorrection = YES;

								if(insertionDelta == 1)
									{
									[prevArrayEnum previousObject];
									lineDriftOffset += ([thisInfo charRange].length
												- [ghostInfo charRange].length) 
												+ insertionDelta;
									rebuildLineDrift--;
									yDisplacement += [thisInfo lineRect].origin.y
											   - [ghostInfo lineRect].origin.y;
									} 
								else 
									if(insertionDelta == -1)
										{
										if(nlDidShift && frameshiftCorrection)
											{	//	frameshiftCorrection = NO;
								}		}	}										
							else 
								lineDriftOffset += ([thisInfo charRange].length 
											- [ghostInfo charRange].length);
							} 
						else 	// new array obviously longer than previous one
							prevArrayEnum = nil;
			}	}	}									// end: optimization
		drawingPoint.x = NSMaxX(currentLineRect);
		}

		if(trailingNlRange.length)			// add the trailing newlines of 
			{								// current paragraph if any
			if(drawingPoint.x > NSWidth(_frame))
				drawingPoint.x = _inset.width;

			[self _addNewlines:trailingNlRange 
				  intoLayoutArray:_lineLayoutInformation 
				  attributes:attributes 
				  atPoint:&drawingPoint 
				  width:NSWidth(_frame)
				  characterIndex:startingLineCharIndex 
				  ghostEnumerator:prevArrayEnum
				  didShift:&nlDidShift 
				  verticalDisplacement:&yDisplacement];

			if(nlDidShift)
				{
				if(insertionDelta == 1)
					{
					frameshiftCorrection = YES;
					rebuildLineDrift--;
					} 
				else 
					if(insertionDelta == -1)
						{
						frameshiftCorrection = YES;
						rebuildLineDrift++;
						} 
					else 
						nlDidShift = NO;
				}
			currentLineIndex += trailingNlRange.length;
			}
		}

	if(aLine == 0)
		[self sizeToFit];
								// lines actually updated (optimized drawing)
	return [_lineLayoutInformation count] - aLine;	
}									/* end: central line formatting method */

- (int) _rebuildLineLayoutFromLine:(int)aLine
{
	if(_tx.isRichText)
		return [self _rebuildRTFLineLayoutFromLine:0 delta:0 actualLine:0];

	return [self _rebuildPlainLineLayoutFromLine:0 delta:0 actualLine:0];
}
											// relies on lineLayoutInformation
- (void) _drawPlainLinesInLineRange:(NSRange)aRange
{
	int lineLayoutInfoCount = [_lineLayoutInformation count];
	int aMax = MAX(0, lineLayoutInfoCount - 1);			// lay out lines before
														// drawing them 
	if(!_tx.fieldEditor && NSMaxRange(aRange) > aMax)						
		{
		[self _rebuildPlainLineLayoutFromLine:aMax delta:0 actualLine:0];
		lineLayoutInfoCount = [_lineLayoutInformation count];
		}

	if ((aMax > 0) || lineLayoutInfoCount)				// make sure linelayout
		{												// is valid
		NSDictionary *a = [self defaultTypingAttributes];
		_LineLayoutInfo *array[aRange.length];
		NSString *lineString = plainContent;
		int i, c;
	
		[_lineLayoutInformation getObjects:array range:aRange];

		if (_tx.secure)
			{
			static NSString *secureString = nil;
			static int secureLength = 0;

			if ((c = [plainContent length]) != secureLength || !secureString)
				{
				char buf[c+1];
	
				if (secureString)
					[secureString release];

				secureLength = c;
				memset(buf, '*', c);
				buf[c] = '\0';
				secureString = [NSString stringWithCString:(const char*)buf];
				[secureString retain];
				}

			lineString = secureString;
			}

		if (_tx.fieldEditor)
			[_LineLayoutInfo calcDrawInfo];

		for(i = 0; i < aRange.length; i++)
			[array[i] drawPlainLine:lineString withAttributes:a];
		}
}

- (void) _drawRichLinesInLineRange:(NSRange)aRange
{
	NSEnumerator *line;
	NSArray *linesToDraw;
	_LineLayoutInfo *info;
	int lc = [_lineLayoutInformation count];
														// lay out lines before 
	if (NSMaxRange(aRange) > lc - 1)   					// drawing them
		[self _rebuildRTFLineLayoutFromLine:lc - 1 delta:0 actualLine:0];

	linesToDraw = [_lineLayoutInformation subarrayWithRange:aRange];

	for (line = [linesToDraw objectEnumerator]; (info = [line nextObject]);)
		[info drawRTFLine:rtfContent];
}

- (NSRange) lineRangeForRect:(NSRect)rect
{
	static NSRect __lastRect = {0,0,0,0};
	static NSRect __lastBounds = {0,0,0,0};
	static unsigned startLine = 0, endLine = 0;

	if (!NSEqualRects(__lastRect, rect) || !NSEqualRects(__lastBounds, _bounds))
		{
		NSPoint upperLeftPoint = rect.origin;
		NSPoint lowerRightPoint = NSMakePoint(NSMaxX(rect),NSMaxY(rect));

		startLine = [self lineLayoutIndexForPoint:upperLeftPoint];
		endLine = [self lineLayoutIndexForPoint:lowerRightPoint];
		__lastRect = rect;
		__lastBounds = _bounds;
		}

	return _NSAbsoluteRange(startLine, endLine+1);
}

- (void) _drawRectNoSelection:(NSRect)rect
{
	if (_tx.drawsBackground && (!_tx.fieldEditor
			|| (_tx.isRichText ? [rtfContent length] : [plainContent length])))
		{								// leave placeholder if FE is empty
		[_backgroundColor set];
		NSRectFill(rect);
		}								// bootstrap layout information for
										// lineLayoutIndexForCharacterIndex:
	if(![_lineLayoutInformation count])	// to work initially	
		[self _rebuildLineLayoutFromLine:0];

	if(_tx.isRichText)
		[self _drawRichLinesInLineRange:[self lineRangeForRect:rect]];
	else
		[self _drawPlainLinesInLineRange:[self lineRangeForRect:rect]];
}

- (void) drawRect:(NSRect)rect
{
	if(_tx.disableDisplay)
		return;

	[self _drawRectNoSelection:rect];
	if(_selectedRange.length)
		[self _drawSelectionRange:_selectedRange];
}

- (void) copy:(id)sender									// Copy and paste
{
	NSMutableArray *types;
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	NSString *s;

	if (_tx.secure)
		return;

	types = [NSMutableArray arrayWithObjects:NSStringPboardType, nil];
	s = [[self string] substringWithRange:_selectedRange];

	if (_tx.isRichText)
		[types addObject:NSRTFPboardType];
	if ([self importsGraphics])
		[types addObject:NSRTFDPboardType];

	[pb declareTypes:types owner:self];
	[pb setString:s forType:NSStringPboardType];

	if (_tx.isRichText)
		[pb setData:[self RTFFromRange:_selectedRange] forType:NSRTFPboardType];
	if ([self importsGraphics])
		[pb setData:[self RTFDFromRange:_selectedRange] forType:NSRTFDPboardType];
}

- (void) copyFont:(id)sender
{
}

- (void) copyRuler:(id)sender
{
}

- (void) delete:(id)sender
{
	[self deleteRange:_selectedRange backspace:NO];
}

- (void) cut:(id)sender
{
	if(_selectedRange.length)
		{
		[self copy:self];
		[self delete:self];
		}
}

- (void) paste:(id)sender
{
	[self performPasteOperation:[NSPasteboard generalPasteboard]];
}

- (void) pasteFont:(id)sender
{
  [self performPasteOperation:[NSPasteboard pasteboardWithName:NSFontPboard]];
}

- (void) pasteRuler:(id)sender
{
  [self performPasteOperation:[NSPasteboard pasteboardWithName:NSRulerPboard]];
}

- (void) checkSpelling:(id)sender
{
	NSSpellChecker *spellChkr = [NSSpellChecker sharedSpellChecker];
	NSRange errorRange = [spellChkr checkSpellingOfString:[self string] 
									startingAt:NSMaxRange(_selectedRange)];
	if(errorRange.length) 
		[self setSelectedRange:errorRange];
	else 
		NSBeep();
}

- (void) showGuessPanel:(id)sender
{
	[[[NSSpellChecker sharedSpellChecker] spellingPanel] orderFront:self];
}

- (void) changeSpelling:(id)sender
{
	[self insertText:[[(NSControl*)sender selectedCell] stringValue]];
}

- (int) spellCheckerDocumentTag
{
	if(!spellCheckerDocumentTag) 
		spellCheckerDocumentTag = [NSSpellChecker uniqueSpellDocumentTag];

	return spellCheckerDocumentTag;
}

- (void) ignoreSpelling:(id)sender
{
	NSSpellChecker *checker = [NSSpellChecker sharedSpellChecker];

	[checker ignoreWord:[[(NSControl*)sender selectedCell] stringValue] 
			 inSpellDocumentWithTag:[self spellCheckerDocumentTag]];
}

- (id) delegate								{ return _delegate; }

- (void) setDelegate:(id)anObject
{
	NSNotificationCenter *n;

	if (_delegate == anObject)
		return;

#define IGNORE_(notif_name) [n removeObserver:_delegate \
							   name:NSText##notif_name##Notification \
							   object:self]

	n = [NSNotificationCenter defaultCenter];
	if (_delegate)
		{
		IGNORE_(DidEndEditing);
		IGNORE_(DidBeginEditing);
		IGNORE_(DidChange);
		}

	if (!(_delegate = anObject))
		return;

#define OBSERVE_(notif_name) \
	if ([_delegate respondsToSelector:@selector(text##notif_name:)]) \
		[n addObserver:_delegate \
		   selector:@selector(text##notif_name:) \
		   name:NSText##notif_name##Notification \
		   object:self]

	OBSERVE_(DidEndEditing);
	OBSERVE_(DidBeginEditing);
	OBSERVE_(DidChange);
}

- (void) resetCursorRects								// Manage the cursor
{
	if (_tx.selectable)
		[self addCursorRect:_bounds cursor:__textCursor];
}

- (void) encodeWithCoder:(NSCoder *)aCoder				// NSCoding protocol
{
	[super encodeWithCoder:aCoder];

	[aCoder encodeConditionalObject:_delegate];
	[aCoder encodeObject: plainContent];
	[aCoder encodeObject: rtfContent];
	[aCoder encodeValueOfObjCType:@encode(unsigned int) at:&_tx];
	[aCoder encodeObject: _backgroundColor];
	[aCoder encodeObject: _textColor];
	[aCoder encodeObject: _font];
	[aCoder encodeValueOfObjCType:@encode(NSRange) at:&_selectedRange];
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
	[super initWithCoder:aDecoder];

	_delegate = [aDecoder decodeObject];
	plainContent = [aDecoder decodeObject];
	rtfContent = [aDecoder decodeObject];
	[aDecoder decodeValueOfObjCType:@encode(unsigned int) at: &_tx];
	_backgroundColor = [aDecoder decodeObject];
	_textColor = [aDecoder decodeObject];
	_font = [aDecoder decodeObject];
	[aDecoder decodeValueOfObjCType: @encode(NSRange) at:&_selectedRange];

	return self;
}

@end /* NSText */
