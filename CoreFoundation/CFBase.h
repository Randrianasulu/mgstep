/*
   CFBase.h

   mini Core Foundation interface

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	September 2009

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CFBase
#define _mGSTEP_H_CFBase

#include <stdint.h>
#include <stdbool.h>


#define _CF_VERSION		((CFIndex) (mGSTEP_VERSION * 100000))


typedef unsigned short  UniChar;

typedef unsigned char   UInt8,  u8;
typedef unsigned short  UInt16, u16;
typedef unsigned int    UInt32, u32;

typedef char			SInt8,	s8;
typedef short			SInt16,	s16;
typedef int				SInt32,	s32;

typedef signed long		CFIndex;

typedef struct {
	CFIndex location;
	CFIndex length;
} CFRange;

static inline CFRange
CFRangeMake(CFIndex location, CFIndex length)
{
    CFRange r = (CFRange){location, length};

	return r;
}

typedef unsigned long	CFOptionFlags;
typedef unsigned long 	CFTypeID;		// unique identifier of each CF "class"

typedef double  CFTimeInterval;			// elapsed tine in seconds
typedef CFTimeInterval CFAbsoluteTime;	// FIX ME s/b in CFDate.h

extern const CFTimeInterval kCFAbsoluteTimeIntervalSince1970;
extern const CFTimeInterval kCFAbsoluteTimeIntervalSince1904;

		// absolute time interval since reference date of 00:00:00 1 Jan 2001
extern CFAbsoluteTime CFAbsoluteTimeGetCurrent(void);


typedef const struct _NSAttributedString        * CFAttributedStringRef;
typedef       struct _NSMutableAttributedString * CFMutableAttributedStringRef;

typedef const struct _NSData        * CFDataRef;
typedef       struct _NSMutableData * CFMutableDataRef;

typedef const struct _NSError * CFErrorRef;

typedef const struct _NSDictionary        * CFDictionaryRef;
typedef       struct _NSMutableDictionary * CFMutableDictionaryRef;

typedef const struct _NSNumber * CFNumberRef;

typedef const struct _NSURLRef * CFURLRef;
typedef const struct _NSURLRequest * CFURLRequestRef;
typedef const struct _NSURLResponse * CFURLResponseRef;

										// CF polymorphic functions operate
typedef const void * CFTypeRef;			// on opaque CF object types

extern CFTypeID	  CFGetTypeID(CFTypeRef cf);
extern CFTypeRef  CFRetain(CFTypeRef cf);
extern void       CFRelease(CFTypeRef cf);


typedef const struct _CFAllocator * CFAllocatorRef;

extern const CFAllocatorRef kCFAllocatorDefault;
extern const CFAllocatorRef kCFAllocatorNull;

extern void * CFAllocatorAllocate ( CFAllocatorRef a,
									CFIndex size,
									CFOptionFlags hint);

extern void * CFAllocatorReallocate ( CFAllocatorRef a,
									  void *ptr,
									  CFIndex size,
									  CFOptionFlags hint);

extern void CFAllocatorDeallocate (CFAllocatorRef a, void *ptr);


#endif  /* _mGSTEP_H_CFBase */
