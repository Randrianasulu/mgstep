/*
   CGError.h

   Core Graphics error codes

   Copyright (C) 2016 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jun 2016

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CGError
#define _mGSTEP_H_CGError

#include <CoreGraphics/CoreGraphics.h>


typedef enum _CGError {
	kCGErrorSuccess          = 0,
	kCGErrorFailure          = 1000,
	kCGErrorIllegalArgument  = 1001,
	kCGErrorInvalidContext   = 1003,
	kCGErrorCannotComplete   = 1004,
	kCGErrorNotImplemented   = 1006,
	kCGErrorRangeCheck       = 1007,
	kCGErrorTypeCheck        = 1008,
	kCGErrorInvalidOperation = 1010
} CGError;

#endif /* _mGSTEP_H_CGError */
