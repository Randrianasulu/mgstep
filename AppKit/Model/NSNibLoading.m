/*
   NIBLoading.m - implements all NSBundle Additions

   Copyright (c) 2004 DSITRI.

   Author: H. Nikolaus Schaller <hns@computer.org>
   Date: June 2004
   Date: Feb 2006  - reworked to read modern NSKeyCoded based NIB files

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/Foundation.h>
#include <Foundation/NSGeometry.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSNib.h>
#include <AppKit/NSNibLoading.h>

#import <AppKit/NSApplication.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSResponder.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSView.h>
#import <AppKit/NSClipView.h>
#import <AppKit/NSLayoutManager.h>
#import <AppKit/NSCell.h>
#import <AppKit/NSButtonCell.h>



/* ****************************************************************************

	Private class and category interfaces used in Keyed Archiving

** ***************************************************************************/

@interface NSResponder  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder;

@end


@interface NSIBObjectData : NSObject  <NSCoding>
{
	// not all are really used by a 10.4 NIB
	// and I have no idea how to get the list of all objects out of that
	id _rootObject;							// the root object
	id _reserved;							// ?
	NSMapTable *_classTable;				// class names (custom classes?)
	NSMutableArray *_connections;			// a table of connections
	NSMapTable *_objectTable;				// object table
	id _fontManager;						// the NSFontManager object
	NSMapTable *instantiatedObjectTable;	// all objects
	NSMapTable *_nameTable;					// table of all object names
	int nextOid;							// next object ID to be encoded
	NSResponder *firstResponder;			// the firstResponder
	NSMapTable *_oidTable;					// object ID table
	id _document;
	NSString *targetFramework;
	NSMutableSet *_visibleWindows;			// all visible windows in archive
	NSMutableArray *_objects;
}

- (void) _establishConnectionsWithOwner:(id)owner;
// - (void) awakeObjectsFromNib;
- (void) orderFrontVisibleWindows;

@end

@interface NSCustomObject : NSObject  <NSCoding>
{
	NSString *className;
	id object;
	id extension;
	id owner;
}
- (id) nibInstantiate;	// instantiates if neccessary and returns a non-retained reference
@end

@interface NSClassSwapper : NSObject  <NSCoding>
{
	NSString *originalClassName;
    NSString *className;
	id realObject;
}
- (id) nibInstantiate;	// instantiates if neccessary and returns a non-retained reference
@end

@interface NSCustomView : NSView  <NSCoding>
{
    NSString *className;
	id view;
    id extension;
	id nextResponder;
	NSView *superView;
	NSArray *subviews;
	int vFlags;
}
- (id) nibInstantiate;	// instantiates if neccessary and returns a non-retained reference
@end

@interface NSWindowTemplate : NSObject
{
    NSString *windowTitle;
    NSString *windowClass;
    NSView *windowView;
    NSWindow *realObject;
		NSString *autosaveName;
    id viewClass;
    id extension;
    NSRect windowRect;
    NSRect screenRect;
    NSSize minSize;
    NSSize maxSize;
    unsigned long _wtFlags;
    int windowStyleMask;
    int windowBacking;
}
- (id) nibInstantiate;	// instantiates if neccessary and returns a non-retained reference
@end

@interface NSCustomResource : NSObject	// NSImage?
{
	NSString *_className;
	NSString *_resourceName;
}
@end

/* ****************************************************************************

	NSIBObjectData

** ***************************************************************************/

@implementation NSIBObjectData

- (void) encodeWithCoder:(NSCoder*) coder		{ NIMP; }		// NSCoding Protocol

- (id) initWithCoder:(NSCoder *) coder;
{
#if 0
	NSLog(@"NSIBObjectData initWithCoder");
	NSLog(@"NSIBObjectData initWithCoder: %@", coder);
#endif
	if(![coder allowsKeyedCoding])
		return NIMP;
#if 0
	{
		NSString *key;
		key=@"NSAccessibilityConnectors", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		key=@"NSAccessibilityOidsKeys", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		key=@"NSAccessibilityOidsValues", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		key=@"NSClassesKeys", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		key=@"NSClassesValues", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		key=@"NSConnections", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		key=@"NSFontManager", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		key=@"NSFramework", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		key=@"NSNamesKeys", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]); 
		key=@"NSNamesValues", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]); 
//		NSNextOid = 207; 
		key=@"NSObjectsKeys", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		key=@"NSObjectsValues", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		key=@"NSOidsKeys", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		key=@"NSOidsValues", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		key=@"NSRoot", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		key=@"NSVisibleWindows", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		}
#endif
	targetFramework=[[coder decodeObjectForKey:@"NSFramework"] retain];
	_rootObject=[[coder decodeObjectForKey:@"NSRoot"] retain];
	// FIXME: there is also an objects table in NIB
	// all objects from NIB that need to receive awakeFromNib
	_objects = [[coder decodeObjectForKey:@"NSObjectsValues"] retain];
#if 0
	NSLog(@"objects 1=%@", _objects);
