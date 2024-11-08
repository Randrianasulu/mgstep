/*
   NSFileManager.m

   Copyright (C) 1997-2016 Free Software Foundation, Inc.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>
   Author: Ovidiu Predescu <ovidiu@net-community.com>
   Date: Feb 1997
   mGSTEP:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Dec 2005

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSFileManager.h>
#include <Foundation/NSException.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSString.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSPathUtilities.h>

#ifndef NO_DIRENT_H
  #include <dirent.h>
#elif defined(HAVE_SYS_DIR_H)
  #include <sys/dir.h>
#elif defined(HAVE_SYS_NDIR_H)
  #include <sys/ndir.h>
#elif defined(HAVE_NDIR_H)
  #include <ndir.h>
#endif
										// determine filesystem max path length
#ifdef _POSIX_VERSION
  #include <utime.h>
#else
  #ifndef __WIN32__
	#include <sys/param.h>				// for MAXPATHLEN
  #endif
  #if HAVE_UTIME_H
	#include <utime.h>
  #endif
#endif

#ifdef HAVE_SYS_VFS_H
  #include <sys/vfs.h>
#endif

#ifdef HAVE_SYS_STATFS_H
  #include <sys/statfs.h>
#else
  #include <sys/param.h>
  #include <sys/mount.h>
  #define HAVE_SYS_STATFS_H  1
#endif

#ifdef HAVE_SYS_STATVFS_H
  #include <sys/statvfs.h>
#endif

#include <sys/stat.h>
#include <fcntl.h>

#if HAVE_PWD_H
  #include <pwd.h>						// For struct passwd
#endif


// Class variables
static NSFileManager *__fm = nil;


@interface NSFileManager (PrivateMethods)
												// Copies contents of src file 
- (BOOL) _copyFile:(NSString*)source 			// to dest file. Assumes source
			toFile:(NSString*)destination		// and dest are regular files
			handler:handler;					// or symbolic links.

- (BOOL) _copyPath:(NSString*)source 			// Recursively copies contents
			toPath:(NSString*)destination		// of src directory to dst.
			handler:handler;

- (BOOL) _handleError:(NSString*)e atPath:(NSString*)path handler:(id)handler;

@end /* NSFileManager (PrivateMethods) */


@interface NSDirectoryEnumerator  (Private)

+ (NSDirectoryEnumerator*) _enumeratorAtPath:(NSString*)path shallow:(BOOL)flag;

@end /* NSDirectoryEnumerator */

/* ****************************************************************************

 		NSFileManager 

** ***************************************************************************/

@implementation NSFileManager

+ (void) initialize
{
	if (__fm == nil)
		__fm = (NSFileManager*)NSAllocateObject(self);
}

+ (NSFileManager *) defaultManager		{ return __fm; }
+ (id) alloc							{ return __fm; }

- (BOOL) changeCurrentDirectoryPath:(NSString*)path	
{														// Directory operations
	const char *cpath = [self fileSystemRepresentationWithPath:path];
    
#if defined(__WIN32__) || defined(_WIN32)
    return SetCurrentDirectory(cpath);
#else
    return (chdir(cpath) == 0);
#endif
}

- (BOOL) createDirectoryAtPath:(NSString*)path
					attributes:(NSDictionary*)attributes
{
#if defined(__WIN32__) || defined(_WIN32)
	return CreateDirectory([path cString], NULL);
#else /* !WIN32 */

	char dirpath[PATH_MAX+1];
	struct stat statbuf;
	const char *cpath = [self fileSystemRepresentationWithPath: path];
	int len = strlen(cpath);
	int cur = 0;

	if (len > PATH_MAX)
		return NO;											// name too long
	if (strcmp(cpath, "/") == 0 || len == 0)
		return NO; 					// cannot use "/" or "" as a new dir path

    strcpy(dirpath, cpath);
    dirpath[len] = '\0';
    if (dirpath[len-1] == '/')
		dirpath[len-1] = '\0';

    do	{
		while (dirpath[cur] != '/' && cur < len)			// find next '/'
			cur++;
	
		if (cur == 0) 							// if first char is '/' then 
			{									// again; (cur == len) -> last
			cur++;								// component
			continue;
			}
		
		dirpath[cur] = '\0';					// check if path from 0 to cur 
		if (stat(dirpath, &statbuf) == 0) 		// is valid
			{
			if (cur == len)
				return NO;						// already existing last path
			}
		else 
			{												// make new dir
			if (mkdir(dirpath, 0777) != 0)
				return NO; 						// could not create component
													// if last directory and 
			if (cur == len && attributes)			// attributes then change
				{
				NSString *p = [self stringWithFileSystemRepresentation:dirpath
									length:cur];

				return [self changeFileAttributes:attributes atPath:p];
			}	}

		dirpath[cur] = '/';
		cur++;
		} 
	while (cur < len);

	return YES;

#endif /* !WIN32 */
}

