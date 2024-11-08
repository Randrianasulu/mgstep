/*
   NSPortCoder.m

   DO coder that transmits object proxies and objects between NSConnections

   Copyright (C) 1994, 1995, 1996, 1997 Free Software Foundation, Inc.

   Author:	Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date:	July 1994
   Rewrite:	Richard Frith-Macdonald <richard@brainstorm.co.u>
   Date:	August 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include "_NSPortCoder.h"
#include <Foundation/NSPort.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSException.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSData.h>
#include <Foundation/NSArchiver.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSHashTable.h>
#include <Foundation/NSConnection.h>
#include <Foundation/NSPortMessage.h>

#define NO_SEL_TYPES	"none"
#define DEFAULT_SIZE	256
#define DEFAULT_FORMAT_VERSION	0
#define DOING_ROOT_OBJECT	(interconnect_stack_height != 0)

// Class variables
static id _dummyObject;
static BOOL debug_coder = NO;
static BOOL debug_connected_coder = NO;
static int default_format_version;
static id default_stream_class;
static id default_cstream_class;


@interface NSPortMessage (TcpInPacketStreams) <Streaming>
@end
								// To fool ourselves into thinking we can call 
								// all these Encoding and Decoding methods.
@interface NSPortCoder (Coding)  <Encoding, Decoding>
@end										// NSPortCoder is an abstract class
											// which creates instances of
@implementation NSPortCoder					// PortEncoder or PortDecoder

+ (void) initialize
{
	if (self == [NSPortCoder class])
		{				// This code has not yet been ported to machines for
						// which a pointer is not the same size as an int.
		NSAssert(sizeof(void*) == sizeof(unsigned),
				@"Pointer and int are different sizes"); 

		default_stream_class = [MemoryStream class];
		default_cstream_class = [BinaryCStream class];
		default_format_version = DEFAULT_FORMAT_VERSION;
		_dummyObject = [NSObject new];
		}
}

+ (void) _setDebugging:(BOOL)f				{ debug_coder = f; }

+ newDecodingWithConnection:(NSConnection*)c timeout:(int)timeout
{
	return [PortDecoder newDecodingWithConnection:c timeout:timeout];
}

+ (id) newForWritingWithConnection:(NSConnection*)c
					sequenceNumber:(int)n
						identifier:(int)i
{
	return [[PortEncoder alloc] _initForWritingWithConnection: c
								sequenceNumber: n
								identifier: i];
}

#if 0  
// PortEncoder
+ newForWritingWithConnection:(NSConnection*)c
			   sequenceNumber:(int)n
			   identifier:(int)i
{		// Export this method and not the -init... method because eventually
		// we may do some caching of old PortEncoder's to speed things up.
	return [[self alloc] _initForWritingWithConnection: c
						 sequenceNumber: n
						 identifier: i];
}
#endif

- (id) _initWithCStream:(id <CStreaming>) cs 	// designated initializer.  Do
		  formatVersion:(int) version			// not call directly.  Instead
{												// override it and call 
	format_version = version;					// [super...] in subclasses.
	cstream = [cs retain];
	classname_2_classname = NULL;
	interconnect_stack_height = 0;

	return self;
}

- (id) init
{
	if ([self class] == [NSPortCoder class])
		{
		[self shouldNotImplement:_cmd];

		return nil;
		}

	return [super init];
}

- (void) dealloc
{							// No. [self _finishDecodeRootObject];
	[cstream release];
	[super dealloc];
}

- (NSConnection*) connection				{ return connection; }
- (int) formatVersion						{ return format_version; }
- (int) identifier							{ return identifier; }
- (unsigned) sequenceNumber					{ return sequence_number; }		
- (void) dismiss							{ SUBCLASS }
- (NSPort*) decodePortObject				{ SUBCLASS return nil; }
- (void) encodePortObject:(NSPort*)aPort 	{ SUBCLASS }
- (BOOL) isBycopy							{ NIMP return NO; }
- (BOOL) isByref							{ NIMP return NO; }
- (NSPort*) replyPort						{ NIMP return nil; }

- (void) encodeValueOfObjCType:(const char*)type				// core methods
							at:(const void*)address;
{
	[self encodeValueOfObjCType:type at:address withName:NULL];
}

- (void) decodeValueOfObjCType:(const char*)type
							at:(void*)address
{
	[self decodeValueOfObjCType: type at: address withName: NULL];
}

- (void) encodeDataObject:(NSData*)data			{ NIMP }
- (NSData*) decodeDataObject					{ NIMP return nil; }

- (unsigned int) versionForClassName:(NSString*)className
{
	[self notImplemented:_cmd];
	return 0;
}

- (void) encodeObject:(id)anObject
{
	[self encodeObject: anObject withName: NULL];
}

- (void) encodeBycopyObject:(id)anObject
{
	[self encodeBycopyObject: anObject withName: NULL];
}

- (void) encodeByrefObject:(id)anObject
{
	[self encodeByrefObject: anObject withName: NULL];
}

- (void) encodeConditionalObject:(id)anObject
{
  /* NeXT's implementation handles *forward* references by running
     through the entire encoding process twice!  GNU Coding can handle
     forward references with only one pass.  Therefore, however, GNU
     Coding cannot return a *forward* reference from -decodeObject, so
     here, assuming this call to -encodeConditionalObject: is mirrored
     by a -decodeObject, we don't try to encode *forward*
     references.

     Note that this means objects that use -encodeConditionalObject:
     that are encoded in the GNU style might decode a nil where
     NeXT-style encoded would not.  I don't see this a huge problem;
     at least not as bad as NeXT coding mechanism that actually causes
     crashes in situations where GNU's does fine.  Still, if we wanted
     to fix this, we might be able to build a kludgy fix based on
     detecting when this would happen, rewinding the stream to the
     "conditional" point, and encoding again.  Yuck. */

	if ([self _coderReferenceForObject: anObject])
		[self encodeObject: anObject];
	else
		[self encodeObject: nil];
}

- (void) encodeRootObject:(id)rootObject
{
	[self encodeRootObject: rootObject withName: NULL];
}

- (id) decodeObject
{
  /* This won't work for decoding GNU-style forward references because
     once the GNU decoder finds the object later in the decoding, it
     will back-patch by storing the id in &o... &o will point to some
     weird location on the stack!  This is why we make the GNU
     implementation of -encodeConditionalObject: not encode forward
     references. */
	id o;

	[self decodeObjectAt: &o withName: NULL];
	return [o autorelease];
}

- (NSUInteger) systemVersion					{ return format_version; }
- (NSMutableData*) archiverData					{ NIMP return nil; }

- (id) initForWritingWithMutableData:(NSMutableData*)mdata
{
	[(id)self initForWritingToStream: [MemoryStream streamWithData: mdata]];
	return self;
}

- (id) initForReadingWithData:(NSData*)data
{
	id r = [[self class] newReadingFromStream:[MemoryStream streamWithData:data]];

	[self release];

	return r;
}
															// Archiving Data 
