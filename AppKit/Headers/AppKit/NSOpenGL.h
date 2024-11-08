/*
   NSOpenGL.h

   OpenGL interface classes

   Copyright (C) 2021 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    May 2021

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSOpenGL
#define _mGSTEP_H_NSOpenGL

#include <AppKit/NSView.h>

#include <GL/gl.h>
#include <GL/glx.h>
#include <GL/glu.h>

@class NSOpenGLPixelFormat;
@class NSGraphicsContext;
@class NSView;


@interface NSOpenGLContext : NSObject
{
	NSGraphicsContext *_cx;
	GLXContext _glx;
	NSView *_view;
}

+ (NSOpenGLContext *) currentContext;

//+ (void) clearCurrentContext;

- (id) initWithFormat:(NSOpenGLPixelFormat *)format
		 shareContext:(NSOpenGLContext *)sharedContext;

- (void) makeCurrentContext;
- (void) flushBuffer;
- (void) clearDrawable;

- (void) setView:(NSView *)view;
- (NSView *) view;

@end


@interface NSOpenGLView : NSView
{
    NSOpenGLContext *_glContext;
//	NSOpenGLPixelFormat *_pixelFormat;  		// ignored, best is selected
}

- (id) initWithFrame:(NSRect)rect pixelFormat:(NSOpenGLPixelFormat *)fmt;

- (NSOpenGLContext *) openGLContext;
- (void) setOpenGLContext:(NSOpenGLContext *)context;
- (void) clearGLContext;

@end

#endif /* _mGSTEP_H_NSOpenGL */
