/*
   NSClipView.h

   Document scrolling content view of a scroll view.

   Copyright (C) 1996-2016 Free Software Foundation, Inc.

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSClipView
#define _mGSTEP_H_NSClipView

#include <AppKit/NSView.h>

@class NSNotification;
@class NSCursor;
@class NSColor;
@class NSWindow;


@interface NSClipView : NSView
{
	NSColor *_backgroundColor;
	NSView *_documentView;
	NSCursor *_cursor;
	NSRect _documentRect; 

    struct __clipViewFlags {
		unsigned int docIsFlipped:1;
		unsigned int copiesOnScroll:1;
		unsigned int drawsBackground:1;
		unsigned int reserved:5;
	} _cv;
}

- (void) setDocumentView:(NSView*)aView;
- (id) documentView;

- (void) scrollToPoint:(NSPoint)newOrigin;
- (BOOL) autoscroll:(NSEvent*)event;
- (NSPoint) constrainScrollPoint:(NSPoint)proposedNewOrigin;

- (void) setCopiesOnScroll:(BOOL)flag;
- (BOOL) copiesOnScroll;

- (NSRect) documentRect;
- (NSRect) documentVisibleRect;

- (void) setDocumentCursor:(NSCursor*)aCursor;
- (NSCursor*) documentCursor;

- (NSColor*) backgroundColor;
- (void) setBackgroundColor:(NSColor*)aColor;
- (void) setDrawsBackground:(BOOL)flag;
- (BOOL) drawsBackground;

- (BOOL) isFlipped;											// NSView methods
- (void) rotateByAngle:(float)angle;
- (void) scaleUnitSquareToSize:(NSSize)newUnitSize;
- (void) setBoundsOrigin:(NSPoint)aPoint;
- (void) setBoundsRotation:(float)angle;
- (void) setBoundsSize:(NSSize)aSize;
- (void) setFrameSize:(NSSize)aSize;
- (void) setFrameOrigin:(NSPoint)aPoint;
- (void) setFrameRotation:(float)angle;
- (void) translateOriginToPoint:(NSPoint)aPoint;
- (void) viewBoundsChanged:(NSNotification*)aNotification;
- (void) viewFrameChanged:(NSNotification*)aNotification;

@end


@interface NSClipView (SuperviewMethods)

- (void) reflectScrolledClipView:(NSClipView*)aClipView;
- (void) scrollClipView:(NSClipView*)aClipView toPoint:(NSPoint)newOrigin;

@end

#endif /* _mGSTEP_H_NSClipView */