- (NSString*) currentDirectoryPath
{
	char path[PATH_MAX];

#if defined(__WIN32__) || defined(_WIN32)
	if (GetCurrentDirectory(PATH_MAX, path) > PATH_MAX)
		return nil;
#else
    if (getcwd(path, PATH_MAX-1) == NULL)
		return nil;
#endif /* WIN32 */

    return [self stringWithFileSystemRepresentation:path length:strlen(path)];
}

- (BOOL) copyPath:(NSString*)source 						// File operations
		   toPath:(NSString*)destination
		   handler:(id)handler
{
	BOOL sourceIsDir;
	NSDictionary *attributes;

    if (![self fileExistsAtPath:source isDirectory:&sourceIsDir]
			|| [self fileExistsAtPath:destination])
		return NO;

    attributes = [self fileAttributesAtPath:source traverseLink:NO];

    if (sourceIsDir) 					// If destination dir is descendant of
		{								// source dir copying isn't possible
		if ([[destination stringByAppendingString:@"/"]
						  hasPrefix:[source stringByAppendingString:@"/"]])
			return NO;

		[handler fileManager:self willProcessPath:destination];
		if (![self createDirectoryAtPath:destination attributes:attributes]) 
			return [self _handleError:nil atPath:destination handler:handler];

		if (![self _copyPath:source toPath:destination handler:handler])
	    	return NO;

	    [self changeFileAttributes:attributes atPath:destination];

	    return YES;
		}

	[handler fileManager:self willProcessPath:source];
	if (![self _copyFile:source toFile:destination handler:handler])
	    return NO;

	[self changeFileAttributes:attributes atPath:destination];

	return YES;
}

- (BOOL) movePath:(NSString*)source 
		   toPath:(NSString*)destination 
		   handler:handler
{
	BOOL sourceIsDir;
	NSString *destinationParent;
	unsigned int sourceDevice, destinationDevice;
	const char *s, *d;

    if (![self fileExistsAtPath:source isDirectory:&sourceIsDir])
		{
		NSLog(@"NSFileManager movePath: source %@ does not exist", source);
		return NO;
		}

    if ([self fileExistsAtPath:destination])
		{
		NSLog(@"NSFileManager movePath: destination %@ exists", destination);
		return NO;
		}
    		// Check to see if the source and destination's parent are on the
			// same physical device so we can perform a rename syscall directly
    sourceDevice = [[[self fileSystemAttributesAtPath:source]
			    			objectForKey:NSFileSystemNumber] unsignedIntValue];
    destinationParent = [destination stringByDeletingLastPathComponent];
    if ([destinationParent isEqual:@""])
		destinationParent = @".";
    destinationDevice = [[[self fileSystemAttributesAtPath:destinationParent]
		  				objectForKey:NSFileSystemNumber] unsignedIntValue];

    if (sourceDevice != destinationDevice) 
		{						// If destination directory is a descendant of 
								// source directory moving isn't possible.
		if (sourceIsDir && [[destination stringByAppendingString:@"/"]
			    hasPrefix:[source stringByAppendingString:@"/"]])
			return NO;

		if ([self copyPath:source toPath:destination handler:handler]) 
			{
	    	NSDictionary *a=[self fileAttributesAtPath:source traverseLink:NO];

	    	[self changeFileAttributes:a atPath:destination];

	    	return [self removeFileAtPath:source handler:handler];
			}

		return NO;
		}						// src and dest are on the same device so we
								// can simply invoke rename on source. 
	s = [self fileSystemRepresentationWithPath:source];
	d = [self fileSystemRepresentationWithPath:destination];

	[handler fileManager:self willProcessPath:source];
	if (rename (s, d) == -1) 
		{
		if (handler) 
			{
			NSDictionary *e = [NSDictionary dictionaryWithObjectsAndKeys:
									source, @"Path", destination, @"ToPath",
									@"cannot move file", @"Error", nil];

			if ([handler fileManager:self shouldProceedAfterError:e])
				return YES;
			}

		return NO;
		}

	return YES;
}

