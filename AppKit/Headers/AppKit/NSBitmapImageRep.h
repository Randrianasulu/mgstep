/*
   NSBitmapImageRep.h

   Bitmap image representations

   Copyright (C) 2000 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    June 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSBitmapImageRep
#define _mGSTEP_H_NSBitmapImageRep

#include <AppKit/NSImageRep.h>

@class NSArray;
@class NSData;


typedef enum _NSTIFFCompression {
	NSTIFFCompressionNone	   = 1,
	NSTIFFCompressionCCITTFAX3 = 3,
	NSTIFFCompressionCCITTFAX4 = 4,
	NSTIFFCompressionLZW	   = 5,
	NSTIFFCompressionJPEG	   = 6,
	NSTIFFCompressionNEXT	   = 32766,
	NSTIFFCompressionPackBits  = 32773,
	NSTIFFCompressionOldJPEG   = 32865
} NSTIFFCompression;


@interface NSBitmapImageRep : NSImageRep  <NSCopying>
{
	unsigned int _bytesPerRow;
	unsigned char **_imagePlanes;
	NSData *_imageData;
	CGImageRef _cgImage;

    struct __bitmapRepFlags {
        unsigned int bitsPerPixel:8;	
		unsigned int isPlanar:1;
        unsigned int samplesPerPixel:4;
		unsigned int cached:1;
        unsigned int compression:14;
        unsigned int reserved:4;
    } _brep;
}

+ (id) imageRepWithData:(NSData *)tiffData;

- (id) initWithFocusedViewRect:(NSRect)rect;
- (id) initWithBitmapDataPlanes:(unsigned char **)planes
					 pixelsWide:(int)width
					 pixelsHigh:(int)height
					 bitsPerSample:(int)bps
					 samplesPerPixel:(int)spp
					 hasAlpha:(BOOL)alpha
					 isPlanar:(BOOL)config
					 colorSpaceName:(NSString *)colorSpaceName
					 bytesPerRow:(int)rowBytes
					 bitsPerPixel:(int)pixelBits;

- (id) initWithCGImage:(CGImageRef)image;
- (CGImageRef) CGImage;

- (BOOL) isPlanar;										// Image attributes
- (int) bitsPerPixel;
- (int) samplesPerPixel;
- (int) numberOfPlanes;
- (int) bytesPerPlane;
- (int) bytesPerRow;

- (unsigned char *) bitmapData;							// Access image Data
- (void) getBitmapDataPlanes:(unsigned char **)data;

@end


@interface NSBitmapImageRep  (TIFF)						// TIFF I/O methods

+ (NSArray *) imageRepsWithData:(NSData *)tiffData;

+ (NSData*) TIFFRepresentationOfImageRepsInArray:(NSArray *)anArray;
+ (NSData*) TIFFRepresentationOfImageRepsInArray:(NSArray *)anArray
			usingCompression:(NSTIFFCompression)compressionType
			factor:(float)factor;
+ (void) getTIFFCompressionTypes:(const NSTIFFCompression **)list
						   count:(int *)numTypes;

- (id) initWithData:(NSData *)tiffData;

- (NSData*) TIFFRepresentation;
- (NSData*) TIFFRepresentationUsingCompression:(NSTIFFCompression)compressType
										factor:(float)factor;

- (BOOL) canBeCompressedUsing:(NSTIFFCompression)compression;
- (void) getCompression:(NSTIFFCompression *)cs factor:(float *)factor;
- (void) setCompression:(NSTIFFCompression)cs factor:(float)factor;

@end

#endif /* _mGSTEP_H_NSBitmapImageRep */
