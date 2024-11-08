/* 
   NSArchiver.h

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>

   This file is part of the mGSTEP Library and is provided under the 
   terms of the libFoundation BSD type license (See the Readme file).
*/

#ifndef _mGSTEP_H_NSArchiver
#define _mGSTEP_H_NSArchiver

#include <Foundation/NSCoder.h>
#include <Foundation/NSHashTable.h>
#include <Foundation/NSMapTable.h>

@class NSMutableData;
@class NSData;


@interface NSArchiver : NSCoder
{
    NSMutableData *_mdata;
    NSHashTable *objects;		// objects written so far
    NSHashTable *conditionals;	// conditional objects
    NSMapTable *classes;		// real classname -> class info
    NSHashTable *pointers;		// set of pointers
    IMP writeIMP;				// write IMP of mdata
    BOOL writingRoot;			// YES if encodeRootObject: was sent
    BOOL findingConditionals;	// YES if finding conditionals
}

+ (NSData*) archivedDataWithRootObject:(id)rootObject;
+ (BOOL) archiveRootObject:(id)rootObject toFile:(NSString*)path;

- (id) initForWritingWithMutableData:(NSMutableData*)mdata;

- (void) encodeConditionalObject:(id)object;
- (void) encodeRootObject:(id)rootObject;

	// Getting Data from the NSArchiver
- (NSMutableData*) archiverData;

	// Substituting One Class for Another
- (NSString*) classNameEncodedForTrueClassName:(NSString*)trueName;
- (void) encodeClassName:(NSString*)trueName
		   intoClassName:(NSString*)inArchiveName;

@end /* NSArchiver */


@interface NSUnarchiver : NSCoder
{
    NSData *_data;
    unsigned cursor;
    IMP readIMP;				// read function of encodingFormat
    unsigned archiverVersion;	// archiver's version that wrote the data
    NSMapTable *objects;		// decoded objects: key -> object
    NSMapTable *classes;		// decoded classes: key -> class info
    NSMapTable *pointers;		// decoded pointers: key -> pointer
    NSMapTable *classAlias;		// archive name -> decoded name
    NSMapTable *classVersions;	// archive name -> class info
}

+ (id) unarchiveObjectWithData:(NSData*)data;			// Decoding Objects
+ (id) unarchiveObjectWithFile:(NSString*)path;

- (id) initForReadingWithData:(NSData*)data;

- (void) decodeArrayOfObjCType:(const char*)itemType
						 count:(NSUInteger)count
						 at:(void*)array;
- (BOOL) isAtEnd;
- (unsigned int) systemVersion;

	// Substituting One Class for Another
+ (NSString*) classNameDecodedForArchiveClassName:(NSString*)nameInArchive;
+ (void) decodeClassName:(NSString*)nameInArchive
			 asClassName:(NSString*)trueName;

- (NSString*) classNameDecodedForArchiveClassName:(NSString*)nameInArchive;
- (void) decodeClassName:(NSString*)nameInArchive
			 asClassName:(NSString*)trueName;
- (unsigned int) versionForClassName:(NSString*)className;

@end


extern NSString *NSInconsistentArchiveException;		// exceptions

#endif /* _mGSTEP_H_NSArchiver */
