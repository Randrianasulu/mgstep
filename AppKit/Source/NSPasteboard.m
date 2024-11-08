/*
   NSPasteboard.m

   Manage cut/copy/paste operations.

   Copyright (C) 1997 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@pcmagic.net>
   Date:    August 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSProcessInfo.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSPasteboard.h>


// Class variables
static NSMutableDictionary *__pasteboards = nil;
static NSString *__contentsPrefix = @"NSTypedFileContentsPboardType:";
static NSString *__namePrefix = @"NSTypedFilenamesPboardType:";


@implementation NSPasteboard

+ (NSPasteboard *) generalPasteboard
{
	return [self pasteboardWithName: NSGeneralPboard];
}

+ (NSPasteboard *) pasteboardWithName:(NSString *)aName
{
	NSPasteboard *pb;

	if (!(pb = [__pasteboards objectForKey: aName]))
		{
		pb = [NSPasteboard new];
		pb->_name = aName;
		pb->_typesProvided = [NSMutableArray new];
		pb->_wait = 3;

		if(!__pasteboards)
			__pasteboards = [[NSMutableDictionary alloc] initWithCapacity:8];
		[__pasteboards setObject:pb forKey:aName];
		}

	return pb;
}

+ (NSPasteboard *) pasteboardWithUniqueName
{
	NSProcessInfo *p = [NSProcessInfo processInfo];

	return [self pasteboardWithName:[p globallyUniqueString]];
}
															// Filter contents
+ (NSPasteboard *) pasteboardByFilteringData:(NSData *)data
									  ofType:(NSString *)type
{
	return nil;
}

+ (NSPasteboard *) pasteboardByFilteringFile:(NSString *)filename
{
	NSData *data = [NSData dataWithContentsOfFile:filename];
	NSString *type = NSCreateFileContentsPboardType([filename pathExtension]);

	return [self pasteboardWithName:filename];
}

+ (NSPasteboard *) pasteboardByFilteringTypesInPasteboard:(NSPasteboard *)pb
{
	return nil;
}

+ (NSArray *) typesFilterableTo:(NSString *)type
{
	NSArray *types = nil;

	return types;
}

- (void) dealloc
{
	[_typesProvided release];
	[_types release];
	[_name release];
	[_owner release];
	[super dealloc];
}

- (void) releaseGlobally
{
	[_target releaseGlobally];
	[__pasteboards removeObjectForKey: _name];
}

- (NSString *) name						{ return _name; }
- (NSArray *) types						{ return _types; }
- (int) changeCount						{ return _changeCount; }

- (int) addTypes:(NSArray *)newTypes owner:(id)newOwner
{
	ASSIGN(_owner, newOwner);
	ASSIGN(_types, [_types arrayByAddingObjectsFromArray: newTypes]);
	[_typesProvided addObjectsFromArray: newTypes];

	return _changeCount++;
}

- (int) declareTypes:(NSArray *)newTypes owner:(id)newOwner
{
	ASSIGN(_types, newTypes);
	ASSIGN(_typesProvided, [_types mutableCopy]);
	ASSIGN(_owner, newOwner);

	return _changeCount++;
}

- (BOOL) setData:(NSData *)data forType:(NSString *)dataType
{
	return NO;
}

- (BOOL) setPropertyList:(id)propertyList forType:(NSString *)dataType
{
	int i = [_types indexOfObjectIdenticalTo:dataType];

	[_typesProvided replaceObjectAtIndex:i withObject:propertyList];

	return YES;
}

- (BOOL) setString:(NSString *)string forType:(NSString *)dataType
{
	NSLog(@"place: \"%@\" onto the pasteboard", string);
	return [self setPropertyList:string forType:dataType];
}

- (NSString *) availableTypeFromArray:(NSArray *)types
{
	if (!_types)		// FIX ME hack for paste in app that did not copy/cut
		_types = [[NSArray arrayWithObjects: NSStringPboardType, nil] retain];

	return [_types firstObjectCommonWithArray:types];
}

- (NSData *) dataForType:(NSString *)dataType
{
	return nil;
}

- (id) propertyListForType:(NSString *)dt
{
	if (!_owner)
		{
		NSMutableDictionary *d = [NSMutableDictionary new];
		NSMutableArray *files = [NSMutableArray new];
		NSString *s = [self stringForType:dt];

		NSLog(@"********* propertyListForType: %@\n",dt);

		[files addObject:s];
		[d setObject:s forKey:@"SourcePath"];
		[d setObject:files forKey:@"SelectedFiles"];

		return d;
		}

	if ([_owner respondsToSelector: @selector(pasteboard:provideDataForType:)])
		[_owner pasteboard:self provideDataForType:dt];

	return [_typesProvided objectAtIndex:[_types indexOfObjectIdenticalTo:dt]];
}

- (NSString *) stringForType:(NSString *)dataType
{
	NSLog(@"paste: \"%@\" from pasteboard", [self propertyListForType:dataType]);
	return [self propertyListForType: dataType];
}

- (BOOL) writeFileContents:(NSString *)filename
{
	NSData *data = [NSData dataWithContentsOfFile:filename];
	NSString *type = NSCreateFileContentsPboardType([filename pathExtension]);

	return NO;
}

- (NSString *) readFileContentsType:(NSString *)type
							 toFile:(NSString *)filename
{
	NSData *d;

	if (type == nil) 
		type = NSCreateFileContentsPboardType([filename pathExtension]);

	d = [self dataForType: type];
	if ([d writeToFile: filename atomically: NO] == NO) 
		return nil;

	return filename;
}

@end /* NSPasteboard */


