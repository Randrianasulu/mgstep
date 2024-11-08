#include <Foundation/NSDate.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSString.h>
#include <Foundation/NSTimeZone.h>

int
main()
{
  id a, b, c, e;                           /* dates */
  id pool = [[NSAutoreleasePool alloc] init];

  // NSDate tests
  printf("NSDate tests\n");
  {
    // Create NSDate instances
    a = [NSDate date];
    printf("+[date] -- %s\n", [[a description] cString]);
    b = [NSDate dateWithTimeIntervalSinceNow: 0];
    printf("+[dateWithTimeIntervalSinceNow: 0] -- %s\n", 
	   [[b description] cString]);
    b = [NSDate dateWithTimeIntervalSinceNow: 600];
    printf("+[dateWithTimeIntervalSinceNow: 600] -- %s\n", 
	   [[b description] cString]);
    b = [NSDate dateWithTimeIntervalSince1970: 0];
    printf("+[dateWithTimeIntervalSince1970: 0] -- %s\n", 
	   [[b description] cString]);
    b = [NSDate dateWithTimeIntervalSince1970: -600];
    printf("+[dateWithTimeIntervalSince1970: -600] -- %s\n", 
	   [[b description] cString]);
    b = [NSDate dateWithTimeIntervalSinceReferenceDate: 0];
    printf("+[dateWithTimeIntervalSinceReferenceDate: 0] -- %s\n", 
	   [[b description] cString]);
    b = [NSDate dateWithTimeIntervalSinceReferenceDate: 300];
    printf("+[dateWithTimeIntervalSinceReferenceDate: 300] -- %s\n", 
	   [[b description] cString]);

    // Comparisons

    if ([a compare: [NSDate distantFuture]] == NSOrderedAscending)
      printf("Current date is before distantFuture\n");
    else
      printf("ERROR: Current date is *not* before distantFuture\n");

    if ([a compare: [NSDate distantPast]] == NSOrderedDescending)
      printf("Current date is after distantPast\n");
    else
      printf("ERROR: Current date is *not* after distantPast\n");

    c = [a earlierDate: b];
    if (c == b)
      printf("%s is earlier than %s\n", [[b description] cString],
	     [[a description] cString]);
    else
      printf("ERROR: %s is not earlier than %s\n", [[b description] cString],
	     [[a description] cString]);

    c = [a laterDate: b];
    if (c == a)
      printf("%s is later than %s\n", [[a description] cString],
	     [[b description] cString]);
    else
      printf("ERROR: %s is not later than %s\n", [[a description] cString],
	     [[b description] cString]);
  }

  // NSCalendarDate tests
  printf("NSCalendarDate tests\n");
  {
    int m, y, d, a;

    // Create an NSCalendarDate with current date and time
    c = [NSCalendarDate calendarDate];
    printf("+[calendarDate] -- %s\n", [[c description] cString]);
    printf("-[dayOfMonth] %d\n", [c dayOfMonth]);
    printf("-[dayOfWeek] %d\n", [c dayOfWeek]);
    printf("-[dayOfYear] %d\n", [c dayOfYear]);
    printf("-[hourOfDay] %d\n", [c hourOfDay]);
    printf("-[monthOfYear] %d\n", [c monthOfYear]);
    printf("-[yearOfCommonEra] %d\n", [c yearOfCommonEra]);

    a = [c absoluteGregorianDay: 9 month: 10 year: 1996];
    printf("%d-%d-%d is Gregorian absolute %d\n", 9, 10, 1996, a);
    printf("-[dayOfCommonEra] %d\n", [c dayOfCommonEra]);
    printf("-[timeIntervalSinceReferenceDate] %f\n", 
	   [c timeIntervalSinceReferenceDate]);

    a = [c absoluteGregorianDay: 1 month: 1 year: 2001];
    printf("%d-%d-%d is Gregorian absolute %d\n", 1, 1, 2001, a);
    [c gregorianDateFromAbsolute: a day: &d month: &m year: &y];
    printf("Gregorian absolute %d is %d-%d-%d\n", a, d, m, y);

    c = [NSCalendarDate dateWithString: @"1996-10-09 0:00:01"
			calendarFormat: @"%Y-%m-%d %H:%M:%S"];
    printf("calendar date %s\n", [[c description] cString]);
    printf("-[dayOfCommonEra] %d\n", [c dayOfCommonEra]);
    printf("-[dayOfMonth] %d\n", [c dayOfMonth]);
    printf("-[dayOfWeek] %d\n", [c dayOfWeek]);
    printf("-[dayOfYear] %d\n", [c dayOfYear]);
    printf("-[hourOfDay] %d\n", [c hourOfDay]);
    printf("-[minuteOfHour] %d\n", [c minuteOfHour]);
    printf("-[monthOfYear] %d\n", [c monthOfYear]);
    printf("-[secondOfMinute] %d\n", [c secondOfMinute]);
    printf("-[yearOfCommonEra] %d\n", [c yearOfCommonEra]);
    printf("-[timeIntervalSinceReferenceDate] %f\n", 
	   [c timeIntervalSinceReferenceDate]);
    e = [NSCalendarDate dateWithString: @"1996-10-09 0:00:0"
			calendarFormat: @"%Y-%m-%d %H:%M:%S"];
    printf("calendar date %s\n", [[e description] cString]);
    printf("-[timeIntervalSinceReferenceDate] %f\n", 
	   [e timeIntervalSinceReferenceDate]);
    printf("NSCalendrical time tests\n");
    {
      NSCalendarDate *momsBDay = [NSCalendarDate dateWithYear:1936
	month:1 day:8 hour:7 minute:30 second:0
	timeZone:[NSTimeZone timeZoneWithName:@"EST"]];
      NSCalendarDate *dob = [NSCalendarDate dateWithYear:1965
	month:12 day:7 hour:17 minute:25 second:0
	timeZone:[NSTimeZone timeZoneWithName:@"EST"]];
      int	years, months, days;

      [dob years:&years months:&months days:&days hours:0
		minutes:0 seconds:0 sinceDate:momsBDay];
      printf("%d, %d, %d\n", years, months, days);
      [dob years:0 months:&months days:&days hours:0
		minutes:0 seconds:0 sinceDate:momsBDay];
      printf("%d, %d\n", months, days);
    }

    printf("\nY2K checks\n");
    c = [NSCalendarDate dateWithString: @"1999-12-31 23:59:59"
			calendarFormat: @"%Y-%m-%d %H:%M:%S"];
    printf("Start at %s\n", [[c description] cString]);
    c = [c addYear:0 month:0 day:0 hour:0 minute:0 second:1];
    printf("Add one second - %s\n", [[c description] cString]);
    c = [c addYear:0 month:0 day:0 hour:0 minute:0 second:1];
    printf("Add another second - %s\n", [[c description] cString]);
    c = [c addYear:0 month:0 day:0 hour:1 minute:0 second:0];
    printf("Add an hour - %s\n", [[c description] cString]);
    c = [c addYear:0 month:0 day:0 hour:-2 minute:0 second:0];
    printf("Subtract two hours - %s\n", [[c description] cString]);

    printf("\nY2K is a leap year checks\n");
    c = [NSCalendarDate dateWithString: @"2000-2-28 23:59:59"
			calendarFormat: @"%Y-%m-%d %H:%M:%S"];
    printf("Start at %s\n", [[c description] cString]);
    c = [c addYear:0 month:0 day:0 hour:0 minute:0 second:1];
    printf("Add one second - %s\n", [[c description] cString]);
    c = [c addYear:0 month:0 day:0 hour:0 minute:0 second:1];
    printf("Add another second - %s\n", [[c description] cString]);
    c = [c addYear:0 month:0 day:0 hour:1 minute:0 second:0];
    printf("Add an hour - %s\n", [[c description] cString]);
    c = [c addYear:0 month:0 day:0 hour:-2 minute:0 second:0];
    printf("Subtract two hours - %s\n", [[c description] cString]);
    c = [c addYear:0 month:0 day:0 hour:5 minute:0 second:0];
    printf("Add five hours - %s\n", [[c description] cString]);
    c = [c addYear:1 month:0 day:0 hour:0 minute:0 second:0];
    printf("Add one year - %s\n", [[c description] cString]);
    c = [c addYear:0 month:0 day:-1 hour:0 minute:0 second:0];
    printf("Subtract one day - %s\n", [[c description] cString]);
    c = [c addYear:1 month:0 day:1 hour:0 minute:0 second:0];
    printf("Add a year and a day - %s\n", [[c description] cString]);

    printf("\n2004 is a leap year checks\n");
    c = [NSCalendarDate dateWithString: @"2004-2-28 23:59:59"
			calendarFormat: @"%Y-%m-%d %H:%M:%S"];
    printf("Start at %s\n", [[c description] cString]);
    c = [c addYear:0 month:0 day:0 hour:0 minute:0 second:1];
    printf("Add one second - %s\n", [[c description] cString]);
    c = [c addYear:0 month:0 day:0 hour:0 minute:0 second:1];
    printf("Add another second - %s\n", [[c description] cString]);
    c = [c addYear:0 month:0 day:0 hour:1 minute:0 second:0];
    printf("Add an hour - %s\n", [[c description] cString]);
    c = [c addYear:0 month:0 day:0 hour:-2 minute:0 second:0];
    printf("Subtract two hours - %s\n", [[c description] cString]);

    printf("\n2100 is NOT a leap year checks\n");
    c = [NSCalendarDate dateWithString: @"2100-2-28 23:59:59"
			calendarFormat: @"%Y-%m-%d %H:%M:%S"];
    printf("Start at %s\n", [[c description] cString]);
    c = [c addYear:0 month:0 day:0 hour:0 minute:0 second:1];
    printf("Add one second - %s\n", [[c description] cString]);
    c = [c addYear:0 month:0 day:0 hour:0 minute:0 second:1];
    printf("Add another second - %s\n", [[c description] cString]);
    c = [c addYear:0 month:0 day:0 hour:1 minute:0 second:0];
    printf("Add an hour - %s\n", [[c description] cString]);
    c = [c addYear:0 month:0 day:0 hour:-2 minute:0 second:0];
    printf("Subtract two hours - %s\n", [[c description] cString]);
  }


//
// NSCalendarDate tests courtesy of Jeremy Bettis <jeremy@hksys.com>
//
	{
    int years, months, days, i;
    NSTimeZone *theZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    NSCalendarDate * baseDate = [NSCalendarDate dateWithYear: 1993 month:3 day: 1 hour:0 minute: 0 second:0 timeZone: theZone];
    NSCalendarDate * laterDate = [NSCalendarDate dateWithYear: 1999 month:4 day: 23 hour:0 minute: 0 second:0 timeZone: theZone];
    NSCalendarDate * closeDate = baseDate;

    printf("\nNSCalendarDate tests 2\n");
    printf("Base date = %s %f\n", [[baseDate description] cString], [baseDate timeIntervalSinceReferenceDate]);
    printf("Later date = %s %f\n", [[laterDate description] cString], [laterDate timeIntervalSinceReferenceDate]);

    [ laterDate years: & years months: 0 days: 0 hours: 0 minutes: 0
             seconds: 0 sinceDate: baseDate ];
    printf("year diff = %d\n", years);
    [ laterDate years: 0 months: &months days: & days hours: 0 minutes: 0
             seconds: 0 sinceDate: baseDate ];
    printf("month diff = %d\n", months);
    [ laterDate years: 0 months: 0 days: & days hours: 0 minutes: 0
             seconds: 0 sinceDate: baseDate ];
    printf("day diff = %d\n", days);

    [ laterDate years: & years months: &months days: 0 hours: 0 minutes: 0
             seconds: 0 sinceDate: baseDate ];
    printf("diff = %d,%d\n", years, months);
    [ laterDate years: & years months: &months days: &days hours: 0 minutes: 0
             seconds: 0 sinceDate: baseDate ];
    printf("diff = %d,%d,%d\n", years, months, days);

    closeDate = baseDate;
    for(i=0;i < 50;i++) {
	[ closeDate years: 0 months: 0 days: &days hours: 0 minutes: 0
		seconds: 0 sinceDate: baseDate ];
	if (i != days) {
	    printf("Close date = '%s' %f diff=%d (should be %d)\n", [[closeDate description] cString], [closeDate timeIntervalSinceReferenceDate], days, i);
	    // break here
	    [ closeDate years: 0 months: 0 days: &days hours: 0 minutes: 0
		seconds: 0 sinceDate: baseDate ];
	}
	closeDate = [closeDate dateByAddingYears:0 months:0 days:1 hours:0 minutes:0 seconds:0];
    }
    closeDate = baseDate;
    for(i=0;i > -50;i--) {
	[closeDate years: 0 months: 0 days: &days hours: 0 minutes: 0 seconds: 0 sinceDate: baseDate];
	if (i != days) {
	    printf("Close date = '%s' %f diff=%d (should be %d)\n", [[closeDate description] cString], [closeDate timeIntervalSinceReferenceDate], days, i);
	    // break here
	    [closeDate years: 0 months: 0 days: &days hours: 0 minutes: 0 seconds: 0 sinceDate: baseDate];
	}
	closeDate = [closeDate dateByAddingYears:0 months:0 days:-1 hours:0 minutes:0 seconds:0];
    }
	}

  [pool release];
  printf("nsdate test complete\n");

  exit(0);
}
