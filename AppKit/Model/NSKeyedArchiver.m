/*
   NSKeyedArchiver.m

   Copyright (C) 1998-2016 Free Software Foundation, Inc.

   Author:	Ovidiu Predescu <ovidiu@net-community.com>
   Date:	October 1997

   Complete rewrite based on GMArchiver code:
   Dr. H. Nikolaus Schaller <hns@computer.org>
   Date: Jan 2006

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>
#include <Foundation/NSKeyedArchiver.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSData.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSScanner.h>
#include <Foundation/NSException.h>
#include "Foundation/NSPropertyList.h"
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSXMLParser.h>
#include <Foundation/NSNull.h>

#include "./IMCustomObject.h"


// Class variables
static NSMutableDictionary *__classToAliasMappings = nil;



@interface NSObject  (KeyedArchivingMethods)
- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder;
@end  /* NSObject (KeyedArchivingMethods) */


@interface GMClassInfo : NSObject
{
	NSString *className;
	int version;
}

+ (id) classInfoWithClassName:(NSString*)className version:(int)version;

- (NSString*) className;

@end


@implementation GMClassInfo

+ (id) classInfoWithClassName:(NSString*)name version:(int)_version
{
	GMClassInfo *object = [[self new] autorelease];

	object->className = [name retain];
	object->version = _version;
	
	return object;
}

- (NSString*) className					{ return className; }

@end


@implementation NSKeyedArchiver

+ (BOOL) archiveRootObject:(id)rootObject toFile:(NSString*)path
{
	NSKeyedArchiver *archiver = [[self new] autorelease];

	[archiver encodeRootObject:rootObject withName:@"RootObject"];

	return [archiver writeToFile:path];
}

- (id) init
{
	propertyList = [NSMutableDictionary new];
	topLevelObjects = [NSMutableArray new];
	[propertyList setObject:topLevelObjects forKey:@"TopLevelObjects"];
	lastObjectRepresentation = propertyList;
	
	objects = NSCreateMapTable (NSNonRetainedObjectMapKeyCallBacks,
								NSObjectMapValueCallBacks, 119);
	conditionals = NSCreateHashTable (NSNonRetainedObjectHashCallBacks, 19);
	classes = NSCreateMapTable (NSObjectMapKeyCallBacks,
								NSObjectMapValueCallBacks, 19);
	[propertyList setObject:@"1" forKey:@"Version"];
	
	return self;
}

- (void) dealloc
{
	[propertyList release];
	[topLevelObjects release];
	NSFreeMapTable(objects);
	NSFreeHashTable(conditionals);
	NSFreeMapTable(classes);
	
	[super dealloc];
}

- (NSString*) newLabel
{
	return [NSString stringWithFormat:@"Object%5d", ++counter];
}

- (BOOL) writeToFile:(NSString*)path
{
	return [propertyList writeToFile:path atomically:YES];
}

- (id) encodeRootObject:(id)rootObject withName:(NSString*)name
{
	id originalPList = propertyList;
	int oldCounter = counter;
	id label;

	if (writingRoot)
		[NSException raise: NSInvalidArgumentException
        			 format: @"Coder has already written root object."];

	writingRoot = YES;

/*
	Prepare for writing the graph objects for which `rootObject' is the root
	node. The algorithm consists of two passes. In the first pass it
	determines the nodes so-called 'conditionals' - the nodes encoded *only*
	with -encodeConditionalObject:. They represent nodes that are not
	related directly to the graph. In the second pass objects are encoded
	normally, except for the conditional objects which are encoded as nil.
*/

	findingConditionals = YES;								// First pass.
	lastObjectRepresentation = propertyList = nil;
	NSResetHashTable(conditionals);
	NSResetMapTable(objects);
	[self encodeObject:rootObject withName:name];

	findingConditionals = NO;								// Second pass.
	counter = oldCounter;
	lastObjectRepresentation = propertyList = originalPList;
	NSResetMapTable(objects);
	label = [self encodeObject:rootObject withName:name];
	
	writingRoot = NO;
	
	return label;
}

- (id) encodeConditionalObject:(id)anObject withName:(NSString*)name
{
	if (findingConditionals) 
		{			// This is the first pass in determining the conditionals
     	id value;	// algorithm. We traverse the graph and insert into the
					// `conditionals' set. In the second pass all objects that 
					// are still in this set will be encoded as nil when they 
					// receive -encodeConditionalObject:. An object is removed 
					// from this set when it receives -encodeObject:.
		if (!anObject)
			return nil;
					// Lookup anObject into the `conditionals' set. If it is 
					// then the object is still a conditional object.
		if ((value = (id)NSHashGet(conditionals, anObject)))
			return value;
										// Maybe it has received -encodeObject:
										// and now is in the `objects' set.
		if ((value = (id)NSMapGet(objects, anObject)))
			return value;
										// anObject was not written previously.
		NSHashInsert(conditionals, anObject);
		}
	else								// If anObject is in the `conditionals'
		{								// set, it is encoded as nil.
		if (!anObject || NSHashGet(conditionals, anObject))
			return [self encodeObject:nil withName:name];

		return [self encodeObject:anObject withName:name];
		}

	return nil;
}

