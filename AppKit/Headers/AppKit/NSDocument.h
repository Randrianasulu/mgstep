/*
   NSDocument.h

   Represents file based documents in a window.

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@ix.netcom.com>
   Date:	Sept 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSDocument
#define _mGSTEP_H_NSDocument

#include <Foundation/NSObject.h>

@class NSWindow;
@class NSWindowController;
@class NSUndoManager;
@class NSString;
@class NSMutableArray;
@class NSArray;
@class NSError;
@class NSURL;


@interface NSDocument : NSObject
{											
	NSWindow *_window;
	NSMutableArray *_windowControllers;
    NSUndoManager *_undoManager;
	NSString *_documentName;
    NSString *_fileType;
    NSURL *_fileURL;

    struct __documentFlags {
		unsigned int isLocked:1;
		unsigned int hasUndoManager:1;
		unsigned int reserved:30;
	} _dc;
}

#if 0
+ (NSArray *) readableTypes;					// need subclass
+ (NSArray *) writableTypes;

- (id) initWithContentsOfURL:(NSURL *)aURL
					  ofType:(NSString *)name
					  error:(NSError **)outError;
#endif

- (id) initWithType:(NSString *)name error:(NSError **)outError;

- (void) close;

- (void) setFileURL:(NSURL *)aURL;
- (NSURL *) fileURL;

- (void) setFileType:(NSString *)name;
- (NSString *) fileType;

- (BOOL) isDocumentEdited;

- (void) showWindows;
- (void) setWindow:(NSWindow *)window;
- (NSString *) windowNibName;

- (NSArray *) windowControllers;
- (void) addWindowController:(NSWindowController *)controller;
- (void) removeWindowController:(NSWindowController *)controller;
- (void) windowControllerWillLoadNib:(NSWindowController *)controller;
- (void) windowControllerDidLoadNib:(NSWindowController *)controller;

#if 0

- (void) revertDocumentToSaved:(id)sender;		// (IBAction)
- (void) saveDocument:(id)sender;
- (void) saveDocumentAs:(id)sender;
- (void) saveDocumentTo:(id)sender;
- (void) lockDocument:(id)sender;
- (void) unlockDocument:(id)sender;
#endif

- (BOOL) hasUndoManager;
- (void) setHasUndoManager:(BOOL)hasUndoManager;
- (void) setUndoManager:(NSUndoManager *)undoManager;
- (NSUndoManager *) undoManager;

@end


@interface NSDocument (NotCocoa)

+ (NSString *) cleanedUpPath:(NSString *)filename;
+ (NSDocument *) documentForWindow:(NSWindow *)window;
+ (NSDocument *) documentForPath:(NSString *)filename;

- (NSWindow *) window;

- (void) setDocumentName:(NSString *)filename;
- (NSString *) documentName;

@end

#endif /* _mGSTEP_H_NSDocument */
