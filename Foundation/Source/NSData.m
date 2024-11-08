/*
   NSData.m

   Byte storage wrapper classes

   Copyright (C) 1995-2020 Free Software Foundation, Inc.

   Author:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date:	March 1995
   Rewrite:	Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date:	September 1997
   mGSTEP:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	May 2005

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSData.h>
#include <Foundation/NSByteOrder.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSSerialization.h>

#include <fcntl.h>
#include <ctype.h>

#if	HAVE_MMAP
  #include <sys/mman.h>
#endif


#ifndef	_C_LNG_DBL
#define _C_LNG_DBL  'D'
#endif

#define num2char(num)  ((num) < 0xa ? ((num) + '0') : ((num) + 0x57))


static SEL __appendSel;
static IMP __appendImp;
static Class __Data;
static Class __MutableData;


@interface	_NSData : NSData
{
	NSUInteger _length;
	void *_bytes;
	BOOL _dontFree;
}
@end

@interface	_NSDataMappedFile : _NSData
@end

@interface	_NSMutableData : _NSData
{
	NSUInteger _capacity;
}
@end



@implementation NSData

+ (void) initialize
{
	__Data = [_NSData class];
	__MutableData = [_NSMutableData class];
	__appendSel = @selector(appendBytes:length:);
	__appendImp = [__MutableData instanceMethodForSelector: __appendSel];
}

+ (id) alloc
{
	return NSAllocateObject(__Data);
}

+ (id) data
{
	return [[[self alloc] init] autorelease];
}

+ (id) dataWithBytes:(const void*)bytes length:(NSUInteger)len
{
	return [[[self alloc] initWithBytes:bytes length:len] autorelease];
}

+ (id) dataWithBytesNoCopy:(void*)b length:(NSUInteger)l freeWhenDone:(BOOL)f
{
	return [[[self alloc] initWithBytesNoCopy:b
						  length:l
						  freeWhenDone:f] autorelease];
}

+ (id) dataWithBytesNoCopy:(void*)bytes length:(NSUInteger)length
{
	return [[[self alloc] initWithBytesNoCopy:bytes length:length] autorelease];
}

+ (id) dataWithContentsOfFile:(NSString*)path
{
	return [[[self alloc] initWithContentsOfFile: path] autorelease];
}

+ (id) dataWithContentsOfFile:(NSString*)path	  // FIX ME s/b designated init
					  options:(NSDataReadingOptions)options
					  error:(NSError**)error
{
	BOOL map = (options & NSDataReadingMappedAlways);

	if (map || options & NSDataReadingMappedIfSafe)
		return [self dataWithContentsOfMappedFile: path];

	// FIX ME use O_DIRECT if NSDataReadingUncached
	return [[[self alloc] initWithContentsOfFile: path] autorelease];
}

+ (id) dataWithContentsOfMappedFile:(NSString*)path
{
	id d = [[_NSDataMappedFile alloc] initWithContentsOfMappedFile:path];

	return [d autorelease];
}

+ (id) dataWithData:(NSData*)data
{
	return [[[self alloc] initWithBytes: [data bytes]
								 length: [data length]] autorelease];
}

- (id) initWithData:(NSData*)data
{
    return [self initWithBytes: [data bytes] length: [data length]];
}

- (NSString*) description		// build a cString and convert into an NSString
{
	const char *src = [self bytes];
	NSUInteger length = [self length];
	const char *name = object_get_class_name(self);
	NSUInteger i, j = strlen(name);
	char *dest;

	if ((dest = (char*) malloc(2 * length + j + length / 4+3)) == 0)
		[NSException raise: NSMallocException format: @"malloc failed"];

	strncpy(dest, name, j);
	dest[j++] = ' ';
	dest[j++] = '<';
	for (i = 0; i < length; i++, j++)
		{
		dest[j++] = num2char((src[i]>>4) & 0x0f);
		dest[j] = num2char(src[i] & 0x0f);
		if ((i&0x3) == 3 && i != length-1)
			dest[++j] = ' ';					// if we've just finished a 
		}										// 32-bit int, print a space
	dest[j++] = '>';
	dest[j] = '\0';

	return [[[NSString alloc] initWithCStringNoCopy: dest
							  length: j
							  freeWhenDone: YES] autorelease];
}

- (void) getBytes:(void*)buffer length:(NSUInteger)length
{
    [self getBytes:buffer range:NSMakeRange(0, length)];
}

- (void) getBytes:(void*)buffer range:(NSRange)aRange
{
	if (NSMaxRange(aRange) > [self length])		// Check for out of range error
		[NSException raise: NSRangeException
					 format: @"Range: (%u, %u) Size: %d",
						aRange.location, aRange.length, [self length]];
	
	memcpy(buffer, [self bytes] + aRange.location, aRange.length);
}

- (NSData*) subdataWithRange:(NSRange)aRange
{
	void *buffer;

	if (NSMaxRange(aRange) > [self length])		// Check for out of range error
		[NSException raise: NSRangeException
					 format: @"Range: (%u, %u) Size: %d",
							aRange.location, aRange.length, [self length]];

	if ((buffer = malloc(aRange.length)) == 0)
		[NSException raise: NSMallocException format: @"malloc failed"];

	[self getBytes:buffer range:aRange];

	return [NSData dataWithBytesNoCopy: buffer length: aRange.length];
}

- (const void *) bytes				{ return SUBCLASS; }
- (NSUInteger) length				{ return 0; }
- (NSUInteger) hash					{ return [self length]; }

- (BOOL) isEqual:(id)anObject
{
	if ([anObject isKindOfClass: [NSData class]])
		return [self isEqualToData: anObject];

	return NO;
}

- (BOOL) isEqualToData:(NSData*)other
{
	NSUInteger len;

	if ((len = [self length]) != [other length])
		return NO;

	return (memcmp([self bytes], [other bytes], len) ? NO : YES);
}

- (BOOL) writeToFile:(NSString*)path
			 options:(NSDataWritingOptions)options
			 error:(NSError**)error
{
	return [self writeToFile:path atomically:(options & NSDataWritingAtomic)];
}

- (BOOL) writeToFile:(NSString *)path atomically:(BOOL)atomic
{
	NSUInteger length = [self length];
	const char *file = [path fileSystemRepresentation];
	char buf[strlen(file)+8];
	int c, fd, nwrite = 0;

	strcpy(buf, file);			// Use path as prefix to mktemp() call so that
	if (atomic)					// both files are on the same filesystem and
		{						// the subsequent rename() will work
		strcat(buf, "XXXXXX");
		if (mktemp(buf) == 0)
			{
			NSLog(@"mktemp (%s) failed - %s", buf, strerror(errno));
			return NO;
		}	}

	if ((fd = open(buf, (O_WRONLY | O_CREAT | O_EXCL), 0700)) < 0)
		{
		NSLog(@"open of: (%s) failed - %s", buf, strerror(errno));
		return NO;
		}

	while ((c = write(fd, [self bytes] + nwrite, length-nwrite)) != 0)
		{
		if (c == -1 && errno != EINTR)
			break;
		nwrite += c;
		if (nwrite >= length)
			break;
		}

	if (nwrite < length)
		{								// failed to write all of the data
		NSLog(@"write (%s) failed - %s", buf, strerror(errno));
		close(fd);
		return NO;
		}

	if (close(fd) != 0)
		{
		NSLog(@"close (%s) failed - %s", buf, strerror(errno));
		return NO;
		}
										// if used temp rename it to real file
	if (atomic && (rename(buf, file) != 0))
		{
		NSLog(@"rename (%s) failed - %s", buf, strerror(errno));
		return NO;
		}

	return YES;
}

- (id) copy										// NSCopying, NSMutableCopying
{
    if (![self isKindOfClass: [NSMutableData class]])
		return [self retain];

	return [[__Data alloc] initWithBytes:[self bytes] length:[self length]];
}

- (id) mutableCopy
{
    return [[__MutableData alloc] initWithBytes: [self bytes]
										 length: [self length]];
}

- (id) replacementObjectForPortCoder:(NSPortCoder*)coder	{ return self; }

- (void) encodeWithCoder:(NSCoder*)coder
{
	NSUInteger len = [self length];

	[coder encodeValueOfObjCType: @encode(NSUInteger) at: &len];
	if (len)
		[coder encodeArrayOfObjCType: @encode(unsigned char)
			   count: len
			   at: [self bytes]];
}

- (id) initWithCoder:(NSCoder*)coder
{
	NSUInteger len = 0;
	void *b = 0;

	[coder decodeValueOfObjCType: @encode(NSUInteger) at: &len];
	if (len)
		{
		if ((b = malloc(len)) == NULL)
			[NSException raise:NSMallocException format:@"malloc failed"];

		[coder decodeArrayOfObjCType: @encode(unsigned char) count: len at: b];
		}

	return [self initWithBytesNoCopy: b length: len];
}

@end  /* NSData */


