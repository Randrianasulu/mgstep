/*
   IMConnectors.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Derived from IBConnectors in objcX, written by 
   Scott Francis, Paul Kunz, Imran Qureshi and Libing Wang.

   Author: Ovidiu Predescu <ovidiu@net-community.com>
   Date: November 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSKeyedArchiver.h>
#include <AppKit/NSActionCell.h>

#include "IMCustomObject.h"

// global variables
extern id __nibOwner;


static void
_setInstanceVariable(id obj, const char *varName, const void *value)
{
#ifdef NEW_RUNTIME

	NSLog(@"%@: setting ivar '%s' to %x", obj, varName, value);

	if (object_setInstanceVariable (obj, varName, (void *)value))
		DBLog(@"found it!");
#else
	if (obj)
		{
		struct objc_class *class = [obj class];
		struct objc_ivar_list *ivars;
		int i;

		NSLog(@"%@: setting ivar '%s' to %x",obj, varName, value);
	
//		for (;class != Nil; class = class_getSuperclass(class))
		for (;class != Nil; class = class_get_super_class(class))
			{
			if (ivars = class->ivars)
				for (i = 0; i < ivars->ivar_count; i++) 
					{
					struct objc_ivar ivar = ivars->ivar_list[i];
			
					if (ivar.ivar_name && !strcmp (ivar.ivar_name, varName)) 
						{
						*((void**)(((char*)obj) + ivar.ivar_offset)) = (id)value;
						DBLog(@"found it!");
		
						return;
					}	}
	
			NSLog(@"searching superclass ivars");
			}

		NSLog(@"** warning: ivar was not found\n");
		}
#endif
}


@interface IMConnector : NSObject
{
	id source;
	id destination;
	NSString *label;
}

- (id) source;
- (id) destination;
- (id) label;

@end

@implementation IMConnector

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver
{
	[archiver encodeObject:source withName:@"source"];
	[archiver encodeObject:destination withName:@"destination"];
	[archiver encodeObject:label withName:@"label"];
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	source = [unarchiver decodeObjectWithName:@"source"];
	destination = [unarchiver decodeObjectWithName:@"destination"];
	label = [unarchiver decodeObjectWithName:@"label"];

	return self;
}

- (id) source					{ return source; }
- (id) destination				{ return destination; }
- (id) label					{ return label; }

@end /* IMConnector */


@interface IMControlConnector : IMConnector

- (void) establishConnection;

@end

@implementation IMControlConnector : IMConnector

- (void) establishConnection
{
	id _source = [source nibInstantiate];
	id _destination = [destination nibInstantiate];
	SEL action = NSSelectorFromString(label);

	if ([_source respondsToSelector:@selector(setTarget:)]) 
		{									
		if(!_destination)						// FIX ME, should we assume nil
			_destination = __nibOwner;			// dest s/b connected to owner?
		NSLog (@"%@: setting target to %@", _source, _destination);
		[_source setTarget:_destination];
		}
	else
		_setInstanceVariable (_source, "target", [_destination retain]);

	if ([_source respondsToSelector:@selector(setAction:)]) 
		{
		DBLog(@"%@: setting action to %@", _source, 
					NSStringFromSelector(action));
		[_source setAction:action];
		}
	else
		_setInstanceVariable (_source, "action", action);
}

@end /* IMControlConnector */


@interface IMOutletConnector : IMConnector

- (void) establishConnection;

@end

@implementation IMOutletConnector

- (void) establishConnection
{
	id _source = [source nibInstantiate];
	id _destination = [destination nibInstantiate];
	NSString *s = [@"set" stringByAppendingString:[label capitalizedString]];
	NSString *setMethodName = [s stringByAppendingString:@":"];
	SEL setSelector = NSSelectorFromString(setMethodName);

	NSLog (@"establish connection: source %@, destination %@, label %@",
			_source, _destination, label);

	if (setSelector && [_source respondsToSelector:setSelector])
		[_source performSelector:setSelector withObject:_destination];
	else
		_setInstanceVariable(_source, [label cString], [_destination retain]);
}

@end /* IMOutletConnector */
