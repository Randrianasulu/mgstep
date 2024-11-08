/*
   NSTabView.m

   Tabbed view

   Copyright (C) 1996-2018 Free Software Foundation, Inc.

   Author:	Michael Hanni <mhanni@sprintmail.com>
   Date:	June 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSArray.h> 
#include <Foundation/NSString.h>

#include <CoreGraphics/CoreGraphics.h>
#include <CoreGraphics/Private/PSOperators.h>

#include <AppKit/NSColor.h>
#include <AppKit/NSEvent.h>
#include <AppKit/NSFont.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSTabView.h>


/* ****************************************************************************

 		NSTabViewItem

** ***************************************************************************/

@implementation NSTabViewItem

- (id) initWithIdentifier:(id)identifier
{
	if ((self = [super init]))
		{
		_identifier = [_identifier retain];
		_tabState = NSBackgroundTab;
		}
	
	return self;
}

- (void) dealloc
{
	[_identifier release];
	[_label release];
	[item_image release];
	[_color release];
	[_view release];
	[_tabView release];

	[super dealloc];
}

- (void) setIdentifier:(id)identifier		{ ASSIGN(_identifier, identifier); }
- (id) identifier							{ return _identifier; }
- (NSString *) label						{ return _label; }
- (void) setLabel:(NSString *)label			{ ASSIGN(_label, label); }
- (void) _setImage:(NSImage *)image			{ ASSIGN(item_image, image); }
- (NSImage *) _image;						{ return item_image; }

- (NSSize) sizeOfLabel:(BOOL)shouldTruncateLabel
{
	NSSize rSize;

	rSize.height = 12;

	if (shouldTruncateLabel) 
		rSize.width = [[_tabView font] widthOfString:_label];
	else 
		rSize.width = [[_tabView font] widthOfString:_label];

	if(item_image)
		rSize.width += [item_image size].width + 2;

	return rSize;
}
									// Set view to display when item is clicked
- (NSView *) view							{ return _view; }
- (void) setView:(NSView *)view				{ ASSIGN(_view, view); }
- (void) setColor:(NSColor *)color			{ ASSIGN(_color, color); }
- (NSColor *) color							{ return _color; }
- (NSTabState) tabState						{ return _tabState; }
- (void) _setTabState:(NSTabState)tabState	{ _tabState = tabState; }
- (NSRect) _tabRect							{ return item_rect; }		
									// Tab view, this is the "super" view.
- (void) _setTabView:(NSTabView *)tabView	{ ASSIGN(_tabView, tabView); }
- (NSTabView *) tabView						{ return _tabView; }
- (id) initialFirstResponder				{ return nil; }
- (void) setInitialFirstResponder:(NSView*)view			{}

- (void) drawLabel:(BOOL)shouldTruncateLabel inRect:(NSRect)tabRect
{
	NSRect lRect;
	NSRect fRect = tabRect;

	item_rect = tabRect;
	PSgsave();

	if (_tabState == NSSelectedTab) 
		{
		fRect.origin.y -= 1;
		fRect.size.height += 1;
		[[NSColor lightGrayColor] set];
		} 
	else 
		if (_tabState == NSBackgroundTab) 
			[[NSColor lightGrayColor] set];
		else 
			[[NSColor lightGrayColor] set];

	NSRectFill(fRect);

	lRect = tabRect;
	lRect.origin.y += 3;
	[[_tabView font] set];

	if(item_image)
		{
		[item_image compositeToPoint:(NSPoint){lRect.origin.x,lRect.origin.y+2} 
					operation: NSCompositeSourceOver];
		lRect.origin.x += [item_image size].width + 2;
		}

	PSsetgray(0);
	PSmoveto(lRect.origin.x, lRect.origin.y);
	PSshow([_label cString]);
	
	PSgrestore();
}

- (void) encodeWithCoder:(NSCoder*)aCoder				// NSCoding protocol
{
	[super encodeWithCoder: aCoder];
	
	[aCoder encodeObject:_identifier];
	[aCoder encodeObject:_label];
	[aCoder encodeObject:_view];
	[aCoder encodeObject:_color];
	[aCoder encodeValueOfObjCType: @encode(NSTabState) at: &_tabState];
	[aCoder encodeObject:_tabView];
}