- (id) encodeObject:(id)anObject withName:(NSString*)name
{
	id upperObjectRepresentation;
	id label;

	if (!anObject) 
		{
		if (!findingConditionals && name)
			[lastObjectRepresentation setObject:@"nil" forKey:name];

		return @"nil";
		}

	label = NSMapGet(objects, anObject);
	if (findingConditionals && !label) 
		{				// Look-up the object in the `conditionals' set. 
						// If the object is there, then remove it because 
						// it is no longer a conditional one.
		if ((label = NSHashGet(conditionals, anObject))) 
			{
			NSHashRemove(conditionals, anObject);
			NSMapInsert(objects, anObject, [self newLabel]);

			return label;
		}	}

    if (!label)
		{
		Class archiveClass;

		if (!level)						// If object gets encoded on the top
			{							// level, set the label to be `name'
			if (!name)
				{
				NSLog (@"Can't encode top level object with a nil name!");
				return nil;
				}
			label = name;
			}
		else
			label = [self newLabel];

		NSMapInsert(objects, anObject, label);
						// Temp save last object into upperObjectRepresentation 
						// so we can restore the stack of objects being encoded 
						// after anObject is encoded.
		upperObjectRepresentation = lastObjectRepresentation;

		anObject = [anObject replacementObjectForModelArchiver:self];
		archiveClass = [anObject classForModelArchiver];

		if (!findingConditionals)
			{
			NSMutableDictionary *objectPList =[NSMutableDictionary dictionary];

							// If anObject is the first object in graph that
							// receives the -encodeObject:withName: message, 
			if (!level)		// save its label into the topLevelObjects array.
				[topLevelObjects addObject:(name ? name : label)];

			lastObjectRepresentation = objectPList;

			if (level)		// Encode 'name = label' in object's representation
				{			// and put the description of anObject on the top 
							// level like 'label = object'.
				if (name)
					[upperObjectRepresentation setObject:label forKey:name];
				[propertyList setObject:objectPList forKey:label];
				}
			else			// encoded object is on the top level so encode it
				{			// and put it under the key 'name'.
				if (name)
					label = name;
				[propertyList setObject:objectPList forKey:label];
				}

			[objectPList setObject:NSStringFromClass(archiveClass) 
						 forKey:@"isa"];
			}									// First pass in determining
		else									// conditional objs algorithm.
			NSHashRemove(conditionals,anObject);// Remove anObject from 
												// `conditionals' set if it is 
												// there and insert it into the 
		level++;								//`objects' set.
		[anObject encodeWithModelArchiver:self];
		level--;

		lastObjectRepresentation = upperObjectRepresentation;
		}
	else
		if (!findingConditionals && (name))
			[lastObjectRepresentation setObject:label forKey:name];

	return label;
}

- (id) encodeString:(NSString*)anObject withName:(NSString*)name
{
	if (!findingConditionals)
		{
		if (!anObject)
			{
			if (name)
				[lastObjectRepresentation setObject:@"nil" forKey:name];
			}
		else
			{
			if (name)
				[lastObjectRepresentation setObject:anObject forKey:name];

			return anObject;
		}	}

	return @"nil";
}

- (id) encodeData:(NSData*)anObject withName:(NSString*)name
{
	if (!findingConditionals)
		{
		if (!anObject)
			{
			if (name)
				[lastObjectRepresentation setObject:@"nil" forKey:name];
			}
		else
			{
			if (name)
				[lastObjectRepresentation setObject:anObject forKey:name];

			return anObject;
		}	}

	return @"nil";
}

- (id) encodeArray:(NSArray*)array withName:(NSString*)name
{
	if (array) 
		{
		int i, count = [array count];
		NSMutableArray *description = [NSMutableArray arrayWithCapacity:count];

		for (i = 0; i < count; i++) 
			{
			id object = [array objectAtIndex:i];
			[description addObject:[self encodeObject:object withName:nil]];
			}

		if (name)
			[lastObjectRepresentation setObject:description forKey:name];

		return description;
		}

	if (name)
		[lastObjectRepresentation setObject:@"nil" forKey:name];

	return @"nil";
}

- (id) encodeDictionary:(NSDictionary*)dictionary withName:(NSString*)name
{
	if (dictionary)
		{
		NSMutableDictionary *description = [NSMutableDictionary 
								dictionaryWithCapacity:[dictionary count]];
		id key, enumerator = [dictionary keyEnumerator];

		while ((key = [enumerator nextObject]))
			{
			id value = [dictionary objectForKey:key];
			id keyDesc = [self encodeObject:key withName:nil];
			id valueDesc = [self encodeObject:value withName:nil];

			[description setObject:valueDesc forKey:keyDesc];
			}

		if (name)
			[lastObjectRepresentation setObject:description forKey:name];

		return description;
		}

	if (name)
		[lastObjectRepresentation setObject:@"nil" forKey:name];

	return @"nil";
}

- (id) propertyList
{
	return propertyList;
}

- (id) encodeClass:(Class)class withName:(NSString*)name
{
	if (class)
		return [self encodeString:NSStringFromClass(class) withName:name];

	return [self encodeString:nil withName:name];
}

- (id) encodeSelector:(SEL)selector withName:(NSString*)name
{
	if (selector)
	   return [self encodeString:NSStringFromSelector(selector) withName:name];

	return [self encodeString:nil withName:name];
}

- (void) encodeChar:(char)value withName:(NSString*)name
{
	if (!findingConditionals && name)
		{
		id valueString = [NSString stringWithFormat:@"%c", value];

		[lastObjectRepresentation setObject:valueString forKey:name];
		}
}

- (void) encodeUnsignedChar:(unsigned char)value withName:(NSString*)name
{
	if (!findingConditionals && name)
		{
		id valueString = [NSString stringWithFormat:@"%uc", value];

		[lastObjectRepresentation setObject:valueString forKey:name];
		}
}

- (void) encodeBOOL:(BOOL)value withName:(NSString*)name
{
	if (!findingConditionals && name)
		[lastObjectRepresentation setObject:(value ? @"YES": @"NO") 
								  forKey:name];
}

