/*
   NSResponder.h

   Event processing base class.

   Copyright (C) 2000-2016 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@pcmagic.net>
   Date:    June 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSResponder
#define _mGSTEP_H_NSResponder

#include <Foundation/NSCoder.h>

@class NSString;
@class NSEvent;
@class NSUndoManager;
@class NSMenu;


@interface NSResponder : NSObject  <NSCoding>
{
	id _nextResponder;
}

- (id) nextResponder;										// Next responder
- (void) setNextResponder:aResponder;

- (BOOL) acceptsFirstResponder;								// First responder
- (BOOL) becomeFirstResponder;
- (BOOL) resignFirstResponder;

- (BOOL) performKeyEquivalent:(NSEvent *)event;				// Event processing
- (BOOL) tryToPerform:(SEL)anAction with:anObject;

- (void) flagsChanged:(NSEvent *)event;
- (void) helpRequested:(NSEvent *)event;
- (void) keyDown:(NSEvent *)event;
- (void) keyUp:(NSEvent *)event;
- (void) mouseDown:(NSEvent *)event;
- (void) mouseDragged:(NSEvent *)event;
- (void) mouseEntered:(NSEvent *)event;
- (void) mouseExited:(NSEvent *)event;
- (void) mouseMoved:(NSEvent *)event;
- (void) mouseUp:(NSEvent *)event;
- (void) noResponderFor:(SEL)eventSelector;
- (void) otherMouseDown:(NSEvent *)event;
- (void) otherMouseUp:(NSEvent *)event;
- (void) otherMouseDragged:(NSEvent *)event;
- (void) rightMouseDown:(NSEvent *)event;
- (void) rightMouseDragged:(NSEvent *)event;
- (void) rightMouseUp:(NSEvent *)event;
- (void) scrollWheel:(NSEvent *)event;

- (void) setMenu:(NSMenu *)menu;
- (NSMenu *) menu;

- (id) validRequestorForSendType:(NSString *)typeSent		// Services menu
					  returnType:(NSString *)typeReturned;
@end


@interface NSResponder	(NSUndoRedoSupport)

- (NSUndoManager *) undoManager;

@end

#endif /* _mGSTEP_H_NSResponder */
