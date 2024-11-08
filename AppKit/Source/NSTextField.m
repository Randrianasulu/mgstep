/*
   NSTextField.m

   Text field control and cell classes

   Copyright (C) 2000-2016 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    June 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSException.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSFormatter.h>

#include <AppKit/NSTextField.h>
#include <AppKit/NSTextFieldCell.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSCursor.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSFont.h>

#include <CoreGraphics/Private/PSOperators.h>


#define NOTE(n_name)    NSControl##n_name##Notification

// class variables
static Class __textFieldCellClass = Nil;


/* ****************************************************************************

		NSTextFieldCell

** ***************************************************************************/

@implementation NSTextFieldCell

- (id) initTextCell:(NSString *)aString
{
	if ((self = [super initTextCell:aString]))
		{
		_c.editable = YES;
		_c.selectable = YES;
		_c.bezeled = YES;
		_c.scrollable = YES;
		_c.alignment = NSLeftTextAlignment;
		_c.cellSubclass = YES;
		_c.drawsBackground = YES;
		ASSIGN(_backgroundColor, [NSColor whiteColor]);
		ASSIGN(_textColor, [NSColor blackColor]);
		}

	return self;
}

- (void) dealloc
{
	[_backgroundColor release];
	[_textColor release];
	
	[super dealloc];
}

- (id) copy
{
	NSTextFieldCell *c = [super copy];

	[c setBackgroundColor: _backgroundColor];
	[c setTextColor: _textColor];
	
	return c;
}

- (NSSize) cellSize
{
	NSFont *f;
	NSSize borderSize, s;

	if ([self isBordered])							// Determine border size
		borderSize = ([self isBezeled]) ? (NSSize){2,2} : (NSSize){1,1};
	else
		borderSize = NSZeroSize;
													// Get size of text with a
	f = [self font];							 	// little buffer space
	s = NSMakeSize([f widthOfString:[self stringValue]] + 4,[f pointSize] + 2);
	s.width += 2 * borderSize.width;				// Add in border size
	s.height += 2 * borderSize.height;
	
	return s;
}

- (NSTextFieldBezelStyle) bezelStyle				{ return _tc.bezelStyle; }
- (void) setBezelStyle:(NSTextFieldBezelStyle)style	{ _tc.bezelStyle = style; }

- (NSString*) placeholderString						{ return _placeholderString; }
- (NSAttributedString*) placeholderAttributedString { return _placeholderString; }

- (void) setPlaceholderString:(NSString*)str
{
	ASSIGN(_placeholderString, str);
}

- (void) setPlaceholderAttributedString:(NSAttributedString*)aStr
{
	ASSIGN(_placeholderString, aStr);
}

- (BOOL) isOpaque					{ return _c.bezeled && _c.drawsBackground;}
- (BOOL) drawsBackground					{ return _c.drawsBackground; }
- (void) setDrawsBackground:(BOOL)flag		{ _c.drawsBackground = flag; }
- (void) setBackgroundColor:(NSColor*)clr	{ ASSIGN(_backgroundColor, clr); }
- (void) setTextColor:(NSColor*)clr			{ ASSIGN(_textColor, clr); }
- (NSColor*) backgroundColor				{ return _backgroundColor; }
- (NSColor*) textColor						{ return _textColor; }

- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
	if (_c.bezeled)
		{
		float grays[] = { NSWhite, NSWhite, NSDarkGray, NSDarkGray,
						  NSLightGray, NSLightGray, NSBlack, NSBlack };
		NSRectEdge *edges = BEZEL_EDGES_NORMAL;

		cellFrame = NSDrawTiledRects(cellFrame, cellFrame, edges, grays,8);
		}
	else if (_c.bordered)
		{
		[_textColor set];
		NSFrameRect (cellFrame);
		cellFrame = NSInsetRect(cellFrame, 1, 1);
		}

	if (_c.drawsBackground)									// Clear cell frame
    	{
		[_backgroundColor set];
		NSRectFill(cellFrame);
    	}

	if (_c.editing)
		return;

	[self drawInteriorWithFrame:cellFrame inView:controlView];
}

- (void) drawInteriorWithFrame:(NSRect)frame inView:(NSView*)controlView
{
	BOOL wasSecure = _c.secure;
	BOOL showPlaceHolder = NO;

	if (_placeholderString && (!_contents || [_contents isEqualToString: @""]))
		{
		showPlaceHolder = YES;
		_c.secure = NO;
		_contents = _placeholderString;
		[[NSColor lightGrayColor] set];
		}
	else
		[_textColor set];

	_controlView = controlView;
	[super drawInteriorWithFrame:frame inView:controlView];

	if (showPlaceHolder)
		{
		_c.secure = wasSecure;
		_contents = nil;
		}
}

- (void) encodeWithCoder:(NSCoder *)aCoder
{
	[super encodeWithCoder:aCoder];
	
	[aCoder encodeObject: _backgroundColor];
	[aCoder encodeObject: _textColor];
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
	[super initWithCoder:aDecoder];
	
	_backgroundColor = [aDecoder decodeObject];
	_textColor = [aDecoder decodeObject];
	
	return self;
}

@end /* NSTextFieldCell */

/* ****************************************************************************

		NSTextField

** ***************************************************************************/

@implementation NSTextField

+ (void) initialize
{
	__textFieldCellClass = [NSTextFieldCell class];
}

+ (Class) cellClass							{ return __textFieldCellClass; }
+ (void) setCellClass:(Class)class			{ __textFieldCellClass = class; }

