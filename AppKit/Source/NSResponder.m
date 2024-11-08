/*
   NSResponder.m

   Event processing base class.

   Copyright (C) 1996-2016 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
   Date: 	1996

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSCoder.h>

#include <AppKit/NSResponder.h>
#include <AppKit/NSGraphics.h>


@implementation NSResponder

- (id) nextResponder							{ return _nextResponder; }
- (void) setNextResponder:(id)aResponder		{ _nextResponder = aResponder;}
- (void) setMenu:(NSMenu *)menu					{ }
- (NSMenu *) menu								{ return nil; }
- (BOOL) acceptsFirstResponder					{ return NO; }
- (BOOL) becomeFirstResponder					{ return YES; }
- (BOOL) resignFirstResponder					{ return YES; }
- (BOOL) performKeyEquivalent:(NSEvent*)event	{ return NO; }

- (BOOL) tryToPerform:(SEL)anAction with:(id)anObject
{													
	if (![self respondsToSelector:anAction])
		{					 							// if we can't perform
		if (!_nextResponder)							// action see if the
			return NO;									// next responder can

		return [_nextResponder tryToPerform:anAction with:anObject];
		}												// else we can perform 
														// action and do so
	[self performSelector:anAction withObject:anObject];

	return YES;
}

- (void) flagsChanged:(NSEvent *)event
{
	if (_nextResponder)
		[_nextResponder flagsChanged:event];
	else
		[self noResponderFor:@selector(flagsChanged:)];
}

- (void) helpRequested:(NSEvent *)event
{
	if (_nextResponder)
		[_nextResponder helpRequested:event];
	else
		[self noResponderFor:@selector(helpRequested:)];
}

- (void) keyDown:(NSEvent *)event
{
	if (_nextResponder)
		[_nextResponder keyDown:event];
	else
		[self noResponderFor:@selector(keyDown:)];
}

- (void) keyUp:(NSEvent *)event
{
	if (_nextResponder)
		[_nextResponder keyUp:event];
	else
		[self noResponderFor:@selector(keyUp:)];
}

- (void) scrollWheel:(NSEvent *)event
{
	if (_nextResponder)
		[_nextResponder scrollWheel:event];
	else
		[self noResponderFor:@selector(scrollWheel:)];
}

- (void) mouseDown:(NSEvent *)event
{
	if (_nextResponder)
		[_nextResponder mouseDown:event];
	else
		[self noResponderFor:@selector(mouseDown:)];
}

- (void) mouseDragged:(NSEvent *)event
{
	if (_nextResponder)
		[_nextResponder mouseDragged:event];
	else
		[self noResponderFor:@selector(mouseDragged:)];
}

- (void) mouseEntered:(NSEvent *)event
{
	if (_nextResponder)
		[_nextResponder mouseEntered:event];
	else
		[self noResponderFor:@selector(mouseEntered:)];
}

- (void) mouseExited:(NSEvent *)event
{
	if (_nextResponder)
		[_nextResponder mouseExited:event];
	else
		[self noResponderFor:@selector(mouseExited:)];
}

- (void) mouseMoved:(NSEvent *)event
{
	if (_nextResponder)
		[_nextResponder mouseMoved:event];
	else
		[self noResponderFor:@selector(mouseMoved:)];
}

- (void) mouseUp:(NSEvent *)event
{
	if (_nextResponder)
		[_nextResponder mouseUp:event];
	else
		[self noResponderFor:@selector(mouseUp:)];
}

- (void) noResponderFor:(SEL)eventSelector
{
	if (eventSelector == @selector(keyDown:))
		NSBeep();									// beep if key down event
}

- (void) otherMouseDown:(NSEvent *)event
{
	if (_nextResponder)
		[_nextResponder otherMouseDown:event];
	else
		[self noResponderFor:@selector(otherMouseDown:)];
}

- (void) otherMouseDragged:(NSEvent *)event
{
	if (_nextResponder)
		[_nextResponder otherMouseDragged:event];
	else
		[self noResponderFor:@selector(otherMouseDragged:)];
}

- (void) otherMouseUp:(NSEvent *)event
{
	if (_nextResponder)
		[_nextResponder otherMouseUp:event];
	else
		[self noResponderFor:@selector(otherMouseUp:)];
}

- (void) rightMouseDown:(NSEvent *)event
{
	if (_nextResponder)
		[_nextResponder rightMouseDown:event];
	else
		[self noResponderFor:@selector(rightMouseDown:)];
}

- (void) rightMouseDragged:(NSEvent *)event
{
	if (_nextResponder)
		[_nextResponder rightMouseDragged:event];
	else
		[self noResponderFor:@selector(rightMouseDragged:)];
}

- (void) rightMouseUp:(NSEvent *)event
{
	if (_nextResponder)
		[_nextResponder rightMouseUp:event];
	else
		[self noResponderFor:@selector(rightMouseUp:)];
}
														// Services menu
- (id) validRequestorForSendType:(NSString *)typeSent
					  returnType:(NSString *)typeReturned
{
	if (_nextResponder)
		return [_nextResponder validRequestorForSendType:typeSent
							   returnType:typeReturned];
	return nil;
}

- (void) encodeWithCoder:(NSCoder*)aCoder				// NSCoding protocol
{
	[aCoder encodeConditionalObject: _nextResponder];
}

- (id) initWithCoder:(NSCoder*)aDecoder
{
	_nextResponder = [aDecoder decodeObject];

	return self;
}

@end  /* NSResponder */


@implementation NSResponder  (NSUndoRedoSupport)

- (NSUndoManager *) undoManager
{
	return (_nextResponder) ? [_nextResponder undoManager] : nil;
}

@end  /* NSResponder (NSUndoRedoSupport) */
