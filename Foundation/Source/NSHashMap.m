/*
   NSHashMap.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
	   Mircea Oancea <mircea@jupiter.elcom.pub.ro>

   This file is part of the mGSTEP Library and is provided under the 
   terms of the libFoundation BSD type license (See the Readme file).
*/

#include <Foundation/NSHashTable.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSArray.h>

#include <math.h>


static void _NSHashGrow(NSHashTable *table, NSUInteger newSize);
static void _NSMapGrow(NSMapTable *table, NSUInteger newSize);


static BOOL
is_prime(NSUInteger n)							// Hash / Map table utilities
{
	int i, n2;

	if(n % 2 == 0)
		return NO;
	n2 = sqrt(n);
    for(i = 3; i <= n2; i+=2)
        if(n % i == 0)
            return NO;

    return YES;
}

static NSUInteger 
nextPrime(NSUInteger old_value)
{
	NSUInteger i, new_value = old_value | 1;

    for(i = new_value; i >= new_value; i += 2)
        if(is_prime(i))
            return i;

	return old_value;
}

static void 								
_NSCheckHashTableFull(NSHashTable* table)
{
    if( ++(table->itemsCount) >= ((table->hashSize * 3) / 4))
		{
		NSUInteger newSize = nextPrime((table->hashSize * 4) / 3);
		if(newSize != table->hashSize)
			_NSHashGrow(table, newSize);
		}
}

static void 
_NSCheckMapTableFull(NSMapTable* table)
{
    if( ++(table->itemsCount) >= ((table->hashSize * 3) / 4))
		{
		NSUInteger newSize = nextPrime((table->hashSize * 4) / 3);
		if(newSize != table->hashSize)
			_NSMapGrow(table, newSize);
		}
}

/* ****************************************************************************

	NSHashTable functions

** ***************************************************************************/

NSHashTable *
NSCreateHashTable(NSHashTableCallBacks callBacks, NSUInteger capacity)
{
	NSHashTable *t = malloc(sizeof(NSHashTable));

    capacity = capacity ? capacity : 13;
    if (!is_prime(capacity))
		capacity = nextPrime(capacity);

    t->hashSize = capacity;
    t->nodes = calloc(t->hashSize, sizeof(void*));
    t->itemsCount = 0;
    t->callbacks = callBacks;
    if (t->callbacks.hash == NULL)
		t->callbacks.hash = (NSUInteger(*)(NSHashTable*, const void*))_NSHashPointer;
    if (t->callbacks.isEqual == NULL)
		t->callbacks.isEqual = (BOOL(*)(NSHashTable*, const void*, const void*)) _NSComparePointers;
    if (t->callbacks.retain == NULL)
		t->callbacks.retain = (void(*)(NSHashTable*, const void*))_NSRetainNothing;
    if (t->callbacks.release == NULL)
		t->callbacks.release = (void(*)(NSHashTable*, void*))_NSReleaseNothing;
    if (t->callbacks.describe == NULL)
		t->callbacks.describe = (NSString*(*)(NSHashTable*, const void*))_NSDescribePointers;

    return t;
}

NSHashTable *
NSCopyHashTable(NSHashTable *table)
{
	NSUInteger i;
	struct _NSHashNode *oldnode, *newnode;
	NSHashTable *new = malloc(sizeof(NSHashTable));
    
    new->hashSize = table->hashSize;
    new->itemsCount = table->itemsCount;
    new->callbacks = table->callbacks;
    new->nodes = calloc(new->hashSize, sizeof(void*));
    
    for (i = 0; i < new->hashSize; i++) 
		{
		for (oldnode = table->nodes[i]; oldnode; oldnode = oldnode->next) 
			{
			newnode = malloc(sizeof(struct _NSHashNode));
			newnode->key = oldnode->key;
			newnode->next = new->nodes[i];
			new->nodes[i] = newnode;
			table->callbacks.retain(new, oldnode->key);
		}	}
    
    return new;
}

void 
NSFreeHashTable(NSHashTable *table)
{
    NSResetHashTable(table);
    free(table->nodes);
    free(table);
}

void 
NSResetHashTable(NSHashTable *table)
{
	NSUInteger i;

    for(i = 0; i < table->hashSize; i++) 
		{
		struct _NSHashNode *next, *node;
		
		node = table->nodes[i];
		table->nodes[i] = NULL;		
		while (node) 
			{
			table->callbacks.release(table, node->key);
			next = node->next;
			free(node);
			node = next;
		}	}

    table->itemsCount = 0;
}