- (void) encodeShort:(short)value withName:(NSString*)name
{
	if (!findingConditionals && name)
		{
		id valueString = [NSString stringWithFormat:@"%s", value];

		[lastObjectRepresentation setObject:valueString forKey:name];
		}
}

- (void) encodeUnsignedShort:(unsigned short)value withName:(NSString*)name
{
	if (!findingConditionals && name)
		{
		id valueString = [NSString stringWithFormat:@"%us", value];

		[lastObjectRepresentation setObject:valueString forKey:name];
		}
}

- (void) encodeInt:(int)value withName:(NSString*)name
{
	if (!findingConditionals && name)
		{
		id valueString = [NSString stringWithFormat:@"%i", value];

		[lastObjectRepresentation setObject:valueString forKey:name];
		}
}

- (void) encodeUnsignedInt:(unsigned int)value withName:(NSString*)name
{
	if (!findingConditionals && name)
		{
		id valueString = [NSString stringWithFormat:@"%u", value];

		[lastObjectRepresentation setObject:valueString forKey:name];
		}
}

- (void) encodeLong:(long)value withName:(NSString*)name
{
	if (!findingConditionals && name)
		{
		id valueString = [NSString stringWithFormat:@"%l", value];

		[lastObjectRepresentation setObject:valueString forKey:name];
		}
}

- (void) encodeUnsignedLong:(unsigned long)value withName:(NSString*)name
{
	if (!findingConditionals && name)
		{
		id valueString = [NSString stringWithFormat:@"%lu", value];

		[lastObjectRepresentation setObject:valueString forKey:name];
		}
}

- (void) encodeFloat:(float)value withName:(NSString*)name
{
	if (!findingConditionals && name)
		{
		id valueString = [NSString stringWithFormat:@"%f", value];

		[lastObjectRepresentation setObject:valueString forKey:name];
		}
}

- (void) encodeDouble:(double)value withName:(NSString*)name
{
	if (!findingConditionals && name)
		{
		id valueString = [NSString stringWithFormat:@"%f", value];

		[lastObjectRepresentation setObject:valueString forKey:name];
		}
}

- (void) encodePoint:(NSPoint)point withName:(NSString*)name
{
	if (!findingConditionals && name)
	 [lastObjectRepresentation setObject:NSStringFromPoint(point) forKey:name];
}

- (void) encodeSize:(NSSize)size withName:(NSString*)name
{
	if (!findingConditionals)
	   [lastObjectRepresentation setObject:NSStringFromSize(size) forKey:name];
}

- (void) encodeRect:(NSRect)rect withName:(NSString*)name
{
	if (!findingConditionals) 
	   [lastObjectRepresentation setObject:NSStringFromRect(rect) forKey:name];
}

- (NSString*) classNameEncodedForTrueClassName:(NSString*)trueName
{
id archiveName = [(id)NSMapGet(classes, trueName) className];

	return archiveName ? archiveName : trueName;
}
			// In the following method the version of class named trueName is 
			// written as version for class named archiveName. Is this right? 
			// It is possible for the archiveName class that it could not be 
			// linked in the running process at the time the archive is written
- (void) encodeClassName:(NSString*)trueName
		   intoClassName:(NSString*)archiveName
{
id classInfo = [GMClassInfo classInfoWithClassName:archiveName
							version:[NSClassFromString(trueName) version]];

	NSMapInsert(classes, trueName, classInfo);
}

@end /* NSKeyedArchiver */


@interface NSObject  (FilesOwner)
- (id) _owner;
@end


@implementation NSKeyedUnarchiver

+ (void) initialize
{
	__classToAliasMappings = [NSMutableDictionary new] ;
}

+ (Class) classForClassName:(NSString *)codedName;
{
	return [__classToAliasMappings objectForKey:codedName];
}

+ (void) setClass:(Class)cls forClassName:(NSString *)codedName;
{
	if(cls)
		[__classToAliasMappings setObject:cls forKey:codedName];
	else
		[__classToAliasMappings removeObjectForKey:codedName];
}

+ (id) unarchiveObjectWithFile:(NSString *)path
{
	NSData *d = [NSData dataWithContentsOfFile: path];

	return (d) ? [[[self alloc] initForReadingWithData: d] autorelease] : nil;
}

+ (id) unarchiveObjectWithData:(NSData *)d
{
	return (d) ? [[[self alloc] initForReadingWithData: d] autorelease] : nil;
}

- (id) initForReadingWithData:(NSData *)data
{
	NSError *err;	// ignored
	NSPropertyListFormat fmt;
	NSAutoreleasePool *arp;
	id plist;
#if 0
	NSLog(@"NSKeyedUnarchiver initForReadingWithData %p[%d]", data, [data length]);
#endif
	if(!data)
		return nil; // can't open
	fmt=NSPropertyListBinaryFormat_v1_0;
	// NOTE: from stack traces we know that Apple's Foundation is directly decoding from a binary PLIST through _decodeObject and _decodeObjectBinary methods
	arp=[NSAutoreleasePool new];
	plist=[NSPropertyListSerialization propertyListWithData:data
									   options:NSPropertyListMutableContainers
									   format:&fmt
									   error:&err];
	[plist retain];	// save
#if 0
	NSLog(@"NSKeyedUnarchiver plist decoded");
#endif
	[arp release];	// throw away all no longer needed temporaries


//	return [self _initForReadingWithPropertyList:[plist autorelease]];
	if((self=[super init]))
		{
		if(!plist || ![[plist objectForKey:@"$archiver"] isEqualToString:@"NSKeyedArchiver"]
				  || [[plist objectForKey:@"$version"] intValue] < 100000)
			{
#if 0
			// FIXME: should we raise exception?
			NSLog(@"can't unarchive keyed plist %@", plist);
			NSLog(@"$archiver %@", [plist objectForKey:@"$archiver"]);
			NSLog(@"$version %@", [plist objectForKey:@"$version"]);
#endif
			[self release];
			return nil;
			}
		_objects=[[plist objectForKey:@"$objects"] retain];				// array with all objects (or references)
		_objectRepresentation=[[plist objectForKey:@"$top"] retain];	// prepare to read out $top object
#if 0
		NSLog(@"$archiver %@", [plist objectForKey:@"$archiver"]);
		NSLog(@"$version %@", [plist objectForKey:@"$version"]);
		NSLog(@"$version %@", [plist objectForKey:@"$top"]);
#endif
		}

	return self;
}

