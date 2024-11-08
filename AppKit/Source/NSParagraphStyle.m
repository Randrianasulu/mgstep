/*
   NSParagraphStyle.m

   NSParagraphStyle and NSMutableParagraphStyle hold paragraph style 
   information NSTextTab holds information about a single tab stop

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Daniel Bðhringer <boehring@biomed.ruhr-uni-bochum.de>
   Date: August 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/Foundation.h>
#include <AppKit/NSParagraphStyle.h>

#include <AppKit/NSLayoutManager.h>
#include <AppKit/NSTextContainer.h>
#include <AppKit/NSTextView.h>

/* ****************************************************************************

	NSTextTab

** ***************************************************************************/

@implementation NSTextTab

- (id) initWithType:(NSTextTabType)type location:(float)loc
{	
	if (self = [super init])
		{
		tabStopType = type;
		location = loc;
		}

	return self;
}

- (float) location						{ return location; }
- (NSTextTabType) tabStopType			{ return tabStopType; }

- (id) copy
{
	return [[isa alloc] init];
}

- initWithCoder:(NSCoder*)aDecoder						// NSCoding protocol
{
	[super initWithCoder:aDecoder];
	
	return self;
}

- (void) encodeWithCoder:(NSCoder*)aCoder	{ [super encodeWithCoder:aCoder]; }

@end

/* ****************************************************************************

	NSParagraphStyle

** ***************************************************************************/

@implementation NSParagraphStyle

+ (NSParagraphStyle *) defaultParagraphStyle
{
	return nil;
}

/* "Leading": distance between the bottom of one line fragment and top of next (applied between lines in the same container). Can't be negative. This value is included in the line fragment heights in layout manager. */
- (float) lineSpacing
{
	return 0;
}

/* Distance between the bottom of this paragraph and top of next. */
- (float) paragraphSpacing
{
	return 0;
}

- (NSTextAlignment) alignment
{
	return 0;
}

/* The following values are relative to the appropriate margin (depending on the paragraph direction) */

/* Distance from margin to front edge of paragraph */
- (float) headIndent
{
	return 0;
}

/* Distance from margin to back edge of paragraph; if negative or 0, from other margin */
- (float) tailIndent
{
	return 0;
}

/* Distance from margin to edge appropriate for text direction */
- (float) firstLineHeadIndent
{
	return 0;
}

/* Distance from margin to tab stops */
- (NSArray *) tabStops						{ return _tabStops; }
- (NSArray *) textBlocks					{ return _textBlocks; }
- (NSArray *) textLists						{ return _textLists; }

/* Line height is the distance from bottom of descenders to top of ascenders; basically the line fragment height. Does not include lineSpacing (which is added after this computation). */
- (float) minimumLineHeight
{
	return 0;
}

/* 0 implies no maximum. */
- (float) maximumLineHeight
{
	return 0;
}

- (NSLineBreakMode) lineBreakMode
{
	return 0;
}

//@end

///@implementation NSParagraphStyle 

- (void)setLineSpacing:(float)aFloat
{}
- (void)setParagraphSpacing:(float)aFloat
{}
- (void)setAlignment:(NSTextAlignment)alignment
{}
- (void)setFirstLineHeadIndent:(float)aFloat
{}
- (void)setHeadIndent:(float)aFloat
{}
- (void)setTailIndent:(float)aFloat
{}
- (void)setLineBreakMode:(NSLineBreakMode)mode
{}
- (void)setMinimumLineHeight:(float)aFloat
{}
- (void)setMaximumLineHeight:(float)aFloat
{}
- (void)addTabStop:(NSTextTab *)anObject
{}
- (void)removeTabStop:(NSTextTab *)anObject
{}
- (void)setTabStops:(NSArray *)array
{}
- (void)setParagraphStyle:(NSParagraphStyle *)obj
{}

- (id) copy							{ return [[isa alloc] init]; }
- (id) mutableCopy					{ return [[isa alloc] init]; }