@implementation	_NSData

- (id) initWithBytes:(const void*)aBuffer length:(NSUInteger)size
{
	if (aBuffer != 0 && size > 0)
		{
		if ((_bytes = malloc(size)) == NULL)
			return _NSInitError(self, @"-initWithBytes:length: alloc %lu bytes failed", size);
		memcpy(_bytes, aBuffer, size);
		_length = size;
		}

	return self;
}

- (id) initWithBytesNoCopy:(void*)b length:(NSUInteger)l freeWhenDone:(BOOL)f
{
	if (f && !b)
		[NSException raise: NSInternalInconsistencyException
					 format: @"Can't init NSData object with NULL buffer."];
	_bytes = b;
	_length = l;
	_dontFree = !f;

	return self;  
}

- (id) initWithBytesNoCopy:(void*)bytes length:(NSUInteger)size
{
	return [self initWithBytesNoCopy:bytes length:size freeWhenDone:YES];  
}

- (id) initWithContentsOfFile:(NSString *)path
{
	NSInteger c, nread = 0;
	int fd;

	if ((fd = open([path fileSystemRepresentation], O_RDONLY | O_CLOEXEC)) < 0)
		return _NSInitError(self, @"-initWithContentsOfFile: unable to open %@ - %s", path, strerror(errno));

	if ((c = lseek(fd, 0, SEEK_END)) < 0)			// Seek to end of the file
		{
		c = errno;
		close(fd);

		return _NSInitError(self, @"Seek EOF failed %@ - %s", path, strerror(c));
		}
	_length = c;

	if (lseek(fd, 0, SEEK_SET) != 0)				// Seek file start
		{
		c = errno;
		close(fd);

		return _NSInitError(self, @"Seek start failed %@ - %s", path, strerror(c));
		}

    if ((_bytes = malloc(_length)) == NULL) 
		[NSException raise:NSMallocException format:@"malloc failed"];

	while ((c = read(fd, _bytes+nread, _length-nread)) != 0)
		{
		if (c == -1 && errno != EINTR)
			return _NSInitError(self, @"Read failed %@ - %s",path, strerror(errno));
		nread += c;
		}

	if (nread != _length)
		NSLog(@"NSData file: %@ length %lu != read %ld", path, _length, nread);
	if (close(fd) != 0)
		NSLog(@"close (%@) failed - %s", path, strerror(errno));

    return self;
}

