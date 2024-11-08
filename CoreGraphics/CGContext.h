/*
   CGContext.h

   Graphics context.

   Copyright (C) 2006-2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jun 2006

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CGContext
#define _mGSTEP_H_CGContext

#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFString.h>

#include <CoreGraphics/CGAffineTransform.h>
#include <CoreGraphics/CGColor.h>
#include <CoreGraphics/CGColorSpace.h>
#include <CoreGraphics/CGFont.h>
#include <CoreGraphics/CGGradient.h>
#include <CoreGraphics/CGImage.h>
#include <CoreGraphics/CGPath.h>
#include <CoreGraphics/CGShading.h>


typedef struct _CGContext * CGContextRef;

typedef enum _CGTextEncoding {
	kCGEncodingFontSpecific,
	kCGEncodingMacRoman
} CGTextEncoding;


extern CGContextRef CGContextRetain( CGContextRef c);
extern void 		CGContextRelease( CGContextRef c);

extern void CGContextFlush( CGContextRef c);
extern void CGContextSynchronize( CGContextRef c);

extern void _CGContextRectNeedsFlush(CGContextRef c, CGRect r);

/* ****************************************************************************

	Saved and restored graphics state parameters:

	•	CTM  (coordinate transformation matrix)
	•	clip region
	•	line attributes  (width, join, miter limit, cap, dash)
	•	stroke flatness
	•	image interpolation quality
	•	should anti-alias
	•	color (fill, stroke, color space, rendering intent, alpha)
	•	font  (size, smoothing parameter)
	•	text  (drawing mode, character spacing)
	•	shadow attributes
	•	pattern phase
	•	blend mode  (compositing operation)

** ***************************************************************************/

extern void CGContextSaveGState( CGContextRef c);
extern void CGContextRestoreGState( CGContextRef c);

extern void CGContextSetFont(CGContextRef c, CGFontRef font);
extern void CGContextSetFontSize(CGContextRef c, float size);
extern void CGContextSelectFont(CGContextRef c,
								const char *name,
								float fontSize,
								CGTextEncoding textEncoding);

extern void CGContextSetLineDash( CGContextRef c,
								  CGFloat phase,
								  const CGFloat lengths[],
								  size_t count);

extern void CGContextSetLineWidth( CGContextRef c, float width);
extern void CGContextSetMiterLimit( CGContextRef c, float limit);
extern void CGContextSetLineCap( CGContextRef c, CGLineCap cap);
extern void CGContextSetLineJoin( CGContextRef c, CGLineJoin join);
extern void CGContextSetFlatness( CGContextRef c, float flatness);

extern void CGContextSetShouldAntialias( CGContextRef c, bool should);
extern void CGContextSetAllowsAntialiasing( CGContextRef c, bool allows);

extern void CGContextDrawImage(CGContextRef c, CGRect r, CGImageRef img);

typedef enum {
	kCGInterpolationDefault,		// gState image interpolation quality
	kCGInterpolationNone,			// hint used when scaling ...etc
	kCGInterpolationLow,
	kCGInterpolationHigh
} CGInterpolationQuality;

extern CGInterpolationQuality CGContextGetInterpolationQuality(CGContextRef c);
extern void CGContextSetInterpolationQuality( CGContextRef c,
											  CGInterpolationQuality q);

/* ****************************************************************************

	Color
 
** ***************************************************************************/

extern void CGContextSetFillColorWithColor(CGContextRef cx, CGColorRef c);
extern void CGContextSetStrokeColorWithColor(CGContextRef cx, CGColorRef c);
extern void CGContextSetGrayFillColor(CGContextRef c, float g, float alpha);
extern void CGContextSetGrayStrokeColor(CGContextRef c, float g, float alpha);
extern void CGContextSetAlpha(CGContextRef c, CGFloat alpha);

extern void CGContextSetRGBStrokeColor( CGContextRef c,
									    float red,
									    float green,
									    float blue,
									    float alpha);