- (id) initWithCoder:(NSCoder*)aDecoder
{
	[super initWithCoder: aDecoder];
	
	[aDecoder decodeValueOfObjCType: @encode(id) at: &_identifier];
	[aDecoder decodeValueOfObjCType: @encode(id) at: &_label];
	[aDecoder decodeValueOfObjCType: @encode(id) at: &_view];
	[aDecoder decodeValueOfObjCType: @encode(id) at: &_color];
	[aDecoder decodeValueOfObjCType: @encode(NSTabState) at:&_tabState];
	[aDecoder decodeValueOfObjCType: @encode(id) at: &_tabView];
	
	return self;
}

@end /* NSTabViewItem */

/* ****************************************************************************

 		NSTabView

** ***************************************************************************/

@implementation NSTabView

- (id) initWithFrame:(NSRect)rect
{
	if ((self = [super initWithFrame:rect]))
		{
		_tabViewItems = [NSMutableArray new];
		_font = [[NSFont systemFontOfSize:12] retain];
		}
	
	return self;
}

- (void) dealloc
{
	[_tabViewItems release];
	[_font release];

	[super dealloc];
}

- (void) addTabViewItem:(NSTabViewItem *)tabViewItem
{
	[tabViewItem _setTabView:self];
	[_tabViewItems insertObject:tabViewItem atIndex:[_tabViewItems count]];
	
	if ([_delegate respondsToSelector: @selector(tabViewDidChangeNumberOfTabViewItems:)])
		[_delegate tabViewDidChangeNumberOfTabViewItems:self];
}

- (void) insertTabViewItem:(NSTabViewItem *)tabViewItem
				   atIndex:(NSInteger)index
{
	[tabViewItem _setTabView:self];
	[_tabViewItems insertObject:tabViewItem atIndex:index];
	
	if ([_delegate respondsToSelector:@selector(tabViewDidChangeNumberOfTabViewItems:)])
		[_delegate tabViewDidChangeNumberOfTabViewItems:self];
}

- (void) removeTabViewItem:(NSTabViewItem *)tabViewItem
{
	int i = [_tabViewItems indexOfObject:tabViewItem];
  
	if (i == -1)
		return;

	[_tabViewItems removeObjectAtIndex:i];

	if ([_delegate respondsToSelector:@selector(tabViewDidChangeNumberOfTabViewItems:)])
		[_delegate tabViewDidChangeNumberOfTabViewItems:self];
}

- (NSInteger) indexOfTabViewItem:(NSTabViewItem *)tabViewItem
{
	return [_tabViewItems indexOfObject:tabViewItem];
}

- (NSInteger) indexOfTabViewItemWithIdentifier:(id)identifier
{
	NSInteger numberOfTabs = [_tabViewItems count];
	NSInteger i;

	for (i = 0; i < numberOfTabs; i++)
		{
		id anItem = [_tabViewItems objectAtIndex:i];

		if ([[anItem identifier] isEqual:identifier])
			return i;
		}

	return NSNotFound;
}

- (NSTabViewItem *) tabViewItemAtIndex:(NSInteger)index
{
	return [_tabViewItems objectAtIndex:index];
}

- (NSInteger) numberOfTabViewItems		{ return [_tabViewItems count]; }
- (NSArray *) tabViewItems				{ return (NSArray *)_tabViewItems; }

- (void) selectFirstTabViewItem:(id)sender	
{ 
	[self selectTabViewItemAtIndex:0];
}

- (void) selectLastTabViewItem:(id)sender
{
	[self selectTabViewItem:[_tabViewItems lastObject]];
}

- (void) selectNextTabViewItem:(id)sender
{
	NSInteger i = [_tabViewItems indexOfObject:_selectedTabViewItem];
	NSInteger count = [_tabViewItems count];

	[self selectTabViewItemAtIndex:MIN(i+1, count)];
}

- (void) selectPreviousTabViewItem:(id)sender
{
	NSInteger i = [_tabViewItems indexOfObject:_selectedTabViewItem];

	[self selectTabViewItemAtIndex:MAX(0, i-1)];
}

- (void) selectTabViewItemWithIdentifier:(id)ir
{
	[self selectTabViewItemAtIndex:[self indexOfTabViewItemWithIdentifier:ir]];
}

- (NSTabViewItem *) selectedTabViewItem
{
	return _selectedTabViewItem;
}