BOOL 
NSCompareHashTables(NSHashTable *table1, NSHashTable *table2)
{
	NSUInteger i;											// Compare Tables
	struct _NSHashNode *node1;
	
    if (table1->hashSize != table2->hashSize)
		return NO;
    for (i = 0; i < table1->hashSize; i++)
		{ 
		for (node1 = table1->nodes[i]; node1; node1 = node1->next) 
	    	if (NSHashGet(table2, node1->key) == NULL)
				return NO;
		}

    return YES;;
}	

NSUInteger
NSCountHashTable(NSHashTable *table)			{ return table->itemsCount;	}

void *
NSHashGet(NSHashTable *table, const void *pointer)
{
	struct _NSHashNode *node;								// Retrieve Items

	node =table->nodes[table->callbacks.hash(table,pointer) % table->hashSize];
    for(; node; node = node->next)
        if(table->callbacks.isEqual(table, pointer, node->key))
            return node->key;

    return NULL;
}

NSArray *
NSAllHashTableObjects(NSHashTable *table)
{
	id array = [NSMutableArray arrayWithCapacity:table->itemsCount];
	struct _NSHashNode *node;
	NSUInteger i;

    for(i = 0; i < table->hashSize; i++)
		for(node = table->nodes[i]; node; node = node->next)
			[array addObject:(NSObject*)(node->key)];

    return array;
}

NSHashEnumerator 
NSEnumerateHashTable(NSHashTable *table)
{
    return (NSHashEnumerator){table, NULL, -1};
}

void *
NSNextHashEnumeratorItem(NSHashEnumerator *en)
{
    if(en->node)
		en->node = en->node->next;
    if(en->node == NULL)
		{
		for(en->bucket++; ((NSUInteger)en->bucket) < en->table->hashSize;
				en->bucket++)
			if (en->table->nodes[en->bucket])
				{
				en->node = en->table->nodes[en->bucket];
				break;
				};

		if (((NSUInteger)en->bucket) >= en->table->hashSize)
			{
			en->node = NULL;
			en->bucket = en->table->hashSize - 1;

			return NULL;
		}	}

    return en->node->key;
}

static void 
_NSHashGrow(NSHashTable *table, NSUInteger newSize)
{
	NSUInteger i;
	struct _NSHashNode **newNodeTable =calloc(newSize,sizeof(struct _NSHashNode*));
    
    for(i = 0; i < table->hashSize; i++) 
		{
		struct _NSHashNode *next, *node;
		NSUInteger h;

		node = table->nodes[i];
		while(node) 
			{
			next = node->next;
			h = table->callbacks.hash(table, node->key) % newSize;
			node->next = newNodeTable[h];
			newNodeTable[h] = node;
			node = next;
		}	}

    free(table->nodes);
	table->nodes = newNodeTable;
    table->hashSize = newSize;
}

void 
NSHashInsert(NSHashTable *table, const void *pointer)
{
	NSUInteger h;
	struct _NSHashNode *node;

    if (pointer == nil)
		[NSException raise: NSInvalidArgumentException
        			 format: @"Nil object to be added in NSHashTable."];

    h = table->callbacks.hash(table, pointer) % table->hashSize;
    for(node = table->nodes[h]; node; node = node->next)
        if(table->callbacks.isEqual(table, pointer, node->key))
            break;
						// Check if an entry for key exists in nodeTable.
    if(node)
		{							// key exists. Set new value and 
		if (pointer != node->key)	// return it's old value of it
			{
			table->callbacks.retain(table, pointer);
			table->callbacks.release(table, node->key);
			}
		node->key = (void*)pointer;

        return;
		}
					// key not found. Allocate a new bucket and initialize it.
    node = malloc(sizeof(struct _NSHashNode));
	table->callbacks.retain(table, pointer);
    node->key = (void*)pointer;
    node->next = table->nodes[h];
    table->nodes[h] = node;

    _NSCheckHashTableFull(table);
}

