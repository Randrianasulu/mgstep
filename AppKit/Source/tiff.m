/*
   tiff.m

   Lib TIFF image support

   Copyright (C) 1996-2020 Free Software Foundation, Inc.

   Author:  Adam Fedor <fedor@colorado.edu>
   Date: 	Feb 1996
   Author:  Felipe A. Rodriguez <farz@mindspring.com>
   Date: 	March 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSData.h>
#include <Foundation/NSException.h>
#include <Foundation/NSNotification.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSGraphics.h>
#include <AppKit/NSImageRep.h>
#include <AppKit/NSBitmapImageRep.h>
#include <AppKit/NSPasteboard.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSView.h>

#include <sys/types.h>
#include <tiff.h>
#include <tiffio.h>
#include <math.h>


typedef struct {				// Structure to store common
    u_long  imageNumber;		// information about a tiff
    u_long  subfileType;
    u_long  width;
    u_long  height;
    u_short bitsPerSample;		// number of bits per data channel
    u_short samplesPerPixel;	// number of channels per pixel
    u_short planarConfig;		// meshed or separate
    u_short photoInterp;		// photometric interpretation of bitmap data
	NSString *space;
    u_short compression;
    int     numImages;			// number of images in tiff
	u_short factor;				// compression quality
} NSTiffInfo; 

typedef struct {
    u_int size;
    u_short *red;
    u_short *green;
    u_short *blue;
} NSTiffColormap;

typedef struct {
	char *data;
	char **wdata;
	long size;
	long *wsize;
	long position;
	const char *mode;
} chandle_t;



static tsize_t
TiffHandleRead(thandle_t handle, tdata_t buf, tsize_t count)
{
	chandle_t *chand = (chandle_t *)handle;

	DBLog (@"TiffHandleRead\n");
	if (chand->mode == "w" || chand->position >= chand->size)
		return 0;
	if (chand->position + count > chand->size)
		count = chand->size - chand->position;
	memcpy(buf, chand->data + chand->position, count);

	return count;
}

static tsize_t
TiffHandleWrite(thandle_t handle, tdata_t buf, tsize_t count)
{
	chandle_t *chand = (chandle_t *)handle;

	DBLog (@"TiffHandleWrite\n");
	if (chand->mode == "r")
		return 0;
	if (!*chand->wdata)
		{
		*chand->wsize = chand->position + count + 1;
		*chand->wdata = malloc(*chand->wsize);
		}
	if (chand->position + count > *chand->wsize)
		{
		*chand->wsize = chand->position + count + 1;
		*chand->wdata = realloc(*chand->wdata, *chand->wsize);
		if (*chand->wdata == NULL)
			return 0;
		}
	memcpy(*chand->wdata + chand->position, buf, count);
	chand->position += count;

	return count;
}

static toff_t
TiffHandleSeek(thandle_t handle, toff_t offset, int mode)
{
	chandle_t *chand = (chandle_t *)handle;

	DBLog (@"TiffHandleSeek\n");
	switch(mode)
		{
		case SEEK_SET: chand->position = offset;  break;
		case SEEK_CUR: chand->position += offset; break;
		case SEEK_END:
			if (offset > 0 && chand->mode == "r")
				return 0;
			chand->position += offset;
			break;
		}

	return chand->position;
}

static int
TiffHandleClose(thandle_t handle)
{
	DBLog (@"TiffHandleClose\n");
	free((chandle_t *)handle);

	return 0;
}

static toff_t
TiffHandleSize(thandle_t handle)	{ return ((chandle_t *)handle)->size; }

static void
TiffHandleUnmap(thandle_t handle, tdata_t data, toff_t size)			{}

static int
TiffHandleMap(thandle_t handle, tdata_t *data, toff_t *size)
{
	chandle_t *chand = (chandle_t *)handle;

	DBLog (@"TiffHandleMap\n");
	*data = chand->data;
	*size = chand->size;

	return 1;
}

static TIFF *
_OpenTiff(char *data, long size, const char *mode, char **wdata, long *wsize)
{
	chandle_t *handle;

	DBLog (@"OpenTiff\n");
	if (!(handle = malloc(sizeof(chandle_t))))
		return NULL;

	handle->data = data;
	handle->size = size;
	handle->position = 0;
	if ((handle->mode = mode) == "w")
		{
		handle->wdata = wdata;
		handle->wsize = wsize;
		}										// Open lib tiff for reading or
												// writing to a stream
	return TIFFClientOpen( "NSImageRep",
							mode,
							(thandle_t)handle,
							TiffHandleRead,
							TiffHandleWrite,
							TiffHandleSeek,
							TiffHandleClose,
							TiffHandleSize,
							TiffHandleMap,
							TiffHandleUnmap);
}

static NSTiffInfo *
_GetTiffInfo(int imageNumber, TIFF *tif)		// Read tif info 
{
	NSTiffInfo *info;							// Note currently we don't
												// determine numImages.
	if (imageNumber >= 0 && !TIFFSetDirectory(tif, imageNumber)) 
		return NULL;
	if (!(info = calloc(1, sizeof(NSTiffInfo))))
		return NULL;
	if (imageNumber >= 0)
		info->imageNumber = imageNumber;
	
	TIFFGetField(tif, TIFFTAG_IMAGEWIDTH,  &info->width);
	TIFFGetField(tif, TIFFTAG_IMAGELENGTH, &info->height);
	TIFFGetField(tif, TIFFTAG_COMPRESSION, &info->compression);
	TIFFGetField(tif, TIFFTAG_SUBFILETYPE, &info->subfileType);
											// If missing use TIFF defaults
	TIFFGetFieldDefaulted(tif, TIFFTAG_BITSPERSAMPLE, &info->bitsPerSample);
	TIFFGetFieldDefaulted(tif, TIFFTAG_SAMPLESPERPIXEL,&info->samplesPerPixel);
	TIFFGetFieldDefaulted(tif, TIFFTAG_PLANARCONFIG, &info->planarConfig);

	if (!TIFFGetField(tif, TIFFTAG_PHOTOMETRIC, &info->photoInterp)) 
		{									// If TIFFTAG_PHOTOMETRIC is not 
		switch (info->samplesPerPixel) 		// present then assign a reasonable 
			{								// default. TIFF 5.0 spec doesn't 
			case 1:							// give a default.
				info->photoInterp = PHOTOMETRIC_MINISBLACK; break;
			case 3: 
			case 4:
				info->photoInterp = PHOTOMETRIC_RGB; break;
			default:
				TIFFError(TIFFFileName(tif),
						  "Missing needed \"PhotometricInterpretation\" tag");
				return (0);
			}
		TIFFError(TIFFFileName(tif),
				"No \"PhotometricInterpretation\" tag, assuming %s\n",
				info->photoInterp == PHOTOMETRIC_RGB ? "RGB" : "min-is-black");
		}
									// 8-bit RGB will be converted to 24-bit by 
	switch(info->photoInterp) 		// the tiff routines, so account for this.
		{
		case PHOTOMETRIC_MINISBLACK: 
			info->space = NSDeviceWhiteColorSpace; break;
		case PHOTOMETRIC_MINISWHITE: 
			info->space = NSDeviceBlackColorSpace; break;
		case PHOTOMETRIC_RGB: 		 
			info->space = NSDeviceRGBColorSpace;   break;
		case PHOTOMETRIC_PALETTE: 
			info->space = NSDeviceRGBColorSpace; 
			info->samplesPerPixel = 3;
		default:
			break;
		}

	return info;
}

static NSTiffColormap *						// Gets the colormap for the image
_GetTiffColormap(TIFF *tif)					// if there is one. Returns a
{											// NSTiffColormap if one was found.
	int i;
	NSTiffInfo *info = _GetTiffInfo(-1, tif);
	int colorMapSize = 8;					// Re-read the tiff info.  Pass -1
	NSTiffColormap *map;					// as the image number which means
											// just read the current image.
	if (info->photoInterp != PHOTOMETRIC_PALETTE)
		return NULL;
    if (!(map = malloc(sizeof(NSTiffColormap))))
		return NULL;

	map->size = 1 << info->bitsPerSample;

	if (!TIFFGetField(tif, TIFFTAG_COLORMAP, &map->red, &map->green, &map->blue))
		{
		TIFFError(TIFFFileName(tif), "Missing required \"Colormap\" tag");
		free(map);

		return NULL;
		}

	for (i = 0; i < map->size; i++)
		if((map->red[i] > 255) ||(map->green[i] > 255) || (map->blue[i] > 255))
			{
			colorMapSize = 16;				// Many programs get TIFF colormaps 
			break;							// wrong.  They use 8-bit colormaps 
			}								// instead of 16-bit colormaps.  
											// This is a heuristic to detect 
	if (colorMapSize == 8)					// and correct this.
		{
		TIFFWarning(TIFFFileName(tif), "Assuming 8-bit colormap");
		for (i = 0; i < map->size; i++)
			{
			map->red[i] = ((map->red[i] * 255) / ((1L << 16) - 1));
			map->green[i] = ((map->green[i] * 255) / ((1L << 16) - 1));
			map->blue[i] = ((map->blue[i] * 255) / ((1L << 16) - 1));
		}	}

	free(info);

	return map;
}

static int
_ReadTiff(TIFF *tif, NSTiffInfo *info, char *data)
{
	u_char *outp = (u_char *)data;
	u_char *buf;
	int row, col, sl_size;	// Read a tiff into a data array. The data array
	int i;					// is assumed to have been allocated to the correct
							// size.  Note that palette images are implicitly
	if (data == NULL)		// coverted to 24-bit contig direct color images.
		return -1;			// Data array should be large enough to hold this.

    if (!(buf = (u_char *) malloc((sl_size = TIFFScanlineSize(tif)))))
		return -1;

	switch (info->photoInterp)
		{
		case PHOTOMETRIC_MINISBLACK:
		case PHOTOMETRIC_MINISWHITE:
			if (info->planarConfig == PLANARCONFIG_CONTIG)
				{
				for (row = 0; row < info->height; row++)
					{
					if (TIFFReadScanline(tif, outp, row, 0) < 0)
						{
						NSLog(@"tiff: line %d bad data\n", row);
						return 1;
						}
					outp += sl_size;
				}	}
			else
				{
				for (i = 0; i < info->samplesPerPixel; i++)
					{
					for (row = 0; row < info->height; row++)
						{
						if (TIFFReadScanline(tif, buf, row, i) < 0)
							{
							NSLog(@"tiff: line %d bad data\n", row);
							return 1;
							}

						for (col = 0; col < sl_size; col++)
							{
							*outp = *(buf + col);
							outp += info->samplesPerPixel;
						}	}

					outp = (u_char *)data + i + 1;
				}	}
			break;

		case PHOTOMETRIC_PALETTE:
			{
			NSTiffColormap *map;
			u_char *inp;

			if (!(map = _GetTiffColormap(tif)))
				return -1;

			for (row = 0; row < info->height; ++row)
				{
				if (TIFFReadScanline(tif, buf, row, 0) < 0)
					{
					NSLog(@"tiff: line %d bad data\n", row);
					return 1;
					}
				for (inp = buf, col = 0; col < info->width; col++)
					{
					*outp++ = map->red[*inp] / 256;
					*outp++ = map->green[*inp] / 256;
					*outp++ = map->blue[*inp] / 256;
					inp++;
				}	}

			free(map->red);
			free(map->green);
			free(map->blue);
			free(map);
			}
			break;

		case PHOTOMETRIC_RGB:
			if (info->planarConfig == PLANARCONFIG_CONTIG)
				{
				for (row = 0; row < info->height; row++)
					{
					if (TIFFReadScanline(tif, outp, row, 0) < 0)
						{
						NSLog(@"tiff: line %d bad data\n", row);
						return 1;
						}
					outp += sl_size;
				}	}
			else
				{
				for (i = 0; i < info->samplesPerPixel; i++)
					{
					for (row = 0; row < info->height; row++)
						{
						if (TIFFReadScanline(tif, buf, row, i) < 0)
							{
							NSLog(@"tiff: line %d bad data\n", row);
							return 1;
							}

						for (col = 0; col < sl_size; col++)
							{
							*outp = *(buf + col);
							outp += info->samplesPerPixel;
						}	}

					outp = (u_char *)data + i + 1;
				}	}
			break;

		default:
			TIFFError(TIFFFileName(tif), "unknown photometric %d\n",
					  info->photoInterp);
			break;
		}

	free (buf);

	return 0;
}

static int
_WriteTiff(TIFF *tif, NSTiffInfo *info, u_char *buf)
{
	unsigned int i, row;

	TIFFSetField(tif, TIFFTAG_IMAGEWIDTH, info->width);
	TIFFSetField(tif, TIFFTAG_IMAGELENGTH, info->height);
	TIFFSetField(tif, TIFFTAG_COMPRESSION, info->compression);
	TIFFSetField(tif, TIFFTAG_SUBFILETYPE, info->subfileType);
	TIFFSetField(tif, TIFFTAG_BITSPERSAMPLE, info->bitsPerSample);
	TIFFSetField(tif, TIFFTAG_SAMPLESPERPIXEL, info->samplesPerPixel);
	TIFFSetField(tif, TIFFTAG_PLANARCONFIG, info->planarConfig);
	TIFFSetField(tif, TIFFTAG_PHOTOMETRIC, info->photoInterp);

	if (info->compression != COMPRESSION_NONE)
		TIFFSetField(tif, TIFFTAG_PREDICTOR, 2);	// horizontal differencing
	if (info->compression == COMPRESSION_JPEG)
		TIFFSetField(tif, TIFFTAG_JPEGQUALITY, info->factor);
	else if (info->compression == COMPRESSION_LZW)
		TIFFSetField(tif, TIFFTAG_ZIPQUALITY, info->factor);

	if (info->samplesPerPixel > 3)	// ASSOCALPHA alpha data is pre-multiplied
		{							// UNASSALPHA alpha data NOT pre-multiplied
		uint16 sampleinfo[] = {EXTRASAMPLE_UNASSALPHA,0};

		TIFFSetField(tif, TIFFTAG_EXTRASAMPLES, 1, sampleinfo);
		}

	switch (info->photoInterp)
		{
		case PHOTOMETRIC_MINISBLACK:
		case PHOTOMETRIC_MINISWHITE:
			if (info->planarConfig == PLANARCONFIG_CONTIG)
				{
				int	line = ceil((float)info->width * info->bitsPerSample / 8.0);

				for (row = 0; row < info->height; ++row)
					{
					if (TIFFWriteScanline(tif, buf, row, 0) < 0)
						{
						NSLog(@"tiff: write line %d failed\n", row);
						return 1;
						}
					buf += line;
				}	}
			else
				{
				int	line = ceil((float)info->width / 8.0);

				for (i = 0; i < info->samplesPerPixel; i++)
					{
					for (row = 0; row < info->height; ++row)
						{
						if (TIFFWriteScanline(tif, buf, row, i) < 0)
							{
							NSLog(@"tiff: write line %d failed\n", row);
							return 1;
							}
						buf += line;
				}	}	}
			break;

		case PHOTOMETRIC_RGB:
			if (info->planarConfig == PLANARCONFIG_CONTIG)
				{
				for (row = 0; row < info->height; ++row)
					{
					if (TIFFWriteScanline(tif, buf, row, 0) < 0)
						{
						NSLog(@"tiff: write line %d failed\n", row);
						return 1;
						}
					buf += info->width * info->samplesPerPixel;
				}	}
			else
				{
				for (i = 0; i < info->samplesPerPixel; i++)
					{
					for (row = 0; row < info->height; ++row)
						{
						if (TIFFWriteScanline(tif, buf, row, i) < 0)
							{
							NSLog(@"tiff: write line %d failed\n", row);
							return 1;
							}
						buf += info->width;
				}	}	}
			break;

		default:
			NSLog(@"Unknown photometric %d in %s\n",
					info->photoInterp, TIFFFileName(tif));
			break;
		}

	TIFFWriteDirectory(tif);

	return 0;
}

static int
_TiffCompression (NSTIFFCompression compression)
{
	switch (compression)
		{
		case NSTIFFCompressionLZW:			return COMPRESSION_LZW;
		case NSTIFFCompressionJPEG:			return COMPRESSION_JPEG;
		case NSTIFFCompressionNEXT:			return COMPRESSION_NEXT;
		case NSTIFFCompressionOldJPEG:		return COMPRESSION_OJPEG;
		case NSTIFFCompressionPackBits:		return COMPRESSION_PACKBITS;
		case NSTIFFCompressionCCITTFAX3:	return COMPRESSION_CCITTFAX3;
		case NSTIFFCompressionCCITTFAX4:	return COMPRESSION_CCITTFAX4;
		case NSTIFFCompressionNone:
		default:							break;
		}
	return COMPRESSION_NONE;
}

/* ****************************************************************************

 		NSBitmapImageRep  (TIFF)

** ***************************************************************************/

