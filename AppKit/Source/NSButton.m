/*
   NSButton.m

   Button control and associated button cell class

   Copyright (C) 2000-2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    June 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSTimer.h>

#include <CoreGraphics/CoreGraphics.h>
#include <CoreGraphics/Private/PSOperators.h>

#include <AppKit/NSButton.h>
#include <AppKit/NSEvent.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/NSFont.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSApplication.h>


static id __buttonCellClass = nil;
static NSButton *__firstResponder = nil;

static NSTimer *__crKeyBlinkTimer = nil;
static id  __crKeyBlinkTimerOwner = nil;
static unsigned int __animCounter = 5;



/* ****************************************************************************

		NSButtonCell

** ***************************************************************************/

@implementation NSButtonCell

- (id) init						{ return [self initTextCell:@"Button"]; }

- (id) initTextCell:(NSString *)aString
{
	if ((self = [super initTextCell:aString]))
		{
		_c.bordered = YES;
		_c.selectable = YES;
		_c.cellSubclass = YES;
		_c.showsFirstResponder = YES;
		_stateMask = NSNoCellMask;				// an NSMomentaryPushButton
		_highlightMask = NSPushInCellMask | NSChangeGrayCellMask;
		_periodicDelay = 0.4;
		_periodicInterval = 0.075;
		}

	return self;
}

- (id) initImageCell:(NSImage *)anImage
{
	if ((self = [self initTextCell:nil]))
		{
		_c.imagePosition = NSImageOnly;
		_normalImage = [anImage retain];
		}

	return self;
}

- (void) dealloc
{
	[_alternateContents release];
	[_alternateImage release];
	[_normalImage release];
	[_keyEquivalent release];
	[_keyEquivalentFont release];
	
	[super dealloc];
}

- (id) copy
{
	NSButtonCell *c = [super copy];

	c->_alternateContents = [_alternateContents copy];
	if(_alternateImage)
		c->_alternateImage = [_alternateImage retain];
	if(_normalImage)
		c->_normalImage = [_normalImage retain];
	if(_keyEquivalent)
		{
		c->_keyEquivalent = [_keyEquivalent copy];
		if(_keyEquivalentFont)
			c->_keyEquivalentFont = [_keyEquivalentFont retain];
		c->_keyEquivalentModifierMask = _keyEquivalentModifierMask;
		}
	c->_bc = _bc;
	c->_highlightMask = _highlightMask;
	c->_stateMask = _stateMask;
	c->_periodicDelay = _periodicDelay;
	c->_periodicInterval = _periodicInterval;
	
	return c;
}

- (NSString *) alternateTitle				{ return _alternateContents; }
- (NSString *) title						{ return [self stringValue]; }
- (void) setAlternateTitle:(NSString *)aStr	{ ASSIGN(_alternateContents,aStr);}
- (void) setTitle:(NSString *)aString		{ [self setStringValue:aString]; }
- (void) setFont:(NSFont *)fontObject		{ [super setFont:fontObject]; }
- (NSCellImagePosition) imagePosition		{ return _c.imagePosition; }
- (NSImage *) alternateImage				{ return _alternateImage; }
- (NSImage *) image							{ return _normalImage; }
- (void) setAlternateImage:(NSImage*)aImage	{ ASSIGN(_alternateImage,aImage); }
- (void) setImage:(NSImage *)anImage		{ ASSIGN(_normalImage, anImage); }

- (void) setImagePosition:(NSCellImagePosition)aPosition
{
	_c.imagePosition = aPosition;
}

- (NSSize) cellSize
{
	NSSize m;

	if(_contents && _font)
		m = (NSSize){[_font widthOfString:_contents],[_font ascender]};

	if (!_c.bordered)
		m = (NSSize){m.width + 8, m.height + 8};
	else
		m = (_c.bezeled) ? (NSSize){m.width + 12, m.height + 12} 
						 : (NSSize){m.width + 10, m.height + 10};

	if (_normalImage != nil)
		{
		switch (_c.imagePosition) 
			{												
			case NSImageOnly:
				m = [_normalImage size];
			case NSNoImage:
				break;
			case NSImageLeft:
			case NSImageRight:
				m.width += [_normalImage size].width + 8;
				break;
			case NSImageBelow:
			case NSImageAbove:
				m.height += [_normalImage size].height + 4;
				break;
			case NSImageOverlaps:
				{
				NSSize img = [_normalImage size];

				m.width = MAX(img.width + 4, m.width);
				m.height = MAX(img.height + 4, m.height);
				break;
		}	}	}

	return m;
}