void 
NSHashInsertKnownAbsent(NSHashTable *table, const void *pointer)
{
	NSUInteger h;
	struct _NSHashNode *node;

    if (pointer == nil)
		[NSException raise: NSInvalidArgumentException
        			 format: @"Nil object to be added in NSHashTable."];

    h = table->callbacks.hash(table, pointer) % table->hashSize;
    for(node = table->nodes[h]; node; node = node->next)
        if(table->callbacks.isEqual(table, pointer, node->key))
            break;

    if(node)				// Check if an entry for key exist in nodeTable.
		[NSException raise: NSInvalidArgumentException
        			 format: @"Nil object already existing in NSHashTable."];
							// key not found. Alloc and init a new bucket
    node = malloc(sizeof(struct _NSHashNode));
	table->callbacks.retain(table, pointer);
    node->key = (void*)pointer;
    node->next = table->nodes[h];
    table->nodes[h] = node;

    _NSCheckHashTableFull(table);
}

void *
NSHashInsertIfAbsent(NSHashTable *table, const void *pointer)
{
	NSUInteger h;
	struct _NSHashNode *node;

    if (pointer == nil)
		[NSException raise: NSInvalidArgumentException
        			 format: @"Nil object to be added in NSHashTable."];

    h = table->callbacks.hash(table, pointer) % table->hashSize;
    for(node = table->nodes[h]; node; node = node->next)
        if(table->callbacks.isEqual(table, pointer, node->key))
            break;

    if(node)				// Check if an entry for key exist in nodeTable.
		return node->key;
							// key not found. Alloc and init a new bucket
    node = malloc(sizeof(struct _NSHashNode));
    table->callbacks.retain(table, pointer);
    node->key = (void*)pointer;
    node->next = table->nodes[h];
    table->nodes[h] = node;

    _NSCheckHashTableFull(table);
    
    return NULL;
}

void 
NSHashRemove(NSHashTable *table, const void *pointer)
{
	NSUInteger h;
	struct _NSHashNode *node, *node1 = NULL;

    if (pointer == nil)
	    return;

    h = table->callbacks.hash(table, pointer) % table->hashSize;
    			// node points to current bucket, and node1 to previous bucket 
				// or to NULL if current node is the first node in the list 
    for(node = table->nodes[h]; node; node1 = node, node = node->next)
        if(table->callbacks.isEqual(table, pointer, node->key))
			{
			table->callbacks.release(table, node->key);
            if(!node1)
                table->nodes[h] = node->next;
            else
                node1->next = node->next;
			free(node);
			(table->itemsCount)--;
	
			return;
			}
}

NSString *
NSStringFromHashTable(NSHashTable *table)
{
	id ret = [NSMutableString new];				// Get a String Representation
	struct _NSHashNode *node;
	NSUInteger i;

    for (i = 0; i < table->hashSize; i++)
		for (node = table->nodes[i]; node; node = node->next) 
			{
	    	[ret appendString:table->callbacks.describe(table, node->key)];
	    	[ret appendString:@" "];
			}
    
    return ret;
}

/* ****************************************************************************

	Map Table Functions

** ***************************************************************************/

NSMapTable *
NSCreateMapTable(NSMapTableKeyCallBacks keyCallbacks, 
				 NSMapTableValueCallBacks valueCallbacks, 
				 NSUInteger capacity)
{
	NSMapTable *t = malloc(sizeof(NSMapTable));
    
    capacity = capacity ? capacity : 13;
    if (!is_prime(capacity))
		capacity = nextPrime(capacity);

    t->hashSize = capacity;
    t->nodes = calloc(t->hashSize, sizeof(void*));
    t->itemsCount = 0;
    t->keyCallbacks = keyCallbacks;
    t->valueCallbacks = valueCallbacks;
    if (t->keyCallbacks.hash == NULL)
		t->keyCallbacks.hash = (NSUInteger(*)(NSMapTable*, const void*))_NSHashPointer;
    if (t->keyCallbacks.isEqual == NULL)
		t->keyCallbacks.isEqual = (BOOL(*)(NSMapTable*, const void*, const void*)) _NSComparePointers;
    if (t->keyCallbacks.retain == NULL)
		t->keyCallbacks.retain = (void(*)(NSMapTable*, const void*))_NSRetainNothing;
    if (t->keyCallbacks.release == NULL)
		t->keyCallbacks.release = (void(*)(NSMapTable*, void*))_NSReleaseNothing;
    if (t->keyCallbacks.describe == NULL)
		t->keyCallbacks.describe = (NSString*(*)(NSMapTable*, const void*))_NSDescribePointers;
    if (t->valueCallbacks.retain == NULL)
		t->valueCallbacks.retain = (void(*)(NSMapTable*, const void*))_NSRetainNothing;
    if (t->valueCallbacks.release == NULL)
		t->valueCallbacks.release = (void(*)(NSMapTable*, void*))_NSReleaseNothing;
    if (t->valueCallbacks.describe == NULL)
		t->valueCallbacks.describe = (NSString*(*)(NSMapTable*, const void*))_NSDescribePointers;

    return t;
}