@implementation NSBitmapImageRep  (TIFF)

+ (BOOL) canInitWithData:(NSData *)data
{
	unsigned char sig[] = {0x49,0x49,0x2A,0x00};			// LE format
	unsigned char sg2[] = {0x4D,0x4D,0x00,0x2A};			// BE format

	return _CGImageCanInitWith((CFDataRef)data, sig, sizeof(sig))
		|| _CGImageCanInitWith((CFDataRef)data, sig, sizeof(sg2));
}

+ (NSArray *) imageRepsWithData:(NSData *)data
{
	TIFF *tif;
	int image = 0;
	NSTiffInfo *info;
	NSMutableArray *array = nil;

	if (!(tif = _OpenTiff((char *)[data bytes], [data length], "r", 0, 0)))
		[NSException raise:NSTIFFException format: @"TIFF open failed"];

	array = [NSMutableArray arrayWithCapacity:1];
	while ((info = _GetTiffInfo(image++, tif))) 
		{
		NSBitmapImageRep *imageRep = [[self class] alloc];

		[imageRep initWithBitmapDataPlanes: NULL
				  pixelsWide: info->width
				  pixelsHigh: info->height
				  bitsPerSample: info->bitsPerSample
				  samplesPerPixel: info->samplesPerPixel
				  hasAlpha:(info->samplesPerPixel > 3)
				  isPlanar:(info->planarConfig == PLANARCONFIG_SEPARATE)
				  colorSpaceName: info->space
				  bytesPerRow: 0
				  bitsPerPixel: 0];
		imageRep->_brep.compression = info->compression;
												// read tiff into data array
		if (_ReadTiff(tif, info, [imageRep bitmapData]))
			[NSException raise:NSTIFFException format: @"invalid TIFF image"];

		free(info);
		[array addObject: imageRep];
		}
	TIFFClose(tif);

	return array;
}