- (BOOL) linkPath:(NSString*)source 
		   toPath:(NSString*)destination
		   handler:handler								{ NIMP return NO; }

- (BOOL) removeFileAtPath:(NSString*)path handler:(id)handler
{
	NSArray	*contents;
	struct stat statbuf;
	int	i = 0, count;

	if (handler)
		[handler fileManager: self willProcessPath: path];

    if (lstat([path fileSystemRepresentation], &statbuf) != 0)
		return [self _handleError:@"lstat" atPath:path handler:handler];

	if (!S_ISDIR(statbuf.st_mode))
		{
		if (unlink([path fileSystemRepresentation]) == 0)
			return YES;

		return [self _handleError:@"unlink" atPath:path handler:handler];
		}

	contents = [self directoryContentsAtPath: path];
	for (count = [contents count]; i < count; i++)
		{
		NSAutoreleasePool *arp = [NSAutoreleasePool new];
		NSString *item = [contents objectAtIndex: i];
		NSString *next = [path stringByAppendingPathComponent: item];
		BOOL result = [self removeFileAtPath: next handler: handler];

		[arp release];
		if (result == NO)
			return NO;
		}

	if (rmdir([path fileSystemRepresentation]) == 0)
		return YES;

	return [self _handleError:@"rmdir" atPath:path handler:handler];
}

- (BOOL) createFileAtPath:(NSString*)path 
				 contents:(NSData*)contents
				 attributes:(NSDictionary*)attributes
{
	int fd, len, written;
	const char *cpath = [self fileSystemRepresentationWithPath:path];

    if ((fd = open (cpath, O_WRONLY|O_TRUNC|O_CREAT, 0644)) < 0)
        return NO;

    if (![self changeFileAttributes:attributes atPath:path]) 
		{
        close (fd);
        return NO;
		}

	written = (len = [contents length]) ? write(fd, [contents bytes], len) : 0;
	close (fd);

    return (written == len);
}

- (NSData*) contentsAtPath:(NSString*)path
{
	return [NSData dataWithContentsOfFile:path];
}

- (BOOL) contentsEqualAtPath:(NSString*)path1 
					 andPath:(NSString*)path2
{
	NSData *d1 = [NSData dataWithContentsOfFile:path1];

	return [d1 isEqualToData: [NSData dataWithContentsOfFile:path2]];
}

- (BOOL) fileExistsAtPath:(NSString*)path
{
    return [self fileExistsAtPath:path isDirectory:NULL];
}

- (BOOL) fileExistsAtPath:(NSString*)path isDirectory:(BOOL*)isDirectory
{
#if defined(__WIN32__) || defined(_WIN32)
	DWORD res = GetFileAttributes([path cString]);

	if (res == -1)
		return NO;
	if (isDirectory)
		*isDirectory = (res & FILE_ATTRIBUTE_DIRECTORY) ? YES : NO;
#else
	struct stat statbuf;

    if (stat([path cString], &statbuf) != 0)
		return NO;
    if (isDirectory)
		*isDirectory = ((statbuf.st_mode & S_IFMT) == S_IFDIR);

#endif /* WIN32 */

	return YES;
}

- (BOOL) isReadableFileAtPath:(NSString*)path
{
	const char *cpath = [self fileSystemRepresentationWithPath:path];
    
    return (access(cpath, R_OK) == 0);
}

- (BOOL) isWritableFileAtPath:(NSString*)path
{
	const char *cpath = [self fileSystemRepresentationWithPath: path];
    
    return (access(cpath, W_OK) == 0);
}

- (BOOL) isExecutableFileAtPath:(NSString*)path
{
	const char *cpath = [self fileSystemRepresentationWithPath:path];
	struct stat s;
    										// test the exec permission bits
	if (stat(cpath, &s) == 0)				// return YES if any are set
		if(s.st_mode & S_IXUSR || s.st_mode & S_IXGRP || s.st_mode & S_IXOTH)
			return YES;

	return NO;
}

- (BOOL) isDeletableFileAtPath:(NSString*)path
{
	const char *cpath = [self fileSystemRepresentationWithPath: path];

    return (access(cpath, X_OK | W_OK) == 0);
}

