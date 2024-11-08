/*
   CFSocket.h

   mini Core Foundation socket interface

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	September 2009

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CFSocket
#define _mGSTEP_H_CFSocket

#include <CoreFoundation/CFBase.h>


typedef struct _CFSocket * CFSocketRef;

typedef int CFSocketNativeHandle;

typedef enum {
	kCFSocketSuccess =  0,
	kCFSocketError	 = -1L,
	kCFSocketTimeout = -2L
} CFSocketError;

/* ****************************************************************************

	typedef void (*CFSocketCallBack) (  CFSocketRef scoket,
										CFSocketCallBackType callbackType,
										CFDataRef address,
										const void *data,
										void *info );
	scoket       -- CF socket trigger
	callbackType -- Bitwise OR of activity that triggered callback function
                      (Read, Accept and Data are mutually exclusive)
	address      -- CFData object with the contents of a struct sockaddr,
				     valid on kCFSocketAcceptCallBack or kCFSocketDataCallBack
	data         -- callback specific data.
				   + SInt32 error for bg failure of kCFSocketConnectCallBack
				   + ptr to CFSocketNativeHandle for kCFSocketAcceptCallBack **
				   + CFData with incoming data for kCFSocketDataCallBack **
	info         -- info member of CFSocketContext structure in CFSocket

	** FIX ME -- marked behavior is not implemented in mGSTEP

** ***************************************************************************/

typedef enum {
	kCFSocketNoCallBack		 = 0,
	kCFSocketReadCallBack	 = 1,  // Read connection, callback must do
	kCFSocketAcceptCallBack	 = 2,  // Accept connection, callback sent handle
	kCFSocketDataCallBack	 = 3,  // Read in bg ready, ret is CFData chunks
	kCFSocketConnectCallBack = 4,  // One-shot bg connect ready, ret 0 or error
	kCFSocketWriteCallBack	 = 8   // Kernel buffers allow further writing
} CFSocketCallBackType;

enum {													// socket CFOptionFlags
    kCFSocketAutomaticallyReenableReadCallBack	 = 1,
    kCFSocketAutomaticallyReenableAcceptCallBack = 2,
    kCFSocketAutomaticallyReenableDataCallBack	 = 3,
    kCFSocketAutomaticallyReenableWriteCallBack	 = 8,	// not reenabled
    kCFSocketLeaveErrors					     = 64,
    kCFSocketCloseOnInvalidate					 = 128
};

typedef void (*CFSocketCallBack)(CFSocketRef s,
								 CFSocketCallBackType type,
								 CFDataRef address,
								 const void *data,
								 void *info);

typedef struct {
	SInt32     protocolFamily;
	SInt32     socketType;
	SInt32     protocol;
	CFDataRef  address;
} CFSocketSignature;

typedef struct {
    CFIndex	version;	// callback:  0 = Obj-C selector, 1 = CFSocketCallBack
    void *info;
	const void *(*retain)(const void *info);
    void        (*release)(const void *info);
    CFStringRef (*copyDescription)(const void *info);
} CFSocketContext;


extern CFTypeID	CFSocketGetTypeID(void);

extern CFSocketRef	CFSocketCreateWithNative( CFAllocatorRef a,
											  CFSocketNativeHandle sock,
											  CFOptionFlags callBackTypes,
											  CFSocketCallBack callout,
											  const CFSocketContext *context );

extern CFSocketRef	CFSocketCreate( CFAllocatorRef a,
									int protocolFamily,
									int socketType,
									int protocol,
									CFOptionFlags callBackTypes,
									CFSocketCallBack callout,
									const CFSocketContext *context );

extern CFSocketError  CFSocketSetAddress(CFSocketRef s, CFDataRef address);
extern CFSocketError  CFSocketConnectToAddress(CFSocketRef s,
											   CFDataRef address,
											   CFTimeInterval timeout);
extern void  CFSocketInvalidate(CFSocketRef s);
extern bool  CFSocketIsValid(CFSocketRef s);

extern CFDataRef  CFSocketCopyAddress(CFSocketRef s);
extern CFDataRef  CFSocketCopyPeerAddress(CFSocketRef s);
extern void  CFSocketGetContext(CFSocketRef s, CFSocketContext *context);

extern CFSocketNativeHandle  CFSocketGetNative(CFSocketRef s);

extern CFOptionFlags  CFSocketGetSocketFlags(CFSocketRef s);
extern void  CFSocketSetSocketFlags(CFSocketRef s, CFOptionFlags flags);

extern void  CFSocketDisableCallBacks(CFSocketRef s, CFOptionFlags callBackTypes);
extern void  CFSocketEnableCallBacks(CFSocketRef s, CFOptionFlags callBackTypes);

extern CFSocketError  CFSocketSendData(CFSocketRef s,
									   CFDataRef address,
									   CFDataRef data,
									   CFTimeInterval timeout);



typedef struct {							// Private struct, DO NOT use
	void *class_pointer;
	void *cf_pointer;

	CFSocketNativeHandle sd;
	CFSocketSignature    sig;
	CFOptionFlags     	 flags;
	CFSocketCallBackType callBackTypes;
	CFSocketCallBack  	 callout;
	CFSocketContext 	*context;
	void *runLoopSource;
} CFSocket;


#if 0										// Not Implemented in mGSTEP

extern CFSocketRef
CFSocketCreateWithSocketSignature( CFAllocatorRef a,
								  const CFSocketSignature *signature,
								  CFOptionFlags callBackTypes,
								  CFSocketCallBack callout,
								  const CFSocketContext *context);
extern CFSocketRef
CFSocketCreateConnectedToSocketSignature( CFAllocatorRef a,
										 const CFSocketSignature *signature,
										 CFOptionFlags callBackTypes,
										 CFSocketCallBack callout,
										 const CFSocketContext *context,
										 CFTimeInterval timeout);
#endif

#endif  /* _mGSTEP_H_CFSocket */
