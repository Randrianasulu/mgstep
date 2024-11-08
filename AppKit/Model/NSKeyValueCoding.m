/*
   NSKeyValueCoding.m

   Object graph coding using Keys and Values

   Created by Dr. H. Nikolaus Schaller on Tue Oct 05 2004.
   Copyright (c) 2004 DSITRI.

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSException.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSNull.h>
#include <Foundation/NSKeyValueCoding.h>
#include <Foundation/NSMethodSignature.h>

#include <ctype.h>


NSString *NSTargetObjectUserInfoKey = @"NSTargetObjectUserInfoKey";
NSString *NSUnknownUserInfoKey      = @"NSUnknownUserInfoKey";

NSString *NSUndefinedKeyException   = @"NSUndefinedKeyException";


@implementation NSObject (NSKeyValueCoding)

+ (BOOL) accessInstanceVariablesDirectly;
{
	return YES;	// default is YES
}

- (id) valueForKeyPath:(NSString *)str
{
	id o=self;
	NSEnumerator *e=[[str componentsSeparatedByString:@"."] objectEnumerator];
	NSString *key;
//	NSLog(@"path=%@", str);
	while(o && (key=[e nextObject]))
//		NSLog(@"key=%@", str);
		// raise exception if !o?
		o=[o valueForKey:key];	// go down key path
	return o;	// return result
}

- (void) setValue:(id)val forKeyPath:(NSString *)str
{ 
	id o=self;
	NSArray *path=[str componentsSeparatedByString:@"."];
	NSEnumerator *e=[path objectEnumerator];
	NSString *key=[e nextObject];
	NSString *nextKey;
	while(o && key)
		{
		nextKey=[e nextObject];
		if(!nextKey)
			{ // is last component
			[o setValue:val forKey:key];	// recursive descent
			return;
			}
		o=[o valueForKey:key];	// go down key path
		key=nextKey;
		}
	// exception?
}

// FIXME: we should define a cache to map the key to the IMP/relative address and necessary type conversions

- (id) valueForKey:(NSString *)str
{
	SEL s;
	IMP msg;
	const char *type=NULL;
	void *addr;	// address of return value
	// FIXME: should also try to look for getter methods like <key>, _<key>, is<Key>, get<Key> etc.
#if 1
	NSLog(@"valueForKey: %@", str);
	NSLog(@"selector: %@", NSStringFromSelector(s));
#endif
	/* if(found in cache)
	 get msg, type, addr from cache
	 else {
	 ...
	 add to cache
	 -> handle valueForUndefinedKey key special case so that we don't search again if we know
	 }*/
	if((s=NSSelectorFromString(str)) && [self respondsToSelector:s])
		{
#ifdef NEW_RUNTIME
		NSMethodSignature *sig=[self methodSignatureForSelector:s];	// FIXME: this can be pretty slow!
		type=[sig methodReturnType];
		msg = objc_msg_lookup(self, s);
#else
		struct objc_method *m = (object_is_instance(self) 
								 ? class_get_instance_method(isa, s)
								 : class_get_class_method(isa, s));
		Class c = object_get_class(self);
		struct objc_protocol_list *protocols = c?c->protocols:NULL;
		msg=m?m->method_imp:NULL;
		type=m?m->method_types:NULL;	// default (if we have an implementation)
		if(protocols)
			// do we need to scan through protocols?
			NSLog(@"not scanning protocols for valueForKey:%@", str);
#endif
//		NSLog(@"IMP = %p", msg);
		if (!msg)
			return _NSInitError(self, @"unknown getter - %s", sel_get_name(s));
		}
	else if([isa accessInstanceVariablesDirectly])
		{ // not disabled: try to access instance variable directly
		struct objc_class *class;
		const char *varName=[str UTF8String];
#ifndef NEW_RUNTIME
		for(class=isa; class != Nil; class = class_get_super_class(class))
			{ // walk upwards through class tree
			struct objc_ivar_list *ivars;
			if((ivars = class->ivars))
				{ // go through instance variables
				int i;
				for(i = 0; i < ivars->ivar_count; i++) 
					{
					struct objc_ivar ivar = ivars->ivar_list[i];
					if(!ivar.ivar_name)
						continue;	// no name - skip
					if(strcmp(ivar.ivar_name, varName) == 0 || (ivar.ivar_name[0]=='_' && strcmp(ivar.ivar_name+1, varName) == 0)) 
						{
						msg=NULL;
						type=ivar.ivar_type;
						addr=((char *)self) + ivar.ivar_offset;
						break;	// found
						}
					}
				if(i < ivars->ivar_count)
					break;	// fall through
				}
			}
#else
		{
		const void *value;

		if (object_getInstanceVariable (self, varName, (void *)value))
			return (id)value;
		}
#endif
		}

