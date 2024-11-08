/*
   NSImageRep.m

   Image representaion classes (Bitmap, Cached, Custom)

   Copyright (C) 1996-2020 Free Software Foundation, Inc.

   Author:  Adam Fedor <fedor@colorado.edu>
   Date: 	Feb 1996
   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	March 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSData.h>
#include <Foundation/NSSet.h>
#include <Foundation/NSException.h>
#include <Foundation/NSNotification.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSGraphics.h>
#include <AppKit/NSImageRep.h>
#include <AppKit/NSBitmapImageRep.h>
#include <AppKit/NSCachedImageRep.h>
#include <AppKit/NSCustomImageRep.h>
#include <AppKit/NSPasteboard.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSView.h>

#include <sys/types.h>


#define MAX_PLANES		5					// Maximum number of color planes

#define CONTEXT			(_CGContext())

// Class variables
static NSMutableArray *__imageRepClasses = nil;
static NSArray *__imgFileTypes = nil;
static NSArray *__pbTypes = nil;
static NSArray *__filesTIF = nil;
static BOOL __loadedPlugins = NO;


/* ****************************************************************************

	NSImageRep

** ***************************************************************************/

@implementation NSImageRep
										// mGSTEP has 3 ImageRep subclasses
+ (void) initialize						// only BitmapReps can load from a file
{
	if (!__imageRepClasses)
		__imageRepClasses = [[NSMutableArray alloc] initWithCapacity: 4];
}

+ (BOOL) canInitWithData:(NSData *)data			{ SUBCLASS return NO; }
+ (BOOL) canInitWithPasteboard:(NSPasteboard*)p { SUBCLASS return NO; }
+ (NSArray *) imageUnfilteredFileTypes			{ return nil; }
+ (NSArray *) imageUnfilteredPasteboardTypes	{ return nil; }

+ (NSArray *) imageFileTypes					
{
	if (!__imgFileTypes)
		{
		NSCountedSet *ift = [NSCountedSet new];
		NSUInteger i, c = [__imageRepClasses count];
		
		for (i = 0; i < c; i++)
			{
			Class irc = [__imageRepClasses objectAtIndex: i];

			[ift addObjectsFromArray: [irc imageUnfilteredFileTypes]];
			}

		__imgFileTypes = [[ift allObjects] retain];
		}

	return __imgFileTypes;
}

+ (NSArray *) imagePasteboardTypes
{
	if (!__pbTypes)
		{
		NSCountedSet *ipt = [NSCountedSet new];
		NSUInteger i, c = [__imageRepClasses count];
		
		for (i = 0; i < c; i++)
			{
			Class irc = [__imageRepClasses objectAtIndex: i];

			[ipt addObjectsFromArray: [irc imageUnfilteredPasteboardTypes]];
			}

		__pbTypes = [[ipt allObjects] retain];
		}

	return __pbTypes;
}

+ (NSArray *) registeredImageRepClasses			
{ 
	return (NSArray*)__imageRepClasses;
}

+ (void) registerImageRepClass:(Class)irc
{
	DBLog(@" register %@", [irc description]);

	if (![irc respondsToSelector: @selector(imageFileTypes)])
		[NSException raise: NSInvalidArgumentException
					 format: @"imageRep does not respond to imageFileTypes"];

	[__imageRepClasses addObject: irc];
	ASSIGN(__imgFileTypes, nil);				// regenerate types next access
	ASSIGN(__pbTypes, nil);
}

+ (void) unregisterImageRepClass:(Class)irc
{
	[__imageRepClasses removeObject: irc];
	ASSIGN(__imgFileTypes, nil);				// regenerate types next access
	ASSIGN(__pbTypes, nil);
	[NSNotificationCenter post: NSImageRepRegistryChangedNotification
						  object: self];
}

+ (id) imageRepWithContentsOfFile:(NSString *)filename
{
	NSArray *array = [self imageRepsWithContentsOfFile: filename];

	return ([array count]) ? [array objectAtIndex: 0] : nil;
}

+ (void) _loadPlugins
{
	int i, count;
	NSArray *bundles = [[NSBundle systemBundle] pathsForResourcesOfType:@"bundle"
												inDirectory:@"AppKit/Plugins"];
	__loadedPlugins = YES;

	for (i = 0, count = [bundles count]; i < count; i++)
		{
		NSString *path = [bundles objectAtIndex: i];
		NSBundle *bundle = [[NSBundle alloc] initWithPath:path];
		Class c;

		if (bundle)
			{
			NSLog(@"Loading bundle %@", path);
			if (!(c = [bundle principalClass]))
				NSLog(@"Error loading principalClass of bundle %@", path);
			else
				[NSImageRep registerImageRepClass: c];
			}
		else
			NSLog(@"Error loading bundle %@", path);
		}
}

