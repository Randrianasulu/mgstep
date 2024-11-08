/*
   NSClipView.m

   Document scrolling view.

   Copyright (C) 1998-2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    May 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/Foundation.h>

#include <CoreGraphics/CoreGraphics.h>
#include <CoreGraphics/Private/PSOperators.h>

#include <AppKit/NSClipView.h>
#include <AppKit/NSAffineTransform.h>
#include <AppKit/NSCursor.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSGraphics.h>


#define CTX				((CGContext *)cx)
#define CTM				CTX->_gs->hasCTM
#define FOCUS_VIEW		((CGContext *) _CGContext())->_gs->focusView
#define XCANVAS			CTX->_gs->xCanvas
#define ISFLIPPED		CTX->_gs->isFlipped


@implementation NSClipView

- (id) initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]))
		{
		_v.isClip = YES;
		_cv.copiesOnScroll = YES;
		_cv.drawsBackground = YES;
		_backgroundColor = [[NSColor lightGrayColor] retain];
		}

	return self;
}

- (void) dealloc
{
	if (_documentView)
		[self setDocumentView: nil];
	[_backgroundColor release];
	[super dealloc];
}

- (void) setDocumentView:(NSView*)aView
{
	NSNotificationCenter *nc;

	if (_documentView == aView)
		return;

	nc = [NSNotificationCenter defaultCenter];
	if (_documentView)
		{
		[_documentView setPostsFrameChangedNotifications:NO];
		[_documentView setPostsBoundsChangedNotifications:NO];
		[nc removeObserver: self
			name: NSViewFrameDidChangeNotification
			object: _documentView];
		[nc removeObserver: self
			name: NSViewBoundsDidChangeNotification
			object: _documentView];
		[_documentView removeFromSuperview];
		}

	if ((_documentView = aView) != nil) 
		{
		[self addSubview:_documentView];
 						// Register for notifications sent by the document view
		[_documentView setPostsFrameChangedNotifications:YES];
		[_documentView setPostsBoundsChangedNotifications:YES];

		[nc addObserver:self 
			selector:@selector(viewFrameChanged:)
			name:NSViewFrameDidChangeNotification 
			object:_documentView];
		[nc addObserver:self
			selector:@selector(viewBoundsChanged:)
			name:NSViewBoundsDidChangeNotification 
			object:_documentView];

		if ([aView respondsToSelector:@selector(backgroundColor)])
			ASSIGN(_backgroundColor, (NSColor *)[(id)aView backgroundColor]);

		[_superview reflectScrolledClipView:self];
		_v.flipped = [_documentView isFlipped];
		}
}

- (NSPoint) constrainScrollPoint:(NSPoint)proposedOrigin
{
	NSRect dr = [self documentRect];
	NSPoint new = proposedOrigin;

	if (dr.size.width > _bounds.size.width)
		{
		if (proposedOrigin.x < dr.origin.x)
			new.x = dr.origin.x;
		else 
			{
			float difference = dr.size.width - _bounds.size.width;
	
			if (proposedOrigin.x > difference)
				new.x = difference;
		}	}				// if doc is smaller than bounds do not adjust Y
							// because of a possible offset to doc's origin
	if (dr.size.height > _bounds.size.height)
		{
		if (proposedOrigin.y < dr.origin.y)
			new.y = dr.origin.y;
		else 
			{
			float difference = dr.size.height - _bounds.size.height;

			if (proposedOrigin.y > difference)
				new.y = difference;
		}	}

	new.y = (new.y < 0) ? 0 : new.y;
	dr.origin = new;
	dr = [_documentView adjustScroll:dr];		// allow doc view to constrain

	return dr.origin;
}

- (NSRect) documentRect
{
	NSRect dr = [_documentView frame];

	dr.size.width  = MAX( dr.size.width, NSWidth(_bounds) );
	dr.size.height = MAX( dr.size.height, NSHeight(_bounds) );
	
	return dr;
}

- (NSRect) documentVisibleRect
{
	NSSize ds = [_documentView bounds].size;
	NSRect r;

	r.origin = _bounds.origin;
	r.size.width  = MIN(ds.width, _bounds.size.width);
	r.size.height = MIN(ds.height, _bounds.size.height);

	return r;
}

- (BOOL) autoscroll:(NSEvent*)event			
{ 
	NSPoint p = [event locationInWindow];
	NSRect r;

	r.origin = [_documentView convertPoint:p fromView:nil];
	r.size = (NSSize){10,10};
	r = [_documentView adjustScroll:r];
//	NSLog (@"NSClipView: autoscroll %f, %f ", p.x, p.y);
//	NSLog (@"NSClipView: aRect %f, %f ", r.origin.x, r.origin.y);

	return [_documentView scrollRectToVisible:r];
}

- (void) viewBoundsChanged:(NSNotification*)aNotification
{
	[_superview reflectScrolledClipView:self];
}

- (void) viewFrameChanged:(NSNotification*)aNotification
{
	NSRect df = [_documentView frame];

	if (df.size.height < _bounds.size.height)		// doc view is smaller than
		_bounds.origin.y = 0;						// clip so reset origin
	if (df.size.width < _bounds.size.width)
		_bounds.origin.x = 0;
	[self setBoundsOrigin:[self constrainScrollPoint:_bounds.origin]];
	if (NSWidth(df) < NSWidth(_frame) || NSHeight(df) < NSHeight(_frame))
		_invalid = [self visibleRect];
}

- (void) scaleUnitSquareToSize:(NSSize)newUnitSize
{
	[super scaleUnitSquareToSize:newUnitSize];
	[_superview reflectScrolledClipView:self];
}

- (void) setBoundsOrigin:(NSPoint)aPoint
{
	[super setBoundsOrigin:aPoint];
	[_superview reflectScrolledClipView:self];
}

- (void) setBoundsSize:(NSSize)aSize
{
	[super setBoundsSize:aSize];
	[_superview reflectScrolledClipView:self];
}

- (void) setFrameSize:(NSSize)aSize
{
	[super setFrameSize:aSize];
	[_superview reflectScrolledClipView:self];
}

- (void) setFrameOrigin:(NSPoint)aPoint
{
	[super setFrameOrigin:aPoint];
	[_superview reflectScrolledClipView:self];
}

- (void) setFrame:(NSRect)rect
{
	DBLog(@"NS ClipView setFrame: org (%1.2f, %1.2f), size (%1.2f, %1.2f)",
			rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
	[super setFrame:rect];
	[_superview reflectScrolledClipView:self];
}

- (void) translateOriginToPoint:(NSPoint)aPoint
{
	[super translateOriginToPoint:aPoint];
	[_superview reflectScrolledClipView:self];
}

- (id) documentView							  { return _documentView; }
- (BOOL) isOpaque							  { return _cv.drawsBackground; }
- (BOOL) copiesOnScroll						  { return _cv.copiesOnScroll; }
- (void) setCopiesOnScroll:(BOOL)flag		  { _cv.copiesOnScroll = flag; }
- (void) setDocumentCursor:(NSCursor*)cursor  { ASSIGN(_cursor, cursor); }
- (NSCursor*) documentCursor				  { return _cursor; }
- (void) setDrawsBackground:(BOOL)flag		  { _cv.drawsBackground = flag; }
- (BOOL) drawsBackground					  { return _cv.drawsBackground; }
- (NSColor*) backgroundColor				  { return _backgroundColor; }

- (void) setBackgroundColor:(NSColor*)aColor
{
	ASSIGN(_backgroundColor, aColor);
}
															// Disable rotation  
- (void) rotateByAngle:(float)angle			  {}			// of clipview
- (void) setBoundsRotation:(float)angle		  {}
- (void) setFrameRotation:(float)angle		  {}

- (BOOL) isFlipped
{
	return [_documentView isFlipped];
}

- (BOOL) becomeFirstResponder
{
	return [_documentView becomeFirstResponder];
}

- (void) resetCursorRects
{
	if(_cursor)
		[self addCursorRect:[self visibleRect] cursor:_cursor];
	[_documentView resetCursorRects];
}

- (void) drawRect:(NSRect)rect
{
	if (!_cv.drawsBackground)
		return;

	[_backgroundColor set];				// debug:  [[NSColor whiteColor] set];
										// might need a flag for special cases
	if (rect.size.height < _bounds.size.height)
		NSRectFill(_bounds);			// elasticity
	else
		NSRectFill(rect);
}

static void
_DrawSlice(CGContextRef cx, NSView *docView, NSRect slice)
{
	if (CTM)										// convert to doc view
		{											// coords if DV scaled
		CGAffineTransform m = CGContextGetCTM(cx);

		m = CGAffineTransformInvert(m);
		slice = CGRectApplyAffineTransform(slice, m);
		}
	DPSinitclip((DPSContext)cx);
	NSRectClip(slice);
	[docView displayRectIgnoringOpacity: slice];
													// simulate unlockFocus
	CGContextRestoreGState(cx);						// Restore grphic state
}

static void
_CopyRectToPoint(CGContextRef cx, NSRect rect, NSPoint point)
{
	if (ISFLIPPED)
		{
		point.y += XCANVAS.origin.y;
		rect.origin.y += XCANVAS.origin.y;
		}

	_CGContextCopyRect(cx, (NSRect){point,rect.size}, rect.origin);
}

- (void) scrollToPoint:(NSPoint)point
{
	CGContextRef cx = (CGContextRef)[_window graphicsContext];
	NSRect start = _bounds;
	NSRect xRemainder, xSlice, ySlice, dest, xClipRect;
	NSPoint src, xCanvasOrigin, clipOrigin;
	float windowHeight;
	NSAffineTransform *matrix;
	NSView *cv;
	BOOL flip;

	_bounds.origin.y = point.y = floor(point.y);	// avoid rounding errors by
	_bounds.origin.x = point.x = floor(point.x);	// constraining the scroll
 
	if ((start.origin.x == point.x) && (start.origin.y == point.y))
		return;			// translate bounds origin in the opposite direction 
						// so that new origin becomes the origin when viewed. 
	[_boundsMatrix setFrameOrigin:(NSPoint){-point.x, -point.y}];

	if (!_cv.copiesOnScroll || !FOCUS_VIEW || !_documentView)
		{											// not copying portion of
		[_documentView setNeedsDisplay:YES];		// document visible before
													// and after scrolling
		if (_bounds.origin.y < 0 || NSMaxY(_bounds) >= [_documentView bounds].size.height)
			{
			_v.needsDisplay = YES;					// [self setNeedsDisplay:YES]
			_invalid = _bounds;
			}
		return;
		}

	cv = [_window contentView];
	matrix = [cv _matrixFromSubview:_superview toSuperview:cv];
	[matrix appendTransform:_frameMatrix];

	_documentRect = [self documentVisibleRect];
	windowHeight = [_window frame].size.height;
									// calc clip view offset within the window
	xClipRect.origin = clipOrigin = [matrix transformPoint:NSZeroPoint];
	xClipRect.size = NSIntersectionRect(_documentRect, _bounds).size;

	if((_cv.docIsFlipped = [_documentView isFlipped]))
		{												// convert to X coords
		xClipRect.origin.y = windowHeight - NSMinY(xClipRect);
		clipOrigin.y = NSMinY(xClipRect) - clipOrigin.y;
		}
	else
		{
		clipOrigin.y = windowHeight - (NSHeight(_frame) + clipOrigin.y);
		xClipRect.origin.y = windowHeight - NSMaxY(xClipRect);
		}

	[matrix appendTransform:_boundsMatrix];

	if(start.origin.y != point.y)		 				// scrolling the y axis
		{
		if(start.origin.y < point.y)		 			// scroll down document
			{
			float amount = point.y - start.origin.y;	// calc area visible
														// before and after
			NSDivideRect(_bounds, &ySlice, &dest, amount, NSMinYEdge);

			src = dest.origin;
			dest.origin = _bounds.origin;				// calc area of slice
														// needing redisplay
			ySlice.origin.y = NSMaxY(_bounds) - ySlice.size.height;
			}
		else											// scroll up document
			{
			float amount = start.origin.y - point.y;

			NSDivideRect(_bounds, &ySlice, &dest, amount, NSMinYEdge);
			src = _bounds.origin;
		}	}
	else
		ySlice.size.height = 0;

	if(start.origin.x != point.x)		 				// scrolling the x axis
		{
		if(start.origin.x < point.x)		 			// scroll doc right
			{
			float amount = point.x - start.origin.x;	// calc area visible
														// before and after
			NSDivideRect(_bounds, &xSlice, &xRemainder, amount, NSMinXEdge);

			if(start.origin.y != point.y)
				src.x = xRemainder.origin.x;
			else
				src = xRemainder.origin;

			xRemainder.origin = _bounds.origin;			// calc area of slice
														// needing redisplay
			xSlice.origin.x = NSMaxX(_bounds) - xSlice.size.width;
			}
		else											// scroll doc left
			{
			float amount = start.origin.x - point.x;

			NSDivideRect(_bounds, &xSlice, &xRemainder, amount, NSMinXEdge);

			if(start.origin.y != point.y)
				src.x = _bounds.origin.x;
			else
				src = _bounds.origin;
			}

		if(start.origin.y != point.y)		
			{
			dest.size.width = xRemainder.size.width;
			dest.origin.x = xRemainder.origin.x;
			}
		else
			{
			dest.size = xRemainder.size;
			dest.origin = xRemainder.origin;
		}	}

	src = [matrix transformPoint:src];
	dest.origin = [matrix transformPoint:dest.origin];

	CGContextSaveGState(cx);							// Save old clip path
	_CGContextSetClipRect(cx, xClipRect);				// and set a new one

	xCanvasOrigin = XCANVAS.origin;						// minimal PSgsave()
	flip = ISFLIPPED;

	XCANVAS.origin = clipOrigin;						// set canvas origin

	if(!(ISFLIPPED = _cv.docIsFlipped))
		{
		dest.origin.y = windowHeight - dest.origin.y
						- NSHeight(_frame) + NSHeight(ySlice);
		src.y = windowHeight - src.y - NSHeight(_frame) + NSHeight(ySlice);
		}

	_CopyRectToPoint(cx, dest, src);					// copy common rect

	XCANVAS.origin = xCanvasOrigin;						// minimal PSgrestore()
	ISFLIPPED = flip;

	if(_cv.docIsFlipped)
		{
		src = [matrix transformPoint:(NSPoint){0, NSMinY(_bounds)}];
		src.y = windowHeight - src.y - NSMinY(_bounds);
		}
	else
		src = [matrix transformPoint:[_documentView frame].origin];

	if(start.origin.x != point.x)						// scrolling the X axis
		{
		_NSLockFocus(_documentView, src, YES);			// partial lockFocus
		_DrawSlice(cx, _documentView, NSIntersectionRect(_documentRect,xSlice));
		if (FOCUS_VIEW == _documentView)
			XCANVAS.origin.x = src.x;					// set new focus origin
		}

	if(start.origin.y != point.y)						// scrolling the Y axis
		{
		_NSLockFocus(_documentView, src, YES);			// partial lockFocus
		_DrawSlice(cx, _documentView, NSIntersectionRect(_documentRect,ySlice));
		if (FOCUS_VIEW == _documentView)
			XCANVAS.origin.y = src.y;					// set new focus origin
		}
														// set clip needs flush
	_CGContextRectNeedsFlush(cx, (CGRect)xClipRect);

	xCanvasOrigin = XCANVAS.origin;						// minimal PSgsave()
	CGContextRestoreGState(cx);
	XCANVAS.origin = xCanvasOrigin;						// minimal PSgrestore()
}

@end
