/*
   NSSavePanel.m

   Standard Save / Open Panels

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Daniel Bðhringer <boehring@biomed.ruhr-uni-bochum.de>
   Date: August 1998
   mGSTEP: Felipe A. Rodriguez <far@iillumenos.com>

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <AppKit/AppKit.h>


// Class variables
static NSSavePanel *__savePanel = nil;
static NSOpenPanel *__openPanel = nil;


@implementation NSSavePanel

+ (NSSavePanel *) savePanel
{	
	if ((!__savePanel) && ![GMModel loadMibFile:@"SavePanel" owner:NSApp]) 
		[NSException raise: NSInternalInconsistencyException 
					 format: @"Cannot open save panel mib model file."];

    return __savePanel;
}

+ (id) alloc
{
	return __savePanel ? __savePanel
					  : (__savePanel = (NSSavePanel *)NSAllocateObject(self));
}

- (id) init
{
	if ((self = [super init]))
		treatsFilePackagesAsDirectories = YES;

	return self;
}

- (BOOL) performDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSDragPboard];
	NSString *Path = [pb stringForType:NSFilenamesPboardType];

	NSLog (@"performDragOperation Path: '%@'\n", Path);

	if (![Path isEqualToString:[[browser path] lastPathComponent]])
		{
		if (![browser setPath:Path])
			{
			NSString *a = [[NSProcessInfo processInfo] processName];

			NSRunAlertPanel(a,@"Invalid path: '%@'",@"Continue",nil,nil, Path);
			
			return NO;
			}
		else
			{
			[self endEditingFor:nil];
			[form setStringValue:[Path lastPathComponent]];
			[form selectText:nil];
		}	}

	return YES;
}

- (NSDragOperation) draggingUpdated:(id <NSDraggingInfo>)sender
{
	return NSDragOperationGeneric;
}

- (BOOL) prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	NSLog(@"NSSavePanel prepareForDragOperation\n");
	return YES;
}

- (NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender
{
	NSLog(@"NSSavePanel draggingEntered\n");
	return NSDragOperationGeneric;
}

- (void) setAccessoryView:(NSView *)view
{
	if (view != _accessoryView)
		{
		[_accessoryView removeFromSuperview];		// released if not retained
		[[self contentView] addSubview: (_accessoryView = view)];
		}
}

- (NSView *) accessoryView				{ return _accessoryView; }
- (void) validateVisibleColumns			{}
- (void) selectText:(id)sender			{ [form selectText:sender]; }
- (void) setTitle:(NSString *)title		{ [titleField setStringValue:title]; }
- (NSString *) title					{ return [titleField stringValue]; }
- (NSString *) prompt					{ return [[form cell] title]; }

- (void) setPrompt:(NSString *)prompt
{	// does currently not work since i went with NSTextField instead of NSForm
	[[form cell] setTitle:prompt];
}

- (NSString *) requiredFileType					// Set Directory and File Type
{
	if(!requiredTypes || ![requiredTypes count])
		return @"";

	return [requiredTypes objectAtIndex:0];
}

- (void) setDirectory:(NSString *)path
{
	NSString *standardizedPath = [path stringByStandardizingPath];
	
	if(standardizedPath && [browser setPath:standardizedPath])
		ASSIGN(lastValidPath, path);
}

- (void) setRequiredFileType:(NSString *)type
{
	id rt = (type) ? [NSArray arrayWithObject: type] : nil;

	ASSIGN(requiredTypes, rt);
}

- (void) setTreatsFilePackagesAsDirectories:(BOOL)flag
{
	treatsFilePackagesAsDirectories = flag;
}

- (BOOL) treatsFilePackagesAsDirectories
{	
	return treatsFilePackagesAsDirectories;
}

- (int) runModalForDirectory:(NSString *)path 				// Run NSSavePanel
						file:(NSString *)name
{
	int	ret;
	static BOOL registered = NO;

	if (!registered)
		{
		registered = YES;
		[[self contentView] registerForDraggedTypes:nil];
		}

	[self setDirectory:path];
//	[browser setPath:[NSString stringWithFormat:@"%@/%@",
//						[self directory],name]];

///	[browser setPath:@"/"];
///	[browser loadColumnZero];
	[form setStringValue:name];
    [self selectText:self];	      // or should it be browser?

#if 0
    if([self class] == [NSOpenPanel class])
		[okButton setEnabled:([browser selectedCell]
								&& [(NSOpenPanel*)self canChooseDirectories])
								|| [[browser selectedCell] isLeaf]];
#endif

	[self display];
	[self makeKeyAndOrderFront:self];
    ret = [NSApp runModalForWindow:self];
    
#if 0
    // replace warning
    if ([self class] == [NSSavePanel class]
			&& [[browser selectedCell] isLeaf] && ret == NSOKButton)
		if (NSRunAlertPanel(@"Save", @"File %@ in %@ exists. Replace it?", 
							@"Cancel", nil,
							[form stringValue],
							[self directory]) == NSAlertAlternateReturn)
			return NSCancelButton;
#endif

    return ret;
}

- (int) runModal
{
	return [self runModalForDirectory:[self directory] file:@""];
}

- (NSString *) directory
{	
	NSString *path = [browser path];
	
	if([[browser selectedCell] isLeaf])		// remove file component of path
		path = [path stringByDeletingLastPathComponent];	

	return (![path length]) ? lastValidPath : path;
}

- (NSString *) filename
{	
	NSString *d = [self directory];
	NSString *r = [NSString stringWithFormat:@"%@/%@", d, [form stringValue]];
	NSString *rf = [self requiredFileType];
		
	if (![rf isEqualToString:@""])
		if (![r hasSuffix:[NSString stringWithFormat:@".%@",rf]])
			r = [NSString stringWithFormat:@"%@.%@", r, rf];

	return [r stringByExpandingTildeInPath];
}
														// Target / Action 
- (void) ok:(id)sender
{												// iterate through selection 
	NSString *f = [form stringValue];			// if a multiple selection

	if (![f isEqualToString: [[browser path] lastPathComponent]])
		{
		NSString *b = [f stringByDeletingLastPathComponent];

		if ([b length])
			{
			if (![browser setPath: b])
				{
				NSString *a = [[NSProcessInfo processInfo] processName];
	
				NSRunAlertPanel(a,@"Invalid path: '%@'",@"Continue",nil,nil,b);
				
				return;
				}
			[form setStringValue:[f lastPathComponent]];
		}	}

	if(_delegate)
		if([_delegate respondsToSelector:@selector(panel:isValidFilename:)]
				&& ![_delegate panel:sender isValidFilename:[self filename]])
			return;

	[NSApp stopModalWithCode:NSOKButton];
	[self orderOut:self];
}

- (void) cancel:(id)sender
{
	[NSApp stopModalWithCode:NSCancelButton];
	[self orderOut:self];
}

- (void) _setHome:(id)sender
{
	[self setDirectory: NSHomeDirectory()];
}

- (void) browser:(NSBrowser*)sender 						// browser delegate
		 createRowsForColumn:(int)column
		 inMatrix:(NSMatrix*)matrix
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *ptc = [sender pathToColumn: column];
	NSArray *files = [fm directoryContentsAtPath: ptc];
	int i, count = [files count];

    NSLog(@"createRowsForColumn");

	[matrix renewRows:count columns:1];				// create necessary cells
	[matrix sizeToCells];	

	if (count == 0)
		return;

    for (i = 0; i < count; ++i) 
		{
		id cell = [matrix cellAtRow: i column: 0];
		BOOL is_dir = NO;
		NSMutableString *s;

		[cell setStringValue: [files objectAtIndex: i]];

		s = [[[NSMutableString alloc] initWithString: ptc] autorelease];
		[s appendString: @"/"];
		[s appendString: [files objectAtIndex: i]];
		[fm fileExistsAtPath: s isDirectory: &is_dir];
		
		[cell setLeaf: (!(is_dir))];
		}
}

- (void) browser:(NSBrowser*)sender 
		 willDisplayCell:(id)cell
		 atRow:(int)row
		 column:(int)column
{
    NSLog(@"willDisplayCell");
}

- (BOOL) browser:(NSBrowser *)sender 
		 selectCellWithString:(NSString *)title
		 inColumn:(int)column
{
	NSString *p = [sender pathToColumn: column];
	NSMutableString *s = [[[NSMutableString alloc] initWithString:p] autorelease];

    NSLog(@"-browser:selectCellWithString {%@}", title);

	[form setStringValue:title];
	[form selectText:nil];
///	[form display];
    if (column > 0)
		[s appendString: @"/"];
    [s appendString:title];

	NSLog(@"-browser: source path: %@", s);
    return YES;
}

- (BOOL) fileManager:(NSFileManager*)fileManager
		 shouldProceedAfterError:(NSDictionary*)errorDictionary
{
    return YES;
}

- (void) encodeWithCoder:(NSCoder *)aCoder				// NSCoding protocol
{
	[aCoder encodeObject: _accessoryView];
	[aCoder encodeConditionalObject:_delegate];
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
	_accessoryView = [aDecoder decodeObject];
	_delegate = [aDecoder decodeObject];
	
	return self;
}

@end /* NSSavePanel */

