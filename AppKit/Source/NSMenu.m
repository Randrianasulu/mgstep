/*
   NSMenu.m

   Application Menu classes

   Copyright (C) 1998-2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    July 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSString.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSRunLoop.h>

#include <CoreGraphics/CoreGraphics.h>
#include <CoreGraphics/Private/_CGFont.h>
#include <CoreGraphics/Private/PSOperators.h>

#include <AppKit/NSMenu.h>
#include <AppKit/NSScreen.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSEvent.h>
#include <AppKit/NSFont.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSButton.h>
#include <AppKit/NSCursor.h>
#include <AppKit/NSTextFieldCell.h>
#include <AppKit/NSColor.h>


#define CTX			((CGContext *)cx)
#define FONT		CTX->_gs->font
#define ASCENDER	CTX->_gs->ascender
#define DESCENDER	CTX->_gs->descender
#define ISFLIPPED	CTX->_gs->isFlipped

#define INTERCELL_SPACE		1


// Class variables
static BOOL __mouseIsDownInMenu  = NO;
static BOOL __userKeyEquivalents = YES;
static BOOL __menuBarVisible     = YES;
static NSFont *__menuFont = nil;
static Class __menuCellClass = Nil;
static float __titleHeight = 0;
static CGFloat __cellPad = 25;
static NSMenuItem *__separator = nil;
static int __maxBounds = 0;

static NSImage *__branchMenuCellH = nil;		// menu item drawing globals
static NSImage *__branchMenuCell;
static NSTextFieldCell *__titleCell = nil;


/* ****************************************************************************

		_NSMenuTitleView

** ***************************************************************************/

@interface _NSTitleView : NSView
@end

@interface _NSMenuTitleView : _NSTitleView
{
	NSMenu *_menu;
}

- (void) setMenu:(NSMenu *)menu;

@end


@implementation _NSMenuTitleView

+ (void) initialize
{
	if (self == [_NSMenuTitleView class])
		{
		__titleCell = [[NSTextFieldCell alloc] initTextCell:@""];
		[__titleCell setBordered:NO];
		[__titleCell setEditable:NO];
		[__titleCell setFont:[NSFont boldSystemFontOfSize: 12]];
		[__titleCell setTextColor:[NSColor whiteColor]];
		}
}

- (void) setMenu:(NSMenu*)menu
{
	ASSIGN(_menu, menu);
	[(NSWindow <_MenuTitle> *)_window setMenu:_menu];
}

- (NSString *) stringValue				{ return [_menu title]; }

- (void) drawRect:(NSRect)rect
{												
	NSRect titleRect = {{rect.origin.x + 3, rect.origin.y + 2},
						{rect.size.width - 4, rect.size.height - 4}};
	_CGDrawMenuTitleBar((CGContextRef)[_window graphicsContext], rect);
	[__titleCell takeStringValueFrom:self];
	[__titleCell drawInteriorWithFrame:titleRect inView:self];
}

- (void) mouseDown:(NSEvent*)event
{
	[[_menu menuCells] mouseDown:event];
}

@end /* _NSMenuTitleView */


@implementation NSMenuView

- (id) initWithFrame:(NSRect)rect
{
	if (self = [super initWithFrame:rect])
		{
		float minHeight = [__menuFont pointSize] - [__menuFont descender] + 6;

		while (_cellHeight < minHeight)
			_cellHeight += 10.0;
		_cells = [NSMutableArray new];
		_menuItem = [NSMenuItem new];
		}

	return self;
}

- (void) dealloc
{
	DBLog (@"NSMenuView of menu '%@' dealloc", [menu title]);
	[_cells release];
	[_menuItem release];
	[super dealloc];
}

- (id) copy
{
	NSMenuView *copy = [[NSMenuView alloc] initWithFrame:_frame];
	int i, count = [_cells count];

	DBLog (@"copy menu matrix of menu with title '%@'", [menu title]);
	for (i = 0; i < count; i++)
		{
		id cellCopy = [[[_cells objectAtIndex:i] copy] autorelease];

		[copy->_cells addObject:cellCopy];
		}

	copy->_cellHeight = _cellHeight;
	copy->_menu = _menu;

	return copy;
}

- (NSInteger) indexOfItemAtPoint:(NSPoint)point
{
	NSInteger count = [_cells count];
	NSInteger i;

	if (_mv.isHorizontal)
		{
		float x = 0;

		point.x -= _frame.origin.x;				// translate from window coords

		for (i = 0; i < count; i++)
			{
			id mi = [_cells objectAtIndex:i];
			NSString *s = [mi stringValue];
			float titleWidth = [__menuFont widthOfString: s];

			x += titleWidth + INTERCELL_SPACE + __cellPad;
			if (point.x < x)
				break;
			}
		}
	else
		i = (NSMaxY(_frame) - point.y) / (_cellHeight + INTERCELL_SPACE);

	return (i >= count) ? NSNotFound : i;
}

- (NSRect) rectOfItemAtIndex:(NSInteger)index
{
	float y;

	if (_mv.isHorizontal)
		{
		float titleWidth = 0;
		float x = 0;
		int i;

		for (i = 0; i <= index; i++)
			{
			id mi = [_cells objectAtIndex:i];
			NSString *s = [mi stringValue];

			x += titleWidth;
			titleWidth = [__menuFont widthOfString: s];
			titleWidth += INTERCELL_SPACE + __cellPad;
			}

		return (NSRect){{x,0},{titleWidth, _cellHeight}};
		}

	y = (([_cells count] - index - 1) * (_cellHeight + INTERCELL_SPACE));

	return (NSRect){{0,y},{NSWidth(_bounds), _cellHeight}};
}

