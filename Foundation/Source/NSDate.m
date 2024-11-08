/*
   NSDate.m

   Implementations of NSDate and NSCalendarDate.

   Copyright (C) 1996, 1998 Free Software Foundation, Inc.

   Author:  Jeremy Bettis <jeremy@hksys.com>
   Date:	March 1995
   mGSTEP:	Felipe A. Rodriguez <far@pcmagic.net>
   Date:	April 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSDate.h>
#include <Foundation/NSString.h>
#include <Foundation/NSTimeZone.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSException.h>
#include <math.h>

#ifndef __WIN32__
	#include <time.h>
	#include <sys/time.h>
#endif /* !__WIN32__ */


// Absolute Gregorian date for NSDate reference date Jan 01 2001
//
//  N = 1;                 // day of month
//  N = N + 0;             // days in prior months for year
//  N = N +                // days this year
//    + 365 * (year - 1)   // days in previous years ignoring leap days
//    + (year - 1)/4       // Julian leap days before this year...
//    - (year - 1)/100     // ...minus prior century years...
//    + (year - 1)/400     // ...plus prior years divisible by 400

#define GREGORIAN_REFERENCE		730486

//  The number of seconds between 1/1/2001 and 1/1/1970 = -978307200.
//  This number comes from: 
//        -(((31 years * 365 days) + 8 days for leap years) = 
//        <total number of days> * 24 hours * 60 minutes * 60 seconds)
//  This ignores leap-seconds. 

#define UNIX_REFERENCE_INTERVAL -978307200.0
#define DISTANT_YEARS			100000.0
#define DISTANT_FUTURE			(DISTANT_YEARS * 365.0 * 24 * 60 * 60)
#define DISTANT_PAST			(-DISTANT_FUTURE)

#define CONST_DATE(v, t) \
	( (v) ? v : (v = [[self alloc] initWithTimeIntervalSinceReferenceDate: t]) )

// Class variables
static NSString *__format = @"%Y-%m-%d %H:%M:%S %z";
static id __distantFuture = nil;
static id __distantPast = nil;

// Month names    FIX ME s/b localized
//
static id __monthAbbrev[12] = { @"Jan", @"Feb", @"Mar", @"Apr", @"May", @"Jun",
							    @"Jul", @"Aug", @"Sep", @"Oct", @"Nov", @"Dec"};
static id __month[12] = { @"January",  @"February", @"March",    @"April",
						 @"May",       @"June",     @"July",     @"August",
						 @"September", @"October",  @"November", @"December" };
static id __dayAbbrev[7] = { @"Sun",@"Mon",@"Tue",@"Wed",@"Thu",@"Fri",@"Sat"};
static id __day[7] = { @"Sunday",   @"Monday", @"Tuesday", @"Wednesday",
					   @"Thursday", @"Friday", @"Saturday" };


/* ****************************************************************************

		NSDate

** ***************************************************************************/

@implementation NSDate

+ (NSTimeInterval) timeIntervalSinceReferenceDate
{														// return current time
	NSTimeInterval interval = UNIX_REFERENCE_INTERVAL;
	struct timeval tp;

	gettimeofday (&tp, NULL);
	interval += tp.tv_sec;
	interval += (double)tp.tv_usec / 1000000.0;
				// There seems to be a problem with bad double arithmetic...
	NSAssert(interval < 0, NSInternalInconsistencyException);
	
	return interval;
}

+ (id) date				{ return [[self new] autorelease];}
+ (id) distantFuture	{ return CONST_DATE(__distantFuture, DISTANT_FUTURE); }
+ (id) distantPast		{ return CONST_DATE(__distantPast,   DISTANT_PAST); }

+ (id) dateWithString:(NSString*)description
{
	return [[[self alloc] initWithString: description] autorelease];
}

+ (id) dateWithTimeIntervalSinceNow:(NSTimeInterval)seconds
{
	return [[[self alloc] initWithTimeIntervalSinceNow: seconds] autorelease];
}

+ (id) dateWithTimeIntervalSince1970:(NSTimeInterval)seconds
{
	return [[[self alloc] initWithTimeIntervalSinceReferenceDate: 
						  	UNIX_REFERENCE_INTERVAL + seconds] autorelease];
}

+ (id) dateWithTimeIntervalSinceReferenceDate:(NSTimeInterval)s
{
	return [[[self alloc] initWithTimeIntervalSinceReferenceDate:s] autorelease];
}

- (id) copy											  { return [self retain]; }
- (id) replacementObjectForPortCoder:(NSPortCoder*)c  { return self; }

- (void) encodeWithCoder:(NSCoder*)coder
{
	[super encodeWithCoder:coder];
	[coder encodeValueOfObjCType:@encode(NSTimeInterval) at:&_secondsSinceRef];
}