NSMapTable *
NSCopyMapTable(NSMapTable *table)
{
	NSMapTable *new;
	struct _NSMapNode *oldnode, *newnode;
	NSUInteger i;

    new = malloc(sizeof(NSMapTable));
    new->hashSize = table->hashSize;
    new->itemsCount = table->itemsCount;
    new->keyCallbacks = table->keyCallbacks;
    new->valueCallbacks = table->valueCallbacks;
    new->nodes = calloc(new->hashSize, sizeof(void*));

    for (i = 0; i < new->hashSize; i++) 
		{
		for (oldnode = table->nodes[i]; oldnode; oldnode = oldnode->next) 
			{
			newnode = malloc(sizeof(struct _NSMapNode));
			newnode->key = oldnode->key;
			newnode->value = oldnode->value;
			newnode->next = new->nodes[i];
			new->nodes[i] = newnode;
			table->keyCallbacks.retain(new, oldnode->key);
			table->valueCallbacks.retain(new, oldnode->value);
		}	}

    return new;
}

void
NSFreeMapTable(NSMapTable *table)
{															// Free a Table
    NSResetMapTable(table);
    free(table->nodes);
    free(table);
}

void
NSResetMapTable(NSMapTable *table)
{
	NSUInteger i;

    for(i = 0; i < table->hashSize; i++)
		{
		struct _NSMapNode *next, *node;

		node = table->nodes[i];
		table->nodes[i] = NULL;
		while (node)
			{
			table->keyCallbacks.release(table, node->key);
			table->valueCallbacks.release(table, node->value);
			next = node->next;
			free(node);
			node = next;
		}	}

    table->itemsCount = 0;
}

BOOL 
NSCompareMapTables(NSMapTable *table1, NSMapTable *table2)
{
	NSUInteger i;										// Compare Two Tables
	struct _NSMapNode *node1;

    if (table1->hashSize != table2->hashSize)
		return NO;
    for (i = 0; i < table1->hashSize; i++) 
		for (node1 = table1->nodes[i]; node1; node1 = node1->next)
			if (NSMapGet(table2, node1->key) != node1->value)
				return NO;

    return YES;
}

NSUInteger 
NSCountMapTable(NSMapTable *table)			{ return table->itemsCount; }

BOOL 
NSMapMember(NSMapTable *table, const void *key,void **originalKey,void **value)
{
	struct _NSMapNode *node;

	node = table->nodes[table->keyCallbacks.hash(table,key) % table->hashSize];
    for(; node; node = node->next)
        if(table->keyCallbacks.isEqual(table, key, node->key)) 
			{
            *originalKey = node->key;
			*value = node->value;

			return YES;
			}

    return NO;
}

void *
NSMapGet(NSMapTable *table, const void *key)
{
	struct _NSMapNode *node;

	node = table->nodes[table->keyCallbacks.hash(table,key) % table->hashSize];
    for(; node; node = node->next)
        if(table->keyCallbacks.isEqual(table, key, node->key))
            return node->value;

    return NULL;
}

NSMapEnumerator 
NSEnumerateMapTable(NSMapTable *table)
{
    return (NSMapEnumerator){table, NULL, -1};
}

BOOL 
NSNextMapEnumeratorPair(NSMapEnumerator *en, void **key, void **value)
{
    if(en->node)
		en->node = en->node->next;
    if(en->node == NULL)
		{
		en->bucket++;
		for (; (NSUInteger)en->bucket < en->table->hashSize; en->bucket++)
			if (en->table->nodes[en->bucket])
				{
				en->node = en->table->nodes[en->bucket];
				break;
				};

		if ((NSUInteger)en->bucket >= en->table->hashSize)
			{
			en->node = NULL;
			en->bucket = en->table->hashSize - 1;

			return NO;
		}	}

    *key = en->node->key;
    *value = en->node->value;

    return YES;
}

NSArray *
NSAllMapTableKeys(NSMapTable *table)
{
	id array = [NSMutableArray arrayWithCapacity:table->itemsCount];
	struct _NSMapNode *node;
	NSUInteger i;

    for(i = 0; i < table->hashSize; i++)
		for(node = table->nodes[i]; node; node=node->next)
			[array addObject:(NSObject*)(node->key)];

    return array;
}

