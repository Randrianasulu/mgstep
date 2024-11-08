/*
   _CGContextFB.m

   FrameBuffer graphics interface

   Copyright (C) 2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jan 2020

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSWindow.h>
#include <AppKit/NSView.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSColor.h>

#ifdef FB_GRAPHICS

#include <linux/kd.h>
#include <linux/vt.h>
#include <termios.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/mman.h>


#define NO_FLIP_TO_X(a, b)  (NSHeight(b) - NSMinY(a) - NSMinY(b) - NSHeight(a))
#define	CONVERT_Y(a, b, f)	((f) ? NSMinY(a) + NSMinY(b) : NO_FLIP_TO_X(a, b))

#define CTX				((CGContext *)cx)
#define CLIP_RECT		CTX->_gs->clip
#define XCANVAS			CTX->_gs->xCanvas
#define ISFLIPPED		CTX->_gs->isFlipped
#define GSTATE			CTX->_gs
#define CTM				CTX->_gs->hasCTM
#define SCREEN_HEIGHT	CTX->_display->_frame.size.height
#define CLAYER			CTX->_layer
#define FLUSH_ME		CTX->_flushRect

#define SBASE			((CGContext *)ly->context)->_bitmap->idata
#define SLINELEN		((CGContext *)ly->context)->_bitmap->bytesPerRow
#define SSIZE			((CGContext *)ly->context)->_bitmap->size
#define SXOFF			(int)ly->_origin.x
#define SYOFF			(int)ly->_origin.y

#define FBBASE			CTX->_display->_fbp
#define FBLINELEN		CTX->_display->_finfo.line_length
#define FBBYTES_PX		CTX->_display->_bytesPerPixel
#define FBSCRNSIZE		CTX->_display->_screensize


static struct termios __saved_tty_attr;


/* ****************************************************************************

	PS/2  Mouse init   http://www.computer-engineering.org/ps2mouse/

	FIX ME  determine mouse type, set scaling ...etc

** ***************************************************************************/

void
FBMouseInitPS2(CGContextRef cx)
{
	char buf[4];
	int count;
															// connect mouse
	if ((CTX->_mg->_mouse = open("/dev/psaux", O_RDWR|O_NONBLOCK)) == -1)
		[NSException raise: NSGenericException
					 format:@"Unable to open Linux PS/2 device (/dev/psaux)."];

	buf[0] = 0xff;											// reset mouse
	write(CTX->_mg->_mouse, buf, 1);
	count = read(CTX->_mg->_mouse, buf, 4);
	printf("RX: %#hhx  %d\n", buf[0], count);

	tcflush(CTX->_mg->_mouse, TCIFLUSH);
}

/* ****************************************************************************

	FBConsoleInit

	FIX ME  might want to intercept signals here for a graceful exit

** ***************************************************************************/

static void
FBConsoleInit(CGContextRef cx)
{
	struct termios new;
	char device[16];
	int freecon;
	int fd;

	if ((fd = open("/dev/console", O_RDONLY|O_NONBLOCK)) == -1)
		[NSException raise: NSGenericException
					 format:@"Unable to open /dev/console."];
	if (ioctl(fd, VT_OPENQRY, &freecon))
		[NSException raise: NSGenericException
					 format:@"Unable to find a free console."];

	sprintf(device, "/dev/tty%d", freecon);
	if ((CTX->_mg->_console = open(device, O_RDONLY|O_NONBLOCK)) == -1)
		[NSException raise: NSGenericException
					 format:@"Unable to open free console."];

	NSLog(@"FBConsoleInit attached to %s\n", device);
	ioctl(fd, VT_ACTIVATE, freecon);
	close(fd);

	if (tcgetattr(CTX->_mg->_console, &__saved_tty_attr) == -1)
		[NSException raise: NSGenericException
					 format:@"Linux console tcgetattr failed."];
	if (tcgetattr(CTX->_mg->_console, &new) == -1)
		[NSException raise: NSGenericException
					 format:@"Linux console tcgetattr failed."];

	new.c_lflag &= ~ (ICANON | ECHO | ISIG);
	new.c_iflag = 0;
	new.c_cc[VMIN] = 18;	// sizeof(buf);
	new.c_cc[VTIME] = 1;	// 0.1 sec char timeout

	if (tcsetattr(CTX->_mg->_console, TCSAFLUSH, &new) == -1)
		[NSException raise: NSGenericException
					 format:@"Linux console tcsetattr failed."];
	if (ioctl(CTX->_mg->_console, KDSKBMODE, K_MEDIUMRAW))
		[NSException raise: NSGenericException
					 format:@"Linux console keyboard mode change failed."];

	FBMouseInitPS2( cx );
}