- (id) initWithCoder:(NSCoder*)coder
{
	self = [super initWithCoder:coder];
	[coder decodeValueOfObjCType:@encode(NSTimeInterval) at:&_secondsSinceRef];

	return self;
}

- (id) init
{
	return [self initWithTimeIntervalSinceReferenceDate:
				 	[self->isa timeIntervalSinceReferenceDate]];
}

- (id) initWithString:(NSString*)description
{
	NSCalendarDate *d = [[NSCalendarDate alloc] initWithString: description];
	NSTimeInterval a = [d timeIntervalSinceReferenceDate];

	self = [self initWithTimeIntervalSinceReferenceDate: a];
	[d release];

	return self;
}

- (id) initWithTimeInterval:(NSTimeInterval)secsToAdd sinceDate:(NSDate *)d
{									// Get other date's time and add the secs
	return [self initWithTimeIntervalSinceReferenceDate:
				 	[d timeIntervalSinceReferenceDate] + secsToAdd];
}

- (id) initWithTimeIntervalSinceNow:(NSTimeInterval)secsToAdd
{									// Get current time and add the secs
	return [self initWithTimeIntervalSinceReferenceDate:
					[self->isa timeIntervalSinceReferenceDate] + secsToAdd];
}

- (id) initWithTimeIntervalSince1970:(NSTimeInterval)seconds
{
	return [self initWithTimeIntervalSinceReferenceDate:
				 	UNIX_REFERENCE_INTERVAL + seconds];
}

- (id) initWithTimeIntervalSinceReferenceDate:(NSTimeInterval)secs
{
	if ((self = [super init]))
		_secondsSinceRef = secs;

	return self;
}

- (NSCalendarDate *) dateWithCalendarFormat:(NSString*)formatString
								   timeZone:(NSTimeZone*)timeZone
{													
	NSCalendarDate *d = [NSCalendarDate alloc];		// Convert to NSCalendar

	[d initWithTimeIntervalSinceReferenceDate: _secondsSinceRef];
	[d setCalendarFormat: formatString];
	if (!timeZone)
		timeZone = [[NSTimeZone localTimeZone] _timeZoneDetailForDate: d];
	[d setTimeZone: timeZone];
	
	return [d autorelease];
}

- (NSString*) description
{
	return [self descriptionWithCalendarFormat:nil timeZone:nil locale:nil];
}

- (NSString *) descriptionWithLocale:(id)locale
{
	return [self descriptionWithCalendarFormat:nil timeZone:nil locale:locale];
}

- (NSString*) descriptionWithCalendarFormat:(NSString*)format
								   timeZone:(NSTimeZone*)aTimeZone
									 locale:(id)locale
{
	NSCalendarDate *d = [self dateWithCalendarFormat:format timeZone:aTimeZone];

	return [d descriptionWithLocale:locale];
}

- (id) addTimeInterval:(NSTimeInterval)seconds
{									
	NSTimeInterval total = _secondsSinceRef + seconds;

	return [self->isa dateWithTimeIntervalSinceReferenceDate:total];
}

- (NSTimeInterval) timeIntervalSince1970
{
	return _secondsSinceRef - UNIX_REFERENCE_INTERVAL;
}

- (NSTimeInterval) timeIntervalSinceDate:(NSDate*)otherDate
{
	return _secondsSinceRef - [otherDate timeIntervalSinceReferenceDate];
}

- (NSTimeInterval) timeIntervalSinceNow
{
	NSTimeInterval now = [self->isa timeIntervalSinceReferenceDate];

	return _secondsSinceRef - now;
}

- (NSTimeInterval) timeIntervalSinceReferenceDate
{
	return _secondsSinceRef;
}

- (NSComparisonResult) compare:(NSDate*)otherDate			// Comparing dates
{
	if (_secondsSinceRef > otherDate->_secondsSinceRef)
		return NSOrderedDescending;
		
	if (_secondsSinceRef < otherDate->_secondsSinceRef)
		return NSOrderedAscending;
		
	return NSOrderedSame;
}

- (BOOL) isEqual:(id)other
{
	if ([other isKindOfClass: [NSDate class]])
		if (1.0 > ABS(_secondsSinceRef - ((NSDate *)other)->_secondsSinceRef))
			return YES;

	return NO;
}		

- (NSDate*) earlierDate:(NSDate*)otherDate
{
	return (_secondsSinceRef > otherDate->_secondsSinceRef) ? otherDate : self;
}

- (NSDate*) laterDate:(NSDate*)otherDate
{
	return (_secondsSinceRef < otherDate->_secondsSinceRef) ? otherDate : self;
}

@end /* NSDate */

/* ****************************************************************************

		NSCalendarDate

** ***************************************************************************/

@interface NSCalendarDate (Private)

- (void) _getYear:(int *)year 
			month:(int *)month 
			day:(int *)day
			hour:(int *)hour 
			minute:(int *)minute 
			second:(int *)second;