- (NSString *) description;
{
	return [NSString stringWithFormat:@"%@ currentObject=%@",
					NSStringFromClass([self class]), _objectRepresentation];
}

- (void) dealloc;
{
	[_objectRepresentation release];
	[_objects release];
///	[__classToAliasMappings release];
	// release local ARP
	[super dealloc];
}

- (BOOL) containsValueForKey:(NSString *)key
{
	return [_objectRepresentation objectForKey:key] != nil;	// if defined
}

- (BOOL) allowsKeyedCoding				{ return YES; }
- (id) delegate							{ return _delegate; }
- (void) setDelegate:(id) delegate		{ _delegate=delegate; }

- (Class) classForClassName:(NSString *)codedName
{
	return [__classToAliasMappings objectForKey:codedName];
}

- (void) setClass:(Class)cls forClassName:(NSString *)codedName
{
	if(cls)
		{
		if(!__classToAliasMappings)
			__classToAliasMappings = [NSMutableDictionary new];
		[__classToAliasMappings setObject:cls forKey:codedName];
		}
	else
		[__classToAliasMappings removeObjectForKey:codedName];
}

/* excerpt of the $objects array

<string>System</string>
<string>controlColor</string>
<dict>
	<key>$class</key>
	<dict>	<- if decodeObjectForKey is a NSDict which itself has a CF$UID key
		<key>CF$UID</key>
		<integer>98</integer>
	</dict>
	<key>NSColorSpace</key>
		<integer>3</integer>	<- decodeObjectForKey is a plain object
	<key>NSWhite</key>
		<data>
MC42NjY2NjY2OQA=
		</data>
</dict>
<dict>
	<key>$classes</key>
		<array>
		<string>NSMatrix</string>
		<string>%NSMatrix</string>
		<string>NSControl</string>
		<string>NSView</string>
		<string>NSResponder</string>
		<string>NSObject</string>
		</array>
	<key>$classname</key>
		<string>NSMatrix</string>
</dict>
etc.
*/

- (id) _dereference:(unsigned int) idx
{ // handle indirect references through NSCFType/CF$UID - cache so that each object is instantiated only once
//	NSAutoreleasePool *arp;
	id obj, newObj;
	NSDictionary *savedRepresentation;
#if KEY_CHECK
	NSMutableArray *savedProcessedKeys;
#endif
	NSDictionary *classRecord;
	NSString *className;
	Class class;
	newObj=[_objects objectAtIndex:idx];	// get real object by number
	if([newObj isEqual:@"$null"])
		return nil;
#if 0
	NSLog(@"dereference objects[%u]=%@", idx, newObj);
#endif
	if(!([newObj isKindOfClass:[NSDictionary class]] && [(NSDictionary *) newObj objectForKey:@"$class"]))
		{
		if([newObj respondsToSelector:@selector(nibInstantiate)])
			{ // needs to return the replacement object
#if 0
			NSLog(@"object %u already stored:%@", idx, newObj);
			NSLog(@" nibInstantiate=%@", [newObj nibInstantiate]);
			// exit(1);
#endif
			return [newObj nibInstantiate];
			}
		return newObj; // has already been decoded and is not an instance representation record
		}
//	arp=[NSAutoreleasePool new];
	savedRepresentation=_objectRepresentation;	// save
	_objectRepresentation=newObj;	// switch over to representation record
	[_objectRepresentation retain];	// we still need it but will replace the description record in the _objects array by the allocated object
#if KEY_CHECK
	savedProcessedKeys=_unprocessedKeys;
	_unprocessedKeys=[[_objectRepresentation allKeys] mutableCopy];	// make a copy so that we can remove entries
#endif
	_sequentialKey=0;	// start over with $1, $2, ... for -decodeObject
	classRecord=[self decodeObjectForKey:@"$class"];	// may itself be a CFType!
	className=[classRecord objectForKey:@"$classname"];	// but should finally be a plain NSDictionary
#if 0
	NSLog(@"className=%@", className);
#endif
	class=[isa classForClassName:className];	// apply global translation table
	if(!class)
		class=[self classForClassName:className];	// apply local translation table
	if(!class)
		class=NSClassFromString(className);		// translate by loaded frameworks
	if(!class && [_delegate respondsToSelector:@selector(unarchiver:cannotDecodeObjectOfClassName:originalClasses:)])
		class=[_delegate unarchiver:self cannotDecodeObjectOfClassName:className originalClasses:[classRecord objectForKey:@"$classes"]];
	if(!class)
		[NSException raise:NSInvalidUnarchiveOperationException
					 format:@"Can't unarchive object for class %@", className];
	obj=[class alloc];					// allocate a fresh object
	[_objects replaceObjectAtIndex:idx withObject:obj];		// store a first reference to avoid endless recursion for self-references (note: this will [newObj release]!)
//	newObj=[[obj initWithCoder:self] autorelease];			// initialize and decode (which might recursively ask to decode a reference to the current object, e.g. if an object is its own next responder or delegate!)
	newObj=[[obj _initWithKeyedCoder:self] autorelease];

	if(newObj)
		{
		if(newObj != obj)
			[_objects replaceObjectAtIndex:idx withObject:newObj];	// store again, since it has been substituted
		if([_delegate respondsToSelector:@selector(unarchiver:didDecodeObject:)])
			newObj=[_delegate unarchiver:self didDecodeObject:newObj];
		if(newObj != obj && [_delegate respondsToSelector:@selector(unarchiver:willReplaceObject:withObject:)])
			[_delegate unarchiver:self willReplaceObject:obj withObject:newObj];	// has been changed between original call to initWithCoder
		}
#if KEY_CHECK
	if([_unprocessedKeys count] != 0)
		{
		NSLog(@"%@: does not decode these keys: %@ in %@", NSStringFromClass(class), _unprocessedKeys, _objectRepresentation);
		}
	[_unprocessedKeys release];
	_unprocessedKeys=savedProcessedKeys;
#endif
	[_objectRepresentation release];
	_objectRepresentation=savedRepresentation;	// restore
	[newObj retain];	// rescue over arp release
//	[arp release];
#if 0
	NSLog(@"obj=%p", newObj);
#endif
	return [newObj autorelease];
}

