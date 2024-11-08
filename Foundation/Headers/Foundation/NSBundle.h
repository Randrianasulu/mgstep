/*
   NSBundle.h

   Dynamic loading of resources.

   Copyright (C) 1995, 1997 Free Software Foundation, Inc.

   Author:	Adam Fedor <fedor@boulder.colorado.edu>
   Date:	1995

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSBundle
#define _mGSTEP_H_NSBundle

#include <Foundation/NSObject.h>

#define NSLocalizedString(key, comment) \
	[[NSBundle mainBundle] localizedStringForKey:(key) value:@"" table:nil]

#define NSLocalizedStringFromTable(key, tbl, comment) \
	[[NSBundle mainBundle] localizedStringForKey:(key) value:@"" table:(tbl)]

#define NSLocalizedStringFromTableInBundle(key, tbl, bundle, comment) \
	[bundle localizedStringForKey:(key) value:@"" table:(tbl)]

@class NSURL;
@class NSString;
@class NSArray;
@class NSDictionary;
@class NSMutableArray;
@class NSMutableDictionary;

extern NSString *NSBundleDidLoadNotification;
extern NSString *NSLoadedClasses;


@interface NSBundle : NSObject
{
    NSString *_path;
    NSMutableArray *_bundleClasses;
    NSMutableDictionary *_searchPaths;
	Class _principalClass;
    id _infoDict;
	BOOL _codeLoaded;
	unsigned int _bundleType;
}

+ (NSBundle *) mainBundle;
+ (NSBundle *) bundleForClass:(Class)aClass;
+ (NSBundle *) bundleWithPath:(NSString *)path;

- (id) initWithPath:(NSString *)path;

- (Class) classNamed:(NSString *)className;
- (Class) principalClass;

- (BOOL) load;

- (NSString *) bundlePath;
- (NSString *) resourcePath;
//- (NSString *) executablePath;
- (NSDictionary *) infoDictionary;

- (NSArray *) pathsForResourcesOfType:(NSString *)extension
						  inDirectory:(NSString *)bundlePath;

- (NSString *) pathForResource:(NSString *)name ofType:(NSString *)ext;
- (NSString *) pathForResource:(NSString *)name
						ofType:(NSString *)ext	
						inDirectory:(NSString *)bundlePath;

- (NSURL *) URLForResource:(NSString *)name withExtension:(NSString *)ext;
- (NSURL *) URLForResource:(NSString *)name
			 withExtension:(NSString *)ext
			  subdirectory:(NSString *)subpath;

- (NSString *) localizedStringForKey:(NSString *)key
							   value:(NSString *)value
							   table:(NSString *)tableName;
@end


@interface NSBundle (mGSTEP)

+ (NSBundle *) systemBundle;

@end

#endif /* _mGSTEP_H_NSBundle */
