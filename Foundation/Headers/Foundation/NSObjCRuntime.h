/*
   NSObjCRuntime.h

   Obj-C runtime interfaces

   Copyright (C) 1995-2016 Free Software Foundation, Inc.

   Author:	Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date:	1995
   Rewrite: Felipe A. Rodriguez <far@illumenos.com>
   Date: 	October 2015

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSObjCRuntime
#define _mGSTEP_H_NSObjCRuntime

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>
#include <limits.h>
#include <errno.h>

#include "../../../Build/config.h"

#include <objc/objc.h>


#ifdef __LIBOBJC_RUNTIME_H_INCLUDED__
  #include <objc/objc-arc.h>
  #include <objc/encoding.h>

  #define __USE_LIBOBJC2__	1
  #define  NeXT_runtime     1
  #define  class_pointer    isa
  #define  sel_registerTypedName  sel_registerTypedName_np
  #define  sel_getTypeEncoding    sel_getType_np

  #include <objc/hooks.h>			// __objc_msg_forward2
  #include <Foundation/Private/class-libobjc2.h>

  typedef struct objc_category Category;

  void * objc_thread_get_data (void);
  int objc_thread_set_data (void *value);

#else
  #include <objc/thr.h>
#endif


#ifdef NEW_RUNTIME
	#include <objc/runtime.h>
	#include <objc/message.h>

	#if __GNU_LIBOBJC__ > 20100911
	  #include <Foundation/Private/struct_objc_class.h>
	#endif

	#define class_get_version      class_getVersion

	#define object_get_class       object_getClass
	#define class_get_super_class  class_getSuperclass

	#define object_get_class_name  object_getClassName
	#define class_get_class_name   class_getName
	#define class_set_version      class_setVersion

	#define class_get_instance_method  class_getInstanceMethod
	#define class_get_class_method     class_getClassMethod

	#define objc_lookup_class      objc_lookUpClass

  #ifdef __LIBOBJC_RUNTIME_H_INCLUDED__
	#define CLS_ISMETA(cls)        class_isMetaClass(cls)
	#define CLS_ISCLASS(cls)       class_isMetaClass(object_getClass(cls))

	#define sel_get_type           sel_getType_np
	#define sel_get_any_typed_uid  sel_registerTypedName_np
	#define sel_get_typed_uid      sel_registerTypedName_np
	#define sel_get_any_uid        sel_registerName
  #else
	#define __CLS_INFO(cls)              ((cls)->info)
	#define __CLS_ISINFO(cls, mask)      ((__CLS_INFO(cls) & mask) == mask)
	#define __CLS_SETINFO(cls, mask)     (__CLS_INFO(cls) |= mask)
	#define __CLS_SETNOTINFO(cls, mask)  (__CLS_INFO(cls) &= ~mask)

	/* The structure is of type MetaClass */
	#define _CLS_META 0x2L
	#define CLS_ISMETA(cls)        ((cls) && __CLS_ISINFO(cls, _CLS_META))

	/* The structure is of type Class */
	#define _CLS_CLASS 0x1L
	#define CLS_ISCLASS(cls)       ((cls) && __CLS_ISINFO(cls, _CLS_CLASS))

	#define sel_get_type           sel_getTypeEncoding
	#define sel_get_any_typed_uid  sel_getTypedSelector
	#define sel_get_typed_uid      sel_registerTypedName
	SEL sel_get_any_uid (const char *name);
  #endif

	#define sel_eq                   sel_isEqual
	#define sel_register_typed_name  sel_registerTypedName
	#define METHOD_NULL	 0

	const char *sel_get_name (SEL selector);    // old version rets null
	BOOL sel_types_match (const char* t1, const char* t2);
	BOOL object_is_instance(id object);

#else
	#include <objc/objc-api.h>
	#include <objc/objc-list.h>
	#include <objc/encoding.h>
	
	#define class_getName		  class_get_class_name
	#define sel_getTypeEncoding   sel_get_type
#endif


@class NSString;

typedef long NSInteger;
typedef unsigned long NSUInteger;		// 4 bytes (ILP32), 8 bytes (LP64)


typedef void NSZone; 

extern SEL        NSSelectorFromString(NSString *selectorName);
extern Class      NSClassFromString(NSString *className);
extern NSString * NSStringFromSelector(SEL aSelector);
extern NSString * NSStringFromClass(Class aClass);