/* ****************************************************************************

 		NSOpenPanel

** ***************************************************************************/

@implementation NSOpenPanel

+ (NSOpenPanel *) openPanel
{	
	if(!__openPanel)	
		{
		[NSKeyedUnarchiver decodeClassName:@"NSSavePanel" 
						   asClassName:@"NSOpenPanel"];

		if (![GMModel loadMibFile:@"SavePanel" owner:NSApp]) 
			[NSException raise:NSInternalInconsistencyException 
						 format:@"Unable to open SavePanel mib model file."];

		[__openPanel setTitle:@"Open"];

		[NSKeyedUnarchiver decodeClassName:@"NSSavePanel" 
						   asClassName:@"NSSavePanel"];
		}

    return __openPanel;
}

+ (id) alloc
{ 
	return __openPanel ? __openPanel
					  : (__openPanel = (NSOpenPanel *)NSAllocateObject(self));
}

- (id) init
{	
	self = [super init];
	[self setTitle:@"Open"];
	_op.canChooseFiles = YES;

  	return self;
}

- (void) setAllowsMultipleSelection:(BOOL)flag
{	
	_op.allowsMultipleSelect = flag;
	[browser setAllowsMultipleSelection:flag];
}

- (void) setCanChooseDirectories:(BOOL)flag	{ _op.canChooseDirectories = flag;}
- (void) setCanChooseFiles:(BOOL)flag		{ _op.canChooseFiles = flag; }
- (BOOL) allowsMultipleSelection 			{ return _op.allowsMultipleSelect;}
- (BOOL) canChooseDirectories				{ return _op.canChooseDirectories;}
- (BOOL) canChooseFiles						{ return _op.canChooseFiles; }