- (id) initWithContentsOfMappedFile:(NSString *)path
{
	[self release];

	return [[_NSDataMappedFile alloc] initWithContentsOfMappedFile: path];
}

- (id) initWithData:(NSData*)anObject
{
	if (anObject == nil)
		return [self initWithBytes: 0 length: 0];

	if (![anObject isKindOfClass: [NSData class]])
		return _NSInitError(self, @"-initWithData: passed a non-data object");

	return [self initWithBytes: [anObject bytes] length: [anObject length]];
}

- (void) dealloc
{
	if (_bytes && !_dontFree)
		free(_bytes);
	_bytes = NULL;
	_length = 0;

	[super dealloc];
}

- (id) copy							{ return [self retain]; }

- (id) mutableCopy
{
	return [[__MutableData alloc] initWithBytes: _bytes length: _length];
}
														// NSCoding	Protocol
- (Class) classForArchiver			{ return __Data; }		// Not static 
- (Class) classForCoder				{ return __Data; }		// when decoded 
- (Class) classForPortCoder			{ return __Data; }	
- (const void *) bytes				{ return _bytes; }
- (NSUInteger) length				{ return _length; }

- (void) getBytes:(void*)buffer range:(NSRange)r
{
	if (NSMaxRange(r) > _length)
		[NSException raise:NSRangeException format:@"Range: (%u, %u) Size: %d",
												r.location, r.length, _length];
	memcpy(buffer, _bytes + r.location, r.length);
}

@end  /* _NSData */


@implementation	_NSDataMappedFile

