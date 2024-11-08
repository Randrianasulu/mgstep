/*
   jpg.m

   Copyright (C) 1999-2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	March 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <AppKit/AppKit.h>

#include <jpeglib.h>


static NSArray *__filesJPG = nil;


struct my_error_mgr {
	struct jpeg_error_mgr pub;		// "public" fields
	jmp_buf setjmp_buffer;			// setjmp for error recovery
};

typedef struct my_error_mgr *my_error_ptr;
									// Expanded data source obj for stdio input
typedef struct {
	struct jpeg_source_mgr pub;		// public fields
	FILE *infile;					// source stream
	JOCTET *buffer;					// start of buffer
	boolean start_of_file;			// have we gotten any data yet?
} my_source_mgr;

typedef my_source_mgr * my_src_ptr;


METHODDEF(void)						// replacement standard error_exit method:
jpg_error_exit (j_common_ptr cinfo)
{		// cinfo->err really points to a my_error_mgr struct, so coerce pointer
	my_error_ptr myerr = (my_error_ptr) cinfo->err;
		// Display message. could postpone this til after return, if we choose
	(*cinfo->err->output_message) (cinfo);

	longjmp(myerr->setjmp_buffer, 1);	// Return control to the setjmp point
}

METHODDEF(boolean)								// Fill input buffer, called 
gs_fill_input_buffer (j_decompress_ptr cinfo)	// whenever buffer is emptied.
{
	my_src_ptr src = (my_src_ptr) cinfo->src;

	src->start_of_file = FALSE;
	
	return TRUE;
}
						// Skip data --- used to skip over a potentially large 
METHODDEF(void)			// amount of uninteresting data such as an APPn marker
gs_skip_input_data (j_decompress_ptr cinfo, long num_bytes)
{
	my_src_ptr src = (my_src_ptr) cinfo->src;
				// Just a dumb implementation for now.  Could use fseek() 
				// except it doesn't work on pipes.  Not clear that being smart 
				// is worth any trouble anyway --- large skips are infrequent.
	if (num_bytes > 0) 
		{
		while (num_bytes > (long) src->pub.bytes_in_buffer) 
			{
			num_bytes -= (long) src->pub.bytes_in_buffer;
			(void) gs_fill_input_buffer(cinfo);
				// note we assume that gs_fill_input_buffer will never return 
				// FALSE, so suspension need not be handled.
			}
		src->pub.next_input_byte += (size_t) num_bytes;
		src->pub.bytes_in_buffer -= (size_t) num_bytes;
		}
}

@interface _NSBitmapImageRepJPEG : NSBitmapImageRep
@end

@implementation _NSBitmapImageRepJPEG 

+ (void) initialize
{
	if (self == [_NSBitmapImageRepJPEG class])
		__filesJPG = [[NSArray arrayWithObjects:@"jpeg", @"jpg", nil] retain];
}

+ (BOOL) canInitWithData:(NSData *)data
{
	unsigned char sig[] = {0xFF,0xD8,0xFF,0xE0,0x00,0x10,0x4A,0x46,0x49,0x46,0x00,0x01};

	return _CGImageCanInitWith((CFDataRef)data, sig, sizeof(sig));
}

+ (NSArray *) imageUnfilteredFileTypes		{ return __filesJPG; }

+ (NSArray *) imageRepsWithData:(NSData *)data
{				// struct containing the JPEG decompression parameters and 
				// pointers to working space (which is allocated as needed by 
				// the JPEG library).
	struct jpeg_decompress_struct cinfo;
				// We use our private extension JPEG error handler.  Note that 
				// this struct must live as long as the main JPEG parameter
				// struct, to avoid dangling-pointer problems.
	struct my_error_mgr jerr;
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:1];
	_NSBitmapImageRepJPEG *imageRep;
	JSAMPROW buffer[1];
											// Config std JPEG error routines,
	cinfo.err = jpeg_std_error(&jerr.pub);	// but override error_exit.
	jerr.pub.error_exit = jpg_error_exit;
										// Establish the setjmp return context 
	if (setjmp(jerr.setjmp_buffer)) 	// for jpg_error_exit to use.
		{		// If we get here, the JPEG code has signaled an error. Need to
				// clean up the JPEG object, close the input file, and return.
		jpeg_destroy_decompress(&cinfo);
		NSLog(@"error while decompressing JPEG");
		NSRunAlertPanel(0, @"error while decompressing JPEG",@"Continue",0,0);
		return nil;
		}

	jpeg_create_decompress(&cinfo);				// init JPEG decompression obj
	jpeg_stdio_src(&cinfo, (FILE *)NULL);		// specify the JPEG data source

	cinfo.src->fill_input_buffer = &gs_fill_input_buffer;
	cinfo.src->skip_input_data = &gs_skip_input_data;
	cinfo.src->next_input_byte = [data bytes];
	cinfo.src->bytes_in_buffer = [data length];

    jpeg_read_header(&cinfo, TRUE);

	if(cinfo.jpeg_color_space == JCS_GRAYSCALE)
		cinfo.out_color_space = JCS_GRAYSCALE;
	else
        cinfo.out_color_space = JCS_RGB;
    cinfo.quantize_colors = FALSE;
    cinfo.do_fancy_upsampling = FALSE;
    cinfo.do_block_smoothing = FALSE;

	jpeg_calc_output_dimensions(&cinfo);
    jpeg_start_decompress(&cinfo);

	imageRep = [[[[self class] alloc] initWithBitmapDataPlanes: NULL
									  pixelsWide: cinfo.image_width
									  pixelsHigh: cinfo.image_height
									  bitsPerSample: 8
									  samplesPerPixel: cinfo.num_components
									  hasAlpha: (cinfo.num_components > 3)
									  isPlanar: NO
									  colorSpaceName: NSDeviceRGBColorSpace
									  bytesPerRow: 0
									  bitsPerPixel: 0] autorelease];
//	imageRep->compression = info->compression;

    buffer[0] = [imageRep bitmapData];

	if(cinfo.jpeg_color_space == JCS_GRAYSCALE)
		{
		while (cinfo.output_scanline < cinfo.output_height)
			{
			jpeg_read_scanlines(&cinfo, buffer, (JDIMENSION)1);
			buffer[0] += cinfo.output_width;
		}	}										// data is in RGB planes
	else											// so mult by row stride
		while (cinfo.output_scanline < cinfo.output_height)
			{
			jpeg_read_scanlines(&cinfo, buffer, (JDIMENSION)1);
			buffer[0] += (cinfo.output_width * 3);
			}

	jpeg_finish_decompress(&cinfo);
	jpeg_destroy_decompress(&cinfo);				// release jpg and it's mem

	[array addObject: imageRep];

	return array;
}

@end /* _NSBitmapImageRepJPEG */
