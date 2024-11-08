/*
   NSArchiver.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>

   This file is part of the mGSTEP Library and is provided under the 
   terms of the libFoundation BSD type license (See the Readme file).
*/

#include <Foundation/NSArchiver.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSData.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSByteOrder.h>
#include <Foundation/NSSerialization.h>

#include <ctype.h>

#define SIGNATURE  "mGSTEP NSArchiver"


NSString *NSInconsistentArchiveException = @"NSInconsistentArchiveException";

enum  { OP_NONE = 0,  OP_ID,     OP_CLASS,   OP_SEL,   OP_STRING,
        OP_CHAR,      OP_SHORT,  OP_INT,     OP_LONG,  OP_FLOAT,
        OP_DOUBLE,    OP_ARRAY,  OP_STRUCT,  OP_PTR,   OP_LAST  };

enum  { REFERENCE = 0x20 };
enum  { VALUE_TYPE_MASK = 0x1f };


static NSMapTable *__classToAliasMappings;    // archive name -> decoded name

id __nil_objc_method (id receiver, SEL op, ...)		{ return receiver; }


@interface ArchiverClassInfo : NSObject
{
    NSString *className;
    unsigned version;
    BOOL written;
}

- (void) setClassName:(NSString*)name;
- (void) setVersion:(int)version;
- (void) setWritten:(BOOL)flag;

- (NSString*) className;
- (unsigned) version;
- (BOOL) written;

@end

@implementation ArchiverClassInfo

- (void) dealloc
{
    [className release];
    [super dealloc];
}

- (void) encodeWithCoder:(NSCoder*)coder
{
	const char *classNameAsString = [className cString];

    [coder encodeValuesOfObjCTypes:"*I", &classNameAsString, &version];
}

- (id) initWithCoder:(NSCoder*)coder
{
	char *classNameAsString;

    [coder decodeValuesOfObjCTypes:"*I", &classNameAsString, &version];
    className = [[NSString stringWithCString:classNameAsString] retain];
    free(classNameAsString);

    return self;
}

- (void) setClassName:(NSString*)name	{ ASSIGN(className, name); }
- (void) setVersion:(int)_version		{ version = _version; }
- (void) setWritten:(BOOL)flag			{ written = flag; }
- (NSString*) className					{ return className; }
- (unsigned) version					{ return version; }
- (BOOL) written						{ return written; }

@end /* ArchiverClassInfo */


@interface NSData (mGSTEP_ArchiverExtensions)
														// Deserializing Data
- (void) deserializeDataAt:(void*)data
				ofObjCType:(const char*)type
				atCursor:(unsigned int*)cursor
				context:(id <NSObjCTypeSerializationCallBack>)callback;
- (int) deserializeIntAtCursor:(unsigned int*)cursor;
														// Serializing Data
- (void) serializeDataAt:(const void*)data
			  ofObjCType:(const char*)type
			  context:(id <NSObjCTypeSerializationCallBack>)callback;

@end

/* ****************************************************************************

 		NSArchiver 

** ***************************************************************************/

@implementation NSArchiver

- (id) init
{
    [self initForWritingWithMutableData:[NSMutableData new]];
    return [super init];
}

- (id) initForWritingWithMutableData:(NSMutableData*)data
{
	const char *signature = SIGNATURE;
	unsigned version = [isa version];

	ASSIGN(_mdata, data);
    writeIMP = [_mdata methodForSelector:
						@selector(serializeDataAt:ofObjCType:context:)];
    if(!objects)
		objects = NSCreateHashTable (NSNonOwnedPointerHashCallBacks, 119);
    else
		NSResetHashTable (objects);

    if(!conditionals)
		conditionals = NSCreateHashTable (NSNonOwnedPointerHashCallBacks, 19);
    else
		NSResetHashTable (conditionals);

    if(!classes)
		classes = NSCreateMapTable (NSObjectMapKeyCallBacks,
									NSObjectMapValueCallBacks, 19);
    else
		NSResetMapTable (classes);

    if(!pointers)
		pointers = NSCreateHashTable (NSNonOwnedPointerHashCallBacks, 0);
    else
		NSResetHashTable (pointers);

    [_mdata serializeDataAt:&signature ofObjCType:@encode(char*) context:nil];
    [_mdata serializeDataAt:&version ofObjCType:@encode(int) context:nil];

    return self;
}

