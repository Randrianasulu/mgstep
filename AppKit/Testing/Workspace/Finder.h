/*
   Finder.h

   File system search tool

   Copyright (C) 2001 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@pcmagic.net>
   Date:	November 2001

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_Finder
#define _mGSTEP_H_Finder

#include "WindowShelf.h"

@class NSTask;
@class NSButton;
@class NSBrowser;
@class NSTextField;
@class NSScrollView;

@interface Finder : WindowShelf
{
	int _master;
	int _rowCount;
	NSMatrix *_scrollViewMatrix;
	NSScrollView *_scrollView;
	NSTextField *textField;
	NSTask *_searchTask;
	NSButton *_searchButton;
	void *_cfSocket;
}

+ (Finder *) sharedFinder;

- (void) search:(id)sender;

@end

#endif /* _mGSTEP_H_Finder */
