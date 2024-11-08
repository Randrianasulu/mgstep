/*
   NSTimeZone.m

   Time zone management.

   Copyright (C) 1997-2017 Free Software Foundation, Inc.

   Author:  Yoo C. Chung <wacko@laplace.snu.ac.kr>
   Date:	June 1997
   mGSTEP:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	April 2005

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.


   NOTE:  The local time zone can be specified with the TZ environment
          variable, the file LOCAL_TIME_FILE or the fallback time zone
          (which is UTC) with precedence in that order.
*/

#include <Foundation/NSTimeZone.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSException.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSString.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/Private/tzfile.h>

#include <sys/types.h>


#define HOUR_SECS	(60*60)
#define DAY_SECS	(HOUR_SECS*24)
								// System file that defines local time zone
#define LOCAL_TIME_FILE  @"localtime"
#define POSIX_TZONES     @"posix/"
								// Temporary structure for holding 
struct ttinfo					// time zone details
{
	int offset; 				// Seconds east of UTC
	BOOL isdst; 				// Daylight savings time?
	char abbr_idx; 				// Index into time zone abbreviations string
};

static id __localTimeZone;		// Local time zone
static id __defaultTimeZone;	// App defined default time zone
static NSLock *__zone_mutex;	// Lock for creating time zones.

								// Dictionary for time zones.  Each time 
								// zone must have a unique name.
static NSMutableDictionary *__zoneDictionary = nil;
static NSMutableDictionary *__abbreviationDictionary = nil;
static NSArray *__knownTimeZoneNames = nil;
								// Search for time zone files in these dirs
NSString *__zonedirs[] = { @"/etc/", @"/usr/share/zoneinfo/", 
						   @"/usr/lib/zoneinfo/",
						   @"/usr/local/share/zoneinfo/",
						   @"/usr/local/lib/zoneinfo/", @"/etc/zoneinfo/",
						   @"/usr/local/etc/zoneinfo/", 0 };

static NSString *
_getTimeZoneFile(NSString *name)
{
	int i;
	NSFileManager *fm = [NSFileManager defaultManager];

	for(i = 0; __zonedirs[i]; i++) 
		{
		NSString *filename = [__zonedirs[i] stringByAppendingString:name];
	    BOOL isDir;

		if ([fm fileExistsAtPath:filename isDirectory:&isDir] && !isDir) 
			return filename;
		}

	return @"";
}

static NSData *
_openTimeZoneFile(NSString *name)
{
	static NSString *FileException = @"FileException";
	NSData *data = nil;

	if(([name cString])[0] != '/')
		name = _getTimeZoneFile(name);

	NS_DURING
		if (![name length] || strchr([name cString], '.') != NULL)
			NSLog(@"Disallowed time zone name `%@'.", name);
		else if (!(data = [[NSData alloc] initWithContentsOfFile: name]))
			[NSException raise:FileException format:@"NSTimeZone init error"];
	NS_HANDLER
		NSLog(@"Unable to obtain time zone `%@'.", name);
		if ([localException name] != FileException)
			[localException raise];
	NS_ENDHANDLER

	return data;
}
									// Decode the four bytes at PTR as a signed 
static inline int					// integer in network byte order.  Based on
_decodeWORD (const void *ptr)		// code included in the GNU C Library 2.0.3
{
#if BYTE_ORDER == BIG_ENDIAN		// && SIZEOF_INT == 4
	return *(const int *) ptr;
#endif

	const unsigned char *p = ptr;
	int result = *p & (1 << (CHAR_BIT - 1)) ? ~0 : 0;

	result = (result << 8) | *p++;
	result = (result << 8) | *p++;
	result = (result << 8) | *p++;
	result = (result << 8) | *p++;

	return result;
}


@interface _TimeTransition : NSObject
{
	int trans_time; 			// When the transition occurs
	char detail_index; 			// Index of time zone detail
}
  
- (id) initWithTime:(int)aTime withIndex:(char)anIndex;
- (int) transTime;
- (char) detailIndex;

@end

@implementation _TimeTransition

- (NSString*) description
{
	return [NSString stringWithFormat: @"%@(%d, %d)", [self class], 
										trans_time, (int)detail_index];
}