- (void) dealloc
{
    [_mdata release];
    NSFreeHashTable(objects);
    NSFreeHashTable(conditionals);
    NSFreeMapTable(classes);
    NSFreeHashTable(pointers);

    [super dealloc];
}

+ (NSData*) archivedDataWithRootObject:(id)rootObject
{
	NSArchiver *archiver = [[self new] autorelease];

    [archiver encodeRootObject:rootObject];

    return [[archiver->_mdata copy] autorelease];
}

+ (BOOL) archiveRootObject:(id)rootObject toFile:(NSString*)path
{
	id data = [self archivedDataWithRootObject:rootObject];

    return [data writeToFile:path atomically:YES];
}

- (void) encodeArrayOfObjCType:(const char*)type
						 count:(unsigned int)count
						 at:(const void*)array
{
	unsigned i, offset, item_size = objc_sizeof_type(type);
	char tag = OP_ARRAY;
	SEL writeSel = @selector(serializeDataAt:ofObjCType:context:);

    (*writeIMP) (_mdata, writeSel, &tag, @encode(char), nil);
    (*writeIMP) (_mdata, writeSel, &count, @encode(int), nil);
								// Optimize writing arrays of elementary types. 
    switch(*type) 				// If such an array has to be written, write
		{						// the type and then the elements of array
		case _C_ID:		tag = _C_ID;		break;
		case _C_CHR:
		case _C_UCHR:   tag = OP_CHAR;		break;
		case _C_SHT:
		case _C_USHT:   tag = OP_SHORT;		break;
		case _C_INT:
		case _C_UINT:   tag = OP_INT;		break;
		case _C_ULNG_LNG:
		case _C_LNG:
		case _C_ULNG:   tag = OP_LONG;		break;
		case _C_FLT:    tag = OP_FLOAT;		break;
		case _C_DBL:    tag = OP_DOUBLE;	break;
		default:		tag = OP_NONE;		break;
		}

    if(tag == OP_NONE) 
		{
		SEL selector = @selector(encodeValueOfObjCType:at:);
		IMP imp = [self methodForSelector:selector];

		for(i = offset = 0; i < count; i++, offset += item_size)
			(*imp) (self, selector, type, (char*)array + offset);
		}
	else 
		{
		(*writeIMP) (_mdata, writeSel, &tag, @encode(char), nil);

		if(tag == _C_ID) 
			{
			const id *_array = array;

			for(i = offset = 0; i < count; i++, offset += item_size)
//				(*writeIMP) (_mdata, writeSel, (char*)array + offset,type,nil);
				[self encodeObject:_array[i]];
			}
		else
			for(i = offset = 0; i < count; i++, offset += item_size)
				(*writeIMP) (_mdata, writeSel, (char*)array+offset, type, nil);
		}    
}