#endif
	[coder decodeObjectForKey:@"NSObjectsKeys"];

	_connections = [[coder decodeObjectForKey:@"NSConnections"] retain];
	_visibleWindows = [[coder decodeObjectForKey:@"NSVisibleWindows"] retain];

	[coder decodeObjectForKey:@"NSClassesValues"];
													// all ClassSwapper objects
//	_classTable = [coder decodeObjectForKey:@"NSClassesKeys"];
	[coder decodeObjectForKey:@"NSClassesKeys"];	// original class names
				
//	_objectTable = [coder decodeObjectForKey:@"NSNamesValues"];	// object table
	[coder decodeObjectForKey:@"NSNamesValues"];

//	_nameTable = [coder decodeObjectForKey:@"NSNamesKeys"];
	[coder decodeObjectForKey:@"NSNamesKeys"];		// table of all object names

	nextOid=[coder decodeIntForKey:@"NSNextOid"];	// next object ID to be encoded

//	_oidTable = [coder decodeObjectForKey:@"NSObjectsKeys"];
	[coder decodeObjectForKey:@"NSObjectsKeys"];	// object ID table

	_fontManager = [[coder decodeObjectForKey:@"NSFontManager"] retain];
	// just reference others once
	[coder decodeObjectForKey:@"NSOidsValues"];
	[coder decodeObjectForKey:@"NSOidsKeys"];
	[coder decodeObjectForKey:@"NSAccessibilityConnectors"];
	[coder decodeObjectForKey:@"NSAccessibilityOidsKeys"];
	[coder decodeObjectForKey:@"NSAccessibilityOidsValues"];
	[coder decodeObjectForKey:@"NSClassesValues"];
#if 0
	NSLog(@"rootObject=%@", _rootObject);
	NSLog(@"classTable=%@", _classTable);
	NSLog(@"connections=%@", _connections);
	NSLog(@"objectTable=%@", _objectTable);
	NSLog(@"fontManager=%@", _fontManager);
	NSLog(@"objects size=%d", [_objects count]);
	NSLog(@"objects=%@", _objects);
	NSLog(@"nameTable=%@", _nameTable);
	NSLog(@"nextOid=%d", nextOid);
	NSLog(@"firstResponder=%@", firstResponder);
	NSLog(@"oidTable=%@", _oidTable);
	NSLog(@"_document=%@", _document);
	NSLog(@"targetFramework=%@", targetFramework);
	NSLog(@"visibleWindows=%@", _visibleWindows);
#endif
#if 0
	{
		NSString *key;
		key=@"NSAccessibilityConnectors", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		key=@"NSAccessibilityOidsKeys", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		key=@"NSAccessibilityOidsValues", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		key=@"NSClassesKeys", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		key=@"NSClassesValues", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		key=@"NSConnections", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		key=@"NSFontManager", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		key=@"NSFramework", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		key=@"NSNamesKeys", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]); 
		key=@"NSNamesValues", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]); 
		//		NSNextOid = 207; 
		key=@"NSObjects", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		key=@"NSObjectsKeys", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		key=@"NSObjectsValues", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		key=@"NSOidsKeys", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		key=@"NSOidsValues", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		key=@"NSRoot", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
		key=@"NSVisibleWindows", NSLog(@"%@=%@", key, [coder decodeObjectForKey:key]);
	}
#endif
	return self;
}

- (void) _establishConnectionsWithOwner:(id)owner
{
	NSEnumerator *e = [_connections objectEnumerator];
	NSNibConnector *c;
#if 0
	unsigned idx=[_objects indexOfObject:_rootObject];
	NSLog(@"loaded %ld connections", [_connections count]);
	NSLog(@"rootObject=%@ idx=%u", _rootObject, idx);
	NSLog(@"owner=%@", owner);
#endif
	while ((c = [e nextObject]))
		{
		[c replaceObject:_rootObject withObject:owner];	// don't connect to the instantiated root object but to the owner
		[c establishConnection];
		}
}

- (void) orderFrontVisibleWindows
{
	// only these should be added to the Windows menu
	[_visibleWindows makeObjectsPerformSelector:@selector(orderFront:) withObject:nil];	// make these windows visible
}

- (id) rootObject;						{ return _rootObject; }	// File's Owner

- (void) dealloc;
{
#if 0
	NSLog(@"NSIBObjectData dealloc");
#endif
	[targetFramework release];
	[_rootObject release];
	[_objects release];
	[_connections release];
	[_visibleWindows release];
//	[_classTable release];
//	[_objectTable release];
//	[_nameTable release];
//	[_oidTable release];
	[_fontManager release];
	[super dealloc];
}

@end  /* NSIBObjectData */


@implementation NSNib  (FilesOwner)

- (id) _owner 									{ return _owner; }

@end


@implementation NSCustomObject

- (void) encodeWithCoder:(NSCoder*) coder		{ NIMP; }	// NSCoding Protocol
- (id) initWithCoder:(NSCoder *)coder			{ return nil; }