- (id) initWithCoder:(NSCoder*)aDecoder						// NSCoding protocol
{
	[super initWithCoder:aDecoder];
	
	return self;
}

- (void) encodeWithCoder:(NSCoder*)aCoder	{ [super encodeWithCoder:aCoder]; }

@end


@implementation NSMutableParagraphStyle 

- (void) setParagraphStyle:(NSParagraphStyle *)obj				{ NIMP; }
- (void) setLineSpacing:(float)aFloat							{ lineSpacing=aFloat; }
- (void) setParagraphSpacing:(float)aFloat						{ paragraphSpacing=aFloat; }
- (void) setAlignment:(NSTextAlignment)align					{ alignment=align; }
- (void) setFirstLineHeadIndent:(float)aFloat					{ firstLineHeadIndent=aFloat; }
- (void) setHeadIndent:(float)aFloat							{ headIndent=aFloat; }
- (void) setTailIndent:(float)aFloat							{ tailIndent=aFloat; }
- (void) setLineBreakMode:(NSLineBreakMode)mode					{ lineBreakMode=mode; }
- (void) setMinimumLineHeight:(float)aFloat						{ minimumLineHeight=aFloat; }
- (void) setMaximumLineHeight:(float)aFloat						{ maximumLineHeight=aFloat; }
// FIXME: we should insert-sort tabs at the correct position!!!
- (void) addTabStop:(NSTextTab *)anObject						{ [_tabStops addObject:anObject]; }
- (void) removeTabStop:(NSTextTab *)anObject					{ [_tabStops removeObject:anObject]; }

- (void) setTabStops:(NSArray *)array
{
	[_tabStops release];
	_tabStops = [array mutableCopy];
}

@end

/* ****************************************************************************

	NSTextContainer

	Author:	H. N. Schaller <hns@computer.org>
	Date:	Jun 2006

** ***************************************************************************/

@implementation NSTextContainer

- (id) initWithContainerSize:(NSSize)size
{
	if ((self = [super init]))
		{
		_size = size;
		_lineFragmentPadding = 5.0;
		}

	return self;
}

- (id) init
{ // undocumented initializer for a "sufficiently large" container; used by Apple in the CircleView example
	return [self initWithContainerSize:(NSSize) { 1e+7, 1e+7 }];
}

- (void) dealloc;
{
	[self setTextView:nil];
	[super dealloc];
}

- (NSString *) description;
{
	return [NSString stringWithFormat:@"%@: size %@ padding=%g%@%@", NSStringFromClass([self class]), NSStringFromSize(_size), _lineFragmentPadding, _heightTracksTextView?@" height-tracks":@"", _widthTracksTextView?@" width-tracks":@""];
}

- (void) setContainerSize:(NSSize)size
{
	if (!NSEqualSizes(_size, size))
		{
		_size = size;
		[_layoutManager textContainerChangedGeometry:self];
		}			// so that glyphs and layout are invalidated
}

- (NSSize) containerSize						{ return _size; }
- (NSTextView *) textView						{ return _textView; }

- (void) setTextView:(NSTextView *)tv
{
	if(_textView != tv)
		{
		NSNotificationCenter *nc=[NSNotificationCenter defaultCenter];

		if(_textView)
			{ // disconnect from text view
				[_textView setPostsFrameChangedNotifications:NO];	// no need to notify any more...
				[_textView setTextContainer:nil];
				[nc removeObserver:self name:NSViewFrameDidChangeNotification object:_textView];
				[_textView release];
				_textView=nil;
			}
		if(tv)
			{ // connect to text view
				_textView=[tv retain];
				[_textView setTextContainer:self];
				[_textView setPostsFrameChangedNotifications:YES];	// should notify...
///				[nc addObserver:self
///					selector:@selector(_track:)
///					name:NSViewFrameDidChangeNotification
///					object:_textView];
///				[self _track:nil];	// initial "notification"
			}
		}
}

- (NSLayoutManager *) layoutManager				{ return _layoutManager; }