- (void) encodeValueOfObjCType:(const char*)type at:(const void*)data
{
	char tag;
	SEL writeSel = @selector(serializeDataAt:ofObjCType:context:);

    switch(*type)
		{							// Write another tag just to be possible to
		case _C_ID: 				// read using the decodeObject method.
			tag = OP_ID;
			(*writeIMP) (_mdata, writeSel, &tag, @encode(char), nil);
			[self encodeObject: *(void**)data];
			return;

		case _C_CLASS:	
			{
			id className = NSStringFromClass(*(Class*)data);
			id classInfo = NSMapGet(classes, className);
		
			tag = OP_CLASS;
			if(classInfo && [classInfo written]) 
				{
				tag |= REFERENCE;
				(*writeIMP) (_mdata, writeSel, &tag, @encode(char), nil);
				(*writeIMP) (_mdata, writeSel, data, @encode(NSUInteger), nil);
				}
			else 
				{
				(*writeIMP) (_mdata, writeSel, &tag, @encode(char), nil);
				(*writeIMP) (_mdata, writeSel, data, @encode(NSUInteger), nil);
										// The classInfo could be nil if the 
										// encodeClassName:intoClassName: was 
										// not previously sent for this class 
				if(!classInfo) 			// name. Create a new entry in classes
					{					// that has as key this class.
					classInfo = (ArchiverClassInfo*)[ArchiverClassInfo alloc];

					[classInfo setClassName:className];
					[classInfo setVersion:[*(Class*)data version]];
					NSMapInsert(classes, className, classInfo);
					[classInfo release];
					}
	
				[classInfo encodeWithCoder:self];
				[classInfo setWritten:YES];
				}
			return;
			}

		case _C_SEL: 
			tag = OP_SEL;
			if (NSHashGet (pointers, *(SEL*)data)) 
				{						// The selector was previously written
				tag |= REFERENCE;
				(*writeIMP) (_mdata, writeSel, &tag, @encode(char), nil);
				(*writeIMP) (_mdata, writeSel, data, @encode(NSUInteger), nil);
				}
			else 
				{						// selector has not yet been written
				const char *name = [NSStringFromSelector(*(SEL*)data) cString];

				NSHashInsert (pointers, *(SEL*)data);
				(*writeIMP) (_mdata, writeSel, &tag, @encode(char), nil);
				(*writeIMP) (_mdata, writeSel, data, @encode(NSUInteger), nil);
				(*writeIMP) (_mdata, writeSel, &name, @encode(char*), nil);
				}
			return;

		case _C_ARY_B: 
			{
			int count = atoi(type + 1);
			const char *itemType = type;

			tag = OP_ARRAY;
			while(isdigit(*++itemType));	// nothing
						// Write another tag just to be possible to read using 
						// the decodeArrayOfObjCType:count:at: method.
			(*writeIMP) (_mdata, writeSel, &tag, @encode(char), nil);
			[self encodeArrayOfObjCType:itemType count:count at:data];
			return;
			}

		case _C_STRUCT_B: 
			{
			int offset = 0;
			int align, rem;

			tag = OP_STRUCT;
			(*writeIMP)(_mdata, writeSel, &tag, @encode(char), nil);
		
			while(*type != _C_STRUCT_E && *type++ != '=')
				/* skip "<name>=" */;
			while(1) 
				{
				[self encodeValueOfObjCType:type at:((char*)data) + offset];
				offset += objc_sizeof_type(type);
				type = objc_skip_typespec(type);
				if(*type != _C_STRUCT_E) 
					{
					align = objc_alignof_type(type);
					if((rem = offset % align))
						offset += align - rem;
					}
				else 
					break;
				}
			return;
			}

		case _C_PTR: 
			{
			tag = OP_PTR;
			if (NSHashGet (pointers, *(char**)data)) 
				{
				tag |= REFERENCE;
				(*writeIMP) (_mdata, writeSel, &tag, @encode(char), nil);
				(*writeIMP) (_mdata, writeSel, data, @encode(NSUInteger), nil);	    
				}
			else 
				{
				NSHashInsert (pointers, *(char**)data);
				(*writeIMP) (_mdata, writeSel, &tag, @encode(char), nil);
				(*writeIMP) (_mdata, writeSel, data, @encode(NSUInteger), nil);	    
				type++; data = *(char**)data;
				[self encodeValueOfObjCType:type at:data];
				}
			return;
			}

		case _C_CHARPTR: 
			{
			const char *cStr = *(void**)data;
			NSUInteger value = cStr ? (NSUInteger)NSHashGet(pointers,cStr) : 0;

			tag = OP_STRING;
			if(value) 
				{
				tag |= REFERENCE;
				(*writeIMP) (_mdata, writeSel, &tag, @encode(char), nil);
				(*writeIMP) (_mdata, writeSel, data, @encode(NSUInteger), nil);	    
				}
			else 
				{
				(*writeIMP) (_mdata, writeSel, &tag, @encode(char), nil);
				value = (NSUInteger)cStr;
				(*writeIMP) (_mdata, writeSel, &value, @encode(NSUInteger), nil);

				if(cStr) 
					{
					int len = strlen(cStr);
		
					NSHashInsert (pointers, cStr);
					(*writeIMP) (_mdata, writeSel, &len,@encode(NSUInteger),nil);
					[_mdata appendBytes:cStr length:len];
					}
				}
			return;
			}

		case _C_CHR:
		case _C_UCHR: 
			{
//			WRITE_TYPE_TAG (char, OP_CHAR, data)
			tag = OP_CHAR;
			(*writeIMP) (_mdata, writeSel, &tag, @encode(char), nil);
			(*writeIMP) (_mdata, writeSel, (void*)data, @encode(char), nil);
			break;
			}
		case _C_SHT:
		case _C_USHT: 
			{
			unsigned short ns = NSSwapHostShortToBig (*(unsigned short*)data);
//			WRITE_TYPE_TAG (short, OP_SHORT, &ns)
			tag = OP_SHORT;
			(*writeIMP) (_mdata, writeSel, &tag, @encode(char), nil);
			(*writeIMP) (_mdata, writeSel, (void*)&ns, @encode(short), nil);
			break;
			}
		case _C_INT:
		case _C_UINT: 
			{
			unsigned int ni = NSSwapHostIntToBig (*(unsigned int*)data);
//			WRITE_TYPE_TAG (int, OP_INT, &ni)
			tag = OP_INT;
			(*writeIMP) (_mdata, writeSel, &tag, @encode(char), nil);
			(*writeIMP) (_mdata, writeSel, (void*)&ni, @encode(int), nil);
			break;
			}
		case _C_LNG:
		case _C_ULNG:
		case _C_ULNG_LNG:
			{
			unsigned long nl = NSSwapHostLongToBig (*(unsigned long*)data);
//			WRITE_TYPE_TAG (long, OP_LONG, &nl);
			tag = OP_LONG;
			(*writeIMP) (_mdata, writeSel, &tag, @encode(char), nil);
			(*writeIMP) (_mdata, writeSel, (void*)&nl, @encode(long), nil);
			break;
			}
		case _C_FLT: 
			{
			NSSwappedFloat nf = NSSwapHostFloatToBig (*(float*)data);
//			WRITE_TYPE_TAG (float, OP_FLOAT, &nf)
			tag = OP_FLOAT;
			(*writeIMP) (_mdata, writeSel, &tag, @encode(char), nil);
			(*writeIMP) (_mdata, writeSel, (void*)&nf, @encode(float), nil);
			break;
			}
		case _C_DBL: 
			{
			NSSwappedDouble nd = NSSwapHostDoubleToBig (*(double*)data);
//			WRITE_TYPE_TAG (double, OP_DOUBLE, &nd)
			tag = OP_DOUBLE;
			(*writeIMP) (_mdata, writeSel, &tag, @encode(char), nil);
			(*writeIMP) (_mdata, writeSel, (void*)&nd, @encode(double), nil);
			break;
			}

		case _C_VOID:
			[NSException raise: NSInvalidArgumentException
						 format: @"cannot encode void type"];
		default:
			[NSException raise: NSInvalidArgumentException
						 format: @"unknown type %c", *type];
		}
}

