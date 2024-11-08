/*
   NSImage.m

   Load, manipulate and display images

   Copyright (C) 1996 Free Software Foundation, Inc.

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSEnumerator.h>

#include <CoreGraphics/CoreGraphics.h>
#include <CoreGraphics/Private/PSOperators.h>

#include <AppKit/NSImage.h>
#include <AppKit/NSBitmapImageRep.h>
#include <AppKit/NSCachedImageRep.h>
#include <AppKit/NSCustomImageRep.h>
#include <AppKit/NSView.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSColor.h>


#define CONTEXT		((CGContextRef)_CGContext())
#define GSTATE   	((CGContext *) _CGContext())->_gs
#define FOCUS_VIEW	((CGContext *) _CGContext())->_gs->focusView
#define ISFLIPPED	((CGContext *) _CGContext())->_gs->isFlipped


// Class variables 
static NSMutableDictionary *__nameToImage = nil;
static NSBundle *__mainBundle = nil;
static NSBundle *__systemBundle = nil;
static NSDictionary *__currentDevice = nil;
//static NSDictionary *__printerDevice = nil;
//static NSDictionary *__screenDevice = nil;


@implementation NSImage

+ (void) initialize
{
	__nameToImage = [[NSMutableDictionary alloc] initWithCapacity: 10];
	__mainBundle = [NSBundle mainBundle];
	__systemBundle = [NSBundle systemBundle];
	[NSBitmapImageRep class];							// load class
}

+ (id) imageNamed:(NSString*)aName
{
	NSImage *image;

	if (!(image = [__nameToImage objectForKey:aName]))
		{												// if image is not yet  
		NSString *n, *p = nil;							// in the name to image
		NSString *ext = [aName pathExtension];			// dict search for it
		NSArray *array = [NSImageRep imageFileTypes];

		DBLog(@"loading image named %@", aName);		// Determine if name
														// has a supported ext 
		if ([ext length] && [array indexOfObject: ext] != NSNotFound)
			{
			n = [aName stringByDeletingPathExtension];	// has a supported ext
			p = [__mainBundle pathForResource:n ofType:ext];
			}
		else											// name does not have a
			{											// supported ext
			id o, e = [array objectEnumerator];

			n = aName;									// search for the image
			while ((o = [e nextObject]))				// locally (mainBundle)
				if ((p = [__mainBundle pathForResource:n ofType:o]))
					break;
			ext = nil;
			}

		if (!p)											// If not found search 
			{											// for image in system
			NSBundle *s = __systemBundle;
			NSString *sub = @"AppKit/Images";			// Path relative to
														// MGSTEP_ROOT System 
			if (ext)									// Resources directory
				p = [s pathForResource:n ofType:ext inDirectory:sub];
			else 
				{
				id o, e = [array objectEnumerator];

				while ((o = [e nextObject]))
					if ((p = [s pathForResource:n ofType:o inDirectory:sub]))
					 	break;
			}	}

		if (p && (image = [[NSImage alloc] initWithSize: NSZeroSize]))
			{
			image->_imageFilePath = [p retain];
			[image setName:aName];
		}	}

	return image;
}

+ (NSArray*) imageTypes
{
	return [NSImageRep imageFileTypes];
}

+ (NSArray*) imageUnfilteredTypes
{
	return [NSBitmapImageRep imageUnfilteredFileTypes];
}

+ (BOOL) canInitWithPasteboard:(NSPasteboard*)pasteboard
{														// FIX ME: Implement
	NSArray *array = [NSImageRep registeredImageRepClasses];
	int i, count = [array count];

	for (i = 0; i < count; i++)
		if ([[array objectAtIndex: i] canInitWithPasteboard: pasteboard])
			return YES;

	return NO;
}

- (id) init
{
	return [self initWithSize: NSZeroSize];
}

- (id) initWithSize:(NSSize)s								// Designated init
{
	if (s.width > 0 && s.height > 0)
		{
		_size = s;
		_img.sizeWasExplicitlySet = YES;
		}
	_img.prefersColorMatch = YES;
	_img.multipleResolutionMatching = YES;
	_reps = [NSMutableArray new];

	return self;
}

- (id) initByReferencingFile:(NSString*)fileName
{
	NSString *e = [fileName pathExtension];

	if (!e || ([[NSImageRep imageFileTypes] indexOfObject:e] == NSNotFound))
		return _NSInitError(self, @"invalid file extension %@", e);

	[self initWithSize: NSZeroSize];
	_imageFilePath = [fileName retain];

	return self;
}

- (id) initWithContentsOfFile:(NSString*)fileName
{
	if (!fileName)
		return _NSInitError(self, @"missing file path");

	if ((self = [self initWithSize: NSZeroSize]))
		{
		_imageFilePath = [fileName retain];

		if (![self isValid])
			return _NSInitError(self, @"invalid file path %@", fileName);
		}

	return self;
}

- (id) initWithData:(NSData*)data
{
	Class cls;

	[self initWithSize: NSZeroSize];

	if ((cls = [NSImageRep imageRepClassForData: data]))
		{
		NSArray *array = nil;
		NSImageRep *image = nil;

		if ([(id)cls respondsToSelector: @selector(imageRepsWithData:)])
			{
			if ((array = [cls imageRepsWithData: data]))
				[self addRepresentations: array];
			}
		else if ((image = [cls imageRepWithData: data]))
			[self addRepresentation: image];

		if (image || array)
			return self;
		}

	[self release];

	return nil;
}

- (id) initWithPasteboard:(NSPasteboard*)pasteboard		{ return NIMP }

- (void) dealloc
{									// Make sure we don't remove name from the
	[_reps release];				// _nameDict if we are just a copy of the 
									// named image, and not the original image 
	if (_name && self == [__nameToImage objectForKey: _name]) 
		[__nameToImage removeObjectForKey:_name];
	[_name release];

	[super dealloc];
}

- (id) copy
{
	NSImage *copy = (NSImage*) NSCopyObject(self);
	
	copy->_name = [_name retain];
	copy->_reps = [NSMutableArray new];
	copy->_color = [_color retain];

	if(_img.isValid)
		{
		[copy->_reps addObject: [[_reps objectAtIndex: 0] copy]];
		copy->_img.isValid = YES;
		copy->_bestRep = nil;
		copy->_plusLRep = nil;
		copy->_highlightedRep = nil;
		}

	return copy;
}

- (void) unlockFocus
{
	GSTATE->imageRep = nil;
	GSTATE->image = nil;
	if (_img.uniqueWindow)
		{
		ISFLIPPED = NO;
		[FOCUS_VIEW unlockFocus];
		}
}

- (void) lockFocus
{
	if (!_bestRep)
		{
		if (_imageFilePath)
			_bestRep = [self bestRepresentationForDevice:nil];
		else
			{
			if (!_size.width || !_size.height)
				[NSException raise:NSImageCacheException
							 format:@"NSImageCache size not specified\n"];
	
			_bestRep = [[NSCachedImageRep alloc] initWithWindow:nil 
												 rect:(NSRect){{0,0}, _size}];
			_img.uniqueWindow = YES;
			}

		if (_bestRep)
			[_reps addObject: _bestRep];
		else
			NSLog(@"Error loading image rep %@ ", [self description]);
		}

	if (_bestRep)
		[self lockFocusOnRepresentation:_bestRep];
}

- (void) setMatchesOnMultipleResolution:(BOOL)flag
{
	_img.multipleResolutionMatching = flag;
}

- (BOOL) matchesOnMultipleResolution	
{ 
	return _img.multipleResolutionMatching;
}

- (void) recache
{															// FIX ME to spec ?
	int i = [_reps count];

	while (i-- > 0) 
		{
		NSImageRep *rp = [_reps objectAtIndex: i];

		if (rp != _highlightedRep && rp != _plusLRep)
			[_reps replaceObjectAtIndex:i withObject:[rp copy]];
		else
			[_reps removeObjectAtIndex:i];
		}
	_bestRep = _highlightedRep = _plusLRep = nil;
}

- (BOOL) setName:(NSString*)string
{
	if (!string || [__nameToImage objectForKey: string])
		return NO;
	
	ASSIGN(_name, string);
	[__nameToImage setObject:self forKey:_name];

	return YES;
}

- (NSString*) name							{ return _name; }
- (void) setPrefersColorMatch:(BOOL)flag	{ _img.prefersColorMatch = flag; }
- (BOOL) prefersColorMatch					{ return _img.prefersColorMatch; }
- (void) setBackgroundColor:(NSColor*)color	{ ASSIGN(_color, color); }
- (NSColor*) backgroundColor				{ return _color; }
- (NSArray*) representations				{ return (NSArray*)_reps; }
- (void) setDelegate:anObject				{ _delegate = anObject; }
- (id) delegate								{ return _delegate; }

- (void) setSize:(NSSize)aSize
{
	_size = aSize;
	_img.sizeWasExplicitlySet = (aSize.width && aSize.height) ? YES : NO;
}

- (NSSize) size
{
	if (!_img.sizeWasExplicitlySet && _size.width == 0) 
		_size = [[self bestRepresentationForDevice: nil] size];

	return _size;
}

- (void) drawAtPoint:(NSPoint)dstPoint
			fromRect:(NSRect)srcRect
			operation:(NSCompositingOperation)op
			fraction:(float)alpha
{
	if (srcRect.size.width > 0 && srcRect.size.height > 0)
		[self drawInRect: (NSRect){dstPoint, srcRect.size}
			  fromRect:  srcRect
			  operation: op
			  fraction:  alpha];
}

- (void) drawInRect:(NSRect)dr
		   fromRect:(NSRect)srcRect
		   operation:(NSCompositingOperation)op
		   fraction:(float)alpha					// FIX ME incomplete !!!
{
	CGImage s = {0};
	CGImageRef p = &s;
	CGBlendMode mode = (CGBlendMode)op;

	if (!_bestRep && GSTATE->imageRep)
		_bestRep = GSTATE->imageRep;
	if (!_bestRep)
		_bestRep = [self bestRepresentationForDevice: nil];

///	[self lockFocusOnRepresentation:_bestRep];
	CGContextSaveGState(CONTEXT);

	CGContextSetAlpha(CONTEXT, alpha);

	if (_color && [_color alphaComponent] > 0)	// background color is visible
		{										// where image is transparent
		[_color setFill];						// default is clearColor 0/0
		NSRectFill(dr);
		}

	if (_img.hasCustomRep)
		{
		CGContextSetBlendMode(CONTEXT, mode);
		GSTATE->xCanvas.origin.x += dr.origin.x;	// CGContextTranslateCTM()
		GSTATE->xCanvas.origin.y += dr.origin.y;
		[_bestRep drawInRect: dr];
		CGContextRestoreGState(CONTEXT);
		return;
		}

	s.samplesPerPixel = [(NSBitmapImageRep*)_bestRep samplesPerPixel];
	s.width = _size.width;
	s.height = _size.height;
	s.bytesPerRow = s.width * s.samplesPerPixel;
	s.size = s.width * s.height * s.samplesPerPixel;
	s.idata = [(NSBitmapImageRep*)_bestRep bitmapData];

///	if (mode == kCGBlendModeNormal && s.samplesPerPixel == 3)
	if (s.samplesPerPixel == 3)
		mode = kCGBlendModeCopy;						// no src Alpha
	CGContextSetBlendMode(CONTEXT, mode);

	if (srcRect.origin.x > 0 || srcRect.origin.y > 0)
		p = CGImageCreateWithImageInRect(p, srcRect);
	CGContextDrawImage(CONTEXT, dr, p);

///	[self unlockFocus];
	CGContextRestoreGState(CONTEXT);

	if (p != &s)
		CGImageRelease(p);
}

- (void) drawInRect:(NSRect)rect
{
	[self drawInRect: rect
		  fromRect:  (NSRect){NSZeroPoint, rect.size}
		  operation: NSCompositeSourceOver
		  fraction:  1.0];
}

- (BOOL) drawRepresentation:(NSImageRep*)imageRep inRect:(NSRect)rect
{
	if (!_img.scalable)
		{
		if ([imageRep drawAtPoint: rect.origin])
			return YES;

		rect.size = _size;
		}
	else
		if ([imageRep drawInRect: rect])
			return YES;

	if ([_delegate respondsToSelector:@selector(imageDidNotDraw:inRect:)])
		{
		NSImage *a;

		if ((a = [_delegate imageDidNotDraw:self inRect:rect]))
			{
			NSImageRep *rp = [a bestRepresentationForDevice: nil];

			return [a drawRepresentation:rp inRect:rect];
		}	}

	return NO;
}

- (void) addRepresentation:(NSImageRep *)imageRep
{
	[_reps addObject:imageRep];
	
	if ([imageRep isKindOfClass: [NSCustomImageRep class]])
		_img.hasCustomRep = YES;
}

- (void) addRepresentations:(NSArray *)imageRepArray
{
	if (imageRepArray)
		[_reps addObjectsFromArray:imageRepArray];
}

- (void) removeRepresentation:(NSImageRep *)imageRep
{
	if (imageRep == _bestRep)
		_bestRep = nil;
	if (imageRep == _highlightedRep)
		_highlightedRep = nil;
	else if (imageRep == _plusLRep)
		_plusLRep = nil;

	[_reps removeObjectIdenticalTo: imageRep];
}

- (BOOL) isValid
{														 
	if (!_img.isValid)
		{
		if (_imageFilePath)
			{
			NSArray *a;

			if ((a = [NSImageRep imageRepsWithContentsOfFile:_imageFilePath]))
				{
				[self addRepresentations: a];
				_img.isValid = YES;
			}	}
		else if ([_reps count])
			_img.isValid = YES;
		}

	return _img.isValid;
}

- (NSData*) TIFFRepresentation
{
	if (_bestRep || (_bestRep = [self bestRepresentationForDevice: nil]))
		if ([_bestRep isKindOfClass: [NSBitmapImageRep class]])
			return [(NSBitmapImageRep *)_bestRep TIFFRepresentation];

	return nil;
}

- (NSData*) TIFFRepresentationUsingCompression:(NSTIFFCompression)cs
										factor:(float)fx
{
	NSBitmapImageRep *b = nil;

	if (_bestRep || (_bestRep = [self bestRepresentationForDevice: nil]))
		if ([_bestRep isKindOfClass: [NSBitmapImageRep class]])
			b = (NSBitmapImageRep *)_bestRep;

	return [b TIFFRepresentationUsingCompression: cs factor: fx];
}

- (id) awakeAfterUsingCoder:(NSCoder*)aDecoder
{
	if (_name && [__nameToImage objectForKey:_name]) 
		return [__nameToImage objectForKey:_name];
    
	return self;
}

- (void) encodeWithCoder:(NSCoder*)coder		{}		// NSCoding Protocol
- (id) initWithCoder:(NSCoder*)coder			{ return self; }

@end


@implementation NSImage  (OSXDeprecated)

- (BOOL) scalesWhenResized						{ return _img.scalable; }
- (void) setScalesWhenResized:(BOOL)flag		{ _img.scalable = flag; }

- (NSImageRep*) bestRepresentationForDevice:(NSDictionary*)devDescription
{
	int i;

	if ((devDescription == __currentDevice) && _bestRep)
		return _bestRep;

	__currentDevice = devDescription;
//	if(__currentDevice == __printerDevice)			// FIX ME determine best
													// rep based on device dict
	if (!_img.isValid)
		[self isValid];								// Make sure we have the
													// image reps loaded in
	for (i = [_reps count]; i-- > 0;)
		{
		_bestRep = [_reps objectAtIndex:i];

		if (!_img.sizeWasExplicitlySet) 
			_size = [_bestRep size];

		return _bestRep;
		}

	return nil;
}

- (void) lockFocusOnRepresentation:(NSImageRep *)imageRep
{
	if (imageRep && [_reps containsObject:imageRep])
		_bestRep = imageRep;
	else
		{
		[self lockFocus];
		return;
		}

	GSTATE->imageRep = _bestRep;
	GSTATE->image = self;

	if (_img.uniqueWindow)
		{
		[[[(NSCachedImageRep*)_bestRep window] contentView] lockFocus];
		ISFLIPPED = YES;
		}
}

- (void) compositeToPoint:(NSPoint)p operation:(NSCompositingOperation)op
{
	NSImageRep *rep;

	if (!_bestRep)
		_bestRep = [self bestRepresentationForDevice: nil];

	switch (op)
		{
		case NSCompositeHighlight:
			if (!(rep = _highlightedRep))
				[_reps addObject:(rep = _highlightedRep = [_bestRep copy])];
			break;
		case NSCompositePlusLighter:
			if (!(rep = _plusLRep))
				[_reps addObject:(rep = _plusLRep = [_bestRep copy])];
			break;
		default:
			rep = _bestRep;
			break;
		}

	[self lockFocusOnRepresentation:rep];
//	PScomposite(0, 0, _size.width, _size.height, 0, p.x, p.y, op);
	[self drawAtPoint:p fromRect:(NSRect){{0,0}, _size} operation:op fraction:1.0];
	[self unlockFocus];
}

- (void) compositeToPoint:(NSPoint)p
				 fromRect:(NSRect)r
				 operation:(NSCompositingOperation)op
{
	NSImageRep *rep;
	float y;

	if (!_bestRep)
		_bestRep = [self bestRepresentationForDevice: nil];

	switch(op)
		{
		case NSCompositeHighlight:
			if (!(rep = _highlightedRep))
				[_reps addObject:(rep = _highlightedRep = [_bestRep copy])];
			break;
		case NSCompositePlusLighter:
			if(!(rep = _plusLRep))
				[_reps addObject:(rep = _plusLRep = [_bestRep copy])];
			break;
		default:
			rep = _bestRep;
			break;
		}

	if (!_img.scalable)
		{
		y = _size.height >= (y = NSMaxY(r)) ? _size.height - y : NSMinY(r);

		if (NSWidth(r) > _size.width - r.origin.x)
			NSWidth(r) = _size.width - r.origin.x;
		if (NSHeight(r) > _size.height - r.origin.y)
			NSHeight(r) = _size.height - r.origin.y;
		}
	else
		y = NSMinY(r);

	[self lockFocusOnRepresentation:rep];
//	PScomposite(NSMinX(r), y, NSWidth(r), NSHeight(r), 0, p.x, p.y, op);
	[self drawAtPoint:p fromRect:(NSRect){{NSMinX(r), y}, r.size} operation:op fraction:1.0];
	[self unlockFocus];
}

- (void) dissolveToPoint:(NSPoint)p fraction:(float)delta
{
	[self dissolveToPoint:p fromRect:(NSRect){{0,0},_size} fraction:delta];
}

- (void) dissolveToPoint:(NSPoint)p fromRect:(NSRect)r fraction:(float)f
{
	NSImageRep *rep;

	if (!_bestRep)
		rep = _bestRep = [self bestRepresentationForDevice: nil];

	if (!(rep = _plusLRep))
		[_reps addObject:(rep = _plusLRep = [_bestRep copy])];

	[self lockFocusOnRepresentation:rep];
	[self drawAtPoint:p fromRect:r operation:NSCompositeSourceOver fraction:f];
	[self unlockFocus];
}

@end  /* NSImage (OSXDeprecated) */