+ (NSArray *) imageRepsWithContentsOfFile:(NSString *)filename
{
	NSString *ext = [filename pathExtension];
	NSArray *array = nil;
	id cls = ([ext length]) ? [self imageRepClassForFileType: ext] : nil;

	if (!__loadedPlugins && !cls && [ext length])
		[self _loadPlugins];

	if (cls || (cls = [self imageRepClassForFileType: ext]))
		{
		NSData *data = [NSData dataWithContentsOfFile: filename];

		if ([cls respondsToSelector: @selector(imageRepsWithData:)])
			array = [cls imageRepsWithData: data];
		else if ([cls respondsToSelector: @selector(imageRepWithData:)])
			array = [cls imageRepWithData: data];
		}
	else
		NSLog(@"Error loading plugin for extension: %@", ext);

	return (array) ? [NSArray arrayWithArray: array] : nil;
}

+ (id) imageRepWithPasteboard:(NSPasteboard *)pb
{
	NSArray *array = [self imageRepsWithPasteboard: pb];

	return ([array count]) ? [array objectAtIndex: 0] : nil;
}

+ (NSArray *) imageRepsWithPasteboard:(NSPasteboard *)pb
{
	int i, count = [__imageRepClasses count];
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:1];
	
	for (i = 0; i < count; i++)
		{
		id rep = [__imageRepClasses objectAtIndex: i];
		NSString *t;

		if ([rep respondsToSelector: @selector(imagePasteboardTypes)]
				&& (t = [pb availableTypeFromArray:[rep imagePasteboardTypes]]))
			{
			NSData *data = [pb dataForType: t];

			if ([rep respondsToSelector: @selector(imageRepsWithData:)])
				[array addObjectsFromArray: [rep imageRepsWithData: data]];
			else 
				if ([rep respondsToSelector: @selector(imageRepWithData:)])
					[array addObject: [rep imageRepWithData: data]];
		}	}

	return (NSArray *)array;
}

+ (Class) imageRepClassForData:(NSData *)data
{
	int i, count = [__imageRepClasses count];
	Class cls;

	for (i = 0; i < count; i++)
		if ([(cls = [__imageRepClasses objectAtIndex: i]) canInitWithData:data])
			return cls;

	return Nil;
}

+ (Class) imageRepClassForFileType:(NSString *)type
{
	int i, count = [__imageRepClasses count];

	for (i = 0; i < count; i++)
		{
		Class cls = [__imageRepClasses objectAtIndex: i];

		if ([[cls imageUnfilteredFileTypes] indexOfObject:type] != NSNotFound)
			return cls;
		}

	return Nil;
}

+ (Class) imageRepClassForPasteboardType:(NSString *)type
{
	int i, count = [__imageRepClasses count];

	for (i = 0; i < count; i++)
		{
		id cls = [__imageRepClasses objectAtIndex: i];

		if ([cls respondsToSelector: @selector(imagePasteboardTypes)])
			if ([[cls imagePasteboardTypes] indexOfObject: type] != NSNotFound)
				return cls;
		}

	return Nil;
}

- (void) dealloc
{
	[_colorSpace release];
	[super dealloc];
}

- (NSSize) size									{ return _size; }
- (void) setSize:(NSSize)aSize					{ _size = aSize; }
- (void) setAlpha:(BOOL)flag					{ _irep.hasAlpha = flag; }
- (BOOL) hasAlpha								{ return _irep.hasAlpha; }
- (BOOL) isOpaque								{ return _irep.isOpaque; }
- (void) setOpaque:(BOOL)flag					{ _irep.isOpaque = flag; }
- (void) setPixelsWide:(int)w					{ _pixelsWide = w; }
- (void) setPixelsHigh:(int)h					{ _pixelsHigh = h; }
- (void) setBitsPerSample:(int)bps				{ _irep.bitsPerSample = bps; }
- (int) pixelsWide								{ return _pixelsWide; }
- (int) pixelsHigh								{ return _pixelsHigh; }
- (int) bitsPerSample							{ return _irep.bitsPerSample; }
- (NSString *) colorSpaceName					{ return _colorSpace; }
- (void) setColorSpaceName:(NSString *)csn		{ ASSIGN(_colorSpace, csn); }
- (BOOL) draw									{ SUBCLASS return NO; }
- (BOOL) drawAtPoint:(NSPoint)aPoint			{ SUBCLASS return NO; }
- (BOOL) drawInRect:(NSRect)aRect				{ SUBCLASS return NO; }

