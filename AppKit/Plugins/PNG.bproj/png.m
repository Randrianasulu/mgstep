/*
   png.m

   Copyright (C) 1999-2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	March 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <libpng16/png.h>

#include <AppKit/AppKit.h>


static NSArray *__filesPNG = nil;


static void
_png_warning(png_structp png_ptr, png_const_charp message)
{
	PNG_CONST char *name = "PNG ERROR";

	if (png_get_error_ptr(png_ptr) != NULL)
		name = png_get_error_ptr(png_ptr);
	NSLog(@"%s: libpng warning: %s\n", name, message);
}

static void
_png_error(png_structp png_ptr, png_const_charp message)
{
	_png_warning(png_ptr, message);

	[NSException raise:NSTIFFException format: @"invalid PNG image"];
}

static void
png_read(png_structp png_ptr, png_bytep data, png_size_t length)
{
	const char **png_data = png_get_io_ptr(png_ptr);

	if (!memcpy((void *)data, *png_data, (size_t)length))
		_png_error(png_ptr, "Read Error");

	(*png_data) += length;
}

@interface _NSBitmapImageRepPNG : NSBitmapImageRep
@end

@implementation _NSBitmapImageRepPNG 

+ (void) initialize
{
	if (self == [_NSBitmapImageRepPNG class])
		__filesPNG = [[NSArray arrayWithObjects: @"png", nil] retain];
}

+ (BOOL) canInitWithData:(NSData *)data
{
	unsigned char sig[] = {0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A};

	return _CGImageCanInitWith( (CFDataRef)data, sig, sizeof(sig) );
}

+ (NSArray *) imageUnfilteredFileTypes		{ return __filesPNG; }

+ (NSArray *) imageRepsWithData:(NSData *)data
{
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:1];
	_NSBitmapImageRepPNG *imageRep = [[[self class] alloc] autorelease];
	png_structp read_ptr;
	png_infop read_info_ptr, end_info_ptr;
	png_uint_32 y, width, height;
	int num_pass, pass;
	int bit_depth, color_type, row_bytes, intent;
	int interlace_type, compression_type, filter_type;
	const char *pin = [data bytes];
	char *buffer;
	BOOL alpha;
	png_color_16p background;
	double screen_gamma = 2.2;			// A good guess for a PC monitors

	read_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING,NULL,NULL,NULL);
	png_set_error_fn(read_ptr, (png_voidp)NULL, _png_error, _png_warning);
	read_info_ptr = png_create_info_struct(read_ptr);
	end_info_ptr = png_create_info_struct(read_ptr);
										// Establish the setjmp return context 
	if (setjmp(png_jmpbuf(read_ptr)))	// for my_error_exit to use.  PNG code
		{								// has signaled an error.  Clean up.
		NSLog(@"error while decompressing PNG");
		png_destroy_read_struct(&read_ptr, &read_info_ptr, &end_info_ptr);
		NSRunAlertPanel(0, @"error while decompressing PNG",@"Continue",0,0);
		return nil;
		}

	png_set_read_fn(read_ptr, (png_voidp)&pin, png_read);
	png_set_read_status_fn(read_ptr, NULL);
	png_read_info(read_ptr, read_info_ptr);

	if (png_get_IHDR(read_ptr, read_info_ptr, &width, &height, &bit_depth,
				&color_type, &interlace_type, &compression_type, &filter_type));

	if (png_get_valid(read_ptr, read_info_ptr, PNG_INFO_tRNS))
		{									// Expand paletted or RGB images
		png_set_tRNS_to_alpha(read_ptr);	// with transparency to full alpha
		alpha = YES;						// channels so the data will be
		}									// available as RGBA quartets.
    else
		alpha = (color_type & PNG_COLOR_MASK_ALPHA);
				// expand palette images to RGB, low-bit-depth grayscale 
				// images to 8 bits, transparency chunks to full alpha channel.
    if (color_type == PNG_COLOR_TYPE_PALETTE
			|| (color_type == PNG_COLOR_TYPE_GRAY && bit_depth < 8))
        png_set_expand(read_ptr);
    if (png_get_valid(read_ptr, read_info_ptr, PNG_INFO_tRNS))
        png_set_expand(read_ptr);
    if (bit_depth == 16)					// strip 16-bit-per-sample
        png_set_strip_16(read_ptr);			// images to 8 bits per sample
    if (color_type == PNG_COLOR_TYPE_GRAY || color_type == PNG_COLOR_TYPE_GRAY_ALPHA)
        png_set_gray_to_rgb(read_ptr);		// convert grayscale to RGB[A]

	if (png_get_sRGB(read_ptr, read_info_ptr, &intent))
		png_set_gamma(read_ptr, screen_gamma, 0.45455);
	else
		{									// Tell libpng to handle gamma
		double image_gamma;					// conversion

		if (png_get_gAMA(read_ptr, read_info_ptr, &image_gamma))
			png_set_gamma(read_ptr, screen_gamma, image_gamma);
		else
			png_set_gamma(read_ptr, screen_gamma, 0.45455);
		}

	num_pass = png_set_interlace_handling(read_ptr);
	png_read_update_info(read_ptr, read_info_ptr);
	row_bytes = png_get_rowbytes(read_ptr, read_info_ptr);

	imageRep = [imageRep initWithBitmapDataPlanes: NULL
						 pixelsWide: width
						 pixelsHigh: height
						 bitsPerSample: png_get_bit_depth(read_ptr, read_info_ptr)
						 samplesPerPixel: (alpha) ? 4 : 3
						 hasAlpha: alpha
						 isPlanar: NO
						 colorSpaceName: NSDeviceRGBColorSpace
						 bytesPerRow: row_bytes
						 bitsPerPixel: 0];		// read_info_ptr->pixel_depth

    buffer = [imageRep bitmapData];

	NS_DURING
		for (pass = 0; pass < num_pass; pass++)
			{
			for (y = 0; y < height; y++)
				{
				png_bytep r_buf[1];

				r_buf[0] = buffer + y * row_bytes;

				png_read_rows(read_ptr, (png_bytepp)r_buf, (png_bytepp)NULL, 1);
			}	}

		png_read_end(read_ptr, end_info_ptr);
		png_destroy_read_struct(&read_ptr, &read_info_ptr, &end_info_ptr);

		[array addObject: imageRep];
	NS_HANDLER
		array = nil;
	NS_ENDHANDLER

	return array;
}

@end /* _NSBitmapImageRepPNG */