+ (NSData*) archivedDataWithRootObject:(id)rootObject
{
	id d = [[NSMutableData alloc] init];
	id a = [[NSArchiver alloc] initForWritingWithMutableData:d];

	[a encodeRootObject:rootObject];

	return [d autorelease];
}

+ (BOOL) archiveRootObject:(id)rootObject toFile:(NSString*)path
{												// FIX ME fix this return value 
	id d = [self archivedDataWithRootObject:rootObject];

	[d writeToFile:path atomically:NO];

	return YES;
}
											// Getting data from the archiver
+ unarchiveObjectWithData:(NSData*)data
{
	return [(Class)self decodeObjectWithName: NULL
						fromStream: [MemoryStream streamWithData:data]];
}

@end  /* NSPortCoder */

/* ****************************************************************************

 		PortEncoder

** ***************************************************************************/

/* xxx For experimentation.  The function in objc-api.h doesn't always
   work for objects; it sometimes returns YES for an instance. */
/* But, metaclasses return YES too? */

static BOOL
my_object_is_class(id object)
{
	if (object != nil && CLS_ISMETA(((Class)object)->class_pointer)
			&& ((Class)object)->class_pointer !=((Class)object)->class_pointer)
		return YES;

	return NO;
}

@implementation PortEncoder

+ (int) defaultFormatVersion				{ return default_format_version; }
+ (void) setDefaultFormatVersion:(int)f		{ default_format_version = f; }
+ (void) setDefaultCStreamClass:(id)sc		{ default_cstream_class = sc; }
+ (void) setDefaultStreamClass:(id)sc		{ default_stream_class = sc; }
+ (id) defaultCStreamClass					{ return default_cstream_class; }
+ (id) defaultStreamClass					{ return default_stream_class; }

- (const char *) defaultDecoderClassname	{ return "PortDecoder"; }

- (void) writeSignature
{							// Careful: the string should not contain newlines.
	[[cstream stream] writeFormat: SIGNATURE_FORMAT_STRING, SIGNATURE_ARGS];
}

- (id) initForWritingToStream:(id <Streaming>)s		// designated initializer
			withFormatVersion:(int)version
			cStreamClass:(Class)cStreamClass
			cStreamFormatVersion:(int)cStreamFormatVersion
{
	id cs = [[cStreamClass alloc] initForWritingToStream: s
							 withFormatVersion: cStreamFormatVersion];

	[super _initWithCStream:cs formatVersion:version];

	[cstream release];
	in_progress_table = NULL;
	object_2_xref = NULL;
	object_2_fref = NULL;
	const_ptr_2_xref = NULL;
	fref_counter = 0;
	[self writeSignature];

	return self;
}

- (id) initForWritingToStream:(id <Streaming>)s
{
	Class cStreamClass = [[self class] defaultCStreamClass];

	return [self initForWritingToStream: s
				 withFormatVersion: DEFAULT_FORMAT_VERSION
				 cStreamClass: cStreamClass
				 cStreamFormatVersion: [cStreamClass defaultFormatVersion]];
}

+ (id) newWritingToStream:(id <Streaming>)s
{
	return [[self alloc] initForWritingToStream: s];
}

+ (BOOL) encodeRootObject: anObject
		 withName:(NSString*) name
		 toStream:(id <Streaming>)stream
{
	id c = [[self alloc] initForWritingToStream: stream];

	[c encodeRootObject: anObject withName: name];
	[c close];
	[c release];
	
	return YES;
}
/* Functions and methods for keeping cross-references
   so objects aren't written/read twice. */

/* These _coder... methods may be overriden by subclasses so that 
   cross-references can be kept differently.

   For instance, ConnectedCoder keeps cross-references to const
   pointers on a per-Connection basis instead of a per-Coder basis.
   We avoid encoding/decoding the same classes and selectors over and
   over again.
*/
- (NSUInteger) _coderCreateReferenceForObject:(id)anObj
{
	NSUInteger xref;

	if (!object_2_xref)
		object_2_xref = NSCreateMapTable(NSNonOwnedPointerOrNullMapKeyCallBacks,
										NSIntMapValueCallBacks, 0);

	xref = NSCountMapTable (object_2_xref) + 1;
	NSMapInsert (object_2_xref, anObj, UINT2PTR(xref));

	return xref;
}

- (NSUInteger) _coderReferenceForObject:(id)anObject
{
	if (object_2_xref)
		return PTR2UINT( NSMapGet (object_2_xref, anObject));

	return 0;
}
		// Using the next three methods, subclasses can change the way that
		// const pointers (like SEL, Class, Atomic strings, etc) are archived.
								// Cache the const ptr's in the Connection, not 
								// separately for each created PortCoder.
- (NSUInteger) _coderReferenceForConstPtr:(const void*)ptr
{
	return [connection _encoderReferenceForConstPtr: ptr];
}

- (NSUInteger) _coderCreateReferenceForConstPtr:(const void*)ptr
{
	return [connection _encoderCreateReferenceForConstPtr: ptr];
}
											// Methods for forward references
- (NSUInteger) _coderCreateForwardReferenceForObject:(id)anObject
{
	NSUInteger fref;

	if (!object_2_fref)
		object_2_fref = NSCreateMapTable ( 
							NSNonOwnedPointerOrNullMapKeyCallBacks,
							NSIntMapValueCallBacks, 0);
	fref = ++fref_counter;
	NSAssert(! NSMapGet (object_2_fref, anObject), @"anObject already in Map");
	NSMapInsert (object_2_fref, anObject, UINT2PTR(fref));

	return fref;
}

- (NSUInteger) _coderForwardReferenceForObject:(id)anObject
{
	if (!object_2_fref)			// This method must return 0 if it's not there.
		return 0;

	return PTR2UINT( NSMapGet (object_2_fref, anObject));
}

- (void) _coderRemoveForwardReferenceForObject:(id)anObject
{
	NSMapRemove (object_2_fref, anObject);
}

/* This is the Coder's interface to the over-ridable
   "_coderPutObject:atReference" method.  Do not override it.  It
   handles the root_object_table. */

- (void) _coderInternalCreateReferenceForObject:(id)anObj
{
	[self _coderCreateReferenceForObject: anObj];
}

/* Handling the in_progress_table.  These are called before and after
   the actual object (not a forward or backward reference) is encoded.

   One of these objects should also call
   -_coderInternalCreateReferenceForObject:.  GNU archiving calls it
   in the first, in order to force forward references to objects that
   are in progress; this allows for -initWithCoder: methods that
   deallocate self, and return another object.  OpenStep-style coding
   calls it in the second, meaning that we never create forward
   references to objects that are in progress; we encode a backward
   reference to the in progress object, and assume that it will not
   change location. */

- (void) _objectWillBeInProgress:(id)anObj
{						// This is "NonOwnedPointer", and not "Object", because
						// with "Object" we would get an infinite loop with 
						// distributed objects when we try to put a Proxy in in 
						// the table, and send the proxy the -hash method.
	if (!in_progress_table)
		in_progress_table = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks, 
											 NSIntMapValueCallBacks, 0);
	
	NSMapInsert (in_progress_table, anObj, (void*)1);
}

