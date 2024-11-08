/*
   NSInvocation.m

   Object rendering of an Obj-C message (action).

   Copyright (C) 1998-2018 Free Software Foundation, Inc.

   Author:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Author:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Author:  Felipe A. Rodriguez <far@illumenos.com>

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSInvocation.h>
#include <Foundation/NSException.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSData.h>

#include <ctype.h>
#include <ffi.h>

#ifdef __USE_LIBOBJC2__
  #include <objc/encoding.h>
#endif

#define MAX_STRUCT_ELEMENTS  64

#define ARGTYPES		  	 ((callframe_t *)_cframe)->argtypes
#define RTYPE		  	 	 ((callframe_t *)_cframe)->rtype
#define CLOSURE		  	 	 ((callframe_t *)_cframe)->closure
#define CIF		  	 		 &((callframe_t *)_cframe)->cif


typedef unsigned long smallret_t;

typedef struct _callframe_t {
	int nargs;
	void **args;
	ffi_closure *closure;									// ffi_closure *
	ffi_cif cif;											// ffi_cif
	ffi_type **argtypes;
	ffi_type *rtype;
	ffi_type rt;											// struct return
} callframe_t;


@interface NSInvocation  (LibFFI)

+ (IMP) _closureWithReciever:(id)reciever selector:(SEL)sel;
- (IMP) _closure;
- (void) _forward:(void **)args withReturn:(void*)ret;

@end



static void *
FFI_type(const char objc_type)
{
	switch (objc_type)
		{
		case _C_ATOM:
		case _C_CLASS:
		case _C_CHARPTR:
		case _C_PTR:
		case _C_SEL:
		case _C_ID:  		return &ffi_type_pointer;
		case _C_CHR:  		return &ffi_type_schar;
		case _C_UCHR:  		return &ffi_type_uchar;
		case _C_SHT:		return &ffi_type_sshort;
		case _C_USHT:		return &ffi_type_ushort;
		case _C_INT:  		return &ffi_type_sint;
		case _C_UINT:  		return &ffi_type_uint;
		case _C_LNG:  		return &ffi_type_slong;
		case _C_ULNG:  		return &ffi_type_ulong;
		case _C_LNG_LNG:  	return &ffi_type_sint64;
		case _C_ULNG_LNG:  	return &ffi_type_uint64;
		case _C_FLT:  		return &ffi_type_float;
		case _C_DBL:  		return &ffi_type_double;
		case _C_VOID:		return &ffi_type_void;
		case _C_STRUCT_B:	return NULL;
		case _C_UNION_B:	return NULL;
		case _C_ARY_B:		return NULL;
		default:			return (void *)-1;
		}
}

static const char *
FFI_next_type(const char *t, int *j, ffi_type *at)
{
	switch (*t)
		{
		case _C_STRUCT_B:
			{
			while (*t != _C_STRUCT_E)			// Skip "<name>=" stuff.
				if (*t++ == '=')
					break;

			if (*t != _C_STRUCT_E)
				t = FFI_next_type(t, j, at);

			while (*t != _C_STRUCT_E)
				t = FFI_next_type(t, j, at);
			t++;								// Skip end-of-struct
			}
			break;

		case _C_UNION_B:
			{
			int	max_size = 0;
			void *f = NULL;

			while (*t != _C_UNION_E)			// Skip "<name>=" stuff.
				if (*t++ == '=')
					break;

			for (; *t != _C_UNION_E && *t; t++)
				{
				int sz = objc_sizeof_type (t);

				if (sz > max_size)		// FIX ME works only with simple types
					{
					void *tf = FFI_type(*t);
					
					if (tf && tf != (void *)-1);
						f = tf;
					max_size = sz;
				}	}
			at->elements[(*j)++] = f;
			t++;								// Skip end-of-union
			}
			break;

		case _C_ARY_B:
			{
			int	length = atoi(++t);
			void *f = NULL;

			while (isdigit(*t))
				t++;
			f = FFI_type(*t++);
			while (f && length--)
				at->elements[(*j)++] = f;
			t++;								// Skip end-of-array
			}
			break;

		default:
			at->elements[(*j)++] = FFI_type(*t++);
		}

	if (*j >= MAX_STRUCT_ELEMENTS)
		[NSException raise:NSInvalidArgumentException format:@"args overflow"];

	return t;
}

static void *
FFI_struct_type(const char *type, ffi_type *at, int *count)
{
	int j = 0;

	at->size = 0;
	at->alignment = 0;
	at->type = FFI_TYPE_STRUCT;

	FFI_next_type(type, &j, at);
	if (count)
		*count = j;

	return at;
}

static callframe_t *
callframe_from_info (NSArgumentInfo *info, int nargs, void **retval)
{
	unsigned size = sizeof(callframe_t);
	unsigned align = __alignof(double);
	unsigned arg_offset = 0;
	unsigned cf_offset = 0;
	callframe_t *cframe;
	int argElements[nargs];
	unsigned ffi_args_offset = 0;
	unsigned ffi_st_offset = 0;
	unsigned ffi_st_elements_offset = 0;
	int i;

	if (nargs > 0)
		{
		unsigned st_count = 0;						// struct args count
		unsigned arg_e_total = 0;					// struct elements count

		if (size % align != 0)
			size += align - (size % align);

		cf_offset = size;							// cf 12 / 24
		size += nargs * sizeof(void*);

		if (size % align != 0)
			size += (align - (size % align));		// cf + arg ptrs array
		arg_offset = size;

		for (i = 0; i < nargs; i++)					// add arg storage
			{
			size += info[i+1].size;
		
			if (size % align != 0)
				size += (align - size % align);
			}

		ffi_args_offset = size;
		size += sizeof(void *) * (nargs + 1);		// ffi argtypes

		memset(argElements, 0, nargs * sizeof(int));
		for (i = 2; i < nargs; i++)					// count struct args
			{
			if (FFI_type(*info[i+1].type) == NULL)
				{
				ffi_type at;
				ffi_type *elements[MAX_STRUCT_ELEMENTS + 1];
				unsigned count = 0;

				at.elements = elements;
				FFI_struct_type(info[i+1].type, &at, &count);
				argElements[i] = count + 1;
				arg_e_total += count + 1;			// struct elements count
				st_count++;							// struct count
			}	}

		ffi_st_offset = size;
		size += sizeof(ffi_type) * st_count;		// + ffi structs array
		if (size % align != 0)
			size += (align - (size % align));
		ffi_st_elements_offset = size;
		size += sizeof(ffi_type *) * arg_e_total;	// + ffi struct arg elements
		}

	if (size % align != 0)
		size += (align - size % align);

	if (retval)
		{
		unsigned end;
		unsigned ffi_rt_elements_offset = 0;
		ffi_type *rtype = NULL;
		int count = 0;

		if ((rtype = FFI_type(*info[0].type)) == NULL)	// ffi return type
			{
			ffi_type at;
			ffi_type *elements[MAX_STRUCT_ELEMENTS + 1];

			at.elements = elements;
			rtype = FFI_struct_type(info[0].type, &at, &count);
			ffi_rt_elements_offset = size;
			size += sizeof(void *) * (count + 1);		// ffi return elements
			}
		if (rtype == (void *)-1)
			[NSException raise:NSGenericException format:@"bad ffi return type"];

		end = size;				// store return value at end of callframe
		size += MAX(info[0].size, sizeof(smallret_t));

		if ((cframe = calloc(size, 1)))
			*retval = (void*)cframe + end;

		if ((cframe->rtype = FFI_type(*info[0].type)) == NULL)
			{
			cframe->rt.elements = (void*)cframe + ffi_rt_elements_offset;
			cframe->rtype = FFI_struct_type(info[0].type, &cframe->rt, NULL);
		}	}
	else
		cframe = calloc(size, 1);

	if (cframe)								// ffi type arrays are implicitly
		{									// NULL terminated by calloc()
		int j = 0;

		cframe->nargs = nargs;
		cframe->args = (void*)cframe + cf_offset;
		cframe->argtypes = (void*)cframe + ffi_args_offset;

		cframe->argtypes[0] = &ffi_type_pointer;		// target
		cframe->argtypes[1] = &ffi_type_pointer;		// selector

		for (i = 2; i < nargs; i++)						// ffi arg types
			{
			if ((cframe->argtypes[i] = FFI_type(*info[i+1].type)) == NULL)
				{
				ffi_type *at = (void*)cframe + ffi_st_offset + (sizeof(ffi_type) * j++);

				at->elements = (void*)cframe + ffi_st_elements_offset + (sizeof(ffi_type *) * argElements[i-1]);
				cframe->argtypes[i] = FFI_struct_type(info[i+1].type, at, NULL);
			}	}

		for (i = 0; i < nargs; i++)
			{
			cframe->args[i] = (void*)cframe + arg_offset;

			arg_offset += info[i+1].size;

			if (arg_offset % align != 0)
				arg_offset += (align - arg_offset % align);
		}	}

	return cframe;
}

static void
callframe_set_arg(callframe_t *cframe, int index, void *buffer, int size)
{
	if (index >= 0 && index < cframe->nargs)
		memcpy(cframe->args[index], buffer, size);
}

static void
callframe_get_arg(callframe_t *cframe, int index, void *buffer, int size)
{
	if (index >= 0 && index < cframe->nargs)
		memcpy(buffer, cframe->args[index], size);
}

static void *
callframe_arg_addr(callframe_t *cframe, int index)
{
	return (index < 0 || index >= cframe->nargs) ? NULL : cframe->args[index];
}


@implementation NSInvocation

+ (NSInvocation*) invocationWithMethodSignature:(NSMethodSignature*)aSignature
{
	NSInvocation *inv = [NSInvocation alloc];

	inv->_sig = [aSignature retain];
	inv->_numArgs = [aSignature numberOfArguments];
	inv->_info = [aSignature methodInfo];

	return [inv autorelease];
}

- (void) setArgument:(void*)buffer atIndex:(int)index
{
	if ((unsigned)index >= _numArgs)
		[NSException raise:NSInvalidArgumentException format:@"bad arg index"];

	if (index == 0)
		[self setTarget: *(id*)buffer];
	else if (index == 1)
		[self setSelector: *(SEL*)buffer];
	else
		{
		int i = index+1;				// Allow for return type in 'info'
		const char *type = _info[i].type;

		if (!_cframe)
			_cframe = callframe_from_info(_info, _numArgs, &_retval);

		if (_vf.retainArgs && (*type == _C_ID || *type == _C_CHARPTR))
			{
			if (*type == _C_ID)
				{
				id old;

				callframe_get_arg(_cframe, index, &old, sizeof(id));
				callframe_set_arg(_cframe, index, &buffer, sizeof(id));
				[*(id*)buffer retain];
				if (old != nil)
					[old release];
				}
			else
				{
				char *oldstr;
				char *newstr = *(char**)buffer;
	
				callframe_get_arg(_cframe, index, &oldstr, _info[i].size);
				if (newstr == 0)
					callframe_set_arg(_cframe, index, buffer, 0);
				else
					{
					char *tmp = malloc(strlen(newstr)+1);
	
					strcpy(tmp, newstr);
					callframe_set_arg(_cframe, index, tmp, _info[i].size);
					}
				if (oldstr != 0)
					free(oldstr);
			}	}
		else
			callframe_set_arg(_cframe, index, buffer, _info[i].size);
		}
}

- (void) getArgument:(void*)buffer atIndex:(int)index
{
	if ((unsigned)index >= _numArgs)
		[NSException raise:NSInvalidArgumentException format:@"bad arg index"];

	if (index == 0)
		*(id*)buffer = _target;
	else if (index == 1)
		*(SEL*)buffer = _selector;
	else
		{
		index++;					// Allow offset for return type info
		callframe_get_arg(_cframe, index-1, buffer, _info[index].size);
		}		
}

- (void) dealloc
{
	if (_vf.retainArgs)
		{
		[_target release];

		if (_cframe && _sig)
			{
			int i;

			for (i = 3; i <= _numArgs; i++)
				{
				if (*_info[i].type == _C_CHARPTR)
					{
					char *str;

					callframe_get_arg(_cframe, i-1, &str, _info[i].size);
					free(str);
					}
				else if (*_info[i].type == _C_ID)
					{
					id obj;
		
					callframe_get_arg(_cframe, i-1, &obj, sizeof(id));
					[obj release];
		}	}	}	}

	if (CLOSURE)
		ffi_closure_free (CLOSURE), 	CLOSURE = NULL;
	if (_cframe)
		free(_cframe);

	[_sig release];

	[super dealloc];
}

- (void) getReturnValue:(void*)buffer
{
	const char *type;

	if (_vf.returnIsValid == NO)
		[NSException raise: NSGenericException format: @"no return value"];

	type = [_sig methodReturnType];

	if (*_info[0].type != _C_VOID)
		{
		int length = _info[0].size;
#if WORDS_BIGENDIAN
		if (length < sizeof(void*))
			length = sizeof(void*);
#endif
		memcpy(buffer, _retval, length);
		}
}

- (void) setReturnValue:(void*)buffer
{
	const char *type = _info[0].type;

	if (*type != _C_VOID)
		{
		int length = _info[0].size;

#if WORDS_BIGENDIAN
		if (length < sizeof(void*))
			length = sizeof(void*);
#endif
		memcpy(_retval, buffer, length);
		}
	_vf.returnIsValid = YES;
}

- (void) setTarget:(id)anObject
{
	if (_vf.retainArgs)
		ASSIGN(_target, anObject);
	else
		_target = anObject;
}

- (id) target								{ return _target ; }
- (SEL) selector							{ return _selector ; }
- (void) setSelector:(SEL)aSelector			{ _selector = aSelector; }
- (NSMethodSignature *) methodSignature		{ return _sig; }
- (BOOL) argumentsRetained					{ return _vf.retainArgs; }

- (void) retainArguments
{
	if (!_vf.retainArgs)
		{
		int	i;
	
		_vf.retainArgs = YES;
		[_target retain];

		if (_cframe == 0)
			return;

		for (i = 3; i <= _numArgs; i++)
			{
			if (*_info[i].type == _C_ID || *_info[i].type == _C_CHARPTR)
				{
				if (*_info[i].type == _C_ID)
					{
					id old;
	
					callframe_get_arg(_cframe, i-1, &old, sizeof(id));
					if (old != nil)
						[old retain];
					}
				else
					{
					char *str;
	
					callframe_get_arg(_cframe, i-1, &str, _info[i].size);
					if (str != 0)
						{
						char *tmp = malloc(strlen(str)+1);
	
						strcpy(tmp, str);
						callframe_set_arg(_cframe, i-1, tmp, strlen(tmp)+1);
		}	}	}	}	}
}

- (void) invoke							{ [self invokeWithTarget:_target]; }

- (void) invokeWithTarget:(id)anObject
{
	IMP imp;
	struct objc_class *target;
	void *avalues[_numArgs+1];
	int i = 0;

	NSAssert(_selector != 0, @"selector must be set before invoking");

	if (!_info)
		[NSException raise:NSInvalidArgumentException format:@"no arg info"];

	if (_info[0].size && _retval)			// clear return value
		memset(_retval, 0, _info[0].size);

	if (anObject == nil)					// message to nil object returns nil
		return;

	if (anObject != _target)
		[self setTarget: anObject];

#ifdef NEW_RUNTIME

	target = object_getClass(_target);
	imp = class_getMethodImplementation(target, _selector);

#else

	target = ((struct objc_class *)_target)->class_pointer;
	imp = method_get_imp(object_is_instance(_target)
			? class_get_instance_method(target, _selector)
			: class_get_class_method(target, _selector));
#endif
											// If fast lookup failed, we may be 
	if (imp == 0)							// forwarding or something ...
		imp = objc_msg_lookup(_target, _selector);
	NSCParameterAssert (imp);

	if (!_cframe)
		_cframe = callframe_from_info(_info, _numArgs, &_retval);

	avalues[i++] = &_target;				// set target and selector
	avalues[i++] = (void *)_selector;

	for (i = 2; i < _numArgs; i++)			// get remaining arguments
		avalues[i] = callframe_arg_addr((callframe_t *)_cframe, i);
	avalues[i] = NULL;
											// init and call the cif
	if (_vf.forwarding || ffi_prep_cif(CIF, FFI_DEFAULT_ABI, _numArgs, RTYPE, ARGTYPES) == FFI_OK)
		ffi_call(CIF, (void *)imp, _retval, avalues);
	else
		[NSException raise:NSGenericException format:@"bad cif prep"];

	_vf.returnIsValid = YES;
}

- (NSString*) description
{
	const char *n = object_get_class_name(self);
	const char *s = _selector ? [NSStringFromSelector(_selector) cString] : "nil";
	const char *t = _target ? [NSStringFromClass([_target class]) cString] : "nil";
	char buffer[1024];				// Don't use -[NSString stringWithFormat:]
									// because it can cause an endless loop
	sprintf (buffer, "<%s %p selector: %s target: %s>", n, self, s, t);

	return [NSString stringWithCString:buffer];
}

- (void) encodeWithCoder:(NSCoder*)aCoder
{
	const char *types = [_sig methodType];
	BOOL out_parameters = NO;
	int i;

	[aCoder encodeObject:_target];
	[aCoder encodeValueOfObjCType:@encode(SEL) at:&_selector];
	[aCoder encodeValueOfObjCType:@encode(unsigned int) at:&_vf];

	for (i = 3; i <= _numArgs; i++)
		{
		const char *type = _info[i].type;
		unsigned flags = _info[i].qual;
		void *datum = callframe_arg_addr(_cframe, i-1);

		switch (*type)
			{
			case _C_ID:
				[aCoder encodeValueOfObjCType:type at:datum];
				break;

			case _C_PTR:	// If the pointer's value is qualified as an OUT
				if ((flags & _F_OUT) || !(flags & _F_IN))
					out_parameters = YES;
				type++;		// Increment TYPE to see what this is a pointer to.
							// If the pointer's value is qualified as an IN
							// parameter or not explicity qualified as an OUT
							// parameter, then encode it.
				if (_vf.returnIsValid || (flags & _F_IN) || !(flags & _F_OUT) || out_parameters)
					[aCoder encodeValueOfObjCType:type at: *(void**)datum];
				break;

			case _C_CHARPTR:							// Handle a (char*) arg
				if ((flags & _F_OUT) || !(flags & _F_IN))
					out_parameters = YES;
						// If the char* is qualified as an IN parameter or not
						// explicity qualified as an OUT param, then encode it.
				if (_vf.returnIsValid || (flags & _F_IN) || !(flags & _F_OUT))
					[aCoder encodeValueOfObjCType:type at:datum];
				break;

			case _C_STRUCT_B:			// Handle struct and array arguments.
			case _C_UNION_B:
			case _C_ARY_B:	// Whether DATUM points to the data, or points to a 
							// pointer that points to the data, depends on the 
							// value of MFRAME_STRUCT_BYREF. Do the right thing
#if MFRAME_STRUCT_BYREF		// so that ENCODER gets a ptr directly to the data.
				[aCoder encodeValueOfObjCType:type at: *(void**)datum];
				break;
#endif
			default:					// Handle arguments of all other types.
				[aCoder encodeValueOfObjCType:type at:datum];
				break;
			}
		}

	if (*_info[0].type != _C_VOID && _vf.returnIsValid)
		{
		if (*_info[0].type == _C_PTR )
			[aCoder encodeValueOfObjCType:_info[0].type+1 at:*(void**)_retval];
		else
			[aCoder encodeValueOfObjCType:_info[0].type at:_retval];
		}
}

- (id) initWithCoder:(NSCoder*)aCoder
{
	BOOL out_parameters = NO;
	NSMethodSignature *sig;
	const char *type;
	int i;

	[aCoder decodeValueOfObjCType:@encode(id) at:&_target];
	[aCoder decodeValueOfObjCType:@encode(SEL) at:&_selector];
	[aCoder decodeValueOfObjCType:@encode(unsigned int) at:&_vf];

    type = sel_get_type(_selector);

    if (type == 0 || *type == '\0') 
		{
		type = [[self methodSignatureForSelector: _selector] methodType];

#ifdef NEW_RUNTIME
		sel_registerTypedName(sel_getName(_selector), type);
#else
		if (type) 
			sel_register_typed_name(sel_get_name(_selector), type);
#endif
		}

	if (!_sig)
		{
		sig = [[NSMethodSignature signatureWithObjCTypes:type] retain];
		_numArgs = [sig numberOfArguments];
		_info = [sig methodInfo];
		}

	if (!_cframe)
		_cframe = callframe_from_info(_info, _numArgs, &_retval);

	for (i = 3; i <= _numArgs; i++)
		{
		const char *type = _info[i].type;
		unsigned flags = _info[i].qual;
		void *datum = callframe_arg_addr(_cframe, i-1);

		switch (*type)
			{
			case _C_ID:
				[aCoder decodeValueOfObjCType: type  at: datum];
				break;

			case _C_PTR:	// Is the pointer's value qualified as an OUT ?
				if ((flags & _F_OUT) || !(flags & _F_IN))
					out_parameters = YES;
				type++;		// Increment TYPE to see what this is a pointer to.
							// If the pointer's value is qualified as an IN 
							// parameter or not explicity qualified as an OUT
							// parameter, then encode it.

							// Memory to be pointed to is allocated on the
							// stack, methods that want to keep the data it
							// points to will have to make their own copies.
				if (!out_parameters || *(void**)datum == NULL)
					*(void**)datum = alloca(objc_sizeof_type (type));
				if (_vf.returnIsValid || (flags & _F_IN) || !(flags & _F_OUT) 		|| out_parameters)
					[aCoder decodeValueOfObjCType:type at: *(void**)datum];
				break;

			case _C_CHARPTR:							// Handle a (char*) arg
				if ((flags & _F_OUT) || !(flags & _F_IN))
					out_parameters = YES;
						// If the char* is qualified as an IN parameter or not
						// explicity qualified as an OUT param, then encode it.
				if (_vf.returnIsValid || (flags & _F_IN) || !(flags & _F_OUT))
					[aCoder decodeValueOfObjCType:type at:datum];
				break;

			case _C_STRUCT_B:			// Handle struct and array arguments.
			case _C_UNION_B:
			case _C_ARY_B:	// Whether DATUM points to the data or points to a
							// pointer that points to the data depends on the
							// value of MFRAME_STRUCT_BYREF. Do the right thing
							// so that ENCODER gets a ptr directly to the data.
#if MFRAME_STRUCT_BYREF
				[aCoder decodeValueOfObjCType:type at: *(void**)datum];
				break;
#endif
			default:					// Handle arguments of all other types.
				[aCoder decodeValueOfObjCType:type at:datum];
				break;
			}
		}

	if (*_info[0].type != _C_VOID && _vf.returnIsValid)
		{
		if (*_info[0].type == _C_PTR )
			{
			const char *type = _info[0].type;
			char *ret;

			type++;
			ret = alloca (objc_sizeof_type (type));
			[aCoder decodeValueOfObjCType:type at:ret];
			*(void**)_retval = ret;
			}
		else
			[aCoder decodeValueOfObjCType:_info[0].type at:_retval];
		}

	return self;
}

@end  /* NSInvocation */

