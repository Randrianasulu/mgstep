/*
   IMCustomObject.h

   Copyright (C) 1996 Free Software Foundation, Inc.

   This class was inspired by CustomObject class from objcX, 
   "an Objective-C class library for a window system". That 
   code was written by Paul Kunz and Imran Qureshi.

   Author: Ovidiu Predescu <ovidiu@net-community.com>
   Date: November 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_IMCustomObject
#define _mGSTEP_H_IMCustomObject

#import <Foundation/NSObject.h>

@interface NSObject (ModelUnarchiving)			// Add an archiving category to 
												// object so every object can 
- (id) nibInstantiate;							// respond to -nibInstantiate

@end


@interface IMCustomObject : NSObject
{
	NSString *className;
	id realObject;
}

- (id) nibInstantiate;

@end

#endif /* _mGSTEP_H_IMCustomObject */