NSString *
NSCreateFileContentsPboardType(NSString *fileType)
{
	return [NSString stringWithFormat:@"%@%@", __contentsPrefix, fileType];
}

NSString *
NSCreateFilenamePboardType(NSString *filename)
{
	return [NSString stringWithFormat:@"%@%@", __namePrefix, filename];
}

NSString *
NSGetFileType(NSString *pboardType)
{
	if ([pboardType hasPrefix: __contentsPrefix]) 
		return [pboardType substringFromIndex: [__contentsPrefix length]];

	if ([pboardType hasPrefix: __namePrefix]) 
		return [pboardType substringFromIndex: [__namePrefix length]];

	return nil;
}

NSArray *
NSGetFileTypes(NSArray *pboardTypes)
{
	NSMutableArray *a = [NSMutableArray arrayWithCapacity: [pboardTypes count]];
	unsigned int i;

	for (i = 0; i < [pboardTypes count]; i++) 
		{
		NSString *s = NSGetFileType([pboardTypes objectAtIndex:i]);
	
		if (s && ! [a containsObject:s]) 
			[a addObject:s];
		}

	if ([a count] > 0) 
		return [[a copy] autorelease];

	return nil;
}

#ifdef FB_GRAPHICS
#else  /* !FB_GRAPHICS */

/* ****************************************************************************

	XR Pasteboard

** ***************************************************************************/

#include <Foundation/NSString.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSProcessInfo.h>

#include <AppKit/NSPasteboard.h>
#include <AppKit/NSEvent.h>
#include <AppKit/NSApplication.h>
#include <CoreGraphics/CoreGraphics.h>

#include "xdnd.h"

#define FULL_LENGTH	 8192L					// Amount to read from properties
#define NUM_ATOMS	 13

#define CTX					((CGContext *)cx)
#define XDND				((DndClass *)CTX->_mg->_dnd)


// Class variables
static char *__primaryPasteboard = NULL;
static BOOL  __processingSelectionRequest = 0;
static int __internd = 0;
static Atom __atoms[NUM_ATOMS];


char *atom_names[NUM_ATOMS] = { "CHARACTER_POSITION",
								"CLIENT_WINDOW",
								"HOST_NAME",
								"HOSTNAME",
								"LENGTH",
								"LIST_LENGTH",
								"NAME",
								"OWNER_OS",
								"SPAN",
								"TARGETS",
								"TIMESTAMP",
								"USER",
								"TEXT"};

#define XR_CHAR_POSITION 	0					// Macros to access elements 
#define XR_CLIENT_WINDOW 	1					// in atom_names array
#define XR_HOST_NAME		2
#define XR_HOSTNAME			3
#define XR_LENGTH			4
#define XR_LIST_LENGTH		5
#define XR_NAME				6
#define XR_OWNER_OS			7
#define XR_SPAN				8
#define XR_TARGETS			9
#define XR_TIMESTAMP		10
#define XR_USER				11
#define XR_TEXT				12


