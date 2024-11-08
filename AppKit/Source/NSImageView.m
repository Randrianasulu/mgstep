/*
   NSImageView.m

   Image view and its image cell class

   Copyright (C) 1999-2016 Free Software Foundation, Inc.

   Author:	Felipe A. Rodriguez <far@illumenos.com>
   Date:	January 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>
#include <CoreGraphics/CoreGraphics.h>
#include <CoreGraphics/Private/PSOperators.h>

#include <AppKit/NSImageView.h>
#include <AppKit/NSImage.h>

// class variables
id __imageCellClass = nil;


/* ****************************************************************************

		NSImageCell

** ***************************************************************************/

@implementation NSImageCell

- (id) init									{ return [self initImageCell:nil];}

- (id) copy
{
	NSImageCell *c = [super copy];

	c->_ic = _ic;
	
	return c;
}

- (NSImageScaling) imageScaling				{ return _ic.imageScaling; }
- (NSImageAlignment) imageAlignment			{ return _ic.imageAlignment; }
- (NSImageFrameStyle) imageFrameStyle		{ return _ic.imageFrameStyle; }

- (void) setImageScaling:(NSImageScaling)scaling
{
	_ic.imageScaling = scaling;
	[_contents setScalesWhenResized: (scaling == NSScaleNone) ? NO : YES];
}

- (void) setImageAlignment:(NSImageAlignment)alignment
{
	_ic.imageAlignment = alignment;
}

- (void) setImageFrameStyle:(NSImageFrameStyle)frameStyle
{
	_ic.imageFrameStyle = frameStyle;
}

- (NSSize) cellSize
{
	if (!_contents)
		return (NSSize){1,1};

	if (_ic.imageFrameStyle == NSImageFrameNone) 
		return [_contents size];

	return NSOffsetRect((NSRect){{0,0}, [_contents size]}, 2, 2).size;
}

- (NSRect) drawingRectForBounds:(NSRect)rect
{
	if (_ic.imageFrameStyle == NSImageFrameNone) 
		return rect;

	return NSInsetRect(rect, 2, 2);
}

- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
	if (cellFrame.size.width <= 0 || cellFrame.size.height <= 0)
		return;

	_controlView = controlView;						// Save last view drawn to

	switch (_ic.imageFrameStyle) 
		{												
		case NSImageFrameNone:
			return [self drawInteriorWithFrame:cellFrame inView:controlView];

		case NSImageFramePhoto:
			_NSImageFramePhoto(cellFrame, cellFrame);
			break;
		case NSImageFrameGrayBezel:
			NSDrawGrayBezel(cellFrame, cellFrame);
			break;
		case NSImageFrameGroove:
			NSDrawGroove(cellFrame, cellFrame);
			break;
		case NSImageFrameButton:
			NSDrawButton(cellFrame, cellFrame);
			break;
		}

	[self drawInteriorWithFrame:NSInsetRect(cellFrame,2,2) inView:controlView];
}