- (void) selectTabViewItem:(NSTabViewItem *)tabViewItem
{
	BOOL canSelect = YES;

	if ([_delegate respondsToSelector:@selector(tabView:shouldSelectTabViewItem:)])
		canSelect = [_delegate tabView:self shouldSelectTabViewItem:tabViewItem];

	if (!canSelect)
		return;

	if (_selectedTabViewItem)
		{
		NSView *selectedView = nil;

		[_selectedTabViewItem _setTabState:NSBackgroundTab];
		if ((selectedView = [_selectedTabViewItem view]) != nil)
			[[selectedView retain] removeFromSuperview];
		}

	_selectedTabViewItem = tabViewItem;

	if ([_delegate respondsToSelector:@selector(tabView:willSelectTabViewItem:)])
		[_delegate tabView:self willSelectTabViewItem:_selectedTabViewItem];

	[_selectedTabViewItem _setTabState:NSSelectedTab];
	if ([_selectedTabViewItem view])
		[self addSubview:[_selectedTabViewItem view]];

	if ([_delegate respondsToSelector:@selector(tabView:didSelectTabViewItem:)])
		[_delegate tabView:self didSelectTabViewItem:_selectedTabViewItem];

	[self setNeedsDisplay:YES];
}

- (void) selectTabViewItemAtIndex:(NSInteger)index
{
	[self selectTabViewItem:[_tabViewItems objectAtIndex:index]];
}

- (void) takeSelectedTabViewItemFromSender:(id)sender
{
}

- (void) setFont:(NSFont *)font				{ ASSIGN(_font, font); }
- (NSFont *) font							{ return _font; }
- (NSTabViewType) tabViewType				{ return _tabViewType; }
- (void) setTabViewType:(NSTabViewType)t	{ _tabViewType = t; }
- (void) setDrawsBackground:(BOOL)flag		{ _drawsBackground = flag; }
- (BOOL) drawsBackground					{ return _drawsBackground; }
- (BOOL) allowsTruncatedLabels				{ return _allowTruncatedLabels; }
- (void) setAllowsTruncatedLabels:(BOOL)a	{ _allowTruncatedLabels = a; }
- (void) setDelegate:(id)object				{ _delegate = object; }
- (id) delegate								{ return _delegate; }
- (NSSize) minimumSize						{ return NSZeroSize; }

- (NSRect) contentRect
{
	NSRect cRect = [self frame];

	cRect.origin.x = 0;

	if (_tabViewType == NSTopTabsBezelBorder)
		{
		cRect.origin.y = 0;
		cRect.size.height -= 16;
		}

	if (_tabViewType == NSBottomTabsBezelBorder)
		{
		cRect.size.height -= 8;
		cRect.origin.y = 8;
		}

	return cRect;
}

