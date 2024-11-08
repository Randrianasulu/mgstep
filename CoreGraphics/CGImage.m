/*
   CGImage.m

   Image functions and structures.

   Copyright (C) 2006-2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jan 2006

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSData.h>

#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFRuntime.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSColor.h>

#include <assert.h>



static void __CGImageDeallocate(CFTypeRef cf)
{
	if (cf)
		{
#ifndef FB_GRAPHICS
		if (((CGImage *)cf)->ximage != NULL)
			{
			XImage *xi = (XImage *)((CGImage *)cf)->ximage;

			((CGImage *)cf)->ximage = NULL;
			if ((void *)((CGImage *)cf)->idata == (void *)xi->data)
				if (!((CGImage *)cf)->_f.externalData)
					xi->data = NULL;
			XDestroyImage(xi);
			}
#endif
		}
}

static const CFRuntimeClass __CGImageClass = {
	_CF_VERSION,
	"CGImage",
	__CGImageDeallocate
};

CGImageRef
CGImageCreate (size_t width,
			   size_t height,
			   size_t bitsPerComponent,			// bits in each color component
			   size_t bitsPerPixel,				// bits in a pixel
			   size_t bytesPerRow,				// width * (BPP / BPC)
			   CGColorSpaceRef s,				// GRAY, RGB, CMYK
			   CGBitmapInfo bitmapInfo,			// has alpha and where
			   CGDataProviderRef provider,
			   const CGFloat decodeMap[],		// remap image colors
			   bool shouldInterpolatePixels,
			   CGColorRenderingIntent method )
{
	int samplesPerPixel = bitsPerPixel / bitsPerComponent;
	int size = width * height * samplesPerPixel;
	CGImage *img = CFAllocatorAllocate(NULL, sizeof(CGImage) + size + 8, 0);

    assert(width > 0 && height > 0);

    if (img)
		{
		img->cf_pointer = (void *)&__CGImageClass;
		img->width = width;
		img->height = height;
		img->size = size;
		img->colorspace = (s) ? s : CGColorSpaceCreateDeviceRGB();
		img->provider = CGDataProviderRetain(provider);
		img->bitsPerPixel = MAX(bitsPerPixel, 8);
		img->samplesPerPixel = samplesPerPixel;
		img->bitsPerComponent = MAX(bitsPerComponent, 8);
		img->bytesPerRow = width * img->bitsPerPixel / 8;
		img->_f.bitmapInfo = bitmapInfo;
		img->_f.shouldInterpolatePixels = shouldInterpolatePixels;
		img->idata = (void *)img + sizeof(CGImage);
		
		if (provider)
			_CGDataProviderLoadImage(provider, img);
		else
			memset (img->idata, 0xff, size);
		}

    return img;
}

CGImageRef
CGImageCreateCopy(CGImageRef img)
{
	return CGImageCreate( ((CGImage *)img)->width,
						  ((CGImage *)img)->height,
						  ((CGImage *)img)->bitsPerComponent,
						  ((CGImage *)img)->bitsPerPixel,
						  ((CGImage *)img)->bytesPerRow,
						  ((CGImage *)img)->colorspace,
						  ((CGImage *)img)->_f.bitmapInfo,
						  NULL,
						  NULL,
						  ((CGImage *)img)->_f.shouldInterpolatePixels,
						  0 );
}

CGImageRef
CGImageRetain(CGImageRef image)
{
	return (image) ? CFRetain(image) : image;
}

void
CGImageRelease(CGImageRef image)
{
	if (image)
		{
		if (((CGImage *)image)->_f.dontFree)	// if stack alloc'd CGImage
			__CGImageDeallocate(image);			// free only backend image
		else
			CFRelease(image);
		}
}

size_t CGImageGetWidth( CGImageRef img )	{ return (img) ? img->width : 0; }
size_t CGImageGetHeight( CGImageRef img )	{ return (img) ? img->height : 0; }

size_t CGImageGetBytesPerRow(CGImageRef p)	{ return (p) ? p->bytesPerRow : 0; }
size_t CGImageGetBitsPerPixel(CGImageRef p) { return (p) ? 0 : 0; }

size_t
CGImageGetBitsPerComponent( CGImageRef img )
{
	return (img) ? img->bitsPerPixel / MAX(img->samplesPerPixel, 2) : 0;
}

CGColorSpaceRef
CGImageGetColorSpace(CGImageRef img)
{
	return (img) ? img->colorspace : NULL;
}

CGImageRef
_CGImageCreateWithColorMask(CGImageRef img, CGImageRef mask, CGColorRef cl)
{
	CGImageRef new = (img->_f.reuseSource) ? img : CGImageCreateCopy(img);
	unsigned char *ip = img->idata;
	unsigned char *op = new->idata;
	unsigned char r = 0x55;			// FIX ME should detect pixel color order
	unsigned char g = 0x55;			// currently hardwired for RGBA to BGRA on
	unsigned char b = 0x55;			// X11 and RGBA to RGB on fb
	int row, col;

	if (cl)							// reduce color weight if alpha < 1
		{							// FIX ME merge with mask alpha mixing ?
		unsigned char a = 255 * (1.0 - ((CGColor *)cl)->_alpha);

		if (a > 20)
			a -= 20;
		r = a + ((CGColor *)cl)->_c.red * ((CGColor *)cl)->_alpha * 255;
		g = a + ((CGColor *)cl)->_c.green * ((CGColor *)cl)->_alpha * 255;
		b = a + ((CGColor *)cl)->_c.blue * ((CGColor *)cl)->_alpha * 255;
		}

	for (row = 0; row < img->height && row < mask->height; row++)
		for (col = 0; col < img->width && col < mask->width; col++)
			{
			unsigned char m = mask->idata[row*mask->width+col];
			unsigned char ialpha = 255 - m;
									// FIX ME hardwired for 24/8 out img
			*op++ = ((*ip++ * m) + (r * ialpha)) >> 8;
			*op++ = ((*ip++ * m) + (g * ialpha)) >> 8;
			*op++ = ((*ip++ * m) + (b * ialpha)) >> 8;
			}

	return new;
}

CGImageRef
CGImageCreateWithMask(CGImageRef img, CGImageRef mask)
{
	CGColor cl = {0};
	
	cl._c.red = 0;
	cl._c.green = 0;
	cl._c.blue = 0;
	cl._alpha = 2/3;

	return _CGImageCreateWithColorMask( img, mask, &cl );
}

CGImageRef
CGImageCreateWithMaskingColors(CGImageRef img, const CGFloat components[])
{
	CGImage *ni = CFAllocatorAllocate(NULL, sizeof(CGImage) + img->size, 0);
	unsigned char ialpha, *bData = img->idata;
	unsigned int j, i, k;
	char *cData;

    if (ni)									// FIX ME img may not be a mask
		{
		ni->cf_pointer = (void *)&__CGImageClass;
		ni->width = img->width;
		ni->height = img->height;
		ni->size = img->size;
		ni->samplesPerPixel = img->samplesPerPixel;
		ni->colorspace = img->colorspace;
		ni->idata = cData = (void *)ni + sizeof(CGImage);
		}

	for (j = 0; j < img->size; j++)
		{
		for (i = 0; i < 8; i++)				// FIX ME bitsPerComponent
			{
			for (k = 0; k < 2 * img->samplesPerPixel; k += 2)
				{
				ialpha = (unsigned short)((char)*bData++);
				if (ialpha > components[k] && ialpha <= components[k+1])
					*cData |= (0x01 << i);
				}
			}
		cData++;
		}

	return ni;
}

CGImageRef
_CGImageMaskCreateWithMaskingColors(CGImageRef img, const CGFloat components[])
{
	unsigned char ialpha, *bData = img->idata;
	unsigned int j, i, k;
	int size = (img->width * img->height);
	int bitmapSize = MAX(size/8,1);
	char *cData;
	CGImage *ni = CFAllocatorAllocate(NULL, sizeof(CGImage) + bitmapSize, 0);

    if (ni)									// FIX ME img may not be a mask
		{
		ni->cf_pointer = (void *)&__CGImageClass;
		ni->width = img->width;
		ni->height = img->height;
		ni->size = bitmapSize;
		ni->samplesPerPixel = 1;
		ni->bitsPerPixel = 1;
		ni->colorspace = CGColorSpaceCreateDeviceGray();
		ni->idata = cData = (void *)ni + sizeof(CGImage);
		}

	for (j = 0; j < bitmapSize; j++)
		{
		for (i = 0; i < 8; i++)				// FIX ME bitsPerComponent
			{
			for (k = 0; k < 2 * img->samplesPerPixel; k += 2)
				{
				ialpha = (unsigned short)((char)*bData++);
				if (ialpha > components[k] && ialpha <= components[k+1])
					*cData |= (0x01 << i);
				}
			}
		cData++;
		}

	return ni;
}

/* ****************************************************************************

   ScaleImage derived from WindowMaker Raster graphics library  (scale.c)
   fixed point math idea from Imlib by Carsten Haitzler (Rasterman)

   Copyright (c) 1997, 1988, 1999 Alfredo K. Kojima

** ***************************************************************************/