Atom 
xConvertTarget(Display *display, Atom desired_target)
{   												
    if (!__internd)										// intern atoms 
        __internd = XInternAtoms(display,atom_names,NUM_ATOMS,False,__atoms);
														// Check common cases. 
    if ((desired_target == __atoms[XR_TIMESTAMP]) 
			|| (desired_target == __atoms[XR_LIST_LENGTH]) 
			|| (desired_target == __atoms[XR_LENGTH]))
        return XA_INTEGER;

    if (desired_target == __atoms[XR_CHAR_POSITION])
        return __atoms[XR_SPAN];

    if (desired_target == __atoms[XR_TARGETS])
        return XA_ATOM;

    if (desired_target == __atoms[XR_CLIENT_WINDOW])
        return XA_WINDOW;

    if ((desired_target == __atoms[XR_HOST_NAME]) 
			|| (desired_target == __atoms[XR_HOSTNAME]) 
			|| (desired_target == __atoms[XR_NAME]) 
			|| (desired_target == __atoms[XR_OWNER_OS]) 
			|| (desired_target == __atoms[XR_USER])) 
        return XA_STRING;

    return desired_target;						// no need to convert target
}   	

unsigned char *
xConvertSelection(Display *display,
				  Window window,
				  Atom xTarget,
				  char *program,
				  char *text_data,
				  Atom *new_target,   				// return
				  int *format,						// return
				  int *number_items)				// return
{   										
	unsigned char *data = NULL;							// Convert text data to
	int length;											// selection target.
	char *user_name;

    if (!__internd)									// intern atoms 
        __internd = XInternAtoms(display,atom_names,NUM_ATOMS,False, __atoms);
    *number_items = 0;								// Initialize.
    *format = 32;						// In virtually all cases, format is 32

    if ((xTarget == XA_STRING) || (xTarget == __atoms[XR_TEXT])) 
		{
        length = strlen(text_data);
        data = (unsigned char*) malloc(length + 1);

        if (data != NULL)
            strcpy(data, text_data);

        *format = 8;   								// Exception to format rule 
        *number_items = length;
		}

    if (xTarget == __atoms[XR_TIMESTAMP]) 
		{
        length = sizeof(int);
        data = (unsigned char*) malloc( length );
        *number_items = 1;
		}

    if (xTarget == __atoms[XR_CLIENT_WINDOW]) 
		{
        length = sizeof(Window);
        data = (unsigned char*) malloc( length );
        *number_items = 1;
		}

    if (xTarget == __atoms[XR_LENGTH]) 
		{
        length = sizeof(int);
        data = (unsigned char*) malloc( length );
        *number_items = 1;
    	}

    if (xTarget == __atoms[XR_NAME]) 
		{
        length = strlen(program) + 1;
        data = (unsigned char*) malloc( length );
        strcpy(data, program);
        *number_items = length;
    	}

    if (xTarget == __atoms[XR_USER]) 
		{				// assume the USER environment variable has this value.
        user_name = getenv("USER");
        length = strlen(user_name) + 1;
        data = (unsigned char*) malloc(length);
        strcpy(data, user_name);
        *number_items = length;
		}

    if ((xTarget == __atoms[XR_HOSTNAME]) || (xTarget ==__atoms[XR_HOST_NAME])) 
		{
		const char *host = [[[NSProcessInfo processInfo] hostName] cString];

        length = strlen(host) + 1;
        data = (unsigned char*) malloc(length);
        strcpy(data, host);
        *number_items = length;
		}

    if (xTarget == __atoms[XR_CHAR_POSITION]) 
		{
        length = sizeof(int) * 2;
        data = (unsigned char*) malloc( length );
        *number_items = 2;
		}

    if (xTarget == __atoms[XR_TARGETS]) 
		{
        length = sizeof(Atom) * NUM_ATOMS;
        data = (unsigned char*) malloc(length);
		}

    *new_target = xConvertTarget(display, xTarget);		// convert target type

    return data;
}   

static Bool 
xProvideSelection(XSelectionRequestEvent *event,
				  Window window,
				  Atom property,
				  Atom target,
				  char *program,  				// program name 
				  char *text_data)
{   
	unsigned char *data;						// serves up selection data
	Atom new_target;
	int format, number_items;
	Bool status = False;
												// convert text data to user's
    data = xConvertSelection(event->display,	// requested format
							 window, 
							 target, 
							 program,
							 text_data,
							 &new_target,
							 &format,
							 &number_items);

	if ((data != NULL) && (number_items > 0)) 
		{										// Write data out to property.
		if ((XChangeProperty(event->display,
							 event->requestor,
							 property,
							 new_target,
							 format,
							 PropModeAppend,
							 data,
							 number_items)) == 0)
			NSLog(@"xProvideSelection: XChangeProperty failed\n");
		else
			status = True;

        XSync(event->display, False);
		}

	if (data)
		XFree(data);							

	return status;
}   