- (id) _initWithKeyedCoder:(NSCoder *) coder;
{
#if 0
	NSLog(@"NSCustomObject initWithCoder %@", coder);
#endif
//	if(![coder allowsKeyedCoding])
//		return NIMP;
	className=[[coder decodeObjectForKey:@"NSClassName"] retain];
	object=[[coder decodeObjectForKey:@"NSObject"] retain];	// if defined...
	extension=[[coder decodeObjectForKey:@"NSExtension"] retain];
//	owner=[[coder decodeObjectForKey:@"FilesOwner"] retain];
	owner=[[(NSKeyedUnarchiver *)coder delegate] _owner];
#if 0
	NSLog(@"className=%@", className);
	NSLog(@"object=%@", object);
	NSLog(@"extension=%@", extension);
	NSLog(@"owner=%@", owner);
#endif
	self=[[[self autorelease] nibInstantiate] retain];	// instantiate immediately
#if 0
	NSLog(@"custom object=%@", self);
#endif
	return self;
}

- (void) dealloc;
{
#if 0
	NSLog(@"NSCustomObject dealloc (class=%@) object=%@", className, object);
#endif
	[className release];
	[object release];
	[extension release];
	[super dealloc];
}

- (id) nibInstantiate;
{ // return real object or instantiate fresh one
	Class class;
#if 0
	NSLog(@"custom object nibInstantiate (class=%@)", className);
#endif
	// FIXME: how can we easily/correctly decode/load singletons???
	// maybe only if their -init method also returns the singleton
	if([className isEqualToString:@"NSApplication"])
		return [NSApplication sharedApplication];
	if(object)
		return object;
	class=NSClassFromString(className);
	if(!class)
		{
		NSLog(@"class %@ not linked for Custom Object", className);
		class=[NSObject class];
		}
	else if ([owner isKindOfClass: class])
		return owner;	// FIX ME  find better way to detect File's Owner
						// NSRoot is detected after objects are decoded
	return object=[[class alloc] init];
}

@end  /* NSCustomObject */


@implementation NSClassSwapper

- (void) encodeWithCoder:(NSCoder*)coder  { NIMP; }			// NSCoding Protocol

- (id) init								  { return NIMP; } // can't init normaly

- (NSString *) description;
{
	return [NSString stringWithFormat:@"%@: classname=%@ originalClassName=%@",
		NSStringFromClass([self class]), className, originalClassName];
}

- (id) initWithCoder:(NSCoder *)coder
{
	Class class;
#if 0
	NSLog(@"NSClassSwapper initWithCoder:%@", coder);
#endif
	if(![coder allowsKeyedCoding])
		return NIMP;
	className=[[coder decodeObjectForKey:@"NSClassName"] retain];
	originalClassName=[[coder decodeObjectForKey:@"NSOriginalClassName"] retain];
#if 0
	NSLog(@"className=%@", className);
	NSLog(@"originalClassName=%@", originalClassName);
#endif
	class=NSClassFromString(className);
	if(!class)
		{
		NSLog(@"class %@ not linked for Class Swapper Object; substituting %@", className, originalClassName);
		class=NSClassFromString(originalClassName);
		}
	if(!class)
		return nil;	// FIXME: exception
	// NOTE: we can't postpone instantiation because otherwise we don't have access to the coder any more
	realObject=[class alloc];	// allocate
	if([class instancesRespondToSelector:_cmd])
		{ // has an implementation of initWithCoder:
#if 0
		NSLog(@"realObject (%@) responds to -%@", NSStringFromClass(class), NSStringFromSelector(_cmd));
#endif
///		realObject=[realObject initWithCoder:coder];	// and decode
		realObject=[realObject _initWithKeyedCoder:(NSKeyedUnarchiver*)coder];	// and decode
		}
	else
		{
#if 0
		NSLog(@"realObject (%@) does not respond to -%@", NSStringFromClass(class), NSStringFromSelector(_cmd));
#endif
		realObject=[realObject init];
		}
	return [[[self autorelease] nibInstantiate] retain];	// directly return the instance - but someone may still hold a reference to the NSClassSwapper object
}

- (void) dealloc
{
#if 0
	NSLog(@"NSClassSwapper %@ dealloc", className);
#endif
	[className release];
	[originalClassName release];
	[realObject release];
	[super dealloc];
}

- (id) nibInstantiate
{
#if 0
	NSLog(@"NSClassSwapper %@ nibInstantiate -> %@", className, realObject);
#endif
	return realObject;
}

- (NSMethodSignature *) methodSignatureForSelector:(SEL)sel
{
	return [realObject methodSignatureForSelector:sel];
}

- (void) forwardInvocation:(NSInvocation *)i
{
	[i setTarget:realObject];
	[i invoke];
}

@end  /* NSClassSwapper */


@implementation NSCustomView

- (void) encodeWithCoder:(NSCoder*) coder		{ NIMP; }		// NSCoding Protocol