void
FBConsoleClose(CGContextRef cx)
{
	int fd;

	printf("FBConsoleClose reset keyboard\n");
	if (ioctl(CTX->_mg->_console, KDSKBMODE, K_XLATE))
		NSLog(@"Failed to restore Linux console keyboard mode");
	if (tcsetattr(CTX->_mg->_console, 0, &__saved_tty_attr) == -1)
		NSLog(@"Failed to restore Linux console keyboard attributes");
	close(CTX->_mg->_console);

	if ((fd = open("/dev/console", O_RDONLY|O_NONBLOCK)) == -1)
		[NSException raise: NSGenericException
					 format:@"Unable to open /dev/console."];
	ioctl(fd, VT_ACTIVATE, 1);
	close(fd);
}

static void
FBShowTestScreen(CGContextRef cx)
{
	NSImage *uimg;

	[[NSColor whiteColor] set];

//	[[NSFont fontWithName:@"Courier" size:12] set];
	[[NSFont fontWithName:@"Helvetica" size:36] set];

	CGContextShowTextAtPoint(cx, 450, 200, ".mGSTEP", strlen(".mGSTEP"));

	if (!(uimg = [NSImage imageNamed:@"URL"]))
		NSLog (@"Failed to load URL.tiff *********\n");
	else
		{
		CGImage *x;

		if (!(x = (CGImage *)_CGContextGetImage(cx, (NSRect){500,150,50,50})))
			NSLog (@"Failed FBGetImage *********\n");
		else
			FBDrawImage(cx, x, (NSPoint){0,0}, (NSRect){550,300,50,50});

		if (![[uimg bestRepresentationForDevice:nil] drawInRect:(NSRect){550,300,50,50}])
			NSLog (@"Failed to draw URL.tiff *********\n");
		}
	NSBeep();
}

void _CGContextInitDisplay(CGContextRef cx)
{
	CGDisplay *d = (CGDisplay *)[_NSScreen alloc];

	CTX->_display = _CGInitDisplay( d );

	CTX->_bitmap = CFAllocatorAllocate(NULL, sizeof(struct _CGImage), 0);
	((CGImage *)CTX->_bitmap)->idata = d->_fbp;
	((CGImage *)CTX->_bitmap)->size = d->_screensize;
	((CGImage *)CTX->_bitmap)->bytesPerRow = d->_finfo.line_length;
	((CGImage *)CTX->_bitmap)->samplesPerPixel = d->_bytesPerPixel;
	((CGImage *)CTX->_bitmap)->bitsPerPixel = d->_vinfo.bits_per_pixel;

	[(CTX->_gs = _CGContextGetGState(cx, _CGContextAllocGState(cx))) init];
	FBConsoleInit(cx);
	_CGContextInitBlendModes(cx);
	FBEraseScreen(cx, CTX->_gs->xCanvas);
	FBShowTestScreen(cx);
}

void
NSBeep(void)
{
	ioctl( ((CGContext *)_CGContext())->_mg->_console, KDMKTONE, (int)(125 << 16) + 1591);
}

/* ****************************************************************************

	FB Context

** ***************************************************************************/

void
FBEraseScreen(CGContextRef cx, NSRect rect)
{
	CGContextSaveGState(cx);
	CGContextSetRGBFillColor(cx, 0, .5, .5, 1);
	CGContextSetBlendMode(cx, kCGBlendModeCopy);
	CGContextFillRect(cx, rect);
	CGContextRestoreGState(cx);
}