- (id) _decodeObjectForRepresentation:(id) obj
{
	id uid;
#if 0
	NSLog(@"decodeObjectForRepresentation %@", obj);
#endif
	if([obj isKindOfClass:[NSCFType class]])
		return [self _dereference:[obj uid]];	// indirect

	if([obj isKindOfClass:[NSArray class]])
		{ // dereference array
		int i, cnt=[obj count];
#if 0
		NSLog(@"decode %u NSArray components for %@", cnt, obj);
#endif
		for(i=0; i<cnt; i++)
			{
#if 0
			id rep=[_objects objectAtIndex:[[obj objectAtIndex:i] uid]];
#endif
			id n;
			n=[self _decodeObjectForRepresentation:[obj objectAtIndex:i]];
#if 0
			if([n isKindOfClass:NSClassFromString(@"NSClassSwapper")])
				{
				NSLog(@"did return class swapper object and not real object: %@", [obj objectAtIndex:i]);
				NSLog(@"  uid=%u", [[obj objectAtIndex:i] uid]);
				NSLog(@"  rep=%@", rep);
				NSLog(@"  obj=%@", n);
				exit(1);
				}
#endif
			if(!n)
				n=[NSNull null];	// replace by NSNull if we could not initialize
			if(![obj isKindOfClass:[NSMutableArray class]])
				obj=[[obj mutableCopy] autorelease];	// not yet mutable - force array to be mutable
			[obj replaceObjectAtIndex:i withObject:n];	// replace by dereferenced object
			}
		return obj;
		}

	if([obj isKindOfClass:[NSDictionary class]])
		{
		if((uid=[(NSDictionary *) obj objectForKey:@"CF$UID"]))
			{
#if 0
			NSLog(@"CF$UID = %@", uid);
#endif
			return [self _dereference:[uid intValue]];
			}
		// shouldn't we dereference dictionary components?
		}

	return obj;	// as is
}

- (id) decodeObjectForKey:(NSString*) name		// handle all special cases
{
	id obj=[_objectRepresentation objectForKey:name];
#if KEY_CHECK
#if 0
	if(!obj)
		{
		NSLog(@"does not contain key: %@ (%@)", name, obj);
		return nil;
		}
#endif
	[_unprocessedKeys removeObject:name];
#endif
	return [self _decodeObjectForRepresentation:obj];
}									// FIX ME pass name ???  e.g. NSAlternateImage

- (id) decodeObject;
{
	NSString *s = [NSString stringWithFormat:@"$%d", ++_sequentialKey];

	return [self decodeObjectForKey:s];
}

- (id) decodeDataObject;
{
	return [self decodeObjectForKey:@"NS.data"];
}

- (BOOL) decodeBoolForKey:(NSString *)key;
{
	id obj=[self decodeObjectForKey:key];
#if 0
	NSLog(@"boolForKey: %@ = %@", key, obj);
#endif
	if(!obj) return NO;	// default
	if(![obj isKindOfClass:[NSNumber class]])
		[NSException raise:NSInvalidUnarchiveOperationException format:@"Can't unarchive object for key %@ as BOOL (obj=%@)", key, obj];
#if 0
	NSLog(@"  -> %@", [obj boolValue]?@"YES":@"NO");
#endif
	return [obj boolValue];
}

- (const unsigned char *) decodeBytesForKey:(NSString *)key
							 returnedLength:(NSUInteger *)lengthp;
{
	id obj=[self decodeObjectForKey:key];
#if 0
	NSLog(@"decodeBytesForKey %@ -> %@ [%@] %@", key, obj, NSStringFromClass([obj class]), self);
#endif
	if(!obj)
		{ // no data
		*lengthp=0;
		return NULL;
		}
	if(![obj isKindOfClass:[NSData class]])
		[NSException raise:NSInvalidUnarchiveOperationException format:@"Can't unarchive object for key %@ as bytes (obj=%@)", key, obj];
	if(lengthp)
		*lengthp=[obj length];
#if 0
	NSLog(@"length=%d bytes=%p", [obj length], [obj bytes]);
#endif
	return [obj bytes];
}

- (double) decodeDoubleForKey:(NSString *)key;
{
	id obj=[self decodeObjectForKey:key];
	if(!obj) return 0.0;	// default
	if(![obj isKindOfClass:[NSNumber class]])
		[NSException raise:NSInvalidUnarchiveOperationException format:@"Can't unarchive object for key %@ as double (obj=%@)", key, obj];
	return [obj doubleValue];
}

