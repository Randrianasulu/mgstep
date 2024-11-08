/*
   NSFileHandle.h

   File (descriptor) Handle wrapper object

   Copyright (C) 1997 Free Software Foundation, Inc.

   Author:	Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date:	1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSFileHandle
#define _mGSTEP_H_NSFileHandle

#include <Foundation/NSObject.h>

@class NSMutableArray;
@class NSMutableDictionary;
@class NSDate;
@class NSString;
@class NSData;
@class NSArray;


@interface NSFileHandle : NSObject
{
	NSMutableDictionary *_note;
	NSString *_description;
	int _writePos;
	NSMutableArray *_writeInfo;
	int _descriptor;
	void *_cfSocket;

	struct __FileHandleFlags {
		unsigned int closeOnDealloc:1;
		unsigned int isRegularFile:1;
		unsigned int isNonBlocking:1;
		unsigned int wasNonBlocking:1;
		unsigned int background:1;
		unsigned int awaitConnect:1;
		unsigned int acceptOK:1;
		unsigned int connectOK:1;
		unsigned int readOK:1;
		unsigned int writeOK:1;
		unsigned int reserved:22;
	} _fh;
}

+ (NSFileHandle*) fileHandleForReadingAtPath:(NSString*)path;
+ (NSFileHandle*) fileHandleForWritingAtPath:(NSString*)path;
+ (NSFileHandle*) fileHandleForUpdatingAtPath:(NSString*)path;

+ (NSFileHandle*) fileHandleWithStandardInput;
+ (NSFileHandle*) fileHandleWithStandardOutput;
+ (NSFileHandle*) fileHandleWithStandardError;
+ (NSFileHandle*) fileHandleWithNullDevice;

- (NSFileHandle*) initWithFileDescriptor:(int)desc;
- (NSFileHandle*) initWithFileDescriptor:(int)desc closeOnDealloc:(BOOL)flag;

- (int) fileDescriptor;								// Returning file handles

- (NSData*) availableData;							// Synchronous I/O ops
- (NSData*) readDataToEndOfFile;
- (NSData*) readDataOfLength:(unsigned int)len;
- (void) writeData:(NSData*)item;
													// Asynchronous I/O ops
- (void) acceptConnectionInBackgroundAndNotifyForModes:(NSArray*)modes;
- (void) acceptConnectionInBackgroundAndNotify;
- (void) readInBackgroundAndNotifyForModes:(NSArray*)modes;
- (void) readInBackgroundAndNotify;
- (void) readToEndOfFileInBackgroundAndNotifyForModes:(NSArray*)modes;
- (void) readToEndOfFileInBackgroundAndNotify;
- (void) waitForDataInBackgroundAndNotifyForModes:(NSArray*)modes;
- (void) waitForDataInBackgroundAndNotify;

- (unsigned long long) offsetInFile;				// Seek within a file
- (unsigned long long) seekToEndOfFile;
- (void) seekToFileOffset:(unsigned long long)pos;

- (void) closeFile;									// file operations
- (void) synchronizeFile;
- (void) truncateFileAtOffset:(unsigned long long)pos;

@end


@interface NSFileHandle (NSFileHandle_Extensions_NOT_OSX)

+ (NSFileHandle*) fileHandleAsClientInBackgroundAtAddress:(NSString*)address
												  service:(NSString*)service
												  protocol:(NSString*)protocol
												  forModes:(NSArray*)modes;

- (void) writeInBackgroundAndNotify:(NSData*)item forModes:(NSArray*)modes;

- (void) _checkWrite;
- (void) ignoreReadDescriptor;
- (void) ignoreWriteDescriptor;
- (void) postReadNotification;
- (void) postWriteNotification;
- (void) watchWriteDescriptor;

@end

													// Notification names
extern NSString *NSFileHandleConnectionAcceptedNotification;
extern NSString *NSFileHandleDataAvailableNotification;
extern NSString *NSFileHandleReadCompletionNotification;
extern NSString *NSFileHandleReadToEndOfFileCompletionNotification;

													// Note handler access keys
extern NSString *NSFileHandleNotificationDataItem;
extern NSString *NSFileHandleNotificationFileHandleItem;
extern NSString *NSFileHandleNotificationMonitorModes;

extern NSString *NSFileHandleError;

extern NSString *NSFileHandleOperationException;	// Exceptions


@interface NSPipe : NSObject
{
    NSFileHandle *_readFileHandle;
    NSFileHandle *_writeFileHandle;
}

+ (id) pipe;
- (id) init;

- (NSFileHandle*) fileHandleForReading;
- (NSFileHandle*) fileHandleForWriting;

@end

#endif /* _mGSTEP_H_NSFileHandle */
