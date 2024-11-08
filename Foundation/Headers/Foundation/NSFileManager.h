/*
   NSFileManager.h

   Copyright (C) 1997 Free Software Foundation, Inc.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>
   Author: Ovidiu Predescu <ovidiu@net-community.com>
   Date: Feb 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSFileManager
#define _mGSTEP_H_NSFileManager

#include <Foundation/NSObject.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSEnumerator.h>

@class NSNumber;
@class NSString;
@class NSData;
@class NSDate;
@class NSArray;
@class NSMutableArray;


@interface NSDirectoryEnumerator : NSEnumerator
{
    NSMutableArray *_enumStack;
    NSMutableArray *_pathStack;
    NSString *_fileName ;
    NSString *_filePath;
    NSString *_topPath;

    struct __FileEnumFlags {
		unsigned int shallow:1;
		unsigned int followLinks:1;
		unsigned int reserved:6;
	} _fm;
}

- (NSDictionary*) directoryAttributes;
- (NSDictionary*) fileAttributes;

- (void) skipDescendents;								// Skip subdirectories

@end /* NSDirectoryEnumerator */


@interface NSFileManager : NSObject

+ (NSFileManager*) defaultManager;
														// Directory operations
- (BOOL) changeCurrentDirectoryPath:(NSString*)path;
- (BOOL) createDirectoryAtPath:(NSString*)path
					attributes:(NSDictionary*)attributes;
- (NSString*) currentDirectoryPath;

- (BOOL) copyPath:(NSString*)source 					// File operations
		   toPath:(NSString*)destination
		   handler:handler;
- (BOOL) movePath:(NSString*)source 
		   toPath:(NSString*)destination 
		   handler:handler;
- (BOOL) linkPath:(NSString*)source 
		   toPath:(NSString*)destination
		   handler:handler;
- (BOOL) removeFileAtPath:(NSString*)path handler:handler;
- (BOOL) createFileAtPath:(NSString*)path 
				 contents:(NSData*)contents
				 attributes:(NSDictionary*)attributes;

- (NSData*) contentsAtPath:(NSString*)path;				// Access file contents
- (BOOL) contentsEqualAtPath:(NSString*)path1 andPath:(NSString*)path2;

- (BOOL) fileExistsAtPath:(NSString*)path;				// Detemine file access
- (BOOL) fileExistsAtPath:(NSString*)path isDirectory:(BOOL*)isDirectory;
- (BOOL) isReadableFileAtPath:(NSString*)path;
- (BOOL) isWritableFileAtPath:(NSString*)path;
- (BOOL) isExecutableFileAtPath:(NSString*)path;
- (BOOL) isDeletableFileAtPath:(NSString*)path;
														// Get / set attributes
- (NSDictionary*) fileAttributesAtPath:(NSString*)path traverseLink:(BOOL)flag;
- (NSDictionary*) fileSystemAttributesAtPath:(NSString*)path;
- (BOOL) changeFileAttributes:(NSDictionary*)attributes atPath:(NSString*)path;

- (NSArray*) directoryContentsAtPath:(NSString*)path;	// List dir contents
- (NSArray*) subpathsAtPath:(NSString*)path;
- (NSDirectoryEnumerator*) enumeratorAtPath:(NSString*)path;

- (BOOL) createSymbolicLinkAtPath:(NSString*)path		// Symbolic-link ops
					  pathContent:(NSString*)otherPath;
- (NSString*) pathContentOfSymbolicLinkAtPath:(NSString*)path;

													// Convert file-sys reps
- (const char*) fileSystemRepresentationWithPath:(NSString*)path;
- (NSString*) stringWithFileSystemRepresentation:(const char*)string
										  length:(unsigned int)len;
@end /* NSFileManager */


@interface NSObject (NSFileManagerHandler)

- (BOOL) fileManager:(NSFileManager*)fileManager
		 shouldProceedAfterError:(NSDictionary*)errorDictionary;
- (void) fileManager:(NSFileManager*)fileManager
		 willProcessPath:(NSString*)path;

@end /* NSObject (NSFileManagerHandler) */


extern NSString *NSFileSize;							// File Attributes
extern NSString *NSFileModificationDate;
extern NSString *NSFileOwnerAccountNumber;
extern NSString *NSFileOwnerAccountName;
extern NSString *NSFileGroupOwnerAccountNumber;
extern NSString *NSFileReferenceCount;
extern NSString *NSFileIdentifier;
extern NSString *NSFileDeviceIdentifier;
extern NSString *NSFilePosixPermissions;
extern NSString *NSFileType;

extern NSString *NSFileTypeDirectory;					// File Types
extern NSString *NSFileTypeRegular;
extern NSString *NSFileTypeSymbolicLink;
extern NSString *NSFileTypeSocket;
extern NSString *NSFileTypeFifo;
extern NSString *NSFileTypeCharacterSpecial;
extern NSString *NSFileTypeBlockSpecial;
extern NSString *NSFileTypeUnknown;

extern NSString *NSFileSystemSize;						// FileSystem Attribute
extern NSString *NSFileSystemFreeSize;
extern NSString *NSFileSystemNodes;
extern NSString *NSFileSystemFreeNodes;
extern NSString *NSFileSystemNumber;


@interface NSDictionary (NSFileAttributes)

- (unsigned long long) fileSize;
- (NSString*) fileType;
- (NSNumber*) fileOwnerAccountNumber;
- (NSNumber*) fileGroupOwnerAccountNumber;
- (NSUInteger) filePosixPermissions;
- (NSDate*) fileModificationDate;

#if 0  // FIX ME not yet implemented
- (NSDate *) fileCreationDate;
- (NSString *) fileOwnerAccountName;
- (NSString *) fileGroupOwnerAccountName;
- (NSInteger) fileSystemNumber;
- (NSUInteger) fileSystemFileNumber;
- (NSNumber *) fileOwnerAccountID;
- (NSNumber *) fileGroupOwnerAccountID;
#endif

@end

#endif /* _mGSTEP_H_NSFileManager */
