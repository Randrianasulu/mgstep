/*
   NSBundle.m

   Dynamic loading of Obj-C resources.

   Copyright (C) 1993-2020 Free Software Foundation, Inc.

   Author:  Adam Fedor <fedor@boulder.colorado.edu>
   Date:	May 1993
   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:	January 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSBundle.h>
#include <Foundation/NSException.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSURL.h>

#include <dirent.h>
#include <dlfcn.h>


#ifdef NEW_RUNTIME
  #define CLS_IS_META(cls)		class_isMetaClass(cls)
  #define TYPE_CALLBACK  		(void (*)(Class, struct objc_category*))
#else
  #define CLS_IS_META(cls)		class_is_class(cls)
  #define TYPE_CALLBACK
#endif


typedef enum {
	NSBUNDLE_BUNDLE = 1, 
	NSBUNDLE_APPLICATION, 
	NSBUNDLE_LIBRARY
} bundle_t;


static NSBundle *__mainBundle = nil;
static NSMapTable *__bundles = NULL;	// for bundles we can't unload, don't 
										// dealloc. true for all bundles (now).
static NSBundle *__systemBundle = nil;
					// When linking in an object file, objc_load_modules calls
					// our callback routine for every Class and Category loaded.
					// __loadingBundle refers to the bundle that is currently
					// loading so we know where to store the class names.
static id __loadingBundle = nil;

static NSRecursiveLock *__loadLock = nil;
static NSDictionary *__localizedStringsPList = nil;

NSString *NSBundleDidLoadNotification = @"NSBundleDidLoadNotification";
NSString *NSLoadedClasses             = @"NSLoadedClasses";

void _bundleLoadCallback(Class theClass, Category *theCategory);


/* ****************************************************************************

	Definitions and translations for dynamic loading with the simple dynamic
	loading library (dl).	- unloading modules not implemented

** ***************************************************************************/

								// Our current callback function
void (*_objc_load_load_callback)(Class, Category*) = 0;

								// dynamic loader was sucessfully initialized. 
static BOOL	__dynamicLoaderInitialized = NO;

								// List of modules we have loaded (by handle) 
static struct objc_list *__dynamicModules = NULL;

#define CTOR_LIST "__CTOR_LIST__"				// GNU name for the CTOR list

#ifndef RTLD_GLOBAL
#define RTLD_GLOBAL 0
#endif

typedef void *dl_handle_t;						// Types defined appropriately 
typedef void *dl_symbol_t;						// for the dynamic linker

								// Do any initialization necessary.  Return 0 
static int						// on success (or if no initialization needed.
__objc_dynamic_init(const char *exec_path)		{ return 0; }

								// Link in module given by the name 'module'.
								// Return a handle which can be used to get 
static dl_handle_t				// information about the loded code.
__objc_dynamic_link(const char *module, int mode, const char *debug_file)
{
    return (dl_handle_t)dlopen(module, RTLD_LAZY | RTLD_GLOBAL);
}
								// Return address of 'symbol' from the module
static dl_symbol_t 				// associated with 'handle'
__objc_dynamic_find_symbol(dl_handle_t handle, const char *symbol)
{
    return dlsym(handle, (char*)symbol);
}
								// remove the code from memory associated with 
static int 						// the module 'handle'
__objc_dynamic_unlink(dl_handle_t handle)
{
    return dlclose(handle);
}
								// Print error message prefaced by error_string 
static void 					// relevant to the last error encountered
__objc_dynamic_error(FILE *error_stream, const char *error_string)
{
    fprintf(error_stream, "%s:%s\n", error_string, dlerror());
}
								// Debugging define these if they are available 
static int __objc_dynamic_undefined_symbol_count(void)		{ return 0; }
static char** __objc_dynamic_list_undefined_symbols(void)	{ return NULL; }

								// Check to see if there are any undefined 
static int						// symbols. Print them out.
objc_check_undefineds(FILE *errorStream)
{
	int i, count = __objc_dynamic_undefined_symbol_count();

	if (count != 0) 
		{
        char **undefs = __objc_dynamic_list_undefined_symbols();

        if (errorStream)
	    	fprintf(errorStream, "Undefined symbols:\n");
        for (i = 0; i < count; i++)
            if (errorStream)
				fprintf(errorStream, "  %s\n", undefs[i]);

		return 1;
    	}

	return 0;
}

#ifdef NEW_RUNTIME

#ifdef __USE_LIBOBJC2__
	struct sarray *__objc_uninstalled_dtable = 0;
