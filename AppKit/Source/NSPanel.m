/*
   NSPanel.m

   Panel windows, Alert panel functions and NSAlert class.

   Copyright (C) 1996-2017 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    June 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSBundle.h>
#include <Foundation/NSException.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSKeyedArchiver.h>

#include <AppKit/AppKit.h>


// Class variables
static NSAlert *__sharedAlert = nil;
static NSPanel *__sharedAlertPanel = nil;
static BOOL __sharedAlertPanelIsActive = NO;

static float __pw = 362;						// default panel width



@implementation	NSPanel

- (id) init
{
	return [self initWithContentRect: NSZeroRect
				 styleMask: (NSTitledWindowMask | NSClosableWindowMask)
				 backing: NSBackingStoreBuffered
				 defer: YES
				 screen:nil];
}

- (id) initWithContentRect:(NSRect)contentRect
				 styleMask:(unsigned int)aStyle
				 backing:(NSBackingStoreType)bufferingType
				 defer:(BOOL)flag
				 screen:(NSScreen *)aScreen
{
	_w.menuExclude = YES;

	if ((self = [super initWithContentRect: contentRect
						styleMask: aStyle
						backing: bufferingType
						defer: flag
						screen: aScreen]))
		{
		_w.releasedWhenClosed = NO;
		_w.hidesOnDeactivate = YES;
		_w.isPanel = YES;
		[super setTitle: @" "];
		}

	return self;
}

- (BOOL) validateMenuItem:(NSMenuItem *)aCell
{
    SEL s = [aCell action];

	if (sel_eq (@selector(hide:), s) || sel_eq (@selector(quit:), s))
		return YES;

    return NO;
}

- (void) keyDown:(NSEvent*)event
{											// If we receive an escape, close.
	if ([@"\e" isEqual: [event charactersIgnoringModifiers]] &&
			([self styleMask] & NSClosableWindowMask) == NSClosableWindowMask)
		[self close];
	else
		[super keyDown: event];
}
															// Panel Behavior
- (void) setFloatingPanel:(BOOL)flag
{
	[super setLevel: (flag) ? NSFloatingWindowLevel : NSNormalWindowLevel];
}

- (BOOL) isFloatingPanel	{ return (_level == NSFloatingWindowLevel); }
- (void) setWorksWhenModal:(BOOL)flag		{ _w.worksWhenModal = flag; }
- (BOOL) worksWhenModal						{ return _w.worksWhenModal; }
- (BOOL) becomesKeyOnlyIfNeeded				{ return _w.becomesKeyOnlyIfNeeded; }
- (void) setBecomesKeyOnlyIfNeeded:(BOOL)f  { _w.becomesKeyOnlyIfNeeded = f; }

- (void) encodeWithCoder:(NSCoder*)aCoder	{ [super encodeWithCoder:aCoder]; }
- (id) initWithCoder:(NSCoder*)d			{ return [super initWithCoder:d]; }

@end  /* NSPanel */

/* ****************************************************************************

		Alert panels

** ***************************************************************************/

typedef struct  { @defs(NSAlert); } _NSAlert;

