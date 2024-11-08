/*
   NSMethodSignature.m

   Obj-C method signature processing

   Copyright (C) 1994, 1995, 1996, 1998 Free Software Foundation, Inc.

   Author:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date:	August 1994
   Rewrite:	Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date:	August 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSMethodSignature.h>
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>

#include <ctype.h>


/* ****************************************************************************

  Deprecated MFRAME macros:
	
  MFRAME_ARGS
	This macro should define a data type to be used for recording
	information about the arguments list of a method.
	See 'CUMULATIVE_ARGS' in the configuration file for your system
	in gcc for a parallel example.

	#define MFRAME_ARGS int
		-- or --
	typedef struct rs6000_args
	{
	  int int_args;         // Number of integer arguments so far.
	  int float_args;       // Number of FP arguments so far.
	  int regs_position;    // The current position for non-FP args.
	  int stack_position;   // The current position in the stack frame.
	} MFRAME_ARGS;

  MFRAME_INIT_ARGS(CUM, RTYPE)
	This macro is used to initialise a variable (CUM) of the type
	defined by MFRAME_ARGS.  The RTYPE value is the type encoding for the
	method return type, it is needed so that CUM can take int account any
	invisible first argument used for returning structures by value.
	See 'INIT_CUMULATIVE_ARGS' in the configuration file for your system
	in gcc for a parallel example.

  MFRAME_ARG_ENCODING(CUM,TYPES,STACK,DEST)
	This macro is used to to determine the encoding of arguments.
	You will have to write this macro for your system by examining the
	gcc source code to determine how the compiler does this on your
	system - look for the usage of CUMULATIVE_ARGS an INIT_CUMULATIVE_ARGS
	in the configuration files for your hardware and operating system in
	the gcc (or egcs) source, and make your macro mirror it's operation.

	Before initial entry,
	  CUM should have been initialised using the MFRAME_INIT_ARGS() macro,
	  TYPES should be a (const char*) variable initialised to a
	    type-encoding string listing the arguments of a function/method,
	  STACK should be an integer variable of value 0 in which the size of
	    the stack arguments will be accumulated,
	  DEST should be a (char*) variable initialised to a pointer to a
	    buffer into which the full type encoding will be written.
	After each use of the macro, TYPES is advanced to point to the next
	argument, and DEST is advanced to point after the encoding of the
	previous argument.
	Of course, you must ensure that the buffer pointed to by DEST is
	large enough so that it does not overflow!
	You will be safe if your buffer is at least ten times as big as
	the type-encoding string you start from.

** ***************************************************************************/