- (id) copy
{
	NSImageRep *copy = (NSImageRep*)NSCopyObject(self);

	copy->_size = _size;
	copy->_irep = _irep;
	copy->_pixelsWide = _pixelsWide;
	copy->_pixelsHigh = _pixelsHigh;
	copy->_colorSpace = [_colorSpace retain];

	return copy;
}

- (void) encodeWithCoder:(NSCoder*)aCoder
{														// NSCoding protocol
	[aCoder encodeObject: _colorSpace];
	[aCoder encodeSize: _size];
	[aCoder encodeValueOfObjCType: @encode(unsigned int) at: &_irep];
	[aCoder encodeValueOfObjCType: @encode(int) at: &_pixelsWide];
	[aCoder encodeValueOfObjCType: @encode(int) at: &_pixelsHigh];
}

- (id) initWithCoder:(NSCoder*)aDecoder
{
	_colorSpace = [[aDecoder decodeObject] retain];
	_size = [aDecoder decodeSize];
	[aDecoder decodeValueOfObjCType:@encode(unsigned int) at: &_irep];
	[aDecoder decodeValueOfObjCType: @encode(int) at: &_pixelsWide];
	[aDecoder decodeValueOfObjCType: @encode(int) at: &_pixelsHigh];

	return self;
}

@end  /* NSImageRep */

/* ****************************************************************************

	NSCachedImageRep -- maintain an image rep in an off screen window

** ***************************************************************************/

@implementation NSCachedImageRep

+ (void) initialize
{
	if (self == [NSCachedImageRep class])
		[self registerImageRepClass: self];
}

- (id) initWithSize:(NSSize)aSize
			  depth:(NSWindowDepth)aDepth
			  separate:(BOOL)separate
			  alpha:(BOOL)alpha	
{
	return [self initWithWindow:nil rect:(NSRect){{0,0},aSize}];
}

- (id) initWithWindow:(NSWindow *)window rect:(NSRect)rect
{
	if ((self = [super init]))
		{
		if (NSIsEmptyRect(rect))
			{
			if (!window) 
				[NSException raise: NSInvalidArgumentException
							 format: @"invalid window and cache rect"];

			_size = [window frame].size;
			}
		else
			_size = rect.size;

		_origin = rect.origin;

		if (window)
			_window = [window retain];
		else
			_window = [[NSWindow alloc] initWithContentRect: rect
										styleMask: NSBorderlessWindowMask
										backing: NSBackingStoreRetained
										defer: NO];
		}

	return self;
}

- (void) dealloc
{
	[_window release];
	[super dealloc];
}

- (BOOL) draw
{
	return [self drawAtPoint:NSZeroPoint];
}

- (BOOL) drawAtPoint:(NSPoint)p
{
	NSCopyBits([_window gState], (NSRect){_origin,_size}, p);

	return YES;
}

- (BOOL) drawInRect:(NSRect)r
{
	NSCopyBitmapFromGState([_window gState], (NSRect){_origin, _size}, r);

	return YES;
}

- (NSRect) rect							{ return (NSRect){_origin,_size}; }
- (NSWindow *) window					{ return _window; }

@end  /* NSCachedImageRep */

/* ****************************************************************************

	NSCustomImageRep

** ***************************************************************************/

@implementation NSCustomImageRep

- (id) initWithDrawSelector:(SEL)aSelector delegate:(id)delegate
{
	if ((self = [super init]))
		{
		_delegate = delegate;
		_selector = aSelector;
		}

	return self;
}

- (id) delegate							{ return _delegate; }
- (SEL) drawSelector					{ return _selector; }

- (BOOL) draw
{
	return ([_delegate performSelector: _selector]) ? YES : NO;
}

- (BOOL) drawInRect:(NSRect)r
{
	return ([_delegate performSelector: _selector]) ? YES : NO;
}

@end  /* NSCustomImageRep */

/* ****************************************************************************

 		NSBitmapImageRep

** ***************************************************************************/

@implementation NSBitmapImageRep 

+ (void) initialize
{
	if (!__filesTIF)
		{
		__filesTIF = [[NSArray arrayWithObjects: @"tiff", @"tif", nil] retain];
		[self registerImageRepClass: self];					// Register self
		}
}

+ (NSArray *) imageUnfilteredFileTypes			{ return __filesTIF; }
+ (NSArray *) imagePasteboardTypes				{ return nil; }
+ (NSArray *) imageUnfilteredPasteboardTypes	{ return nil; }