#else
	extern struct sarray *__objc_uninstalled_dtable;

				// objc runtime -- needed when invalidating the dtable
	extern void __objc_install_premature_dtable(Class);
	extern void sarray_free(struct sarray*);
#endif

/* ****************************************************************************

	Returns the uninstalled dispatch table indicator.
	If a class' dispatch table points to __objc_uninstalled_dtable
	it needs its dispatch table to be installed.

** ***************************************************************************/

struct sarray*
objc_get_uninstalled_dtable()
{
	return __objc_uninstalled_dtable;
}

struct objc_list
{
	void *head;
	struct objc_list *tail;
};

/* Return a cons cell produced from (head . tail).  */
static inline struct objc_list* 
list_cons (void* head, struct objc_list* tail)
{
	struct objc_list* cell;

	cell = (struct objc_list*)malloc (sizeof (struct objc_list));
	cell->head = head;
	cell->tail = tail;
	return cell;
}
#endif

								// Invalidate the dtable so it will be rebuild 
static void						// when a message is sent to the object
objc_invalidate_dtable(Class class)
{
	Class s;

    if (class->dtable == objc_get_uninstalled_dtable()) 
		return;

#ifndef __USE_LIBOBJC2__
    sarray_free(class->dtable);
    __objc_install_premature_dtable(class);
#endif
    for (s = class->subclass_list; s; s=s->sibling_class) 
		objc_invalidate_dtable(s);
}

static int
objc_initialize_loading(FILE *errorStream)
{
	const char *path = [[[NSBundle mainBundle] bundlePath] cString];

    DBLog(@"(objc-load): initializing dynamic loader for %s\n", path);

    if (__objc_dynamic_init(path)) 
		{
		if (errorStream)
			__objc_dynamic_error(errorStream, "Error init'ing dynamic linker");
		return 1;
		} 

	__dynamicLoaderInitialized = YES;

    return 0;
}								// A callback received from Object initializer 
								// (_objc_exec_class). Do what we need to do 
static void 					// and call our own callback.
objc_load_callback(Class class, Category *category)
{
    if (class != 0 && category != 0) 		// Invalidate the dtable, so it 
		{									// will be rebuilt correctly
		objc_invalidate_dtable(class);
		objc_invalidate_dtable(class->class_pointer);
		}

    if (_objc_load_load_callback)
		_objc_load_load_callback(class, category);
}

long
objc_load_module(const char *filename,
				 FILE *errorStream,
				 void (*loadCallback)(Class, Category*),
				 void **header,
				 char *debugFilename)
{
	typedef void (*void_fn)();
	dl_handle_t handle;

    if (!__dynamicLoaderInitialized)
        if (objc_initialize_loading(errorStream))
            return 1;

    _objc_load_load_callback = loadCallback;
    _objc_load_callback = TYPE_CALLBACK objc_load_callback;

    DBLog(@"Debug (objc-load): Linking file %s\n", filename);
													// Link in the object file
	if ((handle = __objc_dynamic_link(filename, 1, debugFilename)) == 0) 
		{
		if (errorStream)
			__objc_dynamic_error(errorStream, "Error (objc-load)");
		return 1;
		}
    __dynamicModules = list_cons(handle, __dynamicModules);

				// If there are any undefined symbols, we can't load the bundle
	if (objc_check_undefineds(errorStream)) 
		{
		__objc_dynamic_unlink(handle);
		return 1;
		}

    _objc_load_callback = 0;
    _objc_load_load_callback = 0;

    return 0;
}

static NSString * 							// Construct a path from components
_bundleResourcePath(NSString *primary, NSString *bundlePath, NSString *lang)
{
	if (bundlePath)
		primary = [primary stringByAppendingPathComponent: bundlePath];
	if (lang)
		primary = [NSString stringWithFormat: @"%@/%@.lproj", primary, lang];

	return primary;
}
										// Find the first directory entry with  
static NSString *						// a given name (with any extension)
_bundle_path_for_name(NSString *path, NSString *name)
{
	struct dirent *e;
	NSString *fullname = nil;
	DIR *d = opendir([path cString]);

	if (d)
		{
		while ((e = readdir(d)))
			{
			if (*(e->d_name) != '.')
				if (strncmp([name cString], e->d_name, [name length]) == 0)
					{
					fullname = [NSString stringWithCString: e->d_name];
					break;
			}		}

		closedir(d);
		}

	return (fullname) ? [path stringByAppendingPathComponent: fullname] : nil;
}

/* ****************************************************************************

		NSBundle

** ***************************************************************************/