- (id) initWithCoder:(NSCoder *) coder;
{ /* NOTE: our implementation does not call super initWithCoder: ! */
/*
 NSClassName = <NSCFType: 0x318ad0>; 
 NSExtension = <NSCFType: 0x318a80>; 
 NSFrame = <NSCFType: 0x318ab0>; 
 NSNextResponder = <NSCFType: 0x318a90>; 
 NSSuperview = <NSCFType: 0x318aa0>; 
*/
#if 0
	NSLog(@"NSCustomView initWithCoder %@", coder);
#endif
	if(![coder allowsKeyedCoding])
		return NIMP;
	className=[[coder decodeObjectForKey:@"NSClassName"] retain];
	extension=[[coder decodeObjectForKey:@"NSExtension"] retain];	// is a NSString
	vFlags=[coder decodeIntForKey:@"NSvFlags"];
#if 0
	NSLog(@"vflags for custom view=%x", vFlags);
#endif
	_frame=[coder decodeRectForKey:@"NSFrame"];	// defaults to NSZeroRect if undefined
	if([coder containsValueForKey:@"NSFrameSize"])
		_frame.size=[coder decodeSizeForKey:@"NSFrameSize"];
	nextResponder=[[coder decodeObjectForKey:@"NSNextResponder"] retain];
	superView=[[coder decodeObjectForKey:@"NSSuperview"] retain];
	view=[[coder decodeObjectForKey:@"NSView"] retain];
	subviews=[[coder decodeObjectForKey:@"NSSubviews"] retain];	// this will indirectly ask us to nibInstantiate for each superview link!
	[coder decodeObjectForKey:@"NSWindow"];
#if 0
	NSLog(@"className=%@", className);
	NSLog(@"view=%@", view);
	NSLog(@"superview=%@", superView);
	NSLog(@"subviews=%@", subviews);
	NSLog(@"extension=%@", extension);
	NSLog(@"extension's class=%@", NSStringFromClass([extension class]));
	NSLog(@"nextResponder=%@", nextResponder);
#endif
	self=[[[self autorelease] nibInstantiate] retain];	// directly return the instance
#if 0
	NSLog(@"self=%@", self);
#endif
	return self;
}

- (void) dealloc
{
#if 0
	NSLog(@"dealloc %@", self);
#endif
	[view release];
	[nextResponder release];
	[superView release];
	[subviews release];
	[className release];
	[extension release];
	[super dealloc];
}

- (id) nibInstantiate
{
	Class class;
	NSView *v;
	NSEnumerator *e;
#if 0
	NSLog(@"NSCutomView nibInstantiate %@", className);
	NSLog(@"view=%@", view);
	NSLog(@"extension=%@", extension);
	NSLog(@"frame=%@", NSStringFromRect(_frame));
	NSLog(@"subviews=%@", subviews);
#endif
	if(!view)
		{ // allocate fresh one
		// FIXME: class translation should already be done during decoding
//		class=[(NSKeyedUnarchiver *) coder classForClassName:className];
//		if(!class)
			class=[NSKeyedUnarchiver classForClassName:className];
		if(!class)	// no substitution
			class=NSClassFromString(className);
		if(!class)
			{
			NSLog(@"class %@ not linked for Custom View", className);
			class=[NSView class];
			}
#if 0
		NSLog(@"class=%@", NSStringFromClass(class));
#endif
		view=[class alloc];
#if 0
		NSLog(@"  alloced=%@", view);
#endif
		view=[view initWithFrame:_frame];
#if 0
		NSLog(@"  inited with frame=%@", view);
#endif
		}
	if(nextResponder)
		[view setNextResponder:nextResponder], [nextResponder release], nextResponder=nil;
	if(superView)
		[superView addSubview:view], [superView release], superView=nil;
	if(subviews)
		{
		e=[subviews objectEnumerator];
		while((v=[e nextObject]))
			[view addSubview:v];	// attach subviews
		[subviews release];
		subviews=nil;
		}
#if 0
	NSLog(@"set custom view vFlags=%x", vFlags);
#endif
#define RESIZINGMASK ((vFlags>>0)&0x3f)	// 6 bit
	[view setAutoresizingMask:RESIZINGMASK];
//#define RESIZESUBVIEWS (((vFlags>>8)&1) != 0)
#define RESIZESUBVIEWS (RESIZINGMASK != 0)	// it appears that a custom view has no special bit for this case
	[view setAutoresizesSubviews:RESIZESUBVIEWS];
#define HIDDEN (((vFlags>>31)&1)!=0)
	[view setHidden:HIDDEN];

	return view;
}

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
	self = [super _initWithKeyedCoder:aDecoder];
//	self = [self initWithCoder:aDecoder];

	className = [[aDecoder decodeObjectForKey:@"NSClassName"] retain];
	subviews=[[aDecoder decodeObjectForKey:@"NSSubviews"] retain];	// this will indirectly ask us to nibInstantiate for each superview link!
	if([self isKindOfClass:[NSClipView class]])
		{
			NSLog(@"NSClipView -- self=%@ has  %d subviews", self, [_subviews count]);
		}

	return self;
}

