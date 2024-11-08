/*
   Controller.h

   Controller object for mGSTEP Workspace

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@ix.netcom.com>
   Date:	November 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_Controller
#define _mGSTEP_H_Controller

#include <Foundation/NSObject.h>

@class NSBrowser;
@class NSButton;
@class NSMatrix;
@class NSTextField;
@class WindowShelf;
@class Browser;


@interface Controller : NSObject
{
	NSTextField *textField;
	WindowShelf *_shelf;

	IBOutlet NSTextField *_openWith;
	IBOutlet NSTextField *_openWithArgs;
	IBOutlet NSTextField *_openWithEnv;
	IBOutlet NSButton *_openWithSave;
	IBOutlet NSPanel *_openWithPanel;

	IBOutlet NSPanel *_aboutPanel;
	IBOutlet NSTextField *_credits;
	IBOutlet NSTextField *_applicationName;
	IBOutlet NSTextField *_version;
	IBOutlet NSTextField *_copyright;
	IBOutlet NSTextField *_applicationVersion;
}

- (Browser *) browser;

- (IBAction) openWith:(id)sender;

- (void) openWithPanel:(id)menuCell;
- (void) openXTerm:(id)menuCell;
- (void) updateViewer:(id)menuCell;
- (void) toggleView:(id)menuCell;
- (void) destroy:(id)menuCell;
- (void) method:(id)menuCell;

- (BOOL) performFileOperation:(NSString *)operation
				  destination:(NSString *)destination;
@end

#endif /* _mGSTEP_H_Controller */
