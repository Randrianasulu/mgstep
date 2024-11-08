/*
   CFStream.h

   mini Core Foundation stream interface

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	September 2009

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CFStream
#define _mGSTEP_H_CFStream


typedef const struct _CFStream * CFStreamRef;

typedef const struct _CFStream * CFReadStreamRef;
typedef const struct _CFStream * CFWriteStreamRef;


extern void
CFStreamCreatePairWithSocket( CFAllocatorRef alloc,
							  CFSocketNativeHandle socketHandle,
							  CFReadStreamRef *readStream,
							  CFWriteStreamRef *writeStream);

extern bool
CFReadStreamSetProperty( CFReadStreamRef s, CFStringRef key, CFTypeRef value);

extern bool
CFWriteStreamSetProperty(CFWriteStreamRef s, CFStringRef key, CFTypeRef value);

extern CFTypeRef
CFReadStreamCopyProperty(CFReadStreamRef s, CFStringRef propertyName);

extern CFTypeRef
CFWriteStreamCopyProperty(CFWriteStreamRef s, CFStringRef propertyName);

												// property set and copy keys
extern CFStringRef kCFStreamPropertyShouldCloseNativeSocket;

extern CFStringRef kCFStreamPropertySocketRemoteHostName;
extern CFStringRef kCFStreamPropertySocketRemotePortNumber;

#endif  /* _mGSTEP_H_CFStream */
