/*
   gif.m

   Copyright (C) 1999-2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	March 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <AppKit/AppKit.h>

#include <gif_lib.h>


static NSArray *__filesGIF = nil;


typedef struct {
	char *data;
	long size;
	long position;
} GIF;

static GIF *
OpenDataGIF(char *data, long size)
{
	GIF *handle;

	DBLog (@"GIFOpenData\n");
	handle = malloc (sizeof(GIF));
	handle->data = data;
	handle->position = 0;
	handle->size = size;

	return handle;
}

static int
ReadGIF(GifFileType *handle, GifByteType *buf, int count)
{
	GIF *chand = (GIF *)handle->UserData;

	DBLog (@"ReadGIF\n");
	if (chand->position >= chand->size)
		return 0;
	if (chand->position + count > chand->size)
		count = chand->size - chand->position;
	memcpy(buf, chand->data + chand->position, count);
	chand->position += count;

	return count;
}

static int
ReadGIFToBuf(GifFileType *gf, GifRowType *ScreenBuffer, int TransparentColor, char *data)
{
	int	i, j;							// IMAGE_DESC_RECORD_TYPE
	int Row = gf->Image.Top;			// Image Position relative to Screen.
	int Col = gf->Image.Left;
	int Width = gf->Image.Width;
	int Height = gf->Image.Height;
	ColorMapObject *ColorMap = gf->Image.ColorMap ? gf->Image.ColorMap
												  : gf->SColorMap;
	DBLog (@"ReadGIFToBuf\n");

	if (Col + Width > gf->SWidth || Row + Height > gf->SHeight)
		{
		NSLog (@"GIF image is not confined to screen dimensions.\n");
		return 1;
		}

	if (gf->Image.Interlace)					// Need to perform 4 passes
		{										// on interlaced images
		int offset[] = { 0, 4, 2, 1 };
		int jump[] = { 8, 8, 4, 2 };

		NSLog (@"(GifFile->Image.Interlace)\n");

		for (i = 0; i < 4; i++)
			for (j = Row + offset[i]; j < Row + Height; j += jump[i])
			    if (DGifGetLine(gf, &ScreenBuffer[j][Col], Width) == GIF_ERROR)
					return 2;
		}
	else
		{
		for (i = gf->Image.Top; i < gf->Image.Top + gf->Image.Height; i++)
			if (DGifGetLine(gf, &ScreenBuffer[Row++][Col], Width) == GIF_ERROR)
				return 3;
		}

	for (i = gf->Image.Top; i < gf->Image.Top + gf->Image.Height; i++)
		{
		GifRowType GifRow = ScreenBuffer[i];
		unsigned char *p = data + (i * gf->SWidth * 3) + (gf->Image.Left * 3);

		for (j = gf->Image.Left; j < gf->Image.Left + Width; j++)
			if (GifRow[j] != TransparentColor)
				{
				GifColorType *ColorMapEntry = &ColorMap->Colors[GifRow[j]];

				*p++ = ColorMapEntry->Red;
				*p++ = ColorMapEntry->Green;
				*p++ = ColorMapEntry->Blue;
				}
			else
				p += 3;
		}

	return 0;									// D_GIF_SUCCEEDED
}

static GifRowType * AllocScreenBuffer(GifFileType *GifFile)
{
	int Size = GifFile->SWidth * sizeof(GifPixelType);  	// bytes in one row
    GifRowType *sb = NULL;
	int i;

	if ((sb = (GifRowType *) malloc(GifFile->SHeight * sizeof(GifRowType))) == NULL)
		[NSException raise:NSMallocException format: @"no memory"];

	if ((sb[0] = (GifRowType) malloc(Size)) == NULL) 	/* First row. */
		[NSException raise:NSMallocException format: @"no memory"];
	for (i = 0; i < GifFile->SWidth; i++)  /* Set its color to BackGround. */
		sb[0][i] = GifFile->SBackGroundColor;

	for (i = 1; i < GifFile->SHeight; i++)
		{	/* Allocate other rows, and set their color to background too: */
		if ((sb[i] = (GifRowType) malloc(Size)) == NULL)
			[NSException raise:NSMallocException format: @"no memory"];

		memcpy(sb[i], sb[0], Size);
		}
	
	return sb;
}

static void FreeScreenBuffer(GifFileType *GifFile, GifRowType *sb)
{
	int i;

	for (i = 0; i < GifFile->SHeight; i++)
		free(sb[i]);
	free(sb);
}

@interface _NSBitmapImageRepGIF : NSBitmapImageRep
{
	CGFloat _animationTime;
}