extern void NSLog(NSString *format, ...);

extern id  _NSLogError(NSString *format, ...);

#ifndef DEBUG		//  Debug -- enable by adding -DDEBUG=1 to CFLAGS
  #define DBLog(format, args...)
#else
  #define DBLog(format, args...)   NSLog(format, ## args)
// alt: do { if (getenv("NSDebugEnabled")  NSLog(format, ## args) } while (0))
#endif
										// handle errors during object init
extern id _NSInitError(id errObject, NSString *format, ...);



#ifndef ABS
#define ABS(a)  ({typeof(a) _a = (a); _a < 0 ? -_a : _a; })
#endif

#ifndef SIGN
#define SIGN(x)  ({typeof(x) _x = (x); _x > 0 ? 1 : (_x == 0 ? 0 : -1); })
#endif

#ifndef ROUND
#define ROUND(V, A)  ({ typeof(V) __v = (V); typeof(A) __a = (A); \
					 __a * ((__v + __a - 1) / __a); })
#endif


#ifndef SEL_EQ
#define SEL_EQ(sel1, sel2)	(sel1 == sel2)
#endif

#ifndef MAX
#define MAX(a,b) ({typeof(a) _a = (a); typeof(b) _b = (b); _a > _b ? _a : _b;})
#endif

#ifndef MIN
#define MIN(a,b) ({typeof(a) _a = (a); typeof(b) _b = (b); _a < _b ? _a : _b;})
#endif


#ifndef PTR2LONG
#define PTR2LONG(P) (((char*)(P)) - (char*)0)
#endif

#ifndef PTR2INT
#define PTR2INT(P)  (((char*)(P)) - (char*)0)
#endif

#ifndef PTR2UINT
#define PTR2UINT(P) (((char*)(P)) - (char*)0)
#endif

#ifndef LONG2PTR
#define LONG2PTR(L) (((char*)0) + (L))
#endif

#ifndef INT2PTR
#define INT2PTR(X)	(((char*)0) + (X))
#endif

#ifndef UINT2PTR
#define UINT2PTR(X)	(((char*)0) + (X))
#endif

//
//	Set OBJECT to VALUE with appropriate retain and release operations.
//
#ifndef ASSIGN
#define	ASSIGN(object,value)  ({ if (object != value) { id __o = (object); \
				  				 object = [(value) retain];  [__o release]; }})
#endif

//
//	Set OBJECT to immutable copy of VALUE.
//
#ifndef SET_COPY
#define	SET_COPY(object,value)  ({ if (object != value) { id __o = (object); \
				  				 object = [(value) copy];  [__o release]; }})
#endif

//
//  Method that must be implemented by a subclass
//
#define SUBCLASS  [self subclassResponsibility: _cmd];

//
//  Method that is not implemented and should not be called
//
#define NIMP  [self notImplemented: _cmd];

//
//  Silence compiler warning about missing super dealloc
//
#ifndef NO_WARN
#define NO_WARN  return; [super dealloc]
#endif


static inline BOOL
_classIsKindOfClass(Class c, Class aClass)
{
	for (;c != Nil; c = class_get_super_class(c))
		if (c == aClass)
			return YES;

    return NO;
}

//
//  BSD limits definitions
//
#ifndef ULONG_LONG_MAX
#define ULONG_LONG_MAX	ULLONG_MAX
#endif

#ifndef LONG_LONG_MAX
#define LONG_LONG_MAX	LLONG_MAX
#endif

#ifndef LONG_LONG_MIN
#define LONG_LONG_MIN	LLONG_MIN
#endif


typedef NSInteger NSComparisonResult; enum
{
	NSOrderedAscending = -1L,
	NSOrderedSame, 
	NSOrderedDescending
};


#define NSIntegerMax	LONG_MAX
#define NSIntegerMin	LONG_MIN
#define NSUIntegerMax	ULONG_MAX

enum { NSNotFound = NSIntegerMax };

											// hook main() to init foundation
#define main(...)  main(int argc, char **argv, char **env)                    \
				{ _init_process(argc,argv,env); return hook(argc,argv,env); } \
				  int hook(__VA_ARGS__)

#endif /* _mGSTEP_H_NSObjCRuntime */