- (void) getPeriodicDelay:(float *)delay interval:(float *)interval
{
	*delay = _periodicDelay;
	*interval = _periodicInterval;
}

- (void) setPeriodicDelay:(float)delay interval:(float)interval
{
	_periodicDelay = delay;
	_periodicInterval = interval;						// Set Repeat Interval
}

- (void) performClick:(id)sender
{
	_c.state = [self nextState];
	[super performClick:sender];
}

- (NSString *) keyEquivalent				{ return _keyEquivalent; }
- (NSFont *) keyEquivalentFont			{ return _keyEquivalentFont; }

- (unsigned int) keyEquivalentModifierMask 	
{ 
	return _keyEquivalentModifierMask;
}

- (void) setKeyEquivalent:(NSString*)key	
{ 
	if (_keyEquivalent != key)
		ASSIGN(_keyEquivalent, [key copy]);
}

- (void) setKeyEquivalentModifierMask:(unsigned int)mask
{
	_keyEquivalentModifierMask = mask;
}

- (void) setKeyEquivalentFont:(NSFont*)fontObj
{
	ASSIGN(_keyEquivalentFont, fontObj);
}

- (void) setKeyEquivalentFont:(NSString*)fontName size: (float)fontSize
{
	ASSIGN(_keyEquivalentFont, [NSFont fontWithName:fontName size:fontSize]);
}

- (void) setButtonType:(NSButtonType)buttonType			// Graphic Attributes
{
	switch (buttonType) 
		{
		case NSMomentaryPushInButton:
			_highlightMask = NSPushInCellMask | NSChangeGrayCellMask;
			_stateMask = NSNoCellMask;
			break;
		case NSMomentaryLightButton:
			_highlightMask = NSChangeBackgroundCellMask;
			_stateMask = NSNoCellMask;
			break;
		case NSMomentaryChangeButton:
			_highlightMask = NSContentsCellMask;
			_stateMask = NSNoCellMask;
			break;
		case NSPushOnPushOffButton:
			_highlightMask = NSPushInCellMask | NSChangeGrayCellMask;
			_stateMask = NSChangeBackgroundCellMask;
			break;
		case NSOnOffButton:
			_stateMask = _highlightMask = NSChangeBackgroundCellMask;
			break;
		case NSToggleButton:
			_highlightMask = NSPushInCellMask | NSContentsCellMask;
			_stateMask = NSContentsCellMask;
			break;
		case NSSwitchButton:
			_stateMask = _highlightMask = NSContentsCellMask;
			[self setImage:[NSImage imageNamed:@"NSSwitch"]];
			[self setAlternateImage:[NSImage imageNamed:@"NSHighlightedSwitch"]];
			[self setImagePosition:NSImageLeft];
			[self setAlignment:NSLeftTextAlignment];
			break;
		case NSRadioButton:
			_stateMask = _highlightMask = NSContentsCellMask;
			[self setImage:[NSImage imageNamed:@"NSRadioButton"]];
			[self setAlternateImage:[NSImage imageNamed: 
										@"NSHighlightedRadioButton"]];
			[self setImagePosition:NSImageLeft];
			[self setAlignment:NSLeftTextAlignment];
			break;
		}

	[self setState:[self state]];						// update our state
}

- (void) setShowsBorderOnlyWhileMouseInside:(BOOL)flag
{
	_bc.showsBorderOnlyWhileMI = flag;
}