- (void) _objectNoLongerInProgress:(id)anObj
{
	NSMapRemove (in_progress_table, anObj);
  /* Register that we have encoded it so that future encoding can 
     do backward references properly. */
	[self _coderInternalCreateReferenceForObject: anObj];
}
												// Method for encoding things.
- (void) encodeValueOfCType:(const char*)type 
						 at:(const void*)d 
						 withName:(NSString*)name
{
	[cstream encodeValueOfCType:type at:d withName:name];
}

- (void) encodeBytes:(const void *)b
			   count:(unsigned)c
			   withName:(NSString*)name
{
	// Is this what we want?  It won't be cleanly readable in TextCStream's.
	[cstream encodeName: name];
	[[cstream stream] writeBytes: b length: c];
}

- (void) encodeTag:(unsigned char)t
{
	if ([cstream respondsToSelector: @selector(encodeTag:)])
		[(id)cstream encodeTag:t];
	else
		[self encodeValueOfCType:@encode(unsigned char) 
			  at:&t 
			  withName:@"Coder tag"];
}

- (void) encodeClass:(Class)aClass 
{
	[self encodeIndent];
	if (aClass == Nil)
		[self encodeTag: CODER_CLASS_NIL];
	else
		{	// xxx Perhaps I should do classname substitution here.
		const char *class_name = class_get_class_name (aClass);
		NSUInteger xref;

      /* Do classname substitution, ala encodeClassName:intoClassName */
		if (classname_2_classname)
			{
			char *subst_class_name =NSMapGet(classname_2_classname,class_name);

			if (subst_class_name)
				{
				class_name = subst_class_name;
				aClass = objc_lookup_class (class_name);
				}
			}

		xref = [self _coderReferenceForConstPtr: aClass];
		if (xref)
			{	// It's already been encoded, so just encode the x-reference
			[self encodeTag: CODER_CLASS_REPEATED];
			[self encodeValueOfCType: @encode(NSUInteger)
				  at: &xref 
				  withName: @"Class cross-reference number"];
			}
		else
			{		// It hasn't been encoded before; encode it
			int class_version = class_get_version (aClass);

			NSAssert (class_name, @"Class doesn't have a name");
			NSAssert (*class_name, @"Class name is empty");

			[self encodeTag: CODER_CLASS];
			[self encodeValueOfCType: @encode(char*)
				  at: &class_name
				  withName: @"Class name"];
			[self encodeValueOfCType: @encode(int)
				  at: &class_version
				  withName: @"Class version"];
			[self _coderCreateReferenceForConstPtr: aClass];
		}	}

	[self encodeUnindent];
}

- (void) encodeAtomicString:(const char*)sp withName:(NSString*)name
{
	[self notImplemented:_cmd];		// xxx Add repeat-string-ptr checking here
	[self encodeValueOfCType:@encode(char*) at:&sp withName:name];
}

- (void) encodeSelector:(SEL)sel withName:(NSString*)name
{
	[self encodeName:name];
	[self encodeIndent];
	if (sel == 0)
		[self encodeTag: CODER_CONST_PTR_NULL];
	else
		{
		NSUInteger xref = [self _coderReferenceForConstPtr: sel];

		if (xref)
			{	// It's already been encoded, so just encode the x-reference
			[self encodeTag: CODER_CONST_PTR_REPEATED];
			[self encodeValueOfCType: @encode(NSUInteger)
				  at: &xref
				  withName: @"SEL cross-reference number"];
			}
		else
			{
			const char *sel_name;
			const char *sel_types;

			[self encodeTag: CODER_CONST_PTR];

			/* Get the selector name and type. */
			sel_name = sel_get_name(sel);
			sel_types = sel_get_type(sel);

#if 1 /* xxx Yipes,... careful... Think about something like this. */
    #ifndef __USE_LIBOBJC2__
			if (!sel_types)
				sel_types = sel_get_type (sel_get_any_typed_uid (sel_get_name (sel)));
    #endif
#endif
			if (!sel_name || !*sel_name)
				[NSException raise: NSGenericException
							 format: @"ObjC runtime didn't provide SEL name"];
			if (!sel_types || !*sel_types)
				sel_types = NO_SEL_TYPES;

			[self _coderCreateReferenceForConstPtr: sel];
			[self encodeValueOfCType: @encode(char*) 
				  at: &sel_name 
				  withName: @"SEL name"];
			[self encodeValueOfCType: @encode(char*) 
				  at: &sel_types 
				  withName: @"SEL types"];
			if (debug_coder)
				fprintf(stderr, "Coder encoding registered sel xref %u\n", xref);
		}	}

	[self encodeUnindent];
}

- (void) encodeValueOfObjCType:(const char*) type 
							at:(const void*) d 
							withName:(NSString*) name
{
	switch (*type)
		{
		case _C_CLASS:
			[self encodeName: name];
			[self encodeClass: *(id*)d];
			break;
		case _C_ATOM:
			[self encodeAtomicString: *(char**)d withName: name];
			break;
		case _C_SEL:
			[self encodeSelector: *(SEL*)d withName: name];
			break;
		case _C_ID:
			[self encodeObject: *(id*)d withName: name];
			break;
		default:
			[self encodeValueOfCType:type at:d withName:name];
		}
}
								// Methods for handling interconnected objects
- (void) startEncodingInterconnectedObjects		{ interconnect_stack_height++;}

- (void) finishEncodingInterconnectedObjects
{
  /* xxx Perhaps we should look at the forward references and
     encode here any forward-referenced objects that haven't been
     encoded yet.  No---the current behavior implements NeXT's
     -encodeConditionalObject: */
	NSParameterAssert (interconnect_stack_height);
	interconnect_stack_height--;
}

- (void) encodeRootObject:(id)anObj withName:(NSString*)name
{								// Unlike NeXT's this CAN be called recursively
	[self encodeName: @"Root Object"];
	[self encodeIndent];
	[self encodeTag: CODER_OBJECT_ROOT];
	[self startEncodingInterconnectedObjects];
	[self encodeObject: anObj withName: name];
	[self finishEncodingInterconnectedObjects];
	[self encodeUnindent];
}

/* These next three methods are the designated coder methods called when
   we've determined that the object has not already been
   encoded---we're not simply going to encode a cross-reference number
   to the object, we're actually going to encode an object (either a
   proxy to the object or the object itself).

   ConnectedCoder overrides _doEncodeObject: in order to implement
   the encoding of proxies. */

- (void) _doEncodeBycopyObject:(id)anObj
{
	BOOL oldBycopy = _is_by_copy;
	BOOL oldByref = _is_by_ref;
	id obj;
	Class cls;

    _is_by_copy = YES;
    _is_by_ref = NO;
    obj = [anObj replacementObjectForPortCoder:(NSPortCoder*)self];
    cls = [obj classForPortCoder];
    [self encodeClass: cls];
    [obj encodeWithCoder:(NSCoder*)self];
    _is_by_copy = oldBycopy;
    _is_by_ref = oldByref;
}