@end

@implementation NSCalendarDate

+ (id) calendarDate				{ return [[[self alloc] init] autorelease]; }

+ (id) dateWithString:(NSString *)description calendarFormat:(NSString *)format
{
	return [[[NSCalendarDate alloc] initWithString: description
									calendarFormat: format] autorelease];
}

+ (id) dateWithString:(NSString *)description
	   calendarFormat:(NSString *)format
	   locale:(id)locale
{
	return [[[NSCalendarDate alloc] initWithString: description
									calendarFormat: format
									locale: locale] autorelease];
}

+ (id) dateWithYear:(int)year
			  month:(unsigned int)month
			  day:(unsigned int)day
			  hour:(unsigned int)hour
			  minute:(unsigned int)minute
			  second:(unsigned int)second
			  timeZone:(NSTimeZone *)aTimeZone
{
	return [[[NSCalendarDate alloc] initWithYear: year
									month: month
									day: day
									hour: hour
									minute: minute
									second: second
									timeZone: aTimeZone] autorelease];
}

- (void) encodeWithCoder:(NSCoder*)aCoder
{
	[super encodeWithCoder: aCoder];
    [aCoder encodeObject: calendar_format];
    [aCoder encodeObject: time_zone];
}

- (id) initWithCoder:(NSCoder*)aCoder
{
    self = [super initWithCoder: aCoder];
    [aCoder decodeValueOfObjCType: @encode(id) at: &calendar_format];
    [aCoder decodeValueOfObjCType: @encode(id) at: &time_zone];

    return self;
}

- (void) dealloc
{
    [calendar_format release];
    [super dealloc];
}

- (id) initWithString:(NSString *)description
{												// FIX ME What is the locale?
	return [self initWithString:description 
				 calendarFormat:__format 
				 locale:nil];
}

- (id) initWithString:(NSString *)description calendarFormat:(NSString *)format
{												// FIX ME What is the locale?
	return [self initWithString: description
				 calendarFormat: format
				 locale: nil];
}