#ifndef DISABLE_DO

/* mframe_do_call()

   Decode the arguments of a method call from a byte stream, build an
   NSInvocation object from the decoded data and invoke it; then encode
   the return value and any pass-by-reference arguments.

   ENCODED_TYPES  A string that describes the return value and arguments.
                  It's argument types and argument type qualifiers should match
                  exactly those that were used when the arguments were encoded.

   DECODER  pointer to a function that obtains the method's argument values.

   void my_decoder (int argnum, void *data, const char *type)

     ARGNUM  argument index, beginning at 0.
     DATA    pointer to the memory where the value should be placed.
     TYPE    pointer to the type string of this value.

     If DECODER malloc's new memory while doing its work then DECODER is 
	 responsible for making sure the memory gets freed. For example, if 
	 DECODER uses -decodeValueOfCType:at:withName: to decode a char* string 
	 this method malloc's new memory to hold the string and DECODER should 
	 autorelease the malloc'ed pointer using the NSData class.

   ENCODER  pointer to a function that records the method's return value and 
            pass-by-reference values.

   void my_encoder (int argnum, void *data, const char *type, int flags)

     ARGNUM  argument index for pass-by-reference values; -1 for return value.
     DATA    pointer to the memory where the value can be found.
     TYPE    pointer to the type string of this value.
     FLAGS   type qualifier flags for this argument; (see <objc/objc-api.h>).

   PASS_POINTERS  flag indicating whether pointers should be passed as
                  pointers (for local stuff) or should be assumed to point
                  to a single data item (for distributed objects).
*/