NSArray *
NSAllMapTableValues(NSMapTable *table)
{
	id array = [NSMutableArray arrayWithCapacity:table->itemsCount];
	struct _NSMapNode *node;
	NSUInteger i;

    for(i = 0; i < table->hashSize; i++)
		for(node = table->nodes[i]; node; node = node->next)
			[array addObject:(NSObject*)(node->value)];

    return array;
}

static void 
_NSMapGrow(NSMapTable *table, NSUInteger newSize)
{
	NSUInteger i;
	struct _NSMapNode **newNodeTable = calloc(newSize, sizeof(struct _NSMapNode*));
    
    for(i = 0; i < table->hashSize; i++) 
		{
		struct _NSMapNode *next, *node;
		NSUInteger h;

		node = table->nodes[i];
		while(node) 
			{
			next = node->next;
			h = table->keyCallbacks.hash(table, node->key) % newSize;
			node->next = newNodeTable[h];
			newNodeTable[h] = node;
			node = next;
		}	}

    free(table->nodes);
    table->nodes = newNodeTable;
    table->hashSize = newSize;
}

void 
NSMapInsert(NSMapTable *table, const void *key, const void *value)
{
	NSUInteger h;
	struct _NSMapNode *node;

	if (key == table->keyCallbacks.notAKeyMarker)
		[NSException raise: NSInvalidArgumentException
        			 format: @"Invalid key to be added in NSMapTable."];

    h = table->keyCallbacks.hash(table, key) % table->hashSize;
    for(node = table->nodes[h]; node; node = node->next)
        if(table->keyCallbacks.isEqual(table, key, node->key))
            break;
											// Check if an entry for key exists
    if(node) 								// in nodeTable.
		{									
		if (key != node->key) 				// key exists.  Set it's new value
			{								// and release the old value.
			table->keyCallbacks.retain(table, key);
			table->keyCallbacks.release(table, node->key);
			}
		if (value != node->value) 
			{
			table->valueCallbacks.retain(table, value);
			table->valueCallbacks.release(table, node->value);
			}
		node->key = (void*)key;
		node->value = (void*)value;

		return;
		}

    node = malloc(sizeof(struct _NSMapNode));	// key not found so allocate a
    table->keyCallbacks.retain(table, key);		// new bucket for the key
	table->valueCallbacks.retain(table, value);
    node->key = (void*)key;
    node->value = (void*)value;
    node->next = table->nodes[h];
    table->nodes[h] = node;

    _NSCheckMapTableFull(table);
}

void *
NSMapInsertIfAbsent(NSMapTable *table, const void *key,const void *value)
{
	NSUInteger h;
	struct _NSMapNode *node;

    if (key == table->keyCallbacks.notAKeyMarker)
		[NSException raise: NSInvalidArgumentException
        			 format: @"Invalid key to be added in NSMapTable."];

    h = table->keyCallbacks.hash(table, key) % table->hashSize;
    for(node = table->nodes[h]; node; node = node->next)
        if(table->keyCallbacks.isEqual(table, key, node->key))
            break;								// Check if key already exists
    if(node)									// in the nodeTable and return
        return node->key;						// it if it does.

    node = malloc(sizeof(struct _NSMapNode));	// key not found, alloc a new
    table->keyCallbacks.retain(table, key);		// bucket for the key
    table->valueCallbacks.retain(table, value);
    node->key = (void*)key;
    node->value = (void*)value;
    node->next = table->nodes[h];
    table->nodes[h] = node;

    _NSCheckMapTableFull(table);

    return NULL;
}

void 
NSMapInsertKnownAbsent(NSMapTable *table, const void *key, const void *value)
{
	NSUInteger h;
	struct _NSMapNode *node;

    if (key == table->keyCallbacks.notAKeyMarker)
		[NSException raise: NSInvalidArgumentException
        			 format: @"Invalid key to be added in NSMapTable."];

    h = table->keyCallbacks.hash(table, key) % table->hashSize;
    for(node = table->nodes[h]; node; node = node->next)
        if(table->keyCallbacks.isEqual(table, key, node->key))
            break;

    if(node) 				// Check if an entry for key exists in nodeTable
		[NSException raise: NSInvalidArgumentException
        			 format: @"Nil object already existing in NSMapTable."];

    node = malloc(sizeof(struct _NSMapNode));	// key not found, alloc a new
    table->keyCallbacks.retain(table, key);		// bucket for the key
    table->valueCallbacks.retain(table, value);
    node->key = (void*)key;
    node->value = (void*)value;
    node->next = table->nodes[h];
    table->nodes[h] = node;

    _NSCheckMapTableFull(table);
}