- (void) _setAnimTime:(CGFloat)delay;
- (CGFloat) _animTime;

@end

@implementation _NSBitmapImageRepGIF 

+ (void) initialize
{
	if (self == [_NSBitmapImageRepGIF class])
		__filesGIF = [[NSArray arrayWithObjects: @"gif", nil] retain];
}

+ (BOOL) canInitWithData:(NSData *)data
{
	unsigned char sig[] = {0x47,0x49,0x46,0x38,0x37,0x61};		// GIF87a
	unsigned char sg2[] = {0x47,0x49,0x46,0x38,0x39,0x61};		// GIF89a

	return _CGImageCanInitWith( (CFDataRef)data, sig, sizeof(sig) )
		|| _CGImageCanInitWith( (CFDataRef)data, sg2, sizeof(sg2) );
}

+ (NSArray *) imageUnfilteredFileTypes		{ return __filesGIF; }

+ (NSArray *) imageRepsWithData:(NSData *)data
{
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:1];
	GIF *handle = OpenDataGIF((char *)[data bytes], [data length]);
#if defined( GIFLIB_MAJOR ) && GIFLIB_MAJOR >= 5
	GifFileType *gf = DGifOpen(handle, ReadGIF, NULL);
#else
	GifFileType *gf = DGifOpen(handle, ReadGIF);
#endif
	GifRecordType RecordType = UNDEFINED_RECORD_TYPE;
    GifRowType *ScreenBuffer = NULL;
	unsigned char *d = NULL;
	int TransparentColor = 0;
	CGFloat delayTime = .1;

	while (RecordType != TERMINATE_RECORD_TYPE)
		{
		if (DGifGetRecordType(gf, &RecordType) == GIF_ERROR)
			NSLog(@"ERROR: reading GIF record type");
		else if (RecordType == IMAGE_DESC_RECORD_TYPE)
			{
			_NSBitmapImageRepGIF *imageRep = [[self class] alloc];

			imageRep = [imageRep initWithBitmapDataPlanes: NULL
								 pixelsWide: gf->SWidth
								 pixelsHigh: gf->SHeight
								 bitsPerSample: 8
								 samplesPerPixel: 3	// gf->SColorResolution
								 hasAlpha: NO		// (gf->SColorResolution > 3)
								 isPlanar: NO
								 colorSpaceName: NSDeviceRGBColorSpace
								 bytesPerRow: gf->SWidth * sizeof(GifPixelType)
								 bitsPerPixel: gf->SColorMap->BitsPerPixel];
			if (!ScreenBuffer)
				{
				ScreenBuffer = AllocScreenBuffer(gf);
				d = [imageRep bitmapData];
				[imageRep _setAnimTime: delayTime];
				}
			else				// image index > 1
				{
				unsigned char *nd = [imageRep bitmapData];

				memcpy(nd, d, gf->SWidth * gf->SHeight * 3);
				d = nd;
				}
				
			if (DGifGetImageDesc(gf) == GIF_ERROR)
				{
				NSLog(@"ERROR: reading GIF image description");
				break;
				}								// read gif into data array
			else if (ReadGIFToBuf(gf, ScreenBuffer, TransparentColor, [imageRep bitmapData]))
				NSLog(@"ERROR: reading GIF line, frame %d", gf->ImageCount);

			[array addObject: [imageRep autorelease]];
			}
		else if (RecordType == EXTENSION_RECORD_TYPE)
			{
			GifByteType *Extension;
			int	ExtCode;

			if (DGifGetExtension(gf, &ExtCode, &Extension) == GIF_ERROR)
				NSLog(@"ERROR: reading GIF extension");

			if (ExtCode == GRAPHICS_EXT_FUNC_CODE && Extension[0] == 0x4)
				{
				if ((Extension[1] & 0x1))
					TransparentColor = Extension[4];
				else
					TransparentColor = -1;
				delayTime = MIN(0.1, Extension[2] * .01);
				//NSLog(@"Dispose Of Graphic: %x", (Extension[1] >> 2) & 0x3);
				}

			while (Extension != NULL)
				if (DGifGetExtensionNext(gf, &Extension) == GIF_ERROR)
					{
					NSLog(@"ERROR: reading next GIF extension");
					break;
					}
			}
		}

	if (ScreenBuffer)
		FreeScreenBuffer(gf, ScreenBuffer);

	return array;
}

- (void) _setAnimTime:(CGFloat)delay			{ _animationTime = delay; }
- (CGFloat) _animTime							{ return _animationTime; }

@end /* _NSBitmapImageRepGIF */
