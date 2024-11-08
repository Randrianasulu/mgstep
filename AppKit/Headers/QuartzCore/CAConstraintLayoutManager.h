/*
   CAConstraintLayoutManager.h

   Graphics animation

   Copyright (C) 2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    May 2020

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CAConstraintLayoutManager
#define _mGSTEP_H_CAConstraintLayoutManager

#include <Foundation/NSObject.h>


@interface CAConstraintLayoutManager : NSObject

+ (id) layoutManager;

@end


typedef enum _CAConstraintAttribute
{
	kCAConstraintMinX,
	kCAConstraintMidX,
	kCAConstraintMaxX,
	kCAConstraintWidth,
	kCAConstraintMinY,
	kCAConstraintMidY,
	kCAConstraintMaxY,
	kCAConstraintHeight

} CAConstraintAttribute;

/* ****************************************************************************

	Constraint objects describe one geometry relationship between two layers.
	Layers are referenced by 'name' with @"superlayer" reserved for layer's
	super layer.  The layout manager applies the typical linear equation:

		layer.attribute = scale * srcLayer.srcAttribute + offset

	Where: scale default is 1 if undefined, offset default is 0.

** ***************************************************************************/

@interface CAConstraint : NSObject  // <NSCoding>
{
	NSString *_sourceName;							// src layer name
	CGFloat _scale;
	CGFloat _offset;

	struct __ConstraintFlags {
		CAConstraintAttribute attribute:8;
		CAConstraintAttribute sourceAttribute:8;	// src layer attribute
		unsigned int reserved:16;
	} _f;
};

+ (id) constraintWithAttribute:(CAConstraintAttribute) attribute
					relativeTo:(NSString *) srcLayerName
					attribute:(CAConstraintAttribute) srcLayerAttribute;

- (id) initWithAttribute:(CAConstraintAttribute) attribute
			  relativeTo:(NSString *) srcLayerName
			   attribute:(CAConstraintAttribute) srcLayerAttribute
				   scale:(CGFloat) scale
				  offset:(CGFloat) offset;

- (NSString *) sourceName;
- (CAConstraintAttribute) attribute;
- (CAConstraintAttribute) sourceAttribute;
- (CGFloat) scale;
- (CGFloat) offset;

@end


@interface CALayer (CAConstraintLayoutManager)

@property(copy)  NSArray *constraints;

- (void) addConstraint:(CAConstraint *)constraint;

@end

#endif /* _mGSTEP_H_CAConstraintLayoutManager */