static void  _TileAlertPanel(NSPanel *p, NSButton *d, NSButton *a, NSButton *o)
{
	int numButtons = 0;
	float maxWidth = 0;

	if (d)					// default Button
		{
		numButtons++;
		maxWidth = [[d cell] cellSize].width;
		}
	if (a)					// alternate Button
		{
		numButtons++;
		maxWidth = MAX([[a cell] cellSize].width, maxWidth);
		}
	if (o)					// other Button
		{
		numButtons++;
		maxWidth = MAX([[o cell] cellSize].width, maxWidth);
		}
	
//	if ([_buttons count] > 3)
//		{}					// FIX ME add support for more than 3 buttons

	if (numButtons)
		{
		NSRect rect = [d frame];
		NSRect frame = [p frame];
		float maxButtonWidthInFrame = ((NSWidth(frame) - 8) / numButtons) - 8;
		BOOL adjustButtonWidth = NO;

		if (maxWidth > maxButtonWidthInFrame)			// widen the panel to
			{											// accomadate buttons 
			float newWidth = MIN(((maxWidth + 8) * numButtons) + 8,
								   [p maxSize].width);

			NSWidth(frame) = newWidth;
			[p setFrame:frame display:NO];
			adjustButtonWidth = YES;
			}
		else if (maxButtonWidthInFrame > (maxWidth+8) && NSWidth(frame) != __pw)
			{
			NSWidth(frame) = __pw;						// reset panel to defs
			[p setFrame:frame display:NO];
			adjustButtonWidth = YES;
			}
		else if (maxWidth > NSWidth(rect))
			adjustButtonWidth = YES;

		if (adjustButtonWidth)
			{
			NSWidth(rect) = maxWidth;
			NSMinX(rect) = NSWidth(frame) - (8 + NSWidth(rect));
			if (d)
				{
				[d setFrame:rect];
				NSMinX(rect) -= (8 + NSWidth(rect));
				}
			if (a)
				{
				[a setFrame:rect];
				NSMinX(rect) -= (8 + NSWidth(rect));
				}
			if (o)
				[o setFrame:rect];
			}

		[[p contentView] display];
		}
}

static id
_NewAlertPanel( NSString *title,
				NSString *message,
				NSString *defaultButton,
				NSString *alternateButton,
				NSString *otherButton,
				_NSAlert *na)
{													// create a new alert
	NSView *cv;
	NSButton *d = nil, *a = nil, *o = nil;
	NSTextField *m, *t;
	NSRect rect = (NSRect){{0,95},{__pw,2}};
	unsigned bs = 8;								// Inter-button space
	unsigned bh = 24;								// Button height
	unsigned bw = 80;								// Button width
	id v;

	na->_panel = [[NSPanel alloc] initWithContentRect:(NSRect){0,0,__pw,162}
								  styleMask: NSTitledWindowMask
								  backing: NSBackingStoreBuffered
								  defer: YES
								  screen: nil];
	na->_buttons = [NSMutableArray new];

	v = [[NSBox alloc] initWithFrame: rect];		// create middle groove
	[v setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];
	[v setTitlePosition: NSNoTitle];
	[v setBorderType: NSGrooveBorder];
	[(cv = [na->_panel contentView]) addSubview: (na->_accessoryView = v)];

	m = [[NSTextField alloc] initWithFrame: (NSRect){{8,46},{344,40}}];
	na->_message = m;
	[m setEditable: NO];
	[m setSelectable: NO];							// create message field
	[m setBezeled: NO];
	[m setDrawsBackground: NO];
	[m setAutoresizingMask: NSViewWidthSizable|NSViewMaxYMargin|NSViewHeightSizable];
	[m setAlignment: NSCenterTextAlignment];
	[m setStringValue: (message ? message : @"")];
	[m setFont: [NSFont systemFontOfSize: 14.0]];
	[[m cell] setWraps:YES];
	[cv addSubview: m];

	t = [[NSTextField alloc] initWithFrame: (NSRect){{64,121},{289,21}}];
	na->_title = t;
	[t setAutoresizingMask: NSViewWidthSizable| NSViewMinYMargin];
	[t setEditable: NO];
	[t setSelectable: NO];							// create title field
	[t setBezeled: NO];
	[t setDrawsBackground: NO];
	[t setStringValue: (title ? title : @"Alert")];
	[t setFont: [NSFont systemFontOfSize: 18.0]];
	[cv addSubview: t];
													// create icon view
	v = [[NSImageView alloc] initWithFrame: (NSRect){{10,105},{48,48}}];
	[v setImage:[NSImage imageNamed: NSApplicationIcon]];
	[cv addSubview: (na->_imageView = v)];

	rect = (NSRect){{274, bs},{bw, bh}};
	if (defaultButton || na->_af.cache)
		{
		na->_default = d = [[NSButton alloc] initWithFrame: rect];
		[d setButtonType: NSMomentaryPushButton];
		[d setTarget: [NSAlert class]];
		[d setAction: @selector(_defaultButtonAction:)];
		[d setTitle: defaultButton];
		[d setKeyEquivalent: @"\r"];
		[d setImagePosition: NSImageRight];
		[d setImage: [NSImage imageNamed: @"GSReturn"]];
		[na->_panel setInitialFirstResponder: d];
		[cv addSubview: d];
		[(NSMutableArray *)na->_buttons addObject: d];
		}

	if (alternateButton || na->_af.cache)
		{
		rect.origin.x = 186.0;
		na->_alternate = a = [[NSButton alloc] initWithFrame: rect];
		[a setButtonType: NSMomentaryPushButton];
		[a setTitle: alternateButton];
		[a setTarget: [NSAlert class]];
		[a setAction: @selector(_alternateButtonAction:)];
		if(alternateButton)
			[cv addSubview: a];
		[(NSMutableArray *)na->_buttons addObject: a];
		}

	if (otherButton || na->_af.cache)
		{
		rect.origin.x = 98.0;
		na->_other = o = [[NSButton alloc] initWithFrame: rect];
		[o setButtonType: NSMomentaryPushButton];
		[o setTitle: otherButton];
		[o setTarget: [NSAlert class]];
		[o setAction: @selector(_otherButtonAction:)];
		if(otherButton)
			[cv addSubview: o];
		[(NSMutableArray *)na->_buttons addObject: o];
		}

	if (na->_af.cache)						// cache controls ?
		{
		__sharedAlert = (NSAlert *)na;
		__sharedAlertPanel = na->_panel;
		}
	else									// else prep for release when
		{									// removed from superview
		[d release];
		[a release];
		[o release];
		[m release];
		[t release];
		}

	[na->_accessoryView release];
	[na->_imageView release];

	_TileAlertPanel(na->_panel, d, a, o);

	return na->_panel;
}

