/*
   NSTask.h

   Task launching and management

   Copyright (C) 2000-2016 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	September 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSTask
#define _mGSTEP_H_NSTask

#include <Foundation/NSObject.h>

@class NSDictionary;
@class NSArray;
@class NSString;
@class NSNotification;


@interface NSTask : NSObject
{
    NSString *_currentDirectoryPath;
    NSString *_launchPath;
    NSArray *_arguments;
    NSDictionary *_environment;

    id _standardInput;
    id _standardOutput;
    id _standardError;

    int _stdinDescriptor;
    int _stdoutDescriptor;
    int _stderrDescriptor;

    int _taskPID;
    int _terminationStatus;

    struct __taskFlags {
		unsigned int hasLaunched:1;
		unsigned int hasTerminated:1;
        unsigned int hasCollected:1;
        unsigned int hasNotified:1;
		unsigned int stdinIsPipe:1;
        unsigned int stdoutIsPipe:1;
        unsigned int stderrIsPipe:1;
        unsigned int reserved:1;
    } _task;
}

+ (NSTask*) launchedTaskWithLaunchPath:(NSString*)path 
							 arguments:(NSArray*)args;

- (NSArray*) arguments;								// Task attributes
- (NSString*) currentDirectoryPath;
- (NSString*) launchPath;
- (NSDictionary*) environment;

- (void) setArguments:(NSArray*)args;				// Set Task attributes
- (void) setCurrentDirectoryPath:(NSString*)path;
- (void) setEnvironment:(NSDictionary*)env;
- (void) setLaunchPath:(NSString*)path;

- (id) standardError;								// NSFileHandle or NSPipe
- (id) standardInput;
- (id) standardOutput;

- (BOOL) isRunning;									// Task state
- (int) terminationStatus;
- (int) processIdentifier;

- (void) launch;
- (void) interrupt;									// send SIGINT
- (void) terminate;									// send SIGTERM
- (void) waitUntilExit;

//- (BOOL) suspend;
//- (BOOL) resume;
//- (NSTaskTerminationReason) terminationReason;

@end


@interface NSTask (NSPipeSupport)

- (void) setStandardInput:(id)fh;					// NSFileHandle or NSPipe
- (void) setStandardOutput:(id)fh;
- (void) setStandardError:(id)fh;

@end


@interface NSTask (PsuedoTerminals)

- (int) _standardError;
- (int) _standardInput;
- (int) _standardOutput;

- (void) _setStandardError:(int)fd;
- (void) _setStandardInput:(int)fd;
- (void) _setStandardOutput:(int)fd;

@end


extern NSString *NSTaskDidTerminateNotification;


#if 0  /* NOT IMPLEMENTEDD */
typedef struct {
    NSTaskTerminationReasonExit           = 1,
    NSTaskTerminationReasonUncaughtSignal = 2
} NSTaskTerminationReason;
#endif /* NOT IMPLEMENTEDD */

#endif /* _mGSTEP_H_NSTask */