- (NSDictionary*) fileAttributesAtPath:(NSString*)path 
						  traverseLink:(BOOL)flag
{
	struct stat statbuf;
	const char *cpath = [self fileSystemRepresentationWithPath: path];
	int mode, count = 9;
			
	id values[10];
	id keys[10] = { NSFileSize,
					NSFileModificationDate,
					NSFileOwnerAccountNumber,
					NSFileGroupOwnerAccountNumber,
					NSFileReferenceCount,
					NSFileIdentifier,
					NSFileDeviceIdentifier,
					NSFilePosixPermissions,
					NSFileType,
					NSFileOwnerAccountName };
	if (!flag)
		{
		if (lstat(cpath, &statbuf) != 0)
			return nil;
		}
	else
		if (stat(cpath, &statbuf) != 0)
			return nil;

    values[0] = [NSNumber numberWithUnsignedLongLong:  statbuf.st_size];
    values[1] = [NSDate dateWithTimeIntervalSince1970: statbuf.st_mtime];
    values[2] = [NSNumber numberWithUnsignedInt:  statbuf.st_uid];
    values[3] = [NSNumber numberWithUnsignedInt:  statbuf.st_gid];
    values[4] = [NSNumber numberWithUnsignedInt:  statbuf.st_nlink];
    values[5] = [NSNumber numberWithUnsignedLong: statbuf.st_ino];
    values[6] = [NSNumber numberWithUnsignedInt:  statbuf.st_dev];
    values[7] = [NSNumber numberWithUnsignedInt:  statbuf.st_mode];

    mode = statbuf.st_mode & S_IFMT;

    if (mode == S_IFREG)
		values[8] = NSFileTypeRegular;
    else if (mode == S_IFDIR)
		values[8] = NSFileTypeDirectory;
	else if (mode == S_IFCHR)
		values[8] = NSFileTypeCharacterSpecial;
	else if (mode == S_IFBLK)
		values[8] = NSFileTypeBlockSpecial;
	else if (mode == S_IFLNK)
		values[8] = NSFileTypeSymbolicLink;
	else if (mode == S_IFIFO)
		values[8] = NSFileTypeFifo;
	else if (mode == S_IFSOCK)
		values[8] = NSFileTypeSocket;
	else
		values[8] = NSFileTypeUnknown;

#if HAVE_PWD_H
	{
	struct passwd *pw;

	if((pw = getpwuid(statbuf.st_uid)))
		{
		count = 10;
		values[9] = [NSString stringWithCString: pw->pw_name];
	}	}
#endif /* HAVE_PWD_H */

    return [[[NSDictionary alloc] initWithObjects:values
								  forKeys:keys
								  count:count] autorelease];
}

- (NSDictionary*) fileSystemAttributesAtPath:(NSString*)path
{
	const char *cpath = [self fileSystemRepresentationWithPath: path];
	long long totalsize, freesize;
	id values[5];
	id keys[5] = {  NSFileSystemSize,
					NSFileSystemFreeSize,
					NSFileSystemNodes,
					NSFileSystemFreeNodes,
					NSFileSystemNumber };

#if defined(__WIN32__) || defined(_WIN32)
	DWORD SectorsPerCluster, BytesPerSector, NumberFreeClusters;
	DWORD TotalNumberClusters;

    if (!GetDiskFreeSpace(cpath, &SectorsPerCluster, &BytesPerSector,
						  &NumberFreeClusters, &TotalNumberClusters))
		return nil;

    totalsize = TotalNumberClusters * SectorsPerCluster * BytesPerSector;
    freesize = NumberFreeClusters * SectorsPerCluster * BytesPerSector;

    values[2] = [NSNumber numberWithLong: LONG_MAX];
    values[3] = [NSNumber numberWithLong: LONG_MAX];
    values[4] = [NSNumber numberWithUnsignedInt: 0];
#else

  #if HAVE_STATVFS || HAVE_SYS_STATFS_H || HAVE_SYS_VFS_H
	struct stat statbuf;
   #else
	return nil;
   #endif  /* HAVE_SYS_VFS_H || HAVE_SYS_STATFS_H */

  #if HAVE_STATVFS
	struct statvfs statfsbuf;
  #else
	struct statfs statfsbuf;
  #endif
    
    if (stat(cpath, &statbuf) != 0)
		return nil;

  #if HAVE_STATVFS
    if (statvfs(cpath, &statfsbuf) != 0)
		return nil;
  #else
    if (statfs(cpath, &statfsbuf) != 0)
		return nil;
  #endif

    totalsize = statfsbuf.f_bsize * statfsbuf.f_blocks;
    freesize = statfsbuf.f_bsize * statfsbuf.f_bavail;

    values[2] = [NSNumber numberWithLong: statfsbuf.f_files];
    values[3] = [NSNumber numberWithLong: statfsbuf.f_ffree];
    values[4] = [NSNumber numberWithUnsignedInt: statbuf.st_dev];

#endif /* WIN32 */

    values[0] = [NSNumber numberWithLongLong: totalsize];
    values[1] = [NSNumber numberWithLongLong: freesize];

    return [[[NSDictionary alloc] initWithObjects:values 
								  forKeys:keys 
								  count:5] autorelease];
}

