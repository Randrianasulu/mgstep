/*
	NSSearchField.m

	Text field control and cell classes

	Author:  Nikolaus Schaller <hns@computer.org>
	Date:    December 2004

	This file is part of the mGSTEP Library and is provided
	under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSException.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSBezierPath.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSGraphicsContext.h>
#include <AppKit/NSSearchField.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSButtonCell.h>
#include <AppKit/NSMenu.h>

// FIX ME: react on textChanged/didEndEditing of the NSText and send the Cell's action


@interface NSBezierPath (RoundedSearchBezel)

+ (NSBezierPath *) _bezierPathWithRoundedBezelInRect:(NSRect)r vertical:(BOOL)f;

@end

@implementation NSBezierPath (RoundedSearchBezel)
// this is a special case of _drawRoundedBezel:

	// // box with halfcircular rounded ends
+ (NSBezierPath *) _bezierPathWithRoundedBezelInRect:(NSRect)borderRect vertical:(BOOL)flag
{
//	return [self bezierPathWithRoundedRect:borderRect xRadius:flag? :borderRect.size.width/2.0 yRadius:flag?borderRect.size.height/2.0: ];
#if 1
	NSBezierPath *p=[self new];
	NSPoint point=borderRect.origin;
	float radius;
	borderRect.size.width-=1.0;
	borderRect.size.height-=1.0;
	if(flag)
		{ // vertical
		radius=borderRect.size.width*0.5;
		point.x+=radius;
		point.y+=radius;
		radius-=1.0;
		[p appendBezierPathWithArcWithCenter:point radius:radius startAngle:180.0 endAngle:360.0];	// bottom half-circle
		point.y+=borderRect.size.height-borderRect.size.width;
		[p appendBezierPathWithArcWithCenter:point radius:radius startAngle:0.0 endAngle:180.0];	// line to first point and top halfcircle
		}
	else
		{ // horizontal
		radius=borderRect.size.height*0.5;
		point.x+=radius;
		point.y+=radius;
		radius-=1.0;
		[p appendBezierPathWithArcWithCenter:point radius:radius startAngle:90.0 endAngle:270.0];	// left half-circle
		point.x+=borderRect.size.width-borderRect.size.height;
		[p appendBezierPathWithArcWithCenter:point radius:radius startAngle:270.0 endAngle:90.0];	// line to first point and right halfcircle
		}
	[p closePath];
	return [p autorelease];
#endif
}
@end


@implementation NSSearchFieldCell

- (id) initTextCell:(NSString *)aString
{
	if((self=[super initTextCell:aString]))
		{
		[self resetCancelButtonCell];
		[self resetSearchButtonCell];
		maxRecents=254;
		}
	return self;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_cancelButtonCell release];
	[_searchButtonCell release];
	[recentSearches release];
	[recentsAutosaveName release];
	[_menuTemplate release];
	[super dealloc];
}

- (id) copy
{
	NSSearchFieldCell *c = [super copy];

	c->_cancelButtonCell=[_cancelButtonCell copy];
	c->_searchButtonCell=[_searchButtonCell copy];
	c->_menuTemplate=[_menuTemplate retain];
	c->recentSearches=[recentSearches copy];
	c->recentsAutosaveName=[recentsAutosaveName retain];
	c->maxRecents=maxRecents;
	c->_sf = _sf;

	return c;
}

- (BOOL) isOpaque
{
	return [super isOpaque] && [_cancelButtonCell isOpaque] && [_searchButtonCell isOpaque];	// only if all components are opaque
}

- (NSRect) drawingRectForBounds:(NSRect)rect
{
	return NSInsetRect(rect, 0, 2);		// account for the cell's border type.
}

- (void) drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{ // draw components
	[super drawInteriorWithFrame:[self searchTextRectForBounds:cellFrame] inView:controlView];
	[_searchButtonCell setTransparent:NO];
	[_searchButtonCell drawInteriorWithFrame:[self searchButtonRectForBounds:cellFrame] inView:controlView];
	[_cancelButtonCell setTransparent:[[self stringValue] length] == 0];
	[_cancelButtonCell drawInteriorWithFrame:[self cancelButtonRectForBounds:cellFrame] inView:controlView];
}

- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
	NSGraphicsContext *ctxt=[NSGraphicsContext currentContext];
	NSBezierPath *p;
#if 0
	NSLog(@"%@ drawWithFrame:%@", self, NSStringFromRect(cellFrame));
#endif
	p=[NSBezierPath _bezierPathWithRoundedBezelInRect:cellFrame vertical:NO];	// box with halfcircular rounded ends
	[ctxt saveGraphicsState];
	[[NSColor whiteColor] set];
	[p fill];		// fill with background color
	[[NSColor blackColor] set];
	[p stroke];		// fill border
//	[p addClip];	// clip to contour				FIX ME path clip mgstep
	if(!_c.editing)
		[self drawInteriorWithFrame:cellFrame inView:controlView];
	[ctxt restoreGraphicsState];
}

- (BOOL) sendsWholeSearchString						{ return _sf.sendsWholeSearchString; }
- (void) setSendsWholeSearchString:(BOOL) flag		{ _sf.sendsWholeSearchString=flag; }
- (BOOL) sendsSearchStringImmediately 				{ return _sf.sendsImmediately; }
- (void) setSendsSearchStringImmediately:(BOOL)flag { _sf.sendsImmediately=flag; }

- (NSInteger) maximumRecents			{ return maxRecents; }
- (void) setMaximumRecents:(NSInteger)max
{
	if(max > 254) max=254;
	maxRecents=max;
}

- (NSArray *) recentSearches				{ return recentSearches; }
- (NSString *) recentsAutosaveName			{ return recentsAutosaveName; }
- (void) setRecentSearches:(NSArray *)s		{ ASSIGN(recentSearches, s); }
- (void) setRecentsAutosaveName:(NSString *)name	{ ASSIGN(recentsAutosaveName, name); }

- (NSMenu *) searchMenuTemplate				{ return _menuTemplate; }
- (void) setSearchMenuTemplate:(NSMenu *)m	{ ASSIGN(_menuTemplate, m); }

- (NSButtonCell *) cancelButtonCell			{ return _cancelButtonCell; }
- (void) setCancelButtonCell:(NSButtonCell *) cell; { ASSIGN(_cancelButtonCell, cell); }
- (NSButtonCell *) searchButtonCell			{ return _searchButtonCell; }
- (void) setSearchButtonCell:(NSButtonCell *) cell; { ASSIGN(_searchButtonCell, cell); }

- (void) resetCancelButtonCell;
{
	NSButtonCell *c= [[NSButtonCell alloc] init];
	[c setButtonType:NSMomentaryChangeButton];	// configure the button
	[c setBezelStyle:NSRegularSquareBezelStyle];	// configure the button
	[c setBordered:NO];
	[c setBezeled:NO];
	[c setEditable:NO];
	[c setImagePosition:NSImageOnly];
//	[c setAlignment:NSRightTextAlignment];
	[c setImage:[NSImage imageNamed:@"stop"]];
	[c setTarget:self];
	[c setAction:@selector(_cancel:)];
	[self setCancelButtonCell:c];
	[c release];
}

- (void) resetSearchButtonCell;
{
	NSButtonCell *c= [[NSButtonCell alloc] init];
	[c setButtonType:NSMomentaryChangeButton];	// configure the button
	[c setBezelStyle:NSRegularSquareBezelStyle];	// configure the button
	[c setBordered:NO];
	[c setBezeled:NO];
	[c setEditable:NO];
	[c setImagePosition:NSImageOnly];
	[c setImage:[NSImage imageNamed:@"search"]];
	[c setTarget:self];
	[c setAction:@selector(_search:)];
	[self setSearchButtonCell:c];
	[c release];
}

#define ICON_WIDTH	16

- (NSRect) cancelButtonRectForBounds:(NSRect) rect;
{
	rect.origin.x+=rect.size.width-(_searchButtonCell?(ICON_WIDTH+4.0):4.0);
	rect.size.width=_cancelButtonCell?ICON_WIDTH:0.0;
	return rect;
}

- (NSRect) searchButtonRectForBounds:(NSRect) rect;
{
	rect.origin.x+=4.0;
//	rect.size.height -= 2.0;
	rect.size.width=_searchButtonCell?ICON_WIDTH:0.0;
	return rect;
}

- (NSRect) searchTextRectForBounds:(NSRect) rect;
{
	NSRect r1=[self searchButtonRectForBounds:rect];
	NSRect r2=[self cancelButtonRectForBounds:rect];
	r1.origin.x+=r1.size.width+2.0;			// to the right of the search button
	r1.size.width=r2.origin.x-r1.origin.x-2.0;
	r1.size.height -= 2;
	return r1;
}

- (void) selectWithFrame:(NSRect)aRect					// similar to editWith-
				  inView:(NSView*)controlView	 		// Frame method but can
				  editor:(NSText*)textObject	 		// be called from more
				delegate:(id)anObject	 				// than just mouseDown
				   start:(int)selStart	 
				  length:(int)selLength
{ // constrain to visible text area
	[super selectWithFrame:[self searchTextRectForBounds:aRect]
					inView:controlView
					editor:textObject
				  delegate:anObject
					 start:selStart
					length:selLength];	// this will already post a NSTextDidChangeNotification notification!
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_textDidChange:) name:NSTextDidChangeNotification object:textObject];	// intercept text changes
}

- (void) endEditing:(NSText *) textObject
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSTextDidChangeNotification object:textObject];
	[super endEditing:textObject];
}

// FIXME:
// make cancel button send delete: message to responder chain
// make search button send action to target (or responder chain)
// make search button menu working

// called by special logic in NSTextField

- (void) _textDidChange:(NSNotification *) n
{ // make textChanged send action (unless disabled or too fast)
	NSText *text=[n object];
#if 1
	NSLog(@"NSSearchField textDidChange:%@", text);
#endif
	if(_sf.sendsWholeSearchString)
		return;	// ignore
#if 1
	NSLog(@"current text: %@", [text string]);
#endif
	[self setStringValue:[text string]]; // copy the current NSTextEdit string so that it can be read from the NSSearchFieldCell!
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(performClick:) object:_controlView];	// cancel previous performer so that we collect several key events
	[self performSelector:@selector(performClick:) withObject:_controlView afterDelay:0.5];	// start a new timeout
}

- (void) _cancel:(id) sender;
{ // user did choose the cancel button
	// how does this influence the fieldEditor?
	[self setStringValue:@""];
}

- (void) _search:(id) sender;
{ // did choose the search button (or typed enter)
	[self performClick:_controlView];
}

- (BOOL) trackMouse:(NSEvent *)event inRect:(NSRect)cellFrame ofView:(NSView *)controlView untilMouseUp:(BOOL)untilMouseUp
{ // check if we should forward to subcell
	NSPoint loc=[event locationInWindow];
	loc = [controlView convertPoint:loc fromView:nil];
	NSLog(@"NSSearchFieldCell trackMouse:%@ inRect:%@", NSStringFromPoint(loc), NSStringFromRect(cellFrame));
	if(NSMouseInRect(loc, [self cancelButtonRectForBounds:cellFrame], NO))
		return [_cancelButtonCell trackMouse:event inRect:cellFrame ofView:controlView untilMouseUp:untilMouseUp];
	if(NSMouseInRect(loc, [self searchButtonRectForBounds:cellFrame], NO))
		return [_searchButtonCell trackMouse:event inRect:cellFrame ofView:controlView untilMouseUp:untilMouseUp];
	// might check for searchtextRectForBounds
 	return [super trackMouse:event inRect:cellFrame ofView:controlView untilMouseUp:untilMouseUp];
}

- (void) encodeWithCoder:(NSCoder *) aCoder
{
	NIMP;
}

- (id) initWithCoder:(NSCoder *) aDecoder
{
	self=[super initWithCoder:aDecoder];
	if(![aDecoder allowsKeyedCoding])
			{ [self release]; return nil; }
#if 0
	NSLog(@"%@ initWithCoder:%@", self, aDecoder);
#endif
	return self;
}

@end /* NSSearchFieldCell */

@implementation NSSearchField

+ (Class) cellClass
{ 
	return [NSSearchFieldCell class]; 
}

+ (void) setCellClass:(Class)class
{ 
	[NSException raise:NSInvalidArgumentException
				format:@"NSSearchField only uses NSSearchFieldCells"];
}

- (NSArray *) recentSearches; { return [[self cell] recentSearches]; }
- (NSString *) recentsAutosaveName; { return [[self cell] recentsAutosaveName]; }
- (void) setRecentSearches:(NSArray *) searches; { [[self cell] setRecentSearches:searches]; }
- (void) setRecentsAutosaveName:(NSString *) name; { [[self cell] setRecentsAutosaveName:name]; }

// undocumented but needed to handle IB connections

- (NSMenu *) searchMenuTemplate; { return [[self cell] searchMenuTemplate]; }
- (void) setSearchMenuTemplate:(NSMenu *) menu; {  [[self cell] setSearchMenuTemplate:menu]; }

@end /* NSSearchField */