- (void) setHorizontalEdgePadding:(CGFloat)pad	{ __cellPad = pad; }
- (CGFloat) horizontalEdgePadding				{ return __cellPad; }
- (float) cellHeight							{ return _cellHeight; }
- (NSArray*) itemArray							{ return _cells; }
- (BOOL) isOpaque								{ return YES; }
- (NSMenu *) menu								{ return _menu; }
- (void) setMenu:(NSMenu*)anObject				{ _menu = anObject; }
- (void) setSelectedCell:(id)aCell				{ selectedCell = aCell; }
- (id) selectedCell								{ return selectedCell; }
- (NSRect) selectedCellRect						{ return selectedCellRect; }
- (BOOL) isHorizontal							{ return _mv.isHorizontal; }

- (void) setHorizontal:(BOOL)flag
{
	int i, count = [_cells count];

	_mv.isHorizontal = flag;
	_cellHeight = NSHeight(_bounds);

	for (i = 0; i < count; i++)
		[[_cells objectAtIndex:i] setHorizontal: flag];
}

- (void) drawRect:(NSRect)rect
{
	int i, count = [_cells count];
	float y = ((count - 1) * (_cellHeight + INTERCELL_SPACE));
	NSRect r = (NSRect){{0,y},{NSWidth(_bounds), _cellHeight}};
	NSRect intersect;

	if (_mv.isHorizontal)
		{
		r = (NSRect){{0,0},{NSWidth(_bounds), _cellHeight}};

		if (NSWidth(_bounds) == NSWidth(rect))
			[_menuItem drawWithFrame:_bounds inView:self];		// draws bevel

		intersect = NSIntersectionRect(r, rect);
		if (NSWidth(intersect) > 0 && NSHeight(intersect) > 0)
			for (i = 0; i < count; i++)
				{
				id mi = [_cells objectAtIndex:i];
				NSString *s = [mi stringValue];
				float titleWidth = [__menuFont widthOfString: s];

				r.size.width = titleWidth + INTERCELL_SPACE + __cellPad;
				if (NSMinX(r) >= NSMinX(intersect) && NSMinX(r) < NSMaxX(intersect))
					[mi drawWithFrame:r inView:self];
				r.origin.x += r.size.width;
				if (NSMinX(r) > NSMaxX(intersect))
					break;
				}
		return;
		}

	r.origin.y = NSHeight(_bounds) - _cellHeight;
	for (i = 0; i < count; i++)
		{
		intersect = NSIntersectionRect(r, rect);

		if (NSWidth(intersect) > 0)
			[[_cells objectAtIndex:i] drawWithFrame:r inView:self];
		r.origin.y -= _cellHeight + INTERCELL_SPACE;
		}
}