typedef struct _NSInvocation_t { @defs(NSInvocation); } NSInvocation_t;


void
mframe_do_call (const char *encoded_types,
				void(*decoder)(int, void*, const char*),
				void(*encoder)(int, const void*, const char*, int))
{
	NSMethodSignature *sig;
	NSInvocation_t *inv;
	const char *type;		// method type string obtained from the target's
							// OBJC_METHOD struct for the selector we're sending.
	void *retval;
	const char *t;			// pointer into the local variable TYPE string.
	const char *e;			// pointer into the argument ENCODED_TYPES string.

	id object;				// target object that will receive the message.
	SEL selector;			// selector for message we're sending to the TARGET.

	int i = 2;				// ARGNUM. argument number being processed

	BOOL out_parameters = NO;	// have arguments that are passed by reference ?
								// encode them, since they may change.
	BOOL pass_pointers = NO; // pass pointers rather than using the DO behaviour
							 // which is to copy a single obj when given a ptr.
	unsigned int instate;
	callframe_t *cframe;	// call arg frame information for calling the method
	NSUInteger numArgs;
							// Decode target object, always first arg to method
	(*decoder) (0, &object, @encode(id));
	NSCParameterAssert (object);
							// Decode the selector, always second arg to method
	(*decoder) (1, &selector, ":");
	NSCParameterAssert (selector);

	(*decoder) (0, &instate, @encode(unsigned int));
							// Get the "selector type" for this method.
#if !defined(NEW_RUNTIME) && !defined(NeXT_runtime)
	type = sel_get_type (selector);
#else
	{
 #if NeXT_runtime
    Method m = class_getInstanceMethod(object->isa, selector);
 #else
    Method m = class_getInstanceMethod(object->class_pointer, selector);
 #endif /* NeXT_runtime */

	if (!m) 
		abort();

	type = method_getTypeEncoding (m);
	}
#endif					// Make sure we successfully got the method type, and
						// that its types match the ENCODED_TYPES.
	NSCParameterAssert (type);
	NSCParameterAssert (sel_types_match(encoded_types, type));
						// Build the call frame
	sig = [NSMethodSignature signatureWithObjCTypes: type];
	numArgs = [sig numberOfArguments];
	cframe = callframe_from_info([sig methodInfo], numArgs,  &retval);

	t = objc_skip_argspec (type);				// init our tmp pointers into
	e = objc_skip_argspec (encoded_types);		// the method type strings.
	NSCParameterAssert (*t == _C_ID);
	callframe_set_arg(cframe, 0, &object, sizeof(id));			// target obj

	t = objc_skip_argspec(t);
	e = objc_skip_argspec(e);
	NSCParameterAssert (*t == _C_SEL);
	callframe_set_arg(cframe, 1, &selector, sizeof(SEL));		// selector

	t = objc_skip_argspec(t);		// Decode args after OBJECT and SELECTOR
	e = objc_skip_argspec(e);
	for (; *t != '\0'; t = objc_skip_argspec(t), e = objc_skip_argspec(e), i++)
		{					// Get type qualifiers, like IN, OUT, INOUT, ONEWAY
							// Type qualifier flags; see <objc/objc-api.h>
		unsigned flags = objc_get_type_qualifiers (e);
		char *datum = callframe_arg_addr(cframe, i);
							// Skip over type qualifiers, so now TYPE is
							// pointing directly at the char corresponding to 
							// the arg's type, as defined in <objc/objc-api.h>
		t = objc_skip_type_qualifiers(t);
							// Decode argument based on its FLAGS and TMPTYPE.
							// Only the first two cases involve parameters that 
							// may be passed by reference, and thus change
							// OUT_PARAMETERS.  *** Note: This logic must match
		switch (*t)			// exactly the code in mframe_dissect_call(); that
			{				// function should encode exactly what we decode.
			case _C_CHARPTR:
							// If the char* is qualified as an OUT parameter
							// or if it not explicitly qualified as an IN 
							// parameter, then we will have to get this char* 
							// again after the method is run, because the 
							// method may have changed it.  Set OUT_PARAMETERS 
				if ((flags & _F_OUT) || !(flags & _F_IN))
					out_parameters = YES;
							// If the char* is qualified as an IN parameter or
							// not explicity qualified as an OUT parameter, 
							// then decode it. Note: decoder allocates memory 
							// for holding string, and it is also responsible 
							// for making sure that the memory gets freed 
							// eventually, (e,g, autorelease of NSData object).
				if ((flags & _F_IN) || !(flags & _F_OUT))
					(*decoder) (i, datum, t);
				break;		// If the pointer's value is qualified as an OUT
							// parameter or if it not explicitly qualified as
			case _C_PTR:	// an IN parameter, then we will have to get the
							// value pointed to again after the method is run,
							// because the method may have changed it.  Set 
							// OUT_PARAMETERS accordingly.
				if ((flags & _F_OUT) || !(flags & _F_IN))
					out_parameters = YES;
				if (pass_pointers)
					{
					if ((flags & _F_IN) || !(flags & _F_OUT))
						(*decoder) (i, datum, t);
					}		// Handle an arg that is a pointer to a non-char *
				else		// But (void*) and (anything**) is not allowed.
					{		// argument is a pointer to something; increment
							// TYPE so we can see what it is a pointer to.
					t++;
							// Memory to be pointed to is allocated on the
							// stack, methods that want to keep the data
							// pointed to will have to make their own copies.
					*(void**)datum = alloca (objc_sizeof_type (t));
							// If the pointer's value is qualified as an IN 
							// parameter, or not explicity qualified as an OUT 
							// parameter, then decode it.
					if ((flags & _F_IN) || !(flags & _F_OUT)		|| out_parameters)
						(*decoder) (i, *(void**)datum, t);
					}
				break;
	
			case _C_STRUCT_B:					// Handle struct and array args
			case _C_UNION_B:					
			case _C_ARY_B:	// Whether DATUM points to the data, or points to a 
							// pointer that points to the data, depends on the 
							// value of MFRAME_STRUCT_BYREF.  Do the right 
							// thing so that ENCODER gets a ptr to the data
#if MFRAME_STRUCT_BYREF
							// Allocate some memory to be pointed to, and to 
							// hold the data.  Note that it is allocated on the 
							// stack, and methods that want to keep the data 
							// pointed to, will have to make their own copies.
				*(void**)datum = alloca (objc_sizeof_type(t));
				(*decoder) (i, *(void**)datum, t);
#else
				(*decoder) (i, datum, t);
#endif
				break;	// NOTE FOR OBJECTS: Unlike [Decoder decodeObjectAt:...,
						// this function does not generate a reference to the
			default:	// object; the object may be autoreleased; -retain it if
						// the method wants to keep a reference to the object.
				(*decoder) (i, datum, t);		// Handle all other types
			}
		}
	(*decoder) (-1, 0, 0);

	inv = (NSInvocation_t *)NSAllocateObject([NSInvocation class]);
	inv->_retval = retval;
	inv->_selector = selector;
	inv->_cframe = cframe;
	inv->_info = [sig methodInfo];
	inv->_numArgs = numArgs;
	inv->_target = object;

	[(NSInvocation *)inv invokeWithTarget:object];
	
	inv->_vf.returnIsValid = YES;

	(*encoder) (-1, encoded_types, @encode(char*), 0);
	(*encoder) (-1, (NSInvocation *)inv, @encode(id), 0);

	NSDeallocateObject((NSInvocation *)inv);

	free(cframe);
}

