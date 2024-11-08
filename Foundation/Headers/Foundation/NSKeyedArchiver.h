/*
   NSKeyedArchiver.h

   Author: Ovidiu Predescu <ovidiu@net-community.com>
   Date: October 1997

   H.N.Schaller, Dec 2005 - API revised to be compatible to 10.4

   Fabian Spillner, May 2008 - API revised to be compatible to 10.5

   Copyright (C) 1997 Free Software Foundation, Inc.
   All rights reserved.

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSKeyedArchiver
#define _mGSTEP_H_NSKeyedArchiver

#include <Foundation/NSCoder.h>
#include <Foundation/NSHashTable.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSGeometry.h>

@class NSString;
@class NSData;
@class NSArray;
@class NSDictionary;
@class NSMutableArray;
@class NSMutableDictionary;
@class NSMutableData;
@class NSKeyedArchiver;
@class NSKeyedUnarchiver;

extern NSString *NSInvalidArchiveOperationException;
extern NSString *NSInvalidUnarchiveOperationException;


@protocol NSKeyedArchiverDelegate  <NSObject>
								// allow delegate to sub or add to runtime etc
- (id) archiver:(NSKeyedArchiver *) archiver didDecodeObject:(id)object;
- (id) archiver:(NSKeyedArchiver *) archiver willEncodeObject:(id)object;

- (void) archiverWillFinish:(NSKeyedArchiver *)unarchiver;
- (void) archiverDidFinish:(NSKeyedArchiver *)unarchiver;

- (void) archiver:(NSKeyedArchiver *)archiver
		 willReplaceObject:(id)anObject
		 withObject:(id)object;
@end


@protocol NSKeyedUnarchiverDelegate  <NSObject>
								// allow delegate to sub or add to runtime etc
- (Class) unarchiver:(NSKeyedUnarchiver *) unarchiver
		  cannotDecodeObjectOfClassName:(NSString *) name
		  originalClasses:(NSArray *) classNames;

- (id) unarchiver:(NSKeyedUnarchiver *)unarchiver didDecodeObject:(id) object;

- (void) unarchiverDidFinish:(NSKeyedUnarchiver *)unarchiver;
- (void) unarchiverWillFinish:(NSKeyedUnarchiver *)unarchiver;

- (void) unarchiver:(NSKeyedUnarchiver *)archiver
		 willReplaceObject:(id)anObject
		 withObject:(id)object;
@end

/* ****************************************************************************

	NSKeyedArchiver

** ***************************************************************************/

@interface NSKeyedArchiver : NSCoder
{
//	NSMutableDictionary *_aliasToClassMappings;		// FIX ME also have global
	NSMutableData *_data;
	NSMutableDictionary *_plist;
	id _delegate;
///	NSPropertyListFormat _outputFormat;


	NSMutableDictionary *propertyList;
	NSMutableArray *topLevelObjects;
	id lastObjectRepresentation;
	NSMapTable *objects;		// object -> name
	NSHashTable *conditionals;	// conditional objects
	NSMapTable *classes;		// real classname -> class info
	int counter;
	int level;
	BOOL writingRoot;			// YES if encodeRootObject:withName: was sent
	BOOL findingConditionals;	// YES if finding conditionals
}

+ (BOOL) archiveRootObject:(id)rootObject toFile:(NSString*)path;

- (id) init;

#if 0	/* not implemented */
+ (NSData *) archivedDataWithRootObject:(id)rootObject;
- (id) initForWritingWithMutableData:(NSMutableData *)data;

+ (void) setClassName:(NSString *)name forClass:(Class)aClass;
- (void) setClassName:(NSString *)name forClass:(Class)aClass;
+ (NSString *) classNameForClass:(Class)aClass;
- (NSString *) classNameForClass:(Class)aClass;

- (void) finishEncoding;
- (void) setDelegate:(id)delegate;
- (id) delegate;