static void
putRGBPixel(CGLayer *ly, int x, int y, unsigned char pixel[3])
{
	CGContextRef cx = ly->context;
	long location;
	unsigned char r, g, b, a;

	location = (x+SXOFF) * FBBYTES_PX + (y+SYOFF) * SLINELEN;
	if (location >= SSIZE || y+SYOFF < 0)
		{
		_CGOutOfBoundsAccess(__FUNCTION__, ly, x, y, location);
		return;
		}

//printf("putRGBPixel x y %d %d  %d %d %d\n",(x+XOFF), (y+YOFF), pixel[2],pixel[1],pixel[0]);
	*(SBASE + location++) = pixel[2];
	*(SBASE + location++) = pixel[1];
	*(SBASE + location++) = pixel[0];
//	*(FBBASE + location) = color[3];
}

static void
getRGBPixel(CGLayer *ly, int x, int y, unsigned char pixel[3])
{
	CGContextRef cx = ly->context;
	long location;
	unsigned char r, g, b, a;

	location = (x+SXOFF) * FBBYTES_PX + (y+SYOFF) * SLINELEN;
	if (location >= SSIZE || y+SYOFF < 0)
		{
		_CGOutOfBoundsAccess(__FUNCTION__, ly, x, y, location);
		return;
		}

	pixel[2] = *(SBASE + location);
	pixel[1] = *(SBASE + location+1);
	pixel[0] = *(SBASE + location+2);
//printf("getRGBPixel x y %d %d  %d %d %d\n",(x+XOFF), (y+YOFF), pixel[2],pixel[1],pixel[0]);
}

void
FBFlushRect(CGContext *cx, NSRect srcRect, NSPoint destPoint)
{
	int i = (int)srcRect.origin.x;
	int j = (int)srcRect.origin.y;
	int mx = (int)MIN(NSMaxX(srcRect), i + cx->_gs->xCanvas.size.width);
	int my = (int)MIN(NSMaxY(srcRect), j + cx->_gs->xCanvas.size.height);
	int x = (int)destPoint.x;
	int y = (int)destPoint.y;

#if 0
  printf("######### FBFlushRect rect %f %f %f %f\n",
		srcRect.origin.x, srcRect.origin.y,
		srcRect.size.width, srcRect.size.height);
  printf("FBFlushRect  %d %d %d %d\n",i, j, mx, my);
#endif

	FBFlushCursor((CGContextRef)cx);

	for (j = (int)srcRect.origin.y, y = (int)destPoint.y; j < my; j++, y++)
		for (i = (int)srcRect.origin.x, x = (int)destPoint.x; i < mx; i++, x++)
			{
			unsigned char pixel[3];

			getRGBPixel(cx->_layer, i, j, pixel);  // get px from backing with 0,0 offset
			putRGBPixel(&(cx->_fb), x, y, pixel);  // put px in fb at window frame offset
			}

	FBDrawCursor((CGContextRef)cx);
}

/* ****************************************************************************

	Draw image directly to FB

** ***************************************************************************/

void
FBDrawImage(CGContextRef cx, CGImage *c, NSPoint src, NSRect rect)
{
	int x, y, i, j;
	int mx = (int)NSMaxX(rect);
	int my = (int)NSMaxY(rect);
	int s = MAX(3, c->samplesPerPixel);
	int stride = c->width * s;

#if 0
	printf("FBDrawImage s stride mx my %d %d %d %d\n",s, stride, mx, my);
#endif
	for (i = (int)rect.origin.x, x = (int)src.x; i < mx; i++, x++)
		for (j = (int)rect.origin.y, y = (int)src.y; j < my; j++, y++)
			putRGBPixel(CLAYER, i, j, c->idata + ((y * stride) + (x*s)));
}

/* ****************************************************************************

	Cursor

** ***************************************************************************/

