/*
   NSCustomImageRep.h

   Render self via method selector of delegate.

   Copyright (C) 2000 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@pcmagic.net>
   Date:    June 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSCustomImageRep
#define _mGSTEP_H_NSCustomImageRep

#include <AppKit/NSImageRep.h>

@interface NSCustomImageRep : NSImageRep
{
	id _delegate;
	SEL _selector;
}

- (id) initWithDrawSelector:(SEL)aSelector delegate:(id)anObject;

- (id) delegate;
- (SEL) drawSelector;

@end

#endif /* _mGSTEP_H_NSCustomImageRep */
