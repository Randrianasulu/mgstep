/*
   NSDictionary.h

   Collection of objects associated with unique keys

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>

   This file is part of the mGSTEP Library and is provided under the 
   terms of the libFoundation BSD type license (See the Readme file).
*/

#ifndef _mGSTEP_H_NSDictionary
#define _mGSTEP_H_NSDictionary

#include <Foundation/NSObject.h>
#include <Foundation/NSMapTable.h>

@class NSString;
@class NSArray;
@class NSEnumerator;


@interface NSDictionary : NSObject  <NSCoding, NSCopying, NSMutableCopying>

+ (id) alloc;
+ (id) dictionary;
+ (id) dictionaryWithContentsOfFile:(NSString*)path;
+ (id) dictionaryWithObjects:(NSArray*)objects forKeys:(NSArray*)keys;
+ (id) dictionaryWithObjects:(id*)objects 
					 forKeys:(id*)keys
					 count:(NSUInteger)count;
+ (id) dictionaryWithObjectsAndKeys:(id)firstObject, ...;
+ (id) dictionaryWithDictionary:(NSDictionary*)aDict;
+ (id) dictionaryWithObject:object forKey:key;

- (id) initWithContentsOfFile:(NSString*)path;
- (id) initWithDictionary:(NSDictionary*)dictionary;
- (id) initWithDictionary:(NSDictionary*)dictionary copyItems:(BOOL)flag;
- (id) initWithObjectsAndKeys:(id)firstObject,...;
- (id) initWithObjects:(NSArray*)objects forKeys:(NSArray*)keys;
- (id) initWithObjects:(id*)objects forKeys:(id*)keys count:(NSUInteger)cnt;

- (NSEnumerator*) keyEnumerator;
- (NSEnumerator*) objectEnumerator;

- (NSArray*) objectsForKeys:(NSArray*)keys notFoundMarker:(id)notFoundObj;

- (id) objectForKey:(id)aKey;

- (NSUInteger) count;
- (NSUInteger) hash;

- (BOOL) isEqualToDictionary:(NSDictionary*)other;
- (BOOL) isEqual:(id)anObject;

- (NSString*) description;
- (NSString*) descriptionInStringsFileFormat;
- (NSString*) descriptionWithLocale:(id)locale;
- (NSString*) descriptionWithLocale:(id)locale indent:(unsigned int)level;

- (BOOL) writeToFile:(NSString*)path atomically:(BOOL)useAuxiliaryFile;

@end /* NSDictionary */


@interface NSDictionary  (NSExtendedDictionary)

- (NSArray *) allKeys;
- (NSArray *) allKeysForObject:(id)object;
- (NSArray *) allValues;

- (NSArray *) keysSortedByValueUsingSelector:(SEL)comparator;

- (void) getObjects:(id*)objects andKeys:(id*)keys;

@end


@interface NSMutableDictionary : NSDictionary

+ (id) dictionaryWithCapacity:(NSUInteger)aNumItems;

@end


@interface NSMutableDictionary (NSExtendedMutableDictionary)

- (id) initWithCapacity:(NSUInteger)aNumItems;
													// Add / Remove Entries
- (void) addEntriesFromDictionary:(NSDictionary*)otherDictionary;
- (void) removeAllObjects;
- (void) removeObjectForKey:(id)theKey;
- (void) removeObjectsForKeys:(NSArray*)keyArray;
- (void) setObject:(id)anObject forKey:(id)aKey;
- (void) setDictionary:(NSDictionary*)otherDictionary;

@end

#endif /* _mGSTEP_H_NSDictionary */