+ (id) imageRepWithData:(NSData *)data
{
	return [[[self class] alloc] initWithData:data];
}

- (id) initWithData:(NSData *)data				{ return self; }

- (id) initWithBitmapDataPlanes:(unsigned char **)planes	// designated init
					 pixelsWide:(int)w
					 pixelsHigh:(int)h
					 bitsPerSample:(int)bitsPerSample
					 samplesPerPixel:(int)samplesPerPixel
					 hasAlpha:(BOOL)alpha
					 isPlanar:(BOOL)isPlanar
					 colorSpaceName:(NSString *)colorSpaceName
					 bytesPerRow:(int)bytesPerRow
					 bitsPerPixel:(int)bPP
{
	if (!bitsPerSample || !samplesPerPixel || !w || !h)
		[NSException raise: NSInvalidArgumentException
					 format: @"initWithBitmapDataPlanes invalid arguments"];

	_pixelsWide = w;
	_pixelsHigh = h;
	_size = (NSSize){w, h};
	_irep.bitsPerSample = bitsPerSample;
	_brep.samplesPerPixel = samplesPerPixel;
	_irep.hasAlpha = alpha;
	_brep.isPlanar = isPlanar;
	_colorSpace = [colorSpaceName retain];
	_brep.bitsPerPixel = (!bPP) ? bitsPerSample * samplesPerPixel : bPP;
	_bytesPerRow = (!bytesPerRow) ? w * _brep.bitsPerPixel / 8 : bytesPerRow;
										// If data is passed to us in planes,
	if (planes)							// we DO NOT own or copy this data.
		{								// Assume it will always be available.
		int i, np = ((_brep.isPlanar) ? _brep.samplesPerPixel : 1);

		if (!(_imagePlanes = calloc(MAX_PLANES, sizeof(unsigned char*))))
			[NSException raise: NSMallocException format:@"malloc failed"];
		for (i = 0; i < np; i++)
			_imagePlanes[i] = planes[i];
		}

	return self;
}

- (id) initWithFocusedViewRect:(NSRect)r
{
	CGImageRef img = _CGContextGetImage(CONTEXT, r);

	if (img == NULL)
		return _NSInitError(self, @"_CGContextGetImage failed");

	return [self initWithCGImage: img];
}

- (id) initWithCGImage:(CGImageRef)img
{
	CGImage *g = (CGImage *)img;
	unsigned char * planes[1];

	if (!img)
		[NSException raise: NSInvalidArgumentException format: @"no image"];

	_cgImage = img;
	planes[0] = ((CGImage *)img)->idata;

	return [self initWithBitmapDataPlanes: planes
				 pixelsWide: g->width
				 pixelsHigh: g->height
				 bitsPerSample: g->bitsPerComponent
				 samplesPerPixel: g->samplesPerPixel
				 hasAlpha: (g->samplesPerPixel > 3)
				 isPlanar: NO
				 colorSpaceName: (NSString *)CGColorSpaceCopyName(g->colorspace)
				 bytesPerRow: g->bytesPerRow
				 bitsPerPixel: g->bitsPerPixel];
}

- (CGImageRef) CGImage
{
	if (!_cgImage)
		{
		int w = _pixelsWide;
		int h = _pixelsHigh;
		size_t bPS = _irep.bitsPerSample;		// bits in each color component
		size_t bPP = _brep.bitsPerPixel;		// bits in a pixel

		_cgImage = CGImageCreate( w, h, bPS, bPP, 0, NULL, 0, NULL, NULL, 0, 0);
		((CGImage *)_cgImage)->idata = [self bitmapData];
		((CGImage *)_cgImage)->samplesPerPixel = _brep.samplesPerPixel;
		}

	return _cgImage;
}

- (void) dealloc
{
	if (_imagePlanes)
		free(_imagePlanes),			_imagePlanes = NULL;
	[_imageData release],			_imageData = nil;
	CGImageRelease(_cgImage), 		_cgImage = NULL;

	[super dealloc];
}

- (id) copy
{
	NSBitmapImageRep *copy = (NSBitmapImageRep*)[super copy];

	copy->_bytesPerRow = _bytesPerRow;
	copy->_brep = _brep;
	copy->_imageData = [_imageData copy];
	copy->_brep.cached = NO;
	copy->_cgImage = NULL;

	return copy;
}