+ (id) alloc
{
	return NSAllocateObject([_NSDataMappedFile class]);
}

- (void) dealloc
{
#if	HAVE_MMAP
	if (_bytes)
		munmap(_bytes, _length);
	_bytes = 0;
	_length = 0;
#endif

	[super dealloc];
}

- (id) initWithContentsOfMappedFile:(NSString*)path
{
	NSInteger c;
	int fd;

#ifndef	HAVE_MMAP
	return [[__Data alloc] initWithContentsOfFile: path];
#else
	if ((fd = open([path fileSystemRepresentation], O_RDONLY | O_CLOEXEC)) < 0)
		return _NSInitError(self, @"-%@ unable to open %@ - %s",
						    NSStringFromSelector(_cmd), path, strerror(errno));

	if ((c = lseek(fd, 0, SEEK_END)) < 0)	// Find size of file to be mapped
		{
		c = errno;
		close(fd);

		return _NSInitError(self, @"-%@ unable to seek to EOF %@ - %s",
						    NSStringFromSelector(_cmd), path, strerror(c));
		}
	_length = c;

	if (lseek(fd, 0, SEEK_SET) != 0)		// Position at start of file.
		{
		c = errno;
		close(fd);

		return _NSInitError(self, @"-%@ unable to seek to SOF %@ - %s",
						    NSStringFromSelector(_cmd), path, strerror(c));
		}
											// MAP_SHARED requires care & msync
	_bytes = mmap(0, _length, PROT_READ, MAP_PRIVATE, fd, 0);
	if (close(fd) != 0)
		NSLog(@"close (%@) failed - %s", path, strerror(errno));

	if (_bytes == ((void*)-1))				// mmap failed
		{
		NSLog(@"File mapping failed for %@ - %s", path, strerror(errno));
		[self release];

		return [[__Data alloc] initWithContentsOfFile: path];
		}

	return self;
#endif	/* HAVE_MMAP */
}

@end  /* _NSDataMappedFile */

/* ****************************************************************************

 		NSMutableData

** ***************************************************************************/

static NSUInteger
_MinGrowth (NSUInteger extra, NSUInteger capacity)
{
	return capacity + extra + MAX((capacity/2),1);
}

static void *
_DataRealloc (void *bytes, NSUInteger size, BOOL *dontFree, NSUInteger *cap)
{
	NSString *fm = @"Unable to set data capacity to '%d'";
	void *b = NULL;

	if (*dontFree)		// implies a copy-on-write operation so size s/b > 0
		{
		if (size != 0)	// if copy zero simply drop reference to dontfree bytes
			{
			if ((b = calloc(size,1)) == 0)
				[NSException raise: NSMallocException format: fm, size];
			else
				memcpy(b, bytes, size);
		}	}
	else if ((b = realloc(bytes, size)) == 0 && size != 0)	// size 0 is a free
		[NSException raise: NSMallocException format: fm, size];

	*dontFree = NO;		// newly allocated must be freed
	*cap = size;

	return b;
}

@implementation NSMutableData

+ (id) alloc						{ return NSAllocateObject(__MutableData); }
+ (Class) class						{ return __MutableData; }

+ (id) dataWithCapacity:(NSUInteger)c
{
	return [[[self alloc] initWithCapacity:c] autorelease];
}

+ (id) dataWithLength:(NSUInteger)length
{
	return [[[self alloc] initWithLength: length] autorelease];
}

- (void *) mutableBytes				{ return SUBCLASS; }
- (void) setLength:(NSUInteger)size	{ SUBCLASS; }

@end  /* NSMutableData */


@implementation	_NSMutableData

+ (id) alloc						{ return NSAllocateObject(__MutableData); }

- (id) initWithCapacity:(NSUInteger)size
{													// designated init #1
	if (size && ((_bytes = malloc(size)) == 0)) 
		[NSException raise:NSMallocException format:@"malloc failed"];

	_capacity = size;
	_length = 0;
	
	return self;
}

- (id) initWithBytes:(const void*)bytes length:(NSUInteger)l
{
	if ((self = [self initWithCapacity: l]) && bytes && l > 0)
		{
		memcpy(_bytes, bytes, l);
		_length = l;
		}

	return self;
}