- (void) encodeRootObject:(id)rootObject
{
	id originalData = _mdata;
	IMP originalWriteIMP = writeIMP;

    if(writingRoot) 
		{
		[NSException raise: NSInternalInconsistencyException
					 format: @"CoderHasAlreadyWrittenRootObjectException"];
		return;
		}

    writingRoot = YES;

	// Prepare for writing the graph objects for which `rootObject' is the root
	// node. The algorithm consists from two passes. In the first pass it
	// determines the nodes so-called 'conditionals' - the nodes encoded *only*
	// with -encodeConditionalObject:. They represent nodes that are not
	// related directly to the graph. In the second pass objects are encoded
	// normally, except for the conditional objects which are encoded as nil.

	findingConditionals = YES;								// First pass.
	_mdata = nil;
	writeIMP = __nil_objc_method;
	NSResetHashTable(conditionals);
	NSResetHashTable(objects);
	[self encodeObject:rootObject];
	
	findingConditionals = NO;								// Second pass.
	_mdata = originalData;
	writeIMP = originalWriteIMP;
	NSResetHashTable(objects);
	[self encodeObject:rootObject];
	
	writingRoot = NO;
}

- (void) encodeConditionalObject:(id)anObject
{
    if(!writingRoot) 
		{
		[NSException raise: NSInternalInconsistencyException
					 format: @"RootObjectHasNotBeenWrittenException"];
		return;
		}

    if(findingConditionals) 
		{			// First pass in determining the conditionals algorithm. 
					// Traverse the graph and insert into `conditionals' set. 
					// In the second pass all objects that are still in this 
					// set will be encoded as nil when they receive an 
					// encodeConditionalObject: message. An object is removed 
					// from this set when it receives -encodeObject:.
		void *value;

		if(!anObject)
			return;
										// Lookup anObject in conditionals set
		value =  NSHashGet(conditionals, anObject);
		if(value)
			return;						// Maybe it has received -encodeObject:
										// and now is in the `objects' set.
		value = NSHashGet(objects, anObject);
		if(value)
			return;
										// anObject was not written previously.
		NSHashInsert(conditionals, anObject);
		}
    else 
		{	// If anObject is in the `conditionals' set, it is encoded as nil.
		if(!anObject || NSHashGet(conditionals, anObject))
	    	[self encodeObject:nil];
		else 
			[self encodeObject:anObject];
    	}
}