- (id) initWithString:(NSString *)description			// This function could
	   calendarFormat:(NSString *)format				// possibly be written
	   locale:(id)locale								// better but it works
{														// ok; currently
	const char *d = [description cString];				// ignores locale info
	const char *f = [format cString];					// and some specifiers.
	char *newf;
	int lf = strlen(f);
	BOOL mtag = NO, dtag = NO, ycent = NO;
	BOOL fullm = NO;
	char ms[80] = "", ds[80] = "", timez[80] = "", ampm[80] = "";
	int yd = 0, md = 0, dd = 0, hd = 0, mnd = 0, sd = 0;
	void *pntr[10] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
	int yord = 0, mord = 0, dord = 0, hord = 0, mnord = 0, sord = 0, tzord = 0;
	int tznum = 0;
	int ampmord = 0;
	int i, order;
	NSTimeZone *tz;
	BOOL zoneByAbbreviation = YES;
										// If either the string or format 
	if (!description)					// is nil then raise exception
		[NSException raise: NSInvalidArgumentException
					 format: @"NSCalendar date description is nil"];
	if (!format)
		[NSException raise: NSInvalidArgumentException
					 format: @"NSCalendar date format is nil"];
										// Find the order of date elements and 
										// translate format string into scanf 
	order = 1;							// ready string
	newf = malloc(lf+1);
	for (i = 0;i < lf; ++i)				// see description method for a list of
		{								// the strftime format specifiers
		newf[i] = f[i];

		if (f[i] == '%')				// Only care about a format specifier
			{
			switch (f[i+1])				// check the character that comes after
				{	
				case '%':								// skip literal %
					++i;
					newf[i] = f[i];
					break;

				case 'Y':								// is it the year
					ycent = YES;
				case 'y':
					yord = order;
					++order;
					++i;
					newf[i] = 'd';
					pntr[yord] = (void *)&yd;
					break;

				case 'B':								// is it the month
					fullm = YES;						// Full month name
				case 'b':
					mtag = YES;							// Month is char string
				case 'm':
					mord = order;
					++order;
					++i;
					if (mtag)
						{
						newf[i] = 's';
						pntr[mord] = (void *)ms;
						}
					else
						{
						newf[i] = 'd';
						pntr[mord] = (void *)&md;
						}
					break;

				case 'a':							// is it the day
				case 'A':
					dtag = YES;						// Day is character string
				case 'd':
				case 'j':
				case 'w':
					dord = order;
					++order;
					++i;
					if (dtag)
						{
						newf[i] = 's';
						pntr[dord] = (void *)ds;
						}
					else
						{
						newf[i] = 'd';
						pntr[dord] = (void *)&dd;
						}
					break;

				case 'H':									// is it the hour
				case 'I':
					hord = order;
					++order;
					++i;
					newf[i] = 'd';
					pntr[hord] = (void *)&hd;
					break;

				case 'M':									// is it the minute
					mnord = order;
					++order;
					++i;
					newf[i] = 'd';
					pntr[mnord] = (void *)&mnd;
					break;

				case 'S':									// is it the second
					sord = order;
					++order;
					++i;
					newf[i] = 'd';
					pntr[sord] = (void *)&sd;
					break;

				case 'Z':									// time zone abbrev
					tzord = order;
					++order;
					++i;
					newf[i] = 's';
					pntr[tzord] = (void *)timez;
					break;

				case 'z':									// time zone in 
					tzord = order;							// numeric format
					++order;
					++i;
					newf[i] = 'd';
					pntr[tzord] = (void *)&tznum;
					zoneByAbbreviation = NO;
					break;

				case 'p':									// AM PM indicator
					ampmord = order;
					++order;
					++i;
					newf[i] = 's';
					pntr[ampmord] = (void *)ampm;
					break;

				default:									// Anything else is 
					free(newf);								// invalid format
					[NSException raise: NSInvalidArgumentException
								 format: @"Invalid NSCalendar date, specifier \
								%c not recognized in format %s", f[i+1], f];
		}	}	}
	newf[lf] = '\0';
							// Have sscanf parse and retrieve the values for us
	if (order != 1)
		sscanf(d, newf, pntr[1], pntr[2], pntr[3], pntr[4], pntr[5], pntr[6],
				pntr[7], pntr[8], pntr[9]);
	
	if (!ycent)				// Put century on year if need be
		yd += 1900;
							// convert month from string to decimal number
	if (mtag)				// FIX ME locale ?
		{
		NSString *m = [NSString stringWithCString: ms];
		id *name = (fullm) ? __month : __monthAbbrev;
		
		for (i = 0; i < 12; ++i)
			if ([name[i] isEqual: m] == YES)
				break;
		md = i + 1;
		}
		
	if (dtag)					// convert day from string to decimal number
		{						// +++ how do we take locale into account?
		}
								// take 'am' and 'pm' into account
	if (ampmord && ((ampm[0] == 'p') || (ampm[0] == 'P')) && (hd != 12))
		hd += 12;							// 12pm is 12pm not 24pm

	if (tzord)								// time zone
		{
		if (zoneByAbbreviation)
			{
			NSString *abbrev = [NSString stringWithCString: timez];

			if (!(tz = [NSTimeZone timeZoneWithAbbreviation: abbrev]))
				tz = [NSTimeZone localTimeZone];
			}
		else
			{
			int tzm, tzh, sign;
		
			if (tznum < 0)
				{
				sign = -1;
				tznum = -tznum;
				}
			else
				sign = 1;
			tzm = tznum % 100;
			tzh = tznum / 100;
			tz = [NSTimeZone timeZoneForSecondsFromGMT:(tzh*60 + tzm)*60*sign];
			if (!tz)
				tz = [NSTimeZone localTimeZone];
		}	}
	else
		tz = [NSTimeZone localTimeZone];
		
	free(newf);

	return [self initWithYear: yd 
				 month: md 
				 day: dd 
				 hour: hd
				 minute: mnd 
				 second: sd 
				 timeZone: tz];
}

- (id) initWithYear:(int)year
			  month:(unsigned int)month
			  day:(unsigned int)day
			  hour:(unsigned int)hour
			  minute:(unsigned int)minute
			  second:(unsigned int)second
			  timeZone:(NSTimeZone *)aTimeZone
{
	int	c, a = [self absoluteGregorianDay: day month: month year: year];
	NSTimeInterval s;

	a -= GREGORIAN_REFERENCE;						// Calculate date as GMT
	s = (double)a * 86400;
	s += hour * 3600;
	s += minute * 60;
	s += second;
													// Assign time zone detail
	time_zone = [aTimeZone _timeZoneDetailForDate:
					[NSDate dateWithTimeIntervalSinceReferenceDate: s]];
	
								// Adjust date so it is correct for time zone.
	s -= [time_zone secondsFromGMT];
	self = [self initWithTimeIntervalSinceReferenceDate: s];
	
			// Now permit up to five cycles of adjustment to allow for daylight 
			// savings. NB. this depends on it being OK to call the
			// [-initWithTimeIntervalSinceReferenceDate:] method repeatedly!
	for (c = 0; c < 5 && self != nil; c++)
		{
		int	y, m, d, h, mm, ss;
		NSTimeZone *z;
		NSDate *dt;
	
		[self _getYear:&y month:&m day:&d hour:&h minute:&mm second:&ss];
		if(y==year && m==month && d==day && h==hour && mm==minute && ss==second)
			return self;
	
				// Has the time-zone detail changed?  If so - adjust time for 
				// it, other wise -  try to adjust to the correct time.
		dt = [NSDate dateWithTimeIntervalSinceReferenceDate: s];
		if ((z = [aTimeZone _timeZoneDetailForDate: dt]) != time_zone)
			{
			NSTimeInterval oldOffset = [time_zone secondsFromGMT];
			NSTimeInterval newOffset = [z secondsFromGMT];

			time_zone = z;
			s += newOffset - oldOffset;
			}
		else
			{
			NSTimeInterval move;		// Do we need to go back or forwards in 
										// time?  Shift at most two hours - we 
			if (y > year)				// know of no daylight savings time
				move = -7200.0;			// which is an offset of more than two
			else if (y < year)			// hours
				move = +7200.0;
			else if (m > month)
				move = -7200.0;
			else if (m < month)
				move = +7200.0;
			else if (d > day)
				move = -7200.0;
			else if (d < day)
				move = +7200.0;
			else if (h > hour || h < hour)
				move = (hour - h)*3600.0;
			else if (mm > minute || mm < minute)
				move = (minute - mm)*60.0;
			else
				move = (second - ss);
		
			s += move;
			}
		self = [self initWithTimeIntervalSinceReferenceDate: s];
		}

	return self;
}