CGImageRef
_CGScaleImage(CGImageRef src, unsigned w, unsigned h)
{
	int bpp;
	int ox, px, py;
	register int x, y, t;
	int dx, dy;
	unsigned char *s;
	unsigned char *d;
	CGImageRef img;

    if (w == src->width && h == src->height)
		return src;

	bpp = src->samplesPerPixel * 8;
    if (!(img = CGImageCreate( w, h, 8, bpp, 0, NULL, 0, NULL, NULL, 0, 0)))
		return NULL;

    dx = (src->width << 16) / w;
    dy = (src->height << 16) / h;
    py = 0;
    d = img->idata;

	switch (src->samplesPerPixel)
		{
		case 4:										// RGBA
			for (y=0; y < h; y++)
				{
				t = src->width * (py >> 16);
				s = src->idata + (t << 2); 			// src->idata + t*4
				ox = 0;
				px = 0;

				for (x=0; x < w; x++)
					{
					px += dx;

					*(d++) = *(s);
					*(d++) = *(s+1);
					*(d++) = *(s+2);
					*(d++) = *(s+3);

					t = (px - ox) >> 16;
					ox += t<<16;
					s += t<<2; 						// t*4
					}
				py += dy;
				}
			break;

		case 3:										// RGB
			for (y=0; y < h; y++)
				{
				t = src->width * (py >> 16);
				s = src->idata + (t << 1) + t;		// src->idata + t*3
				ox = 0;
				px = 0;

				for (x=0; x < w; x++)
					{
					px += dx;

					*(d++) = *(s);
					*(d++) = *(s+1);
					*(d++) = *(s+2);

					t = (px - ox) >> 16;
					ox += t << 16;
					s += (t<<1) + t; 				// t*3
					}
				py += dy;
				}
			break;

		default:									// GRAY
			for (y=0; y < h; y++)
				{
				t = src->width * (py >> 16);
				s = src->idata + t;
				ox = 0;
				px = 0;

				for (x=0; x < w; x++)
					{
					px += dx;

					*(d++) = *(s);

					t = (px - ox) >> 16;
					ox += t << 16;
					s += t;
					}
				py += dy;
				}
			break;
		}
    
    return img;
}

