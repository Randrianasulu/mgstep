/*
   NSScrollView.m

   View which scrolls another via a clip view.

   Copyright (C) 1996-2018 Free Software Foundation, Inc.

   Author:	Ovidiu Predescu <ovidiu@net-community.com>
   Date:	July 1997
   Author:  Felipe A. Rodriguez <far@ix.netcom.com>
   Date:	October 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSRunLoop.h>

#include <AppKit/NSScroller.h>
#include <AppKit/NSClipView.h>
#include <AppKit/NSScrollView.h>
#include <AppKit/NSRulerView.h>
#include <AppKit/NSTableView.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSApplication.h>

#include <math.h>

// Class variables
static Class __rulerViewClass = nil;
static unsigned __elasticCount = 0;
static NSPoint __elasticMark = {0};



@implementation NSScrollView

+ (void) setRulerViewClass:(Class)aClass	{ __rulerViewClass = aClass; }
+ (Class) rulerViewClass					{ return __rulerViewClass; }

+ (NSSize) contentSizeForFrameSize:(NSSize)frameSize	// calc content size by
			 hasHorizontalScroller:(BOOL)hFlag			// taking into account 
			 hasVerticalScroller:(BOOL)vFlag			// the border type
			 borderType:(NSBorderType)borderType
{
	NSSize size = frameSize;

	if (hFlag)											// account for scroller
		size.height -= ([NSScroller scrollerWidth] + 1);
	if (vFlag)
		size.width -= [NSScroller scrollerWidth];

	switch (borderType) 
		{
		case NSLineBorder:
			size.width -= 2;
			size.height -= 2;
			break;
	
		case NSBezelBorder:
		case NSGrooveBorder:
			size.width -= 4;
			size.height -= 4;
		case NSNoBorder:
			break;
  		}

	return size;
}

+ (NSSize) frameSizeForContentSize:(NSSize)contentSize
			 hasHorizontalScroller:(BOOL)hFlag
			 hasVerticalScroller:(BOOL)vFlag
			 borderType:(NSBorderType)borderType
{
	NSSize size = contentSize;

	if (hFlag)											// account for scroller
		size.height += ([NSScroller scrollerWidth] + 1);
	if (vFlag)						
		size.width += ([NSScroller scrollerWidth] + 1);

	switch (borderType) 
		{
		case NSLineBorder:
			size.width += 2;
			size.height += 2;
			break;
	
		case NSBezelBorder:
		case NSGrooveBorder:
			size.width += 4;
			size.height += 4;
		case NSNoBorder:
			break;
  		}

	return size;
}

- (id) initWithFrame:(NSRect)rect
{
	if ((self = [super initWithFrame:rect]))
		{
		_lineScroll = 10;
		_pageScroll = 30;
		_sv.borderType = NSBezelBorder;
		_sv.scrollsDynamically = YES;
//		_sv.leftSideScroller = YES;			// NeXT style, ComboBox needs right
		}

	return self;
}

- (void) dealloc
{
	if (_sv.hasHorizScroller && _sv.hElasticity != NSScrollElasticityNone)
		[_horizScroller setEnabled:NO];
	if (_sv.hasVertScroller && _sv.vElasticity != NSScrollElasticityNone)
		[_vertScroller setEnabled:NO];

	[super dealloc];
}

- (void) setContentView:(NSClipView*)aView
{
	if (_contentView == aView)
		return;
	if (_contentView)
		[_contentView removeFromSuperview];
	if ((_contentView = aView) == nil)
		return;
	[self addSubview:_contentView];
	[self tile];
}

- (void) setHorizontalScroller:(NSScroller*)aScroller
{
	if (_horizScroller != aScroller)
		{
		if(_horizScroller != nil)
			[_horizScroller removeFromSuperview];
		if ((_horizScroller = aScroller) != nil) 
			{
			_sv.hasHorizScroller = YES;
			[_horizScroller setTarget:self];
			[_horizScroller setAction:@selector(_doScroll:)];
			[self addSubview:_horizScroller];
			if (_sv.hElasticity == NSScrollElasticityAutomatic
					&& [_horizScroller scrollerStyle] == NSScrollerStyleLegacy)
				_sv.hElasticity = NSScrollElasticityNone;
		}	}
}

- (void) setHasHorizontalScroller:(BOOL)flag
{
	if (_sv.hasHorizScroller == flag)
		return;
	if (!(_sv.hasHorizScroller = flag))
		[self setHorizontalScroller:nil];
	else if (_horizScroller == nil)
		[self setHorizontalScroller:[[NSScroller new] autorelease]];
	[self tile];
}

- (void) setVerticalScroller:(NSScroller*)aScroller
{
	if (_vertScroller != aScroller)
		{
		if (_vertScroller != nil)
			[_vertScroller removeFromSuperview];
		if ((_vertScroller = aScroller) != nil) 
			{
			_sv.hasVertScroller = YES;
			[_vertScroller setTarget:self];
			[_vertScroller setAction:@selector(_doScroll:)];
			[self addSubview:_vertScroller];
			if (_sv.vElasticity == NSScrollElasticityAutomatic
					&& [_vertScroller scrollerStyle] == NSScrollerStyleLegacy)
				_sv.vElasticity = NSScrollElasticityNone;
		}	}
}

- (void) setHasVerticalScroller:(BOOL)flag
{
	if (_sv.hasVertScroller == flag)
		return;
	if (!(_sv.hasVertScroller = flag))
		[self setVerticalScroller:nil];
	else if (_vertScroller == nil)
		{
		[self setVerticalScroller:[[NSScroller new] autorelease]];
		if (_contentView && ![_contentView isFlipped])
			[_vertScroller setFloatValue:1];
		}
	[self tile];
}

- (void) setScrollerStyle:(NSScrollerStyle)style
{
	if (_vertScroller)
		[_vertScroller setScrollerStyle:style];
	if (_horizScroller)
		[_horizScroller setScrollerStyle:style];
}

- (NSScrollerStyle) scrollerStyle
{
	if (_vertScroller)
		return [_vertScroller scrollerStyle];

	return (_horizScroller) ? [_horizScroller scrollerStyle] : 0;
}

- (NSScrollerKnobStyle) knobStyle
{
	if (_vertScroller)
		return [_vertScroller knobStyle];

	return (_horizScroller) ? [_horizScroller knobStyle] : 0;
}

- (void) setKnobStyle:(NSScrollerKnobStyle)style
{
	if (_vertScroller)
		[_vertScroller setKnobStyle:style];
	if (_horizScroller)
		[_horizScroller setKnobStyle:style];
}

- (void) setHorizontalScrollElasticity:(NSScrollElasticity)elasticity
{
	_sv.hElasticity = elasticity;
}

- (NSScrollElasticity) horizontalScrollElasticity	{ return _sv.hElasticity; }
- (NSScrollElasticity) verticalScrollElasticity		{ return _sv.vElasticity; }

- (void) setVerticalScrollElasticity:(NSScrollElasticity)elasticity
{
	_sv.vElasticity = elasticity;
}

- (void) flashScrollers							// flash overlay scrollers
{
	if (_vertScroller)
		{
		[_vertScroller setEnabled:YES];
		[_vertScroller display];
		}
	if (_horizScroller)
		{
		[_horizScroller setEnabled:YES];
		[_horizScroller display];
		}
}

- (void) scrollWheel:(NSEvent *)event
{
	if (_vertScroller)
		[_vertScroller scrollWheel:event];
	else if (_horizScroller)
		[_horizScroller scrollWheel:event];
}

- (void) _snapBack:(id)sender
{
	NSPoint p = [_contentView bounds].origin;

	NSLog (@"_snapBack: EM %f  point %f", __elasticMark.y, p.y);

	if (__elasticMark.y != p.y || __elasticMark.x != p.x)
		{
		if (__elasticMark.y != p.y)
			p.y += (p.y > 0) ? -10 : 10;
		if (__elasticMark.x != p.x)
			p.x += (p.x > 0) ? -10 : 10;

		__elasticCount = 0;
		[_contentView lockFocus];	// lock focus checked by clipview to copy on scroll
		[_contentView scrollToPoint:p];						// scroll clipview
		[_contentView unlockFocus];
		[NSApp postEvent:_NSAppKitEvent() atStart:NO];
		}

	if (__elasticMark.y != p.y || __elasticMark.x != p.x)
		[self performSelector:@selector(_snapBack:) withObject:self afterDelay:.05];
	if(_headerClipView)
		{
		if (_sv.vertHeader)
			p.x = 0;
		else
			p.y = 0;
		[_headerClipView scrollToPoint:p];
		}
	[_window flushWindow];
}

- (void) _doScroll:(NSScroller*)scroller
{
	float amount;
	float floatValue = [scroller floatValue];
	NSRect clipBounds = [_contentView bounds];
	NSScrollerPart hitPart = [scroller hitPart];
	NSRect documentRect = [_contentView documentRect];
	NSPoint p;
	int elasticity = 0;

	DBLog (@"_doScroll: float value = %f", floatValue);

	if (hitPart == NSScrollerKnob)
		_sv.knobMoved = YES;
	else
		{
		_sv.knobMoved = NO;
		if (hitPart == NSScrollerIncrementLine)
			amount = _lineScroll;
		else if (hitPart == NSScrollerIncrementPage)
			amount = _pageScroll;
		else if (hitPart == NSScrollerDecrementLine)
			amount = -_lineScroll;
		else if (hitPart == NSScrollerDecrementPage)
			amount = -_pageScroll;
		else
			_sv.knobMoved = YES;
		}

	if (!_sv.knobMoved) 							// button / wheel scrolling
		{
		elasticity = -(_sv.hElasticity != NSScrollElasticityNone);
		if (scroller == _horizScroller)
			p = (NSPoint){NSMinX(clipBounds) + amount, NSMinY(clipBounds)};
    	else
			{
			if (scroller != _vertScroller)
     			return;

			elasticity = (_sv.vElasticity != NSScrollElasticityNone);
			p.x = clipBounds.origin.x;
			if ([_contentView isFlipped])		// reverse scroll direction
				amount = -amount;				// if view is flipped
			DBLog (@"scroll: amount = %f, flipped = %d", amount, [_contentView isFlipped]);
			p.y = clipBounds.origin.y + amount;
		}	}
  	else 											// knob scrolling
		{
    	if (scroller == _horizScroller)
			{
     		p.x = floatValue * (NSWidth(documentRect) - NSWidth(clipBounds));
      		p.y = clipBounds.origin.y;
    		}
    	else
			{ 
			if (scroller != _vertScroller)
     			return;

      		p.x = clipBounds.origin.x;
			if (![_contentView isFlipped])
				floatValue = 1 - floatValue;
			p.y = floatValue * (NSHeight(documentRect) - NSHeight(clipBounds));
		}	}

	p = [_contentView constrainScrollPoint:p];		// allow clip and doc views
													// to constrain the position
	if (elasticity != 0)
		{
		if (floatValue == 0 || floatValue == 1)
			{
			if (++__elasticCount >= 5)
				{
				float offset = MIN(10.0 * (__elasticCount - 4), 50);

				__elasticMark = p;
				if (elasticity > 0)							// Y axis
					{
					if ([_contentView isFlipped])
						p.y += (floatValue == 0) ? -offset : offset;
					else
						p.y += (floatValue == 0) ? offset : -offset;
					}
				else										// X axis
					p.x += (floatValue == 0) ? -offset : offset;

				[NSObject cancelPreviousPerformRequestsWithTarget:self
						  selector:@selector(_snapBack:)
						  object:self];
				[self performSelector:@selector(_snapBack:)
					  withObject:self
					  afterDelay:.3];
				}
			}
		else
			{
			__elasticCount = 0;
			__elasticMark = p;
			}
		}

	DBLog (@"scrollToPoint: %f %f", p.x,p.y);
	[_contentView scrollToPoint:p];							// scroll clipview
	if (!_sv.knobMoved)
		[self reflectScrolledClipView:_contentView];
	if(_headerClipView)
		{
		if (_sv.vertHeader)
			p.x = 0;
		else
			p.y = 0;
		[_headerClipView scrollToPoint:p];	// flush order is critical as clip
//		[_window flushWindow];				// rect is removed in scrollToPoint
		}									// but is still stored in gState
}											// and set again in a PSgrestore()

- (void) reflectScrolledClipView:(NSClipView*)aClipView
{
	NSRect documentFrame = NSZeroRect;
	NSRect clipViewBounds;
	id documentView;
															// do nothing if
	if(aClipView != _contentView)							// aClipView is not
		return;												// our content view

	DBLog (@"reflectScrolledClipView:");

	clipViewBounds = [_contentView bounds];
	if ((documentView = [_contentView documentView]))
		documentFrame = [documentView frame];

	if (_sv.hasVertScroller)
		{
		if (documentFrame.size.height <= clipViewBounds.size.height)
			[_vertScroller setEnabled:NO];
		else
			{
			float k = NSHeight(clipViewBounds) / NSHeight(documentFrame);
			float v = clipViewBounds.origin.y / (documentFrame.size.height
							- clipViewBounds.size.height);
			if (![_contentView isFlipped])
				v = 1 - v;
			[_vertScroller setEnabled:YES];
			[_vertScroller setFloatValue:v knobProportion:k];
			[_vertScroller displayIfNeededIgnoringOpacity];
    	}	}

	if (_sv.hasHorizScroller)
		{
		if (documentFrame.size.width <= clipViewBounds.size.width)
			[_horizScroller setEnabled:NO];
		else
			{
      		float k = NSWidth(clipViewBounds) / NSWidth(documentFrame);
      		float v = clipViewBounds.origin.x / (NSWidth(documentFrame)
							- NSWidth(clipViewBounds));
			[_horizScroller setEnabled:YES];
      		[_horizScroller setFloatValue:v knobProportion:k];
			[_horizScroller displayIfNeededIgnoringOpacity];
		}	}

	if(_headerClipView)
		{
		NSPoint p = (_sv.vertHeader) ? (NSPoint){0, NSMinY(clipViewBounds)}
									 : (NSPoint){NSMinX(clipViewBounds), 0};

		[_headerClipView scrollToPoint: p];
		}
}

- (void) setHorizontalRulerView:(NSRulerView*)aRulerView		// FIX ME
{
	ASSIGN(_horizRuler, aRulerView);
}

- (void) setHasHorizontalRuler:(BOOL)flag						// FIX ME
{
	if (_sv.hasHorizRuler == flag)
		return;

	_sv.hasHorizRuler = flag;
}

- (void) setVerticalRulerView:(NSRulerView*)ruler				// FIX ME
{
	ASSIGN(_vertRuler, ruler);
}

- (void) setHasVerticalRuler:(BOOL)flag							// FIX ME
{
	if (_sv.hasVertRuler == flag)
		return;

	_sv.hasVertRuler = flag;
}

- (void) setRulersVisible:(BOOL)flag
{
	if (_sv.rulersVisible != flag)
		{
		_sv.rulersVisible = flag;
		[self tile];
		}
}

- (void) tile
{
	NSRect vScroller, hScroller, contentRect;
	float scrollerWidth = [NSScroller scrollerWidth];
	float borderThickness;

	switch (_sv.borderType) 
		{
		case NSNoBorder:		borderThickness = 0; 	break;
		case NSLineBorder:		borderThickness = 1;	break;
		case NSBezelBorder:
		case NSGrooveBorder:	borderThickness = 2;	break;
 		}

	contentRect.origin = (NSPoint){borderThickness, borderThickness};
	contentRect.size = (NSSize)[isa contentSizeForFrameSize:_bounds.size
									hasHorizontalScroller:_sv.hasHorizScroller
									hasVerticalScroller:_sv.hasVertScroller
									borderType:_sv.borderType];
	if (_sv.hasVertScroller) 
		{
		if (_sv.leftSideScroller)
			{
			vScroller.origin.x = _bounds.origin.x + borderThickness;
			contentRect.origin.x += scrollerWidth + 1;
			}
		else
			vScroller.origin.x = NSMaxX(_bounds) - borderThickness - scrollerWidth;

		vScroller.origin.y = _bounds.origin.y + borderThickness;
		vScroller.size.width = scrollerWidth;
		vScroller.size.height = _bounds.size.height - (2 * borderThickness);
  		}

	if (_sv.hasHorizScroller) 
		{
		if (_sv.hasVertScroller)
			{
			if (_sv.leftSideScroller)
				hScroller.origin.x = NSMinX(_bounds) + NSMaxX(vScroller) + 1;
			else
				hScroller.origin.x = NSMinX(_bounds) + borderThickness;

			hScroller.size.width = NSWidth(_bounds) - scrollerWidth - borderThickness - 1;
			}
		else
			{
			hScroller.origin.x = NSMinX(_bounds) + borderThickness;
			hScroller.size.width = NSWidth(_bounds) - borderThickness;
			}
		hScroller.origin.y = _bounds.origin.y + borderThickness;
		hScroller.size.height = scrollerWidth;

		contentRect.origin.y += scrollerWidth + 1.0;
  		}

	if (_headerClipView)
		{
		NSRect f;

		if (_sv.vertHeader)
			{
			float w = NSWidth([_headerClipView frame]);

			f = (NSRect){ contentRect.origin ,{ w,NSHeight(contentRect) }};
			NSMinX(contentRect) += w;
			NSWidth(contentRect) -= w;
			}
		else
			{
			float h = NSHeight([_headerClipView frame]);

			contentRect.size.height -= h;
			f = (NSRect){{ NSMinX(contentRect),NSMaxY(contentRect) },
						 { NSWidth(contentRect),h }};
			}
		[_headerClipView setFrame:f];
		}
	[_contentView setFrame:contentRect];
	if (_sv.hasHorizScroller)
		[_horizScroller setFrame:hScroller];
	if (_sv.hasVertScroller) 
		[_vertScroller setFrame:vScroller];
												// If the document view is not
	if (![_contentView isFlipped])				// flipped reverse the meaning
		[_vertScroller setFloatValue:1];		// of the vertical scroller's
}

- (void) drawRect:(NSRect)rect
{
	DBLog(@"NSScrollView drawRect: org (%1.2f, %1.2f), size (%1.2f, %1.2f)",
			rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);

	switch (_sv.borderType)
		{
		case NSLineBorder:
			[[NSColor blackColor] set];
			NSFrameRect(rect);
			break;

		case NSBezelBorder:
			{
			float grays[] = { NSWhite, NSWhite, NSDarkGray, NSDarkGray,
							  NSLightGray, NSLightGray, NSBlack, NSBlack };

			NSDrawTiledRects(rect, rect, BEZEL_EDGES_NORMAL, grays, 8);
			}
 			break;

		case NSGrooveBorder:
			{
			NSRectEdge edges[] = {NSMinXEdge,NSMaxYEdge,NSMinXEdge,NSMaxYEdge, 
								  NSMaxXEdge,NSMinYEdge,NSMaxXEdge,NSMinYEdge};
			float grays[] = { NSDarkGray, NSDarkGray, NSWhite, NSWhite,
							  NSWhite, NSWhite, NSDarkGray, NSDarkGray };

			NSDrawTiledRects(rect, rect, edges, grays, 8);
			}

		case NSNoBorder:
			break;
		}
}

- (NSRect) documentVisibleRect
{
	return [_contentView documentVisibleRect];
}

- (void) setBackgroundColor:(NSColor*)aColor
{
	[_contentView setBackgroundColor:aColor];
}

- (void) setDocumentView:(NSView*)aView
{
	if (_headerClipView)
		[_headerClipView removeFromSuperview], _headerClipView = nil;

	if ([aView respondsToSelector:@selector(headerView)])
		{
		NSView *h;
		
		if ((h = [(NSTableView*)aView headerView]))
			{
			NSRect rect = (NSRect){{0,0},[h frame].size};
	
			_sv.vertHeader = (NSHeight(rect) > NSWidth(rect));
			_headerClipView = [[NSClipView alloc] initWithFrame:rect];
			[_headerClipView setDocumentView:h];
			[self addSubview:_headerClipView];
			[_headerClipView release];
		}	}

	if (!_contentView)
		[self setContentView:[[NSClipView new] autorelease]];
	[_contentView setDocumentView:aView];
	if (_contentView && ![_contentView isFlipped])
		[_vertScroller setFloatValue:1];
	[self tile];
	[self reflectScrolledClipView:(NSClipView*)_contentView];		// update
}																	// scroller

- (void) resizeSubviewsWithOldSize:(NSSize)oldSize
{
	DBLog (@"NSScrollView	resizeSubviewsWithOldSize ");
	[super resizeSubviewsWithOldSize:oldSize];
	[self tile];
}

- (NSSize) contentSize
{
	if (_contentView)
		return [_contentView bounds].size;

	return (NSSize)[isa contentSizeForFrameSize:_bounds.size
						hasHorizontalScroller:_sv.hasHorizScroller
						hasVerticalScroller:_sv.hasVertScroller
						borderType:_sv.borderType];
}

- (void) setDrawsBackground:(BOOL)f	{ [_contentView setDrawsBackground:f]; }
- (NSColor*) backgroundColor		{ return [_contentView backgroundColor]; }
- (NSView*) contentView				{ return _contentView; }
- (id) documentView					{ return [_contentView documentView]; }
- (NSCursor*) documentCursor		{ return [_contentView documentCursor]; }

- (void) setDocumentCursor:(NSCursor*)aCursor
{
	[_contentView setDocumentCursor:aCursor];
}

- (void) setBorderType:(NSBorderType)type	{ _sv.borderType = type; }
- (NSBorderType) borderType					{ return _sv.borderType; }
- (NSScroller*) horizontalScroller			{ return _horizScroller; }
- (NSScroller*) verticalScroller			{ return _vertScroller; }
- (BOOL) hasVerticalScroller				{ return _sv.hasVertScroller; }
- (BOOL) hasHorizontalScroller				{ return _sv.hasHorizScroller; }
- (BOOL) hasHorizontalRuler					{ return _sv.hasHorizRuler; }
- (BOOL) hasVerticalRuler					{ return _sv.hasVertRuler; }
- (BOOL) rulersVisible						{ return _sv.rulersVisible; }
- (NSRulerView*) horizontalRulerView		{ return _horizRuler; }
- (NSRulerView*) verticalRulerView			{ return _vertRuler; }
- (void) setLineScroll:(float)aFloat		{ _lineScroll = aFloat; }
- (void) setPageScroll:(float)aFloat		{ _pageScroll = aFloat; }
- (float) pageScroll						{ return _pageScroll; }
- (float) lineScroll						{ return _lineScroll; }
- (void) setScrollsDynamically:(BOOL)flag	{ _sv.scrollsDynamically = flag; }
- (BOOL) scrollsDynamically					{ return _sv.scrollsDynamically; }
- (BOOL) isOpaque							{ return [_contentView isOpaque]; }
- (BOOL) drawsBackground					{ return [_contentView isOpaque]; }
- (BOOL) autohidesScrollers					{ return _sv.autohidesScrollers; }
- (void) setAutohidesScrollers:(BOOL)flag	{ _sv.autohidesScrollers = flag; }

- (void) mouseUp:(NSEvent *)event					// called when mouse goes
{													// up in scroller
	if(_headerClipView)
	  [_window invalidateCursorRectsForView:[_headerClipView documentView]];
	[_window makeFirstResponder:[_contentView documentView]];
}

@end /* NSScrollView */
