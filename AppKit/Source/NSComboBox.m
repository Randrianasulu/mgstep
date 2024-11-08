/*
   NSComboBox.m

   Control which combines a textfield and a popup list.

   Copyright (C) 2000 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    June 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSAutoreleasePool.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSApplication.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSComboBox.h>
#include <AppKit/NSButtonCell.h>
#include <AppKit/NSScrollView.h>
#include <AppKit/NSTableView.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSCursor.h>
#include <AppKit/NSPanel.h>



@interface _CBTableView : NSTableView
@end

@implementation _CBTableView

- (BOOL) acceptsFirstMouse:(NSEvent *)event			{ return YES; }

- (void) mouseDown:(NSEvent*)event
{
	NSDate *df = [NSDate distantFuture];
	float height = [self frame].size.height;
	int itemsCount = [_dataSource numberOfRowsInTableView: self];
	NSUInteger cellHeight = height / itemsCount;
	NSPoint location;
	NSWindow *lastWindow;
	int index;
	int prev = [self selectedRow];
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

			index = (height - location.y) / cellHeight;
			if ((height - location.y) / cellHeight < 0.)
				index = -1;
			if ((index >= itemsCount) || (index < 0))
				index = [self selectedRow];
NSLog(@"Row %d  Prev %d", index, prev);

			if (index != prev)
				{
				[self selectRow:index byExtendingSelection:NO];
				if (prev != -1)
					{									// Unselect previous cell
					NSRect r = [self rectOfRow: prev];

					[_backgroundColor set];
					NSRectFill(r);
					[self drawRow:prev clipRect:r];
					[_window flushWindow];
					}
														// select new menu item
				NSRect r = [self rectOfRow: index];

NSLog(@"select Row %d", index);
				[self highlightSelectionInClipRect:r];
				[self drawRow:index clipRect:r];
				[_window flushWindow];
				[_dataSource setStringValue: [_dataSource tableView:self objectValueForTableColumn:nil row:index]];
				if (prev != -1)
					[_dataSource setState:0];
				prev = index;
			}	}

		event = [NSApp nextEventMatchingMask:NSAnyEventMask
					   untilDate:df
					   inMode:NSEventTrackingRunLoopMode
					   dequeue:YES];
  		}
	while ((type = [event type]) != NSLeftMouseUp);

	[NSEvent stopPeriodicEvents];
	[NSApp discardEventsMatchingMask:NSAnyEventMask beforeEvent:event];

	if (lastWindow == _window)
		[_window orderOut:nil];
    [self unlockFocus];
}

@end /* _CBTableView */


@implementation NSComboBoxCell (ComboBoxCellTableViewDataSource)

- (id) tableView:(NSTableView *)aTableView
	   objectValueForTableColumn:(NSTableColumn *)aTableColumn 
	   row:(int)row
{
    return [self itemObjectValueAtIndex: row];
}

- (int) numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [self numberOfItems];
}

@end


@implementation NSComboBoxCell

- (id) initTextCell:(NSString *)aString
{
	if (self = [super initTextCell:aString])
		{
		_buttonCell = [NSButtonCell alloc];
		[_buttonCell initImageCell: [NSImage imageNamed:@"comboBox"]];
		[_buttonCell setAlternateImage:[NSImage imageNamed:@"comboBox"]];
		[_buttonCell setButtonType: NSToggleButton];
		_popUpList = [NSMutableArray new];
		 _itemHeight = 18;
		 _intercellSpacing = (NSSize){2,2};
		 _visibleItems = 3;
		}

	return self;
}

- (void) dealloc
{
	[_dataSource release];
	[super dealloc];
}

- (void) setHasVerticalScroller:(BOOL)flag	{ _cbc.hasVerticalScroller = flag;}
- (void) setIntercellSpacing:(NSSize)aSize	{ _intercellSpacing = aSize; }
- (void) setItemHeight:(float)itemHeight	{ _itemHeight = itemHeight; }
- (void) setNumberOfVisibleItems:(int)v		{ _visibleItems = v; }
- (void) setUsesDataSource:(BOOL)flag		{ _cbc.usesDataSource = flag; }
- (BOOL) usesDataSource						{ return _cbc.usesDataSource; }
- (id) dataSource							{ return _dataSource; }

- (void) setDataSource:(id)aSource
{
	SEL a = @selector(numberOfItemsInComboBoxCell:);
	SEL b = @selector(comboBox:objectValueForItemAtIndex:);

	if (!_cbc.usesDataSource)
		NSLog(@"NSComboBoxCell is not configured for an internal datasource");

	if (![aSource respondsToSelector: a] || ![aSource respondsToSelector: b])
		NSLog(@"source does not implement NSComboBoxDataSource protocol");

	ASSIGN(_dataSource, aSource);

	if (!_tableView)
		_tableView = [[NSTableView alloc] init];
	[_tableView setDataSource: aSource];
}