- (void) _doEncodeByrefObject:(id)anObj
{
	BOOL oldBycopy = _is_by_copy;
	BOOL oldByref = _is_by_ref;
	id obj;
	Class cls;

    _is_by_copy = NO;
    _is_by_ref = YES;
    obj = [anObj replacementObjectForPortCoder:(NSPortCoder*)self];
    cls = [obj classForPortCoder];
    [self encodeClass: cls];
    [obj encodeWithCoder:(NSCoder*)self];
    _is_by_copy = oldBycopy;
    _is_by_ref = oldByref;
}
		//	These three methods are called by Coder's designated object encoder
		//	when an object is to be sent over the wire with or without bycopy /
		//	byref.  We make sure that if the object asks us whether it is to be
		//	sent bycopy or byref it is told the right thing.
- (void) _doEncodeObject:(id)anObj
{
	id obj = [anObj replacementObjectForPortCoder:(NSPortCoder*)self];
	Class cls = [obj classForPortCoder];

	[self encodeClass: cls];
	[obj encodeWithCoder:(NSCoder*)self];
}

- (void) _encodeObject:(id)anObj				// designated object encoder
			  withName:(NSString*) name
			  isBycopy:(BOOL) bycopy_flag
			  isByref:(BOOL) byref_flag
			  isForwardReference:(BOOL) forward_ref_flag
{
	[self encodeName:name];
	[self encodeIndent];
	if (!anObj)
		[self encodeTag:CODER_OBJECT_NIL];
	else 
		if (my_object_is_class(anObj))
			{
			[self encodeTag: CODER_OBJECT_CLASS];
			[self encodeClass:anObj];
			}
		else
			{
			NSUInteger xref = [self _coderReferenceForObject: anObj];
			if (xref)
				{  // It's already been encoded, so just encode the x-reference
				[self encodeTag: CODER_OBJECT_REPEATED];
				[self encodeValueOfCType: @encode(NSUInteger)
					  at: &xref 
					  withName: @"Object cross-reference number"];
				}
			else 
				if (forward_ref_flag || (in_progress_table 
						&& NSMapGet (in_progress_table, anObj)))
					{				// About to Encode a forward reference,
					NSUInteger fref;	// either because (1) our caller asked for 
									// it, or (2) we are in the middle of 
									// encoding this object, and haven't 
									// finished encoding it yet.
									// Find out if it already has a forward 
									// reference number. If doesn't, create one
					if (!(fref = [self _coderForwardReferenceForObject:anObj]))
					   fref=[self _coderCreateForwardReferenceForObject:anObj];
					[self encodeTag: CODER_OBJECT_FORWARD_REFERENCE];
					[self encodeValueOfCType: @encode(NSUInteger)
						  at: &fref 
						  withName: @"Object forward cross-reference number"];
					}
				else				// No backward or forward references, we
					{				// are going to encode the object.
					NSUInteger fref;
									// Register the object as being in progress 
									// of encoding. In OS-style archiving, this 
									// method also calls
									// -_coderInternalCreateReferenceForObject:
					[self _objectWillBeInProgress: anObj];

					[self encodeTag: CODER_OBJECT];		// Encode the object
					[self encodeIndent];
					if (bycopy_flag)
						[self _doEncodeBycopyObject:anObj];
					else 
						if (byref_flag)
							[self _doEncodeByrefObject:anObj];
						else
							[self _doEncodeObject:anObj];	    
					[self encodeUnindent];
	
			/* Find out if this object satisfies any forward references,
				and encode either the forward reference number, or a
				zero.  NOTE: This test is here, and not before the
				_doEncode.., because the encoding of this object may,
				itself, generate a "forward reference" to this object,
				(ala the in_progress_table).  That is, we cannot know
				whether this object satisfies a forward reference until
				after it has been encoded. */

					if ((fref = [self _coderForwardReferenceForObject: anObj]))
						{
				/* It does satisfy a forward reference; write the forward 
				reference number, so the decoder can know. */
						[self encodeValueOfCType: @encode(NSUInteger)
							  at: &fref 
							withName:@"Object forward cross-reference number"];
			/* Remove it from the forward reference table, since we'll never
				have another forward reference for this object. */
						[self _coderRemoveForwardReferenceForObject: anObj];
						}
					else
						{
						NSUInteger null_fref = 0;

				/* It does not satisfy any forward references.  Let the
				decoder know this by encoding NULL.  Note: in future
				encoding we may have backward references to this
				object, but we will never need forward references to
				this object.  */
						[self encodeValueOfCType: @encode(NSUInteger)
							  at: &null_fref 
							withName:@"Object forward cross-reference number"];
						}
	
						// Done encoding the object, it's no longer in progress
						// In GNU-style archiving, this method also calls
						// -_coderInternalCreateReferenceForObject:
					[self _objectNoLongerInProgress: anObj];
			}		}

	[self encodeUnindent];
}

- (void) encodeObject:(id)anObj withName:(NSString*)name
{
	[self _encodeObject:anObj
		  withName:name
		  isBycopy:NO
		  isByref:NO
		  isForwardReference:NO];
}

- (void) encodeBycopyObject:(id)anObj withName:(NSString*)name
{
	[self _encodeObject:anObj
		  withName:name
		  isBycopy:YES
		  isByref:NO
		  isForwardReference:NO];
}

- (void) encodeByrefObject:(id)anObj withName:(NSString*)name
{
	[self _encodeObject:anObj 
		  withName:name 
		  isBycopy:NO 
		  isByref:YES
		  isForwardReference:NO];
}

- (void) encodeObjectReference:(id)anObj withName:(NSString*)name
{
	[self _encodeObject:anObj
		  withName:name
		  isBycopy:NO
		  isByref:NO
		  isForwardReference:YES];
}

- (void) encodeWithName:(NSString*)name
	  valuesOfObjCTypes:(const char *)types, ...
{
	va_list ap;

	[self encodeName:name];
	va_start(ap, types);
	while (*types)
		{
		[self encodeValueOfObjCType:types
			  at:va_arg(ap, void*)
			  withName:@"Encoded Types Component"];
		types = objc_skip_typespec(types);
		}
	va_end(ap);
}

- (void) encodeValueOfObjCTypes:(const char *)types
							 at:(const void *)d
							 withName:(NSString*)name
{
	[self encodeName:name];
	while (*types)
		{
		[self encodeValueOfObjCType:types 
			  at:d
			  withName:@"Encoded Types Component"];
		types = objc_skip_typespec(types);
		}
}

- (void) encodeArrayOfObjCType:(const char *)type
						 count:(unsigned)c
						 at:(const void *)d
						 withName:(NSString*)name
{
	int i;
	int offset = objc_sizeof_type(type);
	const char *where = d;

  [self encodeName:name];
  for (i = 0; i < c; i++)
		{
		[self encodeValueOfObjCType:type
			  at:where
			  withName:@"Encoded Array Component"];
		where += offset;
		}
}