void 
NSMapRemove(NSMapTable *table, const void *key)
{
	NSUInteger h;
	struct _NSMapNode *node, *node1 = NULL;

    if (key == nil)
	    return;

    h = table->keyCallbacks.hash(table, key) % table->hashSize;

    			// node points to current bucket, and node1 to previous bucket 
				// or to NULL if current node is the first node in the list 
    for(node = table->nodes[h]; node; node1 = node, node = node->next)
        if(table->keyCallbacks.isEqual(table, key, node->key)) 
			{
	    	table->keyCallbacks.release(table, node->key);
	    	table->valueCallbacks.release(table, node->value);
            if(!node1)
                table->nodes[h] = node->next;
            else
                node1->next = node->next;
	    	free(node);
	    	(table->itemsCount)--;

	    	return;
        	}
}

NSString *
NSStringFromMapTable(NSMapTable *table)
{
	id ret = [NSMutableString new];
	struct _NSMapNode *node;
	NSUInteger i;

    for (i = 0; i < table->hashSize; i++)
	  for (node = table->nodes[i]; node; node = node->next) 
		{
	    [ret appendString:table->keyCallbacks.describe(table, node->key)];
	    [ret appendString:@"="];
	    [ret appendString:table->valueCallbacks.describe(table, node->value)];
	    [ret appendString:@"\n"];
		}

    return ret;
}

/* ****************************************************************************

	Convenience functions

** ***************************************************************************/

NSUInteger 
_NSHashObject(void *table, const void *anObject)
{
    return (NSUInteger)[(id)anObject hash];
}

NSUInteger 
_NSHashPointer(void *table, const void *anObject)
{
    return (NSUInteger)((long)anObject / 4);
}

NSUInteger 
_NSHashInteger(void *table, const void *anObject)
{
    return (NSUInteger)(long)anObject;
}

NSUInteger 
_NSHashCString(void *table, const void *aString)
{
	register const char *p = (char*)aString;
	register NSUInteger hash = 0, hash2;
	register int i, n = strlen((char*)aString);

    for(i = 0; i < n; i++) 
		{
        hash <<= 4;
        hash += *p++;
        if((hash2 = hash & 0xf0000000))
            hash ^= (hash2 >> 24) ^ hash2;
		}

    return hash;
}

BOOL 
_NSCompareObjects(void *table, const void *obj1, const void *obj2)
{
    return [(NSObject*)obj1 isEqual:(NSObject*)obj2];
}

BOOL 
_NSComparePointers(void *table, const void *obj1, const void *obj2)
{
    return obj1 == obj2;
}

BOOL 
_NSCompareInts(void *table, const void *obj1, const void *obj2)
{
    return obj1 == obj2;
}

BOOL 
_NSCompareCString(void *table, const void *obj1, const void *obj2)
{
    return strcmp((char*)obj1, (char*)obj2) == 0;
}

void 
_NSRetainObjects(void *table, const void *anObject)
{
    [(NSObject*)anObject retain];
}

void _NSRetainNothing(void *table, const void *anObject)	{}
void _NSReleaseNothing(void *table, void *anObject)			{}
void _NSReleasePointers(void *table, void *anObject)		{ free(anObject); }

void 
_NSReleaseObjects(void *table, void *anObject)
{
    [(NSObject*)anObject release];
}

NSString *
_NSDescribeObjects(void *table, const void *anObject)
{
    return [(NSObject*)anObject description];
}

NSString *
_NSDescribePointers(void *table, const void *anObject)
{
    return [NSString stringWithFormat:@"%p", anObject];
}

NSString *
_NSDescribeInts(void *table, const void *anObject)
{
    return [NSString stringWithFormat:@"%ld", (long)anObject];
}

											// NSHashTable predefined callbacks
const NSHashTableCallBacks NSIntHashCallBacks = { 
    (NSUInteger(*)(NSHashTable*, const void*))_NSHashInteger, 
    (BOOL(*)(NSHashTable*, const void*, const void*))_NSCompareInts, 
    (void(*)(NSHashTable*, const void*))_NSRetainNothing, 
    (void(*)(NSHashTable*, void*))_NSReleaseNothing, 
    (NSString*(*)(NSHashTable*, const void*))_NSDescribeInts 
};

