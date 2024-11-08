/*
   NSUserDefaults.m

   User default settings

   Copyright (C) 1995-2016 Free Software Foundation, Inc.

   Author:  Georg Tuparev <Tuparev@EMBL-Heidelberg.de>
   Date:    1995

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSException.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSDistributedLock.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSString.h>

#define NOTE(note_name)		NSUserDefaults##note_name##Notification


NSString *NOTE(DidChange)      = @"NSUserDefaultsDidChangeNotification";

NSString *NSArgumentDomain 	   = @"NSArgumentDomain";
NSString *NSGlobalDomain 	   = @"NSGlobalDomain";
NSString *NSRegistrationDomain = @"NSRegistrationDomain";


// Class variables
static const NSString *__userDefaultsDB = @".mGSTEP/defaults.plist";
static NSUserDefaults *__sharedDefaults = nil;
static NSString *__processName = nil;


@implementation NSUserDefaults

- (void) _changedPersistentDomain:(NSString *)domainName
{
	if (!_changedDomains)
		_changedDomains = [[NSMutableArray arrayWithCapacity:5] retain];
	else
		{
		NSEnumerator *e = [_changedDomains objectEnumerator];
		id obj;
	
		while ((obj = [e nextObject]))
			if ([obj isEqualToString:domainName])
				return;							// change already registered
		}
	
	[_changedDomains addObject:domainName];
	[NSNotificationCenter post: NOTE(DidChange) object: nil];

	if (!_timerActive)
		{
		_timerActive = YES;
		[NSTimer scheduledTimerWithTimeInterval:30
				 target:self
				 selector:@selector(synchronize)
				 userInfo:nil
				 repeats:NO];
		}
}

+ (NSUserDefaults *) standardUserDefaults
{
	return (__sharedDefaults) ? __sharedDefaults : [self new];
}

+ (NSArray *) userLanguages
{
	NSArray *ul = nil;
	NSString *key = @"Languages";
	const char *env_list;

	if (__sharedDefaults && (ul = [__sharedDefaults stringArrayForKey: key]))
		return ul;

	if ((env_list = getenv("LANGUAGES")))
		{
		NSString *env = [NSString stringWithCString:env_list];

		ul = [[env componentsSeparatedByString:@";"] retain];
		}

	if (!ul || ![ul containsObject:@"English"])
		{
		NSMutableArray *a = [NSMutableArray arrayWithCapacity: ([ul count]+2)];

		if(ul)
			[a addObjectsFromArray: ul];
		[a addObject:@"English"];
		ASSIGN(ul, (NSArray *)a);
		}

	return ul;
}

- (id) init				{ return [self initWithUser:NSUserName()]; }

- (id) initWithUser:(NSString *)userName			// Initializes defaults for 
{													// the specified user
	NSFileManager *fm = [NSFileManager defaultManager];
	NSMutableString *dp;
	NSString *home;

	if (!(home = NSHomeDirectoryForUser(userName)))
		return _NSInitError(self, @"invalid user name '%@'", userName);

	dp = [NSMutableString stringWithFormat:@"%@/%@", home, __userDefaultsDB];
	_defaultsDatabase = [dp retain];

	if (![fm fileExistsAtPath: dp])
		{								// try to create defaults directory
		BOOL isDirectory;				// if it does not exist
		NSString *lockDir = [dp stringByDeletingLastPathComponent];

		if (![fm fileExistsAtPath:lockDir isDirectory:&isDirectory])
			[fm createDirectoryAtPath:lockDir attributes:nil];
		}

	dp = [NSMutableString stringWithFormat: @"%@/%@",
					[dp stringByDeletingLastPathComponent], @"defaults.lock"];
	if (!(_defaultsDBLock = [NSDistributedLock lockWithPath:dp]))
		NSLog(@"NSUserDefaults: failed to create defaults db lock '%@'", dp);
	else
		[_defaultsDBLock retain];

	if (__processName == nil)
		{
		__processName = [[NSProcessInfo processInfo] processName];
		__processName = [[__processName lastPathComponent] retain];
		}
												// Create an empty search list
	_searchList = [[NSMutableArray arrayWithCapacity:10] retain];

	if (!__sharedDefaults)						// if shared instance create 
		{										// standard search list
		__sharedDefaults = self;
		[self setVolatileDomain:nil forName:NSArgumentDomain];	// init Vol
		[_searchList addObject:__processName];			// Application
		[_searchList addObject:NSGlobalDomain];			// NSGlobalDomain
														// Preferred languages
		[_searchList addObjectsFromArray:[NSUserDefaults userLanguages]];
		}
							// init persist domain from archived userdefaults
	_persistDomain = [[NSMutableDictionary dictionaryWithCapacity:10] retain];
	if ([self synchronize] == NO)
		{
		NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
		BOOL done = NO;
		int	attempts;						// Retry for a couple of seconds in 
											// case we are locked out.
		for (attempts = 0; done == NO && attempts < 10; attempts++)
			{
			[runLoop runMode: [runLoop currentMode]
					 beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.3]];
			if ([self synchronize] == YES)
				done = YES;
			}

		if (done == NO && (__sharedDefaults == self))
			{
			__sharedDefaults = nil;

			return _NSInitError(self, @"failed to sync defaults");
		}	}
														// Add App and NSGlobal
	if (![_persistDomain objectForKey:__processName])	// domains if missing
		{												// after sync with DDB
		DBLog(@" adding entry to persistent domain ");
		[_persistDomain setObject:[NSMutableDictionary dictionaryWithCapacity:8]
						forKey:__processName];
		[self _changedPersistentDomain:__processName];
		}

	if (![_persistDomain objectForKey:NSGlobalDomain])
		{
		[_persistDomain setObject:[NSMutableDictionary dictionaryWithCapacity:8]
						forKey:NSGlobalDomain];
		[self _changedPersistentDomain:NSGlobalDomain];
		}

	return self;
}

- (void) dealloc
{
	[_searchList release];
	[_persistDomain release];
	[_volatileDomain release];
	[_changedDomains release];

	[super dealloc];
}

- (NSArray *) arrayForKey:(NSString *)defaultName
{
	id obj = [self objectForKey:defaultName];
	
	return obj && [obj isKindOfClass:[NSArray class]] ? obj : nil;
}

- (BOOL) boolForKey:(NSString *)defaultName
{
	id obj = [self stringForKey:defaultName];
	
	return ((obj) && ([obj isEqualToString:@"YES"] 
			|| [obj isEqualToString:@"yes"] || [obj intValue])) ? YES : NO;
}

- (NSData *) dataForKey:(NSString *)defaultName
{
	id obj = [self objectForKey:defaultName];
	
	return obj && [obj isKindOfClass:[NSData class]] ? obj : nil;
}

- (NSDictionary *) dictionaryForKey:(NSString *)defaultName
{
	id obj = [self objectForKey:defaultName];
	
	return obj && [obj isKindOfClass:[NSDictionary class]] ? obj : nil;
}

- (float) floatForKey:(NSString *)defaultName
{
	id obj = [self stringForKey:defaultName];
	
	return obj ? [obj floatValue] : 0.0;
}

- (int) integerForKey:(NSString *)defaultName
{
	id obj = [self stringForKey:defaultName];
	
	return obj ? [obj intValue] : 0;
}

- (id) objectForKey:(NSString *)defaultName
{
	NSDictionary *d = [_persistDomain objectForKey:__processName];
	id obj = [d objectForKey:defaultName];
	
	if (!obj)
		{
		d = [_volatileDomain objectForKey:__processName];			

		if (!(obj = [d objectForKey:defaultName]))
			{
			d = [_persistDomain objectForKey:@"NSGlobalDomain"];
			obj = [d objectForKey:defaultName];
		}	}			
	
	return obj;
}

- (void) removeObjectForKey:(NSString *)defaultName
{
	NSMutableDictionary *d = [_persistDomain objectForKey:__processName];
	
	if ([d objectForKey:defaultName])
    	{
		if ([d isKindOfClass: [NSMutableDictionary class]] == NO)
			{
			d = [d mutableCopy];
			[_persistDomain setObject:d forKey:__processName];
			}
		[d removeObjectForKey:defaultName];
		[self _changedPersistentDomain:__processName];
		}
}

- (void) setBool:(BOOL)value forKey:(NSString *)defaultName
{
	id obj = (value) ? @"YES" : @"NO";
	
	[self setObject:obj forKey:defaultName];
}

- (void) setFloat:(float)value forKey:(NSString *)defaultName
{	
	char buf[32];

	sprintf(buf,"%g",value);
	[self setObject:[NSString stringWithCString:buf] forKey:defaultName];
}

- (void) setInteger:(int)value forKey:(NSString *)defaultName
{
	char buf[32];

	sprintf(buf,"%d",value);
	[self setObject:[NSString stringWithCString:buf] forKey:defaultName];
}

- (void) setObject:(id)value forKey:(NSString *)defaultName
{
	if (value && defaultName && ([defaultName length] > 0))
		{
		id obj = [_persistDomain objectForKey: __processName];
		NSMutableDictionary *dict;
	
		if ([obj isKindOfClass: [NSMutableDictionary class]] == YES)
			dict = obj;
		else
			{
			dict = [obj mutableCopy];
			[_persistDomain setObject: dict forKey: __processName];
			}
		[dict setObject:value forKey:defaultName];
		[self _changedPersistentDomain:__processName];
		}
}

- (NSArray *) stringArrayForKey:(NSString *)defaultName
{
	id obj, array;
	
	if ((array = [self arrayForKey:defaultName]))
		{
		NSEnumerator *e = [array objectEnumerator];
		
		while ((obj = [e nextObject]))
			if ( ! [obj isKindOfClass:[NSString class]])
				return nil;
		}

	return array;
}

- (NSString *) stringForKey:(NSString *)defaultName
{
	id obj = [self objectForKey:defaultName];

	if(!obj)
		return nil;

	return [obj isKindOfClass:[NSString class]] ? obj : [obj description];
}

- (void) setSearchList:(NSArray*)newList
{
	[_searchList release];
	_searchList = [newList mutableCopy];
}

- (NSMutableArray *) searchList			{ return _searchList; }
- (NSArray *) volatileDomainNames		{ return [_volatileDomain allKeys]; }
- (NSArray *) persistentDomainNames		{ return [_persistDomain allKeys]; }

- (NSDictionary *) persistentDomainForName:(NSString *)domainName
{
	return [_persistDomain objectForKey:domainName];
}

- (void) removePersistentDomainForName:(NSString *)domainName
{
	if ([_persistDomain objectForKey:domainName])
		{
		[_persistDomain removeObjectForKey:domainName];
		[self _changedPersistentDomain:domainName];
		}
}

- (void) setPersistentDomain:(NSDictionary *)domain 
					 forName:(NSString *)domainName
{
	if ([_volatileDomain objectForKey:domainName])
		[NSException raise:NSInvalidArgumentException 
					 format:@"Volatile domain %@ already exists", domainName];

	[_persistDomain setObject:domain forKey:domainName];
	[self _changedPersistentDomain:domainName];
}

- (void) removeVolatileDomainForName:(NSString *)domainName
{
	[_volatileDomain removeObjectForKey:domainName];
}

- (void) setVolatileDomain:(NSDictionary *)domain
				   forName:(NSString *)domainName
{
	if (!_volatileDomain)
		{
		NSArray *args = [[NSProcessInfo processInfo] arguments];
		unsigned c;

		_volatileDomain = [NSMutableDictionary dictionaryWithCapacity:10];
		[_volatileDomain retain];
		
		if ((c = [args count]) > 2)
			{
			NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity: c];
			NSEnumerator *e = [args objectEnumerator];
			id val, key = [e nextObject];

			while (key)
				{					// a leading '-' indicates a defaults key
				if ([key hasPrefix:@"-"])
					{
					key = [key substringFromIndex: 1];
					if (!(val = [e nextObject]))
						{								// No more args
						[d setObject:@"" forKey:key];	// arg is empty.
						break;
						}
					else if ([val hasPrefix:@"-"])
						{  								// another argument
						[d setObject:@"" forKey:key];	// arg is empty.
						key = val;
						continue;
						}
					else
						[d setObject:val forKey:key];	// Real parameter
					}
				key = [e nextObject];
				}

			[_volatileDomain setObject:d forKey:NSArgumentDomain];
			[_searchList addObject:NSArgumentDomain];
			}
		return;
		}

	if ([_persistDomain objectForKey:domainName])
		[NSException raise:NSInvalidArgumentException 
					 format:@"Persistent domain %@ already exists",domainName];

	[_volatileDomain setObject:domain forKey:domainName];
}

- (NSDictionary *) volatileDomainForName:(NSString *)domainName
{
	return [_volatileDomain objectForKey:domainName];
}

- (BOOL) synchronize
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSMutableDictionary *nd = nil;

	_timerActive = NO;

	if ([_defaultsDBLock tryLock] == NO)	// Get file lock - break any lock
		{									// that is more than five mins old
		if ([[_defaultsDBLock lockDate] timeIntervalSinceNow] < -300.0)
			{
			[_defaultsDBLock breakLock];
			if ([_defaultsDBLock tryLock] == NO)
				return NO;
			}
		else
			return NO;
		}									// Read the persistent data from
											// the stored defaults database
	if ([fm fileExistsAtPath: _defaultsDatabase])
		{
		nd = [NSMutableDictionary alloc];

		NS_DURING
			nd = [nd initWithContentsOfFile:_defaultsDatabase];
		NS_HANDLER
			[nd autorelease];
			nd = nil;
		NS_ENDHANDLER

		if (!(nd))
			{
			NSMutableString *s = [_defaultsDatabase mutableCopy];

			[s appendString: @".bak"];
			NSLog(@"Backing up defaults database file to %@", s);
			[fm copyPath: _defaultsDatabase toPath: s handler: nil];
		}	}

	if (!nd)
		nd = [[NSMutableDictionary alloc] initWithCapacity:1];

	if (_changedDomains)
		{           						// Synchronize both dictionaries
		NSEnumerator *e = [_changedDomains objectEnumerator];
		id obj, d;
		
		while ((obj = [e nextObject]))
			{
			if ((d = [_persistDomain objectForKey:obj]))	// Domain was added    					
				[nd setObject:d forKey:obj];				// or changed
			else
				[nd removeObjectForKey:obj];		// Domain was removed
			}
		ASSIGN(_persistDomain, nd);
												// Save any changes to disk ddb
		if (![_persistDomain writeToFile:_defaultsDatabase atomically:YES])
			{
			[_defaultsDBLock unlock];
			return NO;
			}
		ASSIGN(_changedDomains, nil);
		}
	else											// Just update from disk
		ASSIGN(_persistDomain, nd);
	
	[_defaultsDBLock unlock];						// release file lock
	
	return YES;
}

- (NSDictionary *) dictionaryRepresentation
{
	NSEnumerator *e = [_searchList reverseObjectEnumerator];
	NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:10];
	id obj, dict;
	
	while ((obj = [e nextObject]))
		if ((dict = [_persistDomain objectForKey:obj])
				|| (dict = [_volatileDomain objectForKey:obj]))
			[d addEntriesFromDictionary:dict];

	return d;
}	
														// create registration
- (void) registerDefaults:(NSDictionary *)dictionary	// domain if none exists
{
	if (![_volatileDomain objectForKey:NSRegistrationDomain])
		[_searchList addObject: NSRegistrationDomain];
	[_volatileDomain setObject:dictionary forKey:NSRegistrationDomain];
}

- (void) setURL:(NSURL *)url forKey:(NSString *)defaultName			 { }
- (NSURL *) URLForKey:(NSString *)defaultName			{ return NIMP; }

@end
