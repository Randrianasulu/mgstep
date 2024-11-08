/*
   NSRulerView.h

   View which delineates a scroll view's document

   Copyright (C) 1996-2017 Free Software Foundation, Inc.

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSRulerView
#define _mGSTEP_H_NSRulerView

#include <AppKit/NSView.h>

@class NSScrollView;
@class NSImage;


@interface NSRulerMarker : NSObject  <NSObject, NSCopying>

- (id) initWithRulerView:(NSRulerView *)aRulerView
		 markerLocation:(float)location
		 image:(NSImage *)anImage
		 imageOrigin:(NSPoint)imageOrigin; 

- (NSRulerView *) ruler;

- (void) setImage:(NSImage *)anImage;
- (NSImage *) image;

- (void) setImageOrigin:(NSPoint)aPoint;
- (NSPoint) imageOrigin;
- (NSRect) imageRectInRuler;
- (float) thicknessRequiredInRuler;

- (void) setMovable:(BOOL)flag;
- (BOOL) isMovable;
- (BOOL) isRemovable;
- (void) setRemovable:(BOOL)flag;

- (void) setMarkerLocation:(float)location;
- (float) makerLocation;

- (void) setRepresentedObject:(id <NSCopying>)anObject;
- (id <NSCopying>) representedObject;

- (void) drawRect:(NSRect)aRect;
- (BOOL) isDragging;
- (BOOL) trackMouse:(NSEvent *)event adding:(BOOL)flag;

- (id) copy;

@end


typedef enum {
	NSHorizontalRuler,
	NSVerticalRuler
} NSRulerOrientation;


@interface NSRulerView : NSView  <NSObject, NSCoding>

+ (void) registerUnitWithName:(NSString *)unitName
				 abbreviation:(NSString *)abbreviation
				 unitToPointsConversionFactor:(float)conversionFactor
				 stepUpCycle:(NSArray *)stepUpCycle
				 stepDownCycle:(NSArray *)stepDownCycle;

- (id) initWithScrollView:(NSScrollView *)sv orientation:(NSRulerOrientation)o;

- (void) setMeasurementUnits:(NSString *)unitName;
- (NSString *) measurementUnits;

- (void) setClientView:(NSView *)aView;
- (NSView *) clientView;

- (void) setAccessoryView:(NSView *)aView;
- (NSView *) accessoryView;

- (void) setOriginOffset:(float)offset;
- (float) originOffset;

- (NSArray *) markers;
- (void) setMarkers:(NSArray *)markers;
- (void) addMarker:(NSRulerMarker *)aMarker;
- (void) removeMarker:(NSRulerMarker *)aMarker;
- (BOOL) trackMarker:(NSRulerMarker *)aMarker withMouseEvent:(NSEvent *)event;

- (void) moveRulerlineFromLocation:(float)oldLoc toLocation:(float)newLoc;

- (void) drawHashMarksAndLabelsInRect:(NSRect)aRect;
- (void) drawMarkersInRect:(NSRect)aRect;
- (void) invalidateHashMarks;

- (void) setScrollView:(NSScrollView *)scrollView;
- (NSScrollView *) scrollView;

- (void) setOrientation:(NSRulerOrientation)orientation;
- (NSRulerOrientation) orientation;
- (void) setReservedThicknessForAccessoryView:(float)thickness;
- (float) reservedThicknessForAccessoryView;
- (void) setReservedThicknessForMarkers:(float)thickness;
- (float) reservedThicknessForMarkers;
- (void) setRuleThickness:(float)thickness;
- (float) ruleThickness;
- (float) requiredThickness;
- (float) baselineLocation;
- (BOOL) isFlipped;

- (void) rulerView:(NSRulerView *)rv didAddMarker:(NSRulerMarker *)m;
- (void) rulerView:(NSRulerView *)rv didMoveMarker:(NSRulerMarker *)m;
- (void) rulerView:(NSRulerView *)rv didRemoveMarker:(NSRulerMarker *)m;
- (void) rulerView:(NSRulerView *)rv handleMouseDown:(NSEvent *)event;
- (BOOL) rulerView:(NSRulerView *)rv shouldAddMarker:(NSRulerMarker *)m;
- (BOOL) rulerView:(NSRulerView *)rv shouldMoveMarker:(NSRulerMarker *)m;
- (BOOL) rulerView:(NSRulerView *)rv shouldRemoveMarker: (NSRulerMarker *)m;
- (float) rulerView:(NSRulerView *)rv
		  willAddMarker:(NSRulerMarker *)m
		  atLocation:(float)location;
- (float) rulerView:(NSRulerView *)rv
		  willMoveMarker:(NSRulerMarker *)m
		  toLocation:(float)location;
- (void) rulerView:(NSRulerView *)rv willSetClientView:(NSView *)newClient;

@end

#endif /* _mGSTEP_H_NSRulerView */