#endif  /* DISABLE_DO */

/* ****************************************************************************

	LibFFI closure based forwarding

** ***************************************************************************/

static void
__closureCallback(ffi_cif *cif, void *ret, void **args, void *user)
{
	[(NSInvocation *)user _forward:args withReturn:ret];
}

IMP
__objcMessageForwarding(id receiver, SEL sel)
{
	return [NSInvocation _closureWithReciever:receiver selector:sel];
}


@implementation NSInvocation  (LibFFI)

+ (IMP) _closureWithReciever:(id)reciever selector:(SEL)sel
{
	const char *types = sel_get_type (sel);
	NSMethodSignature *sig;
	NSInvocation *inv = nil;

	if (types && (sig = [NSMethodSignature signatureWithObjCTypes:types]))
		{
		inv = [NSInvocation invocationWithMethodSignature: sig];
		inv->_target = [reciever retain];
		inv->_selector = sel;
		}

	return [(NSInvocation *)inv _closure];
}

- (IMP) _closure
{
	IMP imp;

	if (!_cframe)
		_cframe = callframe_from_info(_info, _numArgs, &_retval);

	if ((CLOSURE = ffi_closure_alloc(sizeof(ffi_closure), (void **)&imp)))
		if (ffi_prep_cif(CIF, FFI_DEFAULT_ABI, _numArgs, RTYPE, ARGTYPES) != FFI_OK)
			[NSException raise:NSGenericException format:@"bad cif prep"];

	if (ffi_prep_closure_loc(CLOSURE, CIF, __closureCallback, self, imp) != FFI_OK)
		return NULL;

	_vf.forwarding = YES;							// cif is prep'd

	return imp;
}

- (void) _forward:(void **)args withReturn:(void*)ret
{
	int i;
													// target and selector
	memcpy(&(((callframe_t *)_cframe)->args)[0], args, 2 * sizeof(*args));

	for (i = 2; i < _numArgs; i++)					// set remaining arguments
		[self setArgument:args[i] atIndex:i];
	_retval = ret;

	[_target forwardInvocation: self];
}

@end
