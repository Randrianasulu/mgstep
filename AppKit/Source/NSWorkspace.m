/*
   NSWorkspace.m

   Interface between applications and their filesystem file types 

   Copyright (C) 1996-2016 Free Software Foundation, Inc.

   Author:	Scott Christley <scottc@net-community.com>
   Date:	1996
   Author:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date:	1998
   Author:  Felipe A. Rodriguez <far@iillumenos.com>
   Date:	Feb 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSData.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSTask.h>
#include <Foundation/NSException.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSConnection.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSRunLoop.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSWorkspace.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSPanel.h>


#define WORKSPACE(n_name)		NSWorkspace##n_name##Notification


// Class variables
static NSWorkspace  *__sharedWorkspace = nil;
static NSMutableDictionary *__fileTypes = nil;
static NSMutableDictionary *__applications = nil;
static NSMutableArray *__appPaths = nil;
static NSString *__appSubPaths[] = {@"AppKit/Testing", @"bin", nil};


static NSArray *
__fileTypeInfo(NSString *extension)
{
	NSArray *a = [__fileTypes objectForKey: extension];

	return (a) ? a : [__fileTypes objectForKey:[extension lowercaseString]];
}


@implementation	NSWorkspace

+ (void) initialize
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	__sharedWorkspace = (NSWorkspace *)[self alloc];
	if (!(__fileTypes = [defaults objectForKey: @"FileTypes"]))
		{
		id d = [defaults persistentDomainForName:@"NSGlobalDomain"];

		NSRunAlertPanel(nil, @"Error opening user's defaults database",
						@"Continue", nil, nil);
		__fileTypes = [NSMutableDictionary new];
		[(NSMutableDictionary *)d setObject:__fileTypes forKey:@"FileTypes"];
		}
}

+ (NSWorkspace *) sharedWorkspace			{ return __sharedWorkspace; }
+ (id) alloc								{ return NSAllocateObject(self); }
- (id) init									{ return nil; }
- (void) dealloc							{ NO_WARN; }

- (BOOL) openFile:(NSString *)fullPath
{
	return [self openFile:fullPath withApplication:nil andDeactivate:YES];
}

- (BOOL) openFile:(NSString *)fullPath withApplication:(NSString *)appName
{
	return [self openFile:fullPath withApplication:appName andDeactivate:YES];
}

- (BOOL) openFile:(NSString *)fullPath
		 withApplication:(NSString *)appName
		 andDeactivate:(BOOL)flag
{
	NSString *n, *type;
	id ac = nil;

	NSLog(@"NSWorkspace open '%@' with '%@' \n", fullPath, appName);

	if (!fullPath)
		return NO;

	if (!appName || (!(appName = [self fullPathForApplication: appName])))
		if (![self getInfoForFile:fullPath application:&appName type:&type])
			return NO;

	n = [appName lastPathComponent];
	if ([n isEqualToString: [[NSProcessInfo processInfo] processName]])
		return [[NSApp delegate] application: nil openFile: fullPath];

#ifndef DISABLE_DO
	NS_DURING									// Try to contact a running app
		ac = [NSConnection rootProxyForConnectionWithRegisteredName:n host:@""];
	NS_HANDLER
		ac = nil;								// Fatal error in DO
	NS_ENDHANDLER
#endif  /* DISABLE_DO */

	if (flag)
		[NSApp deactivate];

	if (ac == nil)								// no app connection
		{
		NSArray *a = __fileTypeInfo([fullPath pathExtension]);
		id args;

		if (a && [a count] > 2)					// ddb format: {app,icon,params}
			{
			int i = 0, c;

			args = [[a objectAtIndex:2] componentsSeparatedByString:@" "];
			args = [[args mutableCopy] autorelease];
			c = [args count];

			while(i < c)
				{
				NSString *arg = [args objectAtIndex:i++];
				NSRange r = [arg rangeOfString:@"%s"];

				if(r.length > 0)
					{
					NSMutableString *b = [[arg mutableCopy] autorelease];

					[b replaceCharactersInRange:r withString:fullPath];
					[args replaceObjectAtIndex:i-1 withObject:b];
			}	}	}
		else
			args = [NSArray arrayWithObjects: fullPath, nil];

		[NSTask launchedTaskWithLaunchPath:appName arguments:args];

		if (flag)							// allow app to finish launching so
			{								// that mult files can be opened
			NSDate *d = [NSDate dateWithTimeIntervalSinceNow: 3];
			unsigned int mask = (NSSystemDefinedMask|NSAppKitDefinedMask);
			NSEvent *e;

			while ((e = [NSApp nextEventMatchingMask:mask
							   untilDate:d
							   inMode:NSDefaultRunLoopMode
							   dequeue:YES]))
				if ([e type] == NSSystemDefined)	// focus lost
					break;
		}	}
	else									// app connected via DO
    	{
		NS_DURING
			{
			[ac retain];
//			if (flag == NO)
//	    		[a application: nil openFileWithoutUI: fullPath];
//			else
				[ac application: nil openFile: fullPath];
			}
		NS_HANDLER
			{
			NSRunAlertPanel(nil, [NSString stringWithFormat:
							@"Failed to contact '%@' to open file", n],
							@"Continue", nil, nil);
			return NO;
			}
		NS_ENDHANDLER
		}

	return YES;
}

