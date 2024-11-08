/*
   CALayer.m

   Graphics drawing layer

   Copyright (C) 2006-2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    May 2020

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSGeometry.h>
#include <Foundation/NSNotification.h>

#include <QuartzCore/CALayer.h>
#include <QuartzCore/CATransaction.h>
#include <QuartzCore/CAConstraintLayoutManager.h>
#include <CoreGraphics/CoreGraphics.h>
#include <AppKit/NSView.h>


const CATransform3D CATransform3DIdentity = {1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1};



@interface CAConstraintLayoutManager  (PrivateLayout)

- (void) _applyLayerContraints:(CALayer *)sublayer;

@end


@implementation CALayer

+ (id) layer					{ return [[[self class] new] autorelease]; }

+ (id) defaultValueForKey:(NSString *)key		{ return NIMP; }
+ (BOOL) needsDisplayForKey:(NSString *)key		{ NIMP; return NO; }

- (id) init
{
	_transform = CATransform3DIdentity;
	_sublayerTransform = CATransform3DIdentity;
	_anchorPoint = (CGPoint){.5,.5};

	return self;
}

- (id) initWithLayer:(id)layer					{ return NIMP; }

- (void) dealloc
{
	[_sublayers release];
	[_animations release];
	[_actions release];
	[_constraints release];
	[_layoutManager release];
	CGImageRelease((CGImageRef)_contents);
	CGLayerRelease((CGLayerRef)_layer);
	[super dealloc];
}

- (void) display
{
	if (_f.displayLayer)
		[_delegate displayLayer:self];
	else
		{
		CGImageRef img;

		if (!_layer && !_contents)
			_layer = CGLayerCreateWithContext(_CGContext(), _bounds.size, NULL);

		if (!_contents)
			[self drawInContext: CGLayerGetContext(_layer)];

		[_delegate lockFocus];
		if (_contents)
			img = (CGImageRef)_contents;
		else
			img = ((CGContext *)_layer->context)->_bitmap;
		CGContextDrawImage(_CGContext(), (CGRect){_position, _bounds.size}, img);
///		CGContextDrawLayerAtPoint(cx, NSZeroPoint, _layer);
		if (_sublayers)
			[_sublayers makeObjectsPerformSelector:@selector(display)];
		[_delegate unlockFocus];
		}
}

- (void) drawInContext:(CGContextRef)cx
{
	if (_f.drawLayer)
		[_delegate drawLayer:self inContext:cx];
}

- (id) presentationLayer					{ return NIMP; }
- (id) modelLayer							{ return NIMP; }

- (id) contents								{ return _contents; }
- (void) setContents:(id)img				{ ASSIGN(_contents, img); }

- (id) layoutManager						{ return _layoutManager; }
- (void) setLayoutManager:(id)manager		{ ASSIGN(_layoutManager, manager); }

- (NSString *) name							{ return _name; }
- (void) setName:(NSString *)name			{ ASSIGN(_name, name); }
- (void) _setSuperlayer:(CALayer *)layer	{ _superlayer = layer; }

- (void) setSublayers:(NSArray *)sublayers
{
	ASSIGN(_sublayers, [NSMutableArray arrayWithArray: sublayers]);
	[_sublayers makeObjectsPerformSelector:@selector(_setSuperLayer:)
								withObject:self];
}

- (void) addSublayer:(CALayer *)layer
{
	if (!_sublayers)
		_sublayers = [NSMutableArray new];
	[_sublayers addObject:layer];
	[layer _setSuperlayer:self];
}

- (NSArray *) sublayers 					{ return [_sublayers copy]; }
- (CALayer *) superlayer					{ return _superlayer; }

- (void) insertSublayer:(CALayer *)layer atIndex:(unsigned)index
{
	[_sublayers insertObject:layer atIndex:index];
}

- (void) insertSublayer:(CALayer *)layer below:(CALayer *)other
{
	NSUInteger j = [_sublayers indexOfObjectIdenticalTo: other];

	[_sublayers insertObject:layer atIndex:MAX(0, j-1)];
}

- (void) insertSublayer:(CALayer *)layer above:(CALayer *)other
{
	NSUInteger count = [_sublayers count];
	NSUInteger j = [_sublayers indexOfObjectIdenticalTo: other];

	[_sublayers insertObject:layer atIndex:MIN(count, j+1)];
}

- (void) setNeedsDisplayInRect:(CGRect)rect
{
	_f.needsDisplay = YES;
//	_invalid = rect;		FIX ME how to define invalid CGLayer rect ?
}

- (void) setNeedsDisplay					{ _f.needsDisplay = YES; }
- (BOOL) needsDisplay						{ return _f.needsDisplay; }
- (BOOL) isHidden							{ return _f.hidden; }
- (BOOL) isOpaque							{ return _f.opaque; }
- (BOOL) masksToBounds						{ return _f.masksToBounds; }
- (BOOL) isDoubleSided						{ return _f.doubleSided; }
- (BOOL) isGeometryFlipped					{ return _f.geometryFlipped; }

//- (BOOL) contentsAreFlipped;			// odd # of flipped layers up to root ?

- (void) setOpaque:(BOOL)flag				{ _f.opaque = flag; }
- (void) setShadowOpacity:(CGFloat)opacity	{ _shadowOpacity = opacity; }
- (void) setShadowRadius:(CGFloat)radius	{ _shadowRadius = radius; }
- (id) delegate								{ return _delegate; }

- (void) _viewFrameChanged:(NSNotification*)aNotification
{
	NSUInteger i, count;

	[self setFrame: [_delegate frame]];

	if (_layer)
		{
		size_t w = _bounds.size.width;
		size_t h = _bounds.size.height;
		CGContextRef cx = ((CGLayer *)_layer)->context;

		((CGContext *)cx)->_bitmap = _CGImageResize(((CGContext *)cx)->_bitmap, w, h);
		((CGLayer *)_layer)->_size = _bounds.size;
		((CGContext *)cx)->_gs->xCanvas.size = _bounds.size;
		}

	if (_layoutManager && _sublayers)
		for (i = 0, count = [_sublayers count]; i < count; i++)
			[_layoutManager _applyLayerContraints: [_sublayers objectAtIndex:i]];
}

- (void) setDelegate:(id)delegate
{
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

	if (_delegate)
		[nc removeObserver: self
			name: NSViewFrameDidChangeNotification
			object:_delegate];

	[nc addObserver:self
		selector:@selector(_viewFrameChanged:)
		name:NSViewFrameDidChangeNotification 
		object:delegate];

	_delegate = delegate;
	_f.displayLayer = [_delegate respondsToSelector:@selector(displayLayer:)];
	_f.drawLayer = [_delegate respondsToSelector:@selector(drawLayer:inContext:)];
	[_delegate setPostsFrameChangedNotifications: YES];
}

- (void) setPosition:(CGPoint)point
{
	id action;

	if (![self animationForKey:@"position"] && ![CATransaction disableActions])
		if ((action = [self actionForKey:@"position"]) != nil)
			[self addAnimation:action forKey:@"position"];

	_position = point;
}

- (CGPoint) position						{ return _position; }
- (CGPoint) anchorPoint						{ return _anchorPoint; }
- (void) setAnchorPoint:(CGPoint)point		{ _anchorPoint = point; }

- (CGRect) bounds
{
	return NSInsetRect(_bounds, _borderWidth, _borderWidth);
}

- (void) setBounds:(CGRect)rect
{
	id action;

	if (![self animationForKey:@"bounds"] && ![CATransaction disableActions])
		if ((action = [self actionForKey:@"bounds"]) != nil)
			[self addAnimation:action forKey:@"bounds"];

	_bounds = rect;
}

- (CGRect) frame
{
	return (CGRect){_position, _bounds.size};
}

- (void) setFrame:(CGRect)rect
{
	[self setPosition: rect.origin];
	[self setBounds: (CGRect){_bounds.origin, rect.size}];
}

- (CGFloat) borderWidth						{ return _borderWidth; }
- (void) setBorderWidth:(CGFloat)width		{ _borderWidth = width; }
- (CGColorRef) borderColor					{ return _borderColor; }

- (void) setBorderColor:(CGColorRef)color
{
	if (color != _borderColor)
		{
		CGColorRelease(_borderColor);
		_borderColor = CGColorRetain(color);
		}
}

- (id) actions								{ return _actions; }

- (id <CAAction>) actionForKey:(NSString *)event
{
	return [_actions objectForKey:event];
}

- (void) addAnimation:(CAAnimation *)anime forKey:(NSString *)key
{
	[_animations setObject:anime forKey:key];
}

- (CAAnimation *) animationForKey:(NSString *)key
{
	return [_animations objectForKey:key];
}

- (NSArray *) animationKeys					{ return [_actions allKeys]; }
- (void) removeAllAnimations				{ [_animations removeAllObjects]; }
- (void) removeAnimationForKey:(NSString*)k { [_animations removeObjectForKey:k]; }

@end


NSString * const kCAFillModeForwards  = @"FillModeForwards";
NSString * const kCAFillModeBackwards = @"FillModeBackwards";
NSString * const kCAFillModeBoth      = @"FillModeBoth";
NSString * const kCAFillModeRemoved   = @"FillModeRemoved";


/* ****************************************************************************

	QuartzCore support for CALayer

** ***************************************************************************/

