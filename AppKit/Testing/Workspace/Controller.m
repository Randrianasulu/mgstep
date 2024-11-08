/*
   Controller.m

   Controller object for mGSTEP Workspace

   Copyright (C) 1996-2016 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@ix.netcom.com>
   Date:	November 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <AppKit/AppKit.h>

#include "WindowShelf.h"
#include "Controller.h"
#include "Browser.h"
#include "Finder.h"
#include "Matrix.h"
#include "Cell.h"



@implementation Controller

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSRect wr = (NSRect){{100, 100}, {550, 580}};

	_shelf = [[WindowShelf alloc] initWithFrame:wr rows:3 cols:7 subView:nil];
	[[_shelf matrix] restoreState];
	[_shelf setTitle:@"Workspace"];
	[_shelf display];
	[_shelf orderFront:nil];
	
	{
	NSProcessInfo *pi = [NSProcessInfo processInfo];
	NSArray *args = [pi arguments];
	int i, count = [args count];

	for (i = 1; i < count; i++)
		{
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *a = [args objectAtIndex: i];
		NSString *p = a;
		BOOL isDir = NO, isApp = NO;

		if (![a isAbsolutePath])
			p = [[fm currentDirectoryPath] stringByAppendingPathComponent: a];
		
		DBLog(@"path: '%@'", p);

		if(![fm fileExistsAtPath:p isDirectory:&isDir])
			{
			NSLog(@"Path does not exist: '%@'", p);
			continue;
			}

		[[NSWorkspace sharedWorkspace] selectFile:a
									   inFileViewerRootedAtPath:p];
		}
	}
}

- (void) applicationWillTerminate:(NSNotification *)aNotification
{
	if ([self browser])
		{
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		int h = MAX(NSHeight([[_shelf browser] frame]),
					NSHeight([_shelf frame]) - 240);

		if (h < 100)
			return;

		[defaults setObject:[[NSNumber numberWithInt: h] stringValue]
				  forKey:@"Divider"];
		[defaults setObject: [[_shelf matrix] saveState] forKey: @"Shelf"];
		[defaults synchronize];
		}
}

- (BOOL) application:(NSApplication *)sender openFile:(NSString *)filename 
{
	NSFileManager *fm = [NSFileManager defaultManager];
	BOOL isDir = NO;

	if (![fm fileExistsAtPath:filename isDirectory:&isDir])
		return NO;
NSLog(@"openFile: %@",filename);
	if (isDir)
		return [[NSWorkspace sharedWorkspace] selectFile:nil
											  inFileViewerRootedAtPath:filename];

	[self performFileOperation:NSWorkspaceDecompressOperation
		  destination:filename];

    return YES;
}

- (Browser *) browser
{
	NSWindow *w = [NSApp keyWindow];

	if ([w respondsToSelector: @selector(browser)])
		return [(WindowShelf *)w browser];

	w = [NSApp mainWindow];
	if ([w respondsToSelector: @selector(browser)])
		return [(WindowShelf *)w browser];

	NSLog(@"Workspace browser could not be determined ***");

  	return nil;
}

- (NSString *) path
{															// query browser
  	return [[self browser] path];							// for it's path
}

- (BOOL) setPath:(NSString *)path					
{ 
  	return [[self browser] setPath: path];
}

- (void) doDoubleClick:(id)sender
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSMutableArray *files = [NSMutableArray new];
	NSBrowser *browser = [self browser];
	int count = 1;

	if([sender isKindOfClass: [NSBrowser class]])
		{
		NSArray *cells = [sender selectedCells];

		if ((count = [cells count]) == 1)
			[files addObject:[sender path]];
		else
			{
			NSString *path = [sender pathToColumn:[sender lastColumn]];
			NSEnumerator *e = [cells objectEnumerator];
			NSBrowserCell *cell;

			for(;(cell = [e nextObject]);)
				{
				NSString *f = [cell stringValue];
				NSString *s = [path stringByAppendingPathComponent:f];
	
				[files addObject:s];
		}	}	}
	else
		{
		id cell = [sender selectedCell];
		NSString *p = ([cell respondsToSelector: @selector(path)])
					? [cell path] : [cell stringValue];

		[files addObject:p];
		}

	while (count--)
		{
		NSString *p = [files objectAtIndex: count];
		BOOL isDir = NO, isApp = NO;

		if(![fm fileExistsAtPath:p isDirectory:&isDir])
			continue;

		if(isDir && !(isApp = [[p pathExtension] isEqualToString: @"app"]))
			{
			if(browser && ![p isEqualToString:[browser path]])
//				[self setPath: p];
				[[NSWorkspace sharedWorkspace] selectFile:nil
												inFileViewerRootedAtPath:p];
	
			continue;
			}

		NS_DURING											// open or launch
			[[NSWorkspace sharedWorkspace] openFile:p withApplication:nil];
		NS_HANDLER
			NSRunAlertPanel(nil, [localException reason], @"Continue",nil,nil);
		NS_ENDHANDLER
		}
}

- (void) doClick:(id)sender						{}

- (void) openAboutPanel:(id)menuCell
{
	if (!_aboutPanel)
		{
		[NSApp orderFrontStandardAboutPanel:self];
		[_applicationName setStringValue: @"Workspace.app"];
		[_applicationVersion setStringValue: APPKIT_VERSION];
		[_aboutPanel display];
		}
	[_aboutPanel center];
	[_aboutPanel orderFront: self];
}

- (void) openFinder:(id)menuCell
{
	[[Finder sharedFinder] display];
	[[Finder sharedFinder] makeKeyAndOrderFront:nil];
}

- (void) openXTerm:(id)menuCell
{
	NSBrowser *browser = [self browser];

	if (browser)
		{
		NSString *path = [browser pathToColumn:[browser lastColumn]];
		NSTask *t = [[NSTask new] autorelease];
		NSArray *args = [NSArray arrayWithObjects: @"-geometry", @"+165+12",
										@"-sl", @"256", @"-sb", @"-ls", nil];

		[t setCurrentDirectoryPath:path];
		[t setLaunchPath:@"/usr/X11/bin/xterm"];
		[t setArguments:args];
		[t launch];
		}
}

- (void) _subTaskDidTerminate:(NSNotification *)aNotification
{
	NSTask *t = [aNotification object];

	NSLog (@"_subTaskDidTerminate %@ (%d)", [t launchPath], [t terminationStatus]);
	
	// FIX ME show warning panel if exit != 0
}

- (void) openWith:(id)sender
{
	NSBrowser *browser = [self browser];

	NSLog (@"OpenWith %@ and ARGs %@", [_openWith stringValue], [_openWithArgs stringValue]);

	if (browser)
		{
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *lp = [_openWith stringValue];
		BOOL isDir;

		if ([fm fileExistsAtPath:lp isDirectory:&isDir] && !isDir)
			{
			NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
			NSTask *t = [[NSTask new] autorelease];
			NSString *path = [browser path];
			NSArray *args;

			if ([[_openWithArgs stringValue] length])
				{
				NSArray *a = [[_openWithArgs stringValue] componentsSeparatedByString: @" "];
				args = [a arrayByAddingObject: path];
				}
			else
				args = [NSArray arrayWithObjects: path, nil];

			[t setLaunchPath: lp];
			[t setArguments:args];

			if ([_openWithEnv stringValue])
				{
				NSDictionary *e = nil;			// FIX ME parse dict from str
				[t setEnvironment: e];
				}

			[nc addObserver: self
				selector: @selector(_subTaskDidTerminate:)
				name: NSTaskDidTerminateNotification
				object: t];

			[t launch];
			}
		}

///	if ([_openWithSave stringValue])
		// save params to DDB for filetype

	[[sender window] close];
}

- (void) openWithPanel:(id)menuCell
{
	if (!_openWithPanel)
		if (![NSBundle loadNibNamed:@"OpenWith.nib" owner:self])
			NSLog (@"Cannot load NIB file: OpenWith.nib");

	[_openWithPanel orderFront:self];
}

- (void) updateViewer:(id)menuCell
{
	NSBrowser *browser = [self browser];

	if (browser)
		[browser reloadColumn:[browser lastColumn]];
}

- (void) toggleView:(id)menuCell
{
  	return [[self browser] toggleBrowserView: self];
}

- (void) destroy:(id)menuCell
{
	[self performFileOperation:NSWorkspaceDestroyOperation destination:nil];
}

- (void) duplicate:(id)menuCell
{
	[self performFileOperation:NSWorkspaceDuplicateOperation destination:nil];
}

- (BOOL) performFileOperation:(NSString *)operation
				  destination:(NSString *)destination
{
	NSBrowser *browser = [self browser];
	NSMutableArray *files;
	NSString *source;
	int returnTag;

	if (!browser)
		NSLog(@"Workspace key window or its browser is invalid");

	if (operation == NSWorkspaceDestroyOperation
			|| operation == NSWorkspaceDecompressOperation
			|| operation == NSWorkspaceDuplicateOperation)
		{
		NSArray *cells = [browser selectedCells];
		NSEnumerator *e = [cells objectEnumerator];
		NSBrowserCell *cell;

		source = [browser pathToColumn:[browser selectedColumn]];
		files = [[NSMutableArray new] autorelease];
		for(;(cell = [e nextObject]);)
			[files addObject:[cell stringValue]];
		}
	else
		{
		NSPasteboard *p = [NSPasteboard pasteboardWithName:NSDragPboard];
		NSDictionary *d = [p propertyListForType:NSFilenamesPboardType];

		source = [d objectForKey:@"SourcePath"];
		files = [d objectForKey:@"SelectedFiles"];
		if ([files count] == 1)
			source = [source stringByDeletingLastPathComponent];
		}

	if ([[NSWorkspace sharedWorkspace] performFileOperation: operation
									   source: source
									   destination: destination
									   files:files
									   tag:&returnTag])
		{
		[browser reloadColumn:[browser lastColumn]];
///		if (b != _browser)
///			[_browser reloadColumn:[_browser lastColumn]];
		[(SplitView*)[browser superview] setFileSize:@""];
		
		return YES;
		}

	NSLog(@"Workspace file system operation failed");

	return NO;
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
	if ([[item title] isEqualToString: @"Open Folder..."])
		{
		Browser *browser = [self browser];

		if (browser)
			{
			NSFileManager *fm = [NSFileManager defaultManager];
			NSString *p = [browser path];
			BOOL isDir;

			if ([fm fileExistsAtPath:p isDirectory:&isDir] && isDir)
				return YES;
			}

		return NO;
		}

	return YES;
}
- (void) openFile:(id)menuCell
{
	Browser *browser = [self browser];

	if (browser)
		[self doDoubleClick: browser];
  	NSLog (@"openFile invoked from cell with title '%@'", [menuCell title]);
}

- (void) openFolder:(id)menuCell
{
	Browser *browser = [self browser];

	if (browser)
		[browser setPath: [browser path]];
  	NSLog (@"openFolder invoked from cell with title '%@'", [menuCell title]);
}

- (void) method:(id)menuCell
{
  	NSLog (@"method invoked from cell with title '%@'", [menuCell title]);
}

@end /* Controller */


@implementation	NSWorkspace (WorkspaceExtension)

- (BOOL) selectFile:(NSString *)fullPath
		 inFileViewerRootedAtPath:(NSString *)rootFullpath
{
	static NSRect wr = (NSRect){{200, 0}, {400, 400}};
	WindowShelf *shelf;

	shelf = [[WindowShelf alloc] initWithFrame:wr rows:1 cols:3 subView:nil];

	NSLog(@"NSWorkspace Browser setPath: %@", rootFullpath);
	[[shelf browser] setPath: rootFullpath];

	if (NSMinY(wr) <= 0 || (NSMinY(wr) - NSHeight(wr) - 50 <= 0))
		wr.origin.y = NSHeight([[NSScreen mainScreen] frame]) - 50;
	wr.origin = [shelf cascadeTopLeftFromPoint:wr.origin];

	if (!fullPath)
		fullPath = rootFullpath;
	[shelf setTitle: fullPath];
	[shelf display];
	[shelf orderFront:nil];

	return YES;
}

@end /* NSWorkspace (WorkspaceExtension) */


@implementation	NSScroller (Overlay)

+ (NSScrollerStyle) preferredScrollerStyle	{ return NSScrollerStyleOverlay; }

@end /* NSScroller (Overlay) */