- (BOOL) selectFile:(NSString *)fullPath
		 inFileViewerRootedAtPath:(NSString *)rootFullpath
{
	NSLog(@"selectFile: %@",rootFullpath);
	return [self openFile:rootFullpath withApplication:nil andDeactivate:YES];
}

- (void) _taskDidTerminate:(NSNotification *)aNotification
{
	NSTask *task = (NSTask *)[aNotification object];
	int result;

	if ((result = [task terminationStatus]) == 0)
		{
		NSString *p = [task currentDirectoryPath];

		NSLog(@"workspace task ended normally");

		[self selectFile:p inFileViewerRootedAtPath:p];
		}
	else
		NSLog(@"workspace task exited with error code: %d", result);
}

/* ****************************************************************************

	performFileOperation

	tag returns 0 for sync op success, positive int which reflects op performed
	for async op success and a negative int on failure.

** ***************************************************************************/

- (BOOL) performFileOperation:(NSString *)operation
					   source:(NSString *)source
					   destination:(NSString *)destination
					   files:(NSArray *)files
					   tag:(int *)tag
{
	int result = NSAlertDefaultReturn;
	int count = [files count];
	NSFileManager *fm = [NSFileManager defaultManager];

	NSLog(@"performFileOperation %@", operation);
	
	if (!count)
		return NO;

	if(operation == NSWorkspaceMoveOperation)			 
		{
		*tag = -1;
		while (count--)
			{
			NSString *f = [files objectAtIndex: count];
			NSString *s = [source stringByAppendingPathComponent:f];
			NSString *d = [destination stringByAppendingPathComponent:f];
			NSString *a = [[NSProcessInfo processInfo] processName];

			if ([fm fileExistsAtPath:d])
				{
				NSString *m = @"File exists: %@";

				result = NSRunAlertPanel(a, m, @"Replace", @"Cancel", NULL, d);
				if (result != NSAlertDefaultReturn)
					return NO;
				if (![fm removeFileAtPath:d handler:self])
					return NO;
				}

			result = NSRunAlertPanel(a, @"Move: %@ to: %@ ?", @"Move",
											@"Cancel", NULL, f, d);		// FIX ME
			if (result == NSAlertDefaultReturn)
				if (![fm movePath:s toPath:d handler:self])
					return NO;
			}
		*tag = 0;
		}
	else if(operation == NSWorkspaceCopyOperation)
		{
		*tag = -2;
		while (count--)
			{
			NSString *f = [files objectAtIndex: count];
			NSString *s = [source stringByAppendingPathComponent:f];
			NSString *d = [destination stringByAppendingPathComponent:f];
			NSString *a = [[NSProcessInfo processInfo] processName];

			if ([fm fileExistsAtPath:d])
				{
				NSString *m = @"File exists: %@";

				result = NSRunAlertPanel(a, m, @"Replace", @"Cancel", NULL, d);
				if (result != NSAlertDefaultReturn)
					return NO;
				if (![fm removeFileAtPath:d handler:self])
					return NO;
				}
			
			result = NSRunAlertPanel(a,@"Copy: %@ ?",@"Copy",@"Cancel",NULL,s);

			if (result == NSAlertDefaultReturn)
				if (![fm copyPath:s toPath:d handler:self])
					return NO;
			}
		*tag = 0;
		}
	else if(operation == NSWorkspaceLinkOperation)
		{
		*tag = -3;
		while (count--)
			{
			NSString *f = [files objectAtIndex: count];
			NSString *s = [source stringByAppendingPathComponent:f];
			NSString *d = [destination stringByAppendingPathComponent:f];
			NSString *a = [[NSProcessInfo processInfo] processName];

			result = NSRunAlertPanel(a,@"Link: %@ ?",@"Link",@"Cancel",NULL,s);

			if (result == NSAlertDefaultReturn)
				if (![fm linkPath:s toPath:d handler:self])
					return NO;
			}
		*tag = 0;
		}
	else if(operation == NSWorkspaceDecompressOperation)
		{
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

		*tag = 5;
		while (count--)
			{
			BOOL tar = NO;
			NSArray *args;
			NSString *p, *f = [files objectAtIndex: count];
			NSString *s = [source stringByAppendingPathComponent:f];
			NSString *tmp;
			NSString *ext = [s pathExtension];
			NSTask *task;

			if(![fm isReadableFileAtPath:s])
				{
				NSString *a = [[NSProcessInfo processInfo] processName];

				if (NSRunAlertPanel(a, @"Read permission denied for file: %@",
					  @"Proceed", @"Stop", NULL, s) == NSAlertDefaultReturn)
					continue;

				return NO;
				}

			if ([ext isEqualToString: @"bz2"])
				{
				p = @"/usr/bin/bunzip2";
				if ([s rangeOfString: @".tar"].length > 0)
					tar = YES;
				}
			else if ([ext isEqualToString: @"gz"]
					|| [ext isEqualToString: @"Z"]
					|| [ext isEqualToString: @"z"])
				{
				p = @"/bin/gunzip";
				if ([s rangeOfString: @".tar"].length > 0)
					tar = YES;
				}
			else if ([ext isEqualToString: @"tgz"]
					|| [ext isEqualToString: @"taz"])
				{
				p = @"/bin/gunzip";
				tar = YES;
				}
			else if ([ext isEqualToString: @"xz"])
				p = @"/bin/tar xf";
			else if ([ext isEqualToString: @"tar"])
				p = @"/bin/tar xfpv";
			else
				{
				NSLog(@"Unhandled file ext: %@\n", ext);
				continue;
				}

			tmp = [NSString stringWithFormat:@"/tmp/%@.%d.workspace",
						f, (int)[NSDate timeIntervalSinceReferenceDate]];
NSLog(@"create temporary directory %@", tmp);

			if(![fm createDirectoryAtPath:tmp attributes:nil])
				return NO;

			if (tar)
				s = [NSString stringWithFormat:@"%@ -c %@ | tar xfpv -", p, s];
			else
				s = [NSString stringWithFormat:@"%@ %@", p, s];
			args = [NSArray arrayWithObjects: @"-c", s, nil];

NSLog(@"launching with str arg %@",s);
			task = [NSTask new];
			[task setCurrentDirectoryPath: tmp];
			[task setLaunchPath: @"/bin/sh"];
			[task setArguments: args];

			[nc addObserver: self
				selector: @selector(_taskDidTerminate:)
				name: NSTaskDidTerminateNotification
				object: task];
			[task launch];
		}	}
	else if(operation == NSWorkspaceDestroyOperation)
		{
		*tag = -8;
		while (count--)
			{
			NSString *f = [files objectAtIndex: count];
			NSString *s = [source stringByAppendingPathComponent: f];
			NSString *a = [[NSProcessInfo processInfo] processName];

			result = NSRunAlertPanel(a, @"Destroy path: %@ ?", @"Destroy", 
									 @"Cancel", NULL, s);
			if (result == NSAlertDefaultReturn)
				if (![fm removeFileAtPath:s handler:self])
					return NO;
			}
		*tag = 0;
		}
	else if(operation == NSWorkspaceRecycleOperation)
		{
		*tag = -9;
		while (count--)
			{
			NSString *f = [files objectAtIndex: count];
			NSString *s = [source stringByAppendingPathComponent:f];
			NSString *d = [@"/.NextTrash" stringByAppendingPathComponent:f];
			NSString *a = [[NSProcessInfo processInfo] processName];

			result = NSRunAlertPanel(a, @"Recycle: %@ to: %@?", @"Recycle", 
											@"Cancel", NULL, s, d);
			if (result == NSAlertDefaultReturn)
				if (![fm movePath:s toPath:d handler:self])
					return NO;
			}
		*tag = 0;
		}
	else if(operation == NSWorkspaceDuplicateOperation)
		{
		*tag = -10;
		while (count--)
			{
			NSString *f = [files objectAtIndex: count];
			NSString *n = [NSString stringWithFormat: @"CopyOf%@", f];
			NSString *s = [source stringByAppendingPathComponent:f];
			NSString *p = [source stringByAppendingPathComponent:n];

			if (![fm copyPath:s toPath:p handler:self])
				return NO;
			}
		*tag = 0;
		}
	else if(operation == NSWorkspaceCompressOperation)	*tag = -4;
	else if(operation == NSWorkspaceEncryptOperation)	*tag = -6;
	else if(operation == NSWorkspaceDecryptOperation)	*tag = -7;

	[NSNotificationCenter post:WORKSPACE(DidPerformFileOperation) object:self];

	return (result == NSAlertDefaultReturn) ? YES : NO;
}

