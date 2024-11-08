/*
   Viewer.m

   Image viewer  (TIF, JPG, PNG, GIF, PGM, PPM)

   Copyright (C) 1999-2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	March 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#import <AppKit/AppKit.h>


// Class variables
static NSArray *__fileTypesPNM = nil;
static NSTimer *__frameAnimTimer = nil;


/* ****************************************************************************

		_BitmapImageRepPNM

** ***************************************************************************/

@interface _BitmapImageRepPNM : NSBitmapImageRep
@end

@implementation _BitmapImageRepPNM

+ (void) initialize
{
	if (self == [_BitmapImageRepPNM class])
		__fileTypesPNM = [[NSArray arrayWithObjects: @"pgm", @"ppm", nil] retain];
}

+ (BOOL) canInitWithData:(NSData *)data
{
	unsigned char sig[] = {'P','5'};
	unsigned char sg2[] = {'P','6'};

	return _CGImageCanInitWith( (CFDataRef)data, sig, sizeof(sig) )
		|| _CGImageCanInitWith( (CFDataRef)data, sg2, sizeof(sg2) );
}

+ (NSArray *) imageUnfilteredFileTypes		{ return __fileTypesPNM; }

+ (NSArray *) imageRepsWithData:(NSData *)data
{
	CGImageRef g = _CGImageReadPNM((CFDataRef)data);
	_BitmapImageRepPNM *imageRep;
	NSMutableArray *array = nil;
	
	if (g && (imageRep = [[[self class] alloc] initWithCGImage:g]))
		{
		array = [NSMutableArray arrayWithCapacity:1];
		[array addObject: [imageRep autorelease]];
		}

	return array;
}

@end

@interface NSBitmapImageRep  (_Animation)
- (CGFloat) _animTime;
@end

/* ****************************************************************************

		NSImageView

** ***************************************************************************/

@implementation NSImageView	(ScrollWheel)

- (void) scrollWheel:(NSEvent *)event
{
	NSSize s = [_window frame].size;

	if ([event pressure] > 0)
		[_window setContentSize: (NSSize){s.width*2, s.height*2}];
	else
		[_window setContentSize: (NSSize){s.width/2, s.height/2}];
}

@end

@interface ImageView : NSImageView
{
	unsigned animIndex;
}

@end

@implementation ImageView

- (void) _nextFrame:(id)sender
{
	[self display];
}

- (BOOL) resignFirstResponder						// NSResponder overrides
{
	if (__frameAnimTimer)
		[__frameAnimTimer invalidate],		__frameAnimTimer = nil;

	return YES;
}

- (void) _beginAnimating:(NSImage *)image
{
	CGFloat delayTime = .1;
	id irep = [[image representations] objectAtIndex: 0];

	if ([irep respondsToSelector: @selector(_animTime)])
		if ((delayTime = [irep _animTime]) < .001)
			delayTime = .1;

	__frameAnimTimer = [NSTimer timerWithTimeInterval: delayTime
								target: self
								selector: @selector(_nextFrame:)
								userInfo: nil
								repeats: YES];

	[[NSRunLoop currentRunLoop] addTimer:__frameAnimTimer
								forMode: NSDefaultRunLoopMode];
}

- (BOOL) becomeFirstResponder
{
	if (!__frameAnimTimer)
		{
		NSImage *image = [_cell objectValue];

		if ([[image representations] count] > 1)
			[self _beginAnimating: image];
		}

	return YES;
}

- (void) setImage:(NSImage *)image
{
	[super setImage:image];

	if (!__frameAnimTimer && [[image representations] count] > 1)
		[self _beginAnimating: image];
}

- (void) drawRect:(NSRect)rect
{
	if (__frameAnimTimer)
		{
		NSImage *image = [_cell objectValue];
		NSArray *a = [image representations];
		int i = animIndex++ % [a count];

		[image lockFocusOnRepresentation: [a objectAtIndex: i]];
		}

	[super drawRect:rect];
}

