/*
   Controller.m

   Central controller object for Edit...

   Copyright (c) 1995-1996, NeXT Software, Inc.
   All rights reserved.
   Author: Ali Ozer

   You may freely copy, distribute and reuse the code in this example.
   NeXT disclaims any warranty of any kind, expressed or implied,
   as to its fitness for any particular use.

   mGSTEP changes are:
   Author:  Felipe A. Rodriguez <far@pcmagic.net>
   Date:	November 1998
*/

#import <AppKit/AppKit.h>
#import "Controller.h"
#import "Document.h"

#include <math.h>


BOOL __showLineNumbers = 0;


@implementation Controller

- (void) method:menuCell							// temp for sake of menu
{
  	NSLog (@"method invoked from cell with title '%@'", [menuCell title]);
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
	NSLog(@"Edit prepareForDragOperation\n");
	return YES;
}

- (NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender
{
	NSLog(@"Edit draggingEntered\n");
	return NSDragOperationGeneric;
}

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSArray *arguments = [[NSProcessInfo processInfo] arguments];
	NSString *initialFile;

	[[NSApp appIcon] setDelegate:self];
	[[[NSApp appIcon] contentView] registerForDraggedTypes:nil];

	if ([arguments count] < 2) 
		initialFile = [[[NSBundle mainBundle] bundlePath]
						stringByAppendingString:@"/Resources/README"];
	else
		initialFile = [arguments objectAtIndex:1];

	__showLineNumbers = [[defaults objectForKey:@"LineNumbers"] intValue];

	[[Document alloc] initWithPath:initialFile encoding:UnknownStringEncoding];
}

- (BOOL) applicationShouldTerminate:(NSApplication *)app 
{
	NSArray *windows = [app windows];
	unsigned count = [windows count];
	BOOL needsSaving = NO;
												// Determine if there are any 
    while (!needsSaving && count--) 			// unsaved documents.
		{
        NSWindow *window = [windows objectAtIndex:count];
        Document *d = (Document *)[Document documentForWindow:window];

        if (d && [d isDocumentEdited]) 
			needsSaving = YES;
		}

    if (needsSaving) 
		{
		NSString *quit = @"Title of alert panel which comes up when user \
							chooses Quit and there are unsaved documents.";
		NSString *unsaved = @"Message in the alert panel which comes up when \
						user chooses Quit and there are unsaved documents.";
		NSString *review = @"Choice (on a button) given to user which allows \
						him/her to review all unsaved documents if he/she \
						quits the application without saving them all first.";
		NSString *anyway = @"Choice (on a button) given to user which allows \
						him/her to quit the application even though there are \
						unsaved documents.";
		NSString *cancel = @"Button choice allowing user to cancel.";
        int choice = NSRunAlertPanel(NSLocalizedString(@"Quit", quit), 
					NSLocalizedString(@"You have unsaved documents.", unsaved), 
					NSLocalizedString(@"Review Unsaved", review), 
					NSLocalizedString(@"Quit Anyway", anyway), 
					NSLocalizedString(@"Cancel", cancel));

        if (choice == NSAlertOtherReturn)  
            return NO;											// Cancel

		if (choice != NSAlertAlternateReturn) 
			{								// Review unsaved; Quit Anyway 
			count = [windows count];		// falls through

			while (count--) 
				{
				NSWindow *window = [windows objectAtIndex:count];
				Document *d = (Document *)[Document documentForWindow:window];

				if (d && (![d canCloseDocument])) 
					return NO;
		}	}	}

//	[Preferences saveDefaults];

    return YES;
}

- (void) applicationWillTerminate:(NSNotification *)aNotification
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSNumber *show = [NSNumber numberWithBool: __showLineNumbers];

	[defaults setObject:show forKey:@"LineNumbers"];
	[defaults synchronize];
}

- (BOOL) application:(NSApplication *)sender openFile:(NSString *)filename 
{
			// If the document is in a .rtfd and it's name is TXT.rtf or 
			// index.rtf, open the parent dir... This is because on windows it  
			// doesn't seem trivial to open folders as files via a double click

#ifdef WIN32
	NSString *parentDir = [filename stringByDeletingLastPathComponent];

    if ([[[parentDir pathExtension] lowercaseString] isEqualToString:@"rtfd"])
		{
        NSString *lastPathComponent = [[filename lastPathComponent] 
										lowercaseString];
        if ([lastPathComponent isEqualToString:@"txt.rtf"] || 
				[lastPathComponent isEqualToString:@"index.rtf"]) 
			{
	    	filename = parentDir;
        	}
    	}
#endif

    return [Document openDocumentWithPath:filename 
					 encoding:UnknownStringEncoding] ? YES : NO;
}