static id
_SharedAlertPanel(NSString *title,
				  NSString *message,
				  NSString *defaultButton,
				  NSString *alternateButton,
				  NSString *otherButton,
				  _NSAlert *na)
{													// reuse shared alert panel
	NSView *cv = [na->_panel contentView];

	if (message)
		{
		[na->_message setStringValue: message];
		if ([na->_message superview] == nil)
			[cv addSubview: na->_message];
		}
	else if ([na->_message superview] != nil)
		[na->_message removeFromSuperview];

	[na->_title setStringValue: (title ? title : @"Alert")];

	if (defaultButton)
		{
		[na->_default setTitle: defaultButton];
		if ([na->_default superview] == nil)
			[cv addSubview: na->_default];
		[na->_panel makeFirstResponder: na->_default];
		}
	else if ([na->_default superview] != nil)
		[na->_default removeFromSuperview];

	if (alternateButton)
		{
		[na->_alternate setTitle: alternateButton];
		if ([na->_alternate superview] == nil)
			[cv addSubview: na->_alternate];
		}
	else if ([na->_alternate superview] != nil)
		[na->_alternate removeFromSuperview];

	if (otherButton)
		{
		[na->_other setTitle: otherButton];
		if ([na->_other superview] == nil)
			[cv addSubview: na->_other];
		}
	else if ([na->_other superview] != nil)
		[na->_other removeFromSuperview];

	_TileAlertPanel(na->_panel, na->_default, na->_alternate, na->_other);
	
	return na->_panel;
}

id
NSGetAlertPanel(NSString *title,
				NSString *msg,
				NSString *defaultStr,
				NSString *alternateStr,
				NSString *otherStr, ...)
{
	va_list	ap;
	NSString *m;
	_NSAlert na = {0};

	va_start (ap, otherStr);
	m = [NSString stringWithFormat: msg arguments: ap];
	va_end (ap);

	return _NewAlertPanel(title, m, defaultStr, alternateStr, otherStr, &na);
}