- (BOOL) changeFileAttributes:(NSDictionary*)attributes 
					   atPath:(NSString*)path
{
	const char *cpath = [self fileSystemRepresentationWithPath:path];
	NSNumber *num;
	NSDate *date;
	BOOL status = YES;
	int owner = -1;
	int group = -1;

#ifndef __WIN32__
    if ((num = [attributes objectForKey:NSFileOwnerAccountNumber]))
		owner = [num intValue];
    if ((num = [attributes objectForKey:NSFileGroupOwnerAccountNumber])) 
		group = [num intValue];

	if (owner != -1 || group != -1)
		if (chown(cpath, owner, group) == -1)
			{
			NSLog(@"chown (%s) failed - %s", cpath, strerror(errno));
			status = NO;
			}
#endif
    if ((num = [attributes objectForKey:NSFilePosixPermissions]))
		if (chmod(cpath, [num intValue]) == -1)
			{
			NSLog(@"chmod (%s) failed - %s", cpath, strerror(errno));
			status = NO;
			}

    if ((date = [attributes objectForKey:NSFileModificationDate]))
		{
		struct stat sb;

		if (stat(cpath, &sb) == -1)
			{
			NSLog(@"stat (%s) failed - %s", cpath, strerror(errno));
			status = NO;
			}
		else 
			{
#ifdef _POSIX_VERSION
			struct utimbuf ub;
			ub.actime = sb.st_atime;
			ub.modtime = [date timeIntervalSince1970];
			if (utime(cpath, &ub) == -1)
#else
			time_t ub[2];
			ub[0] = sb.st_atime;
			ub[1] = [date timeIntervalSince1970];
			if (utime((char*)cpath, ub) == -1)
#endif
				{
				NSLog(@"utime (%s) failed - %s", cpath, strerror(errno));
				status = NO;
		}	}	}
    
    return status;
}

- (NSArray*) directoryContentsAtPath:(NSString*)path
{					
	NSDirectoryEnumerator *de;
	NSMutableArray *c = nil;

	if ((de = [NSDirectoryEnumerator _enumeratorAtPath: path shallow:YES]))
		{
		c = [[NSMutableArray alloc] init];
		while ((path = [de nextObject]))
			[c addObject:path];
		}

    return [c autorelease];
}

- (NSDirectoryEnumerator*) enumeratorAtPath:(NSString*)path
{
	return [NSDirectoryEnumerator _enumeratorAtPath:path shallow:NO];
}

- (NSArray*) subpathsAtPath:(NSString*)path
{
	NSDirectoryEnumerator *de;
	NSMutableArray *c = nil;

	if ((de = [NSDirectoryEnumerator _enumeratorAtPath: path shallow:NO]))
		{
		c = [[NSMutableArray alloc] init];
		while ((path = [de nextObject]))
			[c addObject:path];
		}

    return [c autorelease];
}

- (BOOL) createSymbolicLinkAtPath:(NSString*)path
					  pathContent:(NSString*)otherPath
{
	const char *lpath = [self fileSystemRepresentationWithPath:path];
	const char *npath = [self fileSystemRepresentationWithPath:otherPath];
	
#ifdef __WIN32__							// handle symbolic-link operations
    return NO;
#else
    return (symlink(lpath, npath) == 0);
#endif
}

- (NSString*) pathContentOfSymbolicLinkAtPath:(NSString*)path
{
	char lpath[PATH_MAX];
	const char *cpath = [self fileSystemRepresentationWithPath:path];
	int llen = readlink(cpath, lpath, PATH_MAX-1);
    
    if (llen > 0)
		return [self stringWithFileSystemRepresentation:lpath length:llen];

	return nil;
}