- (BOOL) _processEvent:(NSEvent*)event level:(int)level until:(NSDate*)aDate
{
	BOOL newlySelected = (selectedCell == nil);
	BOOL menuIsOffScreen, done = NO;
	BOOL outside = NO;
	int menuWasMoved = 0;
	NSInteger index = selectedCellIndex;
	NSRect windowFrame;
	NSWindow *lastWindow;
	float mousex = 0;

	if (_mv.isHorizontal || (level == 1 && __maxBounds))
		__maxBounds = NSMaxY(_bounds);		// 1st sub menu of horz menu sets
	else if (level == 0)					// point at which mouse is back in
		__maxBounds = 0;					// horz menu

	if((lastWindow = [event window]) != _window)
		windowFrame = [_window frame];
	else
		windowFrame = [lastWindow frame];
	menuIsOffScreen = (NSMinY(windowFrame) <= 0);

//	NSLog(@"Win loc = (%f, %f)", NSMinX(windowFrame), NSMinY(windowFrame));
	[self lockFocus];

	while (!done)
		{
		NSPoint lastPoint = [event locationInWindow];
		BOOL shouldGetAnotherEvent = YES;
		unsigned int mask = NSPeriodicMask;

		if((lastWindow = [event window]) != _window)
			{
			lastPoint = [lastWindow convertBaseToScreen:lastPoint];
			lastPoint = [_window convertScreenToBase:lastPoint];
			}								// Convert point from the event's
											// window to our window.  For main
		if(menuIsOffScreen)					// menu's window they are the same
			{
			static NSEvent *previous = nil;

			if(menuWasMoved && previous == event)
				lastPoint.y -= (5 * menuWasMoved);
			previous = event;
			if(lastPoint.y + NSMinY(windowFrame) <= 2)
				{
				NSMinY(windowFrame) += 5;
				lastPoint.y -= 5;
				[_window setFrameOrigin:windowFrame.origin];
				menuIsOffScreen = (NSMinY(windowFrame) <= 0);
				menuWasMoved++;
				}
			else
				menuWasMoved = 0;
			}

//		NSLog(@"location = (%f, %f)", lastPoint.x, lastPoint.y);

		if (lastPoint.x >= 0 && (!__maxBounds || lastPoint.y <= __maxBounds))
			{	// mouse may be inside our window or one of our attached menus
			if (lastPoint.x < NSWidth(_bounds))
				{				// mouse may be inside our window check y coord
				if (lastPoint.y >= NSMinY(_frame) && lastPoint.y < NSMaxY(_frame))
					{			// mouse is inside our window.  Determine cell
								// if between cells assume it's on upper cell
					index = [self indexOfItemAtPoint: lastPoint];
								// if no selected cell or newly selected cell
					if (index != NSNotFound)
					  if (!selectedCell || ((selectedCellIndex != index)
							&& ((lastPoint.x < (mousex + 4)))))
						{						// and NOT diagonal dragging
						BOOL needsFlush = NO;	// into a submenu
						id aCell = [_cells objectAtIndex:index];
												// deselect previous selected
						if (selectedCell) 		// cell and close its submenu
							{					// if it has one	
							if (_mv.selectedCellHasSubmenu)
								[_selectedCellTarget close];

							[selectedCell highlight:NO
										  withFrame:selectedCellRect
										  inView:self];
							selectedCell = nil;
							needsFlush = YES;
							}
						if([aCell isEnabled])			// select new selected
							{							// cell if enabled
							selectedCellIndex = index;
							selectedCell = aCell;
							_mv.selectedCellHasSubmenu = [aCell hasSubmenu];
							_selectedCellTarget = [aCell target];
							selectedCellRect = [self rectOfItemAtIndex:index];
							[selectedCell highlight:YES 
										  withFrame:selectedCellRect
										  inView:self];
							[_window flushWindow];			// If selected cell
							if(_mv.selectedCellHasSubmenu)	// has submenu open
								[_selectedCellTarget display];
							newlySelected = YES;
							needsFlush = NO;
							}
						if(needsFlush)
							[_window flushWindow];
						}
					mousex = lastPoint.x;
					}
				else
					outside = YES;
				}
			else
				outside = YES;

			if (outside)						// The mouse could be in one of
				{								// the right attached menus.
				NSMenu *attachedMenu = [_menu attachedMenu];

				outside = NO;
				if (attachedMenu)				// if menu has attached menu go
					{							// down one level and check it
					id menuCells = [attachedMenu menuCells];
					int j = level + 1;

					if ([menuCells _processEvent:event level:j until:aDate])
						{
						[self unlockFocus];

						return YES;				// mouse went up in submenu
						}
					}							// mouse exited submenu (NO)

				if (selectedCell)
					{
					if (attachedMenu)
						[attachedMenu close];

					[selectedCell highlight:NO
								  withFrame:selectedCellRect
								  inView:self];
					selectedCell = nil;
					[_window flushWindow];
			}	}	}
		else 								// mouse is left of or above menu
			{								// Close the current menu window
			if (level)
				{
				if (selectedCell)
					{
					[selectedCell highlight:NO
								  withFrame:selectedCellRect
			      				  inView:self];
					[_menu close];
  					[_window flushWindow];
					selectedCell = nil;
					}
				[self unlockFocus];

				return NO;								// return from submenu
			}	}
														// reverse process if
		if(menuIsOffScreen && menuWasMoved)				// menu is off-screen
			mask = (_NSTrackingLoopMask | NSRightMouseUpMask
						| NSRightMouseDraggedMask);
		while (shouldGetAnotherEvent)
			{											// Get the next event
			NSEvent *e = [NSApp nextEventMatchingMask:mask
								untilDate:aDate
								inMode:NSEventTrackingRunLoopMode
								dequeue:YES];
			switch ([e type])
				{
				case NSPeriodic:
					if (mask != NSPeriodicMask && selectedCellIndex != index)
						{
						index = selectedCellIndex;		// if no movement in 2x
						shouldGetAnotherEvent = NO;		// period selected cell
						}								// should reflect index
					mask = (_NSTrackingLoopMask | NSRightMouseUpMask
							| NSRightMouseDraggedMask);
					if(menuIsOffScreen && menuWasMoved)
						shouldGetAnotherEvent = NO;
					break;
				case NSMouseMoved:
				case NSRightMouseUp:					// right mouse up or
				case NSLeftMouseUp:						// left mouse up means
					done = YES;							// we're done
				default:
					event = e;
					if(!(menuIsOffScreen && menuWasMoved))
						shouldGetAnotherEvent = NO;
					break;
		}	}	}

	[NSEvent stopPeriodicEvents];	// ** reached only if mouse went up in cell
	
	if (![selectedCell hasSubmenu])
		{
		SEL action = [selectedCell action];
		id target = [selectedCell target];

		[selectedCell highlight:NO withFrame:selectedCellRect inView:self];

		if (action)										// Send the menu item's
			{											// action to its target
			if (!target || ![target respondsToSelector:action])
				target = [NSApp targetForAction:action];

			if ([NSApp modalWindow])					// handle modal session
				[target performSelector:action
						withObject:selectedCell
						afterDelay:0
						inModes: [NSArray arrayWithObjects: NSModalPanelRunLoopMode, nil]];
			else
				[target performSelector:action withObject:selectedCell afterDelay:0];
			}
		selectedCell = nil;
		}							// Set the state of the selected cell, if 1
	else 							// this indicates the submenu is opened.
		{
		if (newlySelected == NO)
			{
			[selectedCell highlight:NO withFrame:selectedCellRect inView:self];
			if (_mv.isHorizontal)
				[self drawRect: selectedCellRect];
			[_window flushWindow];
			[[selectedCell target] close];
			selectedCell = nil;
    		}
    	else
      		[selectedCell highlight:YES withFrame:selectedCellRect inView:self];
    	}

	[_window flushWindow];
	[self unlockFocus];

	return YES;
}

- (void) mouseDown:(NSEvent*)event
{
	__mouseIsDownInMenu = YES;
	if (!_mv.isHorizontal)
		[self setNeedsDisplay: YES];
	[_menu update];
	[NSEvent startPeriodicEventsAfterDelay:0.03 withPeriod:0.02];
	[self _processEvent:event level:0 until:[NSDate distantFuture]];
	__mouseIsDownInMenu = NO;
	if (_mv.isHorizontal)
		[[_menu menuTitleView] display];
}

- (void) rightMouseDown:(NSEvent*)event
{
	[[NSCursor arrowCursor] push];
	[self mouseDown:event];
	[_menu close];									// if trigger event was a
	[NSCursor pop];									// right mouse, close menu
}

- (CGImage *) _menuTexture:(NSSize)cf
{
	return (NSEqualSizes(cf, _textureSize)) ? _texture : NULL;
}