/* ****************************************************************************

	XRPerformSelectionRequest()

	Respond with our selection data

** ***************************************************************************/

void
XRPerformSelectionRequest(CGContext *cx, XSelectionRequestEvent *xe)
{
	Window xAppRootWindow = [(NSGraphicsContext *)cx xAppRootWindow];
	XSelectionEvent notify;
	unsigned char *data = NULL;
	unsigned long number_items, bytes_remaining;
	int status, i, actual_format;
	Atom MULTIPLE, actual_target;
	Atom *atom_array;

	if ((xe->owner != xAppRootWindow) || (xe->selection != XA_PRIMARY))
		return;
											// check for a target of MULTIPLE
    MULTIPLE = XInternAtom(xe->display, "MULTIPLE", False);

    if (xe->target == MULTIPLE) 
		{
	// For a target of MULTIPLE, there will be a property (in the xEvent) that 
	// contains ATOM_PAIRS, pairs of Atom IDs. In each pair, the first item is 
	// the target, the second is the property to write that target's data to.

        status = XGetWindowProperty(xe->display,			// read property
									xe->requestor,
									xe->property,
									0L,        				// offset
									FULL_LENGTH,
									True,      				// delete when read
									XA_ATOM,
									&actual_target,
									&actual_format,
									&number_items,
									&bytes_remaining,
									&data);
		if (status != Success) 
			{
            number_items = 0;
            status = False;
			}

        atom_array = (Atom*)data;
    
        for (i = 0; i < number_items; i += 2) 
			{
            Atom xTarget = atom_array[i];
            Atom property = atom_array[i+1];

            status = xProvideSelection( xe,
										xAppRootWindow,
										property,
										xTarget,
										"primary",
										__primaryPasteboard);
		}	}
	else 
		{
        status = xProvideSelection( xe,
									xAppRootWindow,
									xe->property,
									xe->target,
									"primary",
									__primaryPasteboard);
		}
										// Provide the data to the property.
	notify.display	 = xe->display;
    notify.type		 = SelectionNotify;
    notify.requestor = xe->requestor;
    notify.selection = xe->selection;
    notify.target	 = xe->target;
    notify.time		 = xe->time;
    notify.property	 = xe->property;
										// On errors, still send message but 
    if (status == False)				// pass a 0 for the property.
        notify.property = None;
	else
		if(data)
			XFree(data);
										// Send event to the requesting program
	XSendEvent(xe->display, xe->requestor, False, 0L, (XEvent*)&notify);
}

void
XRSelectionRequest(CGContext *cx, XSelectionRequestEvent *xe)
{
	if (__processingSelectionRequest)
		{
		NSLog(@"PB: recieved XRSelectionRequest() while busy ******");
		return;
		}
	__processingSelectionRequest = 1;

	if (XDND && xe->selection == XDND->XdndSelection && xe->type == SelectionRequest)
		{
		NSPasteboard *p = [NSPasteboard pasteboardWithName:NSDragPboard];
		NSDictionary *d = [p propertyListForType:NSFilenamesPboardType];
		NSString *s;

		if ((s = [d objectForKey:@"SourcePath"]))
			{
			s = [@"file://" stringByAppendingString:s];

			xdnd_selection_send(XDND, xe, [s cString], [s length]);
		}	}
	else
		XRPerformSelectionRequest(cx, xe);

	__processingSelectionRequest = 0;
}

/* ****************************************************************************

	XRSelectionNotify()

	Owner of selection has signaled that data is ready to be read from property

** ***************************************************************************/