- (BOOL) showsBorderOnlyWhileMouseInside { return _bc.showsBorderOnlyWhileMI; }
- (BOOL) isOpaque					{ return !_bc.transparent && _c.bordered; }
- (BOOL) isTransparent					{ return _bc.transparent; }
- (int) highlightsBy					{ return _highlightMask; }
- (int) showsStateBy					{ return _stateMask; }
- (NSBezelStyle) bezelStyle				{ return _bc.bezelStyle; }
- (void) setTransparent:(BOOL)flag		{ _bc.transparent = flag; }
- (void) setHighlightsBy:(int)mask		{ _highlightMask = mask; }
- (void) setShowsStateBy:(int)mask		{ _stateMask = mask; }
- (void) setBezelStyle:(NSBezelStyle)bs	{ _bc.bezelStyle = bs; }
- (void) setIntValue:(int)anInt			{ [self setState:(anInt != 0)]; }
- (void) setFloatValue:(float)aFloat	{ [self setState:(aFloat != 0.)]; }
- (void) setDoubleValue:(double)aDouble	{ [self setState:(aDouble != 0.)]; }
- (int) intValue						{ return [self state]; }
- (float) floatValue					{ return [self state]; }
- (double) doubleValue					{ return [self state]; }

- (void) mouseEntered:(NSEvent *)event
{
	_bc.mouseInside = YES;
	[_controlView setNeedsDisplay:YES];
}

- (void) mouseExited:(NSEvent *)event
{
	_bc.mouseInside = NO;
	[_controlView setNeedsDisplay:YES];
}

- (void) drawWithFrame:(NSRect)cf inView:(NSView*)controlView
{
	float bg = NSLightGray;

	DBLog(@"NSButtonCell drawWithFrame \n");		// Draw cell's frame

	if (cf.size.width <= 0 || cf.size.height <= 0)
		return;

	if (!_controlView && _bc.showsBorderOnlyWhileMI)
		[controlView addTrackingRect:cf owner:self userData:NULL assumeInside:YES];

	_controlView = controlView;						// Save last view drawn to

	if (__crKeyBlinkTimerOwner == controlView && __crKeyBlinkTimer != nil)
		{
		NSImage *bg = [NSImage imageNamed: @"buttonGradient"];
		float frac[] = { 0.7, 0.76, 0.82, 0.88, 0.94, 1.0, 0.92, 0.86, 0.78 };

		unsigned int i = __animCounter++ % 9;

//	NSLog(@"fraction %f", frac[i]);
		[[NSColor colorWithCalibratedWhite:NSDarkGray alpha:1.0] set];
		NSRectFill(cf);
		cf = NSInsetRect(cf, 1.0, 1.0);
		[bg drawInRect: cf
			  fromRect:  (NSRect){NSZeroPoint, cf.size}
			  operation: NSCompositeSourceOver
			  fraction:  frac[i]];
		[self drawInteriorWithFrame:cf inView:controlView];

		return;
		}
													// draw border if needed
	if (_c.bordered && (!_bc.showsBorderOnlyWhileMI || _bc.mouseInside))
		{
		BOOL isFlipped = [controlView isFlipped];
		NSRectEdge *edges;

		if (_c.highlighted && (_highlightMask & NSPushInCellMask)) 
			{
			float grays[] = { NSWhite, NSWhite, NSDarkGray, NSDarkGray,
							  NSLightGray, NSLightGray, NSBlack, NSBlack };

			edges = isFlipped ? BEZEL_EDGES_FLIPPED : BEZEL_EDGES_NORMAL;
			cf = NSDrawTiledRects(cf, cf, edges, grays, 8);
			}
		else
			{
			float grays[] = { NSBlack, NSBlack, NSWhite,
							  NSWhite, NSDarkGray, NSDarkGray };

			edges = isFlipped ? BUTTON_EDGES_FLIPPED : BUTTON_EDGES_NORMAL;
			cf = NSDrawTiledRects(cf, cf, edges, grays, 6);

			if(!_c.highlighted && __firstResponder == _controlView)
				{
				NSColor *y = [NSColor yellowColor];		// focus ring color
				NSColor *c[] = {y, y, y, y};

				cf = NSDrawColorTiledRects(cf, cf, edges, c, 4);
		}	}	}

	if (_c.state) 								// determine background color
		if(_stateMask & (NSChangeGrayCellMask | NSChangeBackgroundCellMask)) 
			bg = NSWhite;

	if (_c.highlighted) 
		if(_highlightMask & (NSChangeGrayCellMask|NSChangeBackgroundCellMask)) 
			bg = NSWhite;

	if (!_bc.transparent)						// set cell's background color
		{
		[[NSColor colorWithCalibratedWhite:bg alpha:1.0] set];
		NSRectFill(cf);
		}

	[self drawInteriorWithFrame:cf inView:controlView];
}