const NSHashTableCallBacks NSNonOwnedPointerHashCallBacks = { 
    (NSUInteger(*)(NSHashTable*, const void*))_NSHashPointer, 
    (BOOL(*)(NSHashTable*, const void*, const void*))_NSComparePointers, 
    (void(*)(NSHashTable*, const void*))_NSRetainNothing, 
    (void(*)(NSHashTable*, void*))_NSReleaseNothing, 
    (NSString*(*)(NSHashTable*, const void*))_NSDescribePointers 
};

const NSHashTableCallBacks NSNonRetainedObjectHashCallBacks = { 
    (NSUInteger(*)(NSHashTable*, const void*))_NSHashObject, 
    (BOOL(*)(NSHashTable*, const void*, const void*))_NSCompareObjects, 
    (void(*)(NSHashTable*, const void*))_NSRetainNothing, 
    (void(*)(NSHashTable*, void*))_NSReleaseNothing, 
    (NSString*(*)(NSHashTable*, const void*))_NSDescribeObjects 
};
 
const NSHashTableCallBacks NSObjectHashCallBacks = { 
    (NSUInteger(*)(NSHashTable*, const void*))_NSHashObject, 
    (BOOL(*)(NSHashTable*, const void*, const void*))_NSCompareObjects, 
    (void(*)(NSHashTable*, const void*))_NSRetainObjects, 
    (void(*)(NSHashTable*, void*))_NSReleaseObjects, 
    (NSString*(*)(NSHashTable*, const void*))_NSDescribeObjects 
};

const NSHashTableCallBacks NSOwnedObjectIdentityHashCallBacks = { 
    (NSUInteger(*)(NSHashTable*, const void*))_NSHashPointer, 
    (BOOL(*)(NSHashTable*, const void*, const void*))_NSComparePointers, 
    (void(*)(NSHashTable*, const void*))_NSRetainObjects, 
    (void(*)(NSHashTable*, void*))_NSReleaseObjects, 
    (NSString*(*)(NSHashTable*, const void*))_NSDescribeObjects 
};

const NSHashTableCallBacks NSOwnedPointerHashCallBacks = { 
    (NSUInteger(*)(NSHashTable*, const void*))_NSHashObject, 
    (BOOL(*)(NSHashTable*, const void*, const void*))_NSCompareObjects, 
    (void(*)(NSHashTable*, const void*))_NSRetainNothing, 
    (void(*)(NSHashTable*, void*))_NSReleasePointers, 
    (NSString*(*)(NSHashTable*, const void*))_NSDescribePointers 
};

const NSHashTableCallBacks NSPointerToStructHashCallBacks = { 
    (NSUInteger(*)(NSHashTable*, const void*))_NSHashPointer, 
    (BOOL(*)(NSHashTable*, const void*, const void*))_NSComparePointers, 
    (void(*)(NSHashTable*, const void*))_NSRetainNothing, 
    (void(*)(NSHashTable*, void*))_NSReleasePointers, 
    (NSString*(*)(NSHashTable*, const void*))_NSDescribePointers 
};
											// NSMapTable predefined callbacks 
const NSMapTableKeyCallBacks NSIntMapKeyCallBacks = {
    (NSUInteger(*)(NSMapTable *, const void *))_NSHashInteger,
    (BOOL(*)(NSMapTable *, const void *, const void *))_NSCompareInts,
    (void (*)(NSMapTable *, const void *anObject))_NSRetainNothing,
    (void (*)(NSMapTable *, void *anObject))_NSReleaseNothing,
    (NSString *(*)(NSMapTable *, const void *))_NSDescribeInts,
    (const void *)NULL
};

const NSMapTableValueCallBacks NSIntMapValueCallBacks = {
    (void (*)(NSMapTable *, const void *))_NSRetainNothing,
    (void (*)(NSMapTable *, void *))_NSReleaseNothing,
    (NSString *(*)(NSMapTable *, const void *))_NSDescribeInts
};

