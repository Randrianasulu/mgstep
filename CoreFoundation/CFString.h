/*
   CFString.h

   mini Core Foundation string interface

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	September 2009

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CFString
#define _mGSTEP_H_CFString

#include <CoreFoundation/CFBase.h>

#define kCFStringEncodingInvalidId  (0xFFFFFFFFU)
#define kCFStringEncodingISOLatin1  (0x0201U)
#define kCFStringEncodingASCII      (0x0600U)
#define kCFStringEncodingUTF8       (0x08000100U)


typedef const struct _NSString        * CFStringRef;
typedef       struct _NSMutableString * CFMutableStringRef;

typedef UInt32 CFStringEncoding;

							// system defined C string encoding extracted from
						 	// MGSTEP_CSTRING_ENCODING environment variable
extern CFStringEncoding  CFStringGetSystemEncoding(void);
extern CFStringRef       CFStringGetNameOfEncoding( CFStringEncoding e);

extern const CFStringEncoding *CFStringGetListOfAvailableEncodings(void);
extern bool  CFStringIsEncodingAvailable(CFStringEncoding e);

extern UInt32 CFStringConvertEncodingToNSStringEncoding(CFStringEncoding e);

extern CFIndex CFStringGetBytes( CFStringRef s,
								 CFRange r,
								 CFStringEncoding e,
								 UInt8 lossByte,
								 bool isExternalRepresentation,
								 UInt8 *buffer,
								 CFIndex maxBufLen,
								 CFIndex *usedBufLen );

extern CFIndex CFStringGetLength(CFStringRef s);		// # of UniChars

extern void CFShow (CFTypeRef cf);				// print CF object description


#endif  /* _mGSTEP_H_CFString */
