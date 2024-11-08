/*
   NSDate.h

   Encapsulation of time and date

   Copyright (C) 1998 Free Software Foundation, Inc.

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSDate
#define _mGSTEP_H_NSDate

#include <Foundation/NSObject.h>

typedef double NSTimeInterval;				// Time interval difference between 
											// two dates, in seconds.
@class NSArray;
@class NSCalendarDate;
@class NSDictionary;
@class NSString;
@class NSTimeZone;


@interface NSDate : NSObject  <NSCoding, NSCopying>
{
	NSTimeInterval _secondsSinceRef;
}

+ (NSTimeInterval) timeIntervalSinceReferenceDate;

+ (id) date;
+ (id) dateWithString:(NSString*)description;
+ (id) dateWithTimeIntervalSinceNow:(NSTimeInterval)seconds;
+ (id) dateWithTimeIntervalSince1970:(NSTimeInterval)seconds;
+ (id) dateWithTimeIntervalSinceReferenceDate:(NSTimeInterval)seconds;
+ (id) distantFuture;
+ (id) distantPast;

- (id) initWithString:(NSString*)description;
- (id) initWithTimeInterval:(NSTimeInterval)secsToBeAdded
				  sinceDate:(NSDate*)anotherDate;
- (id) initWithTimeIntervalSinceNow:(NSTimeInterval)secsToBeAdded;
- (id) initWithTimeIntervalSince1970:(NSTimeInterval)seconds;
- (id) initWithTimeIntervalSinceReferenceDate:(NSTimeInterval)secs;
															// Converting
- (NSCalendarDate *) dateWithCalendarFormat:(NSString*)formatString
								   timeZone:(NSTimeZone*)timeZone;
- (NSString*) description;
- (NSString*) descriptionWithLocale:(id)locale;
- (NSString*) descriptionWithCalendarFormat:(NSString*)format
								   timeZone:(NSTimeZone*)aTimeZone
									 locale:(id)locale;

- (id) addTimeInterval:(NSTimeInterval)seconds;				// Time Intervals
- (NSTimeInterval) timeIntervalSince1970;
- (NSTimeInterval) timeIntervalSinceDate:(NSDate*)otherDate;
- (NSTimeInterval) timeIntervalSinceNow;
- (NSTimeInterval) timeIntervalSinceReferenceDate;

- (NSComparisonResult) compare:(NSDate*)otherDate;			// Compare dates
- (NSDate*) earlierDate:(NSDate*)otherDate;
- (NSDate*) laterDate:(NSDate*)otherDate;
- (BOOL) isEqual:(id)other;

@end


@interface NSCalendarDate : NSDate
{
	NSString *calendar_format;
	NSTimeZone *time_zone;
}

+ (id) calendarDate;
+ (id) dateWithString:(NSString *)description calendarFormat:(NSString *)format;
+ (id) dateWithString:(NSString *)description
	   calendarFormat:(NSString *)format
	   locale:(id)locale;
+ (id) dateWithYear:(int)year
			  month:(unsigned int)month
			  day:(unsigned int)day
			  hour:(unsigned int)hour
			  minute:(unsigned int)minute
			  second:(unsigned int)second
			  timeZone:(NSTimeZone *)aTimeZone;

- (id) initWithString:(NSString *)description;
- (id) initWithString:(NSString *)description calendarFormat:(NSString *)format;
- (id) initWithString:(NSString *)description
	   calendarFormat:(NSString *)format
	   locale:(id)locale;
- (id) initWithYear:(int)year
			  month:(unsigned int)month
			  day:(unsigned int)day
			  hour:(unsigned int)hour
			  minute:(unsigned int)minute
			  second:(unsigned int)second
			  timeZone:(NSTimeZone *)aTimeZone;

- (int) dayOfCommonEra;										// Date Elements
- (int) dayOfMonth;
- (int) dayOfWeek;
- (int) dayOfYear;
- (int) hourOfDay;
- (int) minuteOfHour;
- (int) monthOfYear;
- (int) secondOfMinute;
- (int) yearOfCommonEra;

- (NSCalendarDate *) addYear:(int)year						// Adjusting Dates
					   month:(unsigned int)month
					   day:(unsigned int)day
					   hour:(unsigned int)hour
					   minute:(unsigned int)minute
					   second:(unsigned int)second;

- (NSString *) description;
- (NSString *) descriptionWithLocale:(id)locale;
- (NSString *) descriptionWithCalendarFormat:(NSString *)format;
- (NSString *) descriptionWithCalendarFormat:(NSString *)format locale:(id)locale;

- (NSString *) calendarFormat;
- (void) setCalendarFormat:(NSString *)format;
- (void) setTimeZone:(NSTimeZone *)aTimeZone;

@end


@interface NSCalendarDate (GregorianDate)

- (int) lastDayOfGregorianMonth:(int)month year:(int)year;
- (int) absoluteGregorianDay:(int)day month:(int)month year:(int)year;
- (void) gregorianDateFromAbsolute:(int)d 
							   day:(int *)day
							   month:(int *)month
							   year:(int *)year;
@end


@interface NSCalendarDate (OPENSTEP)

- (NSCalendarDate *) dateByAddingYears:(int)years
								months:(int)months
								days:(int)days
								hours:(int)hours
								minutes:(int)minutes
								seconds:(int)seconds;

- (void) years:(int*)years
		 months:(int*)months
		 days:(int*)days
		 hours:(int*)hours
		 minutes:(int*)minutes
		 seconds:(int*)seconds
		 sinceDate:(NSDate*)date;
@end

#endif /* _mGSTEP_H_NSDate */