- (void) encodeObject:(id)obj forKey:(NSString *)key;
- (void) encodeConditionalObject:(id)obj forKey:(NSString *)key;
- (void) encodeBool:(BOOL)b forKey:(NSString *)key;
- (void) encodeInt:(int)i forKey:(NSString *)key;
- (void) encodeInt32:(int32_t)i32 forKey:(NSString *)key;
- (void) encodeInt64:(int64_t)i64 forKey:(NSString *)key;
- (void) encodeFloat:(float)f forKey:(NSString *)key;
- (void) encodeDouble:(double)d forKey:(NSString *)key;
- (void) encodeBytes:(const uint8_t*)b length:(NSUInteger)l forKey:(NSString*)k;
#endif

@end /* NSKeyedArchiver */


#define KEY_CHECK 1	// set for checking if all available keys are decoded

@interface NSKeyedUnarchiver : NSCoder
{	
	NSMutableDictionary *_classToAliasMappings;
	NSData *_data;
	NSDictionary *_objectRepresentation;	// list of attributes
	NSMutableArray *_objects;			// array with all objects (either raw or decoded)
	id _delegate;
#if KEY_CHECK
	NSMutableArray *_unprocessedKeys;
#endif
	unsigned int _sequentialKey;


	NSMutableDictionary *propertyList;
	id _decodedObjectRepresentation;
	NSMutableDictionary *namesToObjects;		// object name -> object
	int level;
	int version;
}

+ (id) unarchiveObjectWithFile:(NSString *)path;
+ (id) unarchiveObjectWithData:(NSData *)data;

- (id) initForReadingWithData:(NSData *)data;

+ (Class) classForClassName:(NSString *)codedName;
- (Class) classForClassName:(NSString *)codedName;
- (void) setClass:(Class)cls forClassName:(NSString *)codedName;

- (BOOL) containsValueForKey:(NSString *) key;
- (void) finishDecoding;

- (const unsigned char *) decodeBytesForKey:(NSString *) key
							 returnedLength:(NSUInteger *) length;
- (id) decodeObjectForKey:(NSString *) key;
- (BOOL) decodeBoolForKey:(NSString *) key;
- (int) decodeIntForKey:(NSString *) key;
- (double) decodeDoubleForKey:(NSString *) key;
- (float) decodeFloatForKey:(NSString *) key;
- (int32_t) decodeInt32ForKey:(NSString *) key;
- (int64_t) decodeInt64ForKey:(NSString *) key;

- (void) setDelegate:(id)delegate;
- (id) delegate;

@end /* NSKeyedUnarchiver */

/* ****************************************************************************

	ModelCoding  (obsolete keyed property list archive format)

** ***************************************************************************/

@protocol ModelCoding

/* 
   objects to be archived observe this protocol.

   These methods are much like those from the NSCoding protocol.
   The difference is that you can specify names for the instance
   variables or attributes you encode. The recommended way is not to encode
   instance variables but attributes so that an archive file does not
   depend on the particular version of a class or on different
   instance variable names of the class from another implementation. 
*/

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver;
- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver;

@end


@interface NSObject (ModelArchivingMethods)

+ (id) createObjectForModelUnarchiver:(NSKeyedUnarchiver*)unarchiver;
- (id) replacementObjectForModelArchiver:(NSKeyedArchiver*)archiver;
- (Class) classForModelArchiver;

@end


@interface NSKeyedArchiver  (GMUnarchiver)
															// Archiving Data
+ (BOOL) archiveRootObject:(id)rootObject toFile:(NSString*)path;
- (BOOL) writeToFile:(NSString*)path;

- (id) propertyList;	// Get property list representation from the GMArchiver

															// Encode objects
- (id) encodeRootObject:(id)rootObject withName:(NSString*)name;
- (id) encodeConditionalObject:(id)object withName:(NSString*)name;
- (id) encodeObject:(id)anObject withName:(NSString*)name;
- (id) encodeString:(NSString*)anObject withName:(NSString*)name;
- (id) encodeArray:(NSArray*)array withName:(NSString*)name;
- (id) encodeDictionary:(NSDictionary*)dictionary withName:(NSString*)name;
- (id) encodeData:(NSData*)anObject withName:(NSString*)name;
- (id) encodeClass:(Class)cls withName:(NSString*)name;
- (id) encodeSelector:(SEL)selector withName:(NSString*)name;
															// Encode C types