- (void) drawInteriorWithFrame:(NSRect)cf inView:(NSView*)controlView
{
	NSImage *image = _normalImage;
	NSString *title = nil;
	NSSize imageSize;
	NSRect rect;
	float titleGray = NSBlack;
	float bg = NSLightGray;
	NSCompositingOperation op = NSCompositeSourceOver;

	if (_c.state) 										// determine the effect
		{												// of cell's state on 
		if (_stateMask & NSChangeGrayCellMask) 			// it's appearance
			{
			bg = NSWhite;
			titleGray = NSLightGray;
    		}
   		else
			if (_stateMask & NSChangeBackgroundCellMask)
				{
				bg = NSWhite;
				op = NSCompositeHighlight;
				}

		if (_stateMask & NSContentsCellMask)
			{
			image = (_c.allowsMixedState && _c.state == 2 /* NSMixedState */)
				  ? [NSImage imageNamed:@"NSMultiStateSwitch"] : _alternateImage;

			if (_alternateContents)
				{
				title = _contents;
				_contents = _alternateContents;
		}	}	}

	if (_c.highlighted) 								// determine the effect
		{												// of cell's highlight
		if ((_highlightMask & NSChangeGrayCellMask) && (bg == NSLightGray))
			titleGray = NSLightGray;
		else
			if (_highlightMask & NSChangeBackgroundCellMask)
				op = NSCompositeHighlight;

 		if (_highlightMask & NSContentsCellMask)
			{
			image = (_c.allowsMixedState && _c.state == 2 /* NSMixedState */)
				  ? [NSImage imageNamed:@"NSMultiStateSwitch"] : _alternateImage;

			if (!title && _alternateContents)
				{
				title = _contents;
				_contents = _alternateContents;
		}	}	}

	imageSize = (image) ? [image size] : NSZeroSize;
	rect = (NSRect) {cf.origin, imageSize};

	switch (_c.imagePosition)
		{												
		case NSImageOnly:								// draw image only
			if (NSWidth(cf) > imageSize.width)
				NSMinX(cf) += (NSWidth(cf) - imageSize.width) / 2;
			if (NSHeight(cf) > imageSize.height)
				NSMinY(cf) += (NSHeight(cf) - imageSize.height) / 2;
			[image compositeToPoint:cf.origin operation:op];
			return;
														// draw image to the
		case NSImageLeft:					 			// the left of title
			rect.size.width = imageSize.width + 4;
			rect.size.height = cf.size.height;
			cf.origin.x += (rect.size.width - imageSize.width) / 2;
			cf.origin.y += (rect.size.height - imageSize.height) / 2;
			[image compositeToPoint:cf.origin operation:op];
			rect.origin.x += rect.size.width;
			rect.size.width = cf.size.width - rect.size.width;
			cf = rect;
			break;
														// draw image to the
		case NSImageRight:					 			// right of the title
			rect.origin.x += NSWidth(cf) - (8 + imageSize.width);
			rect.origin.y += (cf.size.height - imageSize.height) / 2;
			[image compositeToPoint:rect.origin operation:op];
			cf.size.width -= imageSize.width;
			break;
														// draw image above
		case NSImageBelow:								// below the title
			cf.size.height /= 2;
			rect.origin = cf.origin;
			cf.origin.x += (cf.size.width - imageSize.width) / 2;
			cf.origin.y += (cf.size.height - imageSize.height)/2;
			[image compositeToPoint:cf.origin operation:op];
			cf.origin = rect.origin;
			cf.origin.y += cf.size.height;
			break;
														// draw the image
		case NSImageAbove:						 		// above the title
			rect.origin.y = NSMaxY(cf) - imageSize.height - 3;
			rect.origin.x += (cf.size.width - imageSize.width) / 2;
			[image compositeToPoint:rect.origin operation:op];
			cf.size.height = rect.origin.y;
			break;
														// draw title over
		case NSImageOverlaps:					 		// the image
			rect.origin = cf.origin;
			cf.origin.x += (cf.size.width - imageSize.width) / 2;
			cf.origin.y += (cf.size.height - imageSize.height) / 2;
			[image compositeToPoint:cf.origin operation:op];
			cf.origin = rect.origin;

		case NSNoImage:									// draw title only
			break;
		}

	PSsetgray(titleGray);
	[super drawInteriorWithFrame:cf inView:controlView];
	if (title != nil) 
		_contents = title;
}

