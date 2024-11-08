/* 
   NSHashTable.h

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>

   This file is part of the mGSTEP Library and is provided under the 
   terms of the libFoundation BSD type license (See the Readme file).
*/

#ifndef _mGSTEP_H_NSHashTable
#define _mGSTEP_H_NSHashTable

#include <Foundation/NSObject.h>

@class NSArray;

struct _NSHashTable;

typedef struct _NSHashTableCallBacks {
    NSUInteger (*hash)(struct _NSHashTable *table, const void *anObject);
    BOOL (*isEqual)(struct _NSHashTable *table, const void *anObject1, 
					const void *anObject2);
    void (*retain)(struct _NSHashTable *table, const void *anObject);
    void (*release)(struct _NSHashTable *table, void *anObject);
    NSString *(*describe)(struct _NSHashTable *table, const void *anObject);
} NSHashTableCallBacks;

struct _NSHashNode {
    void *key;
    struct _NSHashNode *next;
};

typedef struct _NSHashTable {
    struct _NSHashNode **nodes;
    NSUInteger hashSize;
    NSUInteger itemsCount;
    NSHashTableCallBacks callbacks;
} NSHashTable;

typedef struct _NSHashEnumerator {
    struct _NSHashTable *table;
    struct _NSHashNode *node;
    int bucket;
} NSHashEnumerator;

													// Predefined callback sets
extern const NSHashTableCallBacks NSIntHashCallBacks;
extern const NSHashTableCallBacks NSNonOwnedPointerHashCallBacks; 
extern const NSHashTableCallBacks NSNonRetainedObjectHashCallBacks; 
extern const NSHashTableCallBacks NSObjectHashCallBacks; 
extern const NSHashTableCallBacks NSOwnedObjectIdentityHashCallBacks; 
extern const NSHashTableCallBacks NSOwnedPointerHashCallBacks; 
extern const NSHashTableCallBacks NSPointerToStructHashCallBacks; 


NSHashTable *											// Create a Table
NSCreateHashTable(NSHashTableCallBacks callBacks, NSUInteger capacity);

NSHashTable *
NSCreateHashTable(NSHashTableCallBacks callBacks, NSUInteger capacity);

NSHashTable *
NSCopyHashTable(NSHashTable *table);

void NSFreeHashTable(NSHashTable *table); 				// Free a Table
void NSResetHashTable(NSHashTable *table); 
														// Compare Tables
BOOL NSCompareHashTables(NSHashTable *table1, NSHashTable *table2);	

NSUInteger NSCountHashTable(NSHashTable *table);

NSArray *NSAllHashTableObjects(NSHashTable *table);		// Retrieve Items
void *NSHashGet(NSHashTable *table, const void *pointer);
void *NSNextHashEnumeratorItem(NSHashEnumerator *enumerator);
NSHashEnumerator NSEnumerateHashTable(NSHashTable *table);
														// Add / Remove an Item
void NSHashInsert(NSHashTable *table, const void *pointer);
void NSHashInsertKnownAbsent(NSHashTable *table, const void *pointer);
void *NSHashInsertIfAbsent(NSHashTable *table, const void *pointer);
void NSHashRemove(NSHashTable *table, const void *pointer);

NSString *NSStringFromHashTable(NSHashTable *table);	// String Representation

//
// Convenience functions to deal with Hash and Map Table
//
NSUInteger _NSHashObject(void* table, const void* anObject);
NSUInteger _NSHashPointer(void* table, const void* anObject);
NSUInteger _NSHashInteger(void* table, const void* anObject);
NSUInteger _NSHashCString(void* table, const void* anObject);

BOOL _NSCompareObjects(void* table, const void* aObj1, const void* aObj2);
BOOL _NSComparePointers(void* table, const void* aObj1, const void* aObj2);
BOOL _NSCompareInts(void* table, const void* aObj1, const void* aObj2);
BOOL _NSCompareCString(void* table, const void* aObj1, const void* aObj2);

void _NSRetainNothing(void* table, const void* anObject);
void _NSRetainObjects(void* table, const void* anObject);
void _NSReleaseNothing(void* table, void* anObject);
void _NSReleaseObjects(void* table, void* anObject);
void _NSReleasePointers(void* table, void* anObject);

NSString *_NSDescribeObjects(void* table, const void* anObject);
NSString *_NSDescribePointers(void* table, const void* anObject);
NSString *_NSDescribeInts(void* table, const void* anObject);

#endif /* _mGSTEP_H_NSHashTable */