- (float) decodeFloatForKey:(NSString *)key;
{
	id obj=[self decodeObjectForKey:key];
	if(!obj) return 0.0;	// default
	if(![obj isKindOfClass:[NSNumber class]])
		[NSException raise:NSInvalidUnarchiveOperationException format:@"Can't unarchive object for key %@ as float (obj=%@)", key, obj];
	return [obj floatValue];
}

- (int) decodeInt32ForKey:(NSString *)key;
{
	id obj=[self decodeObjectForKey:key];
	if(!obj) return 0;	// default
	if(![obj isKindOfClass:[NSNumber class]])
		[NSException raise:NSInvalidUnarchiveOperationException format:@"Can't unarchive object for key %@ as int32 (obj=%@)", key, obj];
	return [obj longValue];
}

- (int64_t) decodeInt64ForKey:(NSString *)key;
{
	id obj=[self decodeObjectForKey:key];
	if(!obj) return 0;	// default
	if(![obj isKindOfClass:[NSNumber class]])
		[NSException raise:NSInvalidUnarchiveOperationException format:@"Can't unarchive object for key %@ as int64 (obj=%@)", key, obj];
	return [obj longLongValue];
}

- (int) decodeIntForKey:(NSString *)key;
{
	id obj=[self decodeObjectForKey:key];
	if(!obj) return 0;	// default
	if(![obj isKindOfClass:[NSNumber class]])
		[NSException raise:NSInvalidUnarchiveOperationException format:@"Can't unarchive object for key %@ as int (obj=%@)", key, obj];
	return [obj intValue];
}

- (NSPoint) decodePointForKey:(NSString *)key;
{
	id obj=[self decodeObjectForKey:key];
	if(!obj) return NSZeroPoint;	// default
	if([obj isKindOfClass:[NSString class]])
		return NSPointFromString(obj);
	if(![obj isKindOfClass:[NSValue class]])
		[NSException raise:NSInvalidUnarchiveOperationException format:@"Can't unarchive object for key %@ as NSPoint (obj=%@)", key, obj];
	return [obj pointValue];
}

- (NSRect) decodeRectForKey:(NSString *)key;
{
	id obj=[self decodeObjectForKey:key];
	if(!obj) return NSZeroRect;	// default
	if([obj isKindOfClass:[NSString class]])
		{
#if 0
		NSRect r=NSRectFromString(obj);
		NSLog(@"decodeRectForKey: %@ -> NSString %@", key, obj);
		NSLog(@"string from rect: %@", NSStringFromRect(r));
#endif
		return NSRectFromString(obj);
		}
	if(![obj isKindOfClass:[NSValue class]])
		[NSException raise:NSInvalidUnarchiveOperationException format:@"Can't unarchive object for key %@ as NSRect (obj=%@)", key, obj];
	return [obj rectValue];
}

- (NSSize) decodeSizeForKey:(NSString *)key;
{
	id obj=[self decodeObjectForKey:key];
	if(!obj) return NSZeroSize;	// default
	if([obj isKindOfClass:[NSString class]])
		return NSSizeFromString(obj);
	if(![obj isKindOfClass:[NSValue class]])
		[NSException raise:NSInvalidUnarchiveOperationException format:@"Can't unarchive object for key %@ as NSSize (obj=%@)", key, obj];
	return [obj sizeValue];
}

- (void) finishDecoding;
{
#if 0
	NSLog(@"NSKeyedUnarchiver finishDecoding");
#endif
	if(_delegate && [_delegate respondsToSelector:@selector(unarchiverWillFinish:)])
		[_delegate unarchiverWillFinish:self];
	[_objectRepresentation release];
	_objectRepresentation=nil;
	[_objects release];
	_objects=nil;
	if(_delegate && [_delegate respondsToSelector:@selector(unarchiverDidFinish:)])
		[_delegate unarchiverDidFinish:self];
	// release local ARP
}

- (unsigned int) systemVersion			{ return 1; }

@end /* NSKeyedUnarchiver */


@implementation NSKeyedUnarchiver  (GMUnarchiver)

+ (id) unarchiverWithContentsOfFile:(NSString*)path
{
	id plist = [[NSString stringWithContentsOfFile:path] propertyList];
	NSKeyedUnarchiver *u;

	if (!plist)
		return nil;

	u = [[[self alloc] initForReadingWithPropertyList:plist] autorelease];

	return u;
}

+ (id) unarchiveObjectWithName:(NSString*)name fromPropertyList:(id)plist
{
	NSKeyedUnarchiver *u;

	u = [[[self alloc] initForReadingWithPropertyList:plist] autorelease];

	return [u decodeObjectWithName:name];
}

+ (id) unarchiveObjectWithName:(NSString*)name fromFile:(NSString*)path
{
	NSKeyedUnarchiver *unarchiver = [self unarchiverWithContentsOfFile:path];

	return [unarchiver decodeObjectWithName:name];
}

- (id) init
{
	return [self initForReadingWithPropertyList:nil];
}

- (id) initForReadingWithPropertyList:(id)plist
{
	NSString *versionString;

	propertyList = [plist copy];
	_decodedObjectRepresentation = propertyList;
	namesToObjects = [NSMutableDictionary dictionaryWithCapacity:119];
														// Decode version info
	versionString = [propertyList objectForKey:@"Version"];
	[[NSScanner scannerWithString:versionString] scanInt:&version];

	return self;
}

- (id) decodedObjectRepresentation
{
	return _decodedObjectRepresentation;
}

