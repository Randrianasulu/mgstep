/*
   NSAlert.h

   Manage an alert panel.

   Copyright (C) 2017 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    July 2017

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSAlert
#define _mGSTEP_H_NSAlert

#include <Foundation/NSObject.h>
#include <AppKit/NSApplication.h>

@class NSButton;
@class NSTextField;
@class NSString;
@class NSPanel;
@class NSArray;
@protocol NSAlertDelegate;

typedef enum _NSAlertStyle {
	NSWarningAlertStyle       = 0,
	NSInformationalAlertStyle = 1,
	NSCriticalAlertStyle      = 2,
} NSAlertStyle;
											// pos dependant return values
enum {										// change with button's setTag:
	NSAlertFirstButtonReturn  = 1000,		//  --|  right most button
	NSAlertSecondButtonReturn = 1001,		//  -|-  middle
	NSAlertThirdButtonReturn  = 1002		//  |--  third
};


@interface NSAlert : NSObject
{
    NSPanel *_panel;

    id _first;
    id _second;
    id _third;
    NSArray *_buttons;

    id _helpButton;
    id _suppressButton;
//    NSSize _minButtonSize;
//    NSSize _defaultPanelSize;

    NSTextField *_title;					// aka message
    NSTextField *_message;					// format text w/info args list

    id _imageView;
    id _accessoryView;
    id _suppressionButton;					// show again ? checkbox
    id _delegate;

	NSButton *_default;						// for deprecated NSRunAlertPanel()
	NSButton *_alternate;
	NSButton *_other;

    struct __AlertFlags {
		unsigned int cache:1;
		unsigned int showsHelp:1;
		unsigned int showsSuppressButton:1;
		NSAlertStyle alertStyle:2;
		unsigned int reserved:3;
	} _af;
}

+ (NSAlert *) alertWithError:(NSError *)error;

+ (NSAlert *) alertWithMessageText:(NSString *)message
					 defaultButton:(NSString *)defaultButton
					 alternateButton:(NSString *)alternateButton
					 otherButton:(NSString *)otherButton
					 informativeTextWithFormat:(NSString *)format, ...;

- (void) setMessageText:(NSString *)title;
- (void) setInformativeText:(NSString *)inform;
- (void) setAccessoryView:(NSView *)view;

- (NSString *) messageText;
- (NSString *) informativeText;
- (NSView *) accessoryView;
- (id) window;

- (void) setIcon:(NSImage *)icon;
- (NSImage *) icon;
- (NSArray *) buttons;
- (NSButton *) addButtonWithTitle:(NSString *)title;	// added right to left

- (void) setAlertStyle:(NSAlertStyle)style;
- (NSAlertStyle) alertStyle;

- (void) setShowsHelp:(BOOL)flag;						// no NSHelpManager so
- (BOOL) showsHelp;										// delegate must show

- (void) setDelegate:(id <NSAlertDelegate>)delegate;
- (id <NSAlertDelegate>) delegate;

- (void) setShowsSuppressionButton:(BOOL)flag;			// suppression checkbox
- (BOOL) showsSuppressionButton;
- (NSButton *) suppressionButton;

- (void) layout;

- (NSModalResponse) runModal;

@end


@protocol NSAlertDelegate  <NSObject>

- (BOOL) alertShowHelp:(NSAlert *)alert;	// implepmented by delegate for
											// custom help behavior
@end

#endif /* _mGSTEP_H_NSAlert */