@implementation NSBundle

+ (void) initialize
{
    if (!__mainBundle)
		{
		NSProcessInfo *pi = [NSProcessInfo processInfo];
		NSString *sys = [[pi environment] objectForKey:@"MGSTEP_ROOT"];
		NSString *path = [[pi arguments] objectAtIndex:0];
		NSFileManager *fm = [NSFileManager defaultManager];

		__bundles = NSCreateMapTable( NSNonOwnedCStringMapKeyCallBacks,
									  NSObjectMapValueCallBacks, 0);
		__systemBundle = [[NSBundle alloc] initWithPath:sys];
		__systemBundle->_bundleType = (unsigned int)NSBUNDLE_LIBRARY;

		if (![path isAbsolutePath])
			{
			NSString *cd = [fm currentDirectoryPath];

			path = [cd stringByAppendingPathComponent:path];
			if (![fm fileExistsAtPath:path])
				path = sys;				// App without a main bundle
			}

		if (![fm fileExistsAtPath:path])
			[NSException raise: NSInternalInconsistencyException
						 format: @"Can't find main bundle executable %@",path];

										// Strip off the name of the program 
		path = [path stringByDeletingLastPathComponent];
		DBLog(@"NSBundle: main bundle path is %@\n", path);

		[__loadLock lock];
		__mainBundle = [[NSBundle alloc] initWithPath:path];
		__mainBundle->_bundleType = (unsigned int)NSBUNDLE_APPLICATION;
		[__loadLock unlock];
		}
}

+ (NSBundle *) systemBundle			{ return __systemBundle; }	// MGSTEP_ROOT
+ (NSBundle *) mainBundle			{ return __mainBundle; }				

+ (NSBundle *) bundleForClass:(Class)cls
{
	void *key;							// Due to lazy evaluation, we will not
	NSBundle *bundle = nil;				// find a class if either classNamed:
	NSMapEnumerator e;					// or principalClass has not been
 										// called on the particular bundle that
	if (!cls)							// contains the class. (FIXME)
		return nil;

	e = NSEnumerateMapTable(__bundles);
	while (NSNextMapEnumeratorPair(&e, &key, (void **)&bundle))
		{
		if (bundle->_bundleClasses)
			if ([bundle->_bundleClasses indexOfObject:cls] != NSNotFound)
				break;

		bundle = nil;
		}

	if ((!bundle) && CLS_IS_META(cls))			// Is it in the main bundle?
		bundle = [NSBundle mainBundle];

	return bundle;
}

+ (NSBundle *) bundleWithPath:(NSString *)path
{
	return [[[NSBundle alloc] initWithPath: path] autorelease];
}

- (id) initWithPath:(NSString *)path;
{
	NSBundle *bundle;

	if (!path || [path length] == 0)
		return _NSInitError(self, @"No path specified for bundle");

	if ((bundle = (NSBundle *)NSMapGet(__bundles, [path cString])))
		{										// Check if we were already
		[self dealloc];							// init'd for this directory.
		return [bundle retain]; 				// retain and return if so 
		}

	if (![[NSFileManager defaultManager] fileExistsAtPath:path])
		return _NSInitError(self, @"Could not access path %@ for bundle", path);

	_searchPaths = [[NSMutableDictionary alloc] initWithCapacity: 4];
	_path = [path copy];
	_bundleType = (unsigned int)NSBUNDLE_BUNDLE;

	NSMapInsert(__bundles, [_path cString], self);

	return self;
}

- (void) dealloc
{
	NSMapRemove(__bundles, [_path cString]);
	[_bundleClasses release];
	[_infoDict release];
	[_path release];
	[_searchPaths release];
	[super dealloc];							// Currently, the objc runtime 
}												// can't unload modules so 
												// disable dealloc of bundles
- (id) retain 							{ return self; }
- (id) autorelease 						{ return self; }
- (oneway void) release					{}
- (NSUInteger) retainCount 				{ return 1; }
- (NSString *) bundlePath				{ return _path; }

- (Class) classNamed:(NSString *)className
{
	Class theClass = Nil;

	if (!_codeLoaded && (self != __mainBundle) && ![self load]) 
		{
		NSLog(@"No classes in bundle");
		return Nil;
		}

	if (self == __mainBundle) 
		{
		theClass = NSClassFromString(className);
		if (theClass && [[self class] bundleForClass:theClass] != __mainBundle)
			theClass = Nil;
		} 
	else 
		{
		NSInteger j = [_bundleClasses indexOfObject:NSClassFromString(className)];

		if (j != NSNotFound)
			theClass = [_bundleClasses objectAtIndex: j];
		}
  
	return theClass;
}

