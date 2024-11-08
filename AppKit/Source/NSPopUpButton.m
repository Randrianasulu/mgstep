/*
   NSPopUpButton.m

   Popup list control

   Copyright (C) 1999-2016 Free Software Foundation, Inc.

   Author:	Michael Hanni <mhanni@sprintmail.com>
   Date:	June 1999
   Rewrite: Felipe A. Rodriguez <far@illumenos.com>
   Date:    May 2016

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSException.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSEnumerator.h>

#include <CoreGraphics/CoreGraphics.h>
#include <CoreGraphics/Private/PSOperators.h>

#include <AppKit/NSPopUpButton.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSMenuItem.h>
#include <AppKit/NSEvent.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSFont.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSColor.h>



/* ****************************************************************************

		Private _PopUpButtonView, _PopUpButtonWindow

** ***************************************************************************/

@interface _PopUpButtonView : NSView
{
	NSPopUpButton *_owner;
	NSSize _cellSize;
}

- (id) initWithFrame:(NSRect)rect owner:(NSPopUpButton *)aOwner;
- (NSPopUpButton *) _popUpButton;

@end

@implementation _PopUpButtonView

- (id) initWithFrame:(NSRect)rect owner:(NSPopUpButton *)aOwner
{
	if ((self = [super initWithFrame: rect]))
		{
		_owner = aOwner;
		_cellSize = rect.size;
		}

	return self;
}

- (void) mouseDown:(NSEvent*)event
{
	NSDate *distantFuture = [NSDate distantFuture];
	float height = [self frame].size.height;
	NSArray *items = [_owner itemArray];
	int itemsCount = [items count];
	NSPoint location;
	NSRect selectedCellRect;
	NSWindow *lastWindow;
	int index, prev;
	NSMenuItem *anItem;
	NSMenuItem *prevItem = nil;
	id cell = [_owner cell];
	NSEventType type = NSPeriodic;
	NSEvent *lastEvent = event;

	[self lockFocus];
  
	[NSEvent startPeriodicEventsAfterDelay: 0.05 withPeriod: 0.03];

	do {
		if (type != NSPeriodic)
			lastEvent = event;						// movement and real events
		else
			{
			location = [lastEvent locationInWindow];

			if ((lastWindow = [lastEvent window]) != _window)
				{
				if (type == NSSystemDefined)		// popup window focus lost
					break;

				location = [lastWindow convertBaseToScreen: location];
				location = [_window convertScreenToBase: location];
				}

//			NSLog(@"location = (%f, %f)", location.x, location.y);

			index = (height - location.y) / _cellSize.height;
			if ((index >= itemsCount) || (index < 0))
				{
				anItem = nil;
				index = [_owner indexOfSelectedItem];
				}
			else
				anItem = [items objectAtIndex:index];

			if (anItem != prevItem)
				{
				if (prevItem != nil)
					{									// Unselect previous cell
					[cell selectItemAtIndex: prev];
					[cell highlight:NO withFrame:selectedCellRect inView:self];
					[_window flushWindow];
					}

				if ((prevItem = anItem))				// select new menu item
					{
					float y = (itemsCount - index - 1) * _cellSize.height;

					selectedCellRect = (NSRect){{0, y}, _cellSize};
					[cell selectItemAtIndex: (prev = index)];
					[cell highlight:YES withFrame:selectedCellRect inView:self];
					[_window flushWindow];
			}	}	}

		event = [NSApp nextEventMatchingMask:NSAnyEventMask
					   untilDate:distantFuture 
					   inMode:NSEventTrackingRunLoopMode
					   dequeue:YES];
  		}
	while ((type = [event type]) != NSLeftMouseUp);

//	NSLog(@"index: %d\n", index);
	[NSEvent stopPeriodicEvents];
	[NSApp discardEventsMatchingMask:NSAnyEventMask beforeEvent:event];

	[cell selectItemAtIndex: index];
	[cell highlight: NO withFrame: selectedCellRect inView: self];
	[_window flushWindow];
	[_owner selectItemAtIndex: index];

    [_window orderOut:nil];
    [self unlockFocus];
}