- (void) drawInteriorWithFrame:(NSRect)cFrame inView:(NSView*)controlView
{
	NSSize is;

	if (!_contents)
		return;

	switch (_ic.imageScaling)
		{
		case NSScaleProportionally:
			{
			float d;

			is = [_contents size];
			d = MIN(NSWidth(cFrame) / is.width, NSHeight(cFrame) / is.height);
			is.width = floor(is.width * d);
			is.height = floor(is.height * d);
			}
			break;

		case NSScaleToFit:
			is = cFrame.size;
			break;

		case NSScaleNone:
			is = [_contents size];
			break;
		}

	switch (_ic.imageAlignment) 
		{												
		case NSImageAlignCenter:
			if(NSWidth(cFrame) > is.width)
				NSMinX(cFrame) += (NSWidth(cFrame) - is.width) / 2;
			if(NSHeight(cFrame) > is.height)
				NSMinY(cFrame) += (NSHeight(cFrame) - is.height) / 2;
			break;

		case NSImageAlignTop:
			if(NSWidth(cFrame) > is.width)
				NSMinX(cFrame) += (NSWidth(cFrame) - is.width) / 2;
		case NSImageAlignTopLeft:
			NSMinY(cFrame) = MAX((NSMaxY(cFrame) - is.height), NSMinY(cFrame));
			break;

		case NSImageAlignTopRight:
			NSMinX(cFrame) = MAX((NSMaxX(cFrame) - is.width), NSMinX(cFrame));
			NSMinY(cFrame) = MAX((NSMaxY(cFrame) - is.height), NSMinY(cFrame));
			break;

		case NSImageAlignLeft:
			if(NSHeight(cFrame) > is.height)
				NSMinY(cFrame) += (NSHeight(cFrame) - is.height) / 2;
			break;

		case NSImageAlignBottom:
			if(NSWidth(cFrame) > is.width)
				NSMinX(cFrame) += (NSWidth(cFrame) - is.width) / 2;
		case NSImageAlignBottomLeft:
			break;

		case NSImageAlignBottomRight:
			NSMinX(cFrame) = MAX((NSMaxX(cFrame) - is.width), NSMinX(cFrame));
			break;

		case NSImageAlignRight:	
			NSMinX(cFrame) = MAX((NSMaxX(cFrame) - is.width), NSMinX(cFrame));
			if(NSHeight(cFrame) > is.height)
				NSMinY(cFrame) += (NSHeight(cFrame) - is.height) / 2;
			break;
		}

	[_contents compositeToPoint:cFrame.origin
			   fromRect:(NSRect){{0,0},is}
			   operation:NSCompositeSourceAtop];
}

- (void) encodeWithCoder:(NSCoder*)aCoder
{
	[super encodeWithCoder:aCoder];
	[aCoder encodeValueOfObjCType: "S" at: &_ic];
}

- (id) initWithCoder:(NSCoder*)aDecoder
{
	[super initWithCoder:aDecoder];
	[aDecoder decodeValueOfObjCType: "S" at: &_ic];
	
	return self;
}

@end  /* NSImageCell */

/* ****************************************************************************

		NSImageView

** ***************************************************************************/

@implementation NSImageView

+ (void) initialize
{
	if (self == [NSImageView class]) 
   		__imageCellClass = [NSImageCell class];
}

+ (Class) cellClass						{ return __imageCellClass; }
+ (void) setCellClass:(Class)aClass		{ __imageCellClass = aClass; }

- (void) drawRect:(NSRect)rect
{
	if (!NSEqualRects(rect, _bounds))
		{
		PSrectclip(NSMinX(rect),NSMinY(rect),NSWidth(rect),NSHeight(rect));
		rect.origin = NSZeroPoint;
		}

	[_cell drawWithFrame:rect inView:self];
}

- (void) setImageAlignment:(NSImageAlignment)align
{
	[_cell setImageAlignment:align];
}

- (void) setImageScaling:(NSImageScaling)scaling
{
	[_cell setImageScaling:scaling];
}

- (void) setImageFrameStyle:(NSImageFrameStyle)style
{
	[_cell setImageFrameStyle:style];
}

- (void) setImage:(NSImage *)image
{
	[_cell setImage:image];
	[self setNeedsDisplay:YES];
}

- (NSImage *) image							{ return [_cell image]; }
- (void) setEditable:(BOOL)flag				{ [_cell setEditable:flag]; }
- (BOOL) isEditable							{ return [_cell isEditable]; }
- (BOOL) isOpaque							{ return YES; }
- (NSImageScaling) imageScaling				{ return [_cell imageScaling]; }
- (NSImageAlignment) imageAlignment			{ return [_cell imageAlignment]; }
- (NSImageFrameStyle) imageFrameStyle		{ return [_cell imageFrameStyle]; }
- (void) mouseDown:(NSEvent*)event			{ }

@end  /* NSImageView */