- (void) selectItemAtIndex:(int)index
{
	[_tableView selectRow:index byExtendingSelection:NO];
}

- (void) deselectItemAtIndex:(int)index
{
	[_tableView deselectRow:index];
}

- (int) indexOfSelectedItem
{
	return [_tableView selectedRow];
}

- (int) numberOfItems
{
	if (_cbc.usesDataSource)
		return [_dataSource numberOfItemsInComboBoxCell: self];

    return [_popUpList count];
}

- (int) numberOfVisibleItems			{ return _visibleItems; }
- (BOOL) hasVerticalScroller			{ return YES; }
- (NSSize) intercellSpacing				{ return _intercellSpacing; }
- (float) itemHeight					{ return _itemHeight; }

- (void) addItemWithObjectValue:(id)object
{
	if (_cbc.usesDataSource)
		NSLog(@"NSComboBoxCell is not configured for an internal datasource");
	else
		[_popUpList addObject:object];
}

- (void) addItemsWithObjectValues:(NSArray *)objects
{
	if (_cbc.usesDataSource)
		NSLog(@"NSComboBoxCell is not configured for an internal datasource");
	else
		[_popUpList addObjectsFromArray: objects];
}

- (void) insertItemWithObjectValue:(id)object atIndex:(int)index
{
	if (_cbc.usesDataSource)
		NSLog(@"NSComboBoxCell is not configured for an internal datasource");
	else
		[_popUpList insertObject:object atIndex:index];
}

- (void) removeItemWithObjectValue:(id)object
{
	if (_cbc.usesDataSource)
		NSLog(@"NSComboBoxCell is not configured for an internal datasource");
	else
		[_popUpList removeObjectIdenticalTo:object];
}

- (void) removeItemAtIndex:(int)index
{ 
	if (_cbc.usesDataSource)
		NSLog(@"NSComboBoxCell is not configured for an internal datasource");
	else
		[_popUpList removeObjectAtIndex:index];
}

- (void) removeAllItems
{
	if (_cbc.usesDataSource)
		NSLog(@"NSComboBoxCell is not configured for an internal datasource");
	else
		[_popUpList removeAllObjects];
}

- (void) selectItemWithObjectValue:(id)object
{
	[self selectItemAtIndex: [self indexOfItemWithObjectValue:object]];
}

- (id) itemObjectValueAtIndex:(NSInteger)index
{
	if (_cbc.usesDataSource)
		return [_dataSource comboBoxCell:self objectValueForItemAtIndex:index];

    return [_popUpList objectAtIndex:index];
}

- (id) objectValueOfSelectedItem
{
	return [self itemObjectValueAtIndex: [_tableView selectedRow]];
}

- (NSInteger) indexOfItemWithObjectValue:(id)object
{
	NSInteger i = NSNotFound;

	if (_cbc.usesDataSource)
		NSLog(@"NSComboBoxCell is not configured for an internal datasource");
	else
		i = [_popUpList indexOfObject:object];

	return i;
}

- (void) reloadData							{ [_tableView reloadData]; }

- (void) noteNumberOfItemsChanged
{
}

- (void) scrollItemAtIndexToTop:(int)index
{
}

- (void) scrollItemAtIndexToVisible:(int)index
{
}

- (NSArray *) objectValues					{ return _popUpList; }

