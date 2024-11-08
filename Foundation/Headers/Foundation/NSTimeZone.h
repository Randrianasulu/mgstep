/* 
   NSTimeZone.h

   Interface to Time Zone class

   Copyright (C) 2005 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@pcmagic.net>
   Date:	April 2005

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSTimeZone
#define _mGSTEP_H_NSTimeZone

#include <Foundation/NSObject.h>

@class NSDate;
@class NSData;
@class NSArray;
@class NSDictionary;


@interface NSTimeZone : NSObject  <NSCopying, NSCoding>

+ (NSTimeZone *) localTimeZone;
+ (NSTimeZone *) systemTimeZone;
+ (NSTimeZone *) defaultTimeZone;
+ (NSTimeZone *) timeZoneForSecondsFromGMT:(int)seconds;
+ (NSTimeZone *) timeZoneWithName:(NSString *)timeZone;
+ (NSTimeZone *) timeZoneWithAbbreviation:(NSString *)abbreviation;  

+ (NSDictionary *) abbreviationDictionary;
+ (NSArray *) knownTimeZoneNames;

+ (void) setDefaultTimeZone:(NSTimeZone *)timeZone;
+ (void) resetSystemTimeZone;

- (NSData *) data;

- (int) secondsFromGMT;
- (BOOL) isDaylightSavingTime;
- (NSString *) abbreviation;

@end


@interface NSTimeZone (ConcreteTimeZone)

- (id) initWithName:(NSString *)timeZoneName data:(NSData *)data;
- (id) initWithName:(NSString *)name;

- (NSString *) name;
- (NSString *) description;

- (BOOL) isEqualToTimeZone:(NSTimeZone *)timeZone;

- (id) _timeZoneDetailForDate:(NSDate *)date;

@end

#endif /* _mGSTEP_H_NSTimeZone */