- (void) encodeObject:(id)anObject
{
	char tag = OP_ID;
	void *value = 0;
	SEL writeSel = @selector(serializeDataAt:ofObjCType:context:);

    if(!anObject) 
		{
		tag |= REFERENCE;
		(*writeIMP) (_mdata, writeSel, &tag, @encode(char), nil);
		(*writeIMP) (_mdata, writeSel, &value, @encode(NSUInteger), nil);
		}
    else 
		{
		value = NSHashGet(objects, anObject);

		if(findingConditionals && !value) 
			{	// Look-up the object in the `conditionals' set. If object is
				// there, then remove it because it is no longer a conditional.
			value = NSHashGet(conditionals, anObject);
			if(value) 
				{
				NSHashRemove(conditionals, anObject);
				NSHashInsert(objects, anObject);
				return;
			}	}

		if(!value) 
			{
			Class archiveClass;
	
			NSHashInsert(objects, anObject);
	
			if(!findingConditionals) 
				{
				value = anObject;
				anObject = [anObject replacementObjectForCoder:self];
				archiveClass = [anObject classForCoder];
		
				(*writeIMP) (_mdata, writeSel, &tag, @encode(char), nil);
				(*writeIMP) (_mdata, writeSel, &value, @encode(NSUInteger), nil);
				[self encodeValueOfObjCType:"#" at:&archiveClass];
				}
			else 	// This is the first pass of determining the conditionals
				{	// objects algorithm. Remove anObject from `conditionals'
					// set if it is there and insert it into the `objects' set.
				NSHashRemove(conditionals, anObject);
				}
			[anObject encodeWithCoder:self];
			}
		else 
			if(!findingConditionals) 
				{
				tag |= REFERENCE;
				(*writeIMP) (_mdata, writeSel, &tag, @encode(char), nil);
				(*writeIMP) (_mdata, writeSel, &value, @encode(NSUInteger), nil);
				}
    	}
}

- (NSMutableData*) archiverData				{ return _mdata; }

- (NSString*) classNameEncodedForTrueClassName:(NSString*)trueName
{
	NSString *ArchivedName = [(id)NSMapGet(classes, trueName) className];

    return ArchivedName ? ArchivedName : trueName;
}

/* In the following method the version of class named trueName is written as
   version for class named inArchiveName. Is this right? The inArchiveName
   class could not be linked in the running process at the time the archive
   is written. */
- (void) encodeClassName:(NSString*)trueName 
		   intoClassName:(NSString*)inArchiveName
{
	id classInfo = (ArchiverClassInfo*)[ArchiverClassInfo alloc];

	[classInfo setClassName:inArchiveName];
	[classInfo setVersion:[NSClassFromString(trueName) version]];

    NSMapInsert(classes, trueName, classInfo);
    [classInfo release];
}

@end /* NSArchiver */

/* ****************************************************************************

 		NSUnarchiver 

** ***************************************************************************/

@implementation NSUnarchiver

+ (void) initialize
{
    __classToAliasMappings = NSCreateMapTable(NSObjectMapKeyCallBacks,
											  NSObjectMapValueCallBacks, 19);
}

- (id) initForReadingWithData:(NSData*)data
{
	int siglen = strlen(SIGNATURE);
	char *signature;
	SEL readSel = @selector(deserializeDataAt:ofObjCType:atCursor:context:);

    if(!data)
		[NSException raise: NSInvalidArgumentException
					 format: @"argument of -initForReadingWithData: is nil"];

    if (!objects)
		objects = NSCreateMapTable (NSIntMapKeyCallBacks,
				    NSObjectMapValueCallBacks, 119);
    else
		NSResetMapTable (objects);
    if (!classes)
		classes = NSCreateMapTable (NSIntMapKeyCallBacks,
				    NSObjectMapValueCallBacks, 19);
    else
		NSResetMapTable (classes);
    if (!pointers)
		pointers = NSCreateMapTable (NSIntMapKeyCallBacks,
				    NSIntMapValueCallBacks, 19);
    else
		NSResetMapTable (pointers);
    if (!classAlias)
		classAlias = NSCreateMapTable (NSObjectMapKeyCallBacks,
					NSObjectMapValueCallBacks, 19);
    else
		NSResetMapTable (classAlias);
    if (!classVersions)
		classVersions = NSCreateMapTable (NSObjectMapKeyCallBacks,
					    NSObjectMapValueCallBacks, 19);
    else
		NSResetMapTable (classVersions);

	ASSIGN(_data, data);
    cursor = 0;
    readIMP = [_data methodForSelector:readSel];

    (*readIMP) (_data, readSel, &signature, @encode(char*), &cursor, nil);
    if (strncmp (signature, SIGNATURE, siglen))
		[NSException raise: NSInvalidArgumentException
					 format: @"InvalidSignatureForCoderException"];

    free(signature);
    archiverVersion = [_data deserializeIntAtCursor:&cursor];

    return self;
}

