/*
   FileManager.m

   File manager GUI

   Copyright (C) 2001 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:	November 2001

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSFileManager.h>
#include <AppKit/AppKit.h>

#include <fcntl.h>


NSDictionary *__errorDict = nil;


@interface NSFileManager (WorkspaceMethods)
												// Copies contents of src file 
- (BOOL) _copyFile:(NSString*)source 			// to dest file. Assumes source
			toFile:(NSString*)destination		// and dest are regular files
			handler:handler;					// or symbolic links.

- (BOOL) _handleError:(NSString*)e atPath:(NSString*)path handler:(id)handler;

@end


@interface FileCopier : NSObject
{
@public
	NSString *source;
	NSString *dest;
	id eh;

	NSFileManager *_fm;
	NSLevelIndicator *level;

	BOOL _interrupt;

	int fmode;
	unsigned long long fsize;
}

- (BOOL) copyFile:(NSAlert *)alert;
- (void) interrupt;

@end


@implementation FileCopier

- (void) interrupt
{
	_interrupt = YES;
}

- (BOOL) copyFile:(NSAlert *)alert
{
	const char *cpath = [_fm fileSystemRepresentationWithPath:source];
	unsigned long long i;
	int sourceFd, destFd;
	int rbytes, wbytes;
	int bufsize = 8096;
	char buffer[bufsize];
												// Open source file. In case
    if ((sourceFd = open(cpath, O_RDONLY)) < 0) // of error call the handler
		return [_fm _handleError:@"open" atPath:source handler:eh];
												// Do the same for destination
	cpath = [_fm fileSystemRepresentationWithPath:dest];
    if ((destFd = open(cpath, O_WRONLY|O_CREAT|O_TRUNC, fmode)) < 0)
		{
		close (sourceFd);

		return [_fm _handleError:@"open" atPath:dest handler:eh];
		}
							// errors call the handler and abort the operation.
    for (i = 0; i < fsize; i += rbytes)
		{
		if ((rbytes = read(sourceFd, buffer, bufsize)) < 0) 
			{					// Read bytes from source file and write them
			close(sourceFd);	// into the destination file. In case of errors
			close(destFd);		// call the handler and abort the operation.

			return [_fm _handleError:@"read" atPath:source handler:eh];
			}

		if (_interrupt)
			break;
		[level setDoubleValue:i];

		if ((wbytes = write(destFd, buffer, rbytes)) != rbytes) 
			{
			close(sourceFd);
			close(destFd);

			return [_fm _handleError:@"write" atPath:dest handler:eh];
		}	}

    close(sourceFd);
    close(destFd);

//	[NSApp stopModalWithCode: (i == fsize) ? 7 : -1];		// success
	[level setDoubleValue:i];
	[alert setInformativeText: @"Copy complete"];
	[[[alert buttons] objectAtIndex: 0] setTitle: @"Ok"];

	[NSThread exit];
	
	return YES;
}

@end

/* ****************************************************************************

		FileManager (WorkspaceMethods)

** ***************************************************************************/

@implementation NSFileManager  (PrivateMethods)

- (BOOL) _copyFile:(NSString*)source toFile:(NSString*)dest handler:(id)eh
{
	NSDictionary *at = [self fileAttributesAtPath:source traverseLink:NO];
	NSAlert *ca = [NSAlert alertWithMessageText:@"Progress Panel"
						   defaultButton:@"Cancel"
						   alternateButton:nil
						   otherButton:nil
						   informativeTextWithFormat:@"Copying..."];
	NSPanel *p = [ca window];

	NSLevelIndicator *level;
	NSRect levelRect = {{56, 70}, {250, 12}};
	int code;

	FileCopier *fc = [FileCopier new];

    fc->fsize = [[at objectForKey: NSFileSize] unsignedLongLongValue];
    fc->fmode = [[at objectForKey: NSFilePosixPermissions] intValue];

	level = [[NSLevelIndicator alloc] initWithFrame:levelRect];
	[level setMinValue:1];
	[level setMaxValue:fc->fsize];
	[level setDoubleValue:1];
	[level setContinuous:YES];
	[[p contentView] addSubview:level];
	[[p contentView] display];


	fc->source = [source retain];
	fc->dest = [dest retain];
	fc->eh = [eh retain];
	fc->_fm = self;

	fc->level = level;

		[NSThread detachNewThreadSelector:@selector(copyFile:)
				  toTarget:fc
				  withObject: ca];

										// Assumes source is file and exists
    NSAssert1([self fileExistsAtPath:source], @"source '%@' missing", source);
    NSAssert1(at, @"could not get the attributes for file '%@'", source);

	[p center];
	code = [NSApp runModalForWindow: p];
	[fc interrupt];
	[p orderOut: nil];

	if (code == 9)
		{
		NSString *a = [[NSProcessInfo processInfo] processName];

		return (NSRunAlertPanel(a, @"File operation error: %@ with file: %@",
					@"Proceed", @"Stop", NULL, 
					[__errorDict objectForKey:@"Error"],
					[__errorDict objectForKey:@"Path"]) == NSAlertDefaultReturn);
		}

///	[ca release];
//	NSReleaseAlertPanel(p);

    return YES;
}

@end  /* FileManager */


@implementation NSWorkspace  (PrivateMethods)

- (BOOL) fileManager:(NSFileManager *)fm
		 shouldProceedAfterError:(NSDictionary *)errorDict
{
	NSLog(@"NSWorkspace file operation error: '%@' with file: '%@'\n",
			[errorDict objectForKey:@"Error"],
			[errorDict objectForKey:@"Path"]);

	ASSIGN(__errorDict, errorDict);
	if (([NSApp modalWindow]))
		{
		[NSApp stopModalWithCode: 9];
		[NSThread exit];
		}

	return (NSRunAlertPanel([[NSProcessInfo processInfo] processName],
				@"File operation error: %@ with file: %@",
				@"Proceed", @"Stop", NULL, 
				[errorDict objectForKey:@"Error"],
				[errorDict objectForKey:@"Path"]) == NSAlertDefaultReturn);
}

@end  /* FileManager */
