/*
	TextFinder.m

	Find and replace functionality with a minimal panel...

	Copyright (c) 1995-1996, NeXT Software, Inc. All rights reserved.
	Author: Ali Ozer

	You may freely copy, distribute and reuse the code in this example.
	NeXT disclaims any warranty of any kind, expressed or implied, as 
	to its fitness for any particular use.

   	In addition to including this class and FindPanel.nib in your app,
	you probably need to hook up the following action methods in your 
	document object (or whatever object is first responder) to call the 
	appropriate methods in [TextFinder sharedInstance]:

	  orderFrontFindPanel:
	  findNext:
	  findPrevious:
	  enterSelection: (calls setFindString:)
*/

#import <AppKit/AppKit.h>
#import "TextFinder.h"

#define ReplaceAllScopeEntireFile	42
#define ReplaceAllScopeSelection	43

#define OBSERVE_(notif_name) \
		[n addObserver:self \
		   selector:@selector(application##notif_name:) \
		   name:NSApplication##notif_name##Notification \
		   object:NSApp]

// Class variables
static TextFinder *__sharedTextFinder = nil;


@implementation TextFinder

+ (void) initialize						{ __sharedTextFinder = [self new]; }
+ (id) sharedInstance 					{ return __sharedTextFinder; }

- (id) init 
{
    if ((self = [super init]))
		{
		NSNotificationCenter *n = [NSNotificationCenter defaultCenter];

		OBSERVE_(DidBecomeActive);
		OBSERVE_(WillResignActive);
		[self setFindString:@""];
		[self loadFindStringFromPasteboard];
		}

    return self;
}

- (void) loadUI 
{
    if (!_findTextField) 
		{
		if (![NSBundle loadNibNamed:@"FindPanel.mib" owner:self])
			{
            NSLog(@"Failed to load FindPanel.mib");
            NSBeep();
			}

		if (self == __sharedTextFinder)
			[[_findTextField window] setFrameAutosaveName:@"Find"];
		}

    [_findTextField setStringValue:[self findString]];
}

- (void) dealloc 
{
    if (self != __sharedTextFinder)
		{
        [_findString release];
        [super dealloc];
		}
}

- (void) applicationDidBecomeActive:(NSNotification *)notification 
{
	[self loadFindStringFromPasteboard];
}

- (void) applicationWillResignActive:(NSNotification *)notification 
{
	[self loadFindStringToPasteboard];
}

- (void) loadFindStringFromPasteboard 
{
	NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSFindPboard];

    if ([[pb types] containsObject:NSStringPboardType]) 
		{
        NSString *string = [pb stringForType:NSStringPboardType];

        if (string && [string length]) 
			{
            [self setFindString:string];
            findStringChangedSinceLastPasteboardUpdate = NO;
		}	}
}

- (void) loadFindStringToPasteboard 
{
    if (findStringChangedSinceLastPasteboardUpdate && [_findString length]) 
		{
		NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSFindPboard];

        [pb declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:0];
        [pb setString:[self findString] forType:NSStringPboardType];
		findStringChangedSinceLastPasteboardUpdate = NO;
		}
}

- (NSString *) findString					{ return _findString; }

- (void) setFindString:(NSString *)string 
{
    if ([string isEqualToString:_findString]) 
		return;
    [_findString autorelease];
    _findString = [string copy];
    if (_findTextField) 
		{
        [_findTextField setStringValue:_findString];
        [_findTextField selectText:nil];
		}
    findStringChangedSinceLastPasteboardUpdate = YES;
}

- (NSTextView *) textObjectToSearchIn 
{
	id obj = [[NSApp mainWindow] firstResponder];

    return ((id)obj && [obj isKindOfClass:[NSTextView class]]) ? obj : nil;
}

- (NSPanel *) findPanel 
{
	if (!_findTextField) 
		[self loadUI];

    return (NSPanel *)[_findTextField window];
}

- (BOOL) find:(BOOL)direction						// Primitive for finding; 
{													// this ends up setting the 
	NSTextView *text = [self textObjectToSearchIn];		// status field (and
													// beeping if necessary)...
    lastFindWasSuccessful = NO;
    if (text) 
		{
        NSString *textContents = [text string];
        unsigned textLength;

        if (textContents && (textLength = [textContents length])) 
			{
            NSRange range;
            unsigned options = 0;

			if (direction == Backward) 
				options |= NSBackwardsSearch;
			if ([_ignoreCaseButton state])
				options |= NSCaseInsensitiveSearch;
            range = [textContents findString:[self findString] 
								  selectedRange:[text selectedRange] 
								  options:options 
								  wrap:YES];
            if (range.length) 
				{
                [text setSelectedRange:range];
                [text scrollRangeToVisible:range];
                lastFindWasSuccessful = YES;
		}	}	}

    if (!lastFindWasSuccessful) 
		{
        NSBeep();
		[_statusField setStringValue: NSLocalizedStringFromTable(@"Not found",
	  			@"FindPanel",
				@"Status displayed in find panel when string is not found.")];
		}
	else 
        [_statusField setStringValue:@""];

	return lastFindWasSuccessful;
}