- (void) drawRect:(NSRect)rect
{
	NSArray *items = [_owner itemArray];
	unsigned i, count = [items count];
	NSRect r = [self frame];
	id cell = [_owner cell];

	if (count)
		r.origin.y = _cellSize.height * (count - 1);
	r.size = _cellSize;

	for (i = 0; i < count; i++)
		{
		[cell selectItemAtIndex: i];
		[cell drawWithFrame:r inView:self];
		r.origin.y -= _cellSize.height;
		}
}

- (NSPopUpButton *) _popUpButton				{ return _owner; }
- (BOOL) acceptsFirstMouse:(NSEvent *)event		{ return YES; }

@end  /* _PopUpButtonView */


@interface  _PopUpButtonWindow : NSWindow
- (void) setMenu:(NSMenu *)menu;
@end

@implementation _PopUpButtonWindow

- (void) setMenu:(NSMenu *)menu			{ }
- (void) miniaturize:(id)sender			{ }

- (void) orderFront:(id)sender
{
	if (!sender)
		[super orderFront:sender];		// FIX ME should detect popup cell
}

@end

/* ****************************************************************************

		NSPopUpButtonCell

** ***************************************************************************/

@implementation NSPopUpButtonCell

- (id) initTextCell:(NSString *)string pullsDown:(BOOL)flag
{
	if ((self = [super init])) 		// FIX ME  [super initTextCell:string]
		_pbc.pullsDown = flag;

	_c.bordered = YES;
	_c.bezeled = YES;

	return self;
}

- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView*)view  
{
	float grays[] = { NSBlack, NSBlack, NSWhite, NSWhite, NSDarkGray, NSDarkGray };
	NSRect rect = cellFrame;
	NSRect r = NSDrawTiledRects(rect, rect, BUTTON_EDGES_NORMAL, grays, 6);
	NSPoint point;
	NSImage *image = nil;
	NSPopUpButton *pb = [(_PopUpButtonView*)view _popUpButton];

	if (_c.highlighted)
		[[NSColor whiteColor] set];
	else 
		[[NSColor lightGrayColor] set];  
	NSRectFill(r);
	
	point.y = rect.origin.y + (rect.size.height/2) + 4;
	point.x = rect.origin.x + 2;
	rect.origin = point;  
	
	PSsetgray(NSBlack);										// Draw the title
	
	if (view != pb)
		{													// View matrix
		NSMenuItem *mi = [[pb itemArray] objectAtIndex:_selectedIndex];

		[mi drawInteriorWithFrame:NSInsetRect(r, 3, 0) inView:view];
		_contents = [mi title];
		}
	else
		[super drawInteriorWithFrame:NSInsetRect(r, 2, 1) inView:view];

	rect.size.width = 15;                         			// calc image rect
	rect.size.height = cellFrame.size.height;
	rect.origin.x = NSMaxX(cellFrame) - (6 + 12);
	rect.origin.y = cellFrame.origin.y;

	if (_pbc.pullsDown)
		{
		if ([pb itemTitleAtIndex:0] == _contents)
			image = (_c.highlighted) ? [NSImage imageNamed:@"popUpDownH"]
									 : [NSImage imageNamed:@"popUpDown"];
		}
	else
		if ([pb titleOfSelectedItem] == _contents)
			image = [NSImage imageNamed:@"popUpPin"];

	if(image)
		{													// Draw the image
		NSSize size = [image size];
															
		rect.origin.x += (rect.size.width - size.width) / 2;
		rect.origin.y += (rect.size.height - size.height) / 2;
									
		[image compositeToPoint:rect.origin operation:NSCompositeSourceOver];
		}
}

- (void) setPullsDown:(BOOL)flag				{ _pbc.pullsDown = flag; }
- (BOOL) pullsDown								{ return _pbc.pullsDown; }

