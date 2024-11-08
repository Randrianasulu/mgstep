/*
   NSOpenPanel.h

   Standard open panel for opening files

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Daniel Bðhringer <boehring@biomed.ruhr-uni-bochum.de>
   Date: August 1998
   Integration by Felipe A. Rodriguez <far@ix.netcom.com> 

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSOpenPanel
#define _mGSTEP_H_NSOpenPanel

#include <AppKit/NSSavePanel.h>

@class NSString;
@class NSArray;
@class NSMutableArray;

@interface NSOpenPanel : NSSavePanel  <NSCoding>
{
	struct __OpenPanelFlags {
		unsigned int canChooseDirectories:1;
		unsigned int canChooseFiles:1;
		unsigned int allowsMultipleSelect:1;
		unsigned int reserved:5;
	} _op;
}

+ (NSOpenPanel *) openPanel;

- (BOOL) allowsMultipleSelection;						// Filtering Files
- (BOOL) canChooseDirectories;
- (BOOL) canChooseFiles;
- (void) setAllowsMultipleSelection:(BOOL)flag;
- (void) setCanChooseDirectories:(BOOL)flag;
- (void) setCanChooseFiles:(BOOL)flag;
							// Returns an array of the selected files and 
							// directories as absolute paths. Array ontains a  
- (NSArray *) filenames;	// single path if multiple selection is not allowed

- (int) runModalForTypes:(NSArray *)fileTypes;			// Run the NSOpenPanel
- (int) runModalForDirectory:(NSString *)path
						file:(NSString *)name
						types:(NSArray *)fileTypes;
@end

#endif /* _mGSTEP_H_NSOpenPanel */