- (id) initWithTimeIntervalSinceReferenceDate:(NSTimeInterval)seconds
{															// Designated init
	self = [super initWithTimeIntervalSinceReferenceDate: seconds];

	if (!calendar_format)
		calendar_format = __format;
	if (!time_zone)
		time_zone = [[NSTimeZone localTimeZone] _timeZoneDetailForDate: self];

	return self;
}

- (void) _getYear:(int *)year						// Retreiving Date Elements
			month:(int *)month 
			day:(int *)day
			hour:(int *)hour 
			minute:(int *)minute 
			second:(int *)second
{
	int h, m;
	double a, b, c, d = [self dayOfCommonEra];
											// Calc year, month, and day
	[self gregorianDateFromAbsolute: d day: day month: month year: year];

	d -= GREGORIAN_REFERENCE;				// Calc hour, minute, and seconds
	d *= 86400;
	a = fabs(d - (_secondsSinceRef + [time_zone secondsFromGMT]));
	b = a / 3600;
	*hour = (int)b;
	h = *hour;
	h = h * 3600;
	b = a - h;
	b = b / 60;
	*minute = (int)b;
	m = *minute;
	m = m * 60;
	c = a - h - m;
	*second = (int)c;
}

- (int) dayOfCommonEra
{										// Get reference date in terms of days
	double a = (_secondsSinceRef + [time_zone secondsFromGMT]) / 86400.0;
	int r;
										// Offset by Gregorian reference
	a += GREGORIAN_REFERENCE;
	r = (int)a;

	return r;
}

- (int) dayOfMonth
{
	int m, d, y, a = [self dayOfCommonEra];

	[self gregorianDateFromAbsolute:a day: &d month: &m year: &y];

	return d;
}

- (int) dayOfWeek
{												// The era started on a sunday.
	int d = [self dayOfCommonEra];				// Did we always have a seven
												// day week? Did we lose week 
	d = d % 7;									// days changing from Julian to 
	if (d < 0)									// Gregorian? AFAIK seven days 
		d += 7;									// per week is ok for all 
												// reasonable dates. 
	return d;
}

- (int) dayOfYear
{
	int m, d, y, days, i, a = [self dayOfCommonEra];

	[self gregorianDateFromAbsolute: a day: &d month: &m year: &y];
	days = d;
	for (i = m - 1;  i > 0; i--) 			// days in prior months this year
		days = days + [self lastDayOfGregorianMonth: i year: y];

	return days;
}

- (int) hourOfDay
{
	int h;
	double a, d = [self dayOfCommonEra];

	d -= GREGORIAN_REFERENCE;
	d *= 86400;
	a = fabs(d - (_secondsSinceRef + [time_zone secondsFromGMT]));
	a = a / 3600;
	h = (int)a;
										// There is a small chance of getting
	if (h == 24)						// it right at the stroke of midnight
		h = 0;

	return h;
}

- (int) minuteOfHour
{
	int h, m;
	double a, b, d = [self dayOfCommonEra];

	d -= GREGORIAN_REFERENCE;
	d *= 86400;
	a = fabs(d - (_secondsSinceRef + [time_zone secondsFromGMT]));
	b = a / 3600;
	h = (int)b;
	h = h * 3600;
	b = a - h;
	b = b / 60;
	m = (int)b;

	return m;
}

- (int) monthOfYear
{
	int m, d, y, a = [self dayOfCommonEra];

	[self gregorianDateFromAbsolute:a day:&d month:&m year:&y];

	return m;
}