- (void) drawRect:(NSRect)rect
{
	float borderThickness;
	NSInteger numberOfTabs = [_tabViewItems count];
	NSInteger i, previousState = 0;
	NSRect previousRect;

	rect = NSIntersectionRect(_bounds, rect);

	PSgsave();

	switch (_tabViewType)
		{
		case NSTopTabsBezelBorder:
			rect.size.height -= 16;
			NSDrawButton(rect, rect);
			borderThickness = 2;
			break;
		case NSBottomTabsBezelBorder:
			rect.size.height -= 16;
			rect.origin.y += 16;
			NSDrawButton(rect, rect);
			rect.origin.y -= 16;
			borderThickness = 2;
			break;
		case NSNoTabsBezelBorder:
			NSDrawButton(rect, rect);
			borderThickness = 2;
			break;
		case NSNoTabsLineBorder:
			NSFrameRect(rect);
			borderThickness = 1;
			break;
		case NSNoTabsNoBorder:
			borderThickness = 0;
			break;
		}

	if (!_selectedTabViewItem)
		[self selectFirstTabViewItem:nil];

	if (_tabViewType == NSNoTabsBezelBorder || _tabViewType == NSNoTabsLineBorder)
		{
		PSgrestore();
		return;
		}

	if (_tabViewType == NSBottomTabsBezelBorder)
		{
		for (i = 0; i < numberOfTabs; i++) 
			{												// where is tab
			NSPoint iP;
			NSTabViewItem *anItem = [_tabViewItems objectAtIndex:i];
			NSTabState itemState = [anItem tabState];
			NSSize s = [anItem sizeOfLabel:NO];
			NSRect r = {{NSMinX(rect) + 13, NSMinY(rect) + 2},{s.width, 15}};

			if (i == 0) 
				{
				iP = (NSPoint){rect.origin.x,rect.size.height};

				if (itemState == NSSelectedTab) 
					{
					iP.y += 1;
					[[NSImage imageNamed:@"tabDownSelLeft.tiff"]
							  compositeToPoint:iP 
							  operation: NSCompositeSourceOver];
					}
				else 
					if (itemState == NSBackgroundTab)
						[[NSImage imageNamed:@"tabDownUnSelLeft.tiff"]
								  compositeToPoint:iP 
								  operation: NSCompositeSourceOver];
					else
						NSLog(@"Not finished yet.\n");

				PSsetgray(1);
				PSnewpath();
				PSmoveto(NSMinX(r), NSMinY(r) - 1);
				PSrlineto(r.size.width, 0);
				PSstroke();      

				[anItem drawLabel:NO inRect:r];

				previousRect = r;
				previousState = itemState;
				} 
			else 
				{
				iP = (NSPoint){NSMaxX(previousRect), NSMinY(rect)};

				if (itemState == NSSelectedTab) 
					{
					iP.y += 1;
					[[NSImage imageNamed:@"tabDownUnSelToSel.tiff"]
							  compositeToPoint:iP 
							  operation: NSCompositeSourceOver];
					}
				else 
					if (itemState == NSBackgroundTab) 
						{
						if (previousState == NSSelectedTab) 
							{
							iP.y += 1;
							[[NSImage imageNamed:@"tabDownSelToUnSel.tiff"]
									  compositeToPoint:iP 
									  operation: NSCompositeSourceOver];
							iP.y -= 1;
							} 
						else 
							{
							[[NSImage imageNamed:@"tabDownUnSel.tiff"]
									  compositeToPoint:iP 
									  operation: NSCompositeSourceOver];
						}	}
					else
						NSLog(@"Not finished yet.\n");

				r.origin.x = iP.x + 13;
				PSsetgray(1);
				PSnewpath();
				PSmoveto(NSMinX(r), NSMinY(r) - 1);
				PSrlineto(r.size.width, 0);
				PSstroke();      
		
				[anItem drawLabel:NO inRect:r];
		
				previousRect = r;
				previousState = itemState;
				}  

			if (i == numberOfTabs-1) 
				{
				iP.x += s.width + 13;
		
				if ([anItem tabState] == NSSelectedTab)
					[[NSImage imageNamed:@"tabDownSelRight.tiff"]
				compositeToPoint:iP operation: NSCompositeSourceOver];
				else 
					if ([anItem tabState] == NSBackgroundTab)
						[[NSImage imageNamed:@"tabDownUnSelRight.tiff"]
								  compositeToPoint:iP 
								  operation: NSCompositeSourceOver];
					else
						NSLog(@"Not finished yet.\n");
			}	}
		return;
		}

	for (i = 0; i < numberOfTabs; i++) 
		{
		NSPoint iP;
		NSTabViewItem *anItem = [_tabViewItems objectAtIndex:i];
		NSTabState itemState = [anItem tabState];
		NSSize s = [anItem sizeOfLabel:NO];
		NSRect r = {{NSMinX(rect) + 13, NSHeight(rect)},{s.width,15}};

		if (i == 0) 
			{
			iP = (NSPoint){rect.origin.x,rect.size.height};
//			iP = (NSPoint){r.origin.x,rect.size.height};
	
			if (itemState == NSSelectedTab) 
				{
				iP.y -= 1;
//				[[NSImage imageNamed:@"tabDown.tiff"]
				[[NSImage imageNamed:@"tabSelLeft.tiff"]
						  compositeToPoint:iP
						  operation: NSCompositeSourceOver];
				}
			else 
				if (itemState == NSBackgroundTab)
//					[[NSImage imageNamed:@"tabBackground.tiff"]
					[[NSImage imageNamed:@"tabUnSelLeft.tiff"]
							  compositeToPoint:iP 
							  operation: NSCompositeSourceOver];
				else
					NSLog(@"Not finished yet.\n");

			PSsetgray(1);
			PSnewpath();
			PSmoveto(NSMinX(r), NSMinY(r) + 16);
			PSrlineto(NSWidth(r), 0);
			PSstroke();      
	
			[anItem drawLabel:NO inRect:r];
	
			previousRect = r;
			previousState = itemState;
			} 
		else 
			{
			iP = (NSPoint){NSMaxX(previousRect), NSHeight(rect)};

			if (itemState == NSSelectedTab) 
				{
				iP.y -= 1;
//				[[NSImage imageNamed:@"tabDown.tiff"]
				[[NSImage imageNamed:@"tabUnSelToSel.tiff"]
						  compositeToPoint:iP 
						  operation: NSCompositeSourceOver];
				}
			else 
				if (itemState == NSBackgroundTab) 
					{
					if (previousState == NSSelectedTab) 
						{
						iP.y -= 1;
//						[[NSImage imageNamed:@"tabsSeparator.tiff"]
						[[NSImage imageNamed:@"tabSelToUnSel.tiff"]
								  compositeToPoint:iP 
								  operation: NSCompositeSourceOver];
						iP.y += 1;
						} 
					else 
//						[[NSImage imageNamed:@"tabsSeparator.tiff"]
						[[NSImage imageNamed:@"tabUnSel.tiff"]
								  compositeToPoint:iP 
								  operation: NSCompositeSourceOver];
					} 
				else
					NSLog(@"Not finished yet.\n");

			r.origin.x = iP.x + 13;
			PSsetgray(1);
			PSnewpath();
			PSmoveto(NSMinX(r), NSMinY(r) + 16);
			PSrlineto(NSWidth(r), 0);
			PSstroke();      
	
			[anItem drawLabel:NO inRect:r];
	
			previousRect = r;
			previousState = itemState;
			}  
	
		if (i == numberOfTabs - 1) 
			{
			iP.x += s.width + 13;
	
			if ([anItem tabState] == NSSelectedTab)
				[[NSImage imageNamed:@"tabSelRight.tiff"]
						  compositeToPoint:iP 
						  operation: NSCompositeSourceOver];
			else 
				if ([anItem tabState] == NSBackgroundTab)
					[[NSImage imageNamed:@"tabUnSelRight.tiff"]
							  compositeToPoint:iP 
							  operation: NSCompositeSourceOver];
				else
					NSLog(@"Not finished yet.\n");
		}	}

	PSgrestore();
}