- (const char*) fileSystemRepresentationWithPath:(NSString*)path
{
#if defined(__WIN32__) || defined(_WIN32)
	char cpath[4];
	char *fspath = [path cString];			// Convert file-system representations

	if (fspath[0] && (fspath[1] == ':'))	// Check if path specifies drive 
		{									// number or is current drive
		cpath[0] = fspath[0];
		cpath[1] = fspath[1];
		cpath[2] = '\\';
		cpath[3] = '\0';
		}
	else
		{
		cpath[0] = '\\';
		cpath[1] = '\0';
		}

	return [[NSString stringWithCString: cpath] cString];
#else
    return [path cString];
#endif
}

- (NSString*) stringWithFileSystemRepresentation:(const char*)string
										  length:(unsigned int)len
{
    return [NSString stringWithCString:string length:len];
}

@end /* NSFileManager */

/* ****************************************************************************

 		NSDirectoryEnumerator 

** ***************************************************************************/

@implementation NSDirectoryEnumerator

+ (NSDirectoryEnumerator*) _enumeratorAtPath:(NSString*)path shallow:(BOOL)flag
{
	NSDirectoryEnumerator *de;
	BOOL isDir;
	DIR *dir;

    if (![__fm fileExistsAtPath:path isDirectory:&isDir] || !isDir)
		return nil;

	de = [NSDirectoryEnumerator alloc];
    de->_pathStack = [NSMutableArray new];	// recurse into directory `path',
    de->_enumStack = [NSMutableArray new];	// push relative path (to root of  
    de->_topPath = [path retain];			// search) on _pathStack and push
											// sys dir enumerator onto enumPath
    if ((dir = opendir([__fm fileSystemRepresentationWithPath:path])))
		{
		[de->_pathStack addObject:@""];
		[de->_enumStack addObject:[NSValue valueWithPointer:dir]];
		}
    de->_fm.shallow = flag;

	return [de autorelease];
}

- (void) dealloc
{
    while ([_pathStack count])
		{
		closedir((DIR*)[[_enumStack lastObject] pointerValue]);
		[_enumStack removeLastObject];
		[_pathStack removeLastObject];
		[_fileName  release];
		[_filePath release];
		_fileName  = _filePath = nil;
		}
    
    [_pathStack release];
    [_enumStack release];
    [_fileName  release];
    [_filePath release];
    [_topPath release];
	
	[super dealloc];
}
														// Getting attributes
- (NSDictionary*) directoryAttributes
{
    return [__fm fileAttributesAtPath:_filePath traverseLink:_fm.followLinks];
}

- (NSDictionary*) fileAttributes
{
    return [__fm fileAttributesAtPath:_filePath traverseLink:_fm.followLinks];
}

- (void) skipDescendents								// Skip subdirectories
{
    if ([_pathStack count])
		{
		closedir((DIR*)[[_enumStack lastObject] pointerValue]);
		[_enumStack removeLastObject];
		[_pathStack removeLastObject];
		[_fileName release];
		[_filePath release];
		_fileName = _filePath = nil;
		}
}