- (int) secondOfMinute
{
	int h, m, s;
	double a, b, c, d = [self dayOfCommonEra];

	d -= GREGORIAN_REFERENCE;
	d *= 86400;
	a = fabs(d - (_secondsSinceRef + [time_zone secondsFromGMT]));
	b = a / 3600;
	h = (int)b;
	h = h * 3600;
	b = a - h;
	b = b / 60;
	m = (int)b;
	m = m * 60;
	c = a - h - m;
	s = (int)c;

	return s;
}

- (int) yearOfCommonEra
{										// Get reference date in terms of days
	int a = (_secondsSinceRef+[time_zone secondsFromGMT]) / 86400;
	int m, d, y;
											// Offset by Gregorian reference
	a += GREGORIAN_REFERENCE;
	[self gregorianDateFromAbsolute: a day: &d month: &m year: &y];

	return y;
}

- (NSCalendarDate*) addYear:(int)year					// return adjusted date
					  month:(unsigned int)month
					  day:(unsigned int)day
					  hour:(unsigned int)hour
					  minute:(unsigned int)minute
					  second:(unsigned int)second
{
	return [self dateByAddingYears: year
				 months: month
				 days: day
				 hours: hour
		         minutes: minute
		         seconds: second];
}

- (NSString *) description								// String Description 
{
	return [self descriptionWithCalendarFormat: calendar_format locale: nil];
}

- (NSString *) descriptionWithCalendarFormat:(NSString *)format
{
	return [self descriptionWithCalendarFormat: format locale: nil];
}

- (NSString *) descriptionWithCalendarFormat:(NSString *)format locale:(id)locale
{
	char buf[1024];
	const char *f = (format) ? [format cString] : [__format cString];
	int format_len = strlen(f);
	BOOL mtag = NO, dtag = NO, ycent = NO;
	BOOL mname = NO, dname = NO;
	double s;
	int yd = 0, md = 0, mnd = 0, sd = 0, dom = -1, dow = -1, doy = -1;
	int hd = 0, nhd;
	int i, j, k, z;

	[self _getYear:&yd month:&md day:&dom hour:&hd minute:&mnd second:&sd];
	nhd = hd;

//	The strftime format specifiers
//	%a   abbreviated weekday name according to locale
//	%A   full weekday name according to locale
//	%b   abbreviated month name according to locale
//	%B   full month name according to locale
//	%d   day of month as decimal number (leading zero)
//	%e   day of month as decimal number (leading space) **
//	%F   milliseconds (000 to 999) **
//	%H   hour as a decimal number using 24-hour clock
//	%I   hour as a decimal number using 12-hour clock
//	%j   day of year as a decimal number
//	%m   month as decimal number
//	%M   minute as decimal number
//	%p   'am' or 'pm'
//	%S   second as decimal number
//	%U   week of the current year as decimal number (Sunday first day)
//	%W   week of the current year as decimal number (Monday first day)
//	%w   day of the week as decimal number (Sunday = 0)
//	%y   year as a decimal number without century
//	%Y   year as a decimal number with century
//	%z   time zone offset (HHMM) **
//	%Z   time zone
//	%%   literal % character
//
//	** Note -- may not be supported in init method
//
										// Find the order of date elements and 
										// translate format string into printf 
	j = 0;								// ready string
	for (i = 0; i < format_len; ++i)
		{								// Only care about a format specifier
		if (f[i] == '%')
			{							// check the character that comes after
			switch (f[i+1])
				{											// literal %
				case '%':
					++i;
					buf[j] = f[i];
					++j;
					break;

				case 'Y':									// is it the year
					ycent = YES;
				case 'y':
					++i;
					if (ycent)
						k = sprintf(&(buf[j]), "%04d", yd);
					else
						k = sprintf(&(buf[j]), "%02d", (yd - 1900));
					j += k;
					break;

				case 'b':									// is it the month
					mname = YES;
				case 'B':
					mtag = YES;					// Month is character string
				case 'm':
					++i;
					if (mtag)
						{			// +++ Translate to locale character string
						if (mname)
							k = sprintf(&(buf[j]), "%s",
										[__monthAbbrev[md-1] cString]);
						else
							k = sprintf(&(buf[j]), "%s", 
										[__month[md-1] cString]);
						}
					else
						k = sprintf(&(buf[j]), "%02d", md);
					j += k;
					break;
		
				case 'd':									// day of month
					++i;
					k = sprintf(&(buf[j]), "%02d", dom);
					j += k;
					break;
		
				case 'e':									// day of month
					++i;
					k = sprintf(&(buf[j]), "%2d", dom);
					j += k;
					break;
		
				case 'F':									// milliseconds
					s = ([self dayOfCommonEra] -GREGORIAN_REFERENCE) * 86400.0;
					s -= (_secondsSinceRef+[time_zone secondsFromGMT]);
					s = fabs(s);
					s -= floor(s);
					++i;
					k = sprintf(&(buf[j]), "%03d",(int)(s*1000.0));
					j += k;
					break;
		
				case 'j':									// day of year
					if (doy < 0) 
						doy = [self dayOfYear];
					++i;
					k = sprintf(&(buf[j]), "%02d", doy);
					j += k;
					break;

				case 'a':									// is it week-day
					dname = YES;
				case 'A':
					dtag = YES;						// Day is character string
				case 'w':
					++i;
					if (dow < 0) 
						dow = [self dayOfWeek];
					if (dtag)
						{			// +++ Translate to locale character string
						if (dname)
							k = sprintf(&(buf[j]),"%s",
										[__dayAbbrev[dow] cString]);
						else
							k = sprintf(&(buf[j]), "%s", 
										[__day[dow] cString]);
						}
					else
						k = sprintf(&(buf[j]), "%02d", dow);
					j += k;
					break;

				case 'I':									// is it the hour
					nhd = hd % 12;			// 12 hour clock
					if (hd == 12)
						nhd = 12;			// 12pm not 0pm
				case 'H':
					++i;
					k = sprintf(&(buf[j]), "%02d", nhd);
					j += k;
					break;

				case 'M':									// is it the minute
					++i;
					k = sprintf(&(buf[j]), "%02d", mnd);
					j += k;
					break;

				case 'S':									// is it the second
					++i;
					k = sprintf(&(buf[j]), "%02d", sd);
					j += k;
					break;

				case 'p':							// Is it am/pm indicator
					++i;
					if (hd >= 12)
						k = sprintf(&(buf[j]), "PM");
					else
						k = sprintf(&(buf[j]), "AM");
					j += k;
					break;

				case 'Z':									// is it zone name
					++i;
					k = sprintf(&(buf[j]), "%s",
								[[time_zone abbreviation] cString]);
					j += k;
					break;
		
				case 'z':
					++i;
					z = [time_zone secondsFromGMT];
					if (z < 0) 
						{
						z = -z;
						z /= 60;
						k = sprintf(&(buf[j]), "-%02d%02d",z/60,z%60);
						}
					else 
						{
						z /= 60;
						k = sprintf(&(buf[j]), "+%02d%02d",z/60,z%60);
						}
					j += k;
					break;

				default:			// Anything else is unknown so just copy
					buf[j] = f[i];
					++i;
					++j;
					buf[j] = f[i];
					++i;
					++j;
					break;
			}	}
		else
			{
			buf[j] = f[i];
			++j;
		}	}
	buf[j] = '\0';

	return [NSString stringWithCString: buf];
}

