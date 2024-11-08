/*
   CGDirectDisplay.m

   Display and screens management

   Copyright (C) 2017 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jun 2017

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>

#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFRuntime.h>
#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSGraphicsContext.h>
#include <AppKit/NSWindow.h>

#include <fcntl.h>
#include <sys/mman.h>


#define CTX			((CGContext *)_CGContext())



CGDirectDisplayID
CGMainDisplayID(void)
{
	return PTR2UINT( CTX->_display );
}

CGImageRef
CGDisplayCreateImage( CGDirectDisplayID d )
{
	size_t w = CGDisplayPixelsWide(d);
	size_t h = CGDisplayPixelsHigh(d);
	
	return CGDisplayCreateImageForRect(d, NSMakeRect(0, 0, w, h));
}

size_t CGDisplayPixelsWide( CGDirectDisplayID d )
{
	return (d == CGMainDisplayID()) ? CTX->_display->_frame.size.width : 0;
}

size_t CGDisplayPixelsHigh( CGDirectDisplayID d )
{
	return (d == CGMainDisplayID()) ? CTX->_display->_frame.size.height : 0;
}

CGContextRef CGDisplayGetDrawingContext( CGDirectDisplayID d )
{
	return (d == CGMainDisplayID()) ? _CGContext() : NULL;  // FIX ME needs mapping
}

/* ****************************************************************************

	FB Display

** ***************************************************************************/

#ifdef FB_GRAPHICS  /* ******************************************** FBScreen */

@implementation _NSScreen
@end

CGDisplay *
_CGInitDisplay( CGDisplay *d )
{
	if ((d->_fbd = open("/dev/fb0", O_RDWR)) == -1) 		// connect to fb
		[NSException raise: NSGenericException
					 format:@"Unable to open Linux Framebuffer /dev/fb0."];

    if (ioctl(d->_fbd, FBIOGET_FSCREENINFO, &d->_finfo))
		[NSException raise: NSGenericException
					 format:@"Error getting fixed Framebuffer screen info."];

    if (ioctl(d->_fbd, FBIOGET_VSCREENINFO, &d->_vinfo))
		[NSException raise: NSGenericException
					 format:@"Error getting variable Framebuffer screen info."];

											// Determine screen size in bytes
    d->_bytesPerPixel = d->_vinfo.bits_per_pixel / 8;
    d->_screensize = d->_vinfo.xres * d->_vinfo.yres * d->_bytesPerPixel;
											// Memory map frame buffer device
    d->_fbp = (char *)mmap(0, d->_screensize, PROT_READ|PROT_WRITE, MAP_SHARED, d->_fbd, 0);
    if (PTR2INT(d->_fbp) == -1)
		[NSException raise: NSGenericException
					 format:@"Failed to memory map the framebuffer device."];

    NSLog(@"FB: Mapped framebuffer device to memory.\n");
	NSLog(@"FB: Bits per pixel %d\n", d->_vinfo.bits_per_pixel);
	NSLog(@"FB: X res %d \n", d->_vinfo.xres);
	NSLog(@"FB: Y res %d\n", d->_vinfo.yres);
	NSLog(@"FB: Line length %d\n",  d->_finfo.line_length);

	d->_depth = d->_vinfo.bits_per_pixel;
	d->_frame.size.width = (float)d->_vinfo.xres;
	d->_frame.size.height = (float)d->_vinfo.yres;

	return d;
}

void
_CGCloseDisplay(CGDisplay *d)
{
    munmap(d->_fbp, d->_screensize);
    close(d->_fbd);
	d->_fbp = NULL;
	d->_fbd = -1;
}

CGImageRef CGDisplayCreateImageForRect( CGDirectDisplayID d, CGRect r )
{
	return (CGImageRef)NULL;
}

#else  /* ********************************************************* XRScreen */

/* ****************************************************************************

	XR Display

** ***************************************************************************/

#define ATOMS_SIZE  sizeof(__atomNames)/sizeof(char*)

static char *__atomNames[] = {
    "WM_STATE",
    "WM_PROTOCOLS",
    "WM_DELETE_WINDOW",
    "WM_TAKE_FOCUS",
    "_LUZ_WM_STATE"
};


@implementation _NSScreen

- (Display *) xDisplay						{ return xDisplay; }

- (Window) xAppTileWindow					{ return xAppTileWindow; }
- (Window) xAppRootWindow					{ return xAppRootWindow; }
- (Window) xRootWindow						{ return xRootWindow; }

- (BOOL) xHasLuzWindowManager				{ return _sf.hasLuzWM; }
- (BOOL) xTrapProtocolErrors				{ return YES; }

@end


static BOOL
_hasLuzWM( Display *dpy, Window root )
{
	Atom actual;
	int format;
	unsigned long num_items, remaining;
	unsigned char *data = 0;

    if (XGetWindowProperty(dpy, root,
						   XInternAtom(dpy, "_WINDOWMAKER_WM_PROTOCOLS", False),
						   0, 0x8000000L, False, XA_ATOM,
						   &actual, &format,
						   &num_items, &remaining, &data) == Success)
		{
		NSLog(@"XRHasLuzWM: num items %d", num_items);

		if (num_items > 0)
			{
			if (data)
				XFree(data);

			return YES;
		}	}
	else
		NSLog(@"XRHasLuzWM: XGetWindowProperty failed");

	return NO;
}

