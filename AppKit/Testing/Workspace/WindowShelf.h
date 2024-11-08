/*
   WindowShelf.h

   Object that contain a window, shelf and content area

   Copyright (C) 2001 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@pcmagic.net>
   Date:	November 2001

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _Workspace_H_WindowShelf
#define _Workspace_H_WindowShelf

#include <AppKit/NSWindow.h>
#include <AppKit/NSSplitView.h>

@class Matrix;
@class Browser;


@interface WindowShelf : NSWindow
{
	Matrix *_shelf;
	Browser *_browser;

	NSBrowser *_listView;
	NSBrowser *_iconView;
}

- (id) initWithFrame:(NSRect)winRect
				rows:(int)rows
				cols:(int)cols
				subView:(NSView *)subView;

- (Matrix *) matrix;
- (Browser *) browser;

@end


@interface SplitView : NSSplitView
{
	NSTextFieldCell *_textCell;
	NSRect _lastTextRect;
}

- (void) setFileSize:(NSObject *)fsize;

@end

#endif /* _Workspace_H_WindowShelf */