- (NSString *) descriptionWithLocale:(id)locale
{
	return [self descriptionWithCalendarFormat:calendar_format locale:locale];
}

- (void) setCalendarFormat:(NSString *)format
{
	[calendar_format release];
	calendar_format = [format copy];
}

- (NSString *) calendarFormat				{ return calendar_format; }
- (id) copy									{ return [self retain]; }

- (void) setTimeZone:(NSTimeZone *)aTimeZone
{
	time_zone = [aTimeZone _timeZoneDetailForDate: self];
}

@end /* NSCalendarDate */


@implementation NSCalendarDate (GregorianDate)			// Manipulate Gregorian 
														// dates
- (int) lastDayOfGregorianMonth:(int)month year:(int)year
{
	switch (month) 
		{
		case 2:
			if((((year % 4) ==0) && ((year % 100) !=0)) || ((year % 400) == 0))
				return 29;
			else
				return 28;
		case 4:
		case 6:
		case 9:
		case 11: return 30;
		default: return 31;
		}
}

- (int) absoluteGregorianDay:(int)day month:(int)month year:(int)year
{
	int m, N = day;

	for (m = month - 1;  m > 0; m--)		// days in prior months this year
		N = N + [self lastDayOfGregorianMonth: m year: year];

	return (N					// days this year
     		+ 365 * (year - 1)	// days in previous years ignoring leap days
     		+ (year - 1)/4		// Julian leap days before this year...
     		- (year - 1)/100	// ...minus prior century years...
     		+ (year - 1)/400);	// ...plus prior years divisible by 400
}

- (void) gregorianDateFromAbsolute:(int)d
							   day:(int *)day
							   month:(int *)month
							   year:(int *)year
{						// Search forward year by year from approximate year
	*year = d/366;
	while (d >= [self absoluteGregorianDay:1 month:1 year:(*year)+1])
		(*year)++;
						// Search forward month by month from January
	(*month) = 1;
	while (d > [self absoluteGregorianDay: 
			[self lastDayOfGregorianMonth: *month year: *year]
			month: *month year: *year])
	(*month)++;
	*day = d - [self absoluteGregorianDay: 1 month: *month year: *year] + 1;
}

@end  /* NSCalendarDate (GregorianDate) */


@implementation NSCalendarDate (OPENSTEP)

