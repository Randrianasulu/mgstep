/*
   Document.m

   Document object for Edit...

   Copyright (c) 1995-1996, NeXT Software, Inc.
   All rights reserved.
   Author: Ali Ozer

   You may freely copy, distribute and reuse the code in this example.
   NeXT disclaims any warranty of any kind, expressed or implied,
   as to its fitness for any particular use.

   mGSTEP changes:
   Author:  Felipe A. Rodriguez <far@ix.netcom.com>
   Date: May 1999
*/

#include <math.h>
#include <stdio.h>				// for NULL

#include <AppKit/AppKit.h>

#import "Document.h"
#import "MultiplePageView.h"
#import "TextFinder.h"

// Class variables
static NSString *_lastOpenSavePanelDir = nil;
static NSPopUpButton *encodingPopupButton = nil;
static NSView *encodingAccessory = nil;
static NSPoint __nextWindowTop = (NSPoint){200, 0};


@interface NSTextView (LineNumbering)

- (void) setHeaderVisibility;

@end


@implementation Document

+ (BOOL) openUntitled 
{
	Document *d;

    if ((d = [[self alloc] initWithPath:nil encoding:UnknownStringEncoding]))
		{
		[d setPotentialSaveDirectory:[Document openSavePanelDirectory]];
		[d setDocumentName:nil];
        [[d window] makeKeyAndOrderFront:nil];

        return YES;
    	} 

	return NO;
}

+ (BOOL) openDocumentWithPath:(NSString *)filename encoding:(int)encoding 
{
	Document *document = (Document *)[self documentForPath:filename];

	if (!document)								// create new document/window
		{
        document = [[self alloc] initWithPath:filename encoding:encoding];

		DBLog(@"did not use an existing window");
		}
	else
		DBLog(@"using an existing window");

    if (document) 
		{
//      [document doForegroundLayoutToCharacterIndex:[[Preferences 
//				  objectForKey:ForegroundLayoutToIndex] intValue]];

		[[document window] makeKeyAndOrderFront:nil];

        return YES;
		} 

	return NO;
}

+ (void) setLastOpenSavePanelDirectory:(NSString *)dir 
{												// Sets the directory in which  
    if (_lastOpenSavePanelDir != dir) 			// a save was last done.
		{
		[_lastOpenSavePanelDir autorelease];
		_lastOpenSavePanelDir = [dir copy];
		}
}
											// Returns the directory in which 
+ (NSString *) openSavePanelDirectory 		// open/save panels should come up.
{
//	if ([[Preferences objectForKey:OpenPanelFollowsMainWindow] boolValue]) 
    if (-1) 
		{
		Document *doc = (Document *)[Document documentForWindow:[NSApp mainWindow]];

		if (doc && [doc documentName]) 
            return [[doc documentName] stringByDeletingLastPathComponent];

		if (doc && _lastOpenSavePanelDir) 
	    	return _lastOpenSavePanelDir;
		} 
	else 
		if (_lastOpenSavePanelDir) 
			return _lastOpenSavePanelDir;

    return NSHomeDirectory();
}

+ (unsigned) numberOfOpenDocuments	{ return 0; }
+ (void) open:(id)sender			{ [self openWithEncodingAccessory:YES]; }

+ (void) openWithEncodingAccessory:(BOOL)flag 
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];

	if (flag) 
		{
//		[panel setAccessoryView:[self encodingAccessory:[[Preferences 
//		objectForKey:PlainTextEncoding] intValue] includeDefaultEntry:YES]];
		}

	[panel setAllowsMultipleSelection:YES];