- (Class) principalClass
{
	if (!_principalClass)
		{
		NSString *n = [[self infoDictionary] objectForKey:@"NSPrincipalClass"];

		if (self == __mainBundle) 
			{
			_codeLoaded = YES;
			if (n)
				_principalClass = NSClassFromString(n);
			else
				NSLog(@"NSPrincipalClass is not defined in info.plist");
			}
		else
			{
			if ([self load] == NO)
				return Nil;
		
			if (n)
				_principalClass = NSClassFromString(n);
			if (!_principalClass && ([_bundleClasses count]))
				_principalClass = [_bundleClasses objectAtIndex:0];
		}	}

	return _principalClass;
}

- (BOOL) load
{
	[__loadLock lock];

	if (!_codeLoaded)
		{
		NSString *obj = [[self infoDictionary] objectForKey:@"NSExecutable"];
		const char *modPtr[2] = {"", NULL};

		if(!obj)
			[NSException raise:NSInvalidArgumentException
					format:@"'NSExecutable' not defined for bundle %@",_path];
		
		obj = [_path stringByAppendingPathComponent: obj];
		__loadingBundle = self;
		_bundleClasses = [[NSMutableArray arrayWithCapacity:2] retain];
		*modPtr = [obj cString];

#ifdef __APPLE__		// FIX ME rewrite routine per NeXT to avoid this mess
		if(objc_loadModules(modPtr, stderr, _bundleLoadCallback, NULL,NULL))
#else /* !__APPLE__ */
     	if(objc_load_module(*modPtr, stderr, _bundleLoadCallback, NULL,NULL))
#endif /* __APPLE__ */
			{
			[__loadLock unlock];

			return NO;
			}
		else
			{
			NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
			NSDictionary *dict;

			dict = [NSDictionary dictionaryWithObjects: &_bundleClasses
								 forKeys: &NSLoadedClasses 
								 count: 1];
			_codeLoaded = YES;
			__loadingBundle = nil;
			[nc postNotificationName: NSBundleDidLoadNotification 
				object: self
				userInfo: dict];
		}	}

	[__loadLock unlock];

	return YES;
}

/* ****************************************************************************

	Constructs an array of paths, where each path is a possible location
	for a resource in the bundle.  The current algorithm for searching goes:

     <root bundle path> /Resources/ <bundlePath>
     <root bundle path> /Resources/ <bundlePath> / <language.lproj>
     <root bundle path> / <bundlePath>
     <root bundle path> / <bundlePath> / <language.lproj>

** ***************************************************************************/

- (NSArray *) _resourcePathsFor:(NSString *)rootBundlePath
						subPath:(NSString *)bundlePath
{
	NSString *primary, *language;
	NSArray *languages = [NSUserDefaults userLanguages];
	NSMutableArray *array = [NSMutableArray arrayWithCapacity: 8];
	NSEnumerator *e;

	if(_bundleType != NSBUNDLE_LIBRARY)
		{
		primary = [rootBundlePath stringByAppendingPathComponent:@"Resources"];
		[array addObject: _bundleResourcePath(primary, bundlePath, nil)];
		e = [languages objectEnumerator];
		while ((language = [e nextObject]))
			[array addObject:_bundleResourcePath(primary,bundlePath,language)];
		}
	
	primary = rootBundlePath;
	[array addObject: _bundleResourcePath(primary, bundlePath, nil)];
	e = [languages objectEnumerator];
	while ((language = [e nextObject]))
		[array addObject: _bundleResourcePath(primary, bundlePath, language)];
	
	return array;
}

- (NSString *) pathForResource:(NSString *)name
						ofType:(NSString *)ext
						inDirectory:(NSString *)bundlePath
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSEnumerator *e;
	NSArray *searchArray;
	NSString *path;
	NSString *b = (bundlePath) ? bundlePath : @"";
	int extLength = (ext) ? [ext length] : 0;

	if (!name || [name length] == 0) 
		[NSException raise: NSInvalidArgumentException
        			 format: @"No resource name specified."];
														// cache search paths
	if (!(searchArray = [_searchPaths objectForKey:b]))	// by bundlePath name
		{
		searchArray = [self _resourcePathsFor:_path subPath:bundlePath];
		[_searchPaths setObject:searchArray forKey:b];
		}

	e = [searchArray objectEnumerator];

	while((path = [e nextObject]))
		{
		NSString *fullpath = nil;

		if (extLength > 0)
			{
			fullpath = [NSString stringWithFormat:@"%@/%@.%@",path, name, ext];
//			NSLog(@" full0 %@", fullpath);
			if ([fm fileExistsAtPath:fullpath]) 
				return fullpath;
			}
		else
			{
			fullpath = [NSString stringWithFormat: @"%@/%@", path, name];
//			NSLog(@" full %@", fullpath);
			if ([fm fileExistsAtPath:fullpath]) 
				return fullpath;
			if ((fullpath = _bundle_path_for_name(path, name)))
				return fullpath;
		}	}

	return nil;
}

