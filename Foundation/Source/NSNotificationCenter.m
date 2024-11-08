/*
   NSNotificationCenter.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>

   This file is part of the mGSTEP Library and is provided under the 
   terms of the libFoundation BSD type license (See the Readme file).
*/

#include <Foundation/NSNotification.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSHashTable.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSException.h>
#include <Foundation/NSEnumerator.h>

#define MAP_CAPACITY  1031				// save some time, choose a prime

// Class variables	
static NSNotificationCenter *__defaultCenter = nil;


@interface _NoteObserver : NSObject
{
@public
    id observer;						// observer that will receive selector
    SEL selector;						// in a postNotification:
}

- (NSUInteger) hash;
- (BOOL) isEqual:other;
- (void) postNotification:(NSNotification*)notification;

@end

@implementation _NoteObserver

- (BOOL) isEqual:(id)other
{
    if (![other isKindOfClass:[_NoteObserver class]])
    	return NO;

	return (observer == ((_NoteObserver *)other)->observer) 
			&& SEL_EQ(selector, ((_NoteObserver *)other)->selector);
}

- (NSUInteger) hash
{
	return ((long)observer >> 4) + _NSHashCString(NULL,sel_get_name(selector));
}

- (void) postNotification:(NSNotification*)notification
{
    [observer performSelector:selector withObject:notification];
}

@end /* _NoteObserver */


@interface _NoteObjectObservers : NSObject				// Register for objects
{														// to observer mapping
    NSHashTable *observerItems;
}

- (id) init;
- (NSUInteger) count;
- (void) addObjectsToList:(NSMutableArray*)list;
- (void) addObserver:(id)observer selector:(SEL)selector;
- (void) removeObserver:(id)observer;

@end

@implementation _NoteObjectObservers

- (id) init
{
    observerItems = NSCreateHashTable(NSObjectHashCallBacks, MAP_CAPACITY);

    return self;
}

- (void) dealloc
{
    NSFreeHashTable(observerItems);
    [super dealloc];
}

- (NSUInteger) count				{ return NSCountHashTable(observerItems); }

- (void) addObjectsToList:(NSMutableArray*)list
{
	NSHashEnumerator items = NSEnumerateHashTable(observerItems);
	id reg;

    while((reg = (id)NSNextHashEnumeratorItem(&items)))
		[list addObject:reg];
}

- (void) addObserver:(id)observer selector:(SEL)selector
{
	_NoteObserver *reg = [[_NoteObserver alloc] autorelease];

	reg->observer = observer;
	reg->selector = selector;
    NSHashInsertIfAbsent(observerItems, (void *)reg);
}

- (void) removeObserver:(id)observer
{
	_NoteObserver *reg;
	int i, count = NSCountHashTable(observerItems);
	NSMutableArray *list = [[NSMutableArray alloc] initWithCapacity:count];
	NSHashEnumerator itemsEnum = NSEnumerateHashTable(observerItems);
	
	[list autorelease];

    while((reg = (id)NSNextHashEnumeratorItem(&itemsEnum)))
		if (reg->observer == observer)
			[list addObject:reg];
    
    for (i = [list count]-1; i >= 0; i--)
		NSHashRemove(observerItems, (void *)[list objectAtIndex:i]);
}

@end /* _NoteObjectObservers */


@interface _NoteDictionary : NSObject					// Register for objects 
{														// to observer mapping
    NSMapTable *objectObservers;
    _NoteObjectObservers *nilObjectObservers;
}

- (id) init;
- (id) listToNotifyForObject:object;
- (void) addObserver:(id)observer selector:(SEL)selector object:(id)object;
- (void) removeObserver:(id)observer object:(id)object;
- (void) removeObserver:(id)observer;

@end

@implementation _NoteDictionary

- (id) init
{
    objectObservers = NSCreateMapTable( NSNonOwnedPointerMapKeyCallBacks,
										NSObjectMapValueCallBacks, MAP_CAPACITY);
    nilObjectObservers = [_NoteObjectObservers new];

    return self;
}

- (void) dealloc
{
    NSFreeMapTable(objectObservers);
    [nilObjectObservers release];
    [super dealloc];
}