- (id) initWithTime:(int)aTime withIndex:(char)anIndex
{
	trans_time = aTime;
	detail_index = anIndex;
	
	return self;
}

- (int) transTime					{ return trans_time; }
- (char) detailIndex				{ return detail_index; }

@end /* _TimeTransition */


@interface _TimeZoneDetail : NSTimeZone
{
	NSTimeZone *timeZone; 		// Time zone which created this object.
	NSString *abbrev; 			// Abbreviation for time zone detail.
	int offset; 				// Offset from UTC in seconds.
	BOOL is_dst; 				// Is it daylight savings time?
}

- (id) initWithTimeZone:(NSTimeZone*)aZone 
			 withAbbrev:(NSString*)anAbbrev
			 withOffset:(int)anOffset 
			 withDST:(BOOL)isDST;
@end 


@implementation _TimeZoneDetail
  
- (id) initWithTimeZone:(NSTimeZone*)aZone 
			 withAbbrev:(NSString*)anAbbrev
			 withOffset:(int)anOffset 
			 withDST:(BOOL)isDST
{
	timeZone = [aZone retain];
	abbrev = [anAbbrev retain];
	offset = anOffset;
	is_dst = isDST;

	return self;
}
  
- (void) dealloc
{
	[timeZone release];
	[abbrev release];
	[super dealloc];
}

- (_TimeZoneDetail*) _timeZoneDetailForDate:(NSDate*)date
{
	return [timeZone _timeZoneDetailForDate: date];
}

- (NSString*) name						{ return [timeZone name]; }
- (NSString*) abbreviation				{ return abbrev; }
- (BOOL) isDaylightSavingTime			{ return is_dst; }
- (int) secondsFromGMT					{ return offset; }
  
- (NSString*) description
{
	return [NSString stringWithFormat: @"%@(%@, %s%d)",
						[self name], [self abbreviation],
						([self isDaylightSavingTime]? "IS_DST, ": ""),
						[self secondsFromGMT]];
}

@end /* _TimeZoneDetail */


@interface NSTimeZone (TimeZoneDetail)

- (NSArray *) _timeZoneDetailArray;

@end


@interface _TimeZone : NSTimeZone
{
	NSString *_name;
	NSArray *_transitions; 		// Transition times and rules
	NSArray *_details; 			// Time zone details
}

@end
  
@implementation _TimeZone
  
- (id) initWithName:(NSString *)timeZoneName data:(NSData *)data
{
	struct tzhead header;
	unsigned int len;
	const char *bytes;

	if (!data)
		[NSException raise:NSInvalidArgumentException format:@"nil data"];

	if (!(bytes = [data bytes]) || (len=[data length]) < sizeof(struct tzhead))
		[NSException raise:NSGenericException format:@"timezone header scan"];
	else
		{
		const char *zone_abbrevs = memcpy(&header,bytes,sizeof(struct tzhead));
		int n_trans = _decodeWORD(header.tzh_timecnt);
		int n_types = _decodeWORD(header.tzh_typecnt);
		int names_size = _decodeWORD(header.tzh_charcnt);
		struct ttinfo types[n_types];
		int i, j, offset = ((4 * n_trans) + n_trans) + sizeof(struct tzhead);
		id detailsArray, abbrevs[names_size];

		for (i = 0; i < n_types; i++)			// Read time zone details
			{
			if (bytes+offset+6 >= bytes+len)
				[NSException raise:NSGenericException
							 format:@"range error scanning timezone details"];
			types[i].offset = _decodeWORD(bytes+offset);
			memcpy(&types[i].isdst, bytes+offset+4, 2);
			offset += 6;
			for (j = 0; j < i; j++)
				if (types[j].abbr_idx == types[i].abbr_idx
						&& types[j].isdst == types[i].isdst
						&& types[j].offset == types[i].offset)
					types[i].abbr_idx = -1;
			}

		zone_abbrevs = bytes+offset;			// Read abbreviation strings
		i = 0;
		memset(abbrevs, 0, sizeof(id) * names_size);
		while (i < names_size)
			{
			if (*(zone_abbrevs+i) > 65 && *(zone_abbrevs+i) < 123
					&& strlen(zone_abbrevs+i) < 8)
				abbrevs[i] = [NSString stringWithCString: zone_abbrevs+i];
			i = (strchr(zone_abbrevs+i, '\0') - zone_abbrevs) + 1;
			}
												// Create time zone details
		detailsArray = [[NSMutableArray alloc] initWithCapacity: n_types];

		for (i = 0; i < n_types; i++)
			{
			int index = MIN(types[i].abbr_idx, names_size);

			if (index >= 0 && index < names_size && (abbrevs[index]))
				[detailsArray addObject: [[_TimeZoneDetail alloc]
											initWithTimeZone: self
											withAbbrev: abbrevs[index]
											withOffset: types[i].offset
											withDST: (types[i].isdst > 0)]];
			}

		_name = [timeZoneName copy];
		_details = [detailsArray retain];
		[__zoneDictionary setObject: self forKey: timeZoneName];
		[data release];
		}

	return self;
}

