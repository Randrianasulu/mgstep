/*
   NSColorPanel.h

   System color panel

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
   Date:    1996

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSColorPanel
#define _mGSTEP_H_NSColorPanel

#include <AppKit/NSPanel.h>

@class NSView;
@class NSColorList;
@class NSColorWell;
@class NSEvent;


@interface NSColorPanel : NSPanel  <NSCoding>
{
	NSColorWell *_colorWell;
	id _target;
	SEL _action;

	struct __ColorPanelFlags {
		unsigned int showsAlpha:1;
		unsigned int isContinuous:1;
		unsigned int reserved:6;
	} _cp;
}

+ (NSColorPanel *) sharedColorPanel;						// shared instance
+ (BOOL) sharedColorPanelExists;

+ (void) setPickerMask:(int)mask;							// Configuration
+ (void) setPickerMode:(int)mode;

- (NSView *) accessoryView;
- (BOOL) isContinuous;
- (BOOL) showsAlpha;
- (int) mode;
- (void) setAccessoryView:(NSView *)aView;
- (void) setAction:(SEL)aSelector;
- (void) setContinuous:(BOOL)flag;
- (void) setMode:(int)mode;
- (void) setShowsAlpha:(BOOL)flag;
- (void) setTarget:(id)anObject;

- (void) attachColorList:(NSColorList *)aColorList;			// Color List
- (void) detachColorList:(NSColorList *)aColorList;

+ (BOOL) dragColor:(NSColor **)aColor						// Drag-n Drop
		 withEvent:(NSEvent *)anEvent
		 fromView:(NSView *)sourceView;
- (float) alpha;

- (NSColor *) color;
- (void) setColor:(NSColor *)aColor;

@end

extern NSString *NSColorPanelColorChangedNotification;		// Notifications

#endif /* _mGSTEP_H_NSColorPanel */