- (void) encodeArrayOfObjCType:(const char *)type
						 count:(unsigned)c
						 at:(const void *)d
{
	int i;
	int offset = objc_sizeof_type(type);
	const char *where = d;

  for (i = 0; i < c; i++)
		{
		[self encodeValueOfObjCType:type
			  at:where
			  withName:@"Encoded Array Component"];
		where += offset;
		}
}

- (void) encodeIndent					{ [cstream encodeIndent]; }
- (void) encodeUnindent					{ [cstream encodeUnindent]; }
- (void) encodeName:(NSString*)n		{ [cstream encodeName: n]; }

														// Substituting Classes
- (NSString*) classNameEncodedForTrueClassName:(NSString*)trueName
													{ return NIMP; }
- (void) encodeClassName:(NSString*)trueName
		   intoClassName:(NSString*)inArchiveName	{ NIMP; }

- (void) dealloc
{
	if (in_progress_table) 
		NSFreeMapTable (in_progress_table);
	if (object_2_xref) 
		NSFreeMapTable (object_2_xref);
	if (object_2_fref) 
		NSFreeMapTable (object_2_fref);
	if (const_ptr_2_xref) 
		NSFreeMapTable (const_ptr_2_xref);
	if (classname_2_classname) 
		NSFreeMapTable (classname_2_classname);
	[super dealloc];
}

- (id) _initForWritingWithConnection:(NSConnection*)c
					  sequenceNumber:(int)n
					  identifier:(int)i
{
	NSPortMessage *packet;

	packet = [NSPortMessage _portMessageWithSendPort: [c receivePort]
							receivePort: nil
							capacity: DEFAULT_SIZE];

	[self initForWritingToStream: packet];
	[packet release];
	connection = c;
	sequence_number = n;
	identifier = i;
	[self encodeValueOfCType: @encode(typeof(sequence_number))
		  at: &sequence_number
		  withName: @"PortCoder sequence number"];
	[self encodeValueOfCType: @encode(typeof(identifier))
		  at: &identifier
		  withName: @"PortCoder identifier"];

	return self;
}

- (void) dismiss
{
	id packet = [cstream stream];

	NS_DURING
		[[connection sendPort] sendPacket: packet
							   timeout: [connection requestTimeout]];
	NS_HANDLER
		{
		if (debug_connected_coder)
			fprintf(stderr, "dismiss 0x%x: #=%d i=%d write failed - %s\n",
					self, sequence_number, identifier,
					[[localException reason] cString]);
		if ([[connection sendPort] isValid])
			[[connection sendPort] invalidate];
		}
	NS_ENDHANDLER

	if (debug_connected_coder)
		fprintf(stderr, "dismiss 0x%x: #=%d i=%d %d\n",
				self, sequence_number, identifier,
	[packet streamEofPosition]);
	[self release];
}
															// Access to ivars.
- (BOOL) isBycopy					{ return _is_by_copy; }
- (BOOL) isByref					{ return _is_by_ref; }

@end  /* PortEncoder */

/* ****************************************************************************

 		PortDecoder

** ***************************************************************************/

@implementation PortDecoder

+ (void) readSignatureFromCStream:(id <CStreaming>)cs
					 getClassname:(char *) name
					 formatVersion:(int*) version
{
	char package_name[64];
	int major_version;
	int got = [[cs stream] readFormat: SIGNATURE_FORMAT_STRING,
										&package_name, 
										&major_version,
										name, version];
	if (got != 4)
		[NSException raise: @"CoderSignatureMalformedException"
					 format: @"Decoder found a malformed signature"];
}

+ newReadingFromStream:(id <Streaming>)stream
{													// designated initializer.
	id cs = [CStream cStreamReadingFromStream: stream];
	char name[128];										// Max classname length.
	int ver;
	PortDecoder *new_coder;

	[self readSignatureFromCStream:cs getClassname:name formatVersion:&ver];
	
	new_coder = [[objc_lookup_class(name) alloc] _initWithCStream: cs
												 formatVersion: ver];
	new_coder->xref_2_object = NULL;
	new_coder->xref_2_object_root = NULL;
	new_coder->fref_2_object = NULL;
	new_coder->address_2_fref = NULL;

	return new_coder;
}

+ decodeObjectWithName:(NSString* *) name
			fromStream:(id <Streaming>)stream
{
	id o, c = [self newReadingFromStream:stream];

	[c decodeObjectAt: &o withName: name];
	[c release];

	return [o autorelease];
}
/* Functions and methods for keeping cross-references
   so objects that were already read can be referred to again. */

/* These _coder... methods may be overriden by subclasses so that 
   cross-references can be kept differently. */

- (NSUInteger) _coderCreateReferenceForObject:(id)anObj
{
	if (!xref_2_object)
		{
		xref_2_object = [NSMutableArray new];
      /* Append an object so our xref numbers are in sync with the 
		Encoders, which start at 1. */
		[xref_2_object addObject: _dummyObject];
		}
	if (debug_coder)
		fprintf (stderr, "Decoder registering object xref %u\n",
				[xref_2_object count] - 1);
	[xref_2_object addObject: anObj]; // xxx but this will retain anObj.  NO.
									// This return value should be the same as 
									// the index of anObj in xref_2_object.
	return ([xref_2_object count] - 1);
}

- (void) _coderSubstituteObject: anObj atReference:(NSUInteger)xref
{
	[xref_2_object replaceObjectAtIndex: xref withObject: anObj];
}

- _coderObjectAtReference:(NSUInteger)xref
{
	NSParameterAssert (xref_2_object);

	return [xref_2_object objectAtIndex: xref];
}

/* The methods for the root object table.  The *root* object table
   (XREF_2_OBJECT_ROOT) isn't really used for much right now, but it
   may be in the future.  For now, most of the work is don't by
   XREF_2_OBJECT. */

- (void) _coderPushRootObjectTable
{
	if (!xref_2_object_root)
		xref_2_object_root = [NSMutableArray new];
}

- (void) _coderPopRootObjectTable
{
	NSParameterAssert (xref_2_object_root);
	if (!interconnect_stack_height)
		{
		[xref_2_object_root release];
		xref_2_object_root = NULL;
		}
}

- (NSUInteger) _coderCreateReferenceForInterconnectedObject: anObj
{
	if (!xref_2_object_root)
		{
		xref_2_object_root = [NSMutableArray new];
      /* Append an object so our xref numbers are in sync with the 
	 Encoders, which start at 1. */
		[xref_2_object_root addObject: _dummyObject];
		}
	[xref_2_object_root addObject: anObj];
  /* This return value should be the same as the index of anObj 
     in xref_2_object_root. */
	return ([xref_2_object_root count] - 1);
}
		// Using the next three methods, subclasses can change the way that
		// const pointers (like SEL, Class, Atomic strings, etc) are archived.
 							// Cache the const ptr's in the Connection, not 
							// separately for each created PortCoder.
- (NSUInteger) _coderCreateReferenceForConstPtr:(const void*)ptr
{
	return [connection _decoderCreateReferenceForConstPtr: ptr];
}