- (void) selectItemAtIndex:(int)index
{
	_selectedIndex = index;
}

@end  /* NSPopUpButtonCell */

/* ****************************************************************************

		NSPopUpButton

** ***************************************************************************/

@implementation NSPopUpButton

- (id) init
{
	return [self initWithFrame:(NSRect){{0,0},{20,20}} pullsDown:NO];
}

- (id) initWithFrame:(NSRect)frame
{
	return [self initWithFrame:frame pullsDown:NO];
}

- (id) initWithFrame:(NSRect)frame pullsDown:(BOOL)flag
{
	if (!_cell)
		_cell = [[NSPopUpButtonCell alloc] initTextCell:nil pullsDown:flag];

    if ((self = [super initWithFrame:frame]))
		{
		_PopUpButtonView *v;

		_items = [NSMutableArray new];
		_popUpWindow = [_PopUpButtonWindow alloc];
		_popUpWindow = [_popUpWindow initWithContentRect:frame
									 styleMask: NSBorderlessWindowMask
									 backing: NSBackingStoreBuffered
									 defer:YES
									 screen:nil];

		v = [[_PopUpButtonView alloc] initWithFrame:frame owner:self];
		[_popUpWindow setContentView: v];
		}
	else
		[_cell autorelease];

	return self;
}

- (void) dealloc
{
	[_cell release];
	[_items release];
	[_popUpWindow close];
	[super dealloc];
}

- (void) addItemWithTitle:(NSString *)title
{
	[self insertItemWithTitle:title atIndex:[_items count]];
	[self synchronizeTitleAndSelectedItem];
}

- (void) addItemsWithTitles:(NSArray *)itemTitles
{
	int i, count = [itemTitles count];

	for (i = 0; i < count; i++)
		[self addItemWithTitle:[itemTitles objectAtIndex:i]];
}

- (void) insertItemWithTitle:(NSString *)title atIndex:(unsigned int)index
{
	id c = [[NSMenuItem new] autorelease];

	[c setTitle: title];
	[c setHighlightsBy: NSChangeBackgroundCellMask];
	[_items insertObject:c atIndex:index];
	[self synchronizeTitleAndSelectedItem];
}

- (void) removeItemWithTitle:(NSString *)title
{
	NSInteger i = [self indexOfItemWithTitle:title];

	if (i != NSNotFound)
		[_items removeObjectAtIndex: i];
}

- (NSInteger) indexOfItemWithTitle:(NSString *)title
{
	int i, count = [_items count];

	for (i = 0; i < count; i++)
		if ([[[_items objectAtIndex:i] title] isEqual:title])
			return i;

	return NSNotFound;
}

- (void) removeItemAtIndex:(int)index	{ [_items removeObjectAtIndex:index]; }
- (void) removeAllItems					{ [_items removeAllObjects]; }
- (NSInteger) indexOfSelectedItem		{ return _selectedItem; }
- (NSInteger) numberOfItems				{ return [_items count]; }
- (NSArray *) itemArray					{ return _items; }

- (id <NSMenuItem>) itemAtIndex:(NSInteger)index
{
	return [_items objectAtIndex:index];
}

- (NSString *) itemTitleAtIndex:(int)index
{
	return [[_items objectAtIndex:index] title];
}

- (NSArray *) itemTitles
{
	int i, count = [_items count];
	NSMutableArray *titles = [NSMutableArray arrayWithCapacity:count];

	for (i = 0; i < count; i++)
		[titles addObject:[[_items objectAtIndex:i] title]];

	return titles;
}

- (id <NSMenuItem>) itemWithTitle:(NSString *)title
{
	NSInteger i = [self indexOfItemWithTitle:title];

	return (i != NSNotFound) ? [_items objectAtIndex:i] : nil;
}

- (id <NSMenuItem>) lastItem
{
	return ([_items count]) ? [_items lastObject] : nil;
}

- (id <NSMenuItem>) selectedItem
{
	return [_items objectAtIndex:_selectedItem];
}

