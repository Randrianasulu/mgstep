/*
   NSWorkspace.h

   Interface between applications and their filesystem file types 

   Copyright (C) 1996-2016 Free Software Foundation, Inc.

   Author:	Scott Christley <scottc@net-community.com>
   Date:	1996

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSWorkspace
#define _mGSTEP_H_NSWorkspace

#include <Foundation/NSObject.h>
#include <Foundation/NSGeometry.h>

@class NSString;
@class NSArray;
@class NSNotificationCenter;
@class NSImage;
@class NSView;


@interface NSWorkspace : NSObject

+ (NSWorkspace *) sharedWorkspace;

- (BOOL) openFile:(NSString *)fullPath;						// Open files
- (BOOL) openFile:(NSString *)fullPath withApplication:(NSString *)appName;
- (BOOL) openFile:(NSString *)fullPath
		 withApplication:(NSString *)appName
		 andDeactivate:(BOOL)flag;

- (BOOL) performFileOperation:(NSString *)operation			// Manipulate files
					   source:(NSString *)source
					   destination:(NSString *)destination
					   files:(NSArray *)files
					   tag:(int *)tag;

- (BOOL) selectFile:(NSString *)fullPath
		 inFileViewerRootedAtPath:(NSString *)rootFullpath;

- (BOOL) getFileSystemInfoForPath:(NSString *)fullPath		// File information
					  isRemovable:(BOOL *)removableFlag
					  isWritable:(BOOL *)writableFlag
					  isUnmountable:(BOOL *)unmountableFlag
					  description:(NSString **)description
					  type:(NSString **)fileSystemType;
- (BOOL) getInfoForFile:(NSString *)fullPath
			application:(NSString **)appName
			type:(NSString **)type;

- (NSString *) fullPathForApplication:(NSString *)appName;

- (NSImage *) iconForFile:(NSString *)fullPath;
- (NSImage *) iconForFiles:(NSArray *)pathArray;
- (NSImage *) iconForFileType:(NSString *)fileType;

- (BOOL) launchApplication:(NSString *)appName;				// Launch Apps
- (BOOL) launchApplication:(NSString *)appName
				 showIcon:(BOOL)showIcon
				 autolaunch:(BOOL)autolaunch;
@end


@interface NSWorkspace  (NotImplemented)

- (BOOL) unmountAndEjectDeviceAtPath:(NSString *)path;

- (NSNotificationCenter *) notificationCenter;

- (void) hideOtherApplications;

@end


extern NSString *NSWorkspaceDidMountNotification;		// Notifications
extern NSString *NSWorkspaceDidLaunchApplicationNotification;	
extern NSString *NSWorkspaceDidPerformFileOperationNotification;
extern NSString *NSWorkspaceDidTerminateApplicationNotification;
extern NSString *NSWorkspaceDidUnmountNotification;
extern NSString *NSWorkspaceWillLaunchApplicationNotification;
extern NSString *NSWorkspaceWillPowerOffNotification;
extern NSString *NSWorkspaceWillUnmountNotification;


extern NSString *NSPlainFileType;						// File system types
extern NSString *NSDirectoryFileType;
extern NSString *NSApplicationFileType;
extern NSString *NSFilesystemFileType;
extern NSString *NSShellCommandFileType;


extern NSString *NSWorkspaceCompressOperation;			// File operations
extern NSString *NSWorkspaceCopyOperation;
extern NSString *NSWorkspaceDecompressOperation;
extern NSString *NSWorkspaceDecryptOperation;
extern NSString *NSWorkspaceDestroyOperation;
extern NSString *NSWorkspaceDuplicateOperation;
extern NSString *NSWorkspaceEncryptOperation;
extern NSString *NSWorkspaceLinkOperation;
extern NSString *NSWorkspaceMoveOperation;
extern NSString *NSWorkspaceRecycleOperation;

#endif /* _mGSTEP_H_NSWorkspace */
