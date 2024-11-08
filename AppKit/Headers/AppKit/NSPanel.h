/*
   NSPanel.h

   Panel window subclass

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
   Date: 1996

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSPanel
#define _mGSTEP_H_NSPanel

#include <AppKit/NSWindow.h>

@class NSString;

enum {
	NSOKButton	   = 1,
	NSCancelButton = 0
};

enum {
	NSAlertDefaultReturn   = 1,
	NSAlertAlternateReturn = 0,
	NSAlertOtherReturn	   = -1,
	NSAlertErrorReturn	   = -2
};	 


@interface NSPanel : NSWindow  <NSCoding>

- (void) setFloatingPanel:(BOOL)flag;	// palettes float above all others 
- (BOOL) isFloatingPanel;
- (BOOL) becomesKeyOnlyIfNeeded;		// if key entry control clicked
- (void) setBecomesKeyOnlyIfNeeded:(BOOL)flag;
- (void) setWorksWhenModal:(BOOL)flag;	// receives keyboard and mouse events
- (BOOL) worksWhenModal;				// when another window is run modally

@end


id NSGetAlertPanel(NSString *title,						// Create alert panel
                   NSString *msg,
                   NSString *defaultButton,
                   NSString *alternateButton, 
                   NSString *otherButton, ...);

int NSRunAlertPanel(NSString *title,					// Create and run an 
                    NSString *msg,						// alert panel
                    NSString *defaultButton,
                    NSString *alternateButton,
                    NSString *otherButton, ...);

void NSReleaseAlertPanel(id panel);						// Release alert panel

#endif /* _mGSTEP_H_NSPanel */