- (NSString *) titleOfSelectedItem
{
	return [(NSMenuItem*)[self selectedItem] title];
}

- (void) selectItemAtIndex:(int)index
{
	if ((index >= 0) && (index < [_items count]))
		{
		_selectedItem = index;
		[self synchronizeTitleAndSelectedItem];
		}
}

- (void) selectItemWithTitle:(NSString *)title
{
	NSInteger i = [self indexOfItemWithTitle:title];

	if (i != NSNotFound)
		[self selectItemAtIndex: i];
}

- (void) setMenu:(NSMenu *)menu
{
	NSEnumerator *e = [[menu itemArray] objectEnumerator];
	NSMenuItem *mi;

	while((mi = [e nextObject]))
		{
		[mi setType: NSTextCellType];		// FIX ME show up as NSNullCellType
		[_items addObject:mi];
		}
	[self synchronizeTitleAndSelectedItem];

	[_cell setMenu: menu];
}

- (NSMenu *) menu								{ return [_cell menu]; }
- (void) setPullsDown:(BOOL)flag				{ [_cell setPullsDown: flag]; }
- (void) setAutoenablesItems:(BOOL)flag			{}
- (NSPopUpButton *) _popUpButton				{ return self; }
- (BOOL) autoenablesItems						{ return NO; }
- (BOOL) pullsDown								{ return [_cell pullsDown]; }

- (void) setTitle:(NSString *)aString
{
	NSInteger i = [self indexOfItemWithTitle:aString];

	if (i == NSNotFound)
		{
		[self addItemWithTitle:aString];
		i = [_items count];
		}
	[self selectItemAtIndex: i];
}

- (void) synchronizeTitleAndSelectedItem
{
	int i = ([_cell pullsDown]) ? 0 : _selectedItem;

	[_cell setTitle: [[_items objectAtIndex: i] title]]; 
}

- (void) mouseDown:(NSEvent*)event
{
	int count = MAX([_items count], 1);
	NSRect f = (NSRect){{0,0}, {NSWidth(_frame),(_frame.size.height * count)}};
	_PopUpButtonView *pbView = [_popUpWindow contentView];

    [_popUpWindow setFrame:f display:NO];

	if (![_cell pullsDown])
		{													// a pop up button
		NSRect r = [[_window contentView] convertRect:_frame fromView:self];
		NSPoint p = [_window convertBaseToScreen:r.origin];
									// This next operation takes into account 
		p.x -= _frame.origin.x;		// the frames preordained x and y, removing
		p.y -= _frame.origin.y + 1; // them leaves us flush with our button.

		p.y -= ((count - _selectedItem - 1) * _frame.size.height);

		[_popUpWindow setFrameOrigin: p];
		} 
	else 													// pull down button
		{
		NSPoint viewLocation = [_superview convertPoint:_frame.origin
										   toView:[_window contentView]];

		viewLocation = [_window convertBaseToScreen:viewLocation];
		viewLocation.y += _frame.size.height - 1 - [_popUpWindow frame].size.height;
		[_popUpWindow setFrameOrigin:viewLocation];
		}

	[_popUpWindow orderFront: nil];
	[_popUpWindow display];
	[pbView mouseDown:event];

	[self display];

	if ([_cell target] && [_cell action])
		[[_cell target] performSelector:[_cell action] withObject:self];
}

- (void) encodeWithCoder:(NSCoder*)aCoder
{
	[super encodeWithCoder: aCoder];
	
	[aCoder encodeObject: _items];
	[aCoder encodeValueOfObjCType: @encode(int) at: &_selectedItem];
}

- (id) initWithCoder:(NSCoder*)aDecoder
{
	[super initWithCoder: aDecoder];
	
	[aDecoder decodeValueOfObjCType: @encode(id) at: &_items];
	[aDecoder decodeValueOfObjCType: @encode(int) at: &_selectedItem];
	
	return self;
}

@end  /* NSPopUpButton */
