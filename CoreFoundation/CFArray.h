/*
   CFArray.h

   mini Core Foundation array  (bridged to NSArray)

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	September 2009

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CFArray
#define _mGSTEP_H_CFArray

typedef const struct _NSArray        * CFArrayRef;
typedef       struct _NSMutableArray * CFMutableArrayRef;


extern CFArrayRef CFArrayCreate ( CFAllocatorRef a,
								  const void **values,
								  CFIndex numValues,
								  const void *callBacks);

#endif  /* _mGSTEP_H_CFArray */
