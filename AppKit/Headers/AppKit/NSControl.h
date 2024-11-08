/*
   NSControl.h

   View control class

   Copyright (C) 2000-2021 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    June 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSControl
#define _mGSTEP_H_NSControl

#include <AppKit/NSText.h>

@class NSString;
@class NSNotification;
@class NSCell;
@class NSFont;
@class NSEvent;
@class NSFormatter;


@interface NSControl : NSView  <NSCoding>
{
	int _tag;
	id _cell;
}

+ (Class) cellClass;
+ (void) setCellClass:(Class)class;

- (id) initWithFrame:(NSRect)frameRect;

- (void) setCell:(NSCell *)aCell;							// Control's Cell
- (id) cell;

- (BOOL) isEnabled;
- (void) setEnabled:(BOOL)flag;								// Enable / Disable

- (id) selectedCell;										// Selected Cell
- (int) selectedTag;

- (double) doubleValue;										// Control's Value
- (float) floatValue;
- (int) intValue;
- (id) objectValue;
- (NSString *) stringValue;

- (void) setDoubleValue:(double)aDouble;
- (void) setFloatValue:(float)aFloat;
- (void) setIntValue:(int)anInt;
- (void) setObjectValue:(id)anObject;
- (void) setStringValue:(NSString *)aString;

- (void) takeDoubleValueFrom:(id)sender;					// Interaction
- (void) takeFloatValueFrom:(id)sender;
- (void) takeIntValueFrom:(id)sender;
- (void) takeObjectValueFrom:(id)sender;
- (void) takeStringValueFrom:(id)sender;

- (id) formatter;
- (void) setFormatter:(NSFormatter *)newFormatter;
- (void) setAlignment:(NSTextAlignment)mode;
- (NSTextAlignment) alignment;								// Formatting Text
- (void) setFont:(NSFont *)fontObject;
- (NSFont*) font;

- (BOOL) abortEditing;										// Field Editor
- (NSText *) currentEditor;
- (void) validateEditing;

- (void) sizeToFit;											// Sizing Control
- (void) calcSize;											// calc draw info

- (void) drawCell:(NSCell *)aCell;							// Drawing control
- (void) drawCellInside:(NSCell *)aCell;
- (void) selectCell:(NSCell *)aCell;
- (void) updateCell:(NSCell *)aCell;
- (void) updateCellInside:(NSCell *)aCell;
- (void) setNeedsDisplay;

- (SEL) action;												// Target / Action
- (BOOL) isContinuous;
- (BOOL) sendAction:(SEL)theAction to:(id)theTarget;
- (int) sendActionOn:(int)mask;
- (void) setAction:(SEL)aSelector;
- (void) setContinuous:(BOOL)flag;
- (void) setTarget:(id)anObject;
- (id) target;

- (void) setTag:(int)anInt;									// Assigning a Tag
- (int) tag;

- (void) mouseDown:(NSEvent *)event;						// Tracking Mouse
- (BOOL) ignoresMultiClick;
- (void) setIgnoresMultiClick:(BOOL)flag;

@end							// Sent by Control subclasses that allow text 
								// editing such as NSTextField and NSMatrix.  
								// These have delegates, NSControl doesn't.
@interface NSObject (NSControlSubclassDelegate)			

- (BOOL) control:(NSControl *)cl textShouldBeginEditing:(NSText *)fieldEditor;
- (BOOL) control:(NSControl *)cl textShouldEndEditing:(NSText *)fieldEditor;

@end


@interface NSControl (NSKeyboardUI)

- (BOOL) refusesFirstResponder;
- (void) setRefusesFirstResponder:(BOOL)flag;
- (void) performClick:(id)sender;

@end


@interface NSObject (NSControlSubclassNotifications)

- (void) controlTextDidBeginEditing:(NSNotification *)aNotification;
- (void) controlTextDidEndEditing:(NSNotification *)aNotification;
- (void) controlTextDidChange:(NSNotification *)aNotification;

@end

extern NSString *NSControlTextDidBeginEditingNotification;
extern NSString *NSControlTextDidEndEditingNotification;
extern NSString *NSControlTextDidChangeNotification;

#endif /* _mGSTEP_H_NSControl */