- (void) keyDown:(NSEvent *)e				// set scaling quality F1 or F2
{
	NSString *s = [e charactersIgnoringModifiers];

	if ([s length] == 1)
		{
		unichar ch = [s characterAtIndex: 0];

		if (ch == NSF1FunctionKey || ch == NSF2FunctionKey)
			{
			CGContextRef cx = [[_window graphicsContext] graphicsPort];
			
			if (ch == NSF1FunctionKey)
				CGContextSetInterpolationQuality( cx, kCGInterpolationHigh);
			else
				CGContextSetInterpolationQuality( cx, kCGInterpolationLow);
		}	}
}

@end

/* ****************************************************************************

		Document

** ***************************************************************************/

@interface Document : NSDocument
@end

@implementation Document

+ (void) open:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];

	[panel setAllowsMultipleSelection:YES];
///	[panel setDirectory:[Document openSavePanelDirectory]];	  // FIX ME

    if ([panel runModal]) 
		{
        NSArray *filenames = [panel filenames];
        unsigned cnt, numFiles = [filenames count];

       for (cnt = 0; cnt < numFiles; cnt++) 
			{
            NSString *filename = [filenames objectAtIndex:cnt];

			DBLog(@"open file %s\n", [filename cString]);

            if (![[Document alloc] initWithPath:filename])
				{
				NSString *title = NSLocalizedString(@"File system error", nil);
				NSString *m = NSLocalizedString(@"Could not open file %@.",0);
				NSString *d = NSLocalizedString(@"OK", nil);
                NSString *alternate = (cnt + 1 == numFiles) 
									? nil : NSLocalizedString(@"Abort", nil);

                if((NSRunAlertPanel(title, m, d, alternate, nil, filename)
						== NSCancelButton)) 
					break;
		}	}	}
}

- (id) initWithPath:(NSString *)filename
{
	NSRect f, wr = {{100,0},{0,0}};
	ImageView *v;
	NSImage *m;
	NSSize aspect = {1,1};

    if (!filename || !(m = [[NSImage alloc] initWithContentsOfFile:filename]))
		return nil; 

	wr.size = [m size];
	f = [NSWindow frameRectForContentRect:(NSRect){{0,0}, wr.size} styleMask:0];

	if (wr.size.width > wr.size.height)
		aspect.width = wr.size.width / wr.size.height;
	else
		aspect.height = wr.size.height / wr.size.width;

	if (wr.size.height > f.size.height)						// maintain aspect
		{
		wr.size.height = f.size.height;
		wr.size.width *= 1 / aspect.height;
		}
	if (wr.size.width > f.size.width)
		{
		wr.size.width = f.size.width;
		wr.size.height *= 1 / aspect.width;
		}

	v = [[ImageView alloc] initWithFrame: (NSRect){{0,0}, wr.size}];
	[v setImage:m];
	[v setImageScaling:NSScaleToFit];
	[v setAutoresizingMask: (NSViewWidthSizable|NSViewHeightSizable)];

	_window = [[NSWindow alloc] initWithContentRect:(NSRect){50,50,50,50}
								styleMask:_NSCommonWindowMask
								backing:NSBackingStoreBuffered
								defer:NO];
	[_window setDelegate:self];
	[_window setTitle:[filename lastPathComponent]];
	[self setDocumentName:filename];
	[[_window contentView] addSubview: v];
	[_window setContentSize: wr.size];
	[_window setAspectRatio: aspect];
	[_window makeFirstResponder:v];

	if (NSMinY(wr) <= 0 || (NSMinY(wr) - NSHeight(wr) - 50 <= 0))
		wr.origin.y = NSHeight([[NSScreen mainScreen] frame]) - 50;
	wr.origin = [_window cascadeTopLeftFromPoint:wr.origin];
	[_window makeKeyAndOrderFront:nil];

    return self;
}

+ (BOOL) openDocumentWithPath:(NSString *)filename 
{
	NSDocument *d = [self documentForPath:filename];
													// create new doc + window
	if (!d && ![(Document *)(d = [self alloc]) initWithPath:filename])
		[d release];
	else
		{
		[[d window] makeKeyAndOrderFront:nil];

        return YES;
		} 

	return NO;
}