- (const void*) _coderConstPtrAtReference:(NSUInteger)xref
{
	return [connection _decoderConstPtrAtReference: xref];
}
						// Here are the methods for forward object references.
- (void) _coderPushForwardObjectTable
{
	if (!address_2_fref)
		address_2_fref = NSCreateMapTable (NSNonOwnedPointerMapKeyCallBacks,
											NSIntMapValueCallBacks, 0);
				    
}

- (void) _coderPopForwardObjectTable
{
	NSParameterAssert (address_2_fref);
	if (!interconnect_stack_height)
		{
		NSFreeMapTable (address_2_fref);
		address_2_fref = NULL;
		}
}

- (void) _coderSatisfyForwardReference:(NSUInteger)fref withObject:anObj
{
	NSParameterAssert (address_2_fref);
							// xxx Or should this be NSObjectMapValueCallBacks,
							// so we make sure the object doesn't get released
	if (!fref_2_object)		// before we can resolve references with it?
		fref_2_object = NSCreateMapTable (NSIntMapKeyCallBacks,
										NSNonOwnedPointerMapValueCallBacks, 0);
							// There should only be one object for each fref.
	NSAssert (!NSMapGet (fref_2_object, (void*)fref), 
				@"Should have only been one object for each fref");
	NSMapInsert (fref_2_object, UINT2PTR(fref), anObj);
}

- (void) _coderAssociateForwardReference:(NSUInteger)fref
					   withObjectAddress:(void*)addr
{
  /* Register ADDR as associated with FREF; later we will put id 
     associated with FREF at ADDR. */
	NSParameterAssert (address_2_fref);
  /* There should not be duplicate addresses */
	NSAssert (!NSMapGet (address_2_fref, addr), @"Duplicate addresses");
	NSMapInsert (address_2_fref, addr, UINT2PTR(fref));
}

- (void) _coderResolveTopForwardReferences
{
	NSMapEnumerator me;				// Enumerate the forward references and
	void *fref;						// put them at the proper addresses.
	void *addr;

	if (!address_2_fref)
		return;

  /* Go through all the addresses that are needing to be filled
     in with forward references, and put the correct object there.
     If fref_2_object does not contain an object for fref, (i.e. there 
     was no satisfier for the forward reference), put nil there. */
	me = NSEnumerateMapTable (address_2_fref);
	while (NSNextMapEnumeratorPair (&me, &addr, &fref))
		*(id*)addr = (id) NSMapGet (fref_2_object, fref);
}
						// This is the Coder's interface to the over-ridable
						// "_coderCreateReferenceForObject" method.  Do not 
						// override it.  It handles the xref_2_object_root.
- (NSUInteger) _coderInternalCreateReferenceForObject:(id)anObj
{
	NSUInteger xref = [self _coderCreateReferenceForObject: anObj];

	if (DOING_ROOT_OBJECT)
		[self _coderCreateReferenceForInterconnectedObject: anObj];
	return xref;
}

- (void) _coderInternalSubstituteObject:anObj atReference:(NSUInteger)xref
{
	[self _coderSubstituteObject:anObj atReference:xref];
	// FIX ME If we ever use the root object table, do something with it also.
}
												// Method for decoding things.
- (void) decodeValueOfCType:(const char*)type
						 at:(void*)d 
						 withName:(NSString**)namePtr
{
	[cstream decodeValueOfCType:type at:d withName:namePtr];
}

- (void) decodeBytes:(void *)b count:(unsigned)c withName:(NSString**)name
{
	int actual_count;
	// Is this what we want?  It won't be cleanly readable in TextCStream's.
	[cstream decodeName: name];
	actual_count = [[cstream stream] readBytes: b length: c];
	NSAssert2 (actual_count == c, @"expected to read %d bytes, read %d bytes", 
				c, actual_count);
}

- (unsigned char) decodeTag
{
	unsigned char t;

	if ([cstream respondsToSelector: @selector(decodeTag)])
		return [(id)cstream decodeTag];

	[self decodeValueOfCType:@encode(unsigned char) at:&t withName:NULL];

	return t;
}

- (id) decodeClass
{
	unsigned char tag;
	char *class_name;
	int class_version;
	id ret = Nil;
  
	[self decodeIndent];
	switch ((tag = [self decodeTag]))
		{
		case CODER_CLASS_NIL:
			break;
		case CODER_CLASS_REPEATED:
			{
			NSUInteger xref;
			[self decodeValueOfCType: @encode(NSUInteger)
				  at: &xref
				  withName: NULL];
			ret = (id) [self _coderConstPtrAtReference: xref];
			if (!ret)
				[NSException raise: NSGenericException format: 
				@"repeated class cross-reference number %u not found", xref];
			break;
			}
		case CODER_CLASS:
			{
			[self decodeValueOfCType: @encode(char*)
				  at: &class_name
				  withName: NULL];
			[self decodeValueOfCType: @encode(int)
				  at: &class_version
				  withName: NULL];
	
		/* xxx should do classname substitution, 
			ala decodeClassName:intoClassName: here. */
	
			ret = objc_lookup_class (class_name);
		/* Ensure that the [+initialize] method has been called for the
			class by calling one of it's methods */
			if (ret != Nil)
				ret = [ret class];
			if (ret == Nil)
				[NSException raise: NSGenericException
							 format: @"Couldn't find class `%s'", class_name];
			if (class_get_version(ret) != class_version)
				[NSException raise: NSGenericException format: 
					@"Class version mismatch, executable %d != encoded %d",
					class_get_version(ret), class_version];
	
			{
			NSUInteger xref = [self _coderCreateReferenceForConstPtr: ret];

			if (debug_coder)
				fprintf(stderr,
						"Decoder decoding registered class xref %u\n", xref);
			}
			free (class_name);
			break;
			}
		default:
			[NSException raise: NSGenericException
						 format: @"unrecognized class tag = %d", (int)tag];
		}

	[self decodeUnindent];

	return ret;
}

- (const char *) decodeAtomicStringWithName:(NSString **)name
{
	char *s;
								// FIX ME Add repeat-string-ptr checking here
	[self notImplemented:_cmd];
	[self decodeValueOfCType:@encode(char*) at:&s withName:name];

	return s;
}