void
_CGImagePutPixel(CGImage *m, int x, int y, CGColor *c)
{
	long offset;

	offset = (y * m->width * m->samplesPerPixel) + (x * m->samplesPerPixel);
	if (offset > m->size)
		[NSException raise: NSGenericException
					format: @"_CGImagePutPixel out of bounds access."];

	*(m->idata + offset++) = c->_red;
	*(m->idata + offset++) = c->_green;
	*(m->idata + offset) = c->_blue;
}

void
_CGImageGetPixel(CGImage *m, int x, int y, CGColor *c)
{
	long offset;

	offset = (y * m->width * m->samplesPerPixel) + (x * m->samplesPerPixel);
	if (offset > m->size)
		[NSException raise: NSGenericException
					format: @"_CGImageGetPixel out of bounds access."];

	c->_red   = *(m->idata + offset++);
	c->_green = *(m->idata + offset++);
	c->_blue  = *(m->idata + offset++);
}

/* ****************************************************************************

	_CGBevelImage

** ***************************************************************************/

void _CGBevelImage(CGImage *img, NSRect rect, bool highlight, bool bevel)
{
	unsigned int row, col;
	unsigned long pixel;
	float offset = 2;
	unsigned char r, g, b;
	CGColor c;

	if (img == NULL)
		return;

	if (highlight)
		{
		CGColor f = {0};

		f._red = f._green = f._blue = 255;
		for (row = 0; row < NSHeight(rect); row++)
			for (col = 0; col < NSWidth(rect); col++)
				_CGImagePutPixel(img, col, row, &f);
		}

	if (!bevel)
		return;

	for (row = 0; row < NSHeight(rect); row++)
		{
		if (row == 1)
			{
			row = NSHeight(rect) - 2;
			offset = .5;
			}
		else if (row == NSHeight(rect) -1)
			offset = .1;

		for (col = 0; col < NSWidth(rect); col++)
			{
			if (col == 0)
				{
				CGColor f = {0};

				_CGImageGetPixel(img, col, row, &f);
				r = f._red;						// pixel elements to 8 bits
				g = f._green;
				b = f._blue;					// mix background per alpha
				if (r < 50) r = 50;
				if (g < 50) g = 50;
				if (b < 50) b = 50;
				c._red   = (r * offset > 255) ? 255 : r * offset;
				c._green = (g * offset > 255) ? 255 : g * offset;
				c._blue  = (b * offset > 255) ? 255 : b * offset;
				}
			_CGImagePutPixel(img, col, row, &c);
		}	}
		
	offset = 2;
	for (col = 0; col < NSWidth(rect); col++)
		{
		row = 0;
		if (col == 1)
			{
			col = NSWidth(rect) - 2;
			offset = .1;
			row = 0;
			}
		for (; row < NSHeight(rect) - 2; row++)
			{
			if (row == 0)
				{
				CGColor f = {0};

				_CGImageGetPixel(img, col, row+1, &f);
				r = f._red;						// pixel elements to 8 bits
				g = f._green;
				b = f._blue;					// mix background per alpha
				if (r < 50) r = 50;
				if (g < 50) g = 50;
				if (b < 50) b = 50;
				c._red	 = (r * offset > 255) ? 255 : r * offset;
				c._green = (g * offset > 255) ? 255 : g * offset;
				c._blue	 = (b * offset > 255) ? 255 : b * offset;
				}
			_CGImagePutPixel(img, col, row, &c);
		}	}
}