- (id) nextObject
{
#ifdef __WIN32__
#else								// finds the next file according to the top
    [_fileName  release];			// enumerator.  if there is a next file it
    [_filePath release];			// is put in _fileName.  if the current 
    _fileName = _filePath = nil;	// file is a directory and if isRecursive
			// calls recurseIntoDirectory:currentFile.  if current file is a 
			// symlink to a directory and if isRecursive and followLinks calls 
			// recurseIntoDirectory:currentFile.  if at end of current dir pops 
			// stack and attempts to find the next entry in the parent.  Then
			// sets currentFile to nil if there are no more files to enumerate.
    while ([_pathStack count]) 
		{
		DIR *dir = (DIR*)[[_enumStack lastObject] pointerValue];
		struct dirent *dirbuf = readdir(dir);
		struct stat statbuf;
		const char *cpath;

		if (dirbuf) 
			{							// Skip "." and ".." directory entries
			if (strcmp(dirbuf->d_name, ".") == 0 
					|| strcmp(dirbuf->d_name, "..") == 0)
				continue;
										// Name of current file
			_fileName = [__fm stringWithFileSystemRepresentation:dirbuf->d_name
							  length:strlen(dirbuf->d_name)];
			_fileName = [[[_pathStack lastObject]
						stringByAppendingPathComponent:_fileName] retain];
										// Full path of current file
			_filePath = [_topPath stringByAppendingPathComponent:_fileName];
			[_filePath retain];

			cpath = [__fm fileSystemRepresentationWithPath:_filePath];
			if (lstat(cpath, &statbuf) < 0)		// Do not follow links
				break;
										// If link then return it as link
			if (S_IFLNK == (S_IFMT & statbuf.st_mode)) 
				break;
										// Follow links check for directory
			if (stat(cpath, &statbuf) < 0)
				break;
			if (S_IFDIR == (S_IFMT & statbuf.st_mode) && !_fm.shallow) 
				{						// recurses into directory `path', push
				DIR *dir;				// path relative to root of search onto
				const char *c;			// _pathStack and push system dir
										// enumerator on enumPath
				c = [__fm fileSystemRepresentationWithPath:_filePath];

				if ((dir = opendir(c)))
					{
					[_pathStack addObject: _fileName ];
					[_enumStack addObject: [NSValue valueWithPointer:dir]];
				}	}

			break;
			}
		else
			{
			closedir((DIR*)[[_enumStack lastObject] pointerValue]);
			[_enumStack removeLastObject];
			[_pathStack removeLastObject];
			[_fileName  release];
			[_filePath release];
			_fileName = _filePath = nil;
		}	}
#endif

    return _fileName ;
}

@end /* NSDirectoryEnumerator */

/* ****************************************************************************

 		NSDictionary (NSFileAttributes) 

** ***************************************************************************/

@implementation NSDictionary (NSFileAttributes)

- (NSString*) fileType;		{ return [self objectForKey:NSFileType]; }

- (NSNumber*) fileOwnerAccountNumber;
{
	return [self objectForKey:NSFileOwnerAccountNumber];
}

- (NSNumber*) fileGroupOwnerAccountNumber;
{
	return [self objectForKey:NSFileGroupOwnerAccountNumber];
}

- (NSDate*) fileModificationDate;
{
	return [self objectForKey:NSFileModificationDate];
}

- (NSUInteger) filePosixPermissions;
{
	return [[self objectForKey:NSFilePosixPermissions] unsignedIntValue];
}

- (unsigned long long) fileSize
{
	return [[self objectForKey:NSFileSize] unsignedLongLongValue];
}

@end /* NSFileAttributes */

/* ****************************************************************************

 		NSFileManager (PrivateMethods) 

** ***************************************************************************/

@implementation NSFileManager (PrivateMethods)

- (BOOL) _handleError:(NSString*)e atPath:(NSString*)path handler:(id)eh
{
	NSDictionary *d;

	if (!eh)
		return NO;

	if (!e)
		e = @"cannot create directory";			// there are only two kinds of
	else										// errors in the world
		e = [NSString stringWithFormat: @"(%@) %s", e, strerror(errno)];

	d = [NSDictionary dictionaryWithObjectsAndKeys: path, @"Path", 
													e, @"Error", nil];
	return [eh fileManager:self shouldProceedAfterError:d];
}

- (BOOL) _copyFile:(NSString*)source toFile:(NSString*)dest handler:(id)eh
{
	unsigned long long i, fsize;
	int sourceFd, destFd, fmode;
	int rbytes, wbytes;
	int bufsize = 8096;
	char buffer[bufsize];
	const char *cpath = [self fileSystemRepresentationWithPath:source];
	NSDictionary *at = [self fileAttributesAtPath:source traverseLink:NO];
										// Assumes source is file and exists
    NSAssert1([self fileExistsAtPath:source], @"source '%@' missing", source);
    NSAssert1(at, @"could not get the attributes for file '%@'", source);

    fsize = [[at objectForKey: NSFileSize] unsignedLongLongValue];
    fmode = [[at objectForKey: NSFilePosixPermissions] intValue];
												// Open source file. In case
    if ((sourceFd = open(cpath, O_RDONLY)) < 0) // of error call the handler
		return [self _handleError:@"open" atPath:source handler:eh];
												// Do the same for destination
	cpath = [self fileSystemRepresentationWithPath:dest];
    if ((destFd = open(cpath, O_WRONLY|O_CREAT|O_TRUNC, fmode)) < 0)
		{
		close (sourceFd);

		return [self _handleError:@"open" atPath:dest handler:eh];
		}
							// errors call the handler and abort the operation.
    for (i = 0; i < fsize; i += rbytes)
		{
		if ((rbytes = read(sourceFd, buffer, bufsize)) < 0) 
			{					// Read bytes from source file and write them
			close(sourceFd);	// into the destination file. In case of errors
			close(destFd);		// call the handler and abort the operation.

			return [self _handleError:@"read" atPath:source handler:eh];
			}

		if ((wbytes = write(destFd, buffer, rbytes)) != rbytes) 
			{
			close(sourceFd);
			close(destFd);

			return [self _handleError:@"write" atPath:dest handler:eh];
		}	}

    close(sourceFd);
    close(destFd);

    return YES;
}

