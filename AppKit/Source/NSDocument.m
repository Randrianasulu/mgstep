/*
   NSDocument.m

   Abstract class that represents file based documents rendered in a window.

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@ix.netcom.com>
   Date:	Sept 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSUndoManager.h>
#include <Foundation/NSURL.h>

#include <AppKit/NSApplication.h>
#include <AppKit/NSDocument.h>
#include <AppKit/NSWindow.h>



@implementation NSDocument

- (id) initWithType:(NSString *)name error:(NSError **)outError
{
	if ((self = [self init]))
		[self setFileType:name];

	return self;
}

- (void) close								{ [_window close]; }	// FIX ME
- (NSString *) fileType						{ return _fileType; }
- (void) setFileType:(NSString *)name		{ ASSIGN(_fileType, name); }
- (NSURL *) fileURL							{ return _fileURL; }
- (void) setFileURL:(NSURL *)aURL			{ ASSIGN(_fileURL, aURL); }
- (void) setWindow:(NSWindow *)window		{ ASSIGN(_window, window); }
- (BOOL) isDocumentEdited					{ return [_window isDocumentEdited]; }

- (void) dealloc
{
    [_window setDelegate:nil];
    [_documentName release];
    [_undoManager release];
    [super dealloc];
}

- (BOOL) hasUndoManager						{ return _dc.hasUndoManager; }

- (void) setHasUndoManager:(BOOL)hasUndoManager
{
	if (_undoManager && !hasUndoManager)
		ASSIGN(_undoManager, nil);
	_dc.hasUndoManager = hasUndoManager;
}

- (void) setUndoManager:(NSUndoManager *)undoManager
{
	// record undo manager and registers as an observer of NSUndoManager notes 
}

- (NSUndoManager *) undoManager
{
	if (!_undoManager && _dc.hasUndoManager)
		_undoManager = [[NSUndoManager alloc] init];
		
	return _undoManager;
}

- (void) makeWindowControllers
{
	NSWindowController *wc;
	NSString *windowNibName;

	if ((windowNibName = [self windowNibName]))
		{
		NSWindowController *wc = [NSWindowController alloc];
		
		[self windowControllerWillLoadNib: wc];
		if ((wc = [wc initWithWindowNibName:windowNibName owner:self]))
			{
			[self windowControllerDidLoadNib: wc];
			[self addWindowController: wc];
			}
		}
}

- (void) showWindows
{
	[_windowControllers makeObjectsPerformSelector: @selector(showWindow:)
						withObject:self];
}

- (void) addWindowController:(NSWindowController *)controller
{
	if (!_windowControllers)
		_windowControllers = [NSMutableArray new];
	[_windowControllers addObject: controller];
}

- (void) removeWindowController:(NSWindowController *)controller
{
	[_windowControllers removeObject: controller];
}

- (NSArray *) windowControllers
{
	return (NSArray *)_windowControllers;
}

- (void) windowControllerWillLoadNib:(NSWindowController *)wc	{ }
- (void) windowControllerDidLoadNib:(NSWindowController *)wc	{ }
- (NSString *) windowNibName									{ return nil; }

@end  /* NSDocument */


@implementation NSDocument (NotCocoa)

+ (NSDocument *) documentForWindow:(NSWindow *)window 
{
	id d = [window delegate];							// Return document in 
														// specified window.
	return ((d) && [d isKindOfClass:[NSDocument class]]) ? d : nil;
}

+ (NSString *) cleanedUpPath:(NSString *)filename 
{
	NSString *resolvedSymlinks = [filename stringByResolvingSymlinksInPath];

    if ([resolvedSymlinks length] > 0) 
		{
		NSString *standardized = [resolvedSymlinks stringByStandardizingPath];

        return [standardized length] ? standardized : resolvedSymlinks;
		}

    return filename;
}

+ (NSDocument *) documentForPath:(NSString *)filename 
{												
	NSArray *windows = [NSApp windows];
	unsigned i, numWindows = [windows count];

	filename = [self cleanedUpPath:filename];		// Clean up incoming path 

    for (i = 0; i < numWindows; i++) 				// Return an existing doc
		{											// if one exists
		NSWindow *w = [windows objectAtIndex:i];
        NSDocument *document = [self documentForWindow: w];
		NSString *docName = [document documentName];	

		if ((docName) && [filename isEqual:[self cleanedUpPath:docName]]) 
			return document;
		}

	return nil;
}

- (void) setDocumentName:(NSString *)name		{ ASSIGN(_documentName,name); }
- (NSString *) documentName 					{ return _documentName; }
- (NSWindow *) window							{ return _window; }

- (void) windowWillClose:(NSNotification *)notification 
{											
	NSLog(@"Document: windowWillClose");
    [self release];
}

@end  /* NSDocument (NotCocoa) */