/* ****************************************************************************

	fullPathForApplication:  return full app path, search if needed
	
	FIX ME validate with Info.plist ???
	file = [path stringByAppendingPathComponent:@"Resources/Info.plist"];
	info = [NSDictionary dictionaryWithContentsOfFile: file];
	file = [info objectForKey: @"NSExecutable"];
	if (file == nil)
		file = appName;

** ***************************************************************************/

- (NSString *) _searchBundleSubPathsFor:(NSString *)appWrap
{
	NSFileManager *fm = [NSFileManager defaultManager];
	unsigned int i, count;

	if (!(__appPaths))
		{
		NSString *s = [[NSBundle systemBundle] bundlePath];

		__appPaths = [[NSMutableArray alloc] initWithCapacity: 4];
		for (i = 0; __appSubPaths[i]; i++)
			{
			NSString *b = [s stringByAppendingPathComponent:__appSubPaths[i]];
			[__appPaths addObject: b];
			}
		}

	count = [__appPaths count];
	for (i = 0; i < count; i++)
		{						// search for app in bundle AppPaths
		NSString *p = [__appPaths objectAtIndex: i];
		NSArray *dc = [fm directoryContentsAtPath:p];
		NSEnumerator *de = [dc objectEnumerator];
		NSString *file;
		
		while (file = [de nextObject])
			if ([file isEqualToString: appWrap])
				return [NSString stringWithFormat:@"%@/%@", p, file];
		}

	return nil;
}

