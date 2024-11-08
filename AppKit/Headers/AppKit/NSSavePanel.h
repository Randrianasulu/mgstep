/*
   NSSavePanel.h

   Standard save panel for saving files

   Copyright (C) 1996, 1997 Free Software Foundation, Inc.

   Author:  Daniel B�hringer <boehring@biomed.ruhr-uni-bochum.de>
   Date: August 1998
   Integration by Felipe A. Rodriguez <far@ix.netcom.com> 

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSSavePanel
#define _mGSTEP_H_NSSavePanel

#include <Foundation/NSCoder.h>
#include <Foundation/NSSet.h>

#include <AppKit/NSPanel.h>
#include <AppKit/NSBrowser.h>

@class NSString;
@class NSView;

enum {
	NSFileHandlingPanelImageButton,
	NSFileHandlingPanelTitleField,
	NSFileHandlingPanelBrowser,
	NSFileHandlingPanelCancelButton,
	NSFileHandlingPanelOKButton,
	NSFileHandlingPanelForm,
	NSFileHandlingPanelHomeButton,
	NSFileHandlingPanelDiskButton,
	NSFileHandlingPanelDiskEjectButton
};

@interface NSSavePanel : NSPanel  <NSCoding>
{
    NSBrowser *browser;
    id form;
    id homeButton;
    id okButton;
    id mountButton;
    id unmountButton;
    id separator;
	id titleField;
    NSString *lastValidPath;
    NSArray *requiredTypes;
    NSSet *typeTable;
							// to do finish integration, eliminate excess FAR
    NSView *_accessoryView;
	BOOL treatsFilePackagesAsDirectories;
}

+ (NSSavePanel *) savePanel;			// Returns an instance of NSSavePanel, 
										// creating one if necessary.

- (void) setAccessoryView:(NSView *)aView;
- (NSView *) accessoryView;
				// Sets the title of the NSSavePanel to title. By default, 
				// Save is the title string. If you adapt the NSSavePanel 
				// for other uses, its title should reflect the user action 
				// that brings it to the screen.
- (void) setTitle:(NSString *)title;
- (NSString *) title;
				// Returns the prompt of the Save panel field that holds 
				// the current pathname or file name. By default this 
				// prompt is �Name:�. *Note - currently no prompt is shown.
- (NSString *) prompt;
- (void) setPrompt:(NSString *)prompt;
				// Sets the current path name in the Save panel's browser. 
				// The path argument must be an absolute path name.
- (void) setDirectory:(NSString *)path;
				// Specifies the type, a file name extension to be appended to 
				// any selected files that don't already have that extension;
				// The argument type should not include the period that begins 
				// the extension.  Invoke this method each time the Save panel 
				// is used for another file type within the application.
- (void) setRequiredFileType:(NSString *)type;
- (NSString *) requiredFileType;
				// Sets the NSSavePanel's behavior for displaying file packages 
				// (for example, MyApp.app) to the user.  If flag is YES, the 
				// user is shown files and subdirectories within a file 
				// package.  If NO, the NSSavePanel shows each file package as 
				// a file, thereby giving no indication that it is a directory.
- (void) setTreatsFilePackagesAsDirectories:(BOOL)flag;
- (BOOL) treatsFilePackagesAsDirectories;
				// Validates and possibly reloads the browser columns visible 
				// in the Save panel by causing the delegate method 
				// panel:shouldShowFilename: to be invoked. One situation in 
				// which this method would find use is whey you want the 
				// browser show only files with certain extensions based on the 
				// selection made in an accessory-view pop-up list.  When the 
				// user changes the selection, you would invoke this method to
				// revalidate the visible columns. 
- (void) validateVisibleColumns;

				// Initializes the panel to the directory specified by path 
				// and, optionally, the file specified by filename, then 
				// displays it and begins its modal event loop; path and 
				// filename can be empty strings, but cannot be nil.  The 
				// method invokes Application's runModalForWindow: method with 
				// self as the argument.  Returns NSOKButton (if the user 
				// clicks the OK button) or NSCancelButton (if the user clicks 
				// the Cancel button).  Do not invoke filename or directory 
				// within a modal loop because the information that these 
				// methods fetch is updated only upon return.
- (int) runModalForDirectory:(NSString *)path file:(NSString *)filename;
- (int) runModal;
				// Returns the absolute pathname of the directory currently 
				// shown in the panel.  Do not invoke this method within a 
				// modal session (runModal or runModalForDirectory:file:)
				// because the directory information is only updated just 
				// before the modal session ends.
- (NSString *) directory;
- (NSString *) filename;

- (void) ok:(id)sender;									// Target / Action
- (void) cancel:(id)sender;
- (void) selectText:(id)sender;

@end

													// Implemented by Delegate 
@interface NSObject (NSSavePanelDelegate)
				// The NSSavePanel sends this message just before the end of a 
				// modal session for each file name displayed or selected 
				// (including file names in multiple selections).  The delegate 
				// determines whether it wants the file identified by filename; 
				// it returns YES if the file name is valid, or NO if the 
				// NSSavePanel should stay in its modal loop and wait for the 
				// user to type in or select a different file name or names. If 
				// the delegate refuses a file name in a multiple selection, 
				// none of the file names in the selection are accepted.
- (BOOL) panel:(id)sender isValidFilename:(NSString*)filename;
- (NSComparisonResult) panel:(id)sender
					   compareFilename:(NSString *)filename1
					   with:(NSString *)filename2
					   caseSensitive:(BOOL)caseSensitive;	 
- (BOOL) panel:(id)sender shouldShowFilename:(NSString *)filename;

@end

#endif /* _mGSTEP_H_NSSavePanel */
