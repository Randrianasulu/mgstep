/*
   CoreGraphics.h

   mini Core Graphics interfaces.  

   Copyright (C) 2006-2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jun 2006

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CoreGraphics
#define _mGSTEP_H_CoreGraphics

#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFString.h>

#include <CoreGraphics/CGGeometry.h>
#include <CoreGraphics/CGAffineTransform.h>
#include <CoreGraphics/CGColor.h>
#include <CoreGraphics/CGFont.h>
#include <CoreGraphics/CGColorSpace.h>
#include <CoreGraphics/CGPath.h>
#include <CoreGraphics/CGGradient.h>
#include <CoreGraphics/CGShading.h>
#include <CoreGraphics/CGImage.h>
#include <CoreGraphics/CGLayer.h>
#include <CoreGraphics/CGDirectDisplay.h>
#include <CoreGraphics/CGPattern.h>
#include <CoreGraphics/CGContext.h>

#include <CoreGraphics/Private/_CoreGraphics.h>

#define _CG_FLATNESS              0.1
#define _CG_MITER_LIMIT          10.0
#define _CG_LINE_WIDTH            1.0
#define _CG_LINE_JOIN_STYLE      NSMiterLineJoinStyle
#define _CG_LINE_CAP_STYLE       NSButtLineCapStyle
#define _CG_WINDING_RULE         NSNonZeroWindingRule

#endif  /* _mGSTEP_H_CoreGraphics */