- (NSString *) fullPathForApplication:(NSString *)appName
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *lp = [appName lastPathComponent];
	NSString *fp = appName;
	NSString *appWrap = appName;
	BOOL is_dir = NO;

	if (__applications == nil)			// FIX ME need app paths, defaults ?
		__applications = [NSMutableDictionary new];

	if ([appName isEqual: lp])			// app name  (with or w/o .app ext)
		{								// ** must find full path
		if ([appName hasSuffix: @".app"])
			lp = [lp stringByDeletingPathExtension];
		else
			appWrap = nil;
										// app keys are app name w/o ext
		if (!(fp = [__applications objectForKey: lp]))
			{
			if (!appWrap)
				appWrap = [appName stringByAppendingPathExtension: @"app"];
			if ((fp = [self _searchBundleSubPathsFor: appWrap]))
				{
				[__applications setObject:fp forKey:lp];
				DBLog(@"set app full path %@ for key %@", fp, lp);
		}	}	}

	if (fp && [fm fileExistsAtPath:fp isDirectory:&is_dir])
		{								// full path  (with or w/o .app ext)
		if (is_dir)						// e.g. /path/V.app/V or /path/V.app
			{
			if ([lp hasSuffix: @".app"])
				lp = [lp stringByDeletingPathExtension];
			fp = [NSString stringWithFormat:@"%@/%@", fp, lp];	// V.app/V
			}

		if (![fm isExecutableFileAtPath:fp])
			NSLog(@"Error: app with full path %@ is not executable", fp);
		}
	else
		{
		if (fp)
			NSLog(@"Error: invalid app full path %@", fp);
		fp = nil;
		}

	return fp;
}

- (BOOL) getFileSystemInfoForPath:(NSString *)fullPath
					  isRemovable:(BOOL *)removableFlag
					  isWritable:(BOOL *)writableFlag
					  isUnmountable:(BOOL *)unmountableFlag
					  description:(NSString **)description
					  type:(NSString **)fileSystemType
{
	return NO;
}