static char *
mframe_build_signature(const char *typePtr, int *size, int *narg, char *buf)
{
	int	cum;							// MFRAME_ARGS
	BOOL doMalloc = NO;
	const char *types;
	char *start;
	char *dest;
	int total = 0;
	int count = 0;

	if (buf == 0)		// If we have not been given a buffer, alloc space on
		{				// the stack for the largest concievable type encoding.
		doMalloc = YES;
		buf = alloca((strlen(typePtr)+1)*16);
		}
										// Copy the return type info (including 
	types = objc_skip_typespec(typePtr);// qualifiers) into the buffer
	strncpy(buf, typePtr, types - typePtr);
	buf[types-typePtr] = '\0';			// Point to the return type, initialise
										// size of stack args, and skip to the 
										// first argument.
	types = objc_skip_type_qualifiers(typePtr);
	cum = (*types == _C_STRUCT_B || *types == _C_UNION_B || *types == _C_ARY_B)
		? sizeof(void*) : 0;			// MFRAME_INIT_ARGS(cum, types);
	types = objc_skip_typespec(types);
	if (*types == '+')
		types++;

	while (isdigit(*types))
		types++;						// Where to start putting encoding info
										// Leave enough room for the size of 
	start = &buf[strlen(buf)+10];		// the stack args to be stored after
	dest = start;						// the return type.

	while (types && *types)				// Now step through all the arguments. 
		{								// Copy any type qualifiers, but let 
		const char *qual = types;		// the macro write all the other info 
										// into the buffer.
		types = objc_skip_type_qualifiers(types);
		while (qual < types)			// If there are any type qualifiers, 
			*dest++ = *qual++;			// copy the through to the destination.

		  {		// MFRAME_ARG_ENCODING(cum, types, total, dest);
			const char *type = types;
			int align = objc_alignof_type(type);
			int size = objc_sizeof_type(type);

			cum = ROUND(cum, align);
			types = objc_skip_typespec(type);
			sprintf(dest, "%.*s%d", types - type, type, cum);

			if (*types == '+')
				types++;

			while (isdigit(*types))
				types++;

			dest = &dest[strlen(dest)];
			if ((*type == _C_STRUCT_B || *type == _C_UNION_B || *type == _C_ARY_B) && size > 2)
				total = cum + ROUND(size, align);
			else
				total = cum + size;
			cum += ROUND(size, sizeof(void*));
		  }
		count++;						// Write the total size of the stack
		}								// arguments after the return type,
	*dest = '\0';						// then copy the remaining type info to
										// fill the gap.
	sprintf(&buf[strlen(buf)], "%d", total);
	dest = &buf[strlen(buf)];
	while (*start)
		*dest++ = *start++;
	*dest = '\0';
										// If we have written into a local 
	if (doMalloc)						// buffer, we need to allocate memory
		{								// in which to return our result.
		char *tmp = malloc(dest - buf + 1);

		strcpy(tmp, buf);
		buf = tmp;
		}
										// If the caller wants to know the 
	if (size)							// total size of the stack and/or the
		*size = total;					// number of arguments, return them in
										// the appropriate variables.
	if (narg)
		*narg = count;

	return buf;
}