- (BOOL) getDocumentName:(NSString **)newName oldName:(NSString *)oldName 
{												
	NSSavePanel *panel = [NSSavePanel savePanel];	// Puts up a save panel to get
	BOOL result;									// a final name from the user.

//    if (potentialSaveDirectory) 
//		[Document setLastOpenSavePanelDirectory:potentialSaveDirectory];

	if (oldName)
		{
		NSString *d = [oldName stringByDeletingLastPathComponent];
		NSString *f = [oldName lastPathComponent];

		result = [panel runModalForDirectory:d file:f];
		}
	else
		{
//		NSString *d = [Document openSavePanelDirectory];

		result = [panel runModalForDirectory:NSHomeDirectory() file:@""];
		}

	if (result) 
		{
        *newName = [panel filename];

//		if (potentialSaveDirectory) 
//	    	[self setPotentialSaveDirectory:nil];
		} 

	return result;
}

- (BOOL) saveDocument:(BOOL)showSavePanel 
{
	NSString *nameForSaving = [self documentName];
	NSBitmapImageRep *b;
	NSWindow *w;
	NSData *tif;
	NSView *v;

	if (!(w = [NSApp mainWindow]))
		return NO;

	while (1)
		{
        if (!nameForSaving || showSavePanel) 
            if (![self getDocumentName:&nameForSaving oldName:nameForSaving]) 
				return NO;	/* Cancelled */

		[(v = [w contentView]) lockFocus];
		b = [[NSBitmapImageRep alloc] initWithFocusedViewRect: [v bounds]];
		tif = [b TIFFRepresentation];
		[v unlockFocus];

       if ([tif writeToFile:nameForSaving atomically:NO]) 
			{
//            [self setDocumentName:nameForSaving];
//	    	[Document setLastOpenSavePanelDirectory:[nameForSaving 
//						stringByDeletingLastPathComponent]];
			return YES;
			}

		NSRunAlertPanel(@"Cannot Save",
			NSLocalizedString(@"Couldn't save document as %@.", @"Document save error."),
			NSLocalizedString(@"OK", @"OK."), nil, nil, nameForSaving);
		nameForSaving = nil;
		}

    return YES;
}

- (void) saveAs:(id)sender 				{ (void)[self saveDocument:YES]; }
- (void) save:(id)sender 				{ (void)[self saveDocument:NO]; }

@end /* Document */

/* ****************************************************************************

		Controller

** ***************************************************************************/

@interface Controller : NSObject
{
	NSMutableArray *imageArray;
	int index;
	BOOL cycled;
}

@end


@implementation Controller

- (void) open:(id)sender				{ [Document open:self]; }

- (void) method:(id)menuCell
{
	NSLog (@"method invoked from cell with title '%@'", [menuCell title]);
}

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	Document *document;
	NSString *m = [[NSBundle mainBundle] bundlePath];
	NSProcessInfo *processInfo = [NSProcessInfo processInfo];
	NSArray *arguments = [processInfo arguments];
	NSString *initialFile;

	[[NSApp appIcon] setDelegate:self];
	[[[NSApp appIcon] contentView] registerForDraggedTypes:nil];

	[NSImageRep registerImageRepClass: [_BitmapImageRepPNM class]];

	if ([arguments count] < 2)
		initialFile = [m stringByAppendingString:@"/Resources/g4.tiff"];
	else
		initialFile = [arguments objectAtIndex:1];

	document = [[Document alloc] initWithPath:initialFile];
}

- (BOOL) application:(NSApplication *)sender openFile:(NSString *)filename 
{
    return [Document openDocumentWithPath:filename];
}

- (BOOL) performDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSDragPboard];
	NSString *Path = [pb stringForType:NSFilenamesPboardType];

	NSLog (@"performDragOperation Path: '%@'\n", Path);

	if ([self application:NSApp openFile:Path])
		return YES;

	return NO;
}

- (NSDragOperation) draggingUpdated:(id <NSDraggingInfo>)sender
{
	return NSDragOperationGeneric;
}

- (BOOL) prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	NSLog(@"viewer prepareForDragOperation\n");
	return YES;
}

- (NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender
{
	NSLog(@"viewer draggingEntered\n");
	return NSDragOperationGeneric;
}

@end /* Controller */