void
XRSelectionNotify(CGContext *cx, XSelectionEvent *xe)
{
	unsigned long bytes_remaining, number_items;
	Atom actual_target, new_target = XA_STRING;
	int status, actual_format;
	unsigned char *data = NULL;

	NSLog(@"_handleSelectionNotify:\n");
															// validate x event
//  if ((xEvent->property == (Atom) None) || (xEvent->selection != XA_PRIMARY) 
//			|| (xEvent->requestor == (Window) None)) 
    if ((xe->property == (Atom)None) || (xe->requestor == (Window)None))
		{
        NSLog(@"Owning program failed to convert data.\n");
		return;
		}
    									// Check if we need to convert target.
	new_target = xConvertTarget(xe->display, xe->target);

										// Read data from property identified
										// in SelectionNotify event.
    status = XGetWindowProperty(xe->display,
								xe->requestor,
								xe->property,
								0L,					// offset
								FULL_LENGTH,
								True,     			// Delete prop when read.
								new_target,
								&actual_target,
								&actual_format,
								&number_items,
								&bytes_remaining,
								&data);

    if ((status == Success) && (number_items > 0)) 
		{										// Convert data to text string.
// string = PropertyToString(xDisplay,new_target,number_items,(char*)data);

		NSLog(@"_handleSelectionNotify: data  %s\n",data);

		if (new_target == XA_STRING) 
			__primaryPasteboard = strdup(data);
		else
			{
			if (new_target == XDND->types[0])	// FIX ME handle multiple files
				{
				if (strlen(data) > 7)
					__primaryPasteboard = strdup(data+7);
				else
					__primaryPasteboard = strdup(data);
				}
			else
				__primaryPasteboard = strdup(data);
			}

		if (data)
            XFree(data);
		}
}

/* ****************************************************************************

	NSPasteboard  (XRPasteboard)

** ***************************************************************************/

@implementation NSPasteboard  (XRPasteboard)

- (BOOL) setString:(NSString *)string forType:(NSString *)dataType
{
	NSGraphicsContext *cx = [NSGraphicsContext currentContext];
	Display *xDisplay = [cx xDisplay];
	Window xAppRootWindow = [cx xAppRootWindow];

	NSLog(@"place: \"%@\" onto the pasteboard", string);

	if (__primaryPasteboard)
		free(__primaryPasteboard);
	__primaryPasteboard = strdup([string cString]);

	if (_name == NSDragPboard)
		{
		xdnd_set_selection_owner(XDND, xAppRootWindow, 0);

		return YES;
		}

	XSetSelectionOwner(xDisplay, XA_PRIMARY, xAppRootWindow, CurrentTime);

												// check if we acquired primary
//	owner = XGetSelectionOwner( xDisplay, selection );
//	if ( owner != xAppRootWindow )
//		fprintf(stderr, "failed to aquire primary selection\n");
//	return [self setPropertyList: string forType: dataType];

	return YES;
}

/* ****************************************************************************

	Potential endless loop:
	
	XRSelectionRequest() --> PB propertyListForType: -->
		PB stringForType: --> NSApp nextEventMatchingMask: -->
			XRContext SelectionRequest --> XRSelectionRequest()

** ***************************************************************************/

- (NSString *) stringForType:(NSString *)dataType
{
	NSGraphicsContext *cx = [NSGraphicsContext currentContext];
	Display *d = [cx xDisplay];
	Window w = [cx xAppRootWindow];

	NSLog(@"pasting from the pasteboard");

///	if (_owner && __primaryPasteboard && _name == NSDragPboard)
///		return [NSString stringWithCString:__primaryPasteboard];

					// Ask X server to forward request to selection owner.
	if (_name != NSDragPboard)
		XConvertSelection(d, XA_PRIMARY, XA_STRING, XA_STRING, w, CurrentTime);
	else
		if (xdnd_convert_selection (XDND, None, w, XDND->types[0]))
			return @"XRPasteboard Bad Conversion";
					// Request selection data for text display use the target
    XFlush(d);		// atom also as the property to write the incoming data to

	while (_wait-- && ([[NSApp nextEventMatchingMask:NSAnyEventMask
							   untilDate:[NSDate dateWithTimeIntervalSinceNow:1]
							   inMode:NSDefaultRunLoopMode
							   dequeue:YES] type] != NSFlagsChanged));
	if (_wait == 0)
		{
		NSLog(@"PB: -stringForType timeout waiting for selection data ****");
		__processingSelectionRequest = 0;
		}

	_wait = 3;
	NSLog(@"paste: \"%s\" from the pasteboard", __primaryPasteboard);

	if (__primaryPasteboard)
		return [NSString stringWithCString:__primaryPasteboard];

	return @"XRPasteboard Bad Conversion";
}

@end /* NSPasteboard  (XRPasteboard) */

#endif  /* !FB_GRAPHICS */
