/*
   NSGraphics.h

   Copyright (C) 1997-2020 Free Software Foundation, Inc.

   Author:	Ovidiu Predescu <ovidiu@net-community.com>
   Date:	February 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSGraphics
#define _mGSTEP_H_NSGraphics

#include <Foundation/NSObject.h>
#include <Foundation/NSGeometry.h>

#include <CoreGraphics/CGContext.h>

@class NSString;
@class NSColor;


typedef enum {
	NSCompositeSourceOver      = kCGBlendModeNormal,
	NSCompositeClear           = kCGBlendModeClear,
	NSCompositeCopy            = kCGBlendModeCopy,
	NSCompositeSourceIn	       = kCGBlendModeSourceIn,
	NSCompositeSourceOut       = kCGBlendModeSourceOut,
	NSCompositeSourceAtop      = kCGBlendModeSourceAtop,
	NSCompositeDestinationOver = kCGBlendModeDestinationOver,
	NSCompositeDestinationIn   = kCGBlendModeDestinationIn,
	NSCompositeDestinationOut  = kCGBlendModeDestinationOut,
	NSCompositeDestinationAtop = kCGBlendModeDestinationAtop,
	NSCompositeXOR	           = kCGBlendModeXOR,
	NSCompositePlusDarker      = kCGBlendModePlusDarker,
	NSCompositeHighlight       = kCGBlendModeDifference,
	NSCompositePlusLighter     = kCGBlendModePlusLighter
} NSCompositingOperation;


typedef enum {										// Focus ring drawing order
    NSFocusRingOnly  = 0,
    NSFocusRingBelow = 1,
    NSFocusRingAbove = 2
} NSFocusRingPlacement;

typedef enum {
    NSFocusRingTypeDefault  = 0,
    NSFocusRingTypeNone     = 1,
    NSFocusRingTypeExterior = 2
} NSFocusRingType;


extern NSString *NSCalibratedWhiteColorSpace;			// Colorspace Names
extern NSString *NSCalibratedBlackColorSpace;
extern NSString *NSCalibratedRGBColorSpace;
extern NSString *NSDeviceWhiteColorSpace;
extern NSString *NSDeviceBlackColorSpace;
extern NSString *NSDeviceRGBColorSpace;
extern NSString *NSDeviceCMYKColorSpace;
extern NSString *NSNamedColorSpace;
extern NSString *NSCustomColorSpace;

typedef int NSWindowDepth;

extern const float NSBlack;								// Gray Values
extern const float NSWhite;
extern const float NSDarkGray;
extern const float NSLightGray;

extern NSString *NSDeviceResolution;					// Device Dict Keys
extern NSString *NSDeviceColorSpaceName;
extern NSString *NSDeviceBitsPerSample;
extern NSString *NSDeviceIsScreen;
extern NSString *NSDeviceIsPrinter;
extern NSString *NSDeviceSize;


void NSEraseRect(NSRect r);							// Rect Draw Functions
void NSHighlightRect(NSRect r);

void NSRectClip(NSRect r);
void NSRectClipList(const NSRect *rects, int count);

void NSRectFill(NSRect r);
void NSRectFillList(const NSRect *rects, int count);
void NSRectFillListWithGrays(const NSRect *rects,const float *grays,int count);
void NSRectFillListWithColors(const NSRect *rects, NSColor **colors,int count);

void NSDrawButton(NSRect r, NSRect clipRect);
void NSDrawGroove(NSRect r, NSRect clipRect);
void NSDrawGrayBezel(NSRect r, NSRect clipRect);
void NSDrawWhiteBezel(NSRect r, NSRect clipRect);
void _NSImageFramePhoto(NSRect r, NSRect clipRect);
void NSFrameRect(NSRect r);
void NSFrameRectWithWidth(NSRect r, float frameWidth);

												// sides for NSDrawTiledRects()
#define BEZEL_EDGES_NORMAL  \
			((NSRectEdge[]){ NSMaxXEdge, NSMinYEdge, NSMinXEdge, NSMaxYEdge,\
							 NSMaxXEdge, NSMinYEdge, NSMinXEdge, NSMaxYEdge })
#define BEZEL_EDGES_FLIPPED  \
			((NSRectEdge[]){ NSMaxXEdge, NSMaxYEdge, NSMinXEdge, NSMinYEdge,\
							 NSMaxXEdge, NSMaxYEdge, NSMinXEdge, NSMinYEdge })
#define BUTTON_EDGES_NORMAL  \
					((NSRectEdge[]){ NSMaxXEdge, NSMinYEdge, NSMinXEdge,\
									 NSMaxYEdge, NSMaxXEdge, NSMinYEdge })
#define BUTTON_EDGES_FLIPPED  \
					((NSRectEdge[]){ NSMaxXEdge, NSMaxYEdge, NSMinXEdge,\
									 NSMinYEdge, NSMaxXEdge, NSMaxYEdge })

NSRect NSDrawTiledRects(NSRect boundsRect,				// Rect draw primitives
						NSRect clipRect, 
						const NSRectEdge *sides, 
						const float *grays, 
						int count);

NSRect NSDrawColorTiledRects( NSRect boundsRect,
							  NSRect clipRect,
							  const NSRectEdge *sides,
							  NSColor **colors,
							  int count);

void NSRectFillUsingOperation(NSRect r, NSCompositingOperation op);

void NSFrameRectWithWidthUsingOperation(NSRect r,
										float w,
										NSCompositingOperation op);

void NSRectFillListUsingOperation(const NSRect *rects,
								  int count,
								  NSCompositingOperation op);

void NSRectFillListWithColorsUsingOperation(const NSRect *rects,
											NSColor **colors,
											int num,
											NSCompositingOperation op);

const NSWindowDepth * NSAvailableWindowDepths(void);

NSWindowDepth NSBestDepth(NSString *colorSpace,
						  int bitsPerSample,
						  int bitsPerPixel, 
						  BOOL planar,
						  BOOL *exactMatch);

int NSNumberOfColorComponents(NSString *colorSpaceName);
int NSBitsPerPixelFromDepth(NSWindowDepth depth);
int NSBitsPerSampleFromDepth(NSWindowDepth depth);
NSString *NSColorSpaceFromDepth(NSWindowDepth depth);
BOOL NSPlanarFromDepth(NSWindowDepth depth);

//extern void NSSetFocusRingStyle(NSFocusRingPlacement placement);

void NSCopyBitmapFromGState(int srcGstate, NSRect srcRect, NSRect destRect);
void NSCopyBits(int srcGstate, NSRect srcRect, NSPoint destPoint);

void NSBeep(void);

#endif  /* _mGSTEP_H_NSGraphics */