- (BOOL) trackMouse:(NSEvent *)event
			 inRect:(NSRect)cellFrame
			 ofView:(NSView *)controlView
			 untilMouseUp:(BOOL)flag
{
	NSWindow *w = [controlView window];
	NSRect b, t;
	NSPoint p;
	BOOL r;

	if (_c.editing)
		[self endEditing:[w fieldEditor:NO forObject:self]];

	[controlView lockFocus];
	NSDivideRect(cellFrame, &b, &t, 22, NSMaxXEdge);
	b = NSInsetRect(b, 2, 2);

	p = [controlView convertPoint:[event locationInWindow] fromView:nil];

	if ((r = NSMouseInRect(p, b, YES)))
		{
		[_buttonCell highlight:YES withFrame:b inView:controlView];
		[w flushWindow];

		NSPoint o = [controlView convertPoint:t.origin toView:nil];
		NSPoint l = [w convertBaseToScreen: o];
		float wh = (_itemHeight + _intercellSpacing.height);

		wh *= _visibleItems;				// combo win height
		l.y -= wh;

		if (!_popUpWindow)
			{
			NSRect f = {l,{NSWidth(cellFrame),wh}};
			NSTableColumn *tc = [NSTableColumn alloc];

			_popUpWindow = [NSPanel alloc];
			[_popUpWindow initWithContentRect:f
						  styleMask: NSBorderlessWindowMask
						  backing: NSBackingStoreRetained
						  defer:NO
						  screen:nil];
			[_popUpWindow setWorksWhenModal: YES];

			f.origin = NSZeroPoint;
			if (!_tableView)
				_tableView = [[_CBTableView alloc] initWithFrame:f];
			else
				[_tableView setFrame:f];
			[_tableView setBackgroundColor:[NSColor whiteColor]];
			[_tableView setHighlightColor: [NSColor cyanColor]];
			[_tableView setDataSource: self];
			[_tableView setAllowsColumnReordering:NO];
			[_tableView setAllowsColumnResizing:NO];
			[tc initWithIdentifier:@"ComboBoxCell"];
			[tc setWidth:NSWidth(t) + 7];
			[_tableView addTableColumn:tc];
			[_tableView setHeaderView:nil];
			[_tableView setTarget:controlView];
			[_tableView setAction:@selector(takeObjectValueFrom:)];
			_scrollView = [NSScrollView alloc];
			[_scrollView initWithFrame:f];
//				[_scrollView setHasHorizontalScroller:YES];
			[_scrollView setHasVerticalScroller:YES];
			[_scrollView setDocumentView:_tableView];
			[[_popUpWindow contentView] addSubview:_scrollView];
			[[_popUpWindow contentView] display];
			}
		else
			[_popUpWindow setFrameOrigin: l];
		
		[_tableView reloadData];
		[_tableView display];
		[_popUpWindow orderFront: nil];
		[_popUpWindow display];

		[self setState:![self state]];
		[_tableView mouseDown:event];
		}

	[_buttonCell highlight:NO withFrame:b inView:controlView];
	[w flushWindow];

	[controlView unlockFocus];

	if ([self state] == 0)
		[_popUpWindow orderOut:self];

	if ([_popUpWindow isVisible])
		{
		NSDate *df = [NSDate distantFuture];

		for (;;)
			{
			NSAutoreleasePool *pool = [NSAutoreleasePool new];
			NSEvent *e = [NSApp nextEventMatchingMask:NSAnyEventMask
								untilDate:df
								inMode:NSModalPanelRunLoopMode
								dequeue:YES];
			NSWindow *ew = [e window];
			NSEventType et = [e type];

			if (ew == _popUpWindow)
				{
				[_popUpWindow sendEvent: e];

				if (et == NSLeftMouseDown)
					e = nil;
				}
			else						// mouse not in popUpWindow
				{						// see if we need to abort
				if ((et != NSMouseMoved && et != NSSystemDefined
						&& et != NSAppKitDefined)
						|| (et == NSSystemDefined && ew == w))
					{
					BOOL repost = YES;	// NSSystemDefined informs
										// us control view window
					if (ew == w)		// has lost focus
						{
						NSPoint z = [e locationInWindow];		

						z = [controlView convertPoint:z fromView:nil];
						if (NSMouseInRect(z, b, YES))
							repost = NO;
						}				// do not repost if mouse
										// down in our button cell
					if (e && repost)
						[NSApp postEvent:e atStart:YES];
					e = nil;
				}	}

			[pool release];
			if (e == nil)
				break;
			}

		[_popUpWindow orderOut:self];
		}

	return r;
}

- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
	NSRect b, t;

	if (cellFrame.size.width <= 0 || cellFrame.size.height <= 0)
		return;

	_controlView = controlView;							// last view drawn in

	NSDivideRect(cellFrame, &b, &t, 22, NSMaxXEdge);
	[super drawWithFrame:cellFrame inView:controlView];

	b = NSInsetRect(b, 2, 2);
	[_buttonCell drawWithFrame:b inView:controlView];
}

@end /* NSComboBoxCell */


@implementation NSComboBox

+ (Class) cellClass						{ return [NSComboBoxCell class]; }

- (void) setHasVerticalScroller:(BOOL)f	{ [_cell setHasVerticalScroller:f]; }
- (void) setIntercellSpacing:(NSSize)s	{ [_cell setIntercellSpacing:s]; }
- (void) setItemHeight:(float)h			{ [_cell setItemHeight:h]; }
- (void) setNumberOfVisibleItems:(int)v	{ [_cell setNumberOfVisibleItems:v]; }
- (BOOL) hasVerticalScroller			{ return [_cell hasVerticalScroller]; }
- (NSSize) intercellSpacing				{ return [_cell intercellSpacing]; }
- (float) itemHeight					{ return [_cell itemHeight]; }
- (int) numberOfVisibleItems			{ return [_cell numberOfVisibleItems];}