//	NSLog(@"valueForKey type %s", type?type:"not found");
	if(!type)
		return [self valueForUndefinedKey:str];	// was not found

	switch(*type)
		{
			case _C_ID:
			case _C_CLASS:
				return msg ? (*(id (*)(id, SEL)) msg)(self, s) : *(id *) addr;	// get object value
			case _C_CHR:
			case _C_UCHR:
				{
				char ret=msg ? (*(char (*)(id, SEL)) msg)(self, s) :  *(char *) addr;
#if 0
				NSLog(@"valueForKey boxing char");
#endif
				// FIXME: separate signed and unsigned
				return [NSNumber numberWithChar:ret];
				}
			case _C_INT:
			case _C_UINT:
				{
				int ret=msg ? (*(int (*)(id, SEL)) msg)(self, s) :  *(int *) addr;
#if 0
				NSLog(@"valueForKey boxing int");
#endif
				// FIXME: separate signed and unsigned
				return [NSNumber numberWithInt:ret];
				}
			// FIXME: handle other types
		}

	NSLog(@"valueForKey:%@ does not return an object that we can convert (type=%s)", str, type);

	return [self valueForUndefinedKey:str];	// was not found
}

#if NEW

/*
 use as
 if((ivar=_findIvar(isa, "_", 1, name)) == NULL)
	if((ivar=_findIvar(isa, "_isa", 1, name)) == NULL)
		return not found;
 ...
 */

static struct objc_ivar *
_findIvar(struct objc_class *class, char *prefix, int preflen, char *name)
{
	struct objc_ivar *ivar;

	for(; class != Nil; class = class_get_super_class(class))
		{ // walk upwards through class tree
		struct objc_ivar_list *ivars;
		int i;
		if((ivars = class->ivars))
			{
			for(i = 0; i < ivars->ivar_count; i++) 
				{ // check _key
				ivar=&ivars->ivar_list[i];
#if 0
				NSLog(@"check %s = %s", ivar->ivar_name, varName);
#endif
				if(!ivar->ivar_name)
					continue;	// no name - skip
				if(strncmp(ivar->ivar_name, prefix, preflen) == 0 && strcmp(ivar->ivar_name+preflen, name) == 0)
					return ivar;	// found
				}
			}
		}
	return NULL;	// not found
}

#endif

- (void) setValue:(id)val forKey:(NSString *)str
{
	const char *varName=[str cString];
	int len=3+strlen(varName)+1+1;	// check if a matching setter exists (incl. room for "set" or "_is" and a ":")
	char *selName = malloc(len);
	SEL s;
	strcpy(selName, "set");
	strcpy(selName+3, varName);	// append
	selName[3]=toupper(selName[3]);	// capitalize the first letter following "set"
	strcat(selName+3, ":");	// append a :
	NSAssert(strlen(selName) < len, @"buffer overflow");
	s=sel_get_any_uid(selName);
#if 0
	NSLog(@"%p %@: setValue:forKey:%@ val=%@", self, self, str, val);
	NSLog(@"setter = %@ (%s)", NSStringFromSelector(s), selName);
#endif
	if(s && [self respondsToSelector:s])
		{
		// get method signature
		// if necessary, use [val intValue] etc. to fetch the argument with the correct type
		free(selName);
		if(!val)
			[self setNilValueForKey:str];
		else
			[self performSelector:s withObject:val];
		return;
		}
#if 0
	NSLog(@"object does not respond to setter");
#endif
	if([isa accessInstanceVariablesDirectly])
		{
#ifdef NEW_RUNTIME		// go through instance variables in this order:  <key>, _<key>, _is<Key>, or is<Key>
	{
	if (object_setInstanceVariable (self, varName, (void *)val))
		return;
	else				// FIX ME should we autorelease previous value ?
		{
		char *b = calloc(strlen(varName) + 10, 1);
		
		*b = '_';
		strncpy(b+1,varName,strlen(varName));
		if (object_setInstanceVariable (self, b, (void *)val))
			{
			free(b);
			return;
			}
		strncpy(b+1,"is",2);
		strncpy(b+3,varName,strlen(varName));
		if (object_setInstanceVariable (self, b, (void *)val))
			{
			free(b);
			return;
			}
		strncpy(b,"is",2);
		strncpy(b+2,varName,strlen(varName));
		if (object_setInstanceVariable (self, b, (void *)val))
			{
			free(b);
			return;
			}
		free(b);
		}
	}
#else
		// FIXME: we should walk the tree for each variant!
		// FIXME: here, we must remove the trailing ":"
		struct objc_class *class;
		for(class=isa; class != Nil; class = class_get_super_class(class))
			{ // walk upwards through class tree
			struct objc_ivar_list *ivars;
			struct objc_ivar ivar;
			if((ivars = class->ivars))
				{ // go through instance variables in this order: _<key>, _is<Key>, <key>, or is<Key>
				int i;
				for(i = 0; i < ivars->ivar_count; i++) 
					{ // check _key
					ivar = ivars->ivar_list[i];
#if 0
					NSLog(@"check %s = %s", ivar.ivar_name, varName);
#endif
					if(!ivar.ivar_name)
						continue;	// no name - skip
					if(ivar.ivar_name[0]=='_' && strcmp(ivar.ivar_name+1, varName) == 0)
						break;	// found
					}
				if(i == ivars->ivar_count)
					{
					for(i = 0; i < ivars->ivar_count; i++)
						{ // check _isKey
						ivar = ivars->ivar_list[i];
#if 0
						NSLog(@"check %s = %s", ivar.ivar_name, selName+3);
#endif
						if(!ivar.ivar_name)
							continue;	// no name - skip
						if(ivar.ivar_name[0]=='_' && ivar.ivar_name[1]=='i'
								&& ivar.ivar_name[2]=='s'
								&& strcmp(ivar.ivar_name+3, selName+3) == 0)
							break;	// found
						}
					}
				if(i == ivars->ivar_count)
					{
					for(i = 0; i < ivars->ivar_count; i++)
						{ // check key
						ivar = ivars->ivar_list[i];
#if 0
						NSLog(@"check %s = %s", ivar.ivar_name, varName);
#endif
						if(!ivar.ivar_name) continue;	// no name - skip
						if(strcmp(ivar.ivar_name, varName) == 0) break;	// found
						}
					}
				if(i == ivars->ivar_count) 
					{
					for(i = 0; i < ivars->ivar_count; i++)
						{ // check isKey
						ivar = ivars->ivar_list[i];
#if 0
						NSLog(@"check %s = %s", ivar.ivar_name, selName+3);
#endif
						if(!ivar.ivar_name) continue;	// no name - skip
						if(ivar.ivar_name[0]=='i' &&ivar.ivar_name[1]=='s' && strcmp(ivar.ivar_name+2, selName+3) == 0) break;	// found
						}
					}
				if(i < ivars->ivar_count) 
					{ // found
					  // FIXME: should take a look at ivar_type to be an id or call a converter
					id *vp=(id *) (((char *)self) + ivar.ivar_offset);
					[*vp autorelease];
					*vp=[val retain];
#if 0
					NSLog(@"found matching ivar: %s[%d] %p", ivar.ivar_name, ivar.ivar_offset, vp);
#endif
					free(selName);
					return;
					}
				}
			}
#endif
		}

	free(selName);
	[self setValue:(id) val forUndefinedKey:str];
}