- (BOOL) acceptsFirstResponder				{ return [_cell isSelectable]; }
- (BOOL) becomeFirstResponder				{ return [_cell isSelectable]; }
- (BOOL) isEditable							{ return [_cell isEditable]; }
- (BOOL) isSelectable						{ return [_cell isSelectable]; }
- (void) setEditable:(BOOL)flag				{ [_cell setEditable:flag]; }
- (void) setSelectable:(BOOL)flag			{ [_cell setSelectable:flag]; }
- (id) nextText								{ return _nextKeyView; }
- (id) previousText							{ return [self previousKeyView]; }
- (void) setNextText:(id)anObject			{ [self setNextKeyView:anObject]; }
- (void) setPreviousText:(id)anObject		{ [anObject setNextKeyView:self]; }

- (void) selectText:(id)sender
{
	if (_window)
		{
		NSText *t = [_window fieldEditor:YES forObject:_cell];

		[_cell selectWithFrame:[_cell drawingRectForBounds:_bounds]
			   inView:self
			   editor:t
			   delegate:self
			   start:(int)0
			   length:[[_cell stringValue] length]];

		[_window makeFirstResponder: t];
		}
}

- (NSColor*) textColor						{ return [_cell textColor]; }
- (NSColor*) backgroundColor				{ return [_cell backgroundColor]; }
- (void) setTextColor:(NSColor*)aColor		{ [_cell setTextColor:aColor]; }
- (void) setBackgroundColor:(NSColor*)clr	{ [_cell setBackgroundColor:clr];}
- (void) setDrawsBackground:(BOOL)flag		{ [_cell setDrawsBackground:flag];}
- (BOOL) drawsBackground					{ return [_cell drawsBackground]; }
- (BOOL) isBezeled							{ return [_cell isBezeled]; }
- (BOOL) isBordered							{ return [_cell isBordered]; }
- (BOOL) isOpaque							{ return [_cell isOpaque]; }
- (void) setBezeled:(BOOL)flag				{ [_cell setBezeled:flag]; }
- (void) setBordered:(BOOL)flag				{ [_cell setBordered:flag]; }
- (id) delegate								{ return _delegate; }
- (void) setDelegate:(id)anObject			{ _delegate = anObject; }
- (SEL) errorAction							{ return _errorAction; }
- (void) setErrorAction:(SEL)aSelector		{ _errorAction = aSelector; }

- (void) mouseDown:(NSEvent*)event
{
	if ([_cell isSelectable])
		[_cell editWithFrame:[_cell drawingRectForBounds:_bounds]
			   inView:self
			   editor:[_window fieldEditor:YES forObject:_cell]	
			   delegate:self	
			   event:event];
}
															// NSText delegate
- (void) textDidBeginEditing:(NSNotification *)aNotification
{
	[NSNotificationCenter post: NOTE(TextDidBeginEditing) object: self];
}

- (void) textDidChange:(NSNotification *)aNotification
{
	if ([_cell respondsToSelector:@selector(textDidChange:)])
		return [_cell textDidChange:aNotification];
}

- (void) textDidEndEditing:(NSNotification *)aNotification
{
	NSNumber *code;

	if ([_cell isEditable])				// not editing if cell is editable
		return;

	NSLog(@" NSTextField textDidEndEditing ");
	[_cell endEditing:[aNotification object]];

	if ((code = [[aNotification userInfo] objectForKey:NSTextMovement]))
		switch([code intValue])
			{
			case NSReturnTextMovement:
//				[_window makeFirstResponder:self];
				[self sendAction:[self action] to:[self target]];
				break;
			case NSTabTextMovement:
				[_window selectKeyViewFollowingView:self];
				break;
			case NSBacktabTextMovement:
				[_window selectKeyViewPrecedingView:self];
			case NSIllegalTextMovement:
				break;
			}
}

- (BOOL) textShouldBeginEditing:(NSText *)textObject
{
	return YES;
}

- (BOOL) textShouldEndEditing:(NSText*)textObject
{
	NSLog(@" NSTextField textShouldEndEditing ");

	if (![_window isKeyWindow])
		return NO;

	if ([_cell isEntryAcceptable: [textObject string]])
		{
		if ([_delegate respondsTo:@selector(control:textShouldEndEditing:)])
			{
			if (![_delegate control:self textShouldEndEditing:textObject])
				{
				NSBeep();

				return NO;
			}	}

		[_cell setStringValue:[textObject string]];

		return YES;
		}

	NSBeep();											// entry is not valid
	if ([_cell target])
		[[_cell target] performSelector:_errorAction withObject:self];
	if ([_cell formatter])
		[textObject setString:[[_cell formatter] stringForObjectValue:[_cell objectValue]]];
	else
		[textObject setString:[_cell stringValue]];

	return NO;
}

- (void) resetCursorRects								// Manage the cursor
{
	[self addCursorRect:_bounds cursor:[NSCursor IBeamCursor]];
}

- (void) encodeWithCoder:(NSCoder *)aCoder				// NSCoding protocol
{
	[super encodeWithCoder:aCoder];
	
	[aCoder encodeConditionalObject:_delegate];
	[aCoder encodeValueOfObjCType:@encode(SEL) at:&_errorAction];
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
	[super initWithCoder:aDecoder];
	
	_delegate = [aDecoder decodeObject];
	[aDecoder decodeValueOfObjCType:@encode(SEL) at:&_errorAction];
	
	return self;
}

@end /* NSTextField */