const NSMapTableKeyCallBacks NSNonOwnedPointerMapKeyCallBacks = {
    (NSUInteger(*)(NSMapTable *, const void *))_NSHashPointer,
    (BOOL(*)(NSMapTable *, const void *, const void *))_NSComparePointers,
    (void (*)(NSMapTable *, const void *anObject))_NSRetainNothing,
    (void (*)(NSMapTable *, void *anObject))_NSReleaseNothing,
    (NSString *(*)(NSMapTable *, const void *))_NSDescribePointers,
    (const void *)NULL
}; 

const NSMapTableKeyCallBacks NSNonOwnedCStringMapKeyCallBacks = {
    (NSUInteger(*)(NSMapTable *, const void *))_NSHashCString,
    (BOOL(*)(NSMapTable *, const void *, const void *))_NSCompareCString,
    (void (*)(NSMapTable *, const void *anObject))_NSRetainNothing,
    (void (*)(NSMapTable *, void *anObject))_NSReleaseNothing,
    (NSString *(*)(NSMapTable *, const void *))_NSDescribePointers,
    (const void *)NULL
}; 

const NSMapTableKeyCallBacks NSOwnedPointerMapKeyCallBacks = {
    (NSUInteger(*)(NSMapTable *, const void *))_NSHashPointer,
    (BOOL(*)(NSMapTable *, const void *, const void *))_NSComparePointers,
    (void (*)(NSMapTable *, const void *anObject))_NSRetainNothing,
    (void (*)(NSMapTable *, void *anObject))_NSReleasePointers,
    (NSString *(*)(NSMapTable *, const void *))_NSDescribePointers,
    (const void *)NULL
};

const NSMapTableValueCallBacks NSNonOwnedPointerMapValueCallBacks = {
    (void (*)(NSMapTable *, const void *))_NSRetainNothing,
    (void (*)(NSMapTable *, void *))_NSReleaseNothing,
    (NSString *(*)(NSMapTable *, const void *))_NSDescribePointers
};

const NSMapTableKeyCallBacks NSNonOwnedPointerOrNullMapKeyCallBacks = {
    (NSUInteger(*)(NSMapTable *, const void *))_NSHashPointer,
    (BOOL(*)(NSMapTable *, const void *, const void *))_NSComparePointers,
    (void (*)(NSMapTable *, const void *anObject))_NSRetainNothing,
    (void (*)(NSMapTable *, void *anObject))_NSReleaseNothing,
    (NSString *(*)(NSMapTable *, const void *))_NSDescribePointers,
    (const void *)NSNotAPointerMapKey
};

const NSMapTableKeyCallBacks NSNonRetainedObjectMapKeyCallBacks = {
    (NSUInteger(*)(NSMapTable *, const void *))_NSHashObject,
    (BOOL(*)(NSMapTable *, const void *, const void *))_NSCompareObjects,
    (void (*)(NSMapTable *, const void *anObject))_NSRetainNothing,
    (void (*)(NSMapTable *, void *anObject))_NSReleaseNothing,
    (NSString *(*)(NSMapTable *, const void *))_NSDescribeObjects,
    (const void *)NULL
};

const NSMapTableValueCallBacks NSNonRetainedObjectMapValueCallBacks = {
    (void (*)(NSMapTable *, const void *))_NSRetainNothing,
    (void (*)(NSMapTable *, void *))_NSReleaseNothing,
    (NSString *(*)(NSMapTable *, const void *))_NSDescribeObjects
}; 

const NSMapTableKeyCallBacks NSObjectMapKeyCallBacks = {
    (NSUInteger(*)(NSMapTable *, const void *))_NSHashObject,
    (BOOL(*)(NSMapTable *, const void *, const void *))_NSCompareObjects,
    (void (*)(NSMapTable *, const void *anObject))_NSRetainObjects,
    (void (*)(NSMapTable *, void *anObject))_NSReleaseObjects,
    (NSString *(*)(NSMapTable *, const void *))_NSDescribeObjects,
    (const void *)NULL
}; 

const NSMapTableValueCallBacks NSObjectMapValueCallBacks = {
    (void (*)(NSMapTable *, const void *))_NSRetainObjects,
    (void (*)(NSMapTable *, void *))_NSReleaseObjects,
    (NSString *(*)(NSMapTable *, const void *))_NSDescribeObjects
}; 

const NSMapTableValueCallBacks NSOwnedPointerMapValueCallBacks = {
    (void (*)(NSMapTable *, const void *))_NSRetainNothing,
    (void (*)(NSMapTable *, void *))_NSReleasePointers,
    (NSString *(*)(NSMapTable *, const void *))_NSDescribePointers
}; 