- (SEL) decodeSelectorWithName:(NSString **)name
{
	char tag;
	SEL ret = NULL;

	[self decodeName:name];
	[self decodeIndent];
	switch ((tag = [self decodeTag]))
    	{
		case CODER_CONST_PTR_NULL:
			break;
		case CODER_CONST_PTR_REPEATED:
			{
			NSUInteger xref;

			[self decodeValueOfCType: @encode(NSUInteger)
				  at: &xref
				  withName: NULL];
			if (!(ret = (SEL) [self _coderConstPtrAtReference: xref]))
				[NSException raise: NSGenericException format:
				@"repeated selector cross-reference number %u not found",xref];
			break;
			}
		case CODER_CONST_PTR:
			{
			char *sel_name;
			char *sel_types;
			
			[self decodeValueOfCType:@encode(char *)
				  at:&sel_name
				  withName:NULL];
			[self decodeValueOfCType:@encode(char *) 
				  at:&sel_types 
				  withName:NULL];
			if (!strcmp(sel_types, NO_SEL_TYPES))
				ret = sel_get_any_uid(sel_name);
			else
				ret = sel_get_typed_uid(sel_name, sel_types);
			
			if (!ret)
				[NSException raise: NSGenericException
					format: @"Could not find selector (%s) with types [%s]",
					sel_name, sel_types];
			
#ifdef __USE_LIBOBJC2__
			if (strcmp(sel_types, NO_SEL_TYPES) && !(sel_types_match(sel_types, sel_getType_np(ret))))
#else
			if (strcmp(sel_types, NO_SEL_TYPES) && !(sel_types_match(sel_types, sel_get_type(ret))))
#endif
					[NSException raise: NSGenericException
					format: @"ObjC runtime didn't provide SEL with matching type"];
				{
				NSUInteger xref = [self _coderCreateReferenceForConstPtr: ret];
				if (debug_coder)
					fprintf(stderr, "Decoder decoding registered sel xref %u\n", xref);
				}
			free(sel_name);
			free(sel_types);
			break;
			}
		default:
			[NSException raise: NSGenericException
						 format: @"unrecognized selector tag = %d", (int)tag];
		}
	[self decodeUnindent];

	return ret;
}

- (void) startDecodingInterconnectedObjects
{
	interconnect_stack_height++;
	[self _coderPushRootObjectTable];
	[self _coderPushForwardObjectTable];
}

- (void) finishDecodingInterconnectedObjects
{
	NSParameterAssert (interconnect_stack_height);
	
	/* xxx This might not be the right thing to do; perhaps we should do
		this finishing up work at the end of each nested call, not just
		at the end of all nested calls.
		However, then we might miss some forward references that we could
		have resolved otherwise. */
	if (--interconnect_stack_height)
		return;
	
	/* xxx fix the use of _coderPopForwardObjectTable and
		_coderPopRootObjectTable. */
	
	/* resolve object forward references */
	[self _coderResolveTopForwardReferences];
	[self _coderPopForwardObjectTable];
	
	[self _coderPopRootObjectTable];
}

- (void) _decodeRootObjectAt:(id*)ret withName:(NSString**) name
{
	[self startDecodingInterconnectedObjects];
	[self decodeObjectAt:ret withName:name];
	[self finishDecodingInterconnectedObjects];
}

- (void) decodeValueOfObjCType:(const char*)type
							at:(void*)d 
							withName:(NSString**)namePtr
{
	switch (*type)					// FIX ME need to catch unions and make a 
		{							// sensible error message
		case _C_CLASS:
			{
			[self decodeName:namePtr];
			*(id*)d = [self decodeClass];
			break;
			}
		case _C_ATOM:
			*(const char**)d = [self decodeAtomicStringWithName:namePtr];
			break;
		case _C_SEL:
			*(SEL*)d = [self decodeSelectorWithName:namePtr];
			break;
		case _C_ID:
			[self decodeObjectAt:d withName:namePtr];
			break;
		default:
			[self decodeValueOfCType:type at:d withName:namePtr];
		}
}
					// This is the designated (and one-and-only) object decoder
- (void) decodeObjectAt:(id*) anObjPtr withName:(NSString**) name
{
	unsigned char tag;
	NSUInteger fref = 0;
	id dummy_object;

  /* Sometimes the user wants to decode an object, but doesn't care to
     have a pointer to it, (LinkedList elements, for example).  In
     this case, the user can pass in NULL for anObjPtr, and all will
     be safe. */
	if (!anObjPtr)
		anObjPtr = &dummy_object;
	
	[self decodeName:name];
	[self decodeIndent];
	tag = [self decodeTag];
	switch (tag)
		{
    	case CODER_OBJECT_NIL:
      		*anObjPtr = nil;
			break;
		case CODER_OBJECT_CLASS:
			*anObjPtr = [self decodeClass];
			break;
		case CODER_OBJECT_FORWARD_REFERENCE:
			{
			if (!DOING_ROOT_OBJECT)
				[NSException raise: NSGenericException
				format: @"can't decode forward reference when not decoding "
						@"a root object"];
			[self decodeValueOfCType:@encode(NSUInteger) at:&fref withName:NULL];
	/* The user doesn't need the object pointer anyway, don't record
	   it in the table. */
			if (anObjPtr == &dummy_object)
				break;
			[self _coderAssociateForwardReference: fref 
				  withObjectAddress: anObjPtr];
			break;
			}
		case CODER_OBJECT:
			{
			Class object_class;
			SEL new_sel = sel_get_any_uid ("newWithCoder:");
			Method* new_method;
			BOOL create_ref_before_init = NO;
			IMP newWithCoder = NULL;
			/* Initialize this to <0 so we can tell below if it's been set */
			int xref = -1;

			[self decodeIndent];
			object_class = [self decodeClass];

#ifdef NEW_RUNTIME
		Method m = class_getClassMethod (object_getClass(object_class), new_sel);
		if (m)	// use class_getClassMethod first to avoid forwarding
			newWithCoder = class_getMethodImplementation (object_getClass(object_class), new_sel);
		if (newWithCoder && !create_ref_before_init)
			*anObjPtr = (*(newWithCoder))(object_class, new_sel, self);
#else
		/* xxx Should change the runtime.
			class_get_class_method should take the class as its first
			argument, not the metaclass! */
		new_method = class_get_class_method(class_get_meta_class(object_class), new_sel);
		if (new_method && !create_ref_before_init)
			*anObjPtr = (*(new_method->method_imp))(object_class,new_sel,self);
#endif
		else
			{
			SEL init_sel = sel_get_any_uid ("initWithCoder:");
#ifdef NEW_RUNTIME
//			Method m = class_getInstanceMethod (object_class, init_sel);
			IMP initWithCoder = class_getMethodImplementation (object_class, init_sel);
#else
			Method *init_method = class_get_instance_method (object_class, init_sel);
#endif
			/* xxx Or should I send +alloc? */
			*anObjPtr = (id) NSAllocateObject (object_class);
			if (create_ref_before_init)
				xref = [self _coderInternalCreateReferenceForObject:*anObjPtr];
#ifdef NEW_RUNTIME
			if (initWithCoder)
				*anObjPtr = (*(initWithCoder))(*anObjPtr, init_sel, self);
#else
			if (init_method)
				*anObjPtr = (*(init_method->method_imp))(*anObjPtr, init_sel, self);
#endif
			/* xxx else what, error? */
			}

	/* Send -awakeAfterUsingCoder: */
	/* xxx Unknown whether -awakeAfterUsingCoder: should be sent here, or
	   when Decoder is deallocated, or after a root object is finished
	   decoding. */
	/* NOTE: Use of this with the NeXT archiving methods is
	   tricky, because if [*anObj initWithCoder:] creates any
	   objects that references *anObj, and if [*anObj
	   awakeAfterUsingCoder:] replaces itself, then the
	   subobject's references will not be to the replacement.
	   There is no way to magically fix this circular dependancy;
	   users must be aware.  We should just make sure we require
	   the same cautions as NeXT's implementation.  Note that, with
	   the GNU archiving methods, this problem doesn't occur because
	   we don't register the object until after it has been fully
	   initialized and awakened. */
		{
		SEL awake_sel = sel_get_any_uid ("awakeAfterUsingCoder:");
		IMP awake_imp = objc_msg_lookup (*anObjPtr, awake_sel);
		id replacement;

			if (awake_imp)
				{
				replacement = (*awake_imp) (*anObjPtr, awake_sel, self);
		
				if (replacement != *anObjPtr)
					{
					if (xref > 0)
						[self _coderInternalSubstituteObject:replacement 
								atReference:xref];
					*anObjPtr = replacement;
			}	}	}

			[self decodeUnindent];

			// If this was a CODER_OBJECT_FORWARD_SATISFIER, then remember it.
			[self decodeValueOfCType: @encode(NSUInteger)
				  at: &fref 
				  withName: NULL];
			if (fref)
				{
				NSAssert (!create_ref_before_init,
					@"You are trying to decode an object with the non-GNU\n"
					@"OpenStep-style forward references, but the object's\n"
					@"decoding mechanism wants to use GNU features.");
				[self _coderSatisfyForwardReference:fref withObject:*anObjPtr];
				}

				// Would get error here with Connection-wide object references
				// because addProxy gets called in +newRemote:connection:
			if (!create_ref_before_init)
				{
				NSUInteger xref;

				xref = [self _coderInternalCreateReferenceForObject:*anObjPtr];
				if (debug_coder)
				  fprintf(stderr,"Decoder decoding registered class xref %u\n", xref);
				}
			break;
			}
		case CODER_OBJECT_ROOT:
			{
			[self _decodeRootObjectAt: anObjPtr withName: name];
			break;
			}
		case CODER_OBJECT_REPEATED:
			{
			NSUInteger xref;
		
			[self decodeValueOfCType: @encode(NSUInteger)
				  at: &xref 
				  withName: NULL];
			*anObjPtr = [[self _coderObjectAtReference: xref] retain];
			if (!*anObjPtr)
				[NSException raise: NSGenericException format: 
				@"repeated object cross-reference number %u not found", xref];
			break;
			}

		default:
			[NSException raise: NSGenericException
						 format: @"unrecognized object tag = %d", (int)tag];
		}

	[self decodeUnindent];
}

