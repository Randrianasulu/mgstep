/*
   NSUserDefaults.h

   User default settings

   Copyright (C) 1995-2016 Free Software Foundation, Inc.

   Author:  Georg Tuparev <Tuparev@EMBL-Heidelberg.de>
   Date:    1995

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSUserDefaults
#define _mGSTEP_H_NSUserDefaults

#include <Foundation/NSObject.h>

@class NSString;
@class NSMutableString;
@class NSArray;
@class NSMutableArray;
@class NSDictionary;
@class NSMutableDictionary;
@class NSData;
@class NSDistributedLock;
@class NSURL;

/*	typical defaults domain search list:

	NSArgumentDomain		volatile
	Application				persistent
	NSGlobalDomain			persistent
	Languages				volatile
	NSRegistrationDomain	volatile
*/

@interface NSUserDefaults: NSObject
{
	NSMutableArray *_searchList;					// Current search list
	NSMutableDictionary *_persistDomain;			// persistent defaults
	NSMutableDictionary *_volatileDomain;			// volatile defaults
	NSMutableArray *_changedDomains;
	NSMutableString *_defaultsDatabase;
	NSDistributedLock *_defaultsDBLock;
	BOOL _timerActive;								// for synchronization
}

+ (NSUserDefaults *) standardUserDefaults;
+ (NSArray *) userLanguages;

- (id) init;
- (id) initWithUser:(NSString *)userName;

- (NSArray *) arrayForKey:(NSString *)defaultName;		// Get Defaults
- (BOOL) boolForKey:(NSString *)defaultName;
- (NSURL *) URLForKey:(NSString *)defaultName;
- (NSData *) dataForKey:(NSString *)defaultName;
- (NSDictionary *) dictionaryForKey:(NSString *)defaultName;
- (float) floatForKey:(NSString *)defaultName;
- (int) integerForKey:(NSString *)defaultName;
- (id) objectForKey:(NSString *)defaultName;
- (NSArray *) stringArrayForKey:(NSString *)defaultName;
- (NSString *) stringForKey:(NSString *)defaultName;

- (void) removeObjectForKey:(NSString *)defaultName;

- (void) setBool:(BOOL)value forKey:(NSString *)defaultName;
- (void) setFloat:(float)value forKey:(NSString *)defaultName;
- (void) setInteger:(int)value forKey:(NSString *)defaultName;
- (void) setObject:(id)value forKey:(NSString *)defaultName;
- (void) setURL:(NSURL *)url forKey:(NSString *)defaultName;

- (NSMutableArray *) searchList;						// Search List
- (void) setSearchList:(NSArray*)newList;
														// Persistent Domains
- (NSDictionary *) persistentDomainForName:(NSString *)domainName;
- (NSArray *) persistentDomainNames;
- (void) removePersistentDomainForName:(NSString *)domainName;
- (void) setPersistentDomain:(NSDictionary *)domain 
					 forName:(NSString *)domainName;
- (BOOL) synchronize;
														// Volatile Domains
- (void) removeVolatileDomainForName:(NSString *)domainName;
- (void) setVolatileDomain:(NSDictionary *)domain 
				   forName:(NSString *)domainName;
- (NSDictionary *) volatileDomainForName:(NSString *)domainName;
- (NSArray *) volatileDomainNames;

- (NSDictionary *) dictionaryRepresentation;
- (void) registerDefaults:(NSDictionary *)dictionary;	// Register app plist

@end

extern NSString *NSArgumentDomain;						// Standard domains
extern NSString *NSGlobalDomain;
extern NSString *NSRegistrationDomain;

extern NSString *NSUserDefaultsDidChangeNotification;	// Notifications

#endif /* _mGSTEP_H_NSUserDefaults */
