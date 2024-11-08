/*
   CGDataProvider.h

   Callback function based data source.

   Copyright (C) 2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    May 2020

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CGDataProvider
#define _mGSTEP_H_CGDataProvider

typedef struct CGDataProvider *CGDataProviderRef;


extern CGDataProviderRef  CGDataProviderRetain (CGDataProviderRef dp);
extern void               CGDataProviderRelease (CGDataProviderRef dp);

/* ****************************************************************************

	Sequential data access callbacks

** ***************************************************************************/

typedef size_t (*CGDataProviderGetBytesCallback) (void *info,
												 void *buffer,
												 size_t count);

typedef void   (*CGDataProviderRewindCallback)(void *info);
typedef off_t  (*CGDataProviderSkipForwardCallback)(void *info, off_t count);
typedef void   (*CGDataProviderReleaseInfoCallback)(void *info);


typedef struct CGDataProviderSequentialCallbacks {
	unsigned int version;
	CGDataProviderGetBytesCallback     getBytes;
	CGDataProviderSkipForwardCallback  skipForward;
	CGDataProviderRewindCallback       rewind;
	CGDataProviderReleaseInfoCallback  releaseInfo;
} CGDataProviderSequentialCallbacks;


extern CGDataProviderRef
CGDataProviderCreateSequential( void *info,
								const CGDataProviderSequentialCallbacks *cb);

/* ****************************************************************************

	Direct data access callbacks

** ***************************************************************************/

typedef const void *(*CGDataProviderGetBytePointerCallback)(void *info);

typedef size_t (*CGDataProviderGetBytesAtPositionCallback) (void *info,
															void *buffer,
															off_t position,
															size_t count);

typedef void (*CGDataProviderReleaseBytePointerCallback) (void *info,
														  const void *pointer);

typedef struct CGDataProviderDirectCallbacks {
	unsigned int version;
	CGDataProviderGetBytePointerCallback      getBytePointer;
	CGDataProviderReleaseBytePointerCallback  releaseBytePointer;
	CGDataProviderGetBytesAtPositionCallback  getBytesAtPosition;
	CGDataProviderReleaseInfoCallback         releaseInfo;
} CGDataProviderDirectCallbacks;


extern CGDataProviderRef
CGDataProviderCreateDirect( void *info, off_t size,
							const CGDataProviderDirectCallbacks *cb);

extern CGDataProviderRef CGDataProviderCreateWithCFData(CFDataRef data);
extern CGDataProviderRef CGDataProviderCreateWithFilename(const char *path);

	// create a direct access provider with data array of size bytes,
	// calls release cb when provider is released
typedef void (*CGDataProviderReleaseDataCallback) (void *info,
												  const void *data,
												  size_t size);
extern CGDataProviderRef
CGDataProviderCreateWithData (void *info,
							  const void *data,
							  size_t size,
							  CGDataProviderReleaseDataCallback cb);

#endif /* _mGSTEP_H_CGDataProvider */
