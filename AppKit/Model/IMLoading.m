/*
   IMLoading.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@net-community.com>
   Date: November 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSKeyedArchiver.h>

#include <AppKit/NSNibLoading.h>
#include "IMCustomObject.h"


id __nibOwner = nil;
static BOOL __fileOwnerDecoded = NO;



@implementation GMModel

+ (BOOL) loadMibFile:(NSString*)path owner:(id)owner
{
	return [self loadMibFile:path owner:owner bundle:[NSBundle mainBundle]];
}

+ (BOOL) loadMibFile:(NSString*)path
			   owner:(id)owner
			   bundle:(NSBundle*)bundle
{
	NSKeyedUnarchiver *unarchiver;
	id previousNibOwner = __nibOwner;
	GMModel *decoded;
	int i, count;

	if (![path hasSuffix:@".mib"])
		path = [path stringByAppendingPathExtension:@"mib"];

	if ([path isAbsolutePath]) 				// determine if path is absolute
		{									// and that it exists
		if (![[NSFileManager defaultManager] fileExistsAtPath:path])
			return NO;
		}
	else 
		{									// relative path; search in current
		NSString *p;						// bundle, in MGSTEP_ROOT system
											// bundle and in main if needed
		if(!(p = [bundle pathForResource:path ofType:nil inDirectory:nil])) 
			if(!(p = [[NSBundle systemBundle] pathForResource:path
											  ofType:nil
											  inDirectory:@"AppKit/Panels"]))
				if(!(p = [[NSBundle mainBundle] pathForResource:path 
												ofType:nil 
												inDirectory:nil])) 
					return NO;

		path = p;
		}
	NSLog (@"loading model file %@\n", path);

	if (!(unarchiver = [NSKeyedUnarchiver unarchiverWithContentsOfFile:path]))
		return NO;				
								// Set __nibOwner to `owner' so that the first 
	__nibOwner = owner;			// decoded custom object replaces itself with
	__fileOwnerDecoded = NO;	// `owner'. Also set __fileOwnerDecoded so that
								// the first custom object knows it's the first
	decoded = [unarchiver decodeObjectWithName:@"RootObject"];
	[decoded->_connections makeObjectsPerformSelector:@selector(establishConnection)];

	for (i = 0, count = [decoded->_objects count]; i < count; i++)
		{
		id o = [[decoded->_objects objectAtIndex:i] nibInstantiate];

		if ([o respondsToSelector:@selector(awakeFromNib)])
			[o awakeFromNib];							// Send awakeFromNib
		}
										// Restore previous nib owner.  Do this
	__nibOwner = previousNibOwner;		// because loadMibFile:owner: may be
										// invoked recursively.
	return YES;
}

- (void) dealloc
{
	[_objects release];
	[_connections release];
	[super dealloc];
}

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver
{
	[archiver encodeObject:_objects withName:@"Objects"];
	[archiver encodeObject:_connections withName:@"Connections"];
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	_objects = [[unarchiver decodeObjectWithName:@"Objects"] retain];
	_connections = [[unarchiver decodeObjectWithName:@"Connections"] retain];

	return self;
}

@end /* GMModel */


@implementation NSObject (ModelUnarchiving)

- (id) nibInstantiate					{ return self; }

@end


@implementation IMCustomObject

+ (id) createObjectForModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
IMCustomObject *customObject = [[self new] autorelease];
Class class;

	customObject->className = [unarchiver decodeStringWithName:@"className"];
	customObject->realObject = [unarchiver decodeObjectWithName:@"realObject"];

	if (!__fileOwnerDecoded) 
		{
		__fileOwnerDecoded = YES;
		customObject->realObject = __nibOwner;

		return customObject;
		}

	if ((class = NSClassFromString (customObject->className)))
		customObject->realObject = [[class alloc] init];
	else 
		NSLog(@"Class %@ not linked into application",customObject->className);

	return customObject;
}

- (id) nibInstantiate					{ return realObject; }

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver
{
	[archiver encodeString:className withName:@"className"];
	if (realObject)
		[archiver encodeObject:realObject withName:@"realObject"];
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	return self;
}

@end /* IMCustomObject */
