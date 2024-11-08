/*
   NSTextField.h

   Text field control class

   Copyright (C) 2000 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@pcmagic.net>
   Date:    June 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSTextField
#define _mGSTEP_H_NSTextField

#include <AppKit/NSControl.h>

@class NSNotification;
@class NSColor;
@class NSText;


@interface NSTextField : NSControl  <NSCoding>
{
	id _delegate;
	SEL _errorAction;
}

- (BOOL) isEditable;									// Access to Text
- (BOOL) isSelectable;
- (void) setEditable:(BOOL)flag;
- (void) setSelectable:(BOOL)flag;

- (void) selectText:(id)sender;							// Editing Text

- (id) nextText;										// Tab Key Behavior
- (id) previousText;
- (void) setNextText:(id)anObject;
- (void) setPreviousText:(id)anObject;

- (void) setDelegate:(id)anObject;						// Delegate
- (id) delegate;

- (NSColor*) backgroundColor;							// Graphic Attributes
- (NSColor*) textColor;
- (void) setBackgroundColor:(NSColor*)aColor;
- (void) setTextColor:(NSColor*)aColor;
- (void) setDrawsBackground:(BOOL)flag;
- (BOOL) drawsBackground;
- (BOOL) isBezeled;
- (BOOL) isBordered;
- (void) setBezeled:(BOOL)flag;
- (void) setBordered:(BOOL)flag;

- (SEL) errorAction;									// Target / Action
- (void) setErrorAction:(SEL)aSelector;

- (BOOL) acceptsFirstResponder;							// Event handling
- (void) textDidBeginEditing:(NSNotification *)aNotification;
- (void) textDidChange:(NSNotification *)aNotification;
- (void) textDidEndEditing:(NSNotification *)aNotification;
- (BOOL) textShouldBeginEditing:(NSText *)textObject;
- (BOOL) textShouldEndEditing:(NSText *)textObject;

@end

#endif /* _mGSTEP_H_NSTextField */
