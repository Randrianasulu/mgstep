/*
	NSNib.h

	NIB object archives

	Created by Dr. H. Nikolaus Schaller on Sat Jan 07 2006.
	Copyright (c) 2005 DSITRI.

	Author:	Fabian Spillner <fabian.spillner@gmail.com>
	Date:	14. November 2007 - aligned with 10.5 

	This file is part of the mGSTEP Library and is provided
	under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSNib
#define _mGSTEP_H_NSNib

#include <Foundation/NSBundle.h>

@class NSArray;
@class NSString;
@class NSDictionary;
@class NSMutableSet;


extern NSString *NSNibOwner;
extern NSString *NSNibTopLevelObjects;


@interface NSNib : NSObject  <NSCoding>
{
	id _owner;
	id _decoded;		// decoded root object tree
	NSMutableSet *_decodedObjects;
	NSBundle *_bundle;	// bundle where we should locate resources
	NSString *_path;
	NSData *_data;
}

- (id) initWithNibNamed:(NSString *)name bundle:(NSBundle *)bundle;
- (BOOL) instantiateWithOwner:(id)owner topLevelObjects:(NSArray **)objects;

@end

/* ****************************************************************************

	NSNibDeclarations

** ***************************************************************************/

#ifndef __USE_LIBOBJC2__
	#define IBOutlet
	#define IBAction void
#endif

/* ****************************************************************************

	NSNibLoading

	Load named NIB file with designated owner.  Returns array of top level
	objects if optional param is given, returned objects are autoreleased,
	retain (strong ref) the objets or array to prevent dealloc.

** ***************************************************************************/

@interface NSBundle  (NSNibLoading)

- (BOOL) loadNibNamed:(NSString *)nibName
				owner:(id)owner
				topLevelObjects:(NSArray **)topLevelObjects;

+ (BOOL) loadNibNamed:(NSString*)nibName owner:(id)owner;		// deprecated

@end


@interface NSObject  (NSNibAwaking)

- (void) awakeFromNib;

@end

/* ****************************************************************************

	NSNibConnector

** ***************************************************************************/

@interface NSNibConnector : NSObject  <NSCoding>
{
	id _source;
	id _destination;
	NSString *_label;
}

- (id) source;
- (id) destination;
- (NSString *) label;

- (void) setSource:(id)source;
- (void) setDestination:(id)dest;
- (void) setLabel:(NSString *)label;

- (void) establishConnection;
- (void) replaceObject:(id)aObject withObject:(id)bObject;

@end


@interface NSIBUserDefinedRuntimeAttributesConnector : NSObject  <NSCoding>
{
	id _destination;
	NSArray *_keyPaths;
	NSArray *_values;
}
@end

/* ****************************************************************************

	NSNibControlConnector

** ***************************************************************************/

@interface NSNibControlConnector : NSNibConnector

- (void) establishConnection;

@end

/* ****************************************************************************

	NSNibOutletConnector

** ***************************************************************************/

@interface NSNibOutletConnector : NSNibConnector

- (void) establishConnection;

@end

/* ****************************************************************************

	GMModel

	Load MIB property list format  (obsolete)

** ***************************************************************************/

@interface GMModel : NSObject
{
	NSArray *_objects;
	NSArray *_connections;
}

+ (BOOL) loadMibFile:(NSString*)path owner:(id)owner;
+ (BOOL) loadMibFile:(NSString*)path owner:(id)owner bundle:(NSBundle*)bundle;

@end

#endif  /* _mGSTEP_H_NSNib */