/* ****************************************************************************

	_CGImageWritePBM()

	http://netpbm.sourceforge.net/doc/pgm.html

** ***************************************************************************/

static void
_CGImageWriteStreamPBM(CGImage *img, FILE *alpha, FILE *color)
{
	int stride = img->width * img->samplesPerPixel;		// img->bytesPerRow
	int x, y;

	switch (img->samplesPerPixel)
		{
		case 4:
			fprintf(alpha, "P5\n%d %d\n255\n", img->width, img->height);
			fprintf(color, "P6\n%d %d\n255\n", img->width, img->height);

			for (y = 0; y < img->height; y++)
				for (x = 0; x < img->width; x++)
					{
					long location = x * img->samplesPerPixel + y * stride;
					int a = img->idata[location++];
					int r = img->idata[location++];
					int g = img->idata[location++];
					int b = img->idata[location];

					fputc(a, alpha);
					fputc(r, color);
					fputc(g, color);
					fputc(b, color);
					}
			break;

		case 3:
			fprintf(color, "P6\n%d %d\n255\n", img->width, img->height);

			for (y = 0; y < img->height; y++)
				for (x = 0; x < img->width; x++)
					{
					long location = x * img->samplesPerPixel + y * stride;
					int r = img->idata[location++];
					int g = img->idata[location++];
					int b = img->idata[location];

					fputc(r, color);
					fputc(g, color);
					fputc(b, color);
					}
			break;

		case 2:
			fprintf(alpha, "P5\n%d %d\n255\n", img->width, img->height);
			fprintf(color, "P5\n%d %d\n255\n", img->width, img->height);

			for (y = 0; y < img->height; y++)
				for (x = 0; x < img->width; x++)
					{
					long location = x * img->samplesPerPixel + y * stride;
					int a = img->idata[location++];
					int g = img->idata[location];

					fputc(a, alpha);
					fputc(g, color);
					}
			break;

		case 1:
			fprintf(alpha, "P5\n%d %d\n255\n", img->width, img->height);

			for (y = 0; y < img->height; y++)
				for (x = 0; x < img->width; x++)
					{
					long location = x * img->samplesPerPixel + y * stride;
					int g = img->idata[location];

					fputc(g, alpha);
					}
			break;
		}
}