- (void) dealloc
{
	[_name release];
	[_transitions release];
	[_details release];
	[super dealloc];
}

- (NSArray*) _determineTransitions
{
	id transitions = nil;
	struct tzhead header;
	const char *bytes;
	unsigned int len;
	NSData *data;

	if ((data = _openTimeZoneFile(_name)) && (bytes = [data bytes])
			&& (len = [data length]) > sizeof(struct tzhead)
			&& memcpy(&header, bytes, sizeof(struct tzhead)))
		{
		unsigned int n_trans = _decodeWORD(header.tzh_timecnt);
		char trans[4 * n_trans];
		char type_idxs[n_trans];					// Read transitions
		int i, offset = sizeof(struct tzhead);

		if (bytes+offset+((4*n_trans)+n_trans) > bytes+len)
			[NSException raise:NSGenericException
						 format:@"range error in timezone transitions"];
		memcpy(&trans, bytes+offset, (i = (4*n_trans)));
		memcpy(&type_idxs, bytes+offset+i, (n_trans));
		transitions = [[NSMutableArray alloc] initWithCapacity: n_trans];
		for (i = 0; i < n_trans; i++)
			[transitions addObject: [[_TimeTransition alloc]
										initWithTime: _decodeWORD(trans+(i*4))
										withIndex: type_idxs[i]]];
		}
	[data dealloc];

	return transitions;
}

- (_TimeZoneDetail*) _timeZoneDetailForDate:(NSDate*)date
{
	unsigned index = 0;
	unsigned count, detail_count;
	int the_time = (int)[date timeIntervalSince1970];

	if (!_transitions && !(_transitions = [self _determineTransitions]))
		return nil;						// Either DATE is before any transition
										// or there are no transitions. Return
	count = [_transitions count];		// the first non-DST type, or the first
	detail_count = [_details count];	// one if they are all DST.
	if (count == 0 || the_time < [[_transitions objectAtIndex: 0] transTime])
		{
		while (index < detail_count
				&& [[_details objectAtIndex: index] isDaylightSavingTime])
			index++;
		if (index == detail_count)
			index = 0;
		}								// Find the first transition after
	else								// DATE, and then pick the type of the
		{								// transition before it.
		for (index = 1; index < count; index++)
			if (the_time < [[_transitions objectAtIndex: index] transTime])
				break;
		index = [[_transitions objectAtIndex: index-1] detailIndex];
		}

	if (index >= detail_count)			// FIX ME last minute bug fix verify
		index = detail_count > 0 ? (detail_count - 1) : 0;

	return [_details objectAtIndex: index];
}
  
- (NSString*) name										{ return _name; }
- (NSArray*) _timeZoneDetailArray						{ return _details; }

@end /* _TimeZone */


@interface _AbsoluteTimeZone : NSTimeZone
{
	NSString *_name;
	id _detail;
	int _offset; 				// Offset from UTC in seconds.
}

- (id) _initWithOffset:(int)anOffset;

@end

@implementation _AbsoluteTimeZone

- (id) _initWithOffset:(int)anOffset
{
	if ((self = [super init]))
		{
		if (!_name)
			_name = [[NSString stringWithFormat: @"%d", anOffset] retain];
		_offset = anOffset;
		_detail = [[_TimeZoneDetail alloc] initWithTimeZone: self 
											withAbbrev: _name
											withOffset: _offset 
											withDST: NO];
		}

	return self;
}