///	[panel setDirectory:[Document openSavePanelDirectory]];	  // FIX ME oPanel

    if ([panel runModal]) 
		{
        NSArray *filenames = [panel filenames];
        unsigned cnt, numFiles = [filenames count];

 fprintf(stderr," number of doc %d\n", numFiles);

       for (cnt = 0; cnt < numFiles; cnt++) 
			{
            NSString *filename = [filenames objectAtIndex:cnt];
//			int encoding = flag ? [[encodingPopupButton selectedItem] tag]
//								: UnknownStringEncoding;
			int encoding = UnknownStringEncoding;

fprintf(stderr," open doc %s\n",[filename cString]);

            if (![Document openDocumentWithPath:filename encoding:encoding]) 
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

- (id) init 
{
	self = [super init];

//	if (![NSBundle loadNibNamed:@"Document" owner:self]) 
//		{
//		fprintf(stderr, "Cannot open Document model file\n");
//   	return nil;
//		}
    					// This ensures the first view gets set up correctly
    [self setupInitialTextViewSharedState];

    return self;
}

- (id) initWithPath:(NSString*)filename encoding:(int)encoding
{
	NSRect winRect = (NSRect){NSZeroPoint, {550, 400}};
	NSRect scrollViewRect = (NSRect){{0, 0}, {550, 400}};
	NSRect textViewRect = (NSRect){{0, 0}, {525, 396}};
	NSTextView *textView;
	NSColor *backColor;
	NSScrollView *sv;

    if (!(self = [self init])) 
		return nil;

	if (filename && ![self loadFromPath:filename encoding:encoding]) 
		return _NSInitError(self, @"failed to load file %@", filename);

    if (filename)
		{
		NSString *d = [filename stringByDeletingLastPathComponent];

		[Document setLastOpenSavePanelDirectory: d];
		}

	_window = [[NSWindow alloc] initWithContentRect:winRect
								styleMask:_NSCommonWindowMask
								backing:NSBackingStoreBuffered
								defer:NO];
	if (__nextWindowTop.y == 0)
		__nextWindowTop.y = NSHeight([[NSScreen mainScreen] frame]) - 100;
	__nextWindowTop = [_window cascadeTopLeftFromPoint:__nextWindowTop];

	sv = [[NSScrollView alloc] initWithFrame:scrollViewRect];
	[sv setBorderType: NSNoBorder];
	[sv setHasVerticalScroller:YES]; 
	[sv setAutoresizingMask: (NSViewWidthSizable|NSViewHeightSizable)];
	[sv setScrollerStyle:NSScrollerStyleOverlay];
	[sv setKnobStyle:NSScrollerKnobStyleLight];
	[sv setVerticalScrollElasticity: NSScrollElasticityAllowed];

	textView = [self firstTextView];
	[textView setHeaderVisibility];
	[textView setAutoresizingMask: NSViewWidthSizable];
	[textView setFrame: textViewRect];
//	[textView setFont: [NSFont fontWithName:@"ohlfs" size:12]];
	[textView setFont: [NSFont fontWithName:@"Courier" size:12]];
	backColor = [NSColor colorWithCalibratedWhite:0.85 alpha:1.0]; 
	[textView setBackgroundColor:backColor];					// off white

	[sv setDocumentView:textView];
	[[_window contentView] addSubview: sv];
	[_window setDelegate:self];
	[_window setInitialFirstResponder:textView];
	[_window display];
    [_window orderFront:self];

	[sv release];
	[textView release];

//	[[self firstTextView] setSelectedRange:NSMakeRange(0, 0)];
	[self setDocumentName:filename];

    return self;
}

- (void) dealloc 								// Clear the delegates of the 
{												// text views and window, then 
    [[self firstTextView] setDelegate:nil];		// release all resources and go 
    [super dealloc];							// away...
}

- (void) setupInitialTextViewSharedState 
{
	NSTextView *textView = [self firstTextView];
    
//	[textView setUsesFontPanel:YES];
	[textView setDelegate:self];
//	[self setRichText:[[Preferences objectForKey:RichText] boolValue]];
//	[self setHyphenationFactor:0.0];
}

- (NSTextView *) firstTextView 
{
    return (!_textView) ? (_textView = [NSTextView new]) : _textView;
}

- (NSSize) viewSize					{ return [scrollView contentSize]; }

- (void) setViewSize:(NSSize)size 
{
	NSWindow *window = [scrollView window];
	NSRect origWindowFrame = [window frame];
	BOOL hasHoriz = [scrollView hasHorizontalScroller];
	BOOL hasVert = [scrollView hasVerticalScroller];
	NSSize scrollViewSize = [NSScrollView frameSizeForContentSize:size 
										  hasHorizontalScroller: hasHoriz 
										  hasVerticalScroller:hasVert
										  borderType:[scrollView borderType]];

    [window setContentSize:scrollViewSize];
    [window setFrameTopLeftPoint:NSMakePoint(origWindowFrame.origin.x, 
											NSMaxY(origWindowFrame))];
}
				// This method causes the text to be laid out in the foreground
				// (approximately) up to the indicated character index.
- (void) doForegroundLayoutToCharacterIndex:(unsigned)loc 
{}

- (void) setDocumentName:(NSString *)filename 
{
    [_documentName autorelease];
    if (filename) 
		{
        _documentName = [[filename stringByResolvingSymlinksInPath] copy];
        [[self window] setTitleWithRepresentedFilename:_documentName];
		} 
	else 
		{
		NSString *untitled = NSLocalizedString(@"UNTITLED", @"untitled doc");

        if ([self isRichText]) 
			untitled = [untitled stringByAppendingPathExtension:@"rtf"];
		if (potentialSaveDirectory) 
			{
			NSString *u = [potentialSaveDirectory stringByAppendingPathComponent:untitled];

			[[self window] setTitleWithRepresentedFilename: u];
			} 
		else 
			[[self window] setTitle:untitled];

        _documentName = nil;
		}
}

- (void) setPotentialSaveDirectory:(NSString *)nm 
{
}

- (NSString *) potentialSaveDirectory 
{
}

- (void) setDocumentEdited:(BOOL)flag 
{
    if (flag != isDocumentEdited) 
		{
        isDocumentEdited = flag;
        [[self window] setDocumentEdited:isDocumentEdited];
		}
}

- (BOOL) isRichText							{ return isRichText; }
- (BOOL) isDocumentEdited					{ return isDocumentEdited; }
- (BOOL) hasMultiplePages					{ return hasMultiplePages; }
- (void) setHasMultiplePages:(BOOL)flag		{ hasMultiplePages = flag; }
- (NSTextStorage *) textStorage				{ return textStorage; }
- (NSPrintInfo *) printInfo					{ return printInfo; }

- (void) setPrintInfo:(NSPrintInfo *)anObject 
{
}

- (unsigned) numberOfPages 
{												// Multiple page related code
    if (hasMultiplePages) 
        return [[scrollView documentView] numberOfPages];

	return 1;
}

- (void) setScrollView:(id)anObject 
{															// Outlet methods
    scrollView = anObject;
    [scrollView setHasVerticalScroller:YES];
    [scrollView setHasHorizontalScroller:NO];
    [[scrollView contentView] setAutoresizesSubviews:YES];
//    [self fixUpScrollViewBackgroundColor:nil];
}
        
- (void) close:(id)sender 				{ [[self window] close]; }
- (void) saveTo:(id)sender 				{ [self saveAs:sender]; }	  // FIX ME
- (void) saveAs:(id)sender 				{ (void)[self saveDocument:YES]; }
- (void) save:(id)sender 				{ (void)[self saveDocument:NO]; }
												
- (BOOL) saveDocument:(BOOL)showSavePanel 
{
	NSString *nameForSaving = [self documentName];	// Saves the document. Puts up
	int encodingForSaving;							// save panel if necessary or
	BOOL haveToChangeType = NO;						// if showSavePanel is YES.
	BOOL showEncodingAccessory = NO;				// Returns NO if the user
        										// cancels the save...
    if ([self isRichText]) 
		{
        if (nameForSaving && [@"rtfd" isEqualToString:[nameForSaving pathExtension]])
            encodingForSaving = RichTextWithGraphicsStringEncoding;
		else
			{
	    	encodingForSaving = [textStorage containsAttachments] ? 
				   RichTextWithGraphicsStringEncoding : RichTextStringEncoding;
            if ((encodingForSaving == RichTextWithGraphicsStringEncoding) 
					&& nameForSaving && ![@"rtfd" isEqualToString:[nameForSaving pathExtension]])
                nameForSaving = nil;		// Force user to provide a new name
        }	}
	else 
		{
//		NSString *string = [textStorage string];
        NSString *string;

        showEncodingAccessory = YES;
        encodingForSaving = encodingIfPlainText;

//        if ((encodingForSaving != UnknownStringEncoding) 
//				&& ![string canBeConvertedToEncoding:encodingForSaving]) 
//			{
//			haveToChangeType = YES;
//			encodingForSaving = UnknownStringEncoding;
//        	}
        if (encodingForSaving == UnknownStringEncoding) 
			{
//          NSStringEncoding defaultEncoding = [[Preferences 
//								objectForKey:PlainTextEncoding] intValue];
            NSStringEncoding defaultEncoding = NSASCIIStringEncoding;

            if ([string canBeConvertedToEncoding:defaultEncoding]) 
				{
                encodingForSaving = defaultEncoding;
            	} 
			else 
				{
//              const int *plainTextEncoding = SupportedEncodings();
				int encodings[] = {NSASCIIStringEncoding, 0};
                const int *plainTextEncoding = encodings;

                while (*plainTextEncoding != -1) 
					{
                    if ((*plainTextEncoding >= 0) 
							&& (*plainTextEncoding != defaultEncoding) 
							&& (*plainTextEncoding != NSUnicodeStringEncoding) 
							&& (*plainTextEncoding != NSUTF8StringEncoding) && 
						[string canBeConvertedToEncoding:*plainTextEncoding]) 
						{
                        encodingForSaving = *plainTextEncoding;
                        break;
                    	}
                    plainTextEncoding++;
                }	}

			if (encodingForSaving == UnknownStringEncoding) 
				encodingForSaving = NSUnicodeStringEncoding;
			if (haveToChangeType) 
				{
				(void)NSRunAlertPanel(NSLocalizedString(@"Save Plain Text",0), 
							NSLocalizedString(@"Document can no longer be saved using its original %@ encoding. Please choose another encoding (%@ is one possibility).", nil), 
				NSLocalizedString(@"OK", @"OK."), nil, nil, [NSString localizedNameOfStringEncoding:encodingIfPlainText], [NSString localizedNameOfStringEncoding:encodingForSaving]);
		}	}	}

	while (1) 
		{
        if (!nameForSaving || haveToChangeType || showSavePanel) 
			{
			int *en = (haveToChangeType || showEncodingAccessory) 
					? &encodingForSaving : NULL;

            if (![self getDocumentName:&nameForSaving
					   encoding:en
					   oldName:nameForSaving 
					   oldEncoding:encodingForSaving]) 
				return NO;	/* Cancelled */
			}
					// The value of updateFileNames: below will have to become 
					// conditional on whether we're doing Save To at some 
					// point.  Also, we'll want to avoid doing the stuff inside 
					// the 'if' if we're doing Save To.
        if ([self saveToPath:nameForSaving 
				  encoding:encodingForSaving 					// save file
				  updateFilenames:YES]) 
			{
            if (![self isRichText]) 
				encodingIfPlainText = encodingForSaving;
            [self setDocumentName:nameForSaving];
            [self setDocumentEdited:NO];
	    	[Document setLastOpenSavePanelDirectory:[nameForSaving 
						stringByDeletingLastPathComponent]];
			return YES;
			}
		else 
			{
            NSRunAlertPanel(@"Couldn't Save",
                NSLocalizedString(@"Couldn't save document as %@.", 
	@"Message indicating document couldn't be saved under the given name."),
                NSLocalizedString(@"OK", @"OK."), nil, nil, nameForSaving);
            nameForSaving = nil;
			}
		}

    return YES;
}

- (BOOL) getDocumentName:(NSString **)newName 
				encoding:(int *)encodingForSaving 
				oldName:(NSString *)oldName 
				oldEncoding:(int)encoding 
{												
	NSSavePanel *panel = [NSSavePanel savePanel];	// Puts up a save panel to get
	BOOL result;									// a final name from the user.
												// If the user cancels, returns
    switch (encoding) 							// NO. If encoding is non-NULL,
		{										// puts up encoding accessory.
        case RichTextStringEncoding:
            [panel setRequiredFileType:@"rtf"];
            [panel setTitle:NSLocalizedString(@"Save RTF", 
					@"Title of save and alert panels when saving RTF")];
            encodingForSaving = NULL;
            break;
        case RichTextWithGraphicsStringEncoding:
            [panel setRequiredFileType:@"rtfd"];
            [panel setTitle:NSLocalizedString(@"Save RTFD",
					@"Title of save and alert panels when saving RTFD")];
            encodingForSaving = NULL;
            break;
        default:
            [panel setTitle:NSLocalizedString(@"Save Plain Text", 
					@"Title of save and alert panels when saving plain text")];
            if (encodingForSaving) 
				{
                unsigned cnt;

//				[panel setAccessoryView:[[self class] encodingAccessory: 
//						*encodingForSaving includeDefaultEntry:NO]];

//				for (cnt = 0; cnt < [encodingPopupButton numberOfItems]; cnt++) 
					{
//					int encoding = [[encodingPopupButton itemAtIndex:cnt] tag];

//					if ((encoding != UnknownStringEncoding) && ![[textStorage 
//							string] canBeConvertedToEncoding:encoding]) 
//                      [[encodingPopupButton itemAtIndex:cnt] setEnabled:NO];
				}	}
            break;
    }

    if (potentialSaveDirectory) 
		[Document setLastOpenSavePanelDirectory:potentialSaveDirectory];

	if (oldName)
		{
		NSString *d = [oldName stringByDeletingLastPathComponent];
		NSString *f = [oldName lastPathComponent];

		result = [panel runModalForDirectory:d file:f];
		}
	else
		{
		NSString *d = [Document openSavePanelDirectory];

		result = [panel runModalForDirectory:d file:@""];
		}

	if (result) 
		{
        *newName = [panel filename];

		if (potentialSaveDirectory) 
	    	[self setPotentialSaveDirectory:nil];
        
//		if (encodingForSaving) 
//			*encodingForSaving = [[encodingPopupButton selectedItem] tag];
		} 

	return result;
}

- (BOOL) windowShouldClose:(id)sender 	{ return [self canCloseDocument]; }

- (void) textDidChange:(NSNotification *)textObject 
{													// Text view delegation
    if (!isDocumentEdited) 							// messages
        [self setDocumentEdited:YES];
}

- (void) orderFrontFindPanel:(id)sender 			// Find submenu commands
{
	[[TextFinder sharedInstance] orderFrontFindPanel:sender];
}

- (void) findNext:(id)sender	  
{ 
	[[TextFinder sharedInstance] findNext:sender]; 
}

- (void) findPrevious:(id)sender 
{
	[[TextFinder sharedInstance] findPrevious:sender];
}

- (void) enterSelection:(id)sender 
{
	NSRange range = [[self firstTextView] selectedRange];

    if (range.length)
		{
//		NSString *s = [[textStorage string] substringWithRange:range];
		NSString *s = [[[self firstTextView] string] substringWithRange:range];

		[[TextFinder sharedInstance] setFindString:s];
		}
	else
        NSBeep();
}

- (void) jumpToSelection:(id)sender 
{
	NSTextView *textView = [self firstTextView];

	[textView scrollRangeToVisible:[textView selectedRange]];
}
								// Returns YES if the document can be closed. 
- (BOOL) canCloseDocument 		// If the document is edited, gives the user a
{								// chance to save. Returns NO if user cancels.
    if (isDocumentEdited) 
		{
        int result;

		[[self window] makeKeyAndOrderFront:nil];

		result= NSRunAlertPanel( NSLocalizedString(@"Close", @"Title of alert panel which comes when the user tries to quit or close a window containing an unsaved document."), NSLocalizedString(@"Document has been edited. Save?", @"Question asked of user when he/she tries to close a window containing an unsaved document."), NSLocalizedString(@"Save", @"Button choice which allows the user to save the document."), NSLocalizedString(@"Don't Save", @"Button choice which allows the user to abort the save of a document which is being closed."), NSLocalizedString(@"Cancel", @"Button choice allowing user to cancel."));

        if (result == NSAlertDefaultReturn) 
			{														// Save
            if (![self saveDocument:NO]) 
				return NO;								
			} 
		else 
			if (result == NSAlertOtherReturn) 
            	return NO;											// Cancel
		}
							// Don't save case falls through to the YES return
	return YES;
}

- (void) setRichText:(BOOL)flag 
{
	NSTextView *view = [self firstTextView];
	NSMutableDictionary *textAttributes;
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

//	textAttributes = [[NSMutableDictionary alloc] initWithCapacity:2];
    isRichText = flag;
#if 0  // FIX ME need RTF support
    if (isRichText) 
		{
		[textAttributes setObject:[Preferences objectForKey:RichTextFont] 
						forKey:NSFontAttributeName];
        [textAttributes setObject:[NSParagraphStyle defaultParagraphStyle] 
						forKey:NSParagraphStyleAttributeName];

					// Make sure we aren't watching for the DidProcessEditing 
					// notification since we don't adjust tab stops in richtext
        [nc removeObserver:self 
			name:NSTextStorageDidProcessEditingNotification 
			object:[self textStorage]];
		} 
	else 
		{
        [textAttributes setObject:[Preferences objectForKey:PlainTextFont] 
						forKey:NSFontAttributeName];
        [textAttributes setObject:[NSParagraphStyle defaultParagraphStyle] 
						forKey:NSParagraphStyleAttributeName];
        [self removeAttachments];
        
						// Register for DidProcessEditing to fix the tabstops.
        [nc addObserver:self 
			selector:@selector(textStorageDidProcessEditing:) 
			name:NSTextStorageDidProcessEditingNotification 
			object:[self textStorage]];
		}
    
    [view setRichText:isRichText];
    [view setUsesRuler:isRichText];			// If NO, this correctly gets rid 
											// of the ruler if it was up
    [view setImportsGraphics:isRichText];

    if ([textStorage length]) 
        [textStorage setAttributes:textAttributes 
					 range: NSMakeRange(0, [textStorage length])];

    [view setTypingAttributes:textAttributes];
    [textAttributes release];
#endif
}
															// User commands...
- (void) toggleRich:(id)sender
{
    if (isRichText && ([textStorage length] > 0))
		{
		NSString *title = NSLocalizedString(@"Make Plain Text",nil);
		NSString *m = NSLocalizedString(@"Convert document to plain text?",0);
		NSString *d = NSLocalizedString(@"OK", nil);
		NSString *cancel = NSLocalizedString(@"OK", nil);

        if (NSRunAlertPanel(title, m, d, cancel, nil) != NSAlertDefaultReturn)
			return;
		}
    [self setRichText:!isRichText];
    [self setDocumentEdited:YES];
    [self setDocumentName:nil];
}

- (void) printDocumentUsingPrintPanel:(BOOL)uiFlag 
{
	NSPrintOperation *op;

    op = [NSPrintOperation printOperationWithView:[scrollView documentView] 
						   printInfo:printInfo];
    [op setShowsPrintPanel:uiFlag];
    [op runOperation];
}

- (void) printDocument:(id)sender 
{
    [self printDocumentUsingPrintPanel:YES];
}

- (void) togglePageBreaks:(id)sender 
{
    [self setHasMultiplePages:![self hasMultiplePages]];
}

- (void) revert:(id)sender 
{
    if (_documentName) 
		{
        NSString *fileName = [_documentName lastPathComponent];
        int choice = NSRunAlertPanel(NSLocalizedString(@"Revert", nil), 
					NSLocalizedString(@"Revert to saved version of %@?", nil), 
					NSLocalizedString(@"OK", nil), 
					NSLocalizedString(@"Cancel", nil), nil, fileName);

        if (choice == NSAlertDefaultReturn) 
			{
            if(![self loadFromPath:_documentName encoding:encodingIfPlainText])
				{
                NSRunAlertPanel(NSLocalizedString(@"Couldn't Revert",nil), 
				  NSLocalizedString(@"Couldn't revert to saved version of %@.", 
				  nil),NSLocalizedString(@"OK", nil), nil, nil, _documentName);
				} 
			else 
                [self setDocumentEdited:NO];
		}	}
}

@end