- (id) initWithData:(NSData *)data				// Loads default (first) image
{										 		// from TIFF contained in data
	TIFF *tif;
	NSTiffInfo *info;

	if (!(tif = _OpenTiff((char *)[data bytes], [data length], "r", 0, 0)))
		[NSException raise:NSTIFFException format: @"TIFF open failed"];
	if (!(info = _GetTiffInfo(-1, tif)))
		[NSException raise:NSTIFFException format: @"Invalid TIFF info"];

	[self initWithBitmapDataPlanes: NULL
		  pixelsWide: info->width
		  pixelsHigh: info->height
		  bitsPerSample: info->bitsPerSample
		  samplesPerPixel: info->samplesPerPixel
		  hasAlpha:(info->samplesPerPixel > 3)
		  isPlanar:(info->planarConfig == PLANARCONFIG_SEPARATE)
		  colorSpaceName: info->space
		  bytesPerRow: 0
		  bitsPerPixel: 0];
	_brep.compression = info->compression;
												// read tiff into data array
	if (_ReadTiff(tif, info, [self bitmapData]))
		[NSException raise:NSTIFFException format:@"Read invalid TIFF image"];

	free(info);
	TIFFClose(tif);

	return self;
}

- (NSData *) TIFFRepresentation
{
	return [self TIFFRepresentationUsingCompression: NSTIFFCompressionLZW
				 factor: 0.75];
}