- (void) dealloc
{
	[_name release];
	[_detail release];

	[super dealloc];
}

- (id) initWithCoder:(NSCoder*)aDecoder
{
	[aDecoder decodeValueOfObjCType: @encode(id) at: &_name];
	
	return [self _initWithOffset: [_name intValue]];
}

- (_TimeZoneDetail*) _timeZoneDetailForDate:(NSDate*)date	{ return _detail; }
- (NSString*) name											{ return _name; }
  
@end /* _AbsoluteTimeZone */


@implementation NSTimeZone

+ (void) initialize
{
	if (!__zoneDictionary)
		{
		__zoneDictionary = [[NSMutableDictionary alloc] init];
		__zone_mutex = [NSLock new];
		[self systemTimeZone];
		}
}

+ (NSTimeZone*) localTimeZone			{ return __localTimeZone; }

+ (NSTimeZone*) defaultTimeZone
{
	return __defaultTimeZone ? __defaultTimeZone : [self systemTimeZone];
}

+ (NSTimeZone*) systemTimeZone
{
	if (!__localTimeZone)
		{
		NSProcessInfo *pi = [NSProcessInfo processInfo];
		id tzString = [[pi environment] objectForKey: @"TZ"];

		if (tzString != nil)
			if (!(__localTimeZone = [NSTimeZone timeZoneWithName: tzString]))
				NSLog(@"Invalid TZ env variable %@.", tzString);
		if (__localTimeZone == nil)
			__localTimeZone = [NSTimeZone timeZoneWithName: LOCAL_TIME_FILE];
		if (__localTimeZone == nil)
			{					// Worst case alloc something sure to succeed 
			NSLog(@"Using time zone with absolute offset 0.");
			__localTimeZone = [NSTimeZone timeZoneForSecondsFromGMT: 0];
		}	}
	if (__defaultTimeZone == nil)
		__defaultTimeZone = [__localTimeZone retain];

	return __localTimeZone;
}

+ (NSTimeZone*) timeZoneForSecondsFromGMT:(int)seconds
{				// We simply return the following because an existing time zone 
				// with the given offset might not always have the same offset 
				// (daylight savings time, change in standard time, etc.).
	return [[_AbsoluteTimeZone alloc] _initWithOffset: seconds];
}

+ (NSTimeZone*) timeZoneWithAbbreviation:(NSString*)abbreviation
{
	return [[self abbreviationDictionary] objectForKey: abbreviation];
}

+ (id) alloc
{
	return (self == [NSTimeZone class])
				? NSAllocateObject([_TimeZone class])
				: NSAllocateObject(self);
}

- (id) initWithName:(NSString *)name
{
	NSTimeZone *zone;
	NSData *data;

	[__zone_mutex lock];
	if ((zone = [__zoneDictionary objectForKey: name]))
		[self release];
	else if ((data = _openTimeZoneFile(name)))
		zone = [self initWithName:name data:data];
	[__zone_mutex unlock];

	return zone;
}

+ (NSTimeZone*) timeZoneWithName:(NSString*)name
{
	NSTimeZone *zone;
	NSData *data;

	[__zone_mutex lock];
	if (!(zone = [__zoneDictionary objectForKey: name]))
		if ((data = _openTimeZoneFile(name)))
			zone = [[self alloc] initWithName:name data:data];
	[__zone_mutex unlock];

	return zone;
}

+ (void) setDefaultTimeZone:(NSTimeZone*)aTimeZone
{
	if (aTimeZone == nil)
		[NSException raise: NSInvalidArgumentException
					 format: @"Can't set nil time zone."];
	ASSIGN(__defaultTimeZone, aTimeZone);
}

+ (void) resetSystemTimeZone
{
	if (__defaultTimeZone == __localTimeZone)
		ASSIGN(__defaultTimeZone, nil);
	ASSIGN(__localTimeZone, nil);
}