+ (id) unarchiveObjectWithData:(NSData*)data
{
	NSUnarchiver *unarchiver = [[self alloc] initForReadingWithData:data];
	id object = [unarchiver decodeObject];

    [unarchiver release];
    return object;
}

- (void) dealloc
{
    [_data release];
    NSFreeMapTable(classes);
    NSFreeMapTable(objects);
    NSFreeMapTable(pointers);
    NSFreeMapTable(classAlias);
    NSFreeMapTable(classVersions);

    [super dealloc];
}

+ (id) unarchiveObjectWithFile:(NSString*)path
{
	NSData *data = [NSData dataWithContentsOfFile:path];

    return (!data) ? nil : [self unarchiveObjectWithData:data];
}

- (void) decodeArrayOfObjCType:(const char*)type
						 count:(NSUInteger)count
						 at:(void*)array
{
	int i, offset, item_size = objc_sizeof_type(type);
	char tag, written_tag;
	int written_count;
	SEL readSel = @selector(deserializeDataAt:ofObjCType:atCursor:context:);

    (*readIMP) (_data, readSel, &tag, @encode(char), &cursor, nil);
    (*readIMP) (_data, readSel, &written_count, @encode(int), &cursor, nil);
    if(tag != OP_ARRAY)
		[NSException raise: NSInconsistentArchiveException
					 format: @"tag != OP_ARRAY"];
    if(written_count != count)
		[NSException raise: NSInconsistentArchiveException
					 format: @"written_count != count"];
									// Arrays of elementary types are written 
	switch(*type) 					// optimized: the type is written then the
		{							// elements of array follow.
		case _C_ID:		tag = _C_ID;		break;
		case _C_CHR:
		case _C_UCHR:   tag = OP_CHAR;		break;
		case _C_SHT:
		case _C_USHT:   tag = OP_SHORT;		break;
		case _C_INT:
		case _C_UINT:   tag = OP_INT;		break;
		case _C_ULNG_LNG:
		case _C_LNG:
		case _C_ULNG:   tag = OP_LONG;		break;
		case _C_FLT:    tag = OP_FLOAT;		break;
		case _C_DBL:    tag = OP_DOUBLE;	break;
		default:		tag = OP_NONE;		break;
		}

    if(tag == OP_NONE)
		{
		SEL selector = @selector(decodeValueOfObjCType:at:);
		IMP imp = [self methodForSelector:selector];

		for(i = offset = 0; i < count; i++, offset += item_size)
			(*imp)(self, selector, type, (char*)array + offset);
		}
    else 
		{
		(*readIMP)(_data, readSel, &written_tag, @encode(char), &cursor, nil);
		if(tag != written_tag)
			[NSException raise: NSInconsistentArchiveException
						 format: @"tag != written_tag"];

		if(tag == _C_ID)
			{
			id *_array = array;
			for(i = offset = 0; i < count; i++, offset += item_size)
				_array[i] = [self decodeObject];
			}
		else
			for(i = offset = 0; i < count; i++, offset += item_size)
				(*readIMP)(_data, readSel, ((char*)array) + offset, type, 
							&cursor, nil);
		}
}

#define CHECK1(against) \
        if(*type != against) \
			[NSException raise: NSInvalidArgumentException \
						 format: @"*type != against"]; \

#define CHECK2(against1, against2) \
        if(*type != against1 && *type != against2) \
			[NSException raise: NSInvalidArgumentException \
						 format: @"*type != against1 && *type != against2"]; \