- (void) setLayoutManager:(NSLayoutManager *)layoutManager
{
	ASSIGN(_layoutManager, layoutManager);
}

- (void) setLineFragmentPadding:(float)pad		{ _lineFragmentPadding = pad; }
- (float) lineFragmentPadding					{ return _lineFragmentPadding; }

- (void) setWidthTracksTextView:(BOOL)flag		{ _widthTracksTextView = flag; }
- (BOOL) widthTracksTextView					{ return _widthTracksTextView; }
- (BOOL) heightTracksTextView					{ return _heightTracksTextView; }
- (void) setHeightTracksTextView:(BOOL)flag		{ _heightTracksTextView = flag; }

- (NSRect) lineFragmentRectForProposedRect:(NSRect) proposedRect
							sweepDirection:(NSLineSweepDirection) sweepDirection
						 movementDirection:(NSLineMovementDirection) movementDirection
							 remainingRect:(NSRect *) remainingRect;
{ // standard container - limit proposed rect to width and height of container
	NSRect lfr=proposedRect;	// limit by container - may be empty if no space available
	// what is the influence of the movement direction?
	if(NSMinX(lfr) < 0.0)
		{ // trim left edge to container start
		lfr.size.width += lfr.origin.x;
		lfr.origin.x=0.0;
		}
	if(NSMinX(lfr) > _size.width)
		lfr.size.width=0.0;	// starts beyond container width
	else if(NSMaxX(lfr) > _size.width)
		lfr.size.width = _size.width - lfr.origin.x;	// trim right edge to container width
	if(lfr.origin.y < 0.0)
		{ // trim top edge to container start
			lfr.size.height+=lfr.origin.y;
			lfr.origin.y=0.0;
		}
	if(NSMaxY(lfr) > _size.height)
		return NSZeroRect;	// does not fit
	if(remainingRect)
		*remainingRect=NSZeroRect;	// there is no remaining rect for a simple rectangular container
	return lfr;
}
							// replace while leaving text sys web intact
- (void) replaceLayoutManager:(NSLayoutManager *)newLayoutManager
{
	NSArray *textContainers = [_layoutManager textContainers];
	NSUInteger i, cnt=[textContainers count];
	NSTextContainer *c;
	NSLayoutManager *oldLayoutManager=_layoutManager;

	if(newLayoutManager == _layoutManager)
		return;	// no change
	for(i=0; i<cnt; i++)
		{
		c=[textContainers objectAtIndex:i];
		[c retain];
		[oldLayoutManager removeTextContainerAtIndex:i];	// remove first
		[newLayoutManager addTextContainer:c];	// add to new layout manager
		[c release];
		}
}

- (BOOL) containsPoint:(NSPoint)point			{ return YES; }
- (BOOL) isSimpleRectangularTextContainer		{ return YES; }

- (void) encodeWithCoder:(NSCoder *) coder;
{
	// encode NSWidth, NSHeight, padding only if not default value
	NIMP;
}

- (id) initWithCoder:(NSCoder *) coder;
{
	int tcFlags=[coder decodeInt32ForKey:@"NSTCFlags"];
	self=[self init];	// default initialization
#if 0
	NSLog(@"%@ initWithCoder: %@", self, coder);
#endif
#define WIDTHTRACKS ((tcFlags&0x01)!=0)
	_widthTracksTextView=WIDTHTRACKS;
#define HEIGHTTRACKS ((tcFlags&0x02)!=0)
	_heightTracksTextView=HEIGHTTRACKS;
	if([coder containsValueForKey:@"NSWidth"])
		_size.width=[coder decodeFloatForKey:@"NSWidth"];
	if([coder containsValueForKey:@"NSHeight"])
		_size.height=[coder decodeFloatForKey:@"NSHeight"];
	_layoutManager=[coder decodeObjectForKey:@"NSLayoutManager"];
	[self setTextView:[coder decodeObjectForKey:@"NSTextView"]];
#if 0
	NSLog(@"%@ done", self);
#endif
	return self;
}

@end