extern void  CGContextSetRGBFillColor ( CGContextRef c,
									    float red,
									    float green,
									    float blue,
									    float alpha);

									// set color space and its default color
void CGContextSetFillColorSpace(CGContextRef cx, CGColorSpaceRef s);
void CGContextSetStrokeColorSpace(CGContextRef cx, CGColorSpaceRef s);

/* ****************************************************************************

	Color blending  (Porter-Duff blend modes)

	Colors:  R (pre-multiplied result), S (source), D (destination)
	Alpha:   Sa and Da are the alpha component of each.

** ***************************************************************************/

typedef enum {
	kCGBlendModeNormal,				//  R = S + D * (1 - Sa), NeXT SourceOver
	kCGBlendModeMultiply,
	kCGBlendModeScreen,
	kCGBlendModeOverlay,
	kCGBlendModeDarken,
	kCGBlendModeLighten,
	kCGBlendModeColorDodge,
	kCGBlendModeColorBurn,
	kCGBlendModeSoftLight,
	kCGBlendModeHardLight,
	kCGBlendModeDifference,
	kCGBlendModeExclusion,
	kCGBlendModeHue,
	kCGBlendModeSaturation,
	kCGBlendModeColor,
	kCGBlendModeLuminosity,
	kCGBlendModeClear,				//  R = 0
	kCGBlendModeCopy,				//  R = S
	kCGBlendModeSourceIn,			//  R = S * Da
	kCGBlendModeSourceOut,			//  R = S * (1 - Da)
	kCGBlendModeSourceAtop,			//  R = S * Da + D * (1 - Sa)
	kCGBlendModeDestinationOver,	//  R = S * (1 - Da) + D
	kCGBlendModeDestinationIn,		//  R = D * Sa
	kCGBlendModeDestinationOut,		//  R = D * (1 - Sa)
	kCGBlendModeDestinationAtop,	//  R = S * (1 - Da) + D * Sa
	kCGBlendModeXOR,				//  R = S * (1 - Da) + D * (1 - Sa)
	kCGBlendModePlusDarker,			//  R = MAX(0, (1 - D) + (1 - S))
	kCGBlendModePlusLighter			//  R = MIN(1, S + D)
} CGBlendMode;

extern void CGContextSetBlendMode( CGContextRef cx, CGBlendMode mode);

/* ****************************************************************************

	Space transformation

** ***************************************************************************/

extern CGAffineTransform CGContextGetCTM( CGContextRef c);

extern void CGContextConcatCTM( CGContextRef c, CGAffineTransform t);
extern void CGContextRotateCTM( CGContextRef c, CGFloat angle);
extern void CGContextScaleCTM( CGContextRef c, CGFloat sx, CGFloat sy);
extern void CGContextTranslateCTM( CGContextRef c, CGFloat tx, CGFloat ty);

/* ****************************************************************************

	Clipping
 
** ***************************************************************************/

//  Clip to the intersection of CTX's path with its current clip path
extern void CGContextClip( CGContextRef c);
extern void CGContextEOClip( CGContextRef c);		// Use Even-Odd fill rule

extern void CGContextClipToMask(CGContextRef c, CGRect r, CGImageRef mask);
extern void CGContextClipToRect(CGContextRef c, CGRect r);
extern void CGContextClipToRects(CGContextRef c, const CGRect r[], size_t count);

extern void _CGContextSetClipRect(CGContextRef c, CGRect r);

extern CGRect CGContextGetClipBoundingBox(CGContextRef c);

/* ****************************************************************************

	Text
 
** ***************************************************************************/

typedef enum _CGTextDrawingMode {
	kCGTextFill,
	kCGTextStroke,
	kCGTextFillStroke,
	kCGTextInvisible,
	kCGTextFillClip,
	kCGTextStrokeClip,
	kCGTextFillStrokeClip,
	kCGTextClip
} CGTextDrawingMode;

extern void CGContextSetTextDrawingMode(CGContextRef c, CGTextDrawingMode mode);

extern void    CGContextSetTextPosition( CGContextRef c, CGFloat x, CGFloat y);
extern CGPoint CGContextGetTextPosition( CGContextRef c);

