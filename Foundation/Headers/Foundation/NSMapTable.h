/*
   NSMapTable.h

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>

   This file is part of the mGSTEP Library and is provided under the 
   terms of the libFoundation BSD type license (See the Readme file).
*/

#ifndef _mGSTEP_H_NSMapTable
#define _mGSTEP_H_NSMapTable

#include <Foundation/NSObject.h>

@class NSArray;

#define NSNotAnIntMapKey 		((const void *)NSIntegerMin)
#define NSNotAPointerMapKey 	((const void *)NSUIntegerMax)


struct _NSMapTable;

struct _NSMapNode {
    void *key;
    void *value;
    struct _NSMapNode *next;
};

typedef struct _NSMapTableKeyCallBacks {
    NSUInteger (*hash)(struct _NSMapTable *t, const void *anObject);
    BOOL (*isEqual)(struct _NSMapTable *t, const void *obj1, const void *obj2);
    void (*retain)(struct _NSMapTable *t, const void *anObject);
    void (*release)(struct _NSMapTable *t, void *anObject);
    NSString  *(*describe)(struct _NSMapTable *t, const void *anObject);
    const void *notAKeyMarker;
} NSMapTableKeyCallBacks;

typedef struct _NSMapTableValueCallBacks {
    void (*retain)(struct _NSMapTable *t, const void *anObject);
    void (*release)(struct _NSMapTable *t, void *anObject);
    NSString  *(*describe)(struct _NSMapTable *t, const void *anObject);
} NSMapTableValueCallBacks;


typedef struct _NSMapTable {
	struct _NSMapNode **nodes;
	NSUInteger hashSize;
	NSUInteger itemsCount;
	NSMapTableKeyCallBacks keyCallbacks;
	NSMapTableValueCallBacks valueCallbacks;
} NSMapTable;

typedef struct NSMapEnumerator {
    struct _NSMapTable *table;
    struct _NSMapNode *node;
    int bucket;
} NSMapEnumerator;

														// Predefined callbacks
extern const NSMapTableKeyCallBacks   NSIntMapKeyCallBacks;
extern const NSMapTableKeyCallBacks   NSObjectMapKeyCallBacks; 
extern const NSMapTableKeyCallBacks   NSOwnedPointerMapKeyCallBacks;
extern const NSMapTableKeyCallBacks   NSNonOwnedPointerMapKeyCallBacks;
extern const NSMapTableKeyCallBacks   NSNonOwnedCStringMapKeyCallBacks;
extern const NSMapTableKeyCallBacks   NSNonOwnedPointerOrNullMapKeyCallBacks;
extern const NSMapTableKeyCallBacks   NSNonRetainedObjectMapKeyCallBacks;

extern const NSMapTableValueCallBacks NSIntMapValueCallBacks;
extern const NSMapTableValueCallBacks NSObjectMapValueCallBacks;
extern const NSMapTableValueCallBacks NSOwnedPointerMapValueCallBacks;
extern const NSMapTableValueCallBacks NSNonOwnedPointerMapValueCallBacks;
extern const NSMapTableValueCallBacks NSNonRetainedObjectMapValueCallBacks;

														// Create a Table
NSMapTable *NSCreateMapTable( NSMapTableKeyCallBacks keyCallBacks,
							  NSMapTableValueCallBacks valueCallBacks,
							  NSUInteger capacity);
NSMapTable *NSCopyMapTable(NSMapTable *t);

void NSFreeMapTable(NSMapTable *t);						// Free Table
void NSResetMapTable(NSMapTable *t);
														// Compare Two Tables
BOOL NSCompareMapTables(NSMapTable *t1, NSMapTable *t2);

NSUInteger NSCountMapTable(NSMapTable *t);				// Number of Items

BOOL NSMapMember(NSMapTable *t,							// Retrieve Items
				 const void *key,
				 void **originalKey,
				 void **value);

void * NSMapGet(NSMapTable *t, const void *key);

NSMapEnumerator NSEnumerateMapTable(NSMapTable *t);

BOOL NSNextMapEnumeratorPair(NSMapEnumerator *e, void **key, void **value);

NSArray *NSAllMapTableKeys(NSMapTable *t);
NSArray *NSAllMapTableValues(NSMapTable *t);
														// Add or Remove Items
void NSMapInsert(NSMapTable *t, const void *key, const void *value);
void * NSMapInsertIfAbsent(NSMapTable *t, const void *key, const void *value);
void NSMapInsertKnownAbsent(NSMapTable *t, const void *key, const void *value);
void NSMapRemove(NSMapTable *t, const void *key);

NSString * NSStringFromMapTable(NSMapTable *t);

#endif /* _mGSTEP_H_NSMapTable */