@implementation CAAnimation
@end

@implementation CATransaction

+ (BOOL) disableActions						{ return NO; }
+ (void) setDisableActions:(BOOL)flag		{ }

@end

static CGFloat
_CGContraintGetAttribute(CAConstraintAttribute a, CGRect r)
{
	switch (a)
		{
		case kCAConstraintMinX:		return NSMinX(r);
		case kCAConstraintMidX:		return NSMidX(r);
		case kCAConstraintMaxX:		return NSMaxX(r);
		case kCAConstraintWidth:	return NSWidth(r);
		case kCAConstraintMinY:		return NSMinY(r);
		case kCAConstraintMidY:		return NSMidY(r);
		case kCAConstraintMaxY:		return NSMaxY(r);
		case kCAConstraintHeight:	return NSHeight(r);
		}
}

static void
_CGContraintSetAttribute(CAConstraintAttribute a, CGRect *r, CGFloat v)
{
	switch (a)
		{
		case kCAConstraintMinX:  NSMinX(*r) = v;						 break;
		case kCAConstraintMidX:  NSMinX(*r) = MAX(0, v - NSWidth(*r)/2); break;
		case kCAConstraintMaxX:  NSMinX(*r) = MAX(0, v - NSWidth(*r));	 break;
		case kCAConstraintWidth: NSWidth(*r) = v;						 break;
		case kCAConstraintMinY:  NSMinY(*r) = v;						 break;
		case kCAConstraintMidY:  NSMinY(*r) = MAX(0, v - NSHeight(*r)/2); break;
		case kCAConstraintMaxY:  NSMinY(*r) = MAX(0, v - NSHeight(*r));  break;
		case kCAConstraintHeight: NSHeight(*r) = v;						 break;
		}
}

