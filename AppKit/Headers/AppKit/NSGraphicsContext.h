/*
   NSGraphicsContext.h

   Graphics destination management.

   Copyright (C) 1998-2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Nov 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSGraphicsContext
#define _mGSTEP_H_NSGraphicsContext

#include <Foundation/NSObject.h>
#include <Foundation/NSGeometry.h>

@class NSBitmapImageRep;
@class NSWindow;


@interface NSGraphicsContext : NSObject

+ (id) currentContext;
+ (void) setCurrentContext:(id)context;

+ (BOOL) currentContextDrawingToScreen;
+ (void) setGraphicsState:(int)gState;

+ (void) saveGraphicsState;
+ (void) restoreGraphicsState;

- (void) saveGraphicsState;
- (void) restoreGraphicsState;
- (void) flushGraphics;

- (BOOL) isFlipped;		// focus view state, else NO unless init'd as flipped
- (BOOL) isDrawingToScreen;

@end


@interface NSGraphicsContext  (CGContext)
											// instantantiate new CTX objects
+ (NSGraphicsContext *) graphicsContextWithGraphicsPort:(void *)graphicsPort
												flipped:(BOOL)isFlipped;

+ (NSGraphicsContext *) graphicsContextWithWindow:(NSWindow *)window;
+ (NSGraphicsContext *) graphicsContextWithBitmapImageRep:(NSBitmapImageRep *)b;

- (void *) graphicsPort;

- (void) _initWindowContext:(NSRect)frameRect;
- (void) _listenForEvents:(id)queue;
- (void) _releaseWindowContext;

@end

#endif /* _mGSTEP_H_NSGraphicsContext */