void
_CGImageWritePNM(CGImageRef img, const char *name, int frameCounter)
{
	FILE *alpha = NULL;
	FILE *color = NULL;
	NSString *wp;

	wp = [NSString stringWithFormat:@"%s-%03d-alpha.pgm", name, frameCounter];

	if (!(alpha = fopen([wp cString], "wb")))
		NSLog(@"_CGImageWritePGM: failed to open PGM file stream %@", wp);
	else if (img->samplesPerPixel > 1)
		{
		NSString *fmt = (img->samplesPerPixel > 2) ? @"%s-%03d-color.ppm"
												   : @"%s-%03d-color.pgm";
		wp = [NSString stringWithFormat:fmt, name, frameCounter];

		if (!(color = fopen([wp cString], "wb")))
			NSLog(@"_CGImageWritePGM: failed to open PPM file stream %@", wp);
		}

	if (alpha && (color || !(img->samplesPerPixel > 1)))
		{
		_CGImageWriteStreamPBM((CGImage *)img, alpha, color);

		if (color)
			fclose(color);
		fclose(alpha);
		}
}

CGImageRef
_CGImageReadPNM(CFDataRef d)
{
	const unsigned char *p = [(NSData *)d bytes];
	NSUInteger l = [(NSData *)d length];
	CFStringRef type = NULL;
	CGImageRef img = NULL;

	if (_CGImageCanInitWith( d, (const unsigned char []){'P','5'}, 2))
		type = (CFStringRef) @"pgm";
	else if (_CGImageCanInitWith( d, (const unsigned char []){'P','6'}, 2))
		type = (CFStringRef) @"ppm";

	if (type && l > 9)
		{
		const unsigned char *e = p + l;
		unsigned int maxv;
		unsigned int xinc;
		int i, x, y, w, h;

		p += 2;
		for (; p < e && *p == ' ' || *p == '\n' || *p == '\t' || *p == '\r'; p++);
		w = (p < e) ? atoi(p) : 0;
		for (; p < e && *p != ' ' && *p != '\n' && *p != '\t' && *p != '\r'; p++);
		for (; p < e && *p == ' ' || *p == '\n' || *p == '\t' || *p == '\r'; p++);
		h = (p < e) ? atoi(p) : 0;
		NSLog(@"PNM with size %d %d", w, h);
		for (; p < e && *p != ' ' && *p != '\n' && *p != '\t' && *p != '\r'; p++);
		for (; p < e && *p == ' ' || *p == '\n' || *p == '\t' || *p == '\r'; p++);
		maxv = (p < e) ? atoi(p) : 0;
		for (; p < e && *p != ' ' && *p != '\n' && *p != '\t' && *p != '\r'; p++);

		if (maxv == 0 || maxv >= 65536 || w == 0 || h == 0)
			type = NULL;
		else if (*p != ' ' && *p != '\n' && *p != '\t' && *p != '\r')
			type = NULL;
		else
			{
			p++;

			if ((xinc = (maxv < 256) ? 1 : 2) > 1)
				{
				NSLog(@"ERROR: multi-byte PNM file format not supported.");
				type = NULL;				// (short) == (*p << 8) | *(p+1)
			}	}

		if ((NSString *)type == @"pgm" && p + (w * h) <= e)
			{
			img = CGImageCreate( w, h, 8, 8, 0, NULL, 0, NULL, NULL, 0, 0);

			for (y = 0; y < img->height; y++)
				{
				long location = y * img->bytesPerRow;

				for (x = 0; x < img->width; x++, p += xinc)
					img->idata[location++] = *p;
				}
			}
		else if ((NSString *)type == @"ppm" && p + (w * h * 3) <= e)
			{
			img = CGImageCreate( w, h, 8, 24, 0, NULL, 0, NULL, NULL, 0, 0);

			for (y = 0; y < img->height; y++)
				{
				long location = y * img->bytesPerRow;

				for (x = 0; x < img->width; x++, location += 3)
					for (i = 0; i < 3; i++, p += xinc)
						img->idata[location + i] = *p;
				}
			}
		else
			NSLog(@"ERROR: parsing PNM file.");
		}
	else
		NSLog(@"ERROR: invalid PNM file (bad header magic).");

	return img;
}