@implementation CAConstraint

+ (id) constraintWithAttribute:(CAConstraintAttribute) attribute
					relativeTo:(NSString *) srcLayerName
					attribute:(CAConstraintAttribute) srcLayerAttribute
{
	return [[[[self class] alloc] initWithAttribute: attribute
								  relativeTo: srcLayerName
								  attribute: srcLayerAttribute
								  scale: 1.0
								  offset: 0] autorelease];
}

- (id) initWithAttribute:(CAConstraintAttribute) attribute
			  relativeTo:(NSString *) srcLayerName
			   attribute:(CAConstraintAttribute) srcLayerAttribute
				   scale:(CGFloat) scale
				  offset:(CGFloat) offset;
{
	_sourceName = [srcLayerName retain];
	_f.sourceAttribute = srcLayerAttribute;
	_f.attribute = attribute;
	_scale = scale;
	_offset = offset;

	return self;
}

- (void) dealloc
{
	[_sourceName release];
	[super dealloc];
}

- (NSString *) sourceName						{ return _sourceName; }
- (CAConstraintAttribute) attribute				{ return _f.attribute; }
- (CAConstraintAttribute) sourceAttribute		{ return _f.sourceAttribute; }
- (CGFloat) scale								{ return _scale; }
- (CGFloat) offset								{ return _offset; }

- (void) _constrainLayer:(CALayer *)sublayer withFrame:(CGRect *)subframe
{
// if ([_sourceName isEqualToString: @"superlayer"])
		CGRect frame = [[sublayer superlayer] frame];
//	else
//		CGRect frame = [[superlayer layerWithName: _sourceName] frame];
	CGFloat v = _CGContraintGetAttribute(_f.sourceAttribute, frame);

	_CGContraintSetAttribute(_f.attribute, subframe, (_scale * v + _offset));
}

@end

@implementation CAConstraintLayoutManager

+ (id) layoutManager				{ return [[[self class] new] autorelease]; }

- (void) _applyLayerContraints:(CALayer *)sublayer
{
	NSArray *ca = [sublayer constraints];
	CGRect subframe = [sublayer frame];
	NSUInteger j, count = [ca count];

	for (j = 0; j < count; j++)
		[[ca objectAtIndex:j] _constrainLayer:sublayer withFrame:&subframe];
	[sublayer setFrame: subframe];
}

@end

@implementation CALayer (CAConstraintLayoutManager)

- (void) addConstraint:(CAConstraint *)constraint
{
	if (!_constraints)
		_constraints = [NSMutableArray new];
	[_constraints addObject: constraint];
}

- (NSArray *) constraints 					{ return [_constraints copy]; }

- (void) setConstraints:(NSArray *)constraints
{
	ASSIGN(_constraints, [NSMutableArray arrayWithArray: constraints]);
}

@end