- (void) decodeValueOfObjCType:(const char*)type at:(void*)address
{
	SEL readSel = @selector(deserializeDataAt:ofObjCType:atCursor:context:);
	char tag;
				// This statement, by taking the address of `type', forces the 
				// compiler to not allocate `type' into a register
    *(void**)address = &type;
    (*readIMP)(_data, readSel, &tag, @encode(char), &cursor, nil);

	switch(tag & VALUE_TYPE_MASK) 
		{
		case OP_ID: 
			CHECK1(_C_ID)
			*(id*)address = [self decodeObject];
			return;

		case OP_CLASS: 
			{
			void *key;
			NSString *archiveClassName;
			NSString *decodedClassName;
	
			CHECK1(_C_CLASS)
			(*readIMP) (_data, readSel, &key, @encode(NSUInteger), &cursor, nil);
			if (tag & REFERENCE)
				archiveClassName = [(id)NSMapGet(classes, key) className];
			else 
				{
				id classInfo = [ArchiverClassInfo new];
		
				[classInfo initWithCoder:self];
				NSMapInsert(classes, key, classInfo);
				archiveClassName = [classInfo className];
				NSMapInsert(classVersions, archiveClassName, classInfo);
				[classInfo release];
				}
	
			NSAssert (archiveClassName, @"archiveClassName should be non-nil");
			if(!(decodedClassName = NSMapGet(classAlias, archiveClassName)))
				decodedClassName = archiveClassName;
			*(Class*)address = NSClassFromString(decodedClassName);
			if(!*(Class*)address)
				[NSException raise: NSInvalidArgumentException
							 format: @"Unknown Class"];
			return;
			}

		case OP_SEL: 
			{
			void *key;
			id selName;
	
			CHECK1(_C_SEL)
			(*readIMP) (_data, readSel, &key, @encode(NSUInteger), &cursor, nil);
			if (tag & REFERENCE)
				selName = NSMapGet (objects, key);
			else 
				{
				char *name;								// selector name

				(*readIMP) (_data, readSel, &name, @encode(char*),&cursor,nil);
				selName = [[NSString alloc] initWithCStringNoCopy:name
											length:strlen(name)
											freeWhenDone:YES];
				NSMapInsert (objects, key, selName);	// Insert selector into 
				}										// the `objects' table
			*(SEL*)address = NSSelectorFromString(selName);
			return;
			}

		case OP_ARRAY:
			{
            int count;
            const char *itemType;

			CHECK1(_C_ARY_B)
			count = atoi (type + 1);
			itemType = type;
			while (isdigit (*++itemType));				// nothing
			[self decodeArrayOfObjCType:itemType count:count at:address];
            return;
			}

		case OP_STRUCT:
			{
            int offset = 0;
            int align, rem;

			CHECK1(_C_STRUCT_B)
			while (*type != _C_STRUCT_E && *type++ != '=');	 // skip "<name>="
			while (1) 
				{
				[self decodeValueOfObjCType:type at:((char*)address) + offset];
				offset += objc_sizeof_type(type);
				type = objc_skip_typespec(type);
				if(*type != _C_STRUCT_E) 
					{
					align = objc_alignof_type(type);
					if((rem = offset % align))
						offset += align - rem;
					}
				else 
					break;
				}
			return;
			}

		case OP_PTR:		// implementation in libFoundation keeps a ref to
			{				// the ptr in an auto released object in case of
            void *key;		// exceptions.  Avoid this since such an error
							// probably warrants termination.
			CHECK1(_C_PTR)
			(*readIMP)(_data, readSel, &key, @encode(NSUInteger), &cursor, nil);
			if (tag & REFERENCE)
				*(void**)address = NSMapGet(pointers, key);
			else 
				{
				*(void**)address = malloc(objc_sizeof_type(++type));
				NSMapInsert(pointers, key, *(void**)address);
				[self decodeValueOfObjCType:type at:*(void**)address];
				}
			return;
			}

		case OP_STRING:
			{
			void *key;
	
			CHECK1(_C_CHARPTR)
			(*readIMP)(_data, readSel, &key, @encode(NSUInteger), &cursor, nil);
			if(tag & REFERENCE)
				*(void**)address = NSMapGet(pointers, key);
			else 
				{
				if(key) 
					{
					int l;
					NSRange range;

					(*readIMP)(_data,readSel,&l,@encode(NSUInteger),&cursor,nil);
					*(char**)address = malloc(l + 1);
					NSMapInsert(pointers, key, *(char**)address);
					range = NSMakeRange(cursor, l);
					[_data getBytes:*(char**)address range:range];
					cursor += l;
					(*(char**)address)[l] = 0;
					}
				else 
					*(char**)address = NULL;
				}
			return;
			}

        case OP_CHAR: 
			{
			CHECK2(_C_CHR, _C_UCHR)
			(*readIMP)(_data, readSel, address, type, &cursor, nil);
			break;
			}

        case OP_SHORT:
			{
			unsigned short ns;
	
			CHECK2(_C_SHT, _C_USHT)
			(*readIMP)(_data, readSel, &ns, type, &cursor, nil);
			*(unsigned short*)address = NSSwapBigShortToHost (ns);
			break;
			}

		case OP_INT:
			{
			unsigned int ni;
	
			CHECK2(_C_INT, _C_UINT)
			(*readIMP)(_data, readSel, &ni, type, &cursor, nil);
			*(unsigned int*)address = NSSwapBigIntToHost (ni);
			break;
			}

		case OP_LONG: 
			{
			unsigned long nl;
	
///			CHECK2(_C_LNG, _C_ULNG)
			if (*type != _C_LNG && *type != _C_ULNG && *type != _C_ULNG_LNG)
				[NSException raise: NSInvalidArgumentException
							 format: @"*type != C long types"];
			(*readIMP)(_data, readSel, &nl, type, &cursor, nil);
			*(unsigned long*)address = NSSwapBigLongToHost (nl);
			break;
			}

        case OP_FLOAT:
			{
			NSSwappedFloat nf;
	
			CHECK1(_C_FLT)
			(*readIMP)(_data, readSel, &nf, type, &cursor, nil);
			*(float*)address = NSSwapBigFloatToHost (nf);
			break;
			}

        case OP_DOUBLE:
			{
			NSSwappedDouble nd;
	
			CHECK1(_C_DBL)
			(*readIMP)(_data, readSel, &nd, type, &cursor, nil);
			*(double*)address = NSSwapBigDoubleToHost (nd);
			break;
			}

        default:
			[NSException raise: NSInternalInconsistencyException
						 format: @"ReadUnknownTagException"];
		}
}