- (BOOL) application:(NSApplication *)sender openTempFile:(NSString *)filename 
{									
    return [Document openDocumentWithPath:filename 				// ??? Why?
					 encoding:UnknownStringEncoding] ? YES : NO;
}

- (BOOL) applicationOpenUntitledFile:(NSApplication *)sender 
{
    return [Document openUntitled];
}

- (BOOL) application:(NSApplication *)sender printFile:(NSString *)filename 
{
	BOOL retval = NO;
	BOOL releaseDoc = NO;
	Document *d = (Document *)[Document documentForPath:filename];
    
    if (!d) 
		{
        d =  [[Document alloc] initWithPath: filename 
							   encoding: UnknownStringEncoding];
        releaseDoc = YES;
    	}
    if (d) 
		{
        BOOL useUI = [NSPrintInfo defaultPrinter] ? NO : YES;

        [d printDocumentUsingPrintPanel:useUI];
        retval = YES;

        if (releaseDoc) 				// If we created it, we get rid of it.
            [d release];
		}

    return retval;
}

- (void) createNew:(id)sender 		{ (void)[Document openUntitled]; }
- (void) open:(id)sender 			{ (void)[Document open:sender]; }

- (void) saveAll:(id)sender 
{
	NSArray *windows = [[NSApplication sharedApplication] windows];
	unsigned count = [windows count];

    while (count--) 
		{
        NSWindow *window = [windows objectAtIndex:count];
        Document *d = (Document *)[Document documentForWindow:window];

        if (d) 
			{
            if ([d isDocumentEdited]) 
				{
                if (![d saveDocument:NO]) 
					return;
        }   }	}
}

- (void) showInfoPanel:(id)menuCell
{
	if (!_aboutPanel)
		{
		[NSApp orderFrontStandardAboutPanel:self];
		[_applicationVersion setStringValue: APPKIT_VERSION];
		[_aboutPanel center];
		}
	[_aboutPanel orderFront: self];
//    [infoPanel makeKeyAndOrderFront:nil];
}

@end


@interface NSObject (Layout)

- (NSRect) lineRect;
- (NSRange) charRange;

@end


@interface NSTextView (LineNumbering)

- (void) drawHeaderRect:(NSRect)rect;						

@end



@interface HeaderView : NSView
{
	NSTextView *_textView;
}

- (void) setTextView:(NSTextView *)aView;						

@end


@implementation HeaderView

- (void) drawRect:(NSRect)rect
{
	[[NSColor lightGrayColor] set];
	NSRectFill(rect);					
	[_textView drawHeaderRect:NSIntersectionRect(rect, [self visibleRect])];

	[[NSColor darkGrayColor] set];
	NSMinX(rect) = NSMaxX(rect) - 1.0;
	NSWidth(rect) = 1.0;
	NSRectFill(rect);
}

- (BOOL) isFlipped								{ return YES; }
- (BOOL) isOpaque								{ return YES; }
- (void) setTextView:(NSTextView *)aView		{ _textView = aView; }

@end


@implementation NSTextView (LineNumbering)

- (BOOL) autoscroll:(NSEvent *)event					// Auto Scrolling
{
	BOOL didScroll = [super autoscroll:event];

	if (didScroll && _headerView)
		[_headerView autoscroll:event];

	return didScroll;
}