- (void) orderFrontFindPanel:(id)sender 
{
	NSPanel *panel = [self findPanel];

    [_findTextField selectText:nil];
    [panel makeKeyAndOrderFront:nil];
}

- (void) findNext:(id)sender
{
    if (_findTextField) 						// findTextField should be set
		[self setFindString:[_findTextField stringValue]];

    (void)[self find:Forward];
}

- (void) findPrevious:(id)sender 
{
    if (_findTextField) 						// findTextField should be set
		[self setFindString:[_findTextField stringValue]];

    (void)[self find:Backward];
}

- (void) replace:(id)sender 
{
	NSTextView *text = [self textObjectToSearchIn];

    if (!text) 
        NSBeep();
	else 
		{
//		[[text textStorage] replaceCharactersInRange:[text selectedRange] 
        [[text string] replaceCharactersInRange:[text selectedRange] 
					   withString:[_replaceTextField stringValue]];
		[text didChangeText];
		}
	[_statusField setStringValue:@""];
}

- (void) replaceAndFind:(id)sender 
{
    [self replace:sender];
    [self findNext:sender];
}

- (void) replaceAll:(id)sender 
{
	NSTextView *text = [self textObjectToSearchIn];

    if (!text) 
        NSBeep();
	else 
		{	
        NSTextStorage *textStorage = [text textStorage];
        NSString *textContents = [text string];
        NSString *replaceString = [_replaceTextField stringValue];
        BOOL entireFile = replaceAllScopeMatrix ? ([replaceAllScopeMatrix selectedTag] == ReplaceAllScopeEntireFile) : YES;
        NSRange replaceRange = entireFile ? NSMakeRange(0, [textStorage length]) : [text selectedRange];
        unsigned options = NSBackwardsSearch | ([_ignoreCaseButton state] ? NSCaseInsensitiveSearch : 0);
        unsigned replaced = 0;

        if (_findTextField) 
			[self setFindString:[_findTextField stringValue]];

        while (1) 
			{
            NSRange foundRange = [textContents rangeOfString:[self findString] 
											   options:options 
											   range:replaceRange];
            if (foundRange.length == 0) 
				break;
            if ([text shouldChangeTextInRange:foundRange 
					  replacementString:replaceString]) 
				{
				if (replaced == 0) 
					[textStorage beginEditing];
				replaced++;
				[textStorage replaceCharactersInRange:foundRange 
							 withString:replaceString];
				replaceRange.length = foundRange.location - replaceRange.location;
			}	}

        if (replaced > 0) 
			{							// There was at least one replacement
			[textStorage endEditing];	// - need this to bracket beginEditing
			[text didChangeText];		// - need one of these to terminate the 
										// shouldChange... methods we sent
            [_statusField setStringValue:[NSString localizedStringWithFormat: NSLocalizedStringFromTable(@"%d replaced", @"FindPanel", @"Status displayed in find panel when indicated number of matches are replaced."), replaced]];
			} 
		else
			{							// No replacements were done...
            NSBeep();
            [_statusField setStringValue:NSLocalizedStringFromTable(@"Not found", @"FindPanel", @"Status displayed in find panel when the find string is not found.")];
			}
		}
}

@end


@implementation NSString (NSStringTextFinding)

- (NSRange) findString:(NSString *)string 
			selectedRange:(NSRange)selectedRange 
			options:(unsigned)options 
			wrap:(BOOL)wrap 
{
	BOOL forwards = (options & NSBackwardsSearch) == 0;
	unsigned length = [self length];
	NSRange searchRange, range;

    if (forwards) 
		{
		searchRange.location = NSMaxRange(selectedRange);
		searchRange.length = length - searchRange.location;
		range = [self rangeOfString:string options:options range:searchRange];
        if ((range.length == 0) && wrap) 
			{										// If not found look at the 
			searchRange.location = 0;				// first part of the string
            searchRange.length = selectedRange.location;
            range = [self rangeOfString:string 
						  options:options 
						  range:searchRange];
		}	}
	else 
		{
		searchRange.location = 0;
		searchRange.length = selectedRange.location;
        range = [self rangeOfString:string options:options range:searchRange];
        if ((range.length == 0) && wrap) 
			{
            searchRange.location = NSMaxRange(selectedRange);
            searchRange.length = length - searchRange.location;
            range = [self rangeOfString:string 
						  options:options 
						  range:searchRange];
		}	}

	return range;
}        

@end
