/*
   NSCursor.h

   Cursor management

   Copyright (C) 2000 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@pcmagic.net>
   Date:    June 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSCursor
#define _mGSTEP_H_NSCursor

#include <Foundation/NSCoder.h>

@class NSImage;
@class NSEvent;
@class NSColor;


@interface NSCursor : NSObject
{
	NSImage *_image;
	NSPoint _hotSpot;
	BOOL _isSetOnMouseEntered;
	BOOL _isSetOnMouseExited;
}

+ (NSCursor *) currentCursor;							// current app cursor
+ (NSCursor *) arrowCursor;
+ (NSCursor *) IBeamCursor;
+ (NSCursor *) resizeLeftRightCursor;
+ (NSCursor *) dragCopyCursor;
+ (NSCursor *) dragLinkCursor;

+ (BOOL) isHiddenUntilMouseMoves;
+ (void) setHiddenUntilMouseMoves:(BOOL)flag;
+ (void) hide;
+ (void) unhide;

- (id) initWithImage:(NSImage *)image
			foregroundColorHint:(NSColor *)f
			backgroundColorHint:(NSColor *)b
			hotSpot:(NSPoint)hotSpot;

- (id) initWithImage:(NSImage *)image hotSpot:(NSPoint)point;

- (NSImage *) image;
- (NSPoint) hotSpot;
- (void) setHotSpot:(NSPoint)spot;
- (void) setImage:(NSImage *)newImage;					// Cursor attributes

- (BOOL) isSetOnMouseEntered;
- (BOOL) isSetOnMouseExited;
- (void) setOnMouseEntered:(BOOL)flag;
- (void) setOnMouseExited:(BOOL)flag;
- (void) mouseEntered:(NSEvent *)event;
- (void) mouseExited:(NSEvent *)event;

+ (void) pop;
- (void) pop;
- (void) push;

@end


@interface NSCursor  (CursorBackend)

- (void) set;

@end


@interface NSCursor  (CursorExtension)					// mGSTEP extensions

+ (NSCursor *) resizeCursor;
+ (NSCursor *) moveCursor;

@end


@interface NSCursor  (NotImplemented)

+ (NSCursor *) currentSystemCursor;						// sys displayed cursor

+ (NSCursor *) pointingHandCursor;
+ (NSCursor *) closedHandCursor;
+ (NSCursor *) openHandCursor;
+ (NSCursor *) resizeLeftCursor;
+ (NSCursor *) resizeRightCursor;
+ (NSCursor *) resizeUpCursor;
+ (NSCursor *) resizeDownCursor;
+ (NSCursor *) resizeUpDownCursor;
+ (NSCursor *) crosshairCursor;
+ (NSCursor *) disappearingItemCursor;
+ (NSCursor *) operationNotAllowedCursor;
+ (NSCursor *) contextualMenuCursor;
+ (NSCursor *) IBeamCursorForVerticalLayout;

@end

#endif /* _mGSTEP_H_NSCursor */