- (id) decodeObjectWithName:(NSString*)name
{
	id object, label, representation, className, aliasName;
	id upperObjectRepresentation, newObject;
	BOOL objectOnTopLevel = NO;
	Class c;

	if (!name)
		return nil;
											// see if obj was already decoded
	if ((level) && (object = [namesToObjects objectForKey:name]))
		return object;
						// object has not been decoded yet. Read its label from 
						// the current object dictionary representation
	label = [_decodedObjectRepresentation objectForKey:name];
	
	if (label)			// see if object has been decoded using `label' as name
		{
		if ((object = [namesToObjects objectForKey:label]))
			return object;
		}
	else
		{							// Try to find the object on the top level
		if ((label = [propertyList objectForKey:name]))
			objectOnTopLevel = YES;
		else						// There is no object with this name within 
			{						// the current object or on the top level.
			DBLog (@"No object named '%@' in object representation '%@'",
						name, _decodedObjectRepresentation);
	
			return nil;
		}	}						// If on the top level the description is 
									// really the representation of the object. 
									// Otherwise the value is the name of an 
									// object on the top level.
	if (_decodedObjectRepresentation != propertyList && !objectOnTopLevel)
		{
		NSAssert1 ([label isKindOfClass: [NSString class]],
					@"label is not a string: '%@'!", label);
										// label is either a name of an object 
		if ([label isEqual:@"nil"])		// on the top level dictionary or the
			return nil;					// string "nil" which means the object
										// has the nil value.
		representation = [propertyList objectForKey:label];
		}
	else 
		{
		representation = label;
		label = name;
		}
	
	if (!representation)				// There is no object with such a  
		{								// label on the top level dictionary
		NSLog (@"No object object named '%@' on the top level dictionary! "
				@"(error within object representation '%@')",
				label, _decodedObjectRepresentation);

		return nil;
		}
							// Temporary save the current object representation
	upperObjectRepresentation = _decodedObjectRepresentation;
	_decodedObjectRepresentation = representation;
	
	className = [representation objectForKey:@"isa"];	  // Create the object
	if(!(aliasName = [__classToAliasMappings objectForKey: className]))
		c = NSClassFromString(className);
	else
		c = NSClassFromString(aliasName);
	object = [c createObjectForModelUnarchiver:self];
	
	if (!c) 
		{
		NSLog (@"Class %@ not linked into application!", className);
		return nil;
		}
								// Push it into the dictionary of known objects
	[namesToObjects setObject:object forKey:label];

	level++;					// Init it from model dictionary if object is 
	if (object != c)			// an instance and not the class object
		newObject = [object initWithModelUnarchiver:self];
	level--;
	
	if (newObject != object)
		{
		object = newObject;
		[namesToObjects setObject:object forKey:label];
		}
								// Restore the current object representation
	_decodedObjectRepresentation = upperObjectRepresentation;
	
	return object;
}

- (NSString*) decodeStringWithName:(NSString*)name
{
	id string;

	if (!name)
		return nil;

	if (!(string = [_decodedObjectRepresentation objectForKey:name])) 
		{
		DBLog (@"Couldn't find string value for key '%@' (object '%@')",
	    			name, _decodedObjectRepresentation);

		return nil;
		}

	if (![string isKindOfClass:[NSString class]]) 
		{
		NSLog(@"Decoded object is not a string: '%@'! (key '%@', object '%@')",
				string, name, _decodedObjectRepresentation);
		return nil;
		}

	return string;
}

- (NSData*) decodeDataWithName:(NSString*)name
{
	id data;

	if (!name)
		return nil;

	if (!(data = [_decodedObjectRepresentation objectForKey:name]))
		{
		NSLog (@"Couldn't find the data value for key '%@' (object '%@')",
				name, _decodedObjectRepresentation);
		return nil;
		}

	if (![data isKindOfClass:[NSData class]])
		{
		NSLog (@"Decoded object is not a data: '%@'! (key '%@', object '%@')",
				data, name, _decodedObjectRepresentation);
		return nil;
		}

	return data;
}

- (NSArray*) decodeArrayWithName:(NSString*)name
{
	id array, decodedArray;
	int i, count;

	if (!name)
		return nil;

	if (!(array = [_decodedObjectRepresentation objectForKey:name]))
		{
		NSLog (@"Couldn't find the array value for key '%@' (object '%@')",
				name, _decodedObjectRepresentation);
		return nil;
		}

	if (![array isKindOfClass:[NSArray class]])
		{
		NSLog(@"Decoded object is not an array: '%@'! (key '%@', object '%@')",
				array, name, _decodedObjectRepresentation);
		return nil;
		}

	count = [array count];
	decodedArray = [NSMutableArray arrayWithCapacity:count];
	for (i = 0; i < count; i++)
		{
		id label = [array objectAtIndex:i];
		id objectDescription = [propertyList objectForKey:label];

		if (!objectDescription)
			{
      NSLog (@"warning: couldn't find the description for object labeled '%@' "
	     @"in the array description '%@ = %@'!", label, name, array);
			continue;
			}

		[decodedArray addObject:[self decodeObjectWithName:label]];
		}

	return decodedArray;
}