- (id) decodeObject
{
	SEL readSel = @selector(deserializeDataAt:ofObjCType:atCursor:context:);
	char tag;
	void *key;
	id object;

    (*readIMP)(_data, readSel, &tag, @encode(char), &cursor, nil);
    if((tag & VALUE_TYPE_MASK) != OP_ID)
		[NSException raise: NSInternalInconsistencyException
					 format: @"expected object and got type %d", tag];

    (*readIMP)(_data, readSel, &key, @encode(NSUInteger), &cursor, nil);

    if(tag & REFERENCE)
		object = key ? NSMapGet(objects, key) : nil;
    else
		{
		Class class;
		id new_object;

		[self decodeValueOfObjCType:"#" at:&class];
		object = [class alloc];
		NSMapInsert(objects, key, object);
		new_object = [object initWithCoder:self];
		if(new_object != object)
			{
			object = new_object;
			NSMapInsert(objects, key, object);
			}
		new_object = [object awakeAfterUsingCoder:self];
		if(new_object != object)
			{
			object = new_object;
			NSMapInsert(objects, key, object);
		}	}

    return object;
}

- (BOOL) isAtEnd						{ return (cursor >= [_data length]); }
- (unsigned int) systemVersion			{ return archiverVersion; }

+ (NSString*) classNameDecodedForArchiveClassName:(NSString*)nameInArchive
{
	NSString *className = NSMapGet(__classToAliasMappings, nameInArchive);

    return className ? className : nameInArchive;
}

- (NSString*) classNameDecodedForArchiveClassName:(NSString*)nameInArchive
{
	NSString *className = NSMapGet(classAlias, nameInArchive);

    return className ? className : nameInArchive;
}

+ (void) decodeClassName:(NSString*)nameInArchive
			 asClassName:(NSString*)trueName
{
    NSMapInsert(__classToAliasMappings, nameInArchive, trueName);
}

- (void) decodeClassName:(NSString*)nameInArchive 
			 asClassName:(NSString*)trueName
{
    NSMapInsert(classAlias, nameInArchive, trueName);
}

- (unsigned int) versionForClassName:(NSString*)className
{
    return [(id)NSMapGet(classVersions, className) version];
}

@end /* NSUnarchiver */
