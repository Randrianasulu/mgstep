/*
   _CGDirectDisplay.h

   Display screen private

   Copyright (C) 2009 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Nov 2009

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_FBScreen
#define _mGSTEP_H_FBScreen

#include <AppKit/NSScreen.h>


#ifdef FB_GRAPHICS /* FB_GRAPHICS  ***************************** FB Graphics */

#include <linux/fb.h>

@class NSWindow;


@interface _NSScreen : NSScreen
{
	char *_fbp;
	int _bytesPerPixel;
	int _screensize;
	int _fbd;

	struct fb_var_screeninfo _vinfo;
	struct fb_fix_screeninfo _finfo;

	NSWindow *_visibleWindowList;
}

@end

#else  /* !FB_GRAPHICS  **************************************** XR Graphics */


@interface _NSScreen : NSScreen
{
	Display *xDisplay;
	Window xRootWindow;
	Window xAppRootWindow;
	Window xAppTileWindow;

	int _xScreen;
	Visual *_visual;
	Colormap _colormap;

	Atom _stateAtom;
	Atom _protocolsAtom;
	Atom _deleteWindowAtom;
	Atom _takeFocusAtom;
//	Atom _windowStateAtom;
	Atom _windowDecorAtom;

	struct __ScreenFlags {
		unsigned int hasComposite:1;
		unsigned int hasOpenGL:1;
		unsigned int hasRender:1;
		unsigned int hasShape:1;
		unsigned int hasLuzWM:1;
		unsigned int reserved:27;
	} _sf;
}

@end

@interface NSScreen  (XRScreenExtension)

- (Display *) xDisplay;

- (Window) xRootWindow;
- (Window) xAppRootWindow;
- (Window) wAppTileWindow;

- (BOOL) xHasLuzWindowManager;
- (BOOL) xTrapProtocolErrors;

@end

#endif


typedef struct _CGDisplay    { @defs(_NSScreen); } CGDisplay;

extern CGDisplay * _CGInitDisplay( CGDisplay *d );
extern void        _CGCloseDisplay( CGDisplay *d );


#endif /* _mGSTEP_H_FBScreen */