- (BOOL) getInfoForFile:(NSString *)fullPath
			application:(NSString **)appName
			type:(NSString **)type
{
	NSFileManager *fm = [NSFileManager defaultManager];
	BOOL is_dir = NO;
	NSString *app = @"Workspace.app";
	NSString *ext;
	NSArray *a;

	if (![fm fileExistsAtPath:fullPath isDirectory:&is_dir])
		return NO;

	ext = [fullPath pathExtension];

	if (is_dir)										// some kind of dir
		{
//		*type = NSFilesystemFileType;				// file sys mount point
		*type = NSDirectoryFileType;

		if ([ext isEqualToString: @"app"])
			*type = NSApplicationFileType;
		}

	if ((a = __fileTypeInfo(ext)))
		{
		app = [a objectAtIndex: 0];
		if (*type != NSApplicationFileType)
			*type = ext;
		}
	else if (!is_dir)								// Workspace default if dir
		{
		app = @"Edit.app";
		*type = NSPlainFileType;
		}

	if (!(*appName = [self fullPathForApplication: app]))
		return NO;

	return YES;
}

- (NSImage *) iconForFile:(NSString *)fullPath
{
	NSFileManager *fm = [NSFileManager defaultManager];
	BOOL is_dir = NO;
	NSImage *img;
	NSString *ext;
	NSArray *a;

	if (![fm fileExistsAtPath:fullPath isDirectory:&is_dir])
		return [NSImage imageNamed: @"unknown.tiff"];

	ext = [fullPath pathExtension];

	if (is_dir)									// some type of directory
		{
		if ([ext isEqualToString: @"app"])
			return [NSImage imageNamed: @"host.tiff"];	// FIX ME s/b Info.plist icon

		if ((a = __fileTypeInfo(ext)))
			return [NSImage imageNamed: [a objectAtIndex: 1]];

		return [NSImage imageNamed: @"folder.tiff"];
		}
												// some type of file
	if ((img = [self iconForFileType: ext]))
		return img;
	if ([fm isExecutableFileAtPath:fullPath])
		return [NSImage imageNamed: @"unix.tiff"];

	return [NSImage imageNamed: @"text.tiff"];
}

- (NSImage *) iconForFiles:(NSArray *)pathArray
{
	return nil;		// FIX ME return icon for type or multiple selection icon
}

- (NSImage *) iconForFileType:(NSString *)fileType
{
	NSArray *a = __fileTypeInfo(fileType);

	return (a) ? [NSImage imageNamed: [a objectAtIndex: 1]] : nil;
}

- (BOOL) launchApplication:(NSString *)appName
{
	return [self launchApplication:appName showIcon:YES autolaunch:NO];
}

- (BOOL) launchApplication:(NSString *)appName
				  showIcon:(BOOL)showIcon
				  autolaunch:(BOOL)autolaunch
{
	NSString *path;

	NSLog(@"NSWorkspace launchApplication:  '%s'", [appName cString]);

	if (appName == nil || !(path = [self fullPathForApplication: appName]))
		return NO;
	
	NSLog(@"NSWorkspace launchApplication: '%s'\n", [path cString]);

	[NSTask launchedTaskWithLaunchPath: path arguments: nil];
	
	return YES;
}

- (BOOL) unmountAndEjectDeviceAtPath:(NSString *)path		{ return NO; }
- (NSArray *) mountedRemovableMedia							{ return nil; }
- (void) noteFileSystemChanged   { /* linux inotify, OSX FNNotifyByPath() API */ }

/* ****************************************************************************

	NSObject (NSFileManagerHandler)		*** OSX deprecated ***

	FIX ME remove related calling methods from NSFileManager

** ***************************************************************************/

- (void) fileManager:(NSFileManager *)manager willProcessPath:(NSString *)path
{
}

- (BOOL) fileManager:(NSFileManager *)manager
		 shouldProceedAfterError:(NSDictionary *)errorDict
{
	NSString *a = [[NSProcessInfo processInfo] processName];

	NSLog(@"NSWorkspace file operation error: '%@' with file: '%@'\n",
			[errorDict objectForKey:@"Error"],
			[errorDict objectForKey:@"Path"]);

	return (NSRunAlertPanel(a, @"File operation error: %@ with file: %@",
				@"Proceed", @"Stop", NULL, 
				[errorDict objectForKey:@"Error"],
				[errorDict objectForKey:@"Path"]) == NSAlertDefaultReturn);
}

@end