- (NSDictionary*) decodeDictionaryWithName:(NSString*)name
{
	id dictionary, decodedDictionary;
	id enumerator, keyLabel, valueLabel;

	if (!name)
		return nil;

	dictionary = [_decodedObjectRepresentation objectForKey:name];
	if (!dictionary) 
		{
		NSLog(@"Couldn't find the dictionary value for key '%@' (object '%@')",
				name, _decodedObjectRepresentation);
		return nil;
		}

	if (![dictionary isKindOfClass:[NSDictionary class]])
		{
		NSLog (@"Decoded object is not a dictionary: '%@'! (key '%@', object '%@')",
	   dictionary, name, _decodedObjectRepresentation);
		return nil;
		}

	decodedDictionary = [NSMutableDictionary dictionaryWithCapacity:[dictionary count]];
	enumerator = [dictionary keyEnumerator];
	while ((keyLabel = [enumerator nextObject]))
		{
		id key, value, objectDescription;

		if (!(objectDescription = [propertyList objectForKey:keyLabel]))
			{
      NSLog (@"warning: couldn't find the description for object labeled '%@' "
	     @"in the dictionary description '%@ = %@'!",
	     keyLabel, name, dictionary);
			continue;
			}

		key = [self decodeObjectWithName:keyLabel];
		valueLabel = [dictionary objectForKey:keyLabel];

		if (!(objectDescription = [propertyList objectForKey:valueLabel]))
			{
      NSLog (@"warning: couldn't find the description for object labeled '%@' "
	     @"in the dictionary description '%@ = %@'!",
	     valueLabel, name, dictionary);
			continue;
			}

		value = [self decodeObjectWithName:valueLabel];
		[decodedDictionary setObject:value forKey:key];
		}

	return decodedDictionary;
}

- (Class) decodeClassWithName:(NSString*)name
{
	NSString *className = [self decodeStringWithName:name];

	return className ? NSClassFromString (className) : Nil;
}

- (SEL) decodeSelectorWithName:(NSString*)name
{
	NSString *selectorName = [self decodeStringWithName:name];

	return selectorName ? NSSelectorFromString (selectorName) : NULL;
}

- (char) decodeCharWithName:(NSString*)name
{
	NSString *v;
	
	if (!name || !(v = [_decodedObjectRepresentation objectForKey:name]))
		return 0;

	return *[v cString];
}

- (unsigned char) decodeUnsignedCharWithName:(NSString*)name
{
	NSString *v;
	
	if (!name || !(v = [_decodedObjectRepresentation objectForKey:name]))
		return 0;

	return *[v cString];
}

- (BOOL) decodeBOOLWithName:(NSString*)name
{
	NSString *v;
	
	if (!name || !(v = [_decodedObjectRepresentation objectForKey:name]))
		return NO;

	return [v compare:@"YES" options:NSCaseInsensitiveSearch] == NSOrderedSame;
}

- (short) decodeShortWithName:(NSString*)name
{
	return [self decodeIntWithName:name];
}

- (unsigned short) decodeUnsignedShortWithName:(NSString*)name
{
	return [self decodeIntWithName:name];
}

- (int) decodeIntWithName:(NSString*)name
{
	NSString *v;
	int value;
	
	if (name && (v = [_decodedObjectRepresentation objectForKey:name]))
		{
		if ([[NSScanner scannerWithString:v] scanInt: &value]) 
			return value;

		NSLog(@"Failed to scan int '%@' from object '%@' with key '%@'",
				v, _decodedObjectRepresentation, name);
		}

	return 0;
}

- (unsigned int) decodeUnsignedIntWithName:(NSString*)name
{
	return [self decodeIntWithName:name];
}

- (long) decodeLongWithName:(NSString*)name
{
	return [self decodeIntWithName:name];
}

- (unsigned long) decodeUnsignedLongWithName:(NSString*)name
{
	return [self decodeIntWithName:name];
}

- (float) decodeFloatWithName:(NSString*)name
{
	NSString *v;
	float value;
	
	if (name && (v = [_decodedObjectRepresentation objectForKey:name]))
		{
		if ([[NSScanner scannerWithString:v] scanFloat: &value]) 
			return value;

		NSLog(@"Failed to scan int '%@' from object '%@' with key '%@'",
				v, _decodedObjectRepresentation, name);
		}

	return 0;
}

- (double) decodeDoubleWithName:(NSString*)name
{
	return [self decodeDoubleWithName:name];
}

- (NSPoint) decodePointWithName:(NSString*)name
{
	NSString *v;
	
	if (!name || !(v = [_decodedObjectRepresentation objectForKey:name]))
		return NSZeroPoint;

	return NSPointFromString (v);
}

- (NSSize) decodeSizeWithName:(NSString*)name
{
	NSString *v;
	
	if (!name || !(v = [_decodedObjectRepresentation objectForKey:name]))
		return NSZeroSize;

	return NSSizeFromString (v);
}

- (NSRect) decodeRectWithName:(NSString*)name
{
	NSString *v;
	
	if (!name || !(v = [_decodedObjectRepresentation objectForKey:name]))
		return NSZeroRect;

	return NSRectFromString (v);
}

- (BOOL) isAtEnd
{
	return NO;													// FIX ME
}

- (unsigned int) systemVersion			{ return version; }

+ (NSString*) classNameDecodedForArchiveClassName:(NSString*)nameInArchive
{
	NSString *className = [__classToAliasMappings objectForKey:nameInArchive];

    return className ? className : nameInArchive;
}

+ (void) decodeClassName:(NSString*)nameInArchive
			 asClassName:(NSString*)trueName
{
    [__classToAliasMappings setObject:trueName forKey:nameInArchive];
}

- (NSString*) classNameDecodedForArchiveClassName:(NSString*)nameInArchive
{
	return nameInArchive;
}

- (void) decodeClassName:(NSString*)nameInArchive
			 asClassName:(NSString*)trueName
{
}

- (unsigned int) versionForClassName:(NSString*)className
{
	return 1;
}

@end /* NSKeyedUnarchiver */


NSString *NSInvalidArchiveOperationException   = @"NSInvalidArchiveOperationException";
NSString *NSInvalidUnarchiveOperationException = @"NSInvalidUnarchiveOperationException";