- (void) encodeChar:(char)value withName:(NSString*)name;
- (void) encodeUnsignedChar:(unsigned char)value withName:(NSString*)name;
- (void) encodeBOOL:(BOOL)value withName:(NSString*)name;
- (void) encodeShort:(short)value withName:(NSString*)name;
- (void) encodeUnsignedShort:(unsigned short)value withName:(NSString*)name;
- (void) encodeInt:(int)value withName:(NSString*)name;
- (void) encodeUnsignedInt:(unsigned int)value withName:(NSString*)name;
- (void) encodeLong:(long)value withName:(NSString*)name;
- (void) encodeUnsignedLong:(unsigned long)value withName:(NSString*)name;
- (void) encodeFloat:(float)value withName:(NSString*)name;
- (void) encodeDouble:(double)value withName:(NSString*)name;

- (void) encodeSize:(NSSize)size withName:(NSString*)name;	// Encode geometry
- (void) encodeRect:(NSRect)rect withName:(NSString*)name;
- (void) encodePoint:(NSPoint)point withName:(NSString*)name;

											// Substitute One Class for Another
- (NSString*) classNameEncodedForTrueClassName:(NSString*)trueName;
- (void) encodeClassName:(NSString*)trueName
		   intoClassName:(NSString*)inArchiveName;
@end


@interface NSKeyedUnarchiver  (GMUnarchiver)

+ (id) unarchiverWithContentsOfFile:(NSString*)filename;	// Initialize
- (id) initForReadingWithPropertyList:(id)propertyList;

+ (id) unarchiveObjectWithName:(NSString*)name				// Decode Objects
	   fromPropertyList:(id)propertyList;
+ (id) unarchiveObjectWithName:(NSString*)name fromFile:(NSString*)path;

- (id) decodedObjectRepresentation;

- (id) decodeObjectWithName:(NSString*)name;				// Decode objects
- (NSString*) decodeStringWithName:(NSString*)name;
- (NSArray*) decodeArrayWithName:(NSString*)name;
- (NSDictionary*) decodeDictionaryWithName:(NSString*)name;
- (NSData*) decodeDataWithName:(NSString*)name;
- (Class) decodeClassWithName:(NSString*)name;
- (SEL) decodeSelectorWithName:(NSString*)name;

- (char) decodeCharWithName:(NSString*)name;				// Decode C types
- (unsigned char) decodeUnsignedCharWithName:(NSString*)name;
- (BOOL) decodeBOOLWithName:(NSString*)name;
- (short) decodeShortWithName:(NSString*)name;
- (unsigned short) decodeUnsignedShortWithName:(NSString*)name;
- (int) decodeIntWithName:(NSString*)name;
- (unsigned int) decodeUnsignedIntWithName:(NSString*)name;
- (long) decodeLongWithName:(NSString*)name;
- (unsigned long) decodeUnsignedLongWithName:(NSString*)name;
- (float) decodeFloatWithName:(NSString*)name;
- (double) decodeDoubleWithName:(NSString*)name;
															// Decode geometry
- (NSPoint) decodePointWithName:(NSString*)name;
- (NSSize) decodeSizeWithName:(NSString*)name;
- (NSRect) decodeRectWithName:(NSString*)name;

- (BOOL) isAtEnd;									// Manage a GMUnarchiver
- (unsigned int) systemVersion;
											// Substitute One Class for Another
+ (NSString*) classNameDecodedForArchiveClassName:(NSString*)nameInArchive;
+ (void) decodeClassName:(NSString*)nameInArchive
			 asClassName:(NSString*)trueName;
- (NSString*) classNameDecodedForArchiveClassName:(NSString*)nameInArchive;
- (void) decodeClassName:(NSString*)nameInArchive
			 asClassName:(NSString*)trueName;
- (unsigned int) versionForClassName:(NSString*)className;

@end

#endif /* _mGSTEP_H_NSKeyedArchiver */