extern void CGContextSetCharacterSpacing( CGContextRef c, CGFloat spacing);
extern void CGContextSetTextMatrix( CGContextRef c, CGAffineTransform m);

extern CGAffineTransform CGContextGetTextMatrix(CGContextRef c);

extern void CGContextShowGlyphsAtPoint( CGContextRef c,
										CGFloat x, CGFloat y,
										const CGGlyph glyphs[],
										size_t nglyphs);

extern void CGContextShowText (CGContextRef c, const char *bytes, size_t len);
extern void CGContextShowTextAtPoint ( CGContextRef c,
									   CGFloat x, CGFloat y,
									   const char *bytes,
									   size_t length);

/* ****************************************************************************

	Path

	CG context has only a single current CGPath.  The old path is discarded
	when a new path is begun.  The path is not part of the graphics state.
	Saving and restoring graphics state will not affect the current path.
 
** ***************************************************************************/

typedef enum _CGPathDrawingMode {		// path drawing modes (text modes N/A)
	kCGPathFill,
	kCGPathEOFill,
	kCGPathStroke,
	kCGPathFillStroke,
	kCGPathEOFillStroke
} CGPathDrawingMode;


extern CGPoint  CGContextGetPathCurrentPoint( CGContextRef c);
extern CGRect   CGContextGetPathBoundingBox( CGContextRef c);

extern bool CGContextIsPathEmpty( CGContextRef c);
extern bool CGContextPathContainsPoint( CGContextRef c,
										CGPoint p,
										CGPathDrawingMode m);

extern void CGContextBeginPath( CGContextRef c);
extern void CGContextClosePath( CGContextRef c);

extern CGPathRef CGContextCopyPath( CGContextRef c);
	// add path to context's path, tranforms points with CTM before adding them
extern void CGContextAddPath( CGContextRef c, CGPathRef path);
	// replace context's path with stroked version created with cx attributes
extern void CGContextReplacePathWithStrokedPath( CGContextRef cx);

extern void CGContextDrawPath( CGContextRef c, CGPathDrawingMode m);
extern void CGContextFillPath( CGContextRef c);
extern void CGContextEOFillPath( CGContextRef c);
extern void CGContextStrokePath( CGContextRef c);

extern void CGContextMoveToPoint( CGContextRef c, float x, float y);
extern void CGContextAddLineToPoint( CGContextRef c, float x, float y);

extern void CGContextAddQuadCurveToPoint( CGContextRef c,
										  CGFloat cp_x, CGFloat cp_y,
										  CGFloat x, CGFloat y );

								// append cubic Bezier curve to current path
extern void CGContextAddCurveToPoint( CGContextRef c,
									  CGFloat cp1_x, CGFloat cp1_y,
									  CGFloat cp2_x, CGFloat cp2_y,
									  CGFloat x, CGFloat y );

extern void CGContextAddArc( CGContextRef c,
							 float x,
							 float y,
							 float radius,
							 float startAngle,
							 float endAngle,
							 int clockwise);

extern void CGContextAddArcToPoint( CGContextRef cx,
									CGFloat x1, CGFloat y1,
									CGFloat x2, CGFloat y2,
									CGFloat radius);

extern void CGContextFillRect (CGContextRef c, CGRect rect);
extern void CGContextFillRects (CGContextRef c, const CGRect r[], size_t n);
													// make rect transparent
extern void CGContextClearRect( CGContextRef c, CGRect rect);

extern void CGContextStrokeLineSegments( CGContextRef c,
										 const CGPoint points[],
										 size_t count);

extern void CGContextStrokeRect (CGContextRef c, CGRect r);
extern void CGContextStrokeRectWithWidth (CGContextRef c, CGRect r, float w);

extern void CGContextFillEllipseInRect(CGContextRef c, CGRect r);
extern void CGContextStrokeEllipseInRect(CGContextRef c, CGRect r);

