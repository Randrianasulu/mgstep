/*
   NSColorPanel.m

   Color panel and related classes

   Copyright (C) 2005 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    May 2005

   Color Wheel code is derived from WindowMaker implementation by:

     Pascal Hofstee - Code for wheeldrawing and calculating colors from it.
     Alban Hertroys - Optimization of algorithms.

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <AppKit/AppKit.h>
#include <CoreGraphics/Private/_CGColor.h>

#include <math.h>
#include <assert.h>


typedef struct WheelMatrix {
    unsigned int width, height;			// Size of the colorwheel
    unsigned char *data[3];				// Wheel data (R,G,B)
    unsigned char values[256];			// Precalculated values R,G & B = 0-255
} WheelMatrix;


// Class variables
static NSColorPanel *__colorPanel = nil;
static int __colorWheelSize = 159;
static WheelMatrix *__wheel = NULL;


static WheelMatrix *
wheelCreateMatrix(unsigned int width, unsigned int height)
{
	WheelMatrix	*matrix = NULL;
	int	i;
    
    assert((width > 0) && (height > 0));
    
    matrix = malloc(sizeof(WheelMatrix));
    memset(matrix, 0, sizeof(WheelMatrix));
    matrix->width = width;
    matrix->height = height;

    for (i = 0; i < 3; i++)
		matrix->data[i] = malloc(width * height * sizeof(unsigned char));

    return matrix;
}

static void
wheelDestroyMatrix(WheelMatrix *matrix)
{
	int i;
    
	if (!matrix)
		return;
    
    for (i = 0; i < 3; i++)
		if (matrix->data[i])
	    	free(matrix->data[i]);

    free(matrix);
}

static void
wheelInitMatrix(WheelMatrix *matrix)
{
	int i, x, y;
	long ofs[4];
	int xcor, ycor;
	int dhue[4];
	const int cw_halfsize = (__colorWheelSize) / 2;
	const int cw_sqsize = (__colorWheelSize) * (__colorWheelSize);
	struct HSB_Color hsb;

    hsb.brightness = 255;
    
    ofs[0] = -1;							// offsets are counterclockwise
    ofs[1] = -(__colorWheelSize);			// (in triangles)

    for (y = 0; y < cw_halfsize; y++) 
		{
		for (x = y; x < (__colorWheelSize-y); x++) 
			{			// (xcor, ycor) is (x,y) relative to center of matrix
			xcor = 2 * x - __colorWheelSize;
			ycor = 2 * y - __colorWheelSize;
											// saturation will wrap after 255
			hsb.saturation = rint(255.0 * sqrt(xcor * xcor + ycor * ycor) 
									/ __colorWheelSize);
			ofs[0]++;								// top quadrant of matrix
			ofs[1] += __colorWheelSize;				// left quadrant    ____
    	    ofs[2] = cw_sqsize - 1 - ofs[0];		// bottom quadrant |\  /|
			ofs[3] = cw_sqsize - 1 - ofs[1];		// right quadrant  | \/ |
	    											//                 | /\ |
			if (hsb.saturation < 256)				//                 |/__\|
				{
				if (xcor != 0)
					dhue[0] = rint(atan((double)ycor / (double)xcor) 
								* (180.0 / M_PI)) + (xcor < 0 ? 180.0 : 0.0);
				else
					dhue[0] = 270;
				
				dhue[0] = 360 - dhue[0];	// Reverse direction of ColorWheel
				dhue[1] = 270 - dhue[0] + (dhue[0] > 270 ? 360 : 0);
				dhue[2] = dhue[0] - 180 + (dhue[0] < 180 ? 360 : 0);
				dhue[3] = 90 - dhue[0]  + (dhue[0] > 90  ? 360 : 0);
				
				for (i = 0; i < 4; i++)
					{
					int shift = ofs[i];
					struct RGB_Color rgb;

					hsb.hue = dhue[i];
					_CGColorConvertHSBtoRGB_n(hsb, &rgb);
					matrix->data[0][shift] = (unsigned char)(rgb.red);
					matrix->data[1][shift] = (unsigned char)(rgb.green);
					matrix->data[2][shift] = (unsigned char)(rgb.blue);
				}	}
			else 
				{
				for (i = 0; i < 4; i++) 
					{
					int shift = ofs[i];

					matrix->data[0][shift] = (unsigned char)0;
					matrix->data[1][shift] = (unsigned char)0;
					matrix->data[2][shift] = (unsigned char)0;
			}	}	}

		ofs[0] += 2 * y + 1;
		ofs[1] += 1 - (__colorWheelSize) * (__colorWheelSize - 1 - 2 * y);
		}
}

@interface _ColorWheelImageView : NSImageView
@end

@implementation _ColorWheelImageView

- (void) mouseDown:(NSEvent*)event
{
	NSPoint p = [self convertPoint:[event locationInWindow] fromView:nil];
	int x = p.x;
	int y = p.y;
	unsigned long ofs = (y * __colorWheelSize) + x;
	unsigned char r, g, b;
	NSColor *c;

	NSLog(@"ColorWheelImageView mouseDown %d %d\n", x, y);	// FIX ME
r = (unsigned char)__wheel->data[0][ofs];
b = (unsigned char)__wheel->data[1][ofs];
g = (unsigned char)__wheel->data[2][ofs];
	NSLog(@"ColorWheelImageView RGB %d %d %d\n", r, g, b);
	NSLog(@"ColorWheelImageView RGB %f %f %f\n", (float)r/255, (float)g/255, (float)b/255);
c = [NSColor colorWithCalibratedRed:(float)r/255
			      			  green:(float)g/255
			       			  blue:(float)b/255
			      			  alpha:1];
	[(NSColorPanel*)_window setColor:c];
}

@end


@implementation NSColorPanel

+ (id) alloc
{ 
	return __colorPanel ? __colorPanel
			: (__colorPanel = (NSColorPanel*) NSAllocateObject(self)); 
}

+ (BOOL) sharedColorPanelExists				{ return __colorPanel ? YES : NO; }

+ (NSColorPanel *) sharedColorPanel
{
	if ((!__colorPanel) && ![GMModel loadMibFile:@"ColorPanel" owner:NSApp])
		[NSException raise: NSInternalInconsistencyException 
					 format: @"Unable to open color panel mib model file."];

	if (__wheel == NULL)
		{
		NSImage *im = [[NSImage alloc] initWithSize: NSZeroSize];
		NSBitmapImageRep *imageRep = [NSBitmapImageRep alloc];
		int x, y;
		unsigned long ofs = 0;
		unsigned char *data;

		[imageRep initWithBitmapDataPlanes: NULL
				  pixelsWide: 159
				  pixelsHigh: 159
				  bitsPerSample: 8
				  samplesPerPixel: 3
				  hasAlpha: NO
				  isPlanar: NO
				  colorSpaceName: nil
				  bytesPerRow: 0
				  bitsPerPixel: 0];

		[im addRepresentation:imageRep];
		[[[[__colorPanel contentView] subviews] objectAtIndex:0] setImage: im];

		__wheel = wheelCreateMatrix(__colorWheelSize, __colorWheelSize);
		wheelInitMatrix(__wheel);
		data = [imageRep bitmapData];

		for (y = 0; y < __colorWheelSize ; y++) 
			for (x = 0; x < __colorWheelSize ; x++) 
				{
				if ((__wheel->data[0][ofs] != 0)			// if inside wheel
						&& (__wheel->data[1][ofs] != 0) 
						&& (__wheel->data[2][ofs] != 0))
					{
					*(data++) = (unsigned char)(__wheel->data[0][ofs]);
					*(data++) = (unsigned char)(__wheel->data[1][ofs]);
					*(data++) = (unsigned char)(__wheel->data[2][ofs]);
//					*(ptr++) = 0;
					}
				else 
					{
					*(data++) = (char)(0xae);
					*(data++) = (char)(0xaa);
					*(data++) = (char)(0xae);
//					*(ptr++) = 255;
					}
				ofs++;
		}		}

    return __colorPanel;
}

+ (void) setPickerMask:(int)mask			{ NIMP }
+ (void) setPickerMode:(int)mode			{ NIMP }

+ (BOOL) dragColor:(NSColor **)aColor
		 withEvent:(NSEvent *)anEvent
		 fromView:(NSView *)sourceView		{ return NO; }

- (BOOL) isContinuous						{ return _cp.isContinuous; }
- (BOOL) showsAlpha							{ return _cp.showsAlpha; }
- (void) setShowsAlpha:(BOOL)flag			{ _cp.showsAlpha = flag; }
- (float) alpha								{ return 0; }
- (NSView *) accessoryView					{ return nil; }
- (void) setAccessoryView:(NSView *)aView	{}
- (void) setAction:(SEL)aSelector			{ _action = aSelector; }
- (void) setTarget:(id)anObject				{ _target = anObject; }
- (void) setContinuous:(BOOL)flag			{}
- (void) setMode:(int)mode					{}
- (int) mode								{ return 0; }
- (NSColor *) color							{ return [_colorWell color]; }

- (void) setColor:(NSColor *)aColor
{ 
	[_colorWell setColor:aColor];
	
	if (_target && _action)
		[_target performSelector:_action withObject:self];
}

- (void) attachColorList:(NSColorList *)aColorList		{}
- (void) detachColorList:(NSColorList *)aColorList		{}

- (void) encodeWithCoder:(NSCoder *)aCoder				// NSCoding protocol
{
	[super encodeWithCoder:aCoder];
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
	[super initWithCoder:aDecoder];

	return self;
}

@end /* NSColorPanel */

												// abstract superclass which
@implementation NSColorPicker					// enables adding of custom
												// UI's to NSColorPanel
- (id) initWithPickerMask:(int)aMask colorPanel:(NSColorPanel *)colorPanel
{
	__colorPanel = colorPanel;
	return nil;
}

- (NSColorPanel *) colorPanel						{ return __colorPanel; }

- (void) insertNewButtonImage:(NSImage *)newImage
						   in:(NSButtonCell *)newButtonCell	{}

- (NSImage *) provideNewButtonImage					{ return nil; }
- (void) setMode:(int)mode							{}
- (void) attachColorList:(NSColorList *)colorList	{}
- (void) detachColorList:(NSColorList *)colorList	{}
- (void) alphaControlAddedOrRemoved:(id)sender		{}
- (void) viewSizeChanged:(id)sender					{}

@end