- (void) drawHeaderRect:(NSRect)rect						
{
	NSDictionary *attr = [self defaultTypingAttributes];
	NSRange r = [self lineRangeForRect:rect];
	NSObject *array[r.length];
	unichar c = [@"\n" characterAtIndex:0];
	int i, linesDrawn = 0, ro = 0;
	float y;

	if(![_lineLayoutInformation count])		// empty
		return;
	[_lineLayoutInformation getObjects:array range:r];
											// determine the actual starting
	if (r.location++ != 0)					// line number if not drawing from
		{									// the beginning of the text
		ro = [array[0] charRange].location;
		for (i = 0, r.location = 1; i < ro; i++)
			if (c == [plainContent characterAtIndex:i])
				r.location++;
		}

	y = NSMinY([array[0] lineRect]);
	for(i = 0; i < r.length; i++)
		{
		NSRange ra = [array[i] charRange];
		NSRect lineRect = [array[i] lineRect];

		if (y != NSMinY(lineRect))
			{
			if (!ro || c == [plainContent characterAtIndex:MAX(0,ro-1)])
				{
				unsigned int n = r.location++;
				
				while (n > 9999)			// clip to 9999 (width of field)
					n -= 9999;

				[[NSString stringWithFormat:@"%d",n] drawAtPoint:(NSPoint){2,y}
													 withAttributes:attr];
				}
			else
				{
				[@"    " drawAtPoint:(NSPoint){2,y} withAttributes:attr];
				if (linesDrawn == 0)		// if first line to be drawn is
					r.location++;			// blank we must inc line num
				}

			y = NSMinY(lineRect);
			ro = ra.location;
			linesDrawn++;
		}	}

	while (r.location > 9999)
		r.location -= 9999;

	if (!ro || c == [plainContent characterAtIndex:MAX(0,ro-1)])
		{
		NSString *s = [NSString stringWithFormat: @"%d", r.location];

		[s drawAtPoint:(NSPoint){2,y} withAttributes:attr];
		}
	else
		[@"    " drawAtPoint:(NSPoint){2,y} withAttributes:attr];
}

- (void) setHeaderVisibility	{ _tx.headerVisible = __showLineNumbers; }

- (NSView *) headerView
{
	if (!_tx.headerVisible)
		return nil;
	if (!_headerView)
		{
		NSRect f = (NSRect){{0,0},{30,MAX(31,_bounds.size.height)}};

		_headerView = [[HeaderView alloc] initWithFrame: f];
		[(HeaderView *)_headerView setTextView: self];
		}

	return _headerView;
}

- (void) setFrameSize:(NSSize)newSize
{
	[super setFrameSize: newSize];

	if (_tx.headerVisible && _headerView)
		{
		[_headerView setFrameSize: (NSSize){30,newSize.height}];
		[_headerView setNeedsDisplay: YES];
		}
}

- (void) toggleLineNumbers:(id)menuCell
{
	int cRepGState;
	NSRect rect, t;

	if (_tx.headerVisible == __showLineNumbers)
		__showLineNumbers = _tx.headerVisible = !__showLineNumbers;
	else
		_tx.headerVisible = __showLineNumbers;

  	NSLog (@"toggleLineNumbers: invoked from cell with title '%@' tx = %d",
			[menuCell title],_tx.headerVisible);
	
	if (_tx.headerVisible)
		{
		[self lockFocus];
		cRepGState = [self gState];
		rect = [self visibleRect];
		NSCopyBits(cRepGState, rect, (NSPoint){30,NSMinY(rect)});
		[self unlockFocus];
		}
	else
		{
		float inset = [_superview frame].origin.x;		// text clip view inset

		[(NSScrollView *)[_superview superview] lockFocus];
		cRepGState = [self gState];
		rect = (NSRect){{inset,0},[[_superview superview] visibleRect].size};
		NSWidth(rect) -= inset + 1;
		NSCopyBits(cRepGState, rect, (NSPoint){0,0});
		[(NSScrollView *)[_superview superview] unlockFocus];

		[[_superview superview] setNeedsDisplay: YES];
		}

	DBLog (@"toggleLineNumbers: rect (%1.2f, %1.2f), (%1.2f, %1.2f)\n",
			rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);

	[_window flushWindow];
	[(NSScrollView *)[_superview superview] setDocumentView: self];
	if (_tx.headerVisible)
		[_headerView setNeedsDisplay: YES];
	[[self window] makeFirstResponder: self];
}

