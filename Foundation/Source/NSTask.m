/*
   NSTask.m

   Task launching and management

   Copyright (C) 1998-2016 Free Software Foundation, Inc.

   Author:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: 	1998
   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	March 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSTask.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSNotificationQueue.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSFileHandle.h>

#include <sys/types.h>
#include <sys/signal.h>
#include <sys/wait.h>


#define NOTE(note_name) \
		[NSNotification notificationWithName: NSTask##note_name##Notification \
						object: self \
						userInfo: nil]

static void __catchChildExit(int sig);

// Class variables
static NSMutableArray *__taskList = nil;
static NSNotification *__taskDidTerminate = nil;
static NSNotificationQueue *__notificationQueue = nil;

NSString *NSTaskDidTerminateNotification = @"NSTaskDidTerminateNotification";



@implementation NSTask

- (void) _collectChild
{
    if (!_task.hasCollected) 
		{
		if (waitpid(_taskPID, &_terminationStatus, WNOHANG) == _taskPID) 
			{
			_task.hasCollected = YES;
			_task.hasTerminated = YES;

	    	if (WIFEXITED(_terminationStatus)) 
				_terminationStatus = WEXITSTATUS(_terminationStatus);
			}

    	if (_task.hasTerminated && !_task.hasNotified)
			{
			NSNotificationQueue *nq = [NSNotificationQueue defaultQueue];

			_task.hasNotified = YES;
			[nq enqueueNotification:NOTE(DidTerminate)
				postingStyle:NSPostASAP
				coalesceMask:NSNotificationNoCoalescing
				forModes:nil];
			[__taskList removeObject:self];
		}	}
}

+ (void) _taskDidTerminate:(NSNotification *)aNotification
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	NSEnumerator *enumerator = [__taskList reverseObjectEnumerator];
	NSTask *anObject;

	while ((anObject = (NSTask*)[enumerator nextObject]))
		if (!anObject->_task.hasCollected)
			[anObject _collectChild];

    [pool release];
}

+ (void) initialize
{
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

	[nc addObserver: self
		selector: @selector(_taskDidTerminate:)
		name: NSTaskDidTerminateNotification
		object: self];
	__taskList = [NSMutableArray new];
	__taskDidTerminate = [NOTE(DidTerminate) retain];
	[__taskDidTerminate _initSafe];
	__notificationQueue = [NSNotificationQueue defaultQueue];
}

+ (NSTask*) launchedTaskWithLaunchPath:(NSString*)path
							 arguments:(NSArray*)args
{
	NSTask *task = [NSTask new];

	task->_launchPath = [path retain];
	task->_arguments = [args retain];
    [task launch];

    return [task autorelease];
}

- (id) init
{
	_stdinDescriptor = 0;
	_stdoutDescriptor = 1;
	_stderrDescriptor = 2;

    return [super init];
}

- (void) dealloc
{
	[_arguments release];
	[_environment release];
	[_launchPath release];
	[_currentDirectoryPath release];

	[super dealloc];
}

- (NSDictionary*) environment
{
	if (_environment == nil && (!_task.hasLaunched))
		_environment = [[[NSProcessInfo processInfo] environment] retain];

	return _environment;
}

- (void) setEnvironment:(NSDictionary*)env
{
    if (_task.hasLaunched)
		[NSException raise: NSInvalidArgumentException
					 format: @"NSTask - task has been launched"];

	ASSIGN(_environment, env);
}

- (void) setArguments:(NSArray*)args
{
	if (_task.hasLaunched)
		[NSException raise: NSInvalidArgumentException
					 format: @"NSTask - task has been launched"];

	ASSIGN(_arguments, args);
}

- (void) setCurrentDirectoryPath:(NSString*)path
{
    if (_task.hasLaunched)
		[NSException raise: NSInvalidArgumentException
					 format: @"NSTask - task has been launched"];

	ASSIGN(_currentDirectoryPath, path);
}

- (void) setLaunchPath:(NSString*)path
{
    if (_task.hasLaunched)
		[NSException raise: NSInvalidArgumentException
					 format: @"NSTask - task has been launched"];

	ASSIGN(_launchPath, path);
}

- (NSString*) launchPath					{ return _launchPath; }
- (NSString*) currentDirectoryPath			{ return _currentDirectoryPath; }
- (NSArray*) arguments						{ return _arguments; }
- (id) standardInput						{ return _standardInput; }
- (id) standardOutput						{ return _standardOutput; }
- (id) standardError						{ return _standardError; }
- (int) processIdentifier					{ return _taskPID; }

- (BOOL) isRunning
{
	return (_task.hasLaunched == NO || _task.hasTerminated == YES) ? NO : YES;
}

- (int) terminationStatus
{
    if (_task.hasLaunched == NO)
		[NSException raise: NSInvalidArgumentException
					 format: @"NSTask - task has not yet launched"];
    if (_task.hasTerminated == NO)
		[NSException raise: NSInvalidArgumentException
					 format: @"NSTask - task has not yet terminated"];

    if (!_task.hasCollected)
		[self _collectChild];

    return _terminationStatus;
}

- (void) interrupt
{
    if (_task.hasLaunched == NO)
		[NSException raise:NSInvalidArgumentException
					 format:@"task has not yet launched"];

	if (!_task.hasTerminated)
		{
#ifdef HAVE_KILLPG
		killpg(_taskPID, SIGINT);
#else
		kill(_taskPID, SIGINT);
#endif
		}
}

- (void) launch
{
	int	i, pid;
	int	idesc = _stdinDescriptor;
	int	odesc = _stdoutDescriptor;
	int	edesc = _stderrDescriptor;
	const char *executable;
	const char *path = [_currentDirectoryPath cString];
	int argCount = [_arguments count];
	const char *args[argCount+2];
	NSDictionary *e = [self environment];
	int envCount = [e count];
	const char *envl[envCount+1];
	NSArray *k = [e allKeys];

    if (_task.hasLaunched)
		return;

    if (_launchPath == nil)
		[NSException raise: NSInvalidArgumentException
					 format: @"NSTask - no launch path set"];

	if (![[NSFileManager defaultManager] isExecutableFileAtPath:_launchPath])
		[NSException raise: NSInvalidArgumentException
					 format:@"NSTask: invalid launch path %@", _launchPath];

	[__taskList addObject:self];
														// set sig handler to
	(void)signal(SIGCHLD, __catchChildExit);			// catch child exit

    args[0] = executable = [_launchPath cString];
    for (i = 0; i < argCount; i++)
		args[i+1] = [[[_arguments objectAtIndex: i] description] cString];
    args[argCount+1] = 0;

    for (i = 0; i < envCount; i++)
		{
		NSString *s;
		id key = [k objectAtIndex: i];
		id val = [_environment objectForKey: key];
		const char *keyString = [key cString];
		const char *valString = [val cString];

		if (val)
			s = [NSString stringWithFormat:@"%s=%s", keyString, valString];
		else 
			s = [NSString stringWithFormat: @"%s=", keyString];

		envl[i] = [s cString];
		}
    envl[envCount] = 0;

    switch (pid = fork())				// fork to create a child process
   	 	{
		case -1:
			[NSException raise: NSInvalidArgumentException
						 format: @"NSTask - failed to create child process"];
    	case 0:
			if (idesc != 0)				// child -- fork return zero
				dup2(idesc, 0);
			if (odesc != 1)
				dup2(odesc, 1);
			if (edesc != 2)
				dup2(edesc, 2);
			if(path && chdir(path) == -1)
				NSLog(@"NSTask: unable to change directory to '%s'", path);
			execve(executable, (char *const *)args, (char *const *)envl);
			NSLog(@"NSTask: unable to execve '%s'", executable);
			exit(-1);

		default:						// parent -- fork returns PID of child
			_taskPID = pid;
			_task.hasLaunched = YES;
			if (_task.stdinIsPipe)
				[[_standardInput fileHandleForReading] closeFile];
			if (_task.stdoutIsPipe)
				[[_standardOutput fileHandleForWriting] closeFile];
			if (_task.stderrIsPipe && _standardOutput != _standardError)
				[[_standardError fileHandleForWriting] closeFile];
			break;
   	 	}
}

- (void) terminate
{
    if (_task.hasLaunched == NO)
		[NSException raise: NSInvalidArgumentException
					 format: @"NSTask - task has not yet launched"];

	if (!_task.hasTerminated)
		{
		_task.hasTerminated = YES;
#ifdef HAVE_KILLPG
		killpg(_taskPID, SIGTERM);
#else
		kill(_taskPID, SIGTERM);
#endif
		}
}

- (void) waitUntilExit
{
    while ([self isRunning]) 				// Poll at 1.0 second intervals
		{
		NSDate *d = [[NSDate alloc] initWithTimeIntervalSinceNow: 1.0];

		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:d];
		[d release];
		}
}

@end


@implementation NSTask (NSPipe_Support)

- (void) setStandardInput:(id)fh
{
	ASSIGN(_standardInput, fh);
	if ((_task.stdinIsPipe = [fh isKindOfClass:[NSPipe class]]))
		_stdinDescriptor = [[fh fileHandleForReading] fileDescriptor];
	else
		_stdinDescriptor = [fh fileDescriptor];
}

- (void) setStandardOutput:(id)fh
{
	ASSIGN(_standardOutput, fh);
	if ((_task.stdoutIsPipe = [fh isKindOfClass:[NSPipe class]]))
		_stdoutDescriptor = [[fh fileHandleForWriting] fileDescriptor];
	else
		_stdoutDescriptor = [fh fileDescriptor];
}

- (void) setStandardError:(id)fh
{
	ASSIGN(_standardError, fh);
	if ((_task.stderrIsPipe = [fh isKindOfClass:[NSPipe class]]))
		_stderrDescriptor = [[fh fileHandleForWriting] fileDescriptor];
	else
		_stderrDescriptor = [fh fileDescriptor];
}

@end  /* NSTask (NSPipe_Support) */


@implementation NSTask (PsuedoTerminals)

- (int) _standardInput						{ return _stdinDescriptor; }
- (int) _standardOutput						{ return _stdoutDescriptor; }
- (int) _standardError						{ return _stderrDescriptor; }
- (void) _setStandardInput:(int)fd			{ _stdinDescriptor = fd; }
- (void) _setStandardOutput:(int)fd			{ _stdoutDescriptor = fd; }
- (void) _setStandardError:(int)fd			{ _stderrDescriptor = fd; }

@end


static void
__catchChildExit(int sig)
{
	if(sig == SIGCHLD)
		[__notificationQueue enqueueNotification:__taskDidTerminate
							 postingStyle:NSPostASAP
							 coalesceMask:NSNotificationNoCoalescing
							 forModes:nil];
}
