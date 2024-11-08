/*
   _CoreGraphics.h

   Private CoreGraphics interface

   Copyright (C) 2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Oct 2020

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CoreGraphics_Private
#define _mGSTEP_H_CoreGraphics_Private

#ifndef FB_GRAPHICS
	#include <X11/Xlib.h>
	#include <X11/Xutil.h>
	#include <X11/keysym.h>
	#include <X11/Xatom.h>
	#include <X11/extensions/shape.h>
  #define BOOL XWINDOWSBOOL						// prevent X windows BOOL
	#include <X11/Xlibint.h>
	#include <X11/Xmd.h>						// warning
  #undef BOOL
	#include <CoreGraphics/Private/XRBitmapImageRep.h>
	#include <CoreGraphics/Private/XRWindow.h>
	#include <CoreGraphics/Private/XRCursor.h>
#endif

#include <CoreGraphics/Private/_CGColor.h>
#include <CoreGraphics/Private/_CGDirectDisplay.h>
#include <CoreGraphics/Private/_CGContext.h>

#endif /* _mGSTEP_H_CoreGraphics_Private */
