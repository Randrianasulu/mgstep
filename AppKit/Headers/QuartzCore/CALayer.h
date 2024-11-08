/*
   CALayer.h

   Graphics drawing layer

   Copyright (C) 2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    May 2020

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CALayer
#define _mGSTEP_H_CALayer

#include <Foundation/NSObject.h>
#include <CoreGraphics/CoreGraphics.h>
#include <QuartzCore/CAMediaTiming.h>
#include <QuartzCore/CAAnimation.h>
#include <QuartzCore/CATransform3D.h>

@class NSArray;
@class NSMutableArray;
@class NSMutableDictionary;


enum CAAutoresizingMask
{
	kCALayerNotSizable	  = 0,
	kCALayerMinXMargin	  = (1 << 0),
	kCALayerWidthSizable  = (1 << 1),
	kCALayerMaxXMargin	  = (1 << 2),
	kCALayerMinYMargin    = (1 << 3),
	kCALayerHeightSizable = (1 << 4),
	kCALayerMaxYMargin    = (1 << 5)
};


@interface CALayer : NSObject  // <NSCoding, CAMediaTiming>
{
	NSString *_name;							// name used by layout manager
	id _layoutManager;							// applies frame rects to subs

	id _contents;								// CGImage contents of layer
	CGLayerRef _layer;							// alternate CGLayer contents

	CALayer *_mask;
	CALayer *_superlayer;

	NSMutableArray *_constraints;
	NSMutableArray *_sublayers;

	NSMutableDictionary *_actions;
	NSMutableDictionary *_animations;

    id _delegate;
									// normalized achor point for bounds rect
	CGPoint _anchorPoint;			// {0,0} bottom left to {1,1} top right
	CGRect _bounds;
	CGFloat _zPosition;				// Z axis positioning in superlayer
	CGPoint _position;				// position in superlayer that anchor point
									// of bounds rect is aligned to
	CGFloat _shadowOpacity;
	CGFloat _shadowRadius;

	CGFloat _borderWidth;
	CGColorRef _borderColor;

	CATransform3D _transform;
	CATransform3D _sublayerTransform;			// applied to sublayers while
												// rendering content
    struct _LayerFlags {
		unsigned int drawLayer:1;
		unsigned int displayLayer:1;
		unsigned int needsDisplay:1;
		unsigned int doubleSided:1;
		unsigned int geometryFlipped:1;
		unsigned int hidden:1;
		unsigned int opaque:1;
		unsigned int masksToBounds:1;
		unsigned int reserved:24;
	} _f;
}

+ (id) layer;

+ (id) defaultValueForKey:(NSString *)key;
+ (BOOL) needsDisplayForKey:(NSString *)key;

- (id) init;
- (id) initWithLayer:(id)layer;

- (void) display;

- (void) drawInContext:(CGContextRef)cx;

- (void) setNeedsDisplay;
- (void) setNeedsDisplayInRect:(CGRect)rect;

- (id) presentationLayer;
- (id) modelLayer;

- (id) contents;
- (void) setContents:(id)cgimage;
// CGRect contentsRect;
// NSString *contentsGravity;
// CGFloat contentsScale;
// CGRect contentsCenter;

- (id) layoutManager;
- (void) setLayoutManager:(id)manager;

- (NSString *) name;
- (void) setName:(NSString *)name;

- (void) addSublayer:(CALayer *)layer;
- (void) insertSublayer:(CALayer *)layer atIndex:(unsigned)i;
- (void) insertSublayer:(CALayer *)layer below:(CALayer *)other;
- (void) insertSublayer:(CALayer *)layer above:(CALayer *)other;

- (BOOL) isHidden;
- (BOOL) isOpaque;
- (BOOL) masksToBounds;
- (BOOL) isDoubleSided;
- (BOOL) isGeometryFlipped;

//- (BOOL) contentsAreFlipped;			// odd # of flipped layers up to root ?

- (void) setShadowOpacity:(CGFloat)opacity;
- (void) setShadowRadius:(CGFloat)radius;

- (void) setDelegate:(id)delegate;
- (id) delegate;

- (CGPoint) position;
- (CGPoint) anchorPoint;
- (CGRect) frame;
- (CGRect) bounds;

- (void) setBounds:(CGRect)rect;
- (void) setFrame:(CGRect)rect;
- (void) setPosition:(CGPoint)point;
- (void) setAnchorPoint:(CGPoint)point;

- (CGFloat) borderWidth;
- (void) setBorderWidth:(CGFloat)width;
- (void) setBorderColor:(CGColorRef)color;
- (CGColorRef) borderColor;

- (void) addAnimation:(CAAnimation *)anime forKey:(NSString *)key;
- (void) removeAnimationForKey:(NSString *)key;
- (void) removeAllAnimations;

- (CAAnimation *) animationForKey:(NSString *)key;
- (NSArray *) animationKeys;

@end


@protocol CAAction

- (void) runActionForKey:(NSString *)event
				  object:(id)object
			   arguments:(NSDictionary *)args;
@end


@interface NSObject (CALayerDelegate)

- (void) displayLayer:(CALayer *)layer;
- (void) drawLayer:(CALayer *)layer inContext:(CGContextRef)cx;
- (void) layoutSublayersOfLayer:(CALayer *)layer;

- (id <CAAction>) actionForLayer:(CALayer *)layer forKey:(NSString *)event;

@end


@interface CALayer (CAAction)

+ (id <CAAction>) defaultActionForKey:(NSString *)event;
- (id <CAAction>) actionForKey:(NSString *)event;

@end

#endif /* _mGSTEP_H_CALayer */