- (void) cacheMenuTexture:(CGImage *)tx withSize:(NSSize)cf
{
	if (_texture)
		CGImageRelease(_texture);
	_texture = tx;					// FIX ME s/b CGImageRetain(tx)
	_textureSize = cf;
}

@end /* NSMenuView */


@interface NSMenuView  (XRMenuTitleView)

- (CGImage *) _menuTexture:(NSSize)cf;
- (void) cacheMenuTexture:(CGImage *)tx withSize:(NSSize)cf;

@end

/* ****************************************************************************

		Private _MenuWindow

** ***************************************************************************/

@interface _MenuWindow : NSWindow
{
	NSMenu *_menu;
}

@end

@implementation _MenuWindow				

- (void) setFrameTopLeftPoint:(NSPoint)xOrigin
{
	NSMenu *attachedMenu;

	[super setFrameTopLeftPoint: xOrigin];
															// Move attached
	if ((attachedMenu = [_menu attachedMenu])) 				// menus if any
		{
		xOrigin.x = NSMaxX(_frame) + 1;
		[[attachedMenu _menuWindow] setFrameTopLeftPoint: xOrigin];
		}
}

- (void) setMenu:(NSMenu*)aMenu			{ _menu = aMenu; }
- (void) miniaturize:(id)sender			{ }

- (void) sendEvent:(NSEvent *)event
{
	if ([event type] == NSLeftMouseDown)
		[[_contentView hitTest:[event locationInWindow]] mouseDown:event];
}

- (void) displayIfNeeded
{
	if (_w.needsDisplay)
		[super displayIfNeeded];

	if (!_w.visible)
		{
		if (NSMinY(_frame) == 0 && NSMinX(_frame) == 0)
			{
			float top = NSHeight([[NSScreen mainScreen] frame]);

			[self setFrameTopLeftPoint:(NSPoint){0,top}];
			}

		[self orderFront:nil];
		}
}

@end  /* _MenuWindow */

/* ****************************************************************************

		NSMenuItem

** ***************************************************************************/

@implementation NSMenuItem

+ (void) initialize
{
	if (!__branchMenuCellH)
		{
		__branchMenuCell = [[NSImage imageNamed: @"menuRight"] retain];
///		__branchMenuCellH = [[__branchMenuCell copy] setName: @"menuRightH"];
		__branchMenuCellH = [[NSImage imageNamed:@"menuRightH"] retain];
		}
}

+ (void) setUsesUserKeyEquivalents:(BOOL)flag  { __userKeyEquivalents = flag; }
+ (BOOL) usesUserKeyEquivalents				   { return __userKeyEquivalents; }

+ (NSMenuItem *) separatorItem
{
	return (__separator) ? __separator : (__separator = [self new]);
}

+ (id <NSMenuItem>) _menuItemWithTitle:(NSString*)aString
							    action:(SEL)aSelector
							    keyEquivalent:(NSString*)charCode
{
	NSMenuItem *item = [[__menuCellClass new] autorelease];

	item->_contents = [aString retain];
	item->action = aSelector;
	item->_keyEquivalent = [charCode copy];

	return item;
}

- (id) initWithTitle:(NSString *)t action:(SEL)a keyEquivalent:(NSString *)code
{
	_c.enabled = YES;
	_c.bezeled = YES;
	_contents = [t retain];
	_keyEquivalent = [code copy];							// char code
	action = a;
	_font = [__menuFont retain];
	_c.type = NSTextCellType;
	_c.alignment = NSLeftTextAlignment;

	return self;
}

- (id) init
{
	return [self initWithTitle:nil action:0 keyEquivalent:nil];
}

- (void) dealloc
{
	DBLog (@"NSMenuItem '%@' dealloc", [self title]);

	if (self == __separator)
		return;
	if (_mi.hasSubmenu)
		[target release];

	[super dealloc];
}

- (id) copy
{
	NSMenuItem *copy = [super copy];

	if (_mi.hasSubmenu)
		{												// recursive call to
		copy->target = [target copy];					// create submenus
		copy->_c.highlighted = NO;					
		copy->_mi.hasSubmenu = _mi.hasSubmenu;
		}

	return copy;
}

- (NSMenu *) submenu				{ return (NSMenu *)target; }
- (NSMenu *) menu					{ return _menu; }
- (void) setMenu:(NSMenu *)menu		{ ASSIGN(_menu, menu); }
- (BOOL) hasSubmenu					{ return _mi.hasSubmenu; }
- (BOOL) isEnabled					{ return _mi.hasSubmenu ? YES : _c.enabled; }
- (BOOL) isSeparatorItem			{ return (self == __separator); }
- (void) setState:(int)value		{ _c.highlighted = _c.state = value; }
- (void) setHorizontal:(BOOL)flag	{ _mi.isHorizontal = flag; }
- (void) setRepresentedObject:(id)o	{ ASSIGN(_representedObject, o); }
- (id) representedObject			{ return _representedObject; }

- (NSString *) keyEquivalent
{
	if (__userKeyEquivalents)
		return [self userKeyEquivalent];

	return [super keyEquivalent];
}

- (NSString *) userKeyEquivalent
{
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	NSDictionary *d = [ud persistentDomainForName:NSGlobalDomain];
	NSDictionary *k = [d objectForKey:@"NSCommandKeys"];
	NSString *userKeyEquivalent = [k objectForKey:[self stringValue]];

	return (userKeyEquivalent) ? userKeyEquivalent : [super keyEquivalent];
}

- (void) setTarget:(id)obj								// Target / Action
{
	if (_mi.hasSubmenu)
		[target release];
	if ((_mi.hasSubmenu = (obj && [obj isKindOfClass:[NSMenu class]])))
		[obj retain];
	target = obj;
}

@end  /* NSMenuItem */

/* ****************************************************************************

		NSMenu

** ***************************************************************************/

@implementation NSMenu

