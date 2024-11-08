/*
   NSDistributedLock.m

   Restrict access to resources shared by multiple apps.

   Copyright (C) 1997-2016 Free Software Foundation, Inc.

   Author:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date:    1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSDistributedLock.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSException.h>
#include <Foundation/NSValue.h>

#include <fcntl.h>



@implementation NSDistributedLock

+ (NSDistributedLock*) lockWithPath:(NSString*)aPath
{
    return [[[self alloc] initWithPath: aPath] autorelease];
}

- (void) breakLock
{
	NSFileManager *fileManager = [NSFileManager defaultManager];

	if ([fileManager removeFileAtPath: _lockPath handler: nil] == NO)
		[NSException raise: NSGenericException 
					 format: @"Failed to remove lock directory '%@' - %s",
					 		_lockPath, strerror(errno)];
	[_lockTime release];
	_lockTime = nil;
}

- (void) dealloc
{
	[_lockPath release];
	[_lockTime release];
	[super dealloc];
}

- (NSDistributedLock*) initWithPath:(NSString*)aPath
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *lockDir = [aPath stringByDeletingLastPathComponent];
	BOOL isDir = NO;

	if (![fm fileExistsAtPath:lockDir isDirectory:&isDir])
		return _NSInitError(self, @"lock '%@' invalid path", aPath);
	if (!isDir)
		return _NSInitError(self, @"lock '%@' invalid dir path", aPath);
	if ([fm isWritableFileAtPath:lockDir] == NO)
		return _NSInitError(self, @"lock '%@' dir not writable", aPath);
	if ([fm isExecutableFileAtPath:lockDir] == NO)
		return _NSInitError(self, @"lock '%@' dir not accessible", aPath);

	_lockPath = [aPath copy];

	return self;
}

- (NSDate*) lockDate
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSDictionary *a = [fm fileAttributesAtPath:_lockPath traverseLink:YES];

	return [a objectForKey: NSFileModificationDate];
}

- (BOOL) tryLock
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSMutableDictionary *a = [NSMutableDictionary dictionaryWithCapacity: 1];
	NSDictionary *d;

	[a setObject: [NSNumber numberWithUnsignedInt: 0755]
		  forKey: NSFilePosixPermissions];
	
	if ([fm createDirectoryAtPath:_lockPath attributes:a] == NO)
		{
		BOOL isDir;
	
		if ([fm fileExistsAtPath:_lockPath isDirectory:&isDir] == NO || !isDir)
			[NSException raise: NSGenericException 
						 format: @"Failed to create lock directory '%@' - %s",
						 		_lockPath, strerror(errno)];
		[_lockTime release];
		_lockTime = nil;

		return NO;
		}

	d = [fm fileAttributesAtPath:_lockPath traverseLink:YES];
	[_lockTime release];
	_lockTime = [[d objectForKey: NSFileModificationDate] retain];

	return YES;
}

- (void) unlock
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSDictionary *attributes;

	if (_lockTime == nil)
		[NSException raise:NSGenericException format:@"locked by another app"];

				// Don't remove the lock if it has already been broken by
				// someone else and re-created.  Unfortunately, there is a 
				// window between testing and removing, we do the best we can.
	attributes = [fileManager fileAttributesAtPath:_lockPath traverseLink:YES];
	if ([_lockTime isEqual: [attributes objectForKey: NSFileModificationDate]])
		{
		if ([fileManager removeFileAtPath: _lockPath handler: nil] == NO)
			[NSException raise: NSGenericException
						 format: @"Failed to remove lock directory '%@' - %s",
						 		_lockPath, strerror(errno)];
		}
	else
		NSLog(@"lock '%@' already broken and in use again\n", _lockPath);
	
	[_lockTime release];
	_lockTime = nil;
}

@end
