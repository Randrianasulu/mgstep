/*
   CFRuntime.h

   mini Core Foundation runtime interface

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	September 2009

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CFRuntime
#define _mGSTEP_H_CFRuntime


typedef struct _CFRuntimeClass {	// defines a mini CF class
    CFIndex    version;
    const char *className;
    void       (*dealloc)(CFTypeRef cf);
} CFRuntimeClass;

#endif  /* _mGSTEP_H_CFRuntime */