+ (void) initialize
{
	__menuCellClass = [NSMenuItem class];
	__menuFont = [[NSFont systemFontOfSize:0] retain];
}

+ (BOOL) menuBarVisible					{ return __menuBarVisible; }
+ (void) setMenuBarVisible:(BOOL)v		{ __menuBarVisible = v; }
+ (void) setCellClass:(Class)aClass		{ __menuCellClass = aClass; }
+ (Class) cellClass						{ return __menuCellClass; }
+ (NSView *) _newMenuTitleView			{ return [_NSMenuTitleView new]; }

+ (void) popUpContextMenu:(NSMenu*)m withEvent:(NSEvent*)e forView:(NSView*)v
{
	NSPoint p = [NSEvent mouseLocation];

	p.y = NSHeight([[NSScreen mainScreen] frame]) - p.y;
//	NSLog(@" PopUp Context Menu loc = (%f, %f)",p.x, p.y);
	[[m _menuWindow] setFrameTopLeftPoint:p];
	[m update];
	[m display];
}

- (id) init								{ return [self initWithTitle:nil]; }

- (void) _initWindowFrame:(NSRect)menuWin
{						
	NSView *cv;

	NSLog (@"create menu window '%@', frame = (%f, %f, %f, %f)",
				[self title], menuWin.origin.x, menuWin.origin.y,
				menuWin.size.width, menuWin.size.height);

	if (_mn.isHorizontal)
		menuWin.origin.y = [[NSScreen mainScreen] frame].size.height - 20;

	[(window = [_MenuWindow alloc]) initWithContentRect:menuWin
									styleMask:NSBorderlessWindowMask
									backing:NSBackingStoreRetained
									defer:NO
									screen:nil];
	if (_mn.isHorizontal)
		{
		[_menuView setFrameOrigin:NSMakePoint(5, 0)];
		[_menuView setFrameSize: NSMakeSize(menuWin.size.width - 5, __titleHeight)];
		}
	else
		[_menuView setFrameSize: menuWin.size];

	if (_mn.isHorizontal)
		{
		float f = [__menuFont widthOfString: _title] + __cellPad;

		[_titleView setFrameOrigin:NSMakePoint(0, 0)];
		[_titleView setFrameSize: NSMakeSize(f, __titleHeight)];
		}

	[(cv = [window contentView]) addSubview:_menuView];
	 if (!_supermenu && _mn.isHorizontal)
		[cv addSubview:_titleView];

	_mn.menuChangedMessagesEnabled = YES;
}

- (id) initWithTitle:(NSString*)aTitle
{						
	ASSIGN(_title, aTitle);
	_menuView = [[NSMenuView alloc] initWithFrame:(NSRect){{0,0},{80,20}}];
	[_menuView setMenu:self];
	_mn.autoenablesItems = YES;
	__titleHeight = 20;
	_titleView = [NSMenu _newMenuTitleView];
	[_titleView setFrameOrigin:NSMakePoint(0, 0)];
	[_titleView setFrameSize:NSMakeSize (20, __titleHeight)];
	[(NSView <_MenuTitle> *)_titleView setMenu:self];

	return self;
}

- (void) dealloc
{
	DBLog (@"NSMenu '%@' dealloc", _title);
	[_title release];
	[window release];

	[super dealloc];
}

- (id) copy
{
	NSMenu *copy = (NSMenu *)NSAllocateObject (isa);
	NSRect mframe = (NSRect){{0,0},{80,20}};
	NSArray *cells;
	int i, count;

	DBLog (@"copy menu with title '%@'", [self title]);

	copy->_title = [_title copy];
	copy->_menuView = [_menuView copy];
	[copy->_menuView setMenu:copy];
											// Change the supermenu object of
	cells = [copy->_menuView itemArray];	// the new cells to the new menu
	for (i = 0, count = [cells count]; i < count; i++)
		{
		id cell = [cells objectAtIndex:i];

		if ([cell hasSubmenu])
			{
			NSMenu *submenu = [cell target];

			submenu->_supermenu = copy;
			}
		}
	NSHeight(mframe) = ([_menuView cellHeight] + INTERCELL_SPACE) * count - INTERCELL_SPACE;

	[copy->_menuView setFrame:mframe];
	copy->_supermenu = _supermenu;
	copy->_attachedMenu = nil;
	copy->_mn = _mn;
	copy->_mn.isHorizontal = NO;							// menu needs update

	copy->_titleView = [NSMenu _newMenuTitleView];
	[(NSView <_MenuTitle> *)copy->_titleView setMenu:copy];
	
	[copy sizeToFit];
	[copy update];

	return copy;
}

- (void) addItem:(NSMenuItem *)item
{
//	NSLog(@"a addItem %@ - count %d", item, [item retainCount]);
	NSLog(@"nib addItem %@", [item title]);

	_mn.menuHasChanged = YES;
	[(NSMutableArray *)[_menuView itemArray] addObject:item];
	[(NSMenuItem *) item setMenu:self];

#if 0
	[[item submenu] setSupermenu:self]; // attach (submenu may be nil)
	if(_mn.menuChangedMessagesEnabled)	// FIX ME flag appears misused elsewhere
		{								// and is deprecated in OSX 10.6
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		NSNumber *n = [NSNumber numberWithInt:[_menuView count]-1];
		NSDictionary *d = [NSDictionary dictionaryWithObject:n
										forKey:@"NSMenuItemIndex"];
		[nc postNotificationName:NSMenuDidAddItemNotification
			object:self
			userInfo:d];
		}
#endif
}

- (NSMenuItem *) addItemWithTitle:(NSString*)aString
						   action:(SEL)aSelector
						   keyEquivalent:(NSString*)charCode
{
	id m = [__menuCellClass _menuItemWithTitle:aString
							action:aSelector
							keyEquivalent:charCode];
	_mn.menuHasChanged = YES;
	[(NSMutableArray *)[_menuView itemArray] addObject:m];

	return m;
}

