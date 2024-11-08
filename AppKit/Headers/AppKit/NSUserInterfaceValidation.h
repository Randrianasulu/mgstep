/*
   NSValidatedUserInterfaceItem.h

   Use responder chain feedback to auto enable/disable controls

   Copyright (C) 2009 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Nov 2009

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSValidatedUserInterfaceItem
#define _mGSTEP_H_NSValidatedUserInterfaceItem

#import <Foundation/NSObject.h>


@protocol NSValidatedUserInterfaceItem

- (SEL) action;
- (int) tag;

@end


@protocol NSUserInterfaceValidations

- (BOOL) validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)item;

@end

#endif /* _mGSTEP_H_NSValidatedUserInterfaceItem */