- (id) listToNotifyForObject:(id)object
{
	id reg = nil;
	int count;
	id list;
    
    if (object)
		reg = NSMapGet(objectObservers, object);
    count = [reg count] + [nilObjectObservers count];
    list = [[[NSMutableArray alloc] initWithCapacity:count] autorelease];
    [reg addObjectsToList:list];
    [nilObjectObservers addObjectsToList:list];
    
    return list;
}

- (void) addObserver:(id)observer selector:(SEL)selector object:(id)object
{
	_NoteObjectObservers *reg;
    
    if (object) 
		{
		if (!(reg = (id)NSMapGet(objectObservers, object)))
			{
			reg = [[_NoteObjectObservers new] autorelease];
			NSMapInsert(objectObservers, object, reg);
		}	}
    else
		reg = nilObjectObservers;
    
    [reg addObserver:observer selector:selector];
}

- (void) removeObserver:(id)observer object:(id)object
{
	_NoteObjectObservers *reg;

	reg = (object) ? NSMapGet(objectObservers, object) : nilObjectObservers;
    [reg removeObserver:observer];
}

- (void) removeObserver:(id)observer
{
	id obj, reg;
	NSMapEnumerator regEnum = NSEnumerateMapTable(objectObservers);

    while (NSNextMapEnumeratorPair(&regEnum, (void*)&obj, (void*)&reg))
		[reg removeObserver:observer];

    [nilObjectObservers removeObserver:observer];
}

@end /* _NoteDictionary */

/* ****************************************************************************

	NSNotificationCenter

** ***************************************************************************/

@implementation NSNotificationCenter 

+ (void) initialize
{
    if (__defaultCenter == nil) 
		__defaultCenter = [[self alloc] init];
}

+ (NSNotificationCenter*) defaultCenter			{ return __defaultCenter; }

- (id) init
{
    _noteForObject = [NSMutableDictionary new];

    return self;
}

- (void) dealloc
{
    [_noteForObject release];
    [super dealloc];
}

- (void) addObserver:(id)observer
			selector:(SEL)selector 
			name:(NSString*)notificationName 
			object:(id)object
{
	_NoteDictionary *d;
    
    if (notificationName == nil)
		notificationName = @"AnyNameNotificationKey";

	if (!(d = [_noteForObject objectForKey:notificationName]))
		{
		d = [[_NoteDictionary new] autorelease];
		[_noteForObject setObject:d forKey:notificationName];
		}

    [d addObserver:observer selector:selector object:object];
}

- (void) removeObserver:(id)observer name:(NSString*)ns object:(id)ob
{
    if (ns != nil)
    	[[_noteForObject objectForKey:ns] removeObserver:observer object:ob];
	else if (observer != nil)			// no name provided so iterate thru
		{								// all registered note names
		id enumerator = [_noteForObject keyEnumerator];

		while ((ns = [enumerator nextObject]))
			[[_noteForObject objectForKey:ns] removeObserver:observer object:ob];
		}
}

- (void) removeObserver:(id)observer
{
	id enumerator = [_noteForObject keyEnumerator];
	NSString *ns;

	DBLog(@"removeObserver %@", [observer description]);

	while ((ns = [enumerator nextObject]))
		[[_noteForObject objectForKey:ns] removeObserver:observer];
}

- (void) postNotificationName:(NSString*)n object:(id)object
{
	[self postNotificationName:n object:object userInfo:nil];
}

- (void) postNotificationName:(NSString*)notificationName 
					   object:(id)object
					   userInfo:(NSDictionary*)userInfo;
{
	id notice = [[NSNotification alloc] initWithName:notificationName
										object:object
										userInfo:userInfo];
    [self postNotification: notice];
    [notice release];
}

- (void) postNotification:(NSNotification*)n		// post notification to all
{													// registered observers
	NSArray *na;
	_NoteDictionary *d = [_noteForObject objectForKey:[n name]];
	id object = [n object];

    if (!d && ([n name] == nil))
		[NSException raise:NSInvalidArgumentException
					 format:@"NSNotification: notification name is nil"];

    na = [d listToNotifyForObject:object];			// get list of registered
    [na makeObjectsPerformSelector:@selector(postNotification:) withObject:n];
}

@end /* NSNotificationCenter */


@implementation NSNotificationCenter (NotInOSX)

+ (void) post:(NSString*)ns object:(id)object
{
	[__defaultCenter postNotificationName:ns object:object userInfo:nil];
}

@end /* NSNotificationCenter (Not_OSX) */
