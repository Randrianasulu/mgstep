/*
   matrix.m

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#import <AppKit/AppKit.h>



@interface Controller : NSObject
{
	NSMatrix *matrix;
}

@end

@implementation Controller

- (id) init
{
	[[NSApplication sharedApplication] setDelegate: self];	
}

- (void) setMatrixMode:sender
{
	[matrix setMode:[[sender selectedCell] tag]];
}

- (void) setSelectionByRect:sender
{
	[matrix setSelectionByRect:[sender state]];
}

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSWindow *window = [[NSWindow alloc] init];
	NSRect winRect = {{100, 100}, {600, 600}};
	NSRect matrixRect = {{175, 5}, {460, 550}};
	NSRect selectionMatrixRect = {{12, 36}, {120, 80}};
	NSMatrix* selectionMatrix;
	NSButtonCell* buttonCell;
	NSButton* selectionByRectSwitch;
	id handler = self;

	buttonCell = [[NSButtonCell new] autorelease];
	[buttonCell setButtonType:NSPushOnPushOffButton];

	matrix = [[[NSMatrix alloc] initWithFrame:matrixRect
								mode:NSRadioModeMatrix
								prototype:buttonCell
								numberOfRows:30
								numberOfColumns:5]
								autorelease];
	[[window contentView] addSubview:matrix];
//  [matrix _test];

	[buttonCell setButtonType:NSRadioButton];
	[buttonCell setBordered:NO];

  	selectionMatrix = [[NSMatrix alloc] initWithFrame:selectionMatrixRect
										mode:NSRadioModeMatrix
										prototype:buttonCell
										numberOfRows:4
										numberOfColumns:1];
	[selectionMatrix setTarget:handler];
	[selectionMatrix setAction:@selector(setMatrixMode:)];
	
	buttonCell = [selectionMatrix cellAtRow:0 column:0];
	[buttonCell setTitle:@"Radio"];
	[buttonCell setTag:NSRadioModeMatrix];
	
	buttonCell = [selectionMatrix cellAtRow:1 column:0];
	[buttonCell setTitle:@"Highlight"];
	[buttonCell setTag:NSHighlightModeMatrix];
	
	buttonCell = [selectionMatrix cellAtRow:2 column:0];
	[buttonCell setTitle:@"List"];
	[buttonCell setTag:NSListModeMatrix];
	
	buttonCell = [selectionMatrix cellAtRow:3 column:0];
	[buttonCell setTitle:@"Track"];
	[buttonCell setTag:NSTrackModeMatrix];
	
	[[window contentView] addSubview:selectionMatrix];

	selectionByRectSwitch = [NSButton alloc];
	[selectionByRectSwitch initWithFrame:(NSRect){{12,12},{150,20}}];
	[selectionByRectSwitch autorelease];
	[selectionByRectSwitch setButtonType:NSSwitchButton];
	[selectionByRectSwitch setBordered:NO];
	[selectionByRectSwitch setTitle:@"Selection by rect"];
	[selectionByRectSwitch setState:1];
	[selectionByRectSwitch setTarget:handler];
	[selectionByRectSwitch setAction:@selector(setSelectionByRect:)];
	[[window contentView] addSubview:selectionByRectSwitch];
	
	[window setTitle:@"NSMatrix"];
	[window setFrame:winRect display:YES];
	[window orderFront:nil];
}

@end

int
main(int argc, char **argv, char** env)
{
    return NSApplicationMain(argc, argv);
}