- (NSArray *) filenames
{
	if(_op.allowsMultipleSelect && [[browser selectedCells] count] > 1) 
		{	
		NSEnumerator *e = [[browser selectedCells] objectEnumerator];
		NSMutableArray *array = [NSMutableArray array];
		NSString *d = [self directory];
		id c;

		while((c = [e nextObject]))
		 	 [array addObject:[NSString stringWithFormat:@"%@/%@", 
										d, [c stringValue]]];
		return array;
		}

	return [NSArray arrayWithObject:[self filename]];
}

- (int) runModalForTypes:(NSArray *)fileTypes			// Run the NSOpenPanel
{
	return [self runModalForDirectory:[self directory] 
				 file: @"" 
				 types: fileTypes];
}

- (int) runModalForDirectory:(NSString *)path 
						file:(NSString *)name
						types:(NSArray *)fileTypes
{
	if(![fileTypes respondsToSelector:@selector(objectAtIndex:)])
		[NSException raise: NSInternalInconsistencyException 
					 format: @"not an array."];

    NSLog(@"runModalForDirectory:");
	ASSIGN(requiredTypes, fileTypes);

	return [self runModalForDirectory:path file:name];
}

- (void) encodeWithCoder:(NSCoder *)aCoder				// NSCoding protocol
{
	[super encodeWithCoder:aCoder];
	[aCoder encodeValueOfObjCType:@encode(unsigned int) at:&_op];
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
	[super initWithCoder:aDecoder];
	[aDecoder decodeValueOfObjCType:@encode(unsigned int) at:&_op];
	
	return self;
}

@end /* NSOpenPanel */