@end  /* NSCustomView */


@implementation NSWindowTemplate

- (void) encodeWithCoder:(NSCoder*)coder		{ NIMP; }		// NSCoding Protocol

- (id) initWithCoder:(NSCoder*)coder
{
	Class class;
	if(![coder allowsKeyedCoding])
		return NIMP;
	// FIXME: we don't need to decode that all?
	maxSize=[coder decodeSizeForKey:@"NSMaxSize"];
	minSize=[coder decodeSizeForKey:@"NSMinSize"];
	screenRect=[coder decodeRectForKey:@"NSScreenRect"];	// visibleFrame of the screen when we were archived
	viewClass=[coder decodeObjectForKey:@"NSViewClass"];
	_wtFlags=[coder decodeIntForKey:@"NSWTFlags"];
	windowBacking=[coder decodeIntForKey:@"NSWindowBacking"];
	windowClass=[coder decodeObjectForKey:@"NSWindowClass"];
	windowRect=[coder decodeRectForKey:@"NSWindowRect"];
	windowStyleMask=[coder decodeIntForKey:@"NSWindowStyleMask"];
	windowTitle=[coder decodeObjectForKey:@"NSWindowTitle"];
	windowView=[coder decodeObjectForKey:@"NSWindowView"];
	autosaveName=[coder decodeObjectForKey:@"NSFrameAutosaveName"];
	[coder decodeObjectForKey:@"NSWindowContentMinSize"];
	[coder decodeObjectForKey:@"NSWindowContentMaxSize"];
#if 0
	NSLog (@"  screenRect = %@", NSStringFromRect(screenRect));
	NSLog (@"  windowRect = %@", NSStringFromRect(windowRect));
	NSLog (@"  windowStyleMask = %d", windowStyleMask);
	NSLog (@"  windowBacking = %d", windowBacking);
	NSLog (@"  windowTitle = %@", windowTitle);
	NSLog (@"  viewClass = %@", viewClass);
	NSLog (@"  windowClass = %@", windowClass);
	NSLog (@"  windowView = %@", [windowView _subtreeDescription]);
	NSLog (@"  realObject = %@", realObject);
	NSLog (@"  extension = %@", extension);
	NSLog (@"  minSize = %@", NSStringFromSize(minSize));
	NSLog (@"  maxSize = %@", NSStringFromSize(maxSize));
#endif
#if 0
	NSLog (@"  _wtFlags = %08x", _wtFlags);
#endif
	class=[(NSKeyedUnarchiver *) coder classForClassName:windowClass];
	if(!class)
		class=[NSKeyedUnarchiver classForClassName:windowClass];
	if(!class)	// no substitution
		class=NSClassFromString(windowClass);	// this allows to load a subclass
	if(!class)
		{
		NSLog(@"class %@ not linked or substituted for Custom Window", windowClass);
		class=[NSWindow class];
		}
	realObject=[[class alloc] initWithContentRect:windowRect
								  styleMask:windowStyleMask
									backing:windowBacking
									  defer:YES];
	[realObject setTitle:windowTitle];
	[realObject setContentView:windowView];
	[realObject setMinSize:minSize];
	[realObject setMaxSize:maxSize];
	if(!autosaveName)
		autosaveName=@"";
	[realObject setFrameAutosaveName:autosaveName];
#if 0	// FIXME: do something reasonable with these values
	if((_wtFlags>>19)&0x01)
		{ // right spring
		NSLog(@"right spring");
		}
	if((_wtFlags>>19)&0x02)
		{ // left spring
		NSLog(@"left spring");
		}
	if((_wtFlags>>19)&0x04)
		{ // top spring
		NSLog(@"top spring");
		}
	if((_wtFlags>>19)&0x08)
		{ // bottom spring
		NSLog(@"bottom spring");
		}
#endif
	return [[[self autorelease] nibInstantiate] retain];
}

- (id) nibInstantiate
{
	return realObject;
}

- (void) dealloc
{
#if 0 && defined(__mySTEP__)
	free(malloc(8192));
#endif	
	[realObject release];
	[super dealloc];
}

@end  /* NSWindowTemplate */


@implementation NSCustomResource

#if 0
- (NSSize) size;
{
	NSLog(@"!!! someone is asking for -size of %@", self); // this happens if we simply take it as an NSImage...
	abort();
	return NSMakeSize(10.0, 10.0);
}
#endif

- (NSString *) className		{ return _className; }
- (NSString *) name				{ return _resourceName; }

- (NSString *) description;
{
	return [NSString stringWithFormat:@"%@: classname=%@ resourcename=%@", NSStringFromClass([self class]), _className, _resourceName];
}
   
- (void) encodeWithCoder:(NSCoder*) coder		{ NIMP; }		// NSCoding Protocol

