/*
   CGBlend.m

   Porter-Duff compositing modes and pixel ops

   Copyright (C) 2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	Jan 2020

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSString.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSGraphics.h>
#include <AppKit/NSColor.h>


#define CTX			((CGContext *)cx)
											// Saturation arithmetic [0-255]
#define SMUL(a,b)	(((a) * ((b) + ((b) >> 7))) >> 8)
#define SRND(b)		((b) + ((b) >> 7))


static unsigned short __gtl[256];					// gamma to linear table
static unsigned char __ltg[65536];					// linear to gamma table

#ifdef FB_GRAPHICS
static const float GAMMA = 1.0;
#else
static const float GAMMA = 1.2;
#endif


static void
sover_t(unsigned char *src, unsigned char cov, int len, unsigned char *dst)
{
	unsigned char r = *src++;				// color encoded in first 3 bytes
	unsigned char g = *src++;
	unsigned char b = *src++;

	while (len--)
		{
		unsigned char alpha = *src++;
		unsigned char ialpha = 255 - alpha;

		if (alpha > 0)
			{
			dst[0] = ((dst[0] * ialpha) + (r * alpha)) >> 8;
			dst[1] = ((dst[1] * ialpha) + (g * alpha)) >> 8;
			dst[2] = ((dst[2] * ialpha) + (b * alpha)) >> 8;
			dst[3] = alpha;
			}
		dst += 4;
		}
}

static void
sover_c(unsigned char *src, _CGInk *ink, int len, unsigned char *dst)
{
	while (len--)
		{									// color encoded in first 4 bytes
		unsigned char alpha = dst[3];

		if (dst[3] == 255 && src[3] == 255)
			{									// full cov wtih opaque paint
			dst[0] = src[0];
			dst[1] = src[1];
			dst[2] = src[2];
			}
		else
			{
			unsigned char ialpha = 255 - alpha;
			unsigned char r = dst[0];
			unsigned char g = dst[1];
			unsigned char b = dst[2];

			dst[0] = ((r * ialpha) + (src[0] * alpha)) >> 8;
			dst[1] = ((g * ialpha) + (src[1] * alpha)) >> 8;
			dst[2] = ((b * ialpha) + (src[2] * alpha)) >> 8;
//			dst[3] = alpha;
			}

		dst += 4;
		}
}

static void
copy_c(unsigned char *src, _CGInk *ink, int len, unsigned char *dst)
{
	if (src[3] > 0)
		while (len--)						// color encoded in first 4 bytes
			{
			dst[0] = src[0];
			dst[1] = src[1];
			dst[2] = src[2];
			dst[3] = src[3];
			dst += 4;
			}
}

static void
blend_4a4(unsigned char *src, _CGInk *ink, int len, unsigned char *dst)
{
	unsigned char cov = ink->cov;

	while (len--)
		{
		if (dst[3] > 0 && src[3] > 0)									// mask
			{
//			unsigned char alpha = 255;
			unsigned char alpha = ((dst[3] * src[3] >> 8) * cov) >> 8;  // mask
			unsigned char ialpha = 255 - alpha;
			unsigned char r = dst[0];
			unsigned char g = dst[1];
			unsigned char b = dst[2];

			dst[0] = ((r * ialpha) + (src[2] * alpha)) >> 8;
			dst[1] = ((g * ialpha) + (src[1] * alpha)) >> 8;
			dst[2] = ((b * ialpha) + (src[0] * alpha)) >> 8;
			dst[3] = alpha;
			}
		dst += 4;
		src += 4;
		}
}

static void
blend_4a4_bgr(unsigned char *src, _CGInk *ink, int len, unsigned char *dst)
{
	unsigned char cov = ink->cov;

	while (len--)
		{
		if (dst[3] > 0 && src[3] > 0)									// mask
			{
//			unsigned char alpha = 255;
			unsigned char alpha = ((dst[3] * src[3] >> 8) * cov) >> 8;  // mask
			unsigned char ialpha = 255 - alpha;
			unsigned char r = dst[0];
			unsigned char g = dst[1];
			unsigned char b = dst[2];

			dst[0] = ((r * ialpha) + (src[0] * alpha)) >> 8;
			dst[1] = ((g * ialpha) + (src[1] * alpha)) >> 8;
			dst[2] = ((b * ialpha) + (src[2] * alpha)) >> 8;
//			dst[0] = __ltg[((__gtl[r] >> 8) * ialpha) + (src[0] * alpha)];
//			dst[1] = __ltg[((__gtl[g] >> 8) * ialpha) + (src[1] * alpha)];
//			dst[2] = __ltg[((__gtl[b] >> 8) * ialpha) + (src[2] * alpha)];
			dst[3] = alpha;
			}
		dst += 4;
		src += 4;
		}
}

static void
copy_4a4_bgr(unsigned char *src, _CGInk *ink, int len, unsigned char *dst)
{
	while (len--)
		{
		*dst++ = *src++;
		*dst++ = *src++;
		*dst++ = *src++;
		*dst++ = *src++;
		}
}

static void
copy_4a4_rgb(unsigned char *src, _CGInk *ink, int len, unsigned char *dst)
{
	while (len--)
		{
		*dst++ = src[3];
		*dst++ = src[2];
		*dst++ = src[1];
		*dst++ = src[0];
		src += 4;
		}
}

static void
copy_4a4(unsigned char *src, _CGInk *ink, int len, unsigned char *dst)
{
	unsigned char cov = ink->cov;

	while (len--)		// FIX ME actually SourceAtop and similar to blend_4a4
		{
		if (src[3] > 0)										// menu
			{
			unsigned char alpha = (src[3] * cov >> 8);		// menu
			unsigned char ialpha = 255 - alpha;
			unsigned char r = dst[0];
			unsigned char g = dst[1];
			unsigned char b = dst[2];

			dst[0] = ((r * ialpha) + (src[2] * alpha)) >> 8;
			dst[1] = ((g * ialpha) + (src[1] * alpha)) >> 8;
			dst[2] = ((b * ialpha) + (src[0] * alpha)) >> 8;
			dst[3] = alpha;
			}
		dst += 4;
		src += 4;
		}
}

static void
copy_3a4(unsigned char *src, _CGInk *ink, int len, unsigned char *dst)
{
	unsigned char cov = ink->cov;

	while (len--)
		{
		dst[0] = (src[2] * cov) >> 8;
		dst[1] = (src[1] * cov) >> 8;
		dst[2] = (src[0] * cov) >> 8;
		dst[3] = 255;
		dst += 4;
		src += ink->length;
		}
}

static void
copy_1a4(unsigned char *src, _CGInk *ink, int len, unsigned char *dst)
{
	unsigned char cov = ink->cov;

	while (len--)
		{
		dst[0] = (src[0] * 255) >> 8;
		dst[1] = (src[0] * 255) >> 8;
		dst[2] = (src[0] * 255) >> 8;
		dst[3] = 255;
		dst += 4;
		src += 1;
		}
}

static void
clear_p(unsigned char *src, _CGInk *ink, int len, unsigned char *dst)
{
	unsigned char back[4] = {dst[4], dst[5], dst[6], dst[7]};
	unsigned char cov = src[len];

	while (len--)
		{
		cov += *src;
		*src++ = 0;

		dst[3] = SMUL(back[3], cov);
		dst[2] = back[2];
		dst[1] = back[1];
		dst[0] = back[0];
		dst += 4;
		}
}

static void
copy_p(unsigned char *src, _CGInk *ink, int len, unsigned char *dst)
{
	unsigned char back[4] = {dst[4], dst[5], dst[6], dst[7]};
	unsigned char cov = src[len];
	unsigned char *rgba = ink->rgba;
	unsigned long offset = 0;

	while (len--)
		{
		unsigned int q = (offset % ink->length) << 2;		// * 4
		unsigned short r = *(rgba + q);
		unsigned short g = *(rgba + q + 1);
		unsigned short b = *(rgba + q + 2);
		unsigned short alpha = *(rgba + q + 3);

		cov += *src;
		*src++ = 0;

		if (cov < 255)
			{
			unsigned char ca = SMUL(cov, alpha);

			dst[3] = ca;
			dst[2] = SMUL((short)r - back[2], ca) + back[2];
			dst[1] = SMUL((short)g - back[1], ca) + back[1];
			dst[0] = SMUL((short)b - back[0], ca) + back[0];
			}
		else
			{
			dst[3] = alpha;
			dst[2] = r;
			dst[1] = g;
			dst[0] = b;
			}

		dst += 4;
		offset++;
		}
}

static void
plusd_p(unsigned char *src, _CGInk *ink, int len, unsigned char *dst)
{
	unsigned char cov = src[len];
	unsigned char *rgba = ink->rgba;
	unsigned long offset = 0;

	while (len--)
		{
		cov += *src;
		*src++ = 0;

		if (cov > 0)
			{
			unsigned int q = (offset % ink->length) << 2;		// * 4
			unsigned short r = *(rgba + q);
			unsigned short g = *(rgba + q + 1);
			unsigned short b = *(rgba + q + 2);
			unsigned short alpha = *(rgba + q + 3);
			unsigned char ca = SMUL(cov, alpha);
			unsigned char da = 255 - SMUL(ca, dst[3]);

			dst[3] = ca;
			dst[2] = SMUL((short)r, da) + SMUL((short)dst[2], 255 - ca);
			dst[1] = SMUL((short)g, da) + SMUL((short)dst[1], 255 - ca);
			dst[0] = SMUL((short)b, da) + SMUL((short)dst[0], 255 - ca);
			}

		dst += 4;
		offset++;
		}
}

static void
din_p(unsigned char *src, _CGInk *ink, int len, unsigned char *dst)
{
	unsigned char back[4] = {dst[4], dst[5], dst[6], dst[7]};
	unsigned char cov = src[len];
	unsigned char *rgba = ink->rgba;
	unsigned long offset = 0;

	while (len--)				// show dest pixels that cover source pixels
		{
		cov += *src;
		*src++ = 0;

		if (dst[3] > 0 && cov > 0)
			{
			unsigned int q = (offset % ink->length) << 2;		// * 4
			unsigned short r = *(rgba + q);
			unsigned short g = *(rgba + q + 1);
			unsigned short b = *(rgba + q + 2);
			unsigned short alpha = *(rgba + q + 3);
			unsigned char ca = SMUL(cov, alpha);

			dst[3] = SMUL((short)dst[3], ca);
			dst[2] = SMUL((short)dst[2], ca);
			dst[1] = SMUL((short)dst[1], ca);
			dst[0] = SMUL((short)dst[0], ca);
			}
		else
			{
			dst[2] = back[2];
			dst[1] = back[1];
			dst[0] = back[0];
			}

		dst += 4;
		offset++;
		}
}

static void
dout_p(unsigned char *src, _CGInk *ink, int len, unsigned char *dst)
{
	unsigned char back[4] = {dst[4], dst[5], dst[6], dst[7]};
	unsigned char cov = src[len];
	unsigned char *rgba = ink->rgba;
	unsigned long offset = 0;

	while (len--)				// show dest pixels not covered by source pixels
		{
		cov += *src;
		*src++ = 0;

		if (cov > 0)
			{
			dst[3] = back[3];
			dst[2] = back[2];
			dst[1] = back[1];
			dst[0] = back[0];
			}

		dst += 4;
		offset++;
		}
}

static void
xor_p(unsigned char *src, _CGInk *ink, int len, unsigned char *dst)
{
	unsigned char back[4] = {dst[4], dst[5], dst[6], dst[7]};
	unsigned char cov = src[len];
	unsigned char *rgba = ink->rgba;
	unsigned long offset = 0;

	while (len--)			// erase source and destination pixels that overlap
		{
		cov += *src;
		*src++ = 0;

		if (cov > 0)
			{
			if (dst[3] > 0)
				{
				dst[2] = back[2];
				dst[1] = back[1];
				dst[0] = back[0];
				}
			else
				{
				unsigned int q = (offset % ink->length) << 2;		// * 4
				unsigned short r = *(rgba + q);
				unsigned short g = *(rgba + q + 1);
				unsigned short b = *(rgba + q + 2);
				unsigned short alpha = *(rgba + q + 3);
				unsigned char ca = SMUL(cov, alpha);

				dst[3] = ca;
				dst[2] = SMUL((short)r, ca);
				dst[1] = SMUL((short)g, ca);
				dst[0] = SMUL((short)b, ca);
			}	}

		dst += 4;
		offset++;
		}
}

static void
sin_p(unsigned char *src, _CGInk *ink, int len, unsigned char *dst)
{
	unsigned char back[4] = {dst[4], dst[5], dst[6], dst[7]};
	unsigned char cov = src[len];
	unsigned char *rgba = ink->rgba;
	unsigned long offset = 0;

	while (len--)			// draw source pixels that cover destination pixels,
		{					// erase remaining source and destination pixels.
		cov += *src;
		*src++ = 0;

		if (cov > 0 && dst[3] > 0)
			{
			unsigned int q = (offset % ink->length) << 2;		// * 4
			unsigned short r = *(rgba + q);
			unsigned short g = *(rgba + q + 1);
			unsigned short b = *(rgba + q + 2);
			unsigned short alpha = *(rgba + q + 3);
			unsigned char ca = SMUL(cov, alpha);

			dst[3] = ca;
			dst[2] = SMUL((short)r, ca);
			dst[1] = SMUL((short)g, ca);
			dst[0] = SMUL((short)b, ca);
			}
		else
			{
			dst[2] = back[2];
			dst[1] = back[1];
			dst[0] = back[0];
			}

		dst += 4;
		offset++;
		}
}

static void
sout_p(unsigned char *src, _CGInk *ink, int len, unsigned char *dst)
{
	unsigned char back[4] = {dst[4], dst[5], dst[6], dst[7]};
	unsigned char cov = src[len];
	unsigned char *rgba = ink->rgba;
	unsigned long offset = 0;

	while (len--)			// draw source pixels that do not cover dst pixels
		{
		cov += *src;
		*src++ = 0;

		if (dst[3] == 0 && cov > 0)
			{
			unsigned int q = (offset % ink->length) << 2;		// * 4
			unsigned short r = *(rgba + q);
			unsigned short g = *(rgba + q + 1);
			unsigned short b = *(rgba + q + 2);
			unsigned short alpha = *(rgba + q + 3);
			unsigned char ca = SMUL(cov, alpha);

			dst[3] = ca;
			dst[2] = SMUL((short)r, ca);
			dst[1] = SMUL((short)g, ca);
			dst[0] = SMUL((short)b, ca);
			}
		else
			{
			dst[2] = back[2];
			dst[1] = back[1];
			dst[0] = back[0];
			}

		dst += 4;
		offset++;
		}
}

static void
datop_p(unsigned char *src, _CGInk *ink, int len, unsigned char *dst)
{
	unsigned char back[4] = {dst[4], dst[5], dst[6], dst[7]};
	unsigned char cov = src[len];
	unsigned char *rgba = ink->rgba;
	unsigned long offset = 0;

	while (len--)				// show dest pixels that cover source pixels
		{
		cov += *src;
		*src++ = 0;

		if (cov == 0)
			{
			dst[2] = SMUL((short)back[2] - dst[2], 255) + dst[2];
			dst[1] = SMUL((short)back[1] - dst[1], 255) + dst[1];
			dst[0] = SMUL((short)back[0] - dst[0], 255) + dst[0];
			}
		else if (dst[3] < 255)
			{
			unsigned int q = (offset % ink->length) << 2;		// * 4
			unsigned short r = *(rgba + q);
			unsigned short g = *(rgba + q + 1);
			unsigned short b = *(rgba + q + 2);
			unsigned short alpha = *(rgba + q + 3);
			unsigned char ca = SMUL(cov, alpha);

			dst[3] = ca;
			dst[2] = SMUL((short)r - dst[2], ca) + dst[2];
			dst[1] = SMUL((short)g - dst[1], ca) + dst[1];
			dst[0] = SMUL((short)b - dst[0], ca) + dst[0];
			}

		dst += 4;
		offset++;
		}
}

static void
satop_p(unsigned char *src, _CGInk *ink, int len, unsigned char *dst)
{
	unsigned char cov = src[len];
	unsigned char *rgba = ink->rgba;
	unsigned long offset = 0;

	while (len--)				// draw source pixels that cover dest pixels
		{
		cov += *src;
		*src++ = 0;

		if (cov > 0 && dst[3] > 0)
			{
			unsigned int q = (offset % ink->length) << 2;		// * 4
			unsigned short r = *(rgba + q);
			unsigned short g = *(rgba + q + 1);
			unsigned short b = *(rgba + q + 2);
			unsigned short alpha = *(rgba + q + 3);
			unsigned char ca = SMUL(cov, alpha);
			unsigned char da = dst[3];

			dst[3] = ca;
//			dst[2] = SMUL((short)r, da) + SMUL((short)dst[2], 255 - ca);
//			dst[1] = SMUL((short)g, da) + SMUL((short)dst[1], 255 - ca);
//			dst[0] = SMUL((short)b, da) + SMUL((short)dst[0], 255 - ca);

			dst[2] = SMUL((short)r - dst[2], ca) + dst[2];
			dst[1] = SMUL((short)g - dst[1], ca) + dst[1];
			dst[0] = SMUL((short)b - dst[0], ca) + dst[0];
			}

		dst += 4;
		offset++;
		}
}

static void
dover_p(unsigned char *src, _CGInk *ink, int len, unsigned char *dst)
{
	unsigned char cov = src[len];
	unsigned char *rgba = ink->rgba;
	unsigned long offset = 0;

	while (len--)
		{
		cov += *src;
		*src++ = 0;

		if (cov > 0 && dst[3] < 255)
			{
			unsigned int q = (offset % ink->length) << 2;		// * 4
			unsigned short r = *(rgba + q);
			unsigned short g = *(rgba + q + 1);
			unsigned short b = *(rgba + q + 2);
			unsigned short alpha = *(rgba + q + 3);
			unsigned char ca = SMUL(cov, alpha);

			dst[3] = ca;
			dst[2] = SMUL((short)r - dst[2], ca) + dst[2];
			dst[1] = SMUL((short)g - dst[1], ca) + dst[1];
			dst[0] = SMUL((short)b - dst[0], ca) + dst[0];
			}

		dst += 4;
		offset++;
		}
}

static void
sover_p(unsigned char *src, _CGInk *ink, int len, unsigned char *dst)
{
	unsigned char cov = src[len];
	unsigned char *rgba = ink->rgba;
	unsigned long offset = 0;

	while (len--)
		{
		cov += *src;
		*src++ = 0;

		if (cov > 0)
			{
			unsigned int q = (offset % ink->length) << 2;		// * 4
			unsigned short r = *(rgba + q);
			unsigned short g = *(rgba + q + 1);
			unsigned short b = *(rgba + q + 2);
			unsigned short alpha = *(rgba + q + 3);

			if (cov == 255 && (!ink->mask || dst[3] == 255) && alpha == 255)
				{								// full cov wtih opaque paint
				dst[3] = alpha;
				dst[2] = r;
				dst[1] = g;
				dst[0] = b;
				}
			else
				{
				unsigned char sa = SMUL(cov, alpha);
				unsigned char ca = SMUL(cov, dst[3]);
				unsigned char ialpha = 255 - ca;

				dst[0] = SMUL(ca, b) + SMUL(ialpha, dst[0]);
				dst[1] = SMUL(ca, g) + SMUL(ialpha, dst[1]);
				dst[2] = SMUL(ca, r) + SMUL(ialpha, dst[2]);
				dst[3] = SMUL(ca, sa) + SMUL(ialpha, dst[3]);
				}
			}

		dst += 4;
		offset++;
		}
}

static void
xor_c(unsigned char *src, _CGInk *ink, int len, unsigned char *dst)
{
	while (len--)
		{
		dst[0] = src[0] ^ dst[0];			// r
		dst[1] = src[1] ^ dst[1];			// g
		dst[2] = src[2] ^ dst[2];			// b
		dst[3] = 255;
		dst += 4;
		}
}

static void
nop_0x0(unsigned char *src, _CGInk *ink, int len, unsigned char *dst)
{
	NSLog(@"CGBlendMode: error NOP blend mode invoked");
}

void
CGContextSetBlendMode( CGContextRef cx, CGBlendMode mode)
{
	if (mode > kCGBlendModePlusLighter)
		NSLog(@"CG error: invalid blend mode %d", mode);
	else
		{
		CTX->_gs->blendMode = mode;
		CTX->_gs->pathBlend = sover_p;
		CTX->_gs->textBlend = sover_t;

		switch (mode)
			{
			case kCGBlendModeClear:
				CTX->_gs->pathBlend = clear_p;
				break;
			case kCGBlendModeCopy:
				CTX->_gs->pathBlend = copy_p;
				CTX->_gs->colorBlend = copy_c;
				break;
			case kCGBlendModeNormal:
				CTX->_gs->colorBlend = sover_c;
				break;
			case kCGBlendModeDestinationOver:
				CTX->_gs->pathBlend = dover_p;
				break;
			case kCGBlendModeDestinationAtop:
				CTX->_gs->pathBlend = datop_p;
				break;
			case kCGBlendModeDestinationIn:
				CTX->_gs->pathBlend = din_p;
				break;
			case kCGBlendModeDestinationOut:
				CTX->_gs->pathBlend = dout_p;
				break;
			case kCGBlendModeSourceAtop:
				CTX->_gs->pathBlend = satop_p;
				break;
			case kCGBlendModeSourceIn:
				CTX->_gs->pathBlend = sin_p;
				break;
			case kCGBlendModeSourceOut:
				CTX->_gs->pathBlend = sout_p;
				break;
			case kCGBlendModePlusDarker:
				CTX->_gs->pathBlend = plusd_p;
				break;
			case kCGBlendModeDifference:
				[[NSColor highlightColor] set];
			case kCGBlendModePlusLighter:
			case kCGBlendModeXOR:
				CTX->_gs->colorBlend = xor_c;
				CTX->_gs->pathBlend = xor_p;
				break;
			default:
				CTX->_gs->colorBlend = nop_0x0;
				break;
		}	}
}

void
_CGContextSetImageBlendMode( CGContextRef cx, CGImage *a)
{
	unsigned nc = a->samplesPerPixel;

	switch (CTX->_gs->blendMode)		// FIX ME set src image colorspace ?
		{
		case kCGBlendModeSourceAtop:
			if (nc == 1)
				CTX->_gs->imageBlend = copy_1a4;
			else
				CTX->_gs->imageBlend = (nc == 3) ? copy_3a4 : copy_4a4;
			break;
		case kCGBlendModeCopy:
			if ((a->_f.bitmapInfo & kCGBitmapByteOrderMask) == _kCGBitmapByteOrderBGR)
				CTX->_gs->imageBlend = (nc == 3) ? copy_3a4 : copy_4a4_bgr;
			else
				CTX->_gs->imageBlend = (nc == 3) ? copy_3a4 : copy_4a4_rgb;
			break;
		case kCGBlendModeNormal:
		default:
			if ((a->_f.bitmapInfo & kCGBitmapByteOrderMask) == _kCGBitmapByteOrderBGR)
				CTX->_gs->imageBlend = blend_4a4_bgr;
			else
				CTX->_gs->imageBlend = blend_4a4;
			break;
		}
}

void
_CGContextInitBlendModes(CGContextRef cx)
{
	int i;

	for (i = 0; i < 256; i++)
		__gtl[i] = (unsigned short)(pow(i/255.0, GAMMA) * 65535.0 + 0.5);

	for (i = 0; i < 65536; i++)
		__ltg[i] = (unsigned char)(pow(i/65535.0, 1/GAMMA) * 255.0 + 0.5);
}

void
mov_3x3up(unsigned char *src, int len, unsigned char *dst)
{
	while (len--)
		{
		*dst++ = *src++;
		*dst++ = *src++;
		*dst++ = *src++;
		src++;
		dst++;
		}
}

void
mov_3x3dn(unsigned char *src, int len, unsigned char *dst)
{
	while (len--)
		{
		dst[0] = src[0];
		dst[1] = src[1];
		dst[2] = src[2];
		src -= 4;
		dst -= 4;
		}
}