static const char *
mframe_next_arg(const char *typePtr, NSArgumentInfo *info)
{	
	NSArgumentInfo local;				// Step through method encoding 
	BOOL flag;							// information extracting details.

	if (info == 0)
		info = &local;
										// Skip past any type qualifiers,  
	flag = YES;							// return them if caller wants them
	info->qual = 0;
	while (flag)
		{
		switch (*typePtr)
			{
			case _C_CONST:  info->qual |= _F_CONST; break;
			case _C_IN:     info->qual |= _F_IN; break;
			case _C_INOUT:  info->qual |= _F_INOUT; break;
			case _C_OUT:    info->qual |= _F_OUT; break;
			case _C_BYCOPY: info->qual |= _F_BYCOPY; break;
#ifdef _C_BYREF
			case _C_BYREF:  info->qual |= _F_BYREF; break;
#endif
			case _C_ONEWAY: info->qual |= _F_ONEWAY; break;
			default: flag = NO;
			}
		if (flag)
			typePtr++;
		}

	info->type = typePtr;

	switch (*typePtr++)				// Scan for size and alignment information.
		{
		case _C_ID:
			info->size = sizeof(id);
			info->align = __alignof__(id);
			break;

		case _C_CLASS:
			info->size = sizeof(Class);
			info->align = __alignof__(Class);
			break;

		case _C_SEL:
			info->size = sizeof(SEL);
			info->align = __alignof__(SEL);
			break;

		case _C_CHR:
			info->size = sizeof(char);
			info->align = __alignof__(char);
			break;

		case _C_UCHR:
			info->size = sizeof(unsigned char);
			info->align = __alignof__(unsigned char);
			break;

		case _C_SHT:
			info->size = sizeof(short);
			info->align = __alignof__(short);
			break;

		case _C_USHT:
			info->size = sizeof(unsigned short);
			info->align = __alignof__(unsigned short);
			break;

		case _C_INT:
			info->size = sizeof(int);
			info->align = __alignof__(int);
			break;

		case _C_UINT:
			info->size = sizeof(unsigned int);
			info->align = __alignof__(unsigned int);
			break;

		case _C_LNG:
			info->size = sizeof(long);
			info->align = __alignof__(long);
			break;

		case _C_ULNG:
			info->size = sizeof(unsigned long);
			info->align = __alignof__(unsigned long);
			break;

		case _C_LNG_LNG:
			info->size = sizeof(long long);
			info->align = __alignof__(long long);
			break;

		case _C_ULNG_LNG:
			info->size = sizeof(unsigned long long);
			info->align = __alignof__(unsigned long long);
			break;

		case _C_FLT:
			info->size = sizeof(float);
			info->align = __alignof__(float);
			break;

		case _C_DBL:
			info->size = sizeof(double);
			info->align = __alignof__(double);
			break;

		case _C_PTR:
			info->size = sizeof(char*);
			info->align = __alignof__(char*);
			if (*typePtr == '?')
				typePtr++;
			else
				{
				typePtr = mframe_next_arg(typePtr, &local);
				info->isReg = local.isReg;
				info->offset = local.offset;
				}
			break;

		case _C_ATOM:
		case _C_CHARPTR:
			info->size = sizeof(char*);
			info->align = __alignof__(char*);
			break;
		
		case _C_ARY_B:
			{
			int	length = atoi(typePtr);
		
			while (isdigit(*typePtr))
				typePtr++;

			typePtr = mframe_next_arg(typePtr, &local);
			info->size = length * ROUND(local.size, local.align);
			info->align = local.align;
			typePtr++;								// Skip end-of-array
			}
			break; 
		
		case _C_STRUCT_B:
			{
//			struct { int x; double y; } fooalign;
			struct { unsigned char x; } fooalign;
			int acc_size = 0;
			int acc_align = __alignof__(fooalign);

			while (*typePtr != _C_STRUCT_E)			// Skip "<name>=" stuff.
				if (*typePtr++ == '=')
					break;
													// Base structure alignment 
			if (*typePtr != _C_STRUCT_E)			// on first element.
				{
				typePtr = mframe_next_arg(typePtr, &local);
				if (typePtr == 0)
					return 0;						// error

				acc_size = ROUND(acc_size, local.align);
				acc_size += local.size;
				acc_align = MAX(local.align, __alignof__(fooalign));
				}
													// Continue accumulating 
			while (*typePtr != _C_STRUCT_E)			// structure size.
				{
				typePtr = mframe_next_arg(typePtr, &local);
				if (typePtr == 0)
					return 0;						// error

				acc_size = ROUND(acc_size, local.align);
				acc_size += local.size;
				}
			info->size = acc_size;
			info->align = acc_align;
//printf("_C_STRUCT_B  size %d align %d\n",info->size,info->align);
			typePtr++;								// Skip end-of-struct
			}
			break;

		case _C_UNION_B:
			{
			int	max_size = 0;
			int	max_align = 0;

			while (*typePtr != _C_UNION_E)			// Skip "<name>=" stuff.
				if (*typePtr++ == '=')
					break;

			while (*typePtr != _C_UNION_E)
				{
				typePtr = mframe_next_arg(typePtr, &local);
				if (typePtr == 0)
					return 0;						// error
				max_size = MAX(max_size, local.size);
				max_align = MAX(max_align, local.align);
				}
			info->size = max_size;
			info->align = max_align;
			typePtr++;								// Skip end-of-union
			}
			break;
		
		case _C_VOID:
			info->size = 0;
			info->align = __alignof__(char*);
			break;
		
		default:
			return 0;
		}

	if (typePtr == 0)
		return 0;									// error
						// If we had a pointer argument, we will already have 
						// gathered (and skipped past) the argframe offset 
						// info - so we don't need to (and can't) do it here.
	if (info->type[0] != _C_PTR || info->type[1] == '?')
		{
		if (*typePtr == '+')					// May tell the caller if item 
			{									// is stored in a register.
			typePtr++;
			info->isReg = YES;
			}
		else 
			if (info->isReg)
				info->isReg = NO;
												// May tell the caller what the 
		info->offset = 0;						// stack/register offset is for
		while (isdigit(*typePtr))				// this argument.
			info->offset = info->offset * 10 + (*typePtr++ - '0');
		}

	return typePtr;
}