- (id) initWithCoder:(NSCoder *) coder
{
#if 0
	NSLog(@"%@ initWithCoder", NSStringFromClass([self class]));
#endif
	if(![coder allowsKeyedCoding])
		{
		return NIMP;
		}
	else
		{
		_className = [[coder decodeObjectForKey:@"NSClassName"] retain];
		_resourceName = [[coder decodeObjectForKey:@"NSResourceName"] retain];
#if 0
		NSLog(@"delegate: %@", [(NSKeyedUnarchiver *) coder delegate]);
		NSLog(@"bundle: %@", [[(NSKeyedUnarchiver *) coder delegate] _bundle]);
#endif
		if([_className isEqualToString:@"NSImage"])
			{
			NSImage *img = nil;
			[self autorelease];
#if 1
			NSLog(@"NSCustomResource replaced by NSImage: %@", _resourceName);
#endif
			if([_resourceName isEqualToString:NSApplicationIcon])
				{ // try to load application icon
///				NSString *subst=[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIconFile"];	// replace from Info.plist
//				NSString *subst=[[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSApplicationIcon"];	// replace from Info.plist
///				if([subst length] > 0)
///					ASSIGN(_resourceName, subst);			// try to load that one
				}
///			img=[[NSImage _imageNamed:_resourceName inBundle:[[(NSKeyedUnarchiver *) coder delegate] _bundle]] retain];
			if(! (img = [NSImage imageNamed:_resourceName]))
				NSLog(@"NSCustomResource did not find NSImage: %@", _resourceName);
			return img;
			}
#if 0
		NSLog(@"NSCustomResource initializedWithCoder: %@", self);
#endif
		}
	// we might look-up the object from a table and return a reference instead
#if 0
	NSLog(@"NSCustomResource initializedWithCoder: %@", self);
#endif
	[self autorelease];

	return [[NSClassFromString(_className) alloc] init];
}

@end  /* NSCustomResource */


@interface NSButtonImageSource : NSObject  <NSCoding>
{
	NSString *_name;
}
- (id) initWithName:(NSString *) name;
- (NSImage *) buttonImageForCell:(NSButtonCell *) cell;
@end

@implementation NSButtonImageSource

- (void) encodeWithCoder:(NSCoder*) coder		{ NIMP; }		// NSCoding Protocol

- (id) initWithCoder:(NSCoder *) coder
{
#if 0
	NSLog(@"%@ initWithCoder", NSStringFromClass([self class]));
#endif
	if(![coder allowsKeyedCoding])
		return NIMP;

	_name = [coder decodeObjectForKey:@"NSImageName"];	// NSRadioButton etc.

	if ([_name isEqualToString:@"NSSwitch"])
		{
		NSImage *img;

		[self autorelease];
		_name = @"NSHighlightedSwitch";
#if 1
		NSLog(@"NSButtonImageSource replaced by NSImage: %@", _name);
#endif
		if(! (img = [NSImage imageNamed:_name]))
			NSLog(@"NSButtonImageSource did not find NSImage: %@", _name);

		return img;
		}

	[_name retain];

	return self;
}

- (id) initWithName:(NSString *) name
{
	if((self=[super init]))
		{
		_name=[name retain];
		// we could already load images here
		}
	return self;
}

- (NSString *) name			{ return _name; }	// same as -[NSImage name]

- (NSString *) description	{ return [NSString stringWithFormat:@"NSButtonImageSource: %@", _name]; }

- (void) dealloc
{
	[_name release];
	[super dealloc];
}

- (NSImage *) buttonImageForCell:(NSButtonCell *) cell
{
	int state=[cell state];
	NSImage *img=nil;
#if 0
	NSLog(@"%@ buttonImageForCell:%@", self, cell);
#endif
	if([_name isEqualToString:@"NSRadioButton"])
		{
		switch(state)
			{
			default:
			case NSOffState:
				img=[NSImage imageNamed:@"NSRadioButton"];
				break;
			case NSMixedState:
			case NSOnState:
				img=[NSImage imageNamed:@"NSHighlightedRadioButton"];
				break;
			}
		}
	else if([_name isEqualToString:@"NSSwitch"])
		{
		switch(state)
			{
			default:
			case NSOffState:
				img=[NSImage imageNamed:@"NSSwitch"];
				break;
			case NSMixedState:
				img=[NSImage imageNamed:@"NSMultiStateSwitch"];
				break;
			case NSOnState:
				img=[NSImage imageNamed:@"NSHighlightedSwitch"];
				break;
			}
		}
	else if([_name isEqualToString:@"NSDisclose"])
		{
		if([cell isHighlighted])
			img=[NSImage imageNamed:@"GSDiscloseH"];
		else switch(state)
			{
			case NSOffState:
				img=[NSImage imageNamed:@"GSDiscloseOff"];
				break;
			case NSMixedState:
				img=[NSImage imageNamed:@"GSDiscloseHalf"];
				break;
			case NSOnState:
				img=[NSImage imageNamed:@"GSDiscloseOn"];
				break;
			}
		}
#if 0
	NSLog(@"image=%@", img);
#endif
	return img;
}

@end  /* NSButtonImageSource */

/* ****************************************************************************

	NSNib

** ***************************************************************************/

@implementation NSNib