static int
_XRProtocolErrorHandler(Display *d, XErrorEvent *e)
{
	if (!e)
		fprintf(stderr, "XError: NULL\n");
	else
		{
		char buf[64];
		char code[32];

		XGetErrorText(d, e->error_code, buf, sizeof(buf));
		NSLog(@"XError: %s", buf);

		snprintf(code, sizeof(code), "%d", e->request_code);
		XGetErrorDatabaseText(d, "XRequest", code, "?", buf, sizeof(buf));
		NSLog(@"   Request Code: %d (%s)", e->request_code, buf);
		NSLog(@"   Minor Code: %d", e->minor_code);
		NSLog(@"   Resource ID: 0x%lx", (unsigned long)e->resourceid);
		NSLog(@"   Error Serial: %lu", (unsigned long)e->serial);
		}

	return 0;
}

CGDisplay *
_CGInitDisplay( CGDisplay *d )
{
	Atom atoms[ATOMS_SIZE];
	int eventp, errorp;

	if ([(NSScreen *)d xTrapProtocolErrors])
		XSetErrorHandler(_XRProtocolErrorHandler);

	if ((d->xDisplay = XOpenDisplay(NULL)) == NULL) 	// connect to X server
		[NSException raise: NSGenericException
					 format:@"Unable to connect to X server."];

	d->_xScreen = DefaultScreen(d->xDisplay);
	d->_frame.size.width = (float)DisplayWidth(d->xDisplay, d->_xScreen);
	d->_frame.size.height = (float)DisplayHeight(d->xDisplay, d->_xScreen);

	d->xRootWindow = RootWindow(d->xDisplay, d->_xScreen);
	d->_depth = DefaultDepth(d->xDisplay, d->_xScreen);
	d->_visual = DefaultVisual(d->xDisplay, d->_xScreen);
	d->_colormap = XDefaultColormap(d->xDisplay, d->_xScreen);

	if (d->_visual->class == PseudoColor || d->_visual->class == StaticColor)
		fprintf(stderr, "mGSTEP does not support pseudo color visuals\n");
	else if (d->_visual->class == GrayScale || d->_visual->class == StaticGray)
		fprintf(stderr, "mGSTEP does not support gray scale visuals\n");

    if (XInternAtoms(d->xDisplay, __atomNames, ATOMS_SIZE, False, atoms) == 0)
		[NSException raise: NSGenericException format:@"XInternAtoms()"];

    d->_stateAtom        = atoms[0];
    d->_protocolsAtom    = atoms[1];
    d->_deleteWindowAtom = atoms[2];
    d->_takeFocusAtom    = atoms[3];
    d->_windowDecorAtom  = atoms[4];

	d->xAppRootWindow = XCreateSimpleWindow(d->xDisplay, d->xRootWindow, 0,0,1,1,0,1,0);

	if (!(d->_sf.hasLuzWM = [(NSScreen *)d xHasLuzWindowManager]))
		d->_sf.hasLuzWM = _hasLuzWM(d->xDisplay, d->xRootWindow);

	if (XShapeQueryExtension(d->xDisplay, &eventp, &errorp))
		d->_sf.hasShape = YES;

	return d;
}

void
_CGCloseDisplay(CGDisplay *d)
{
	XDestroyWindow (d->xDisplay, d->xAppRootWindow);
	XCloseDisplay(d->xDisplay);
	d->xDisplay = NULL;
}

CGImageRef CGDisplayCreateImageForRect( CGDirectDisplayID d, CGRect r )
{
	CGImage *img = NULL;
	XImage *xi;

	if ((xi = XRGetXImageFromRootWindow(CGDisplayGetDrawingContext(d), r)))
		{
		img = (CGImage *)CGImageCreate(1, 1, 8, 32, 0, NULL,0, NULL,NULL, 0,0);
		img->width = (size_t)r.size.width;
		img->height = (size_t)r.size.height;
		img->size = img->width * img->height * img->samplesPerPixel;
		img->bytesPerRow = img->width * img->bitsPerPixel / 8;
		img->ximage = xi;
		img->idata = xi->data;
		img->_f.bitmapInfo = _kCGBitmapByteOrderBGR;
		img->_f.externalData = YES;
		}

	return (CGImageRef)img;
}

#endif  /* XRScreen */


const NSWindowDepth *
NSAvailableWindowDepths(void)
{
#if 0						// FIX ME implement X11 display screen query
	int count;
	int *xDepths = XListDepths([NSScreen xDisplay], screen_number, &count);
// int XScreenCount(display)
// Screen *XScreenOfDisplay(display, screen_number)
#endif
	static NSWindowDepth depthsArray[] = {0, 0};

	depthsArray[0] = [[NSScreen mainScreen] depth];

	return depthsArray;
}

NSWindowDepth
NSBestDepth( NSString *colorSpace,
			 int bitsPerSample,
			 int bitsPerPixel,
			 BOOL planar,
			 BOOL *exactMatch )
{
	return [NSWindow defaultDepthLimit];
}

int NSBitsPerPixelFromDepth(NSWindowDepth depth)	{ return 0; }
int NSBitsPerSampleFromDepth(NSWindowDepth depth)	{ return 8; } // per color