- (void) encodeWithCoder:(NSCoder*)aCoder
{
	[super encodeWithCoder:aCoder];

	[aCoder encodeObject: _alternateContents];
	[aCoder encodeObject: _alternateImage];
	[aCoder encodeObject: _normalImage];
	[aCoder encodeValueOfObjCType: @encode(BOOL) at: &_bc];
}

- (id) initWithCoder:(NSCoder*)aDecoder
{
	[super initWithCoder:aDecoder];

	_alternateContents = [aDecoder decodeObject];
	_alternateImage = [aDecoder decodeObject];
	_normalImage = [aDecoder decodeObject];
	[aDecoder decodeValueOfObjCType: @encode(BOOL) at: &_bc];
	
	return self;
}

@end

/* ****************************************************************************

		NSButton

** ***************************************************************************/

@implementation NSButton

+ (void) initialize
{
	if (self == [NSButton class]) 
   		__buttonCellClass = [NSButtonCell class];
}

+ (Class) cellClass						{ return __buttonCellClass; }
+ (void) setCellClass:(Class)aClass		{ __buttonCellClass = aClass; }

- (void) dealloc
{
	if (__crKeyBlinkTimerOwner == self && __crKeyBlinkTimer != nil)
		{
		[__crKeyBlinkTimer invalidate];
		__crKeyBlinkTimer = __crKeyBlinkTimerOwner = nil;
		}
    [super dealloc];
}

- (void) getPeriodicDelay:(float*)delay interval:(float*)interval
{
	[_cell getPeriodicDelay:delay interval:interval];
}

- (void) setPeriodicDelay:(float)delay interval:(float)interval
{
	[_cell setPeriodicDelay:delay interval:interval];
}

- (void) setButtonType:(NSButtonType)aType
{
	[_cell setButtonType:aType];
	[self setNeedsDisplay:YES];
}

- (void) setState:(int)value
{
	[_cell setState:value];
	[self setNeedsDisplay:YES];
}

- (void) setAllowsMixedState:(BOOL)flag { [_cell setAllowsMixedState:flag]; }
- (void) setNextState					{ [_cell setNextState]; }
- (void) setIntValue:(int)value			{ [self setState:value]; }
- (void) setFloatValue:(float)aFloat	{ [self setState:(aFloat != 0)]; }
- (void) setDoubleValue:(double)aDouble	{ [self setState:(aDouble != 0)]; }
- (int) state							{ return [_cell state]; }
- (NSString *) alternateTitle			{ return [_cell alternateTitle]; }
- (NSString *) title					{ return [_cell title]; }
- (NSString *) keyEquivalent			{ return [_cell keyEquivalent]; }
- (NSImage *) image						{ return [_cell image]; }
- (NSImage *) alternateImage			{ return [_cell alternateImage]; }
- (NSCellImagePosition) imagePosition	{ return [_cell imagePosition]; }
- (BOOL) allowsMixedState				{ return [_cell allowsMixedState]; }
- (BOOL) isBordered						{ return [_cell isBordered]; }
- (BOOL) isTransparent					{ return [_cell isTransparent]; }
- (BOOL) isOpaque						{ return [_cell isOpaque]; }
- (BOOL) acceptsFirstMouse:(NSEvent *)e	{ return YES; }

- (void) setAlternateTitle:(NSString *)aString
{
	[_cell setAlternateTitle:aString];
	[self setNeedsDisplay:YES];
}

- (void) setTitle:(NSString *)aString
{										// FIX ME per Apple docs the set*
	[_cell setTitle:aString];			// methods redraw only if necessary
	[self setNeedsDisplay:YES];
}

- (void) setAlternateImage:(NSImage *)anImage
{
	[_cell setAlternateImage:anImage];
	[self setNeedsDisplay:YES];
}

- (void) setImage:(NSImage *)anImage
{
	[_cell setImage:anImage];
	[self setNeedsDisplay:YES];
}

- (void) setImagePosition:(NSCellImagePosition)aPosition
{
	[_cell setImagePosition:aPosition];
	[self setNeedsDisplay:YES];
}

- (void) setBordered:(BOOL)flag
{
	[_cell setBordered:flag];
	[self setNeedsDisplay:YES];
}