- (NSCalendarDate *) dateByAddingYears:(int)years
								months:(int)months
								days:(int)days
								hours:(int)hours
								minutes:(int)minutes
								seconds:(int)seconds
{
	int i, year, month, day, hour, minute, second;

	[self _getYear: &year
		  month: &month
		  day: &day
		  hour: &hour
		  minute: &minute
		  second: &second];

	second += seconds;
	minute += second/60;
	second %= 60;
	if (second < 0)
		{
		minute--;
		second += 60;
		}

	minute += minutes;
	hour += minute/60;
	minute %= 60;
	if (minute < 0)
		{
		hour--;
		minute += 60;
		}

	hour += hours;
	day += hour/24;
	hour %= 24;
	if (hour < 0)
		{
		day--;
		hour += 24;
		}

	day += days;
	if (day > 28)
		{
		i = [self lastDayOfGregorianMonth: month year: year];
		while (day > i)
			{
			day -= i;
			if (month < 12)
				month++;
			else
				{
				month = 1;
				year++;
				}
			i = [self lastDayOfGregorianMonth: month year: year];
			}
		}
	else
		while (day <= 0)
			{
			if (month == 1)
				{
				year--;
				month = 12;
				}
			else
				month--;
			day += [self lastDayOfGregorianMonth: month year: year];
			}
	
	month += months;      
	while (month > 12)
		{
		year++;
		month -= 12;
		}
	while (month < 1)
		{
		year--;
		month += 12;
		}

	year += years;

	return [NSCalendarDate dateWithYear:year
							month:month
							day:day
							hour:hour
							minute:minute
							second:second
							timeZone:nil];
}

- (void) years:(int*)years
		 months:(int*)months
		 days:(int*)days
		 hours:(int*)hours
		 minutes:(int*)minutes
		 seconds:(int*)seconds
		 sinceDate:(NSDate*)date
{
	NSCalendarDate *start;
	NSCalendarDate *end;
	NSCalendarDate *tmp;
	int diff;
	int extra;
	int sign;
	int syear, smonth, sday, shour, sminute, ssecond;
	int eyear, emonth, eday, ehour, eminute, esecond;

					// FIXME What if the two dates are in different time zones?
					// How about daylight savings time?
	if ([date isKindOfClass: [NSCalendarDate class]])
		tmp = (NSCalendarDate*)[date retain];
	else
		tmp = [[NSCalendarDate alloc] initWithTimeIntervalSinceReferenceDate:
				[date timeIntervalSinceReferenceDate]];

	end = (NSCalendarDate*)[self laterDate: tmp];
	if (end == self)
		{
		start = tmp;
		sign = 1;
		}
	else
		{
		start = self;
		sign = -1;
		}

	[start _getYear: &syear
		   month: &smonth
		   day: &sday
		   hour: &shour
		   minute: &sminute
		   second: &ssecond];
	[end _getYear: &eyear
		 month: &emonth
		 day: &eday
		 hour: &ehour
		 minute: &eminute
		 second: &esecond];

		// Calculate year difference and leave any remaining months in 'extra'
	diff = eyear - syear;
	extra = 0;
	if (emonth < smonth)
		{
		diff--;
		extra += 12;
		}
	if (years)
		*years = sign*diff;
	else
		extra += diff*12;

		// Calculate month difference and leave any remaining days in 'extra'
	diff = emonth - smonth + extra;
	extra = 0;
	if (eday < sday)
		{
		diff--;
		extra = [end lastDayOfGregorianMonth: smonth year: syear];
		}
	if (months)
		*months = sign*diff;
	else
		{
		while (diff--) 
			{
			int tmpmonth = emonth - diff;
			int tmpyear = eyear;

			tmpmonth--;
			while (tmpmonth < 1) 
				{
				tmpmonth += 12;
				tmpyear--;
				}
			extra += [end lastDayOfGregorianMonth: tmpmonth year: tmpyear];
		}	}

		// Calculate day difference and leave any remaining hours in 'extra'
	diff = eday - sday + extra;
	extra = 0;
	if (ehour < shour)
		{
		diff--;
		extra = 24;
		}
	if (days)
		*days = sign * diff;
	else
		extra += diff * 24;

		// Calculate hour difference and leave any remaining minutes in 'extra'
	diff = ehour - shour + extra;
	extra = 0;
	if (eminute < sminute)
		{
		diff--;
		extra = 60;
		}
	if (hours)
		*hours = sign * diff;
	else
		extra += diff * 60;
	
		// Calc minute difference and leave any remaining seconds in 'extra'
	diff = eminute - sminute + extra;
	extra = 0;
	if (esecond < ssecond)
		{
		diff--;
		extra = 60;
		}
	if (minutes)
		*minutes = sign * diff;
	else
		extra += diff * 60;
	
	diff = esecond - ssecond + extra;
	if (seconds)
		*seconds = sign * diff;
	[tmp release];
}

@end /* NSCalendarDate */