- (id) initWithBytesNoCopy:(void*)b length:(NSUInteger)l freeWhenDone:(BOOL)f
{
	if ((_bytes = b))								// designated init #2
		{
		_dontFree = !f;
		_capacity = _length = l;
		}

	return self;
}

- (id) initWithBytesNoCopy:(void*)bytes length:(NSUInteger)size
{
	return [self initWithBytesNoCopy:bytes length:size freeWhenDone:YES];
}

- (id) initWithLength:(NSUInteger)size
{
    if ((self = [self initWithCapacity: size]) && size)
		memset(_bytes, '\0', (_length = size));

    return self;
}

- (id) initWithContentsOfFile:(NSString *)path
{
    if ((self = [self initWithCapacity: 0]) != nil)
		if ((self = [super initWithContentsOfFile:path]) != nil)
			_capacity = _length;

    return self;
}

- (id) initWithData:(NSData*)anObject
{
    if (anObject == nil) 
		return [self initWithCapacity: 0];

    if (![anObject isKindOfClass: [NSData class]]) 
		return _NSInitError(self, @"-initWithData: of non-data object");

    return [self initWithBytes: [anObject bytes] length: [anObject length]];
}

- (id) copy
{
	return [[__MutableData alloc] initWithBytes: _bytes length: _length];
}

- (void) setLength:(NSUInteger)size
{
	if (size > _capacity || (size > 0 && size < _capacity / 2))
		_bytes = _DataRealloc(_bytes, size, &_dontFree, &_capacity);
    if (size > _length)
		memset(_bytes + _length, '\0', size - _length);		// zero added
    _length = size;
}

- (void) increaseLengthBy:(NSUInteger)extraLength
{
	[self setLength: _length + extraLength];
}

- (void) _setCapacity:(NSUInteger)size
{
	if (size != _capacity)
		_bytes = _DataRealloc(_bytes, size, &_dontFree, &_capacity);
	if (_capacity < _length)
		_length = size;
}

- (void) appendBytes:(const void*)b length:(NSUInteger)size
{
    if (_length + size > _capacity)
		[self _setCapacity: _MinGrowth(size, _capacity)];

    memcpy(_bytes + _length, b, size);
    _length += size;
}

- (const void *) bytes						{ return _bytes; }
- (void *) mutableBytes						{ return _bytes; }
- (NSUInteger) length						{ return _length; }
- (NSUInteger) _capacity					{ return _capacity; }

- (void) replaceBytesInRange:(NSRange)r withBytes:(const void*)moreBytes
{
    if (NSMaxRange(r) > _length)
		[NSException raise:NSRangeException format:@"Range: (%u, %u) Size: %u",
												r.location, r.length, _length];
    memcpy(_bytes + r.location, moreBytes, r.length);
}

- (void) appendData:(NSData*)other							// Appending Data
{
	[self appendBytes: [other bytes] length: [other length]];
}

- (void) resetBytesInRange:(NSRange)r
{					  
	if (NSMaxRange(r) > _length)
		[NSException raise:NSRangeException format:@"Range: (%u, %u) Size: %d",
										r.location, r.length, [self length]];
	memset(_bytes + r.location, 0, r.length);
}

- (void) setData:(NSData*)data
{
	NSRange	r = NSMakeRange(0, [data length]);

	[self setLength: r.length];
	[self replaceBytesInRange: r withBytes: [data bytes]];
}

- (Class) classForArchiver					{ return __MutableData; }
- (Class) classForCoder						{ return __MutableData; }
- (Class) classForPortCoder					{ return __MutableData; }

@end  /* _NSMutableData */

/* ****************************************************************************

 		_NSData, _NSMutableData  (Private ArchiverExtensions)

** ***************************************************************************/

static inline void
getBytes(void *dst, void *src, NSUInteger len, NSUInteger limit, NSUInteger *pos)
{
	if (*pos > limit || len > limit || len+*pos > limit)
		[NSException raise: NSRangeException
					 format: @"Range: (%u, %u) Size: %d", *pos, len, limit];

	memcpy(dst, src + *pos, len);
	*pos += len;
}

@implementation _NSData  (_ArchiverExtensions)

- (unsigned) deserializeIntAtCursor:(NSUInteger*)cursor
{
	unsigned ni;

    [self getBytes:&ni range:(NSRange){*cursor, sizeof(unsigned)}];
    *cursor += sizeof(unsigned);

    return NSSwapBigIntToHost(ni);
}