- (BOOL) _copyPath:(NSString*)source
			toPath:(NSString*)destination
			handler:handler
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	NSDirectoryEnumerator *en = [self enumeratorAtPath:source];
	NSString *dirEntry;

    while ((dirEntry = [en nextObject])) 
		{
		NSDictionary *at = [en fileAttributes];
		NSString *fileType = [at objectForKey:NSFileType];
		NSString *sf = [source stringByAppendingPathComponent:dirEntry];
		NSString *df = [destination stringByAppendingPathComponent:dirEntry];

		[handler fileManager:self willProcessPath:sf];

		if ([fileType isEqual:NSFileTypeDirectory])
			{
			if (![self createDirectoryAtPath:df attributes:at]) 
				{
				if (![self _handleError:nil atPath:df handler:handler])
					return NO;
	    		}
			else 
				{
				[en skipDescendents];
				if (![self _copyPath:sf toPath:df handler:handler])
					return NO;
			}	}
		else if ([fileType isEqual:NSFileTypeRegular])
			{
			if (![self _copyFile:sf toFile:df handler:handler])
				return NO;
			}
		else if ([fileType isEqual:NSFileTypeSymbolicLink])
			{
			if (![self createSymbolicLinkAtPath:df pathContent:sf]) 
				{
				NSDictionary *e;

				if (handler == nil)
					return NO;

				e = [NSDictionary dictionaryWithObjectsAndKeys:
						sf, @"Path", df, @"ToPath",
						@"cannot create symbolic link", @"Error", nil];

				if (![handler fileManager:self shouldProceedAfterError:e])
					return NO;
			}	}
		else
			NSLog(@"cannot copy file '%@' of type '%@'", sf, fileType);

		[self changeFileAttributes:at atPath:df];
		}

	[pool release];

	return YES;
}

@end /* NSFileManager (PrivateMethods) */


NSString *NSFileType              = @"NSFileType";
NSString *NSFileSize              = @"NSFileSize";
NSString *NSFileModificationDate  = @"NSFileModificationDate";
NSString *NSFileOwnerAccountNumber= @"NSFileOwnerAccountNumber";
NSString *NSFileOwnerAccountName  = @"NSFileOwnerAccountName";
NSString *NSFileGroupOwnerAccountNumber = @"NSFileGroupOwnerAccountNumber";
NSString *NSFileReferenceCount    = @"NSFileReferenceCount";
NSString *NSFileIdentifier        = @"NSFileIdentifier";
NSString *NSFileDeviceIdentifier  = @"NSFileDeviceIdentifier";
NSString *NSFilePosixPermissions  = @"NSFilePosixPermissions";

NSString *NSFileTypeDirectory    = @"NSFileTypeDirectory";
NSString *NSFileTypeRegular      = @"NSFileTypeRegular";
NSString *NSFileTypeSymbolicLink = @"NSFileTypeSymbolicLink";
NSString *NSFileTypeSocket       = @"NSFileTypeSocket";
NSString *NSFileTypeFifo         = @"NSFileTypeFifo";
NSString *NSFileTypeCharacterSpecial = @"NSFileTypeCharacterSpecial";
NSString *NSFileTypeBlockSpecial = @"NSFileTypeBlockSpecial";
NSString *NSFileTypeUnknown      = @"NSFileTypeUnknown";

NSString *NSFileSystemSize		= @"NSFileSystemSize";
NSString *NSFileSystemFreeSize	= @"NSFileSystemFreeSize";
NSString *NSFileSystemNodes 	= @"NSFileSystemNodes";
NSString *NSFileSystemFreeNodes = @"NSFileSystemFreeNodes";
NSString *NSFileSystemNumber 	= @"NSFileSystemNumber";