- (NSString *) pathForResource:(NSString *)name ofType:(NSString *)ext
{
	return [self pathForResource:name ofType:ext inDirectory:nil];
}

- (NSURL *) URLForResource:(NSString *)name
			 withExtension:(NSString *)ext
			  subdirectory:(NSString *)subpath
{
	NSString *pt = [self pathForResource:name ofType:ext inDirectory:subpath];

	return [[[NSURL alloc] initFileURLWithPath:pt] autorelease];
}

- (NSURL *) URLForResource:(NSString *)name withExtension:(NSString *)ext
{
	return [self URLForResource:name withExtension:ext subdirectory:nil];
}

- (NSArray *) pathsForResourcesOfType:(NSString *)extension
						  inDirectory:(NSString *)bundlePath
{
	NSString *path, *b = (bundlePath) ? bundlePath : @"";
	NSMutableArray *resources = [NSMutableArray arrayWithCapacity: 2];
	NSArray *searchArray;
	NSEnumerator *e;
														// cache search paths
	if(!(searchArray = [_searchPaths objectForKey:b]))	// by bundlePath name
		{
		searchArray = [self _resourcePathsFor:_path subPath:bundlePath];
		[_searchPaths setObject:searchArray forKey:b];
		}
	e = [searchArray objectEnumerator];

	while((path = [e nextObject]))
		{
		DIR *thedir;
		struct dirent *entry;

		if ((thedir = opendir([path cString]))) 
			{
			while ((entry = readdir(thedir))) 
				{
				if (*entry->d_name != '.') 
					{
					char *ext = strrchr(entry->d_name, '.');

					if (!extension || [extension length] == 0 || 
							(ext && strcmp(++ext, [extension cString]) == 0))
						[resources addObject: [NSString stringWithFormat: 
												@"%@/%s",path, entry->d_name]];
				}	}
			closedir(thedir);
		}	}

	return resources;
}

- (NSString *) localizedStringForKey:(NSString *)key
							   value:(NSString *)value
							   table:(NSString *)tableName
{
	NSString *ls = nil;
	NSString *path = nil;
	NSDictionary *d = nil;

	if (tableName)
		path = [self pathForResource:tableName ofType:@"strings"];
	else if (!__localizedStringsPList)
		path = [self pathForResource:@"Localizable" ofType:@"strings"];
	else
		d = __localizedStringsPList;

	if (!path && (!__localizedStringsPList || tableName))
		{
		NSArray *r = [self pathsForResourcesOfType:@"strings" inDirectory:nil];

		if (r && [r count])
			path = [r objectAtIndex: 0];
		}

	if (path)
		{
		NSString *s = [NSString stringWithContentsOfFile: path];

		d = [s propertyListFromStringsFileFormat];
		if (!tableName && !__localizedStringsPList)
			__localizedStringsPList = [d retain];
		}
							// ret value if key is nil or localized not found
	if ((ls = [d objectForKey: key]) == nil)
		ls = (!value || ([value length] == 0)) ? key : value;

	return ls;
}

- (NSString *) resourcePath
{
	return [_path stringByAppendingPathComponent: @"Resources"];
}

- (NSDictionary *) infoDictionary
{
	if (_infoDict == nil)
		{
		NSString *p;

		if ((p = [self pathForResource:@"Info" ofType:@"plist"]))
			_infoDict = [[NSDictionary dictionaryWithContentsOfFile: p] retain];
		else
			_infoDict = [[NSDictionary dictionary] retain];
		}

	return _infoDict;
}

- (void) _addClass:(Class)aClass
{
	[_bundleClasses addObject:(id)aClass];
}

@end /* NSBundle */


void
_bundleLoadCallback(Class theClass, Category *theCategory)
{
	NSCAssert(__loadingBundle, NSInternalInconsistencyException);

	if (!theCategory)								// Don't store categories
		[__loadingBundle _addClass:theClass];
}