/* 
   For encoding and decoding the method arguments, we have to know where
   to find things in the "argframe" as returned by __builtin_apply_args.
   For some situations this is obvious just from the selector type
   encoding, but structures passed by value cause a problem because some
   architectures actually pass these by reference, i.e. use the
   structure-value-address mentioned in the gcc/config/_/_.h files.

   These differences are not encoded in the selector types.

   Below is my current guess for which architectures do this.
   xxx I really should do this properly by looking at the gcc config values.

   I've also been told that some architectures may pass structures with
   sizef(structure) > sizeof(void*) by reference, but pass smaller ones by
   value.  The code doesn't currently handle that case.
*/

const char *
NSGetSizeAndAlignment(const char *typePtr, unsigned *sizep, unsigned *alignp)
{
	NSArgumentInfo info;

	typePtr = mframe_next_arg(typePtr, &info);
	if (sizep)
		*sizep = info.size;
	if (alignp)
		*alignp = info.align;
	
	return typePtr;
}


@implementation NSMethodSignature

+ (NSMethodSignature*) signatureWithObjCTypes:(const char*)t
{
	NSMethodSignature *m = [[NSMethodSignature alloc] autorelease];

	m->methodTypes = mframe_build_signature(t, &m->argFrameLength, &m->numArgs, 0); 

    return m;
}

- (void) dealloc
{
    if (methodTypes)
		free((void*)methodTypes),	methodTypes = NULL;
    if (info)
		free((void*)info),			info = NULL;
    [super dealloc];
}

- (unsigned) numberOfArguments				{ return numArgs; }
- (unsigned) frameLength					{ return argFrameLength; }

- (NSArgumentInfo) argumentInfoAtIndex:(unsigned)index
{
    if (index >= numArgs)
		[NSException raise: NSInvalidArgumentException
					 format: @"Index overflow."];
    if (info == 0)
		[self methodInfo];

    return info[index+1];
}

- (const char*) getArgumentTypeAtIndex:(unsigned)index
{
    if (index >= numArgs)
		[NSException raise: NSInvalidArgumentException
		    		 format: @"Index overflow."];
    if (info == 0)
		[self methodInfo];

    return info[index+1].type;
}

- (BOOL) isOneway
{
	if (info == 0)
		[self methodInfo];

	return (info[0].qual & _F_ONEWAY) ? YES : NO;
}

- (unsigned) methodReturnLength
{
	if (info == 0)
		[self methodInfo];

	return info[0].size;
}

- (const char*) methodReturnType
{
    if (info == 0)
		[self methodInfo];

    return info[0].type;
}

@end  /* NSMethodSignature */


@implementation NSMethodSignature (mGSTEP)

- (NSArgumentInfo*) methodInfo
{
    if (info == 0) 
		{
		const char *types = methodTypes;
		int i;

		info = malloc(sizeof(NSArgumentInfo) * (numArgs+1));
		for (i = 0; i <= numArgs; i++)
			types = mframe_next_arg(types, &info[i]);
    	}

    return info;
}

- (const char*) methodType					{ return methodTypes; }

@end  /* NSMethodSignature (mGSTEP) */

/* ****************************************************************************

	DEPRECATED

** ***************************************************************************/

#ifdef __GNU_LIBOBJC__	// GCC 4.6+

int
method_types_get_size_of_stack_arguments (const char *type)
{										// Return the size of the argument 
	type = objc_skip_typespec (type);	// block needed on the stack to invoke
	return atoi (type);					// the method MTH.  This may be zero, 
}										// if all args are passed in registers.

int
method_types_get_size_of_register_arguments(const char *types)
{
	const char *type = strrchr(types, '+');

	return (type) ? atoi(++type) + sizeof(void*) : 0;
}

int
method_types_get_number_of_arguments (const char *type)
{
	int i = 0;					// Return the number of arguments that the 
								// method MTH expects.  Note that all methods 
	while (*type)				// need two implicit arguments `self' & `_cmd'
		{
		type = objc_skip_argspec (type);
		i += 1;
		}

	return i - 1;
}

#endif