static void
writeCursorRGBA_Pixel(CGContextRef cx, int x, int y, unsigned char *bData)
{
	long location;
	unsigned char alpha, ialpha, r, g, b, *rp, *gp, *bp;
	unsigned char rr, gg, bb;
	unsigned char *restorePtr = CTX->_mg->_cursorRestorePtr;

	location = x * FBBYTES_PX + y * FBLINELEN;
	if (location > FBSCRNSIZE)
		_CGOutOfBoundsAccess(__FUNCTION__, NULL, x, y, location);

	b = *restorePtr++ = *(FBBASE + location);
	g = *restorePtr++ = *(FBBASE + location+1);
	r = *restorePtr   = *(FBBASE + location+2);

	if (CTX->_mg->_curorNumColors == 4)
		{
		rp = bData++;
		gp = bData++;
		bp = bData++;
		alpha = (char)*bData++;
		ialpha = 255 - alpha;

		rr = ((*rp & alpha) | (r & ialpha));
		gg = ((*gp & alpha) | (g & ialpha));
		bb = ((*bp & alpha) | (b & ialpha));
		}
	else if (CTX->_mg->_curorNumColors == 1)
		bb = gg = rr = (char)*bData++;
	else
		{
		rr = (char)*bData++;
		gg = (char)*bData++;
		bb = (char)*bData++;
		}

	*(FBBASE + location++) = bb;
	*(FBBASE + location++) = gg;
	*(FBBASE + location++) = rr;
//	*(FBBASE + location) = pixel[3];
}

void
FBDrawCursorRect(CGContextRef cx, NSRect rect)
{
	int x, y;
	int w = NSMaxX(rect);
	int h = NSMaxY(rect);
	unsigned char *bData = CTX->_mg->_cursorBitmap;

	CTX->_mg->_cursorRestorePtr = CTX->_mg->_cursorRestoreBuf;

	for (y = NSMinY(rect); y < h; y++)
		for (x = NSMinX(rect); x < w; x++)
			{
			writeCursorRGBA_Pixel(cx, x, y, bData);
			CTX->_mg->_cursorRestorePtr += 3;
			bData += 4;
			}
	CTX->_mg->_cursorRestorePtr = CTX->_mg->_cursorRestoreBuf;
}

static void
restoreCursorPixel(CGContextRef cx, int x, int y)
{
	long int location;
	unsigned char *restorePtr = CTX->_mg->_cursorRestorePtr;
		
	location = x * FBBYTES_PX + y * FBLINELEN;
	if (location > FBSCRNSIZE)
		_CGOutOfBoundsAccess(__FUNCTION__, NULL, x, y, location);

	*(FBBASE + location++) = *restorePtr++;
	*(FBBASE + location++) = *restorePtr++;
	*(FBBASE + location++) = *restorePtr;
}

void
FBRestoreCursorRect(CGContextRef cx, NSRect rect)
{
	int x, y;
	int w = NSMaxX(rect);
	int h = NSMaxY(rect);

	if (CTX->_mg->_cursorRestorePtr)
		for (y = NSMinY(rect); y < h; y++)
			for (x = NSMinX(rect); x < w; x++)
				{
				restoreCursorPixel(cx, x, y);
				CTX->_mg->_cursorRestorePtr += 3;
				}
}

CGImageRef _CGContextCreateImage(CGContextRef cx, CGSize z)
{
	int w = z.width;
	int h = z.height;
	unsigned m_sys_bpp = 32;	// also quantum of a scanline (8, 16, or 32)
	size_t br = z.width * 32 / 8;

	CGImageRef img = CGImageCreate( w, h, 8, 32, br, NULL, 0, NULL, NULL, 0, 0);

	return img;
}

CGImageRef _CGContextResizeBitmap(CGContextRef cx, CGSize z)
{
	return _CGImageResize( CTX->_bitmap, (int)z.width, (int)z.height);
}

/* ****************************************************************************

	FB Clip

** ***************************************************************************/

