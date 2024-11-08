/*
   NSDragging.h

   Protocols for drag 'n' drop.

   Copyright (C) 1997 Free Software Foundation, Inc.

   Author:  Simon Frankau <sgf@frankau.demon.co.uk>
   Date:    1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSDragging
#define _mGSTEP_H_NSDragging

#include <Foundation/Protocol.h>
#include <Foundation/NSGeometry.h>

@class NSWindow;
@class NSPasteboard;
@class NSImage;

typedef enum _NSDragOperation {
	NSDragOperationNone		= 0,					// no op == rejection
	NSDragOperationCopy		= 1,
	NSDragOperationLink		= 2,
	NSDragOperationGeneric	= 4,
	NSDragOperationPrivate	= 8,
	NSDragOperationAll		= 15   
} NSDragOperation;

													// protocol for sender of 
@protocol NSDraggingInfo							// messages to a drag 
													// destination
- (NSWindow *) draggingDestinationWindow;
- (NSPoint) draggingLocation;
- (NSPasteboard *) draggingPasteboard;
- (int) draggingSequenceNumber;
- (id) draggingSource;
- (NSDragOperation) draggingSourceOperationMask;
- (NSImage *) draggedImage;
- (NSPoint) draggedImageLocation;
- (void) slideDraggedImageTo:(NSPoint)screenPoint;

@end

													// Methods implemented by 
@interface NSObject (NSDraggingDestination)			// a reciever of drag ops 
													// (drag destination)
- (NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender;
- (NSDragOperation) draggingUpdated:(id <NSDraggingInfo>)sender;
- (void) draggingExited:(id <NSDraggingInfo>)sender;
													// sent after image drop
- (BOOL) prepareForDragOperation:(id <NSDraggingInfo>)sender;
- (BOOL) performDragOperation:(id <NSDraggingInfo>)sender;
- (void) concludeDragOperation:(id <NSDraggingInfo>)sender;

@end
													// Methods implemented by
													// object that initiated 
@interface NSObject (NSDraggingSource)				// the drag session.  First 
													// must be implemented
- (NSDragOperation) draggingSourceOperationMaskForLocal:(BOOL)isLocal;
- (BOOL) ignoreModifierKeysWhileDragging;
- (void) draggedImage:(NSImage *)image beganAt:(NSPoint)screenPoint;
- (void) draggedImage:(NSImage*)image
			  endedAt:(NSPoint)screenPoint
			  deposited:(BOOL)didDeposit;
@end

#endif /* _mGSTEP_H_NSDragging */