- (void) reloadData
{
	[self setNeedsDisplay: YES];
}

- (void) noteNumberOfItemsChanged
{
}

- (void) scrollItemAtIndexToTop:(int)index
{
}

- (void) scrollItemAtIndexToVisible:(int)index
{
}

- (void) selectItemAtIndex:(int)index
{
}

- (void) deselectItemAtIndex:(int)index
{
}

- (int) indexOfSelectedItem				{ return [_cell indexOfSelectedItem]; }
- (int) numberOfItems					{ return [_cell numberOfItems]; }

- (void) setUsesDataSource:(BOOL)flag	{ [_cell setUsesDataSource:flag]; }
- (BOOL) usesDataSource					{ return [_cell usesDataSource]; }
- (id) dataSource						{ return [_cell dataSource]; }
- (void) setDataSource:(id)aSource		{ [_cell setDataSource:aSource]; }

- (void) addItemWithObjectValue:(id)o	{ [_cell addItemWithObjectValue:o]; }

- (void) addItemsWithObjectValues:(NSArray *)objects
{
	[_cell addItemsWithObjectValues:objects];
	[self setNeedsDisplay: YES];
}

- (void) insertItemWithObjectValue:(id)object atIndex:(int)index
{
	[_cell insertItemWithObjectValue:object atIndex:index];
}

- (void) removeItemWithObjectValue:(id)o{ [_cell removeItemWithObjectValue:o];}
- (void) removeItemAtIndex:(int)index	{ [_cell removeItemAtIndex:index]; }
- (void) removeAllItems					{ [_cell removeAllItems]; }
- (NSArray *) objectValues				{ return [_cell objectValues]; }

- (void) selectItemWithObjectValue:(id)object
{
	return [_cell selectItemWithObjectValue:object];
}

- (id) itemObjectValueAtIndex:(NSInteger)index
{
	return [_cell itemObjectValueAtIndex:index];
}

- (id) objectValueOfSelectedItem
{
	return [_cell objectValueOfSelectedItem];
}

- (NSInteger) indexOfItemWithObjectValue:(id)object
{
	return [_cell indexOfItemWithObjectValue:object];
}

- (void) mouseDown:(NSEvent*)event
{
	if (![_cell trackMouse:event inRect:_bounds ofView:self untilMouseUp:YES])
		{
		NSRect b, t, d = [_cell drawingRectForBounds:_bounds];

		NSDivideRect(d, &b, &t, 22, NSMaxXEdge);
		[_cell editWithFrame:t
			   inView:self			
			   editor:[_window fieldEditor:YES forObject:_cell]
			   delegate:self
			   event:event];
		}
}

- (void) setDelegate:(id)anObject
{
	NSNotificationCenter *n;

	if (_delegate == anObject)
		return;

#define IGNORE_(notif_name) [n removeObserver:_delegate \
							   name:NSComboBox##notif_name##Notification \
							   object:self]

	n = [NSNotificationCenter defaultCenter];
	if (_delegate)
		{
		IGNORE_(SelectionIsChanging);
		IGNORE_(SelectionDidChange);
		IGNORE_(WillDismiss);
		IGNORE_(WillPopUp);
		}

	if (!(_delegate = anObject))
		return;

#define OBSERVE_(notif_name) \
	if ([_delegate respondsToSelector:@selector(comboBox##notif_name:)]) \
		[n addObserver:_delegate \
		   selector:@selector(comboBox##notif_name:) \
		   name:NSComboBox##notif_name##Notification \
		   object:self]

	OBSERVE_(SelectionIsChanging);
	OBSERVE_(SelectionDidChange);
	OBSERVE_(WillDismiss);
	OBSERVE_(WillPopUp);
}

- (void) resetCursorRects								// Manage the cursor
{
	NSRect b, t;

	NSDivideRect(_bounds, &b, &t, 22, NSMaxXEdge);
	[self addCursorRect:t cursor:[NSCursor IBeamCursor]];
}

- (void) encodeWithCoder:(id)aCoder						// NSCoding protocol
{
	[super encodeWithCoder:aCoder];
}

- (id) initWithCoder:(id)aDecoder
{
	return [super initWithCoder:aDecoder];
}

- (void) takeObjectValueFrom:(id)sender					// override NSControl
{
	[_cell setObjectValue: [_cell objectValueOfSelectedItem]];
	[self setNeedsDisplay:YES];
}

@end /* NSComboBox */