- (int) bitsPerPixel			{ return _brep.bitsPerPixel; }
- (int) samplesPerPixel			{ return _brep.samplesPerPixel; }
- (int) numberOfPlanes			{ return _brep.isPlanar ? _brep.samplesPerPixel : 1; }
- (int) bytesPerPlane			{ return _bytesPerRow * _pixelsHigh; }
- (int) bytesPerRow				{ return _bytesPerRow; }
- (BOOL) isPlanar				{ return _brep.isPlanar; }

- (BOOL) draw
{
	return [self drawInRect:(NSRect){{0,0}, _size}];
}

- (BOOL) drawAtPoint:(NSPoint)p
{
	return [self drawInRect:(NSRect){p, _size}];
}

- (BOOL) drawInRect:(NSRect)r
{
	CGImage s = {0};

	if (NSWidth(r) <= 0 || NSHeight(r) <= 0)
		return NO;								// rect is not visible		

	s.width = (size_t)_size.width;
	s.height = (size_t)_size.height;
	s.idata = [self bitmapData];
	s.samplesPerPixel = _brep.samplesPerPixel;
	s.bytesPerRow = s.width * _brep.samplesPerPixel;
	s.size = s.height * s.bytesPerRow;
	s._f.cache = YES;
	s.cimage = _cgImage;

	CGContextDrawImage(CONTEXT, r, &s);

	_cgImage = s.cimage;
	_brep.cached = s.cimage != NULL;
	_irep.isOpaque = s._f.isOpaque;

	return YES;
}

- (unsigned char *) bitmapData				// NeXT RGBA tiffs are not planar
{											// which means _imagePlanes[0]
	if (!_imagePlanes || !_imagePlanes[0])	// points at all of _imageData
		{
		int i, planeSize = (_bytesPerRow * _pixelsHigh);
		long length = _brep.samplesPerPixel * planeSize * sizeof(unsigned char);

		_imagePlanes = calloc(MAX_PLANES, sizeof(unsigned char*));
		_imageData = [[NSMutableData dataWithLength: length] retain];
		_imagePlanes[0] = (char *)[_imageData bytes];

		if (_brep.isPlanar) 
			for (i = 1; i < _brep.samplesPerPixel; i++) 
				_imagePlanes[i] = _imagePlanes[0] + (i * planeSize);
		}									

	return _imagePlanes[0];
}

- (void) getBitmapDataPlanes:(unsigned char **)data
{
	int i;

	if (!_imagePlanes || !_imagePlanes[0])
		[self bitmapData];

	if (data)
		{
		if (!_brep.isPlanar)
			data[0] = _imagePlanes[0];
		else
			for (i = 0; i < _brep.samplesPerPixel; i++)
				data[i] = _imagePlanes[i];
		}
}

@end  /* NSBitmapImageRep */


#ifndef FB_GRAPHICS  /* *********************************** XRBitmapImageRep */

/* ****************************************************************************

	XR BitmapImageRep

** ***************************************************************************/

@implementation NSBitmapImageRep (XRBitmapImageRep)

- (XImage *) xImage
{
	if (!_cgImage)
		{
		CGSize z = (CGSize){_pixelsWide, _pixelsHigh};
		unsigned int row, col;
		unsigned char *bData;
		XImage *ximage;

		_cgImage = _CGContextCreateImage(CONTEXT, z);
		ximage = ((XImage *)((CGImage *)_cgImage)->ximage);

		bData = [self bitmapData];
		for (row = 0; row < _pixelsHigh; row++)
			for (col = 0; col < _pixelsWide; col++)
				{
				unsigned long pixel;
				unsigned char r = *bData++;
				unsigned char g = *bData++;
				unsigned char b = *bData++;

				pixel = ((r << 16) & 0xff0000) + ((g << 8) & 0xff00) + b;
				XPutPixel(ximage, col, row, pixel);
				}
		}

	return (_cgImage) ? (XImage *)((CGImage *)_cgImage)->ximage : NULL;
}

- (Pixmap) xPixmapMask
{
	CGImage ci = {0};

	ci.width = _size.width;
	ci.height = _size.height;
	ci.idata = [(NSBitmapImageRep *)self bitmapData];
	ci.samplesPerPixel = _brep.samplesPerPixel;

	return XRCreatePixmapMask(CONTEXT, &ci);
}

- (Pixmap) xPixmapBitmap
{
	CGImage ci = {0};

	ci.width = _size.width;
	ci.height = _size.height;
	ci.idata = [(NSBitmapImageRep *)self bitmapData];
	ci.samplesPerPixel = _brep.samplesPerPixel;

	return XRCreatePixmapBitPlane(CONTEXT, &ci);
}

@end  /* NSBitmapImageRep (XRBitmapImageRep) */

#endif  /* !FB_GRAPHICS */