void
NSReleaseAlertPanel(id alertPanel)
{
	[alertPanel close];
	if (alertPanel != __sharedAlertPanel)
		[alertPanel release];
	else
		__sharedAlertPanelIsActive = NO;
}

int
NSRunAlertPanel(NSString *title,
				NSString *msg,
				NSString *defaultStr,
				NSString *alternateStr,
				NSString *otherStr, ...)
{
	va_list	ap;
	NSPanel *p;
	NSString *m;
	_NSAlert *sa = (_NSAlert *)__sharedAlert;
	int response = NSAlertErrorReturn;

	if (defaultStr == nil)
		defaultStr = @"OK";
	
	va_start (ap, otherStr);
	m = [NSString stringWithFormat: msg arguments: ap];
	va_end (ap);

	if (__sharedAlertPanel == nil || __sharedAlertPanelIsActive)
		{
		_NSAlert na = {0};

		if (!__sharedAlertPanelIsActive)	// cache if to be shared alert
			{
			sa = (_NSAlert *)[NSAlert new];
			sa->_af.cache = YES;			// non shared panels are released
			}								// by NSReleaseAlertPanel()
		else
			sa = &na;

		p = _NewAlertPanel(title, m, defaultStr, alternateStr, otherStr, sa);
		}
	else
		p = _SharedAlertPanel(title, m, defaultStr, alternateStr, otherStr, sa);

	if (p != nil)
		{
		if (__sharedAlertPanel == p)
			__sharedAlertPanelIsActive = YES;
		[p center];
		response = [NSApp runModalForWindow: p];
		NSReleaseAlertPanel(p);
		}

	return response;
}

/* ****************************************************************************

		NS Alert
	
** ***************************************************************************/

@implementation	NSAlert

+ (void) _buttonAction:(id)sender
{
	[NSApp stopModalWithCode: [sender tag]];
}

+ (void) _helpButtonAction:(id)sender
{
	[[sender delegate] alertShowHelp:sender];
}

+ (void) _defaultButtonAction:(id)sender
{
	[NSApp stopModalWithCode:NSAlertDefaultReturn];
}

+ (void) _alternateButtonAction:(id)sender
{
	[NSApp stopModalWithCode:NSAlertAlternateReturn];
}

+ (void) _otherButtonAction:(id)sender
{ 
	[NSApp stopModalWithCode:NSAlertOtherReturn];
}

+ (NSAlert *) alertWithMessageText:(NSString *)title
					 defaultButton:(NSString *)defaultStr
					 alternateButton:(NSString *)altStr
					 otherButton:(NSString *)otherStr
					 informativeTextWithFormat:(NSString *)fmt, ...
{
	va_list	ap;
	NSString *m;
	_NSAlert *na = (_NSAlert *)[NSAlert new];

	va_start (ap, fmt);
	m = [NSString stringWithFormat: fmt arguments: ap];
	va_end (ap);

	na->_panel = _NewAlertPanel(title, m, defaultStr, altStr, otherStr, na);
	
	return [(NSAlert *)na autorelease];
}

+ (NSAlert *) alertWithError:(NSError *)error
{
	_NSAlert *na = (_NSAlert *)[NSAlert new];
	NSString *m = [error localizedDescription];

	na->_panel = _NewAlertPanel(@"Error", m, @"OK", nil, nil, na);

	return [(NSAlert *)na autorelease];
}

- (id) init
{
	_panel = _NewAlertPanel(@"Alert", @"", nil, nil, nil, (_NSAlert *)self);

	return self;
}

- (void) dealloc
{
	[_panel release];
	[_buttons release];
	[super dealloc];
}