- (NSTabViewItem *) tabViewItemAtPoint:(NSPoint)point
{
	NSInteger numberOfTabs = [_tabViewItems count];
	NSInteger i;

	point = [self convertPoint:point fromView:nil];
	for (i = 0; i < numberOfTabs; i++) 
		{
		NSTabViewItem *aTab = [_tabViewItems objectAtIndex:i];

		if (NSPointInRect(point, [aTab _tabRect]))
			return aTab;
		}

	return nil;
}

- (void) mouseDown:(NSEvent *)event
{
	NSTabViewItem *t = [self tabViewItemAtPoint:[event locationInWindow]];

	if (t && ![t isEqual:_selectedTabViewItem])
		[self selectTabViewItem:t];
}

- (void) encodeWithCoder:(NSCoder*)aCoder				// NSCoding Protocol
{ 
	[super encodeWithCoder: aCoder];
			
	[aCoder encodeObject:_tabViewItems];
	[aCoder encodeObject:_font];
	[aCoder encodeValueOfObjCType: @encode(NSTabViewType) at: &_tabViewType];
	[aCoder encodeValueOfObjCType: @encode(BOOL) at: &_drawsBackground];
	[aCoder encodeValueOfObjCType: @encode(BOOL) at: &_allowTruncatedLabels];
	[aCoder encodeObject:_delegate];
}

- (id) initWithCoder:(NSCoder*)aDecoder
{
	[super initWithCoder: aDecoder];
	
	[aDecoder decodeValueOfObjCType: @encode(id) at: &_tabViewItems];
	[aDecoder decodeValueOfObjCType: @encode(id) at: &_font];
	[aDecoder decodeValueOfObjCType: @encode(NSTabViewType) at:&_tabViewType];
	[aDecoder decodeValueOfObjCType: @encode(BOOL) at: &_drawsBackground];
	[aDecoder decodeValueOfObjCType: @encode(BOOL) at: &_allowTruncatedLabels];
	[aDecoder decodeValueOfObjCType: @encode(id) at: &_delegate];
	
	return self;
}

@end /* NSTabView */