- (NSMenuItem *) insertItemWithTitle:(NSString*)aString
							  action:(SEL)aSelector
							  keyEquivalent:(NSString*)charCode
							  atIndex:(unsigned int)index
{
	id m = [__menuCellClass _menuItemWithTitle:aString
							action:aSelector
							keyEquivalent:charCode];
	_mn.menuHasChanged = YES;							// menu needs update
	[(NSMutableArray*)[_menuView itemArray] insertObject:m atIndex:index];

	return m;
}

- (void) removeItem:(NSMenuItem *)anItem
{
	NSMutableArray *ia = (NSMutableArray *)[_menuView itemArray];
	NSInteger row = [ia indexOfObject:anItem];

	if (row == NSNotFound)
		return;

	[ia removeObjectAtIndex:row];
	_mn.menuHasChanged = YES;							// menu needs update
}

- (NSMenuItem *) itemWithTag:(int)aTag
{
	NSEnumerator *e = [[_menuView itemArray] objectEnumerator];
	NSMenuItem *m;

	while((m = [e nextObject]))
		if([m tag] == aTag)
			return m;

	return nil;
}

- (NSMenuItem *) itemWithTitle:(NSString*)aString
{
	NSEnumerator *e = [[_menuView itemArray] objectEnumerator];
	NSMenuItem *m;

	while((m = [e nextObject]))
		if([[m title] isEqual:aString])
			return m;

	return nil;
}

- (void) setTitle:(NSString*)aTitle
{
	ASSIGN(_title, aTitle);
///	[self sizeToFit];
}

- (NSString *) title						{ return _title; }
- (NSView *) menuTitleView					{ return _titleView; }
- (NSMenuView *) menuCells					{ return _menuView; }
- (CGFloat) menuBarHeight					{ return __titleHeight; }

- (id) initWithCoder:(NSCoder*)aDecoder		{ return self; }
- (void) encodeWithCoder:(NSCoder*)aCoder	{}
													// action assigned to menu
- (void) submenuAction:(id)sender			{}		// item's that open submenu
- (NSArray*) itemArray						{ return [_menuView itemArray]; }
- (NSMenu*) attachedMenu					{ return _attachedMenu; }
- (NSMenu*) supermenu						{ return _supermenu; }
- (void) setAutoenablesItems:(BOOL)flag		{ _mn.autoenablesItems = flag;}
- (BOOL) autoenablesItems					{ return _mn.autoenablesItems;}

- (BOOL) isAttached		
{ 
	return (_supermenu) && ([_supermenu attachedMenu] == self);
}

- (NSWindow *) _menuWindow
{
	if (!window)
		{
		[self update];
		[self sizeToFit];
		}

	return window;
}

- (NSPoint) locationForSubmenu:(NSMenu*)aSubmenu
{
	NSRect f = [window frame];
	NSRect submenuFrame = (aSubmenu) ? [aSubmenu->window frame] : NSZeroRect;
 
 	if (_mn.isHorizontal)
		{
		float mv = [_menuView frame].origin.x;

		if ([_menuView selectedCell])
			mv += [_menuView selectedCellRect].origin.x;
		else
			mv = 0;

	 	return (NSPoint){NSMinX(f) + mv, NSMinY(f) - 1 - NSHeight(submenuFrame)};
		}

  	return (NSPoint){NSMaxX(f) + 1, NSMaxY(f) - NSHeight(submenuFrame)};
}

- (void) setHorizontal:(BOOL)flag
{
	[_menuView setHorizontal: (_mn.isHorizontal = flag)];
}

- (void) update
{
	id cells;
	int i, count;

	if (!window)
		[self _initWindowFrame:(NSRect){{0,0}, {80, 100}}];

	if(!__mouseIsDownInMenu && (![window isVisible]))
		return;									// update only if win visible
												// unless mouse is down in menu
	cells = [_menuView itemArray];
	count = [cells count];
	_mn.menuChangedMessagesEnabled = NO;		// Temp disable menu auto dispy

	for (i = 0; i < count; i++)
		{
		NSMenuItem <NSMenuItem> *cell = [cells objectAtIndex: i];
		SEL action = [cell action];
		BOOL wasEnabled = [cell isEnabled];
		BOOL shouldBeEnabled = wasEnabled;
		id validator = nil;

		if ([cell hasSubmenu])					// Update submenu items if any
			{
			[[cell target] update];
			continue;
			}

		if (!action) 							// If there is no action there
			shouldBeEnabled = NO;				// can be no validator for cell
		else
			{
			validator = [cell target];
			if (!validator || ![validator respondsToSelector: action])
				validator = [NSApp targetForAction:action];	// go thru window
			}												// responder chain

		if (validator != nil)
			{ 
			if ([validator respondsToSelector: @selector(validateMenuItem:)])
				shouldBeEnabled = [validator validateMenuItem: cell];
			else
				shouldBeEnabled = YES;
			}
	
		if (shouldBeEnabled != wasEnabled)
			{
			[cell setEnabled: shouldBeEnabled];
			[_menuView setNeedsDisplayInRect: [_menuView rectOfItemAtIndex: i]];
		}	}

	_mn.menuChangedMessagesEnabled = YES;		// Reenable displaying of menus

	if (_mn.menuHasChanged)									// resize if menu
		[self sizeToFit];									// has been changed

	[_menuView displayIfNeeded];
	[[_menuView window] flushWindowIfNeeded];
}