- (void) decodeWithName:(NSString* *)name
		 valuesOfObjCTypes:(const char *)types, ...
{
	va_list ap;

	[self decodeName:name];
	va_start(ap, types);
	while (*types)
		{
		[self decodeValueOfObjCType:types
			  at:va_arg(ap, void*)
			  withName:NULL];
		types = objc_skip_typespec(types);
		}
	va_end(ap);
}

- (void) decodeValueOfObjCTypes:(const char *)types
							 at:(void *)d
							 withName:(NSString* *)name
{
	[self decodeName:name];
	while (*types)
		{
		[self decodeValueOfObjCType:types at:d withName:NULL];
		types = objc_skip_typespec(types);
		}
}

- (void) decodeArrayOfObjCType:(const char *)type
						 count:(unsigned)c
						 at:(void *)d
						 withName:(NSString* *) name
{
	int i;
	int offset = objc_sizeof_type(type);
	char *where = d;

	[self decodeName:name];
	for (i = 0; i < c; i++)
		{
		[self decodeValueOfObjCType:type at:where withName:NULL];
		where += offset;
		}
}

- (void) decodeArrayOfObjCType:(const char *)type
						 count:(unsigned)c
						 at:(void *)d
{
	int i;
	int offset = objc_sizeof_type(type);
	char *where = d;

	for (i = 0; i < c; i++)
		{
		[self decodeValueOfObjCType:type at:where withName:NULL];
		where += offset;
		}
}

- (void) decodeIndent						{ [cstream decodeIndent]; }
- (void) decodeUnindent						{ [cstream decodeUnindent]; }
- (void) decodeName:(NSString**)n			{ [cstream decodeName: n]; }

+ (NSString*) classNameDecodedForArchiveClassName:(NSString*)inArchiveName
{ 
	NIMP return nil; 
}

+ (void) decodeClassName:(NSString*) inArchiveName
             asClassName:(NSString *)trueName			{ NIMP }

- (void) dealloc
{
	if (xref_2_object) 
		[xref_2_object release];
	if (xref_2_object_root) 
		[xref_2_object_root release];
	if (xref_2_const_ptr) 
		NSFreeMapTable (xref_2_const_ptr);
	if (fref_2_object) 
		NSFreeMapTable (fref_2_object);
	if (address_2_fref) 
		NSFreeMapTable (address_2_fref);
	[connection release];

	[super dealloc];
}

+ (id) newDecodingWithConnection:(NSConnection*)c timeout:(int)timeout
{
	PortDecoder *cd;
	id in_port = [c receivePort];						// Try to get a packet
	id packet = [in_port receivePacketWithTimeout: timeout];
	id reply_port;

	if (!packet)
		return nil;									// timeout 
												
	cd = [self newReadingFromStream: packet];		// Create new PortDecoder
	[packet release];
	reply_port = [packet replyPort];
	cd->connection = [NSConnection _connectionWithReceivePort: in_port
								   sendPort: reply_port];
													// Decode PortDecoder ivars
	[cd decodeValueOfCType: @encode(typeof(cd->sequence_number))
		at: &(cd->sequence_number)
		withName: NULL];
	[cd decodeValueOfCType: @encode(typeof(cd->identifier))
		at: &(cd->identifier)
		withName: NULL];
	
	if (debug_connected_coder)
		fprintf(stderr, "newDecoding #=%d id=%d\n",
				cd->sequence_number, cd->identifier);
	return cd;
}

+ (id) newDecodingWithPacket:(InPacket*)packet connection:(NSConnection*)c
{
	PortDecoder *cd = [self newReadingFromStream: packet];	  // Create PortDecoder
	id in_port = [c receivePort];
	id reply_port;

	[packet release];
	reply_port = [packet replyOutPort];
	cd->connection = [NSConnection _connectionWithReceivePort: in_port
								   sendPort: reply_port];
											// Decode the PortDecoder's ivars
	[cd decodeValueOfCType: @encode(typeof(cd->sequence_number))
		at: &(cd->sequence_number)
		withName: NULL];
	[cd decodeValueOfCType: @encode(typeof(cd->identifier))
		at: &(cd->identifier)
		withName: NULL];
	
	if (debug_connected_coder)
		fprintf(stderr, "newDecoding #=%d id=%d\n",
				cd->sequence_number, cd->identifier);
	return cd;
}
															// Access to ivars
- (NSPort*) replyPort	{ return (NSPort*)[(id)[cstream stream] replyPort]; }
- (void) dismiss		{ [self release]; }

@end  /* PortDecoder */
