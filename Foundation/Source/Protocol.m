/*
   Protocol.m

   Implementation of class Protocol

   Copyright (C) 1997 Free Software Foundation, Inc.

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/Protocol.h>



@implementation Protocol

+ (struct objc_method_description *) descriptionForInstanceMethod:(SEL)s
{
	return (struct objc_method_description *)class_get_instance_method(self,s);
}

- (struct objc_method_description *) descriptionForMethod:(SEL)aSel
{
	return (struct objc_method_description *) (object_is_instance(self)
								? class_get_instance_method(self->isa, aSel)
								: class_get_class_method(self->isa, aSel));
}

- (struct objc_method_description *) descriptionForInstanceMethod:(SEL)aSel
{
	int i;
	struct objc_protocol_list *proto_list;			// Look up information
	const char *name = sel_get_name (aSel);			// specific to a protocol
	struct objc_method_description *result;

	for (i = 0; i < instance_methods->count; i++)
		if (!strcmp ((char*)instance_methods->list[i].name, name))
			return &(instance_methods->list[i]);

	for (proto_list = protocol_list; proto_list; proto_list = proto_list->next)
		{
		for (i = 0; i < proto_list->count; i++)
		  if((result = [(id)proto_list->list[i] descriptionForInstanceMethod:aSel]))
			   return result;
		}

	return NULL;
}

- (struct objc_method_description *) descriptionForClassMethod:(SEL)aSel
{
	int i;
	struct objc_protocol_list *proto_list;
	const char *name = sel_get_name (aSel);
	struct objc_method_description *result;

	for (i = 0; i < class_methods->count; i++)
		if (!strcmp ((char*)class_methods->list[i].name, name))
			return &(class_methods->list[i]);

	for (proto_list = protocol_list; proto_list; proto_list = proto_list->next)
		{
		for (i = 0; i < proto_list->count; i++)
			if((result = [(id)proto_list->list[i] descriptionForClassMethod:aSel]))
				return result;
		}

	return NULL;
}

- (const char *) name
{
	return _protocolName;
}

- (BOOL) conformsTo:(Protocol *)aProtocolObject		// Test conformance
{
#ifdef NEW_RUNTIME
	Class c;

	for (c = object_getClass(self); c != Nil; c = class_getSuperclass(c))
		if (class_conformsToProtocol(c, aProtocolObject))
			return YES;
#else
	int i;
	struct objc_protocol_list *proto_list;

	if (!strcmp(aProtocolObject->_protocolName, self->_protocolName))
		return YES;

	for (proto_list = protocol_list; proto_list; proto_list = proto_list->next)
		{
		for (i = 0; i < proto_list->count; i++)
			if ([proto_list->list[i] conformsTo: aProtocolObject])
				return YES;
		}
#endif

	return NO;
}

@end