- (void) deserializeDataAt:(void*)data
				ofObjCType:(const char*)type
				atCursor:(NSUInteger*)cursor
				context:(id <NSObjCTypeSerializationCallBack>)callback
{
    if (data == 0 || type == 0) 
		{
		if (data == 0) 
			NSLog(@"Attempt to deserialize from a NULL pointer.");
		if (type == 0)
			NSLog(@"Attempt to deserialize with a NULL type encoding.");
		return;
		}

	DBLog(@"_NSData deserialize type '%c'\n", *type);

	switch (*type) 
		{
		case _C_ID: 
			[callback deserializeObjectAt: data 
					  ofObjCType: type
					  fromData: self 
					  atCursor: cursor];
			return;

		case _C_CHARPTR: 
			{
			NSUInteger len = [self deserializeIntAtCursor: cursor];

			if (len == -1) 
				{
				*(const char**)data = NULL;
				return;
				}

			*(char**)data = (char*)malloc(len+1);
			getBytes(*(void**)data, _bytes, len, _length, cursor);
			(*(char**)data)[len] = '\0';
			return;
			}

		case _C_ARY_B: 
			{
			unsigned offset = 0;
			unsigned size;
			unsigned count = atoi(++type);
			unsigned i;
	
			while (isdigit(*type)) 
				type++;
	
			size = objc_sizeof_type(type);
	
			for (i = 0; i < count; i++) 
				{
				[self deserializeDataAt: (char*)data + offset
					  ofObjCType: type
					  atCursor: cursor
					  context: callback];
				offset += size;
				}
			return;
			}
		case _C_STRUCT_B: 
			{
			int offset = 0;
	
			while (*type != _C_STRUCT_E && *type++ != '='); // skip "<name>="
			for (;;)
				{
				[self deserializeDataAt: ((char*)data) + offset
					  ofObjCType: type
					  atCursor: cursor
					  context: callback];
				offset += objc_sizeof_type(type);
				type = objc_skip_typespec(type);
				if (*type != _C_STRUCT_E) 
					{
					int	align = objc_alignof_type(type);
					int	rem = offset % align;
		
					if (rem != 0)
						offset += align - rem;
					}
				else 
					break;
				}
			return;
			}
        case _C_PTR: 
			{
	    	unsigned len = objc_sizeof_type(++type);

			*(char**)data = (char*)malloc(len);
			[[[__Data alloc] initWithBytesNoCopy: *(void**)data 
								  length: len] autorelease];
			[self deserializeDataAt: *(char**)data
					ofObjCType: type
					atCursor: cursor
					context: callback];
			return;
			}
		case _C_CHR:
		case _C_UCHR:
		case _C_BOOL:
			getBytes(data, _bytes, sizeof(unsigned char), _length, cursor);
			return;
	
		case _C_SHT:
		case _C_USHT: 
			{
			unsigned short ns;

			getBytes((void*)&ns, _bytes, sizeof(ns), _length, cursor);
			*(unsigned short*)data = NSSwapBigShortToHost(ns);
			return;
			}
		case _C_INT:
		case _C_UINT:
			{
			unsigned ni;
	
			getBytes((void*)&ni, _bytes, sizeof(ni), _length, cursor);
			*(unsigned*)data = NSSwapBigIntToHost(ni);
			return;
			}
        case _C_LNG:
		case _C_ULNG: 
			{
			unsigned long nl;

			getBytes((void*)&nl, _bytes, sizeof(nl), _length, cursor);
			*(unsigned long*)data = NSSwapBigLongToHost(nl);
			return;
			}
        case _C_LNG_LNG:
		case _C_ULNG_LNG: 
			{
			unsigned long long nl;
	
			getBytes((void*)&nl, _bytes, sizeof(nl), _length, cursor);
			*(unsigned long long*)data = NSSwapBigLongLongToHost(nl);
			return;
			}
        case _C_FLT:
			{
			NSSwappedFloat nf;

			getBytes((void*)&nf, _bytes, sizeof(nf), _length, cursor);
			*(float*)data = NSSwapBigFloatToHost(nf);
			return;
			}

        case _C_DBL:
		case _C_LNG_DBL:		// FIX ME s/b 16 bytes
			{
			NSSwappedDouble nd;
	
			getBytes((void*)&nd, _bytes, sizeof(nd), _length, cursor);
			*(double*)data = NSSwapBigDoubleToHost(nd);
			return;
			}

		case _C_CLASS:
			{
			unsigned ni;
	
			getBytes((void*)&ni, _bytes, sizeof(ni), _length, cursor);
			if ((ni = NSSwapBigIntToHost(ni)) == 0)
				*(Class*)data = 0;
			else
				{
				char name[ni+1];
				Class c;
	
				getBytes((void*)name, _bytes, ni, _length, cursor);
				name[ni] = '\0';
				if ((c = objc_get_class(name)) == 0)
					[NSException raise: NSInternalInconsistencyException
								 format: @"can't find class - %s", name];
				*(Class*)data = c;
				}
			return;
			}
		case _C_SEL: 
			{
			unsigned ln, lt;
	
			getBytes((void*)&ln, _bytes, sizeof(ln), _length, cursor);
			ln = NSSwapBigIntToHost(ln);
			getBytes((void*)&lt, _bytes, sizeof(lt), _length, cursor);
			lt = NSSwapBigIntToHost(lt);
			if (ln == 0)
				*(SEL*)data = 0;
			else 
				{
				char name[ln+1];
				char types[lt+1];
				SEL	sel;
		
				getBytes((void*)name, _bytes, ln, _length, cursor);
				name[ln] = '\0';
				getBytes((void*)types, _bytes, lt, _length, cursor);
				types[lt] = '\0';
		
///				if (lt)
					sel = sel_get_typed_uid(name, types);
///				else
///					sel = sel_get_any_typed_uid(name);
				if (sel == 0)
					[NSException raise: NSInternalInconsistencyException
								 format: @"can't find sel with name '%s' "
										@"and types '%s'", name, types];
				*(SEL*)data = sel;
				}
			return;
			}
        default:
			[NSException raise: NSGenericException
						 format: @"Unknown type to deserialize - '%s'", type];
		}
}