- (BOOL) performKeyEquivalent:(NSEvent*)event
{
	NSString *ci;

	if ([event type] == NSKeyDown
			&& (ci = [event charactersIgnoringModifiers]) && [ci length])
		{
		id cells = [_menuView itemArray];
		int i, count = [cells count];
		unsigned int modFlags = [event modifierFlags];

		for (i = 0; i < count; i++) 
			{
			NSMenuItem <NSMenuItem> *c = [cells objectAtIndex:i];
	
			if ([c hasSubmenu]) 
				{
				if ([[c target] performKeyEquivalent:event])
					{
					if (![c isHighlighted])
						{
						NSRect b = [_menuView rectOfItemAtIndex:i];
					
						[_menuView lockFocus];
						[c highlight:YES withFrame:b inView:_menuView];
						[window flushWindow];
						[c highlight:NO withFrame:b inView:_menuView];
						[window flushWindow];
						[_menuView unlockFocus];
						}

					return YES;						// event has been handled
				}	}								// by a cell in submenu 
			else 	
				{
				if ([[c keyEquivalent] isEqual: ci])
					{
					SEL action = [c action];
					id target = [c target];
					NSRect b;
					
					if (window)
						{
						b = [_menuView rectOfItemAtIndex:i];
						[_menuView lockFocus];
						[c highlight:YES withFrame:b inView:_menuView];
						[window flushWindow];
						}

					if (action)
						{
						if (!target || ![target respondsToSelector:action])
							target = [NSApp targetForAction:action];

						[target performSelector:action withObject:c];
						}

					if (window)
						{
						[c highlight:NO withFrame:b inView:_menuView];
						[_menuView unlockFocus];
						}
	
					return YES;
		}	}	}	}

	return NO;
}

- (void) sizeToFit
{
	NSArray *cells = [_menuView itemArray];
	int i, count = [cells count];
	float tw = 15;
	NSRect f = (window) ? [window frame] : (NSRect){{0,0}, {80, 20}};

	if (!count)
		return;

	NSWidth(f) = [__menuFont widthOfString: _title] + __cellPad;
	for (i = 0; i < count; i++)							// calc max cell width
		{
		NSString *s = [[cells objectAtIndex:i] stringValue];
		float titleWidth = [__menuFont widthOfString: s];

		tw += titleWidth + __cellPad;
		NSWidth(f) = MAX(titleWidth + __cellPad + 10, NSWidth(f));
		}

	if (_mn.isHorizontal)
		f.size.width = tw;
	else
		NSHeight(f) = (([_menuView cellHeight] + INTERCELL_SPACE) * count) - INTERCELL_SPACE;

	[_menuView setFrameSize:f.size];					// resize frame to hold
	_mn.menuHasChanged = NO;							// all menu cells

	if (!_mn.isHorizontal)
		{
		[_titleView setFrameOrigin: (NSPoint){0,NSHeight(f) - __titleHeight}];
		[_titleView setFrameSize: NSMakeSize(NSWidth(f), __titleHeight)];
		}

	if (!window)
		[self _initWindowFrame:f];
	[window setFrame:f display:[window isVisible]];
}

- (void) setSubmenu:(NSMenu*)aMenu forItem:(NSMenuItem *)anItem
{
	[(NSMenuItem*)anItem setTarget:aMenu];
	[(NSMenuItem <NSMenuItem> *)anItem setAction:@selector(submenuAction:)];
	if (aMenu)
		aMenu->_supermenu = self;
	
	aMenu->_title = [[(NSMenuItem*)anItem title] retain];
	
	_mn.menuHasChanged = YES;
	if (_mn.menuChangedMessagesEnabled)
		[self sizeToFit];
}

- (void) display
{
	id selectedCell;

	if (!__menuBarVisible && !_supermenu)
		return;

	if (!window)
        [self sizeToFit];

	if (_mn.menuHasChanged)
        [self sizeToFit];

	if (_supermenu) 						// we are not main menu so query
		{									// super menu for our position
		[window setFrameOrigin:[_supermenu locationForSubmenu:self]];
		_supermenu->_attachedMenu = self;
		}

	if ((selectedCell = [_menuView selectedCell]))
		[[selectedCell target] display];

	[window displayIfNeeded];
}

- (void) close
{
	NSLog(@"NSMenu close");
	if (_supermenu && (_supermenu->_attachedMenu != self))
		return;
										// Close attached menus.  Recursive if
	if (_attachedMenu)					// attached menu has an attached menu
		[self _closeAttachedMenu: nil];

	[window orderOut:nil];
	if (_supermenu)
		_supermenu->_attachedMenu = nil;
}

- (void) _closeAttachedMenu:(NSEvent *)event
{
	if (_attachedMenu)
		{
		if (event && ([event window] == [_menuView window]))
			return;									// menu event, don't close
		if (event && ([event window] == [[_attachedMenu menuCells] window]))
			return;

		[_attachedMenu close];
		[_menuView lockFocus];
		[[_menuView selectedCell] highlight:NO
								  withFrame:[_menuView selectedCellRect]
								  inView:_menuView];
		[_menuView setSelectedCell:nil];
		[_menuView unlockFocus];
		if (_mn.isHorizontal)
			[_titleView display];
		}
}

@end  /* NSMenu */

/* ****************************************************************************

	NSMenuItem  (AXMenuItemDrawing)

** ***************************************************************************/

static void _DrawCellTexture(CGContextRef cx, CGImage *img, NSPoint p, NSRect r)
{
	CGContextSetBlendMode(cx, kCGBlendModeSourceAtop);
	_CGContextCompositeImage(cx, r, img);		// FIX ME  p is ignored
}

@implementation NSMenuItem  (AXMenuItemDrawing)

