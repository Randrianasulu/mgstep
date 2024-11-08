/*
   NSException.h

   Exception handler class interface

   Copyright (C) 1995-2016 Free Software Foundation, Inc.

   Author:	Adam Fedor <fedor@boulder.colorado.edu>
   Date:	1995

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSException
#define _mGSTEP_H_NSException

#include <Foundation/NSString.h>
#include <setjmp.h>
#include <stdarg.h>
#include <assert.h>

@class NSDictionary;


extern NSString *NSGenericException;					// Common exceptions
extern NSString *NSInternalInconsistencyException;
extern NSString *NSInvalidArgumentException;
extern NSString *NSParseErrorException;
extern NSString *NSMallocException;
extern NSString *NSRangeException;



@interface NSException : NSObject  <NSCoding, NSCopying>
{    
	NSString *e_name;
	NSString *e_reason;
	NSDictionary *e_info;
}

+ (NSException *) exceptionWithName:(NSString *)name
							 reason:(NSString *)reason
							 userInfo:(NSDictionary *)userInfo;

+ (void) raise:(NSString *)name format:(NSString *)format,...;
+ (void) raise:(NSString *)name format:(NSString *)fmt arguments:(va_list)argl;

- (id) initWithName:(NSString *)name 
			 reason:(NSString *)reason 
			 userInfo:(NSDictionary *)userInfo;
- (void) raise;

- (NSString *) name;									// Query Exception
- (NSString *) reason;
- (NSDictionary *) userInfo;

@end


typedef struct _NSHandler					// Exception handler definitions
{
    jmp_buf jumpState;						// place to longjmp to 
    struct _NSHandler *next;				// ptr to next handler
    NSException *exception;
} NSHandler;


typedef void NSUncaughtExceptionHandler(NSException *exception);

extern NSUncaughtExceptionHandler *_NSUncaughtExceptionHandler;

#define NSGetUncaughtExceptionHandler()      _NSUncaughtExceptionHandler
#define NSSetUncaughtExceptionHandler(proc) (_NSUncaughtExceptionHandler = (proc))

/* ****************************************************************************

   NS_DURING, NS_HANDLER and NS_ENDHANDLER are always used as:

      NS_DURING
	      some code which might raise an error
	  NS_HANDLER
	      code that will be jumped to if an error occurs
	  NS_ENDHANDLER

   If any error is raised within the first block of code, the second block
   of code will be jumped to.  Typically, this code will clean up any
   resources allocated in the routine, possibly case on the error code
   and perform special processing, and default to RERAISE the error to
   the next handler.  Within the scope of the handler, a local variable
   called exception holds information about the exception raised.

   It is illegal to exit the first block of code by any other means than
   NS_VALRETURN, NS_VOIDRETURN, or just falling out the bottom.

** ***************************************************************************/

// private support routines.  Do not call directly. 
extern void _NSAddHandler( NSHandler *handler );
extern void _NSRemoveHandler( NSHandler *handler );

#define NS_DURING { NSHandler NSLocalHandler;			\
		    _NSAddHandler(&NSLocalHandler);		\
		    if( !setjmp(NSLocalHandler.jumpState) ) {

#define NS_HANDLER _NSRemoveHandler(&NSLocalHandler); } else { \
		    NSException *localException;               \
		    localException = NSLocalHandler.exception;

#define NS_ENDHANDLER }}

#define NS_VALRETURN(val)  do { typeof(val) temp = (val);	\
			_NSRemoveHandler(&NSLocalHandler);	\
			return(temp); } while (0)
#define NS_VALUERETURN  NS_VALRETURN

#define NS_VOIDRETURN	do { _NSRemoveHandler(&NSLocalHandler);	\
			return; } while (0)

//
//	Asserts are compiled in only if DEBUG is defined
//
#ifdef DEBUG

#define NSAssert(condition, desc) assert(condition)
#define NSAssert5(condition,desc,arg1,arg2,arg3,arg4,arg5) assert(condition)
#define NSAssert4(condition, desc, arg1, arg2, arg3, arg4)	assert(condition)
#define NSAssert3(condition, desc, arg1, arg2, arg3) assert(condition)
#define NSAssert2(condition, desc, arg1, arg2) assert(condition)
#define NSAssert1(condition, desc, arg1) assert(condition)
#define NSParameterAssert(condition) assert(condition)	

#define NSCAssert5(condition,desc,arg1,arg2,arg3,arg4,arg5) assert(condition)
#define NSCAssert4(condition, desc, arg1, arg2, arg3, arg4)	assert(condition)
#define NSCAssert3(condition, desc, arg1, arg2, arg3) assert(condition)
#define NSCAssert2(condition, desc, arg1, arg2)	assert(condition)
#define NSCAssert1(condition, desc, arg1) assert(condition)
#define NSCAssert(condition, desc) assert(condition)
#define NSCParameterAssert(condition) assert(condition)

#else

#define NSAssert(condition, desc) //
#define NSAssert5(condition, desc, arg1, arg2, arg3, arg4, arg5) //
#define NSAssert4(condition, desc, arg1, arg2, arg3, arg4)	//
#define NSAssert3(condition, desc, arg1, arg2, arg3) //
#define NSAssert2(condition, desc, arg1, arg2) //
#define NSAssert1(condition, desc, arg1) //
#define NSParameterAssert(condition) //	

#define NSCAssert5(condition, desc, arg1, arg2, arg3, arg4, arg5) //
#define NSCAssert4(condition, desc, arg1, arg2, arg3, arg4)	//
#define NSCAssert3(condition, desc, arg1, arg2, arg3) //
#define NSCAssert2(condition, desc, arg1, arg2)	//
#define NSCAssert1(condition, desc, arg1) //
#define NSCAssert(condition, desc) //
#define NSCParameterAssert(condition) //

#endif /* DEBUG */

#endif /* _mGSTEP_H_NSException */