- (NSData *) TIFFRepresentationUsingCompression:(NSTIFFCompression)compression
										 factor:(float)factor
{
	TIFF *tif;
	NSTiffInfo info;
	char *bytes = 0;
	long length = 0;

	if (![self canBeCompressedUsing: compression])
		compression = NSTIFFCompressionNone;
	else if (compression == NSTIFFCompressionJPEG)	// 0-100, typical 75
		info.factor = rint(MIN(1.0, MAX(0.0, factor)) * 100);
	else if (compression == NSTIFFCompressionLZW)	// 1-9, typical 6
		info.factor = MAX(1, rint(MIN(1.0, MAX(0.0, factor)) * 9));
	info.numImages = 1;
	info.imageNumber = 0;
	info.subfileType = 0;
	info.width = _pixelsWide;
	info.height = _pixelsHigh;
	info.samplesPerPixel = _brep.samplesPerPixel;
	info.bitsPerSample = _irep.bitsPerSample;
	info.compression = _TiffCompression(compression);
	info.planarConfig = (_brep.isPlanar) ? PLANARCONFIG_SEPARATE
										 : PLANARCONFIG_CONTIG;
	info.photoInterp = PHOTOMETRIC_RGB;
	if (_colorSpace == NSDeviceWhiteColorSpace)
		info.photoInterp = PHOTOMETRIC_MINISBLACK;
	else if (_colorSpace == NSDeviceBlackColorSpace)
		info.photoInterp = PHOTOMETRIC_MINISWHITE;

	if ((tif = _OpenTiff(0, 0, "w", &bytes, &length)) == 0)
		[NSException raise:NSTIFFException format: @"Tiff write open failed"];
	if (_WriteTiff(tif, &info, [self bitmapData]))
		[NSException raise:NSTIFFException format: @"Tiff write failed"];

	TIFFClose(tif);

	return [NSData dataWithBytesNoCopy:bytes length:length];
}

- (BOOL) canBeCompressedUsing:(NSTIFFCompression)c
{
	return (c == NSTIFFCompressionNEXT || c == 0
	   || ((c == NSTIFFCompressionCCITTFAX3 || c == NSTIFFCompressionCCITTFAX4)
	   && (_irep.bitsPerSample != 1 || _brep.samplesPerPixel != 1))) ? NO : YES;
}

- (void) getCompression:(NSTIFFCompression *)compression factor:(float *)factor
{
	*compression = _brep.compression;
	*factor = 0.75;
}

- (void) setCompression:(NSTIFFCompression)compression factor:(float)factor
{
	_brep.compression = compression;
//	_factor = factor;
}

+ (void) getTIFFCompressionTypes:(const NSTIFFCompression **)list
						   count:(int *)numTypes			{ NIMP }
+ (NSData *) TIFFRepresentationOfImageRepsInArray:(NSArray *)anArray
															{ return NIMP }
+ (NSData *) TIFFRepresentationOfImageRepsInArray:(NSArray *)anArray
			 usingCompression:(NSTIFFCompression)compressionType
			 factor:(float)factor							{ return NIMP }

@end  /* NSBitmapImageRep */
