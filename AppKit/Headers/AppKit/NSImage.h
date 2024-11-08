/*
   NSImage.h

   Image container class

   Copyright (C) 1999 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:	April 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSImage
#define _mGSTEP_H_NSImage

#include <Foundation/NSBundle.h>
#include <AppKit/NSBitmapImageRep.h>
#include <AppKit/NSGraphics.h>

@class NSString;
@class NSData;
@class NSPasteboard;
@class NSImageRep;
@class NSColor;
@class NSView;
@class NSMutableArray;


@interface NSImage : NSObject  <NSCoding>
{
	NSString *_name;
	NSString *_imageFilePath;
	NSMutableArray *_reps;
	NSImageRep *_bestRep;
	NSImageRep *_highlightedRep;
	NSImageRep *_plusLRep;
	NSColor *_color;
	NSSize _size;
	id _delegate;

	struct __imageFlags {
		unsigned int scalable:1;
		unsigned int uniqueWindow:1;
		unsigned int sizeWasExplicitlySet:1;
		unsigned int prefersColorMatch:1;
		unsigned int multipleResolutionMatching:1;
		unsigned int subImage:1;
		unsigned int isValid:1;
		unsigned int hasCustomRep:1;
		unsigned int reserved:24;
	} _img;
}

+ (id) imageNamed:(NSString*)name;

+ (NSArray*) imageTypes;
+ (NSArray*) imageUnfilteredTypes;

+ (BOOL) canInitWithPasteboard:(NSPasteboard*)pasteboard;

- (id) initByReferencingFile:(NSString*)filename;
- (id) initWithContentsOfFile:(NSString*)filename;
- (id) initWithData:(NSData*)data;
- (id) initWithPasteboard:(NSPasteboard*)pasteboard;
- (id) initWithSize:(NSSize)aSize;

- (void) unlockFocus;
- (void) lockFocus;

- (void) setSize:(NSSize)aSize;
- (NSSize) size;

- (BOOL) setName:(NSString*)name;
- (NSString*) name;

- (void) drawInRect:(NSRect)dst								// Draw the Image
		   fromRect:(NSRect)src
		   operation:(NSCompositingOperation)op
		   fraction:(float)alpha;

- (void) drawAtPoint:(NSPoint)dst
			fromRect:(NSRect)src
			operation:(NSCompositingOperation)op
			fraction:(float)alpha;

- (void) drawInRect:(NSRect)rect;
- (BOOL) drawRepresentation:(NSImageRep *)imageRep inRect:(NSRect)aRect;

- (BOOL) prefersColorMatch;
- (BOOL) matchesOnMultipleResolution;
- (void) setPrefersColorMatch:(BOOL)flag;
- (void) setMatchesOnMultipleResolution:(BOOL)flag;

- (void) addRepresentation:(NSImageRep*)imageRep;			// Representations
- (void) addRepresentations:(NSArray*)imageRepArray;
- (void) removeRepresentation:(NSImageRep*)imageRep;
- (NSArray*) representations;

- (BOOL) isValid;
- (void) recache;
- (void) setBackgroundColor:(NSColor*)aColor;
- (NSColor*) backgroundColor;

- (NSData*) TIFFRepresentation;								// Producing a TIFF
- (NSData*) TIFFRepresentationUsingCompression:(NSTIFFCompression)comp
										factor:(float)aFloat;
- (void) setDelegate:(id)anObject;							// Set the Delegate
- (id) delegate;

@end


@interface NSImage  (OSXDeprecated)

- (BOOL) scalesWhenResized;
- (void) setScalesWhenResized:(BOOL)flag;

- (NSImageRep*) bestRepresentationForDevice:(NSDictionary*)deviceDescription;

- (void) lockFocusOnRepresentation:(NSImageRep *)imageRepresentation;

- (void) compositeToPoint:(NSPoint)aPoint					// Draw the Image
				operation:(NSCompositingOperation)op;
- (void) compositeToPoint:(NSPoint)aPoint
				 fromRect:(NSRect)aRect
				 operation:(NSCompositingOperation)op;

- (void) dissolveToPoint:(NSPoint)dstPoint fraction:(float)alpha;
- (void) dissolveToPoint:(NSPoint)aPoint
				fromRect:(NSRect)aRect
				fraction:(float)alpha;
@end


@interface NSObject (NSImageDelegate)						// Implemented by
															// the delegate
- (NSImage*) imageDidNotDraw:(id)sender inRect:(NSRect)aRect;

@end


@interface NSBundle (NSImageAdditions) 

- (NSString*) pathForImageResource:(NSString*)name;

@end

#endif /* _mGSTEP_H_NSImage */
