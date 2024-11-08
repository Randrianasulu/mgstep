/*
   _CGPath.h

   Graphics path private interface

   Copyright (C) 2019 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    November 2019

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _H_CGPath
#define _H_CGPath

typedef struct _IntegerRect iRect;
typedef struct _PolygonEdge pEdge;

typedef struct DashContext {

	CGFloat phase;
	const CGFloat *lengths;
	size_t count;
	unsigned int cursor;

} _CGPathDash;


typedef struct RenderContext {

	struct _gGET *get;
	const CGAffineTransform *ctm;
	float flatness;

	int linecap;
	int linejoin;
	float linewidth;
	float miterlimit;

	CGPoint vA[2];						// line join/cap vertices
	CGPoint vB[2];
	int lenA;
	int lenB;
	int dot;

	CGMutablePathRef copy;				// dst path when stroke copying

	_CGPathDash *dash;
	CGPoint org;

	void (*lineto)  (struct RenderContext *, CGPoint);

} rCTX, _CGRenderCTX;

/* ****************************************************************************

	Global Edge Table - path scan conversion generated list of all edges
	Active Edge Table - GET subset with edges that instersect drawing scanline

	The path rendering algorithm is derived from code and documentation in:

      Michael Abrash’s Graphics Programming Black Book, Special Edition

    A brief summary from Chapter 40:

    0. Store all polygon edges in Y-primary / X-secondary sort order in the
       GET along with initial X and Y coordinates, error terms and error
       term adjustments, lengths, and directions of X movement for each edge.
    1. Set current Y coordinate to Y coordinate of the first edge in the GET.
    2. Move all edges with the current Y coordinate from the GET to the AET,
       removing them from the GET and maintaining the X-sorted order of the AET.
    3. Draw all odd-to-even spans in the AET at the current Y coordinate.
    4. Count down the lengths of all edges in the AET, removing any edges that 
       are done, and advancing the X coordinates of all remaining edges in the 
       AET by one scan line.
    5. Sort the AET in order of ascending X coordinate.
    6. Advance the current Y coordinate by one scan line.
    7. If either the AET or GET is not empty go back to step 2.

** ***************************************************************************/

typedef struct _gGET
{
	NSUInteger index;
	NSUInteger size;
	NSUInteger length;
	pEdge *edges;

	iRect clip;
	iRect bbox;

} gGET;

typedef struct _gAET
{
	NSUInteger size;
	NSUInteger length;
	pEdge **edges;

} gAET;


extern void _CGAddEdgeGET(gGET *g, float x, float y, float x1, float y1);

extern void _CGPathStroke( CGPath *p, _CGRenderCTX *r);
extern void _CGPathFill( CGPath *p, gGET *g, CGAffineTransform *m, float flatness);

#endif /* _H_CGPath */