void _CGContextSetClipRect(CGContextRef cx, CGRect rect)
{													// set device coords clip
	if(rect.origin.y < 0)
		{
		fprintf(stderr,"FB ClipToRect error: negative clip rect origin\n");
printf("######### FB ClipToRect clip %f %f %f %f\n",
		rect.origin.x, rect.origin.y,
		rect.size.width, rect.size.height);
		return;
		}

	if (NSMaxY(rect) > SCREEN_HEIGHT)
		NSHeight(rect) = SCREEN_HEIGHT - NSMinY(rect);
	CLIP_RECT = rect;

	_clip_rect(cx, CLIP_RECT);
}

/* ****************************************************************************

	Intersect current clipping path with `rect'.  Resets context path to empty.

** ***************************************************************************/

void CGContextClipToRect(CGContextRef cx, CGRect rect)
{
	NSPoint org;
	CGRect r;

	if (CTM)
		rect = CGRectApplyAffineTransform(rect, GSTATE->_ctm);

	org.x = NSMinX(rect) + NSMinX(XCANVAS);
	org.y = CONVERT_Y(rect, XCANVAS, ISFLIPPED);

#if 0
  printf("######### CGContextClipToRect scr o clip %f %f %f %f\n",
		CLIP_RECT.origin.x, CLIP_RECT.origin.y,
		CLIP_RECT.size.width, CLIP_RECT.size.height);
  printf("######### CGContextClipToRect rect %f %f %f %f\n",
		org.x, org.y, rect.size.width, rect.size.height);
#endif

	r = NSIntersectionRect((NSRect){org, rect.size}, CLIP_RECT);

	_CGContextSetClipRect(cx, r);

#if 0
  printf("######### CGContextClipToRect device clip %f %f %f %f\n",
		CLIP_RECT.origin.x, CLIP_RECT.origin.y,
		CLIP_RECT.size.width, CLIP_RECT.size.height);
#endif
//	NSLog(@"CGContextClipToRect %@", NSStringFromRect(CLIP_RECT));
	if (NSIsEmptyRect(CLIP_RECT))
		NSLog(@"CGContextClipToRect emptpy");
}	

void _CGContextRectNeedsFlush(CGContextRef cx, CGRect rect)
{
	rect = NSIntersectionRect(rect, (NSRect){0,0, CTX->_gs->xCanvas.size});
	FLUSH_ME = NSUnionRect(FLUSH_ME, rect);

	if (FLUSH_ME.origin.y < 0 || FLUSH_ME.origin.x < 0)
		{
		NSLog (@"_rectNeedsFlush (%f, %f) (%f, %f)\n",
					FLUSH_ME.origin.x, FLUSH_ME.origin.y,
					FLUSH_ME.size.width, FLUSH_ME.size.height);
		NSLog (@"_rectNeedsFlush (%f, %f) (%f, %f)\n",
					rect.origin.x, rect.origin.y,
					rect.size.width, rect.size.height);
		}

	if (CTX->_window)
		[CTX->_window _needsFlush];
}

void CGContextFlush( CGContextRef cx)
{
	DBLog (@"flushWindow (%f, %f) (%f, %f)\n",
			FLUSH_ME.origin.x, FLUSH_ME.origin.y,
			FLUSH_ME.size.width, FLUSH_ME.size.height);

	FBFlushRect((CGContext *)cx, FLUSH_ME, FLUSH_ME.origin);

	FLUSH_ME = NSZeroRect;
}

void _CGContextBitmapNeedsFlush(int x, int y, int xm, int ym)				{ }
void _CGContextFlushBitmap(CGContextRef cx, int x, int y, int xm, int ym)	{ }
void  CGContextSynchronize(CGContextRef cx)									{ }

/* ****************************************************************************

	Graphic state object

** ***************************************************************************/

@implementation _GState

- (id) init
{
	CGContext *cx = (CGContext *)context;

	xCanvas = ((CGDisplay *)cx->_display)->_frame;
	isFlipped = 1;
	CGContextSetBlendMode( (CGContextRef)cx, cx->_gs->blendMode);

	return self;
}

- (void) dealloc
{
	if (_line.dash.lengths)
		free(_line.dash.lengths),	_line.dash.lengths = NULL;

	[super dealloc];
}

@end  /* _GState */

#endif  /* !FB_GRAPHICS   */
