/*
   NSSegmentedControl.m

   Text field control and cell classes

   Author:  Nikolaus Schaller <hns@computer.org>
   Date:    April 2006

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>
#include <Foundation/NSException.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSSegmentedCell.h>
#include <AppKit/NSSegmentedControl.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSFont.h>
#include <AppKit/NSBezierPath.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSMenu.h>



@interface NSBezierPath (RoundedBezel)

typedef enum _NSRoundedBezelSegments
{
	NSRoundedBezelMiddleSegment=0,
	NSRoundedBezelLeftSegment=1,
	NSRoundedBezelRightSegment=2,
	NSRoundedBezelBothSegment=NSRoundedBezelLeftSegment | NSRoundedBezelRightSegment
} NSRoundedBezelSegments;

+ (void) _drawRoundedBezel:(NSRoundedBezelSegments) border
				   inFrame:(NSRect) frame
				   enabled:(BOOL) enabled
				   selected:(BOOL) selected
				   highlighted:(BOOL) highlighted
				   radius:(float) radius;
@end


@implementation NSBezierPath (RoundedBezel)

// this is a special case of _drawRoundedBezel:

+ (NSBezierPath *) _bezierPathWithBoxBezelInRect:(NSRect) borderRect radius:(float) radius
{
	NSBezierPath *b=[self new];
	borderRect.size.width-=1.0;
	borderRect.size.height-=1.0;	// draw inside
	[b appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(borderRect)+radius, NSMinY(borderRect)+radius)
																radius:radius
														startAngle:270.0
															endAngle:180.0
														 clockwise:YES];
	[b appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(borderRect)+radius, NSMaxY(borderRect)-radius)
																radius:radius
														startAngle:180.0
															endAngle:90.0
														 clockwise:YES];
	[b appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(borderRect)-radius, NSMaxY(borderRect)-radius)
																radius:radius
														startAngle:90.0
															endAngle:0.0
														 clockwise:YES];
	[b appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(borderRect)-radius, NSMinY(borderRect)+radius)
																radius:radius
														startAngle:0.0
															endAngle:270.0
														 clockwise:YES];
	[b closePath];
	return [b autorelease];
}

static void
_SegmentShadingValues (void *info, const CGFloat *in, CGFloat *out)
{
	CGFloat v = *in;
	size_t k, components = (size_t)info;
	static const CGFloat c[] = {.75, .75, .75, 0};

    for (k = 0; k < components - 1; k++)
        *out++ = c[k] * v;
     *out++ = 1;						// alpha
}

extern CGFunctionRef _CreateShadingFunction (CGColorSpaceRef cs, CGFunctionCallbacks *cb);

static CGShadingRef
_SegmentShading(void)
{
	static CGFunctionRef fn;
	static CGShadingRef shading = NULL;
	static CGFunctionCallbacks callbacks = { 0, &_SegmentShadingValues, NULL };

	if (!shading)
		{
		CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();

		CGPoint s = CGPointMake(0.0, 0.0);		// vertical gradient white top
		CGPoint e = CGPointMake(0.0, 1.0);

		fn = _CreateShadingFunction(colorspace, &callbacks);
		shading = CGShadingCreateAxial(colorspace, s, e, fn, NO, NO);
		}

 	return shading;
}

#define H_PATTERN_SIZE 16
#define V_PATTERN_SIZE 32
#define H_PSIZE 16
#define V_PSIZE 32

static void
DrawColoredPattern (void *info, CGContextRef myContext)
{
	CGFloat width = H_PATTERN_SIZE;
	CGFloat height = V_PATTERN_SIZE;
	CGAffineTransform at = CGAffineTransformMakeScale (width, height);

	CGContextSaveGState (myContext);
	CGContextConcatCTM (myContext, at);
	CGContextDrawShading(myContext, _SegmentShading());
    CGContextRestoreGState (myContext); // 15
}

static void
ColoredPatternPainting (CGContextRef myContext)
{
    static CGPatternRef pattern = NULL;// 1
    CGFloat         alpha = 1,// 3
                    width, height;// 4
    static const CGPatternCallbacks callbacks = {0, &DrawColoredPattern, NULL};
//    CGContextSaveGState (myContext);

	if (!pattern)
		{
		CGColorSpaceRef patternSpace = CGColorSpaceCreatePattern (NULL);// 2

		CGContextSetFillColorSpace (myContext, patternSpace);// 7
		CGColorSpaceRelease (patternSpace);// 8

		pattern = CGPatternCreate (NULL, // 9
					CGRectMake (0, 0, H_PSIZE, V_PSIZE),// 10
					CGAffineTransformMake (1, 0, 0, 1, 0, 0),// 11
					H_PATTERN_SIZE, // 12
					V_PATTERN_SIZE, // 13
					kCGPatternTilingConstantSpacing,// 14
					YES, // 15
					&callbacks);// 16

		CGContextSetFillPattern (myContext, pattern, &alpha);// 17
		CGPatternRelease (pattern);// 18
		}
	else
    	CGContextSetFillPattern (myContext, pattern, &alpha);// 17
}

// rename to _drawSegmentedBezel
// add backgroundColor parameter (for the default if not enabled)
// add radius parameter - then we can also use it to draw the standard round button

+ (void) _drawRoundedBezel:(NSRoundedBezelSegments) border
				   inFrame:(NSRect) frame
				   enabled:(BOOL) enabled
				   selected:(BOOL) selected
				   highlighted:(BOOL) highlighted
				   radius:(float) radius
{
	NSColor *background = nil;
	NSBezierPath *b=[self new];
	if(border&NSRoundedBezelLeftSegment)
		{ // left side shaped
		[b appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(frame)+radius, NSMinY(frame)+radius)
									  radius:radius
								  startAngle:270.0
									endAngle:180.0
								   clockwise:YES];
		[b appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(frame)+radius, NSMaxY(frame)-1.0-radius)
									  radius:radius
								  startAngle:180.0
									endAngle:90.0
								   clockwise:YES];
		}
	else
		{ // left vertical
		[b moveToPoint:NSMakePoint(NSMinX(frame), NSMinY(frame))];
		[b lineToPoint:NSMakePoint(NSMinX(frame), NSMaxY(frame)-1.0)];
		}
	if(border&NSRoundedBezelRightSegment)
		{ // right side shaped
		[b appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(frame)-radius, NSMaxY(frame)-1.0-radius)
									  radius:radius
								  startAngle:90.0
									endAngle:0.0
								   clockwise:YES];
		[b appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(frame)-radius, NSMinY(frame)+radius)
									  radius:radius
								  startAngle:0.0
									endAngle:270.0
								   clockwise:YES];
		}
	else
		{ // right vertical
		[b lineToPoint:NSMakePoint(NSMaxX(frame), NSMaxY(frame)-1.0)];
		[b lineToPoint:NSMakePoint(NSMaxX(frame), NSMinY(frame))];
		}
	[b closePath];
	[b setLineWidth:.25];
	// setting colors should be done by the caller
	if(enabled)
		{
		if(selected)
			{
			if(highlighted)
				background=[NSColor grayColor];
///				background=[NSColor controlShadowColor];
			else
				background=[NSColor whiteColor];
///				background=[NSColor selectedControlColor];
			}
		else
			{
			if(highlighted)
				background=[NSColor controlHighlightColor];
			else
///				background=[NSColor grayColor];
				ColoredPatternPainting (_CGContext());		// sets fill
///				background=[NSColor controlColor];
			}
		}
	else
		background=[NSColor controlBackgroundColor];
	[background setFill];
	[b fill];	// fill background
	[[NSColor blackColor] setStroke];
	[b stroke];	// stroke border line
	[b release];
}

@end


@implementation NSSegmentItem

- (id) init;
{
	if((self=[super init]))
		{
		_enabled=YES;	// default
		}
	return self;
}

- (void) dealloc;
{
	[_label release];
	[_tooltip release];
	[_image release];
	[_menu release];
	[super dealloc];
}

- (NSString *) description;
{
	return [NSString stringWithFormat:@"NSSegmentItem:%@ tag=%d image=%@ menu=%@ tooltip=%@ enabled=%d highlighted=%d selected=%d",
		_label,
		_tag,
		_image,
		_menu,
		_tooltip,
		_enabled,
		_highlighted,
		_selected];
}

- (NSString *) label; { return _label; }
- (NSString *) tooltip; { return _tooltip; }
- (NSImage *) image; { return _image; }
- (NSMenu *) menu; { return _menu; }
- (float) width; { return _width; }
- (int) tag; { return _tag; }
- (BOOL) enabled; { return _enabled; }
- (BOOL) highlighted; { return _highlighted; }
- (BOOL) selected; { return _selected; }

- (float) autoWidth;
{
	if(_width == 0.0 && _label)
		return [_label sizeWithAttributes:nil].width+4.0;
	return _width;
}

- (void) setLabel:(NSString *) label; { ASSIGN(_label, label); }
- (void) setTooltip:(NSString *) tooltip; { ASSIGN(_tooltip, tooltip); }
- (void) setImage:(NSImage *) image; { ASSIGN(_image, image); }
- (void) setMenu:(NSMenu *) menu; { ASSIGN(_menu, menu); }
- (void) setWidth:(float) width; { _width=width; }
- (void) setTag:(int) tag; { _tag=tag; }
- (void) setEnabled:(BOOL) enabled; { _enabled=enabled; }
- (void) setHighlighted:(BOOL) flag; { _highlighted=flag; }
- (void) setSelected:(BOOL) selected; { _selected=selected; }

- (void) encodeWithCoder:(NSCoder *) aCoder
{
	NIMP;
}

- (id) initWithCoder:(NSCoder *) aDecoder
{
	if(![aDecoder allowsKeyedCoding])
		{ [self release]; return nil; }
#if 0
	NSLog(@"initWithCoder: %@", self);
#endif
	return self;
}

@end


@implementation NSSegmentedCell

- (id) initTextCell:(NSString *)aString
{
	if((self=[super initTextCell:aString]))
		{
			[self setAlignment:NSCenterTextAlignment];
			_segments=[[NSMutableArray alloc] initWithCapacity:10];
		}
	return self;
}

- (id) copy
{
	NSSegmentedCell *c = [super copy];
	if(c)
		{
		c->_mode=_mode;
//	c->_count=_count;
//	c->_capacity=_capacity;
		// copy entries?
		}
	return c;
}

- (void) dealloc;
{
	[_segments release];
	[super dealloc];
}

- (NSSize) cellSize;
{
	// sum up all widths and use default height for controlSize
	NIMP; return NSZeroSize;
}

- (void) drawWithFrame:(NSRect) cellFrame inView:(NSView*) controlView
{
	unsigned int i=0, count=[_segments count];
	NSRect frame=cellFrame;
	// should we set any clipping?
	while(i < count && frame.origin.x < cellFrame.size.width)
		{ // there is still room for a segment
///		frame.size.width=[[_segments objectAtIndex:i] autoWidth];
///		if (frame.size.width <= 4)
			frame.size.width = cellFrame.size.width / count;
		[self drawSegment:i inFrame:frame withView:controlView];
		frame.origin.x+=frame.size.width-1;
		i++;
		}
}

- (void) drawInteriorWithFrame:(NSRect)frame inView:(NSView*)controlView
{ // we can't use this method since we can't distingush between interior and exterior
}

- (void) drawSegment:(NSInteger)i inFrame:(NSRect) frame withView:(NSView *) controlView;
{
	NSSegmentItem *s=[_segments objectAtIndex:i];
	int border=(i==0?1:0)+(i==[_segments count]-1?2:0);
	NSImage *img;
	_c.enabled=[s enabled];	// copy status of current cell
	[NSBezierPath _drawRoundedBezel:border
				  inFrame:  NSInsetRect(frame, 1, 1)
				  enabled:(_c.enabled && [(NSSegmentedControl *) controlView isEnabled])
				  selected:[s selected]
				  highlighted:(_c.highlighted && [s highlighted])
				  radius:4.0];
	if((img=[s image]))
		{ // composite segment image
		[img drawAtPoint:frame.origin fromRect:(NSRect){NSZeroPoint, [img size]} operation:NSCompositeSourceOver fraction:1.0];
		}
	_contents=[s label];
	[super drawInteriorWithFrame:frame inView:controlView];	// use NSCell's drawing method for this segment
}

- (BOOL) trackMouse:(NSEvent *)event
			 inRect:(NSRect)cellFrame
			 ofView:(NSView *)controlView
			 untilMouseUp:(BOOL)untilMouseUp
{ // check to which subcell we have to forward tracking
	NSPoint loc=[event locationInWindow];
	NSRect frame=cellFrame;
	unsigned int count=[_segments count];
	loc = [controlView convertPoint:loc fromView:nil];
#if 1
	NSLog(@"NSSegmentedCell trackMouse:%@ inRect:%@", NSStringFromPoint(loc), NSStringFromRect(cellFrame));
#endif
	if(_trackedSegment < count)
		{
		[[_segments objectAtIndex:_trackedSegment] setHighlighted:NO];	// remove highlighting
		[controlView setNeedsDisplayInRect:cellFrame];		// could be restriced to highlighting position
		}
	_trackedSegment=0;
	while(_trackedSegment < count && frame.origin.x < cellFrame.size.width)
		{ // there is still room for a segment
///		frame.size.width=[[_segments objectAtIndex:_trackedSegment] autoWidth];
///		if (frame.size.width <= 4)
			frame.size.width = cellFrame.size.width / count;
		if(NSMouseInRect(loc, frame, NO))
			{
#if 1
			NSLog(@"mouse is in segment %d", _trackedSegment);
#endif
			[[_segments objectAtIndex:_trackedSegment] setHighlighted:YES];	// set highlighting
			[controlView setNeedsDisplayInRect:cellFrame];		// could be restriced to highlighting position
			break;
			}
		frame.origin.x+=frame.size.width;
		_trackedSegment++;
		}
 	return [super trackMouse:event inRect:frame ofView:controlView untilMouseUp:untilMouseUp];	// track while in this segment
}

- (void) stopTracking:(NSPoint) lastPoint
				   at:(NSPoint) stopPoint
				   inView:(NSView *) controlView
				   mouseIsUp:(BOOL) flag
{
	if(_trackedSegment < [_segments count])
		{
		[[_segments objectAtIndex:_trackedSegment] setHighlighted:NO];	// remove highlighting

		if(flag && [self isEnabledForSegment:_trackedSegment])
			{ // make the segment where the mouse did go up the selected segment
			[self setSelectedSegment:_trackedSegment];
			}
		}
}

- (NSImage *) imageForSegment:(NSInteger)segment
{
	return [[_segments objectAtIndex:segment] image];
}

- (BOOL) isEnabledForSegment:(NSInteger)segment
{
	return [[_segments objectAtIndex:segment] enabled];
}

- (BOOL) isSelectedForSegment:(NSInteger)segment
{
	return [[_segments objectAtIndex:segment] selected];
}

- (NSString *) labelForSegment:(NSInteger)segment
{
	return [[_segments objectAtIndex:segment] label];
}

- (void) makeNextSegmentKey;
{
	NIMP;
}

- (void) makePreviousSegmentKey;
{
	NIMP;
}

- (NSMenu *) menuForSegment:(NSInteger) segment
{
	return [[_segments objectAtIndex:segment] menu];
}

- (NSInteger) segmentCount			{ return [_segments count]; }

- (NSInteger) selectedSegment;
{
	unsigned int i, count=[_segments count];
	for(i=0; i<count; i++)
		if([self isSelectedForSegment:i])
			return i;
	return -1;
}

- (BOOL) selectSegmentWithTag:(NSInteger)t
{
	unsigned int i, count=[_segments count];
	for(i=0; i<count; i++)
		{
		if([[_segments objectAtIndex:i] tag] == t)
			{ // found
			[self setSelectedSegment:i];
			return YES;
			}
		}
	return NO;
}

- (void) setEnabled:(BOOL)flag forSegment:(NSInteger)segment
{
	[[_segments objectAtIndex:segment] setEnabled:flag];
}

- (void) setImage:(NSImage *)image forSegment:(NSInteger)segment
{
	[[_segments objectAtIndex:segment] setImage:image];
}

- (void) setLabel:(NSString *)label forSegment:(NSInteger)segment
{
	[[_segments objectAtIndex:segment] setLabel:label];
}
- (void) setMenu:(NSMenu *)menu forSegment:(NSInteger)segment
{
	[[_segments objectAtIndex:segment] setMenu:menu];
}

- (void) setSegmentCount:(NSInteger)count
{ // limited to 2049?
	if(count < [_segments count])
		[_segments removeObjectsInRange:NSMakeRange(count, [_segments count]-count)];
	while(count > [_segments count])
		{
		NSSegmentItem *s=[NSSegmentItem new];	// create empty item
		[_segments addObject:s];
		[s release];
		}
}

- (void) setSelected:(BOOL)flag forSegment:(NSInteger)segment
{
	[[_segments objectAtIndex:segment] setSelected:flag];
}

- (void) setSelectedSegment:(NSInteger)segment
{
	int lastSelected=[self selectedSegment];
	if(segment == lastSelected)
		return;	// unchanged
	if(_mode != NSSegmentSwitchTrackingSelectAny && lastSelected >= 0)
		[self setSelected:NO forSegment:lastSelected];
	if(segment >= 0 && segment < [self segmentCount])
		[self setSelected:YES forSegment:segment];
}

- (void) setTag:(NSInteger)t forSegment:(NSInteger)segment
{
	[[_segments objectAtIndex:segment] setTag:t];
}

- (void) setToolTip:(NSString *)tooltip forSegment:(NSInteger)segment
{
	[[_segments objectAtIndex:segment] setTooltip:tooltip];
}

- (void) setTrackingMode:(NSSegmentSwitchTracking) mode		{ _mode=mode; }

- (void) setWidth:(CGFloat)width forSegment:(NSInteger)segment
{
	[[_segments objectAtIndex:segment] setWidth:width];
}

- (NSInteger) tagForSegment:(NSInteger)segment
{
	return [[_segments objectAtIndex:segment] tag];
}

- (NSString *) toolTipForSegment:(NSInteger)segment
{
	return [[_segments objectAtIndex:segment] tooltip];
}

- (NSSegmentSwitchTracking) trackingMode				{ return _mode; }

- (CGFloat) widthForSegment:(NSInteger)segment
{
	return [[_segments objectAtIndex:segment] width];
}

- (void) encodeWithCoder:(NSCoder *) aCoder
{
///	[super encodeWithCoder:aCoder];
	NIMP;
}

- (id) initWithCoder:(NSCoder *) aDecoder
{
	unsigned int count;
	self=[super initWithCoder:aDecoder];
	if(![aDecoder allowsKeyedCoding])
		{ [self release]; return nil; }
	_c.enabled=YES;
	[self setAlignment:NSCenterTextAlignment];
	_segments = [[aDecoder decodeObjectForKey:@"NSSegmentImages"] retain];	// array of segments
	count=[_segments count];
	return self;
}

@end


@implementation NSSegmentedControl

+ (Class) cellClass							{ return [NSSegmentedCell class]; }
+ (void) setCellClass:(Class)class			{  }

- (NSImage *) imageForSegment:(NSInteger) segment	{ return [_cell imageForSegment:segment]; }
- (BOOL) isEnabledForSegment:(NSInteger) segment	{ return [_cell isEnabledForSegment:segment]; }
- (BOOL) isSelectedForSegment:(NSInteger) segment	{ return [_cell isSelectedForSegment:segment]; }
- (NSString *) labelForSegment:(NSInteger) segment	{ return [_cell labelForSegment:segment]; }
- (NSMenu *) menuForSegment:(NSInteger) segment		{ return [_cell menuForSegment:segment]; }
- (NSInteger) segmentCount							{ return [_cell segmentCount]; }
- (NSInteger) selectedSegment						{ return [_cell selectedSegment]; }
- (BOOL) selectSegmentWithTag:(NSInteger) tag		{ return [_cell selectSegmentWithTag:tag]; }

- (void) setEnabled:(BOOL)flag forSegment:(NSInteger)segment
{
	return [_cell setEnabled:flag forSegment:segment];
}

- (void) setImage:(NSImage *)image forSegment:(NSInteger)segment
{
	return [_cell setImage:image forSegment:segment];
}
- (void) setLabel:(NSString *) label forSegment:(NSInteger)segment
{
	return [_cell setLabel:label forSegment:segment];
}

- (void) setMenu:(NSMenu *) menu forSegment:(NSInteger)segment
{
	return [_cell setMenu:menu forSegment:segment];
}

- (void) setSegmentCount:(NSInteger) count
{
	return [_cell setSegmentCount:count];
}

- (void) setSelected:(BOOL) flag forSegment:(NSInteger)segment
{
	return [_cell setSelected:flag forSegment:segment];
}

- (void) setSelectedSegment:(NSInteger) selectedSegment
{
	return [_cell setSelectedSegment:selectedSegment];
}

- (void) setWidth:(CGFloat) width forSegment:(NSInteger)segment
{
	return [_cell setWidth:width forSegment:segment];
}

- (CGFloat) widthForSegment:(NSInteger) segment
{
	return [_cell widthForSegment:segment];
}

- (void) encodeWithCoder:(NSCoder *) aCoder
{
	[super encodeWithCoder:aCoder];
}

- (id) initWithCoder:(NSCoder *) aDecoder
{
	return [super initWithCoder:aDecoder];	// NSControl
}

@end