@end  /* _NSData  (_ArchiverExtensions) */


@implementation _NSMutableData  (_ArchiverExtensions)

- (void) serializeDataAt:(const void*)data
			  ofObjCType:(const char*)type
			  context:(id <NSObjCTypeSerializationCallBack>)callback
{
    if (data == 0 || type == 0) 
		{
		if (data == 0) 
			NSLog(@"Attempt to serialize from a NULL pointer.");
		if (type == 0)
			NSLog(@"Attempt to serialize with a NULL type encoding.");
		return;
		}

	DBLog(@"_NSMutableData serialize type '%c'\n", *type);

    switch (*type) 
		{
        case _C_ID:
			[callback serializeObjectAt:(id*)data 
					  ofObjCType:type 
					  intoData: (NSMutableData*)self];
			return;

        case _C_CHARPTR: 
			{
			unsigned len;
			unsigned ni;

			if (!*(void**)data)
				{
				unsigned ni = NSSwapHostIntToBig(-1);
//				[self appendBytes: &ni length: sizeof(unsigned)];
				(*__appendImp)(self, __appendSel, &ni, sizeof(unsigned));
				return;
				}
			len = strlen(*(void**)data);
			ni = NSSwapHostIntToBig(len);
			if (_length + len + sizeof(unsigned) > _capacity)
				[self _setCapacity:_MinGrowth(len + sizeof(unsigned), _capacity)];
			memcpy(_bytes + _length, &ni, sizeof(unsigned));
			_length += sizeof(unsigned);
			if (len)
				{
				memcpy(_bytes + _length, *(void**)data, len);
				_length += len;
				}
			return;
			}
        case _C_ARY_B:
			{
			unsigned offset = 0;
			unsigned size;
			unsigned count = atoi(++type);
			unsigned i;

            while (isdigit(*type))
				type++;
				// Serialized objects are going to take up at least as much
				// space as the originals, so calc and alloc min space needed
			size = objc_sizeof_type(type);
			if (_length + (size * count) > _capacity)
				[self _setCapacity:_MinGrowth((size * count), _capacity)];
			
			for (i = 0; i < count; i++)
				{
				[self serializeDataAt: (char*)data + offset
					  ofObjCType: type
					  context: callback];
				offset += size;
				}
			return;
			}
        case _C_STRUCT_B:
			{
            int offset = 0;

            while (*type != _C_STRUCT_E && *type++ != '='); // skip "<name>="
            for (;;)
				{
                [self serializeDataAt: ((char*)data) + offset
					  ofObjCType: type
					  context: callback];
                offset += objc_sizeof_type(type);
                type = objc_skip_typespec(type);
                if (*type != _C_STRUCT_E)
					{
                    unsigned align = objc_alignof_type(type);
					unsigned rem = offset % align;

                    if (rem != 0)
                        offset += align - rem;
					}
                else
					break;
				}
            return;
			}
		case _C_PTR:
			[self serializeDataAt: *(char**)data
				  ofObjCType: ++type
				  context: callback];
			return;

		case _C_CHR:
		case _C_UCHR:
		case _C_BOOL:
			(*__appendImp)(self, __appendSel, data, sizeof(unsigned char));
			return;

		case _C_SHT:
		case _C_USHT:
			{
			unsigned short ns = NSSwapHostShortToBig(*(unsigned short*)data);
			(*__appendImp)(self, __appendSel, &ns, sizeof(unsigned short));
			return;
			}
		case _C_INT:
		case _C_UINT:
			{
			unsigned ni = NSSwapHostIntToBig(*(unsigned int*)data);
			(*__appendImp)(self, __appendSel, &ni, sizeof(unsigned));
			return;
			}
		case _C_LNG:
		case _C_ULNG:
			{
			unsigned long nl = NSSwapHostLongToBig(*(unsigned long*)data);
			(*__appendImp)(self, __appendSel, &nl, sizeof(unsigned long));
			return;
			}
		case _C_LNG_LNG:
		case _C_ULNG_LNG:
			{
			unsigned long long nl;
		
			nl = NSSwapHostLongLongToBig(*(unsigned long long*)data);
			(*__appendImp)(self, __appendSel, &nl, sizeof(unsigned long long));
			return;
			}
		case _C_FLT:
			{
			NSSwappedFloat nf = NSSwapHostFloatToBig(*(float*)data);

			(*__appendImp)(self, __appendSel, &nf, sizeof(NSSwappedFloat));
			return;
			}
		case _C_DBL:
		case _C_LNG_DBL:		// FIX ME s/b 16 bytes
			{
			NSSwappedDouble nd = NSSwapHostDoubleToBig(*(double*)data);
			(*__appendImp)(self, __appendSel, &nd, sizeof(NSSwappedDouble));
			return;
			}
        case _C_CLASS: 
			{
            const char *name = *(Class*)data ? (*(Class*)data)->name : "";
            unsigned ln = strlen(name);
			unsigned ni = NSSwapHostIntToBig(ln);

			if (_length + ln + sizeof(unsigned) > _capacity)
				[self _setCapacity:_MinGrowth(ln + sizeof(unsigned), _capacity)];
	    	memcpy(_bytes + _length, &ni, sizeof(unsigned));
	    	_length += sizeof(unsigned);
	    	if (ln) 
				{
				memcpy(_bytes + _length, name, ln);
				_length += ln;
	    		}
	    	return;
			}
        case _C_SEL:
			{
            const char *name = *(SEL*)data ? sel_get_name(*(SEL*)data) : "";
            unsigned ln = strlen(name);
			const char *types = *(SEL*)data ?
								(const char*) sel_get_type(*(SEL*)data) : "";
            unsigned lt = strlen(types);
	    	unsigned ni = NSSwapHostIntToBig(ln);
	    	unsigned extra = ln + lt + 2 * sizeof(unsigned);

			if (_length + extra > _capacity)
				[self _setCapacity:_MinGrowth(extra, _capacity)];
			memcpy(_bytes+_length, &ni, sizeof(unsigned));
			_length += sizeof(unsigned);
			ni = NSSwapHostIntToBig(lt);
			memcpy(_bytes + _length, &ni, sizeof(unsigned));
			_length += sizeof(unsigned);
			if (ln)
				{
				memcpy(_bytes + _length, name, ln);
				_length += ln;
				}
			if (lt)
				{
				memcpy(_bytes + _length, types, lt);
				_length += lt;
				}
			return;
			}
		default:
			[NSException raise: NSGenericException
						 format: @"Unknown type to serialize - '%s'", type];
		}
}

@end  /* _NSMutableData  (_ArchiverExtensions) */