- (Class) unarchiver:(NSKeyedUnarchiver *)unarchiver
			cannotDecodeObjectOfClassName:(NSString *)name
			originalClasses:(NSArray *)classNames
{
	NSLog(@"unarchiver:%@ cannotDecodeObjectOfClassName:%@ originalClasses:%@", unarchiver, name, classNames);
	return [NSNull class];	// substitute dummy
}

- (id) unarchiver:(NSKeyedUnarchiver *)unarchiver didDecodeObject:(id)object
{
#if 0
	NS_DURING
		NSLog(@"unarchiver:%@ didDecodeObject:%@", unarchiver, object);
	NS_HANDLER
		NSLog(@"unarchiver:%@ didDecodeObject:%@", unarchiver, NSStringFromClass([object class]));
	NS_ENDHANDLER
#endif
	if([_decodedObjects containsObject:object])
		{
			NSLog(@"duplicate - already unarchived: %@", object);
			return object;
		}

	[_decodedObjects addObject:object];

	return object;
}

#if 0
- (void) unarchiver:(NSKeyedUnarchiver *)unarchiver willReplaceObject:(id)object withObject:(id)newObject
{
	NSLog(@"unarchiver:%@ willReplaceObject:%@ withObject:%@", unarchiver, object, newObject);
}

- (void) unarchiverDidFinish:(NSKeyedUnarchiver *)unarchiver
{
	NSLog(@"unarchiverDidFinish:%@", unarchiver);
}

- (void) unarchiverWillFinish:(NSKeyedUnarchiver *)unarchiver
{
	NSLog(@"unarchiverWillFinish:%@", unarchiver);
}
#endif

- (id) initWithNibNamed:(NSString *)name bundle:(NSBundle *)bundle
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *nib;
	BOOL isDir;

//	NSLog(@"NSNib initWithNibNamed:%@ bundle:%@", name, [bundle bundlePath]);

	_bundle = (bundle) ? [bundle retain] : [[NSBundle mainBundle] retain];

	if ([name isAbsolutePath])
		_path = name;
	else
		{
		if ([name hasSuffix:@".nib"])
			name = [name stringByDeletingPathExtension];

		NSLog(@"name: %@", name);

		if(!(_path = [bundle pathForResource:name ofType:@"nib" inDirectory:nil]))
			{
			NSLog(@"not found in referencing bundle: %@", name);

			[self release];
			return nil;
			}
#if 0
	NSLog(@"bundle=%@", bundle);
	NSLog(@"bundlePath=%@", [bundle bundlePath]);
	NSLog(@"path=%@", _path);
#endif
		}
						// is file.nib itself a bundle ?  (IB 1.x - 2.x)
	if ([fm fileExistsAtPath:_path isDirectory:&isDir] && isDir)
		nib = [_path stringByAppendingPathComponent:@"keyedobjects.nib"];
	else
		nib = _path;  // s/b keyed archive itself (compiled by IB 3.x from XIB)

//	NSLog(@"loading model file %@", nib);
	if (!(_data = [[NSData alloc] initWithContentsOfMappedFile:nib]))
		{
		[self release];
		return nil;
		}

//	NSLog(@"file mapped %@", _path);

	return self;
}

- (void) dealloc
{
	[_bundle release];
	[_decodedObjects release];
	[_decoded release];
	[super dealloc];
}

- (BOOL) instantiateWithOwner:(id)owner topLevelObjects:(NSArray **)topObjects
{
	NSEnumerator *e;
	id o;
	id rootObject;
	NSKeyedUnarchiver *unarchiver;
	NSAutoreleasePool *arp=[NSAutoreleasePool new];

	_owner = owner;
	_decodedObjects = [[NSMutableSet alloc] initWithCapacity:100];	// will store all objects

//	NSLog(@"initialize unarchiver %@", _path);
	unarchiver=[[NSKeyedUnarchiver alloc] initForReadingWithData:_data];
	[_data release];	// clean up no longer needed unless archiver does
	if (!unarchiver)
		NSLog(@"can't open with keyed unarchiver");
	[unarchiver setDelegate:self];

//	NSLog(@"unarchiver decode IB.objectdata %@", _path);
	if (!(_decoded = [unarchiver decodeObjectForKey:@"IB.objectdata"]))
		NSLog(@"can't decode IB.objectdata");
	[unarchiver finishDecoding];
	[unarchiver release];	// no longer needed
	if(!_decoded)
		_decoded=[NSUnarchiver unarchiveObjectWithFile:[_path stringByAppendingPathComponent:@"objects.nib"]];	// try again by unarchiving
#if 1
	NSLog(@"decoded NSIBObjectData: %@", _decoded);
#endif
	if(!_decoded)
		{
		NSLog(@"Not able to decode model file %@ (maybe, old NIB format)", _path);
		[arp release]; 
		[self release];
		return NO;
		}
	[_decoded retain];	// keep decoded object

	[arp release];


	if(![_decoded isKindOfClass:[NSIBObjectData class]])
		return NO;

	if (topObjects)
		*topObjects = [NSMutableArray arrayWithCapacity:10];	// return top level objects

	rootObject = [_decoded rootObject];
#if 0
	NSLog(@"establishConnections");
#endif

	[_decoded _establishConnectionsWithOwner:owner];

#if 0
	NSLog(@"awakeFromNib %d objects", [_decodedObjects count]);
#endif
#if 0
	NSLog(@"objects 2=%@", _decodedObjects);
#endif

	e = [_decodedObjects objectEnumerator];	// awake objs from nib (in no specific order)
	while ((o = [e nextObject]))
		{
		if (o == rootObject)
			o = owner;	// replace

		if (topObjects)
			{
			if ([*topObjects indexOfObjectIdenticalTo:o])
				{
				NSLog(@"instantiateWithOwner: duplicate object: %@", o);
				continue;
				}
			[(NSMutableArray *) *topObjects addObject:o];
			}

		if ([o respondsToSelector:@selector(awakeFromNib)])
			{
#if 0
			NSLog(@"awakeFromNib: %@", o);
#endif
			[o awakeFromNib];							// Send awakeFromNib
			}
		}
	[_decodedObjects release];
	_decodedObjects = nil;

#if 0
	NSLog(@"orderFrontVisibleWindows");
#endif
	[_decoded orderFrontVisibleWindows];
	[_decoded release];
	_decoded = nil;

	return YES;
}