- (void) drawWithFrame:(NSRect)cf inView:(NSMenuView *)controlView
{
	CGContextRef cx = (CGContextRef)[[controlView window] graphicsContext];
	BOOL isEnabled = (_mi.hasSubmenu) ? YES : _c.enabled;
	NSImage *image = __branchMenuCell;
	NSPoint point;
	NSRect rect;

//	NSLog (@"NSMenuItem drawWithFrame %f %f %f %f *** ",
//			cf.origin.x, cf.origin.y, cf.size.width, cf.size.height);
	if ((int)cf.size.width <= 0)
		return;

	if (_c.highlighted && isEnabled)
		{
		static CGImage *img = NULL;
		static NSSize renderedSize = {0,0};

		if (!NSEqualSizes(cf.size, renderedSize))
			{
			NSRect ins = (NSRect){NSZeroPoint, cf.size};

			CGImageRelease(img);

			if ((img = (CGImage *)_CGContextCreateImage(cx, cf.size)) == NULL)
				return;
			if (_mi.isHorizontal)
				_CGBevelImage(img, NSInsetRect(ins, 0, 1), YES, NO);
			else
				_CGBevelImage(img, ins, YES, _c.bezeled);
			renderedSize = cf.size;
			}

		rect.origin = (NSPoint){cf.origin.x, cf.origin.y + 2};
		rect.size = (NSSize){cf.size.width, cf.size.height - 2};
		_DrawCellTexture(cx, img, (NSPoint){0,2}, rect);
		image = __branchMenuCellH;
		}
	else
		{
		if (_mi.isHorizontal)
			{
			CGImage *tx = [controlView _menuTexture: cf.size];
			NSRect cfi = NSInsetRect(cf, 0, 2);

			if (!tx)
				{			// FIX ME verify GC does not leak, s/b autoreleased
				CGContextRef gc = _CGRenderHorzMenu(cx, cf.size, NO);

				tx = (CGImage *)((CGContext *)gc)->_bitmap;
				[controlView cacheMenuTexture:tx withSize:cf.size];
				}
			cfi.size.height += 1;
			_DrawCellTexture(cx, tx, (NSPoint){0,2}, cfi);
			}
		else
			{
			CGImage *tx = [controlView _menuTexture: cf.size];

			if (!tx)
				{
				if (!_contents)
					{										// horizontal bezel
					CGContextRef gc = _CGRenderHorzMenu(cx, cf.size, _c.bezeled);

					tx = (CGImage *)((CGContext *)gc)->_bitmap;
					[controlView cacheMenuTexture:tx withSize:cf.size];
					}
				else										// vertical cell
					{
					CGContextRef gc = _CGRenderMenuCell(cx, cf.size, _c.bezeled);

					tx = (CGImage *)((CGContext *)gc)->_bitmap;
					[controlView cacheMenuTexture:tx withSize:cf.size];
					}
				}
			_DrawCellTexture(cx, tx, NSZeroPoint, cf);
			}
		}

	if (!_contents)
		return;

	PSsetgray(_c.enabled ? NSBlack : NSDarkGray);			// set text color

	cf = rect = NSInsetRect(cf, 1, 3);						// calc interior

	if(_font != FONT)										// if needed set 
		[_font set];										// the font

#ifdef FB_GRAPHICS
	point.y = rect.origin.y - (rect.size.height / 2.) + DESCENDER;
#else
	point.y = rect.origin.y;
#endif
    point.x = rect.origin.x + 2;							// calc the title's
	rect.origin = point;									// origin

	if (_c.imagePosition == NSImageLeft)					// hack FIX ME
		{
		rect.origin.x += 18;
		image = (_c.highlighted) ? _alternateImage : _normalImage;
		}

	{
	const char *str = [_contents cString];
	NSPoint p = rect.origin;

#ifdef FB_GRAPHICS
	p.y = NSMaxY(rect);
	if (!ISFLIPPED)
		p.y -= ((ASCENDER + DESCENDER) / 2);
#else
	p.y += DESCENDER;
#endif
	CGContextShowTextAtPoint(cx, p.x, p.y, str, strlen(str));	// draw title
	}

	if (_mi.isHorizontal)
		return;

	rect.size.width = 15;									// calc image rect
	rect.size.height = cf.size.height;
	if (_c.imagePosition == NSImageLeft)
		rect.origin.x = point.x;
	else
		rect.origin.x = NSMaxX(cf) - 16;
	rect.origin.y = cf.origin.y;

	if (_mi.hasSubmenu || _c.imagePosition != NSNoImage) 	// if submenu draw
		{													// arrow image
		if (image)
			{
			NSSize size = [image size];
			NSImageRep *bestRep = [image bestRepresentationForDevice:nil];
			NSRect dr;

			rect.origin.x += (rect.size.width - size.width) / 2.;
			rect.origin.y += (rect.size.height - size.height) / 2.;
			dr = (NSRect){rect.origin, size};

			CGContextDrawImage(cx, dr, [(NSBitmapImageRep *)bestRep CGImage]);
		}	}
	else
		{
		if (_keyEquivalent)								// key equivalent text
			{
			const char *s = [_keyEquivalent cString];
			float keyEquivWidth = _CGTextWidth((CGFont *)FONT, s, strlen(s));
			NSPoint p;

			if (keyEquivWidth < cf.size.width)
				point.x = NSMaxX(cf) - (5 + keyEquivWidth);
			else
				point.x = cf.origin.x + 2;
			p = rect.origin = point;
#ifdef FB_GRAPHICS
			p.y = NSMaxY(rect);
			if (!ISFLIPPED)
				p.y -= ((ASCENDER + DESCENDER) / 2);
#else
			p.y += DESCENDER;		// h too high, p & q too low
#endif
			if (*s == 'p' || *s == 'q')
				p.y += 1;
			CGContextShowTextAtPoint(cx, p.x, p.y, s, strlen(s));
		}	}
}

@end  /* NSMenuItem  (AXMenuItemDrawing) */