- (void) shiftRight:(id)menuCell
{
	id content = (_tx.isRichText) ? [rtfContent string] : plainContent;
	unichar c = [@"\n" characterAtIndex:0];
	NSRange redrawLineRange;
	NSRange sr = _selectedRange;
	int end = NSMaxRange(_selectedRange);
	int lineIndex = [self lineLayoutIndexForCharacterIndex: sr.location]; 
	int lineCount = [_lineLayoutInformation count];
	int len = 0;

	if (_selectedRange.length)			// end of select should not include nl
		while (end-- > 0 && (c == [content characterAtIndex: end]));

	for (; end >= 0; end--)
		if (end == 0 || c == [content characterAtIndex: end])
			{
NSLog(@"Controller insert tab at  %d\n", end);
			[content insertString:@"\t" atIndex: ((end) ? end+1 : end)];
			len++;
			if (end <= _selectedRange.location)
				break;					// insert tabs until the first nl
			}							// preceding the start of the selection

	redrawLineRange = _NSAbsoluteRange(lineIndex, lineCount);
	if(_tx.isRichText)
		redrawLineRange.length = [self _rebuildRTFLineLayoutFromLine:redrawLineRange.location
									   delta:len - sr.length
									   actualLine:lineIndex];
	else
		redrawLineRange.length = [self _rebuildPlainLineLayoutFromLine:redrawLineRange.location
									   delta:len - sr.length
									   actualLine:lineIndex];
	[self sizeToFit];								// ScrollView interaction

	sr = (sr.length) ? (NSRange){sr.location, sr.length+len}
					 : (NSRange){sr.location+len, sr.length};
	[self setSelectedRange: sr];

//	redrawLineRange = NSIntersectionRange(redrawLineRange, [self lineRangeForRect:[self visibleRect]]);
	lineCount = [self lineLayoutIndexForCharacterIndex:NSMaxRange(sr)];
	redrawLineRange = (NSRange){lineIndex, MAX(1, (lineCount - lineIndex)+1)};

	NSLog(@"Controller redisplay linerange %d  %d\n", redrawLineRange.location,redrawLineRange.length);
	[self _displayLineRange:redrawLineRange];
	[NSNotificationCenter post:NSTextDidChangeNotification object:self];
}

- (void) shiftLeft:(id)menuCell
{
	id content = (_tx.isRichText) ? [rtfContent string] : plainContent;
	unichar c = [@"\n" characterAtIndex:0];
	unichar t = [@"\t" characterAtIndex:0];
	unichar s = [@" " characterAtIndex:0];
	NSRange redrawLineRange;
	NSRange sr = _selectedRange;
	int end = NSMaxRange(_selectedRange);
	int lineIndex = [self lineLayoutIndexForCharacterIndex: sr.location]; 
	int lineCount = [_lineLayoutInformation count];
	int len = [content length];
	
	if (_selectedRange.length)			// end of select should not include nl
		while (end-- > 0 && (c == [content characterAtIndex: end]));

	for (; end >= 0; end--)
		if (end == 0 || c == [content characterAtIndex: end])
			{
			int index = ((end) ? end+1 : end);
			int tabWidth = 4;
			
			while (tabWidth--)
				{
				if ([content characterAtIndex: index] == t)
					{
					if (index < _selectedRange.location)
						sr.location--;
					else
						sr.length--;
					[content deleteCharactersInRange: (NSRange){index,1}];
					break;
					}
				else if ([content characterAtIndex: index] == s)
					{
					if (index < _selectedRange.location)
						sr.location--;
					else
						sr.length--;
					[content deleteCharactersInRange: (NSRange){index,1}];
					}
				else
					break;
				}
			if (end <= _selectedRange.location)
				break;
			}

	redrawLineRange = _NSAbsoluteRange(lineIndex, lineCount);
	if(_tx.isRichText)
		redrawLineRange.length = [self _rebuildRTFLineLayoutFromLine:redrawLineRange.location
									   delta:len - sr.length
									   actualLine:lineIndex];
	else
		redrawLineRange.length = [self _rebuildPlainLineLayoutFromLine:redrawLineRange.location
									   delta:len - sr.length
									   actualLine:lineIndex];
	[self sizeToFit];								// ScrollView interaction
	[self setSelectedRange: sr];

//	redrawLineRange = NSIntersectionRange(redrawLineRange, [self lineRangeForRect:[self visibleRect]]);
	lineCount = [self lineLayoutIndexForCharacterIndex:NSMaxRange(sr)];
	redrawLineRange = (NSRange){lineIndex, MAX(1, (lineCount - lineIndex)+1)};

	NSLog(@"Controller redisplay linerange %d  %d\n", redrawLineRange.location,redrawLineRange.length);
	[self _displayLineRange:redrawLineRange];
	[NSNotificationCenter post:NSTextDidChangeNotification object:self];
}

@end  /* NSTextView (LineNumbering) */