extern void CGContextAddEllipseInRect( CGContextRef c, CGRect r);
extern void CGContextAddRect( CGContextRef c, CGRect r);
extern void CGContextAddRects( CGContextRef c, const CGRect r[], size_t count);
extern void CGContextAddLines(CGContextRef c, const CGPoint p[], size_t count);

/* ****************************************************************************

	Gradient and Shading
 
** ***************************************************************************/

extern void CGContextDrawShading (CGContextRef c, CGShadingRef shading);

				// fill context clip with a radial gradient between two circles
				// with centers at start and end
extern void CGContextDrawRadialGradient(CGContextRef c,
										CGGradientRef gradient,
										CGPoint startCenter,
										CGFloat startRadius,
										CGPoint endCenter,
										CGFloat endRadius,
										CGGradientDrawingOptions options);

				// fill context clip with a linear color gradient between
				// start and end points which correspond to the gradient's
				// locations 0 thru 1 respectively.
extern void CGContextDrawLinearGradient(CGContextRef c,
										CGGradientRef gradient,
										CGPoint startPoint,
										CGPoint endPoint,
										CGGradientDrawingOptions options);

/* ****************************************************************************

	Shadows

	Set graphics state shadow params (Gaussian filter) for all objects drawn.
	
	offset:  device space translation
	blur:    a positive number indicating the ammount of blur
	color:   shadow color or NULL for full transparency (disables shadow)

	CGContextSetShadow() is equivalent to using black with 1/3 alpha
	
** ***************************************************************************/

extern void CGContextSetShadowWithColor(CGContextRef c,
										CGSize offset,
										CGFloat blur,
										CGColorRef color);

extern void CGContextSetShadow(CGContextRef cx, CGSize offset, CGFloat blur);

/* ****************************************************************************

	Layer

	Create a cache layer for drawing, flushes to context surface at end.
	Sets alpha to 1, shdadow off and blend mode to kCGBlendModeNormal.
	Initial values are restored at end layer.  Respects context clipping.
 
** ***************************************************************************/

extern void CGContextBeginTransparencyLayer( CGContextRef c,
											 CFDictionaryRef auxInfo );
extern void CGContextBeginTransparencyLayerWithRect( CGContextRef c,
													 CGRect r,
													 CFDictionaryRef auxInfo);
extern void CGContextEndTransparencyLayer( CGContextRef c);

/* ****************************************************************************

	CG BitmapContext

	CTX which draws onto its bitmap.  Allocates 'data" if NULL.

** ***************************************************************************/

typedef void (*CGBitmapContextReleaseDataCallback)(void *info, void *data);


extern CGContextRef  CGBitmapContextCreateWithData(
							   void *data,				// bytesPerRow * height
							   size_t width,
							   size_t height,
							   size_t bitsPerComponent,
							   size_t bytesPerRow,
							   CGColorSpaceRef s,
							   CGBitmapInfo b,			// has alpha ...etc
							   CGBitmapContextReleaseDataCallback r,
							   void *info );			// release info

extern CGContextRef  CGBitmapContextCreate( void *data,
											size_t width,
											size_t height,
											size_t bitsPerComponent,
											size_t bytesPerRow,
											CGColorSpaceRef s,
											CGBitmapInfo b);

extern CGImageRef CGBitmapContextCreateImage( CGContextRef c);

extern void * CGBitmapContextGetData( CGContextRef c);
extern size_t CGBitmapContextGetWidth( CGContextRef c);
extern size_t CGBitmapContextGetHeight( CGContextRef c);
extern size_t CGBitmapContextGetBytesPerRow( CGContextRef c);
extern size_t CGBitmapContextGetBitsPerPixel( CGContextRef c);
extern size_t CGBitmapContextGetBitsPerComponent( CGContextRef c);

extern CGImageAlphaInfo CGBitmapContextGetAlphaInfo( CGContextRef c);
extern CGBitmapInfo     CGBitmapContextGetBitmapInfo( CGContextRef c);
extern CGColorSpaceRef  CGBitmapContextGetColorSpace( CGContextRef c);

#endif  /* _mGSTEP_H_CGContext */
