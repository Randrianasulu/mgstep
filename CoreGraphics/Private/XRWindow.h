/*
   XRWindow.h

   X11 NSWindow categories

   Copyright (C) 1998-2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    May 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_XRWindow
#define _mGSTEP_H_XRWindow

#include <AppKit/NSWindow.h>


enum {
	XREventMask = ExposureMask        | KeyPressMask      | KeyReleaseMask
				| ButtonPressMask     | ButtonReleaseMask | ButtonMotionMask
				| StructureNotifyMask | PointerMotionMask | EnterWindowMask
				| LeaveWindowMask     | FocusChangeMask   | PropertyChangeMask
				| ColormapChangeMask  | KeymapStateMask | VisibilityChangeMask
};


@interface NSWindow  (XRWindow)

- (Window) xWindow;
- (Drawable) xDrawable;

- (GC) xGC;
- (GC) xRootGC;

- (NSPoint) xParentOffset;
- (NSRect) xFrame;

- (void) xSetSizeHints:(NSPoint)xOrigin;
- (void) xSetMapped:(BOOL)flag;

- (BOOL) xExposedRectangle:(XRectangle)rect;				// Expose events
- (void) xProcessExposedRectangles;

- (void) xSetInputFocus;
- (void) xTossFirstEvent;

- (int) xGrabMouse;											// X Mouse capture
- (int) xReleaseMouse;

- (unsigned long) xGetWindowAttributes:(XSetWindowAttributes *)wa;

@end


@interface NSWindow  (XDND)

- (void) xSetXDNDAware;

@end


extern NSWindow * XRWindowWithXWindow(Window xWindow);


typedef struct {						// Luz window manager support
    unsigned long flags;
    unsigned long window_style;
    unsigned long window_level;
    Pixmap miniaturize_pixmap;			// pixmap for miniaturize button
    Pixmap close_pixmap;				// pixmap for close button
    Pixmap maximize_pixmap;
    Pixmap doc_pixmap;					// pixmap representing document
    unsigned long extra_flags;

} XRAttributes;

#define XRWindowFlags         (1 << 0)
#define XRWindowLevel         (1 << 1)
#define XRWindowStyle         (1 << 2)
#define XRMiniaturizePixmap   (1 << 3)
#define XRClosePixmap         (1 << 4)
#define XRMaximizePixmap      (1 << 5)
#define XRDocumentPixmap      (1 << 6)
#define XRExtraFlags          (1 << 7)

#define XRDocumentEditedFlag  (1 << 0)


typedef struct {						// Motif window manager support

   unsigned long flags;
   unsigned long functions;
   unsigned long decorations;
   long          inputMode;
   unsigned long status;

} PropMwmHints;

/* MWM Defines */
#define MWM_HINTS_FUNCTIONS		(1L << 0)
#define MWM_HINTS_DECORATIONS	(1L << 1)
#define MWM_HINTS_INPUT_MODE	(1L << 2)
#define MWM_HINTS_STATUS		(1L << 3)

#define MWM_FUNC_ALL      		(1L << 0)
#define MWM_FUNC_RESIZE			(1L << 1)
#define MWM_FUNC_MOVE			(1L << 2)
#define MWM_FUNC_MINIMIZE		(1L << 3)
#define MWM_FUNC_MAXIMIZE		(1L << 4)
#define MWM_FUNC_CLOSE			(1L << 5)

#define MWM_DECOR_ALL			(1L << 0)
#define MWM_DECOR_BORDER		(1L << 1)
#define MWM_DECOR_RESIZEH		(1L << 2)
#define MWM_DECOR_TITLE			(1L << 3)
#define MWM_DECOR_MENU			(1L << 4)
#define MWM_DECOR_MINIMIZE		(1L << 5)
#define MWM_DECOR_MAXIMIZE		(1L << 6)

#define MWM_INPUT_MODELESS                  0
#define MWM_INPUT_PRIMARY_APPLICATION_MODAL 1
#define MWM_INPUT_SYSTEM_MODAL              2
#define MWM_INPUT_FULL_APPLICATION_MODAL    3

#endif /* _mGSTEP_H_XRWindow */