- (void) setTransparent:(BOOL)flag
{
	[_cell setTransparent:flag];
	[self setNeedsDisplay:YES];
}

- (void) highlight:(BOOL)flag
{
	[_cell highlight:flag withFrame:_bounds inView:self];
}

- (void) setKeyEquivalent:(NSString*)aKeyEquivalent			// Key Equivalent
{
	[_cell setKeyEquivalent: aKeyEquivalent];
}

- (unsigned int) keyEquivalentModifierMask
{
	return [_cell keyEquivalentModifierMask];
}

- (void) setKeyEquivalentModifierMask:(unsigned int)mask
{
	[_cell setKeyEquivalentModifierMask: mask];
}

- (void) _blinkButton:(id)sender
{
	static int blinkCounter = 0;
	BOOL didLock = NO;

	if (_window == nil)
		{
		if (__crKeyBlinkTimer != nil)
			{
			[__crKeyBlinkTimer invalidate];
			__crKeyBlinkTimer = __crKeyBlinkTimerOwner = nil;
			}
		return;
		}

	if ([NSView focusView] != self)
		{	
		[self lockFocus];
		didLock = YES;
		}

	[_cell highlight:NO withFrame:_bounds inView:self];

	if (didLock)
		[self unlockFocus];

	[_window flushWindow];

	if (blinkCounter++ > 30)				// post periodic AppKit events to
		{									// flush the autorelease pool
		[NSApp postEvent:_NSAppKitEvent() atStart:NO];
		blinkCounter = 0;
		}
}

- (void) _startReturnKeyBlinkTimer
{
	NSRunLoop *c = [NSRunLoop currentRunLoop];

	__crKeyBlinkTimer = [NSTimer timerWithTimeInterval: 0.2
								 target: self
								 selector: @selector(_blinkButton:)
								 userInfo: nil
								 repeats: YES];

	[c addTimer:__crKeyBlinkTimer forMode:NSDefaultRunLoopMode];
	[c addTimer:__crKeyBlinkTimer forMode:NSModalPanelRunLoopMode];
	__crKeyBlinkTimerOwner = self;
}

- (void) _stopReturnKeyBlinkTimer
{
	[__crKeyBlinkTimer invalidate];
	__crKeyBlinkTimer = __crKeyBlinkTimerOwner = nil;
	[self _blinkButton:self];
}

- (BOOL) acceptsFirstResponder
{														
	return [_cell acceptsFirstResponder] || ([self keyEquivalent] != nil);				
}														

- (BOOL) resignFirstResponder						// NSResponder overrides
{
	if (_nextKeyView && [_cell showsFirstResponder])
		{
		__firstResponder = nil;
		[self display];
		}

	if (__crKeyBlinkTimer)
		[self _stopReturnKeyBlinkTimer];

	return YES;
}

- (BOOL) becomeFirstResponder
{
	NSString *key;

	if (_nextKeyView && [_cell showsFirstResponder])
		{
		__firstResponder = self;
		[self display];
		}

	if (__crKeyBlinkTimer)
		[self _stopReturnKeyBlinkTimer];
	if ((key = [self keyEquivalent]) && [key isEqualToString: @"\r"])
		[self _startReturnKeyBlinkTimer];

	return YES;
}

- (void) keyDown:(NSEvent*)event
{
	if ([self performKeyEquivalent: event] == NO)
		{
		if (([_cell acceptsFirstResponder] && 0x20 == [event keyCode])) // Space
			[self performClick: self];
		else
			[super keyDown: event];
		}
}

- (BOOL) performKeyEquivalent:(NSEvent *)anEvent
{
	if ([self isEnabled])
		{
		NSString *key = [self keyEquivalent];

		if (key != nil && [key isEqual: [anEvent charactersIgnoringModifiers]])
			{
			unsigned int mask = [self keyEquivalentModifierMask];

			if (([anEvent modifierFlags] & mask) == mask)
				{
				[self performClick: self];

				return YES;
		}	}	}

	return NO;
}

- (void) encodeWithCoder:(NSCoder*)c	{ [super encodeWithCoder:c]; }
- (id) initWithCoder:(NSCoder*)d		{ return [super initWithCoder:d]; }

@end  /* NSButton */
