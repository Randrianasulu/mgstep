/*
   NSException.m

   Exception handler encapsulation class

   Copyright (C) 1993-2016 Free Software Foundation, Inc.

   Author:	Adam Fedor <fedor@boulder.colorado.edu>
   Date:	Mar 1995

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSException.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSDictionary.h>


NSString *NSGenericException               = @"NSGenericException";
NSString *NSInternalInconsistencyException = @"NSInternalInconsistencyException";
NSString *NSInvalidArgumentException       = @"NSInvalidArgumentException";
NSString *NSMallocException                = @"NSMallocException";
NSString *NSRangeException                 = @"NSRangeException";
NSString *NSParseErrorException            = @"NSParseErrorException";

NSUncaughtExceptionHandler *_NSUncaughtExceptionHandler = NULL;



static void
_NSFoundationUncaughtExceptionHandler(NSException *exception)
{
    fprintf(stderr, "%s: %s\n",
			[[exception name] cString], [[exception reason] cString]);
    abort();
}

void 
_NSAddHandler(NSHandler *handler)
{
	NSThread *thread = [NSThread currentThread];

    handler->next = thread->_exception_handler;
    thread->_exception_handler = handler;
}

void 
_NSRemoveHandler(NSHandler *handler)
{
	NSThread *thread = [NSThread currentThread];

    thread->_exception_handler = thread->_exception_handler->next;
}



@implementation NSException

+ (NSException *) exceptionWithName:(NSString *)name
							 reason:(NSString *)reason
							 userInfo:(NSDictionary *)userInfo 
{
    return [[[self alloc] initWithName:name 
						  reason:reason
						  userInfo:userInfo] autorelease];
}

+ (void) raise:(NSString *)name format:(NSString *)format,...
{
	va_list args;

    va_start(args, format);
    [self raise:name format:format arguments:args];
    va_end(args);						// FIXME: This probably doesn't matter,
}										// but va_end won't get called

+ (void) raise:(NSString *)name format:(NSString *)fmt arguments:(va_list)argl
{
	NSString *r = [NSString stringWithFormat:fmt arguments:argl];
	NSException *except = [self exceptionWithName:name reason:r userInfo:nil];

    [except raise];
}

- (id) initWithName:(NSString *)name 
			 reason:(NSString *)reason
			 userInfo:(NSDictionary *)userInfo 
{
    if ((self = [super init]))
		{
		e_name = [name retain];
		e_reason = [reason retain];
		e_info = [userInfo retain];
		}
	
    return self;
}

- (void) dealloc
{
	[e_name release],	e_name = nil;
	[e_reason release],	e_reason = nil;
	[e_info release],	e_info = nil;

	[super dealloc];
}

- (void) raise
{
	NSThread *thread;
	NSHandler *handler;
    
    if (_NSUncaughtExceptionHandler == NULL)
        _NSUncaughtExceptionHandler = _NSFoundationUncaughtExceptionHandler;

    thread = [NSThread currentThread];
    handler = thread->_exception_handler;
    if (handler == NULL)
    	_NSUncaughtExceptionHandler(self);
	else
		{
		thread->_exception_handler = handler->next;
		handler->exception = self;
		longjmp(handler->jumpState, 1);
		}
}

- (id) deepen
{
    e_name = [e_name copy];
    e_reason = [e_reason copy];
    e_info = [e_info copy];

    return self;
}

- (NSString *) name										{ return e_name; }
- (NSString *) reason									{ return e_reason; }
- (NSDictionary *) userInfo								{ return e_info; }

- (id) copy												{ return [self retain];}
- (id) replacementObjectForPortCoder:(NSPortCoder*)pc	{ return self; }

- (id) initWithCoder:(NSCoder *)aCoder
{
    if ((self = [super initWithCoder:aCoder]))
		{
		e_name = [[aCoder decodeObject] retain];
		e_reason = [[aCoder decodeObject] retain];
		e_info = [[aCoder decodeObject] retain];
		}

    return self;
}

- (void) encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeObject:e_name]; 
    [aCoder encodeObject:e_reason]; 
    [aCoder encodeObject:e_info]; 
}

@end  /* NSException */