+ (NSDictionary*) abbreviationDictionary
{
	if (__abbreviationDictionary == nil)	// inefficient but rarely used
		{
		NSAutoreleasePool *pool = [NSAutoreleasePool new];
		NSMutableDictionary *d = [[NSMutableDictionary alloc] init];
		id name, e = [[NSTimeZone knownTimeZoneNames] objectEnumerator];

		while ((name = [e nextObject]) != nil)
			{
			NSTimeZone *zone;

			if ((zone = [NSTimeZone timeZoneWithName: name]))
				{
				id de = [[zone _timeZoneDetailArray] objectEnumerator];
				id detail;

				while ((detail = [de nextObject]) != nil)
					[d setObject:name forKey:[detail abbreviation]];
			}	}
		if (__abbreviationDictionary == nil)	// FIX ME use CAS primitive?
			__abbreviationDictionary = d;
		[pool release];
		if (__abbreviationDictionary != d)
			[d release];
		}

	return __abbreviationDictionary;
}

+ (NSArray*) knownTimeZoneNames
{
	if (__knownTimeZoneNames == nil)
		{
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *zonedir = nil;
		int i;

		for(i = 1; __zonedirs[i] && !zonedir; i++)
			{
			NSString *p = [__zonedirs[i] stringByAppendingString:POSIX_TZONES];
			BOOL isDir;

			if ([fm fileExistsAtPath:p isDirectory:&isDir] && isDir)
				zonedir = p;
			}

		[__zone_mutex lock];
		if (__knownTimeZoneNames == nil && zonedir)
			{
			NSAutoreleasePool *pool = [NSAutoreleasePool new];
			NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:zonedir];
			NSString *file;
			id a = [[NSMutableArray alloc] init];

			while (file = [enumerator nextObject])
				{
				NSString *name = [zonedir stringByAppendingString: file];
				NSTimeZone *zone = nil;
				NSData *data = nil;
				BOOL isDir;

				if ([fm fileExistsAtPath:name isDirectory:&isDir] && !isDir)
					if (!(zone = [__zoneDictionary objectForKey: file]))
						if ((data = _openTimeZoneFile(name)))
							zone = [[self alloc] initWithName:file data:data];

				if (zone != nil)
					{
					int offset, j;
					id details = [zone _timeZoneDetailArray];
					id detail, e = [details objectEnumerator];
	
					while ((detail = [e nextObject]) != nil)
						if (![detail isDaylightSavingTime])
							break;					// Get a standard time

					if (detail == nil)				// If no standard time
						detail = [details objectAtIndex: 0];

					offset = [detail secondsFromGMT];
										// Get index from normalized offset
					if ((j = ((offset+DAY_SECS) %DAY_SECS)/HOUR_SECS) < 24)
						[a addObject: file];
				}	}

			__knownTimeZoneNames = [[NSArray arrayWithArray: a] retain];
			[pool release];
			}
		[__zone_mutex unlock];
		}

	return __knownTimeZoneNames;
}

- (NSString*) description						{ return [self name]; }

- (NSString*) abbreviation
{
	return [[self _timeZoneDetailForDate: [NSDate date]] abbreviation];
}

- (NSData *) data
{
	return [_openTimeZoneFile([self name]) autorelease];
}

- (BOOL) isDaylightSavingTime
{
	return [[self _timeZoneDetailForDate: [NSDate date]] isDaylightSavingTime];
}

- (int) secondsFromGMT
{
	return [[self _timeZoneDetailForDate: [NSDate date]] secondsFromGMT];
}

- (BOOL) isEqualToTimeZone:(NSTimeZone *)timeZone	// FIX ME concrete classes
{
	return (self == timeZone) || [[self name] isEqualToString:[timeZone name]];
}

- (id) copy										{ return [self retain]; }

- (void) encodeWithCoder:(NSCoder*)aCoder
{
	if (self == __localTimeZone)
		[aCoder encodeObject: @"NSLocalTimeZone"];
	else
		[aCoder encodeObject: [self name]];
}

- (id) initWithCoder:(NSCoder*)aDecoder
{
	NSString *name = [aDecoder decodeObject];
	NSTimeZone *zone;

	if ([name isEqual: @"NSLocalTimeZone"])
		{
		[self release];
		return __localTimeZone;
		}

	if (!(zone = [self initWithName: name]))	// FIX ME need to test this
		{
		[self release];
		return [[_AbsoluteTimeZone alloc] initWithCoder:aDecoder];
		}

	return zone;
}

@end  /* NSTimeZone */