- (void) setAccessoryView:(NSView *)view
{
	if (view != _accessoryView)
		{
		[_accessoryView removeFromSuperview];
		[[_panel contentView] addSubview: (_accessoryView = view)];
		}
}

- (NSView *) accessoryView					{ return _accessoryView; }
- (NSString *) messageText					{ return [_title stringValue]; }
- (NSString *) informativeText				{ return [_message stringValue]; }
- (void) setMessageText:(NSString *)t		{ [_title setStringValue:t]; }
- (void) setInformativeText:(NSString *)m	{ [_message setStringValue:m]; }
- (void) setIcon:(NSImage *)icon			{ [_imageView setImage:icon]; }
- (NSImage *) icon							{ return [_imageView image]; }
- (NSArray *) buttons						{ return _buttons; }

- (NSButton *) addButtonWithTitle:(NSString *)title
{
	NSRect r = (NSRect){{274,8},{24,80}};
	NSButton *b;

	if (title == nil)
		[NSException raise:NSInvalidArgumentException format:@"Invalid title"];

	b = [[NSButton alloc] initWithFrame: r];
	[b setButtonType: NSMomentaryPushButton];
	[b setTarget: [NSAlert class]];
	[b setAction: @selector(_buttonAction:)];
	[b setTitle: title];

	if (!_first)
		{
		_first = b;
		[b setKeyEquivalent: @"\r"];
		[_panel setInitialFirstResponder: _first];
		[b setTag: NSAlertFirstButtonReturn];
		_buttons = [NSMutableArray new];
		}
	else if (!_second)
		{
		_second = b;
		[b setTag: NSAlertSecondButtonReturn];
		}
	else if (!_third)
		{
		_third = b;
		[b setTag: NSAlertThirdButtonReturn];
		}
	else								// NSAlertThirdButtonReturn + n
		[b setTag: NSAlertThirdButtonReturn + [_buttons count]];

	[[_panel contentView] addSubview: b];
	[(NSMutableArray *)_buttons addObject: b];
	[b release];

	_TileAlertPanel(_panel, _first, _second, _third);
}

- (NSAlertStyle) alertStyle					{ return _af.alertStyle; }
- (void) setAlertStyle:(NSAlertStyle)style	{ _af.alertStyle = style; }
- (void) setShowsSuppressionButton:(BOOL)f  { _af.showsSuppressButton = f; }
- (BOOL) showsSuppressionButton				{ return _af.showsSuppressButton; }
- (NSButton *) suppressionButton			{ return _suppressionButton; }
- (id) window								{ return _panel; }
- (id <NSAlertDelegate>) delegate			{ return _delegate; }
- (BOOL) showsHelp							{ return _af.showsHelp; }

- (void) setShowsHelp:(BOOL)flag
{
	if (!(_af.showsHelp = flag) && _helpButton)
		{
		[_helpButton removeFromSuperview];
		_helpButton = nil;
		}

	if (_af.showsHelp && !_helpButton)
		{
		_helpButton = [[NSButton alloc] initWithFrame:(NSRect){{8,40},{18,18}}];
		[_helpButton setButtonType: NSMomentaryPushButton];
		[_helpButton setTarget: [NSAlert class]];
		[_helpButton setAction: @selector(_helpButtonAction:)];
		[_helpButton setTitle: @"?"];
		[[_panel contentView] addSubview: _helpButton];
		[_helpButton release];
		}
}

- (void) setDelegate:(id <NSAlertDelegate>)delegate
{
	if ([delegate respondsToSelector: @selector(alertShowHelp:)])
		_delegate = delegate;
}

- (void) layout
{
	if (_default != nil)
		_TileAlertPanel(_panel, _default, _alternate, _other);
	else
		_TileAlertPanel(_panel, _first, _second, _third);
}

- (NSModalResponse) runModal
{
	int response = [NSApp runModalForWindow: _panel];

	[_panel orderOut:self];

	return response;
}

@end  /* NSAlert */