- (void) setValue:(id)value forUndefinedKey:(NSString *)key
{
	NSString *r = [NSString stringWithFormat:@"setValue:%@ forKey:%@ is undefined: %@", value, key, self];
	NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys: self, NSTargetObjectUserInfoKey, key, NSUnknownUserInfoKey, nil];

	[[NSException exceptionWithName:NSUndefinedKeyException reason:r userInfo:d] raise];
}

- (void) setNilValueForKey:(NSString *)key
{
	[NSException raise:NSInvalidArgumentException
				 format:@"%@ can't setNilValue: for key %@: %@", self, key, self];
}

- (id) valueForUndefinedKey:(NSString *)key
{
	NSString *r = [NSString stringWithFormat:@"valueForKey:%@ is undefined: %@", key, self];
	NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:self, NSTargetObjectUserInfoKey, key, NSUnknownUserInfoKey, nil];

	[[NSException exceptionWithName:NSUndefinedKeyException reason:r userInfo:d] raise];

	return nil;
}

- (NSDictionary *) dictionaryWithValuesForKeys:(NSArray *)keys
{
	NSMutableDictionary *r=[NSMutableDictionary dictionaryWithCapacity:[keys count]];
	NSEnumerator *e=[keys objectEnumerator];
	NSString *key;
	id val;

	while((key=[e nextObject]))
		{
		val=[self valueForKey:key];
		if(!val)
			val=[NSNull null];
		[r setObject:val forKey:key];
		}

	return r;
}

- (void) setValuesForKeysWithDictionary:(NSDictionary *)keyedValues
{
	NSEnumerator *e=[keyedValues keyEnumerator];
	NSString *key;
	id val;
	while((key=[e nextObject]))
		{
		val=[keyedValues objectForKey:key];
		if([val isKindOfClass:[NSNull class]])
			val=nil;
		[self setValue:val forKey:key];
		}
}

- (BOOL) validateValue:(id *) val forKey:(NSString *) str error:(NSError **) error		{ NIMP; return NO; }
- (BOOL) validateValue:(id *) val forKeyPath:(NSString *) str error:(NSError **) error	{ NIMP; return NO; }
- (NSMutableArray *) mutableArrayValueForKey:(NSString *) str     { return NIMP; }
- (NSMutableArray *) mutableArrayValueForKeyPath:(NSString *) str { return NIMP; }
- (NSMutableSet *) mutableSetValueForKey:(NSString *) key         { return NIMP; }
- (NSMutableSet *) mutableSetValueForKeyPath:(NSString *) keyPath { return NIMP; }

@end


@implementation NSDictionary (NSKeyValueCoding)

- (id) valueForKey:(NSString *)key
{
	return [self objectForKey:key];
}

@end


@implementation NSMutableDictionary (NSKeyValueCoding)

- (void) setValue:(id)value forKey:(NSString *)key
{
	[self setObject:value forKey:key];
}

@end