- (void) encodeWithCoder:(NSCoder *) aCoder				{ NIMP; }
- (id) initWithCoder:(NSCoder *) aDecoder				{ NIMP; return self; }

@end  /* NSNib */


@implementation NSBundle  (NSNibLoading)

- (BOOL) loadNibNamed:(NSString *)name
				owner:(id)owner
				topLevelObjects:(NSArray **)topObjects
{
	NSNib *n = [[[NSNib alloc] initWithNibNamed:name bundle:self] autorelease];

	return (n) ? [n instantiateWithOwner:owner topLevelObjects:topObjects] : NO;
}

+ (BOOL) loadNibNamed:(NSString*)name owner:(id)owner
{
	NSBundle *b;
	NSString *p;

	if ([name hasSuffix:@".mib"])
		return [GMModel loadMibFile:name owner:owner];

	if (!(b = [NSBundle bundleForClass:[owner class]]))
		b = [NSBundle mainBundle];

	if ([name isAbsolutePath]) 				// determine if path is absolute
		{									// and that it exists
		if (![[NSFileManager defaultManager] fileExistsAtPath:name])
			return NO;
		}
	else 
		{									// relative path; search in current
		if (!(p = [b pathForResource:name ofType:nil inDirectory:nil]))
			if (!(p = [[NSBundle systemBundle] pathForResource:name
											   ofType:nil
											   inDirectory:@"AppKit/Panels"]))
					return NO;
		name = p;
		}

	return [b loadNibNamed:name owner:owner topLevelObjects:NULL];
}

@end /* NSBundle (NibLoading) */


@implementation NSBundle (NSHelpManagerAdditions)

- (NSAttributedString *) contextHelpForKey:(NSString *) key
{
	return nil;
}

@end /* NSBundle (NSHelpManager) */


@implementation NSBundle (NSImageAdditions)

- (NSString *) pathForImageResource:(NSString *) name
{
	NSString *p;
	NSEnumerator *e = [[NSImage imageUnfilteredTypes] objectEnumerator];
	NSString *ftype;
	NSString *ext=[name pathExtension];
	if([ext length] > 0)
		{ // qualified by explicit extension
		if(![[e allObjects] containsObject:ext])
			return nil;	// is not in list of file types
		return [self pathForResource:[name stringByDeletingPathExtension] ofType:ext];
		}
	while((ftype=[e nextObject]))
		{ // try all file types
		p=[self pathForResource:name ofType:ftype];
		if(p)
			return p;	// found
		}
	return nil;	// not found
}

@end /* NSBundle (NSImage) */


@implementation NSBundle (NSSoundAdditions)

- (NSString *) pathForSoundResource:(NSString *) name
{
	NSString *p;
//	NSEnumerator *e=[[NSSound soundUnfilteredFileTypes] objectEnumerator];
	NSString *ftype;
	NSString *ext=[name pathExtension];
	if([ext length] > 0)
		{ // qualified by explicit extension
//		if(![[e allObjects] containsObject:ext])
//			return nil;	// is not in list of file types
		return [self pathForResource:[name stringByDeletingPathExtension] ofType:ext];
		}
//	while((ftype=[e nextObject]))
		{ // try all file types
//		p=[self pathForResource:name ofType:ftype];
//		if(p)
//			return p;	// found
		}
	return nil;	// not found
}

@end /* NSBundle (NSSound) */


#if 0
@implementation NSObject (NIB)

- (id) awakeAfterUsingCoder:(NSCoder *) coder;
{
	NSLog(@"awakeAfterUsingCoder:%@", coder);
	return self;
}

@end
#endif