CGImageRef
_CGImageResize(CGImageRef img, size_t width, size_t height)
{
	int size = width * height * ((CGImage *)img)->samplesPerPixel + 8;

    assert(width > 0 && height > 0);

    img = CFAllocatorReallocate (NULL, (void *)img, sizeof(CGImage) + size, 0);

    if (img)
		{
		((CGImage *)img)->cf_pointer = (void *)&__CGImageClass;
		((CGImage *)img)->width = width;
		((CGImage *)img)->height = height;
		((CGImage *)img)->size = size;
		((CGImage *)img)->bytesPerRow = width * img->bitsPerPixel / 8;
		((CGImage *)img)->idata = (void *)img + sizeof(CGImage);
		memset (img->idata, 0xff, size);
		}

    return img;
}

static inline void
getBGRPixel(CGImage *img, int px, int py, unsigned char pixel[3])
{
	long location = px + py;
	int i = 3;

	if (location >= img->size)
		_CGOutOfBoundsAccess(__FUNCTION__, NULL, px, py, location);
	else
		while (--i >= 0)							// convert RGB/A to BGR
			pixel[i] = *(img->idata + location++);
}

CGImageRef
CGImageCreateWithImageInRect(CGImageRef image, CGRect r)
{
	CGImage *img = (CGImage *)image;		// FIX ME image must be RGB or RGBA
	CGImageRef new;
	int x, y, j;
	int w = r.size.width;
	int h = r.size.height;
	int iy = (int)r.origin.y;
	int ix = (int)r.origin.x * img->samplesPerPixel;
	int xinc = img->samplesPerPixel;
	CGColorSpaceRef s = img->colorspace;

    if (!(new = CGImageCreate( w, h, 8, 24, 0, s, 0, NULL, NULL, 0, 0)))
		return NULL;

	for (j = iy, y = 0; y < new->height; j++, y++)
		{
		int yo = (y * new->bytesPerRow);
		int py = j * img->bytesPerRow;
		int xo, px;

		for (px = ix, x = 0, xo = 0; x < new->width; x++, xo += 3, px += xinc)
			getBGRPixel(img, px, py, new->idata + yo + xo);
		}

    return new;
}

bool
_CGImageCanInitWith( CFDataRef d, const u8 *sig, NSUInteger slen)
{
	const unsigned char *p = [(NSData *)d bytes];
	NSUInteger len = [(NSData *)d length];
	int i = 0;

	if (len > slen)
		for (i = 0; i < slen; i++)
			if (*(p+i) != *(sig+i))
				break;

	return (i == slen) ? YES : NO;
}
