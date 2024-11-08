/*
   CGColorSpace.h

   mini Core Graphics color space

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	August 2017

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CGColorSpace
#define _mGSTEP_H_CGColorSpace

#include <CoreFoundation/CFString.h>


typedef enum _CGColorSpaceModel {

	kCGColorSpaceModelUnknown = -1,			// NSUnknownColorSpaceModel
	kCGColorSpaceModelMonochrome,			// NSGrayColorSpaceModel
	kCGColorSpaceModelRGB,					// NSRGBColorSpaceModel
	kCGColorSpaceModelCMYK,					// NSCMYKColorSpaceModel
	kCGColorSpaceModelLab,
	kCGColorSpaceModelDeviceN,				// NSDeviceNColorSpaceModel
	kCGColorSpaceModelIndexed,				// NSIndexedColorSpaceModel
	kCGColorSpaceModelPattern				// NSPatternColorSpaceModel

} CGColorSpaceModel;


typedef struct _CGColorSpace *CGColorSpaceRef;

typedef struct _CGColorSpace {

	void *class_pointer;
	void *cf_pointer;

	CFStringRef name;

	CGColorSpaceModel model;

	unsigned char _blue;					// color component shift
	unsigned char _green;
	unsigned char _red;

} CGColorSpace;


extern CGColorSpaceRef CGColorSpaceCreateWithName(CFStringRef name);
extern CGColorSpaceRef CGColorSpaceCreateDeviceRGB(void);
extern CGColorSpaceRef CGColorSpaceCreateDeviceGray(void);

extern CFStringRef CGColorSpaceCopyName(CGColorSpaceRef s);

extern CGColorSpaceRef CGolorSpaceRetain (CGColorSpaceRef s);
extern void            CGolorSpaceRelease(CGColorSpaceRef s);

extern CGColorSpaceModel CGColorSpaceGetModel(CGColorSpaceRef s);

	// number of color components in color space without the alpha value
extern size_t CGColorSpaceGetNumberOfComponents(CGColorSpaceRef s);

	// baseSpace s/b NULL for colored pat or CS of draw colors in uncolored pat
extern CGColorSpaceRef CGColorSpaceCreatePattern(CGColorSpaceRef baseSpace);

									// *Generic* == NSCalibrated*ColorSpace
extern const CFStringRef kCGColorSpaceGenericRGB;			// is BGR on X11
extern const CFStringRef kCGColorSpaceGenericRGBLinear;		// RGB w/Gamma 1.0
extern const CFStringRef kCGColorSpaceGenericGray;

#endif  /* _mGSTEP_H_CGColorSpace */
