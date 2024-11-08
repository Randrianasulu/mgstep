/*
   CGImage.h

   Image functions and structures.

   Copyright (C) 2009 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Mar 2009

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CGImage
#define _mGSTEP_H_CGImage

#include <CoreGraphics/CGColorSpace.h>
#include <CoreGraphics/CGDataProvider.h>

typedef enum {
	kCGImageAlphaNone,                   // RGB
	kCGImageAlphaPremultipliedLast,      // RGBA premultiplied
	kCGImageAlphaPremultipliedFirst,     // ARGB premultiplied
	kCGImageAlphaLast,                   // RGBA
	kCGImageAlphaFirst,                  // ARGB
	kCGImageAlphaNoneSkipLast,           // RBGX
	kCGImageAlphaNoneSkipFirst,          // XRGB
	kCGImageAlphaOnly,                   // alpha bit plane
} CGImageAlphaInfo;

typedef enum {
	kCGBitmapByteOrderDefault  = 0,
	kCGBitmapAlphaInfoMask     = 0x1F,   // CGImageAlphaInfo mask
	kCGBitmapFloatComponents   = (1 << 8),
	kCGBitmapByteOrder16Little = (1 << 12),
	kCGBitmapByteOrder32Little = (2 << 12),
	kCGBitmapByteOrder16Big    = (3 << 12),
	kCGBitmapByteOrder32Big    = (4 << 12),
	_kCGBitmapByteOrderBGR     = (5 << 12),
	kCGBitmapByteOrderMask     = 0x7000
} CGBitmapInfo;


typedef const struct _CGImage * CGImageRef;

typedef CFTypeID CGColorRenderingIntent;


typedef struct _CGImage {

	void *class_pointer;
	void *cf_pointer;

    unsigned int width;					// size of the image
    unsigned int height;

	unsigned int size;

	int bitsPerPixel;
	int bitsPerComponent;
	int samplesPerPixel;				// Bytes/Px: GRAY 1-2, RGB 3, RBGA 4

//  int depth;							// depth of image
    int bytesPerRow;					// accelarator, line length to next
//	int line_length;

    unsigned char *idata;				// image data RGBA, RGB, GRAY

	CGColorSpaceRef colorspace;
	CGDataProviderRef provider;

	CGImageRef cimage;					// scaled cache of image data

#ifndef FB_GRAPHICS
	void *ximage;						// wrapped XImage
#endif

	struct __ImageFlags {
		unsigned int dontFree:1;		// struct alloc on stack, don't free
		unsigned int shouldInterpolatePixels:1;
		CGBitmapInfo bitmapInfo:16;
		unsigned int cache:1;
		unsigned int isOpaque:1;
		unsigned int reuseSource:1;
		unsigned int externalData:1;	// image data is not owned, don't free
		unsigned int reserved:10;
	} _f;

} CGImage;


extern CGImageRef CGImageRetain (CGImageRef img);
extern void       CGImageRelease (CGImageRef img);

/* ****************************************************************************

	size_t bitsPerComponent			bits per color component (RGBA32 = 8)
	size_t bitsPerPixel				bits in a source pixel (min: BPC)
	size_t bytesPerRow				line length = width * (BPP / BPC)
	CGColorSpaceRef					GRAY, RGB, CMYK
	CGBitmapInfo					has alpha and where
	CGDataProviderRef				opaque type that supplies data
	const CGFloat decodeMap[]		remap image colors
	bool shouldInterpolatePixels	smooth pixels if rendered at higher res
	CGColorRenderingIntent method	color space remap method

** ***************************************************************************/

extern CGImageRef  CGImageCreate( size_t width,
								  size_t height,
								  size_t bitsPerComponent,
								  size_t bitsPerPixel,
								  size_t bytesPerRow,
								  CGColorSpaceRef colorspace,
								  CGBitmapInfo bitmapInfo,
								  CGDataProviderRef provider,
								  const CGFloat decodeMap[],
								  bool shouldInterpolatePixels,
								  CGColorRenderingIntent method );

extern CGImageRef  CGImageMaskCreate( size_t width,
									  size_t height,
									  size_t bitsPerComponent,
									  size_t bitsPerPixel,
									  size_t bytesPerRow,
									  CGDataProviderRef provider,
									  const CGFloat decodeMap[],
									  bool shouldInterpolate );

									// create new by masking image
extern CGImageRef CGImageCreateWithMask(CGImageRef img, CGImageRef mask);

extern CGImageRef CGImageCreateCopy(CGImageRef img);
									// create new from sub-rect of image
extern CGImageRef CGImageCreateWithImageInRect(CGImageRef img, CGRect r);
									// create new image masked by min/max array
									// of colorspace num components * 2
extern CGImageRef CGImageCreateWithMaskingColors(CGImageRef img,
												 const CGFloat components[]);
extern size_t CGImageGetWidth( CGImageRef img );
extern size_t CGImageGetHeight( CGImageRef img );

extern size_t CGImageGetBytesPerRow( CGImageRef img );
extern size_t CGImageGetBitsPerPixel( CGImageRef img );
extern size_t CGImageGetBitsPerComponent( CGImageRef img );

extern bool   CGImageIsMask( CGImageRef img );

extern CGColorSpaceRef CGImageGetColorSpace(CGImageRef img);

/* ****************************************************************************

	Private

** ***************************************************************************/

extern CGImageRef _CGImageMaskCreateWithMaskingColors( CGImageRef s,
												 const CGFloat components[]);

extern CGImageRef _CGScaleImage(CGImageRef s, unsigned width, unsigned height);
extern CGImageRef _CGSmoothScaleImage( CGImageRef s, unsigned w, unsigned h );
extern CGImageRef _CGZoomFilter( CGImageRef src, unsigned w, unsigned h );

extern void _CGImageGetPixel(CGImage *img, int x, int y, CGColorRef c);
extern void _CGImagePutPixel(CGImage *img, int x, int y, CGColorRef c);

extern void _CGBevelImage(CGImage *img, CGRect r, bool highlight, bool bevel);

extern CGImageRef _CGImageResize( CGImageRef img, size_t width, size_t height);

extern CGImageRef  _CGImageReadPNM(CFDataRef d);
extern void _CGImageWritePNM(CGImageRef img, const char *name, int frameCounter);

extern bool _CGImageCanInitWith( CFDataRef d, const u8 *sig, unsigned long slen);

#endif /* _mGSTEP_H_CGImage */
