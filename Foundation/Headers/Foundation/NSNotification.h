/*
   NSNotification.h

   Copyright (C) 1995-2016 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>

   This file is part of the mGSTEP Library and is provided under the 
   terms of the libFoundation BSD type license (See the Readme file).
*/

#ifndef _mGSTEP_H_NSNotification
#define _mGSTEP_H_NSNotification

#include <Foundation/NSObject.h>

@class NSDictionary;
@class NSArray;


@interface NSNotification : NSObject  <NSCoding>
{
	id _name;
	id _object;
	id _info;
	id _registry;
}

+ (NSNotification*) notificationWithName:(NSString*)name object:object;
+ (NSNotification*) notificationWithName:(NSString*)aName
								  object:(id)anObject
								  userInfo:(NSDictionary*)userInfo;

- (id) initWithName:(NSString*)aName
			 object:(id)anObject 
			 userInfo:(NSDictionary*)userInfo;

- (NSString*) name;
- (NSDictionary*) userInfo;
- (id) object;

@end /* NSNotification */


@interface NSNotificationCenter : NSObject
{
    id _noteForObject;
    id _anyNoteForObject;
}

+ (NSNotificationCenter *) defaultCenter;
													// Posting Notifications
- (void) postNotification:(NSNotification*)notification;
- (void) postNotificationName:(NSString*)notificationName object:(id)object;
- (void) postNotificationName:(NSString*)notificationName 
					   object:(id)object
					   userInfo:(NSDictionary*)userInfo;

- (void) addObserver:(id)observer					// Add / Remove Observers
			selector:(SEL)selector 
			name:(NSString*)name 
			object:(id)object;
- (void) removeObserver:(id)observer name:(NSString*)name object:(id)object;
- (void) removeObserver:(id)observer;

@end /* NSNotificationCenter */


@interface NSNotificationCenter (Not_OSX)

+ (void) post:(NSString*)notificationName object:(id)object;

@end

#endif /* _mGSTEP_H_NSNotification */
