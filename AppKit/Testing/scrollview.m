/*
   scrollview.m

   Scroll View tests

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <AppKit/AppKit.h>
#include <CoreGraphics/Private/PSOperators.h>


@interface TestView : NSView
@end

@implementation TestView

- (void) drawRect:(NSRect)rect
{
	NSFont *f;
	float width, height;
	NSColor *c = [NSColor greenColor];
	NSColor *blue = [NSColor blueColor];
	NSColor *y = [NSColor yellowColor];
	NSColor *mg = [NSColor magentaColor];
	NSColor *orange = [NSColor orangeColor];

	DBLog(@"Painting TestView %f %f %f %f\n", bounds.origin.x,
			bounds.origin.y, bounds.size.width, bounds.size.height);
	
	[orange set];
	NSRectFill([self bounds]);
	NSDrawGroove(NSMakeRect (10, 10, 100, 200), NSMakeRect (10, 10, 100, 200));

	[blue set];

	f = [NSFont boldSystemFontOfSize: 24];						// Text
	[f set];
	PSmoveto(15, 20);
	PSshow("Bold system font.");
	
	f = [NSFont systemFontOfSize: 24];
	[f set];
	PSmoveto(15, 50);
	PSshow("System font.");
	
	f = [NSFont fontWithName:@"Courier" size:12];
	[f set];
	PSmoveto(15, 100);
	PSshow("User fixed pitch font.");
	
	f = [NSFont userFontOfSize: 24];
	[f set];
	PSmoveto(15, 150);
	PSshow("User font.");

	[blue set];											// Absolute Lines
	PSnewpath();
	PSmoveto(400, 400);
	PSlineto(420, 400);
	PSlineto(440, 380);
	PSlineto(440, 360);
	PSlineto(420, 340);
	PSlineto(400, 340);
	PSlineto(380, 360);
	PSlineto(380, 380);
	PSclosepath();
	PSfill();

	[y set];											// Relative Lines
	PSnewpath();
	PSmoveto(400, 200);
	PSrlineto(20, 0);
	PSrlineto(20, -20);
	PSrlineto(0, -20);
	PSrlineto(-20, -20);
	PSrlineto(-20, 0);
	PSrlineto(-20, 20);
	PSrlineto(0, 20);
	PSclosepath();
	PSstroke();
}

- (void) mouseDown:(NSEvent *)event
{
	NSPoint location = [event locationInWindow];
	NSPoint p = [self convertPoint:location fromView:nil];
	NSClipView *clipView = (NSClipView *)[self superview];
	NSRect rect;

	NSLog (@"mouse down at (%2.2f, %2.2f), window location (%2.2f, %2.2f)",
			p.x, p.y, location.x, location.y);

	rect = [clipView bounds];
	NSLog (@"clip view bounds = ((%f, %f) (%f, %f))",
			rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
	
	rect = [self bounds];
	NSLog (@"self bounds = ((%f, %f) (%f, %f))\n",
			rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
}

@end

@interface Controller : NSObject
{
	NSScrollView *scrollView;
	NSRect viewFrame;
	NSMatrix *matrix;
}

- (void) setScrollView:(id)aView;

@end

@implementation Controller

- (void) setButtonTitles
{
	int i, j, index = 0;
	int numRows = [matrix numberOfRows];
	int numCols = [matrix numberOfColumns];
	id cell;

  for (i = 0; i < numRows; i++)
    for (j = 0; j < numCols; j++) {
      cell = [matrix cellAtRow:i column:j];
      [cell setTag:index];
      [cell setTitle:[NSString stringWithFormat:@"button %d, %d (%d)", i, j, index]];
      [cell setTarget:self];
      [cell setAction:@selector(handleCellAction:)];
      index++;
    }
}

- (void) handleCellAction:sender
{
	NSLog (@"handleCellAction: sender = %@", [[sender selectedCell] title]);
}

- (void) addRow:sender
{
	[matrix addRow];
	[self setButtonTitles];
	[matrix sizeToCells];
	[matrix setNeedsDisplay:YES];
}

- (void) addColumn:sender
{
	[matrix addColumn];
	[self setButtonTitles];
	[matrix sizeToCells];
	[matrix setNeedsDisplay:YES];
}

- (void) removeRow:sender
{
	if ([matrix selectedRow] >= 0) 
		{
		[matrix setNeedsDisplay:YES];
		[matrix removeRow:[matrix selectedRow]];
		[matrix sizeToCells];
		}
}

- (void) removeColumn:sender
{
	if ([matrix selectedColumn] >= 0) 
		{
		[matrix removeColumn:[matrix selectedColumn]];
		[matrix setNeedsDisplay:YES];
		[matrix sizeToCells];
		}
}

- (void) setMatrixMode:sender
{
	NSLog (@"setMatrixMode: %d", [[sender selectedCell] tag]);
	[matrix setMode:[[sender selectedCell] tag]];
}

- (void) initScrollView2
{
	NSWindow *window = [[NSWindow alloc] init];
	NSScrollView *sv2;
	NSMatrix *selectionMatrix;
	NSButtonCell *buttonCell;
	NSButton *addRowButton, *removeRowButton, *addColButton, *removeColButton;
	NSRect matrixRect = NSZeroRect;
	NSRect scrollViewRect = {{20, 115}, {350, 235}};
	NSRect winRect = {{500, 200}, {400, 450}};
	NSRect selectionMatrixRect = {{30, 15}, {85, 95}};
	NSRect addRowRect = {{160, 70}, {95, 24}};
	NSRect removeRowRect = {{160, 32}, {95, 24}};
	NSRect addColRect = {{272, 70}, {95, 24}};
	NSRect removeColRect = {{272, 32}, {95, 24}};

	buttonCell = [[NSButtonCell new] autorelease];
	[buttonCell setButtonType:NSPushOnPushOffButton];
	matrix = [[[NSMatrix alloc] initWithFrame:matrixRect	// configure matrix
								mode:NSRadioModeMatrix
								prototype:buttonCell
								numberOfRows:0
								numberOfColumns:0]
								autorelease];
	[matrix retain];

	sv2 = [[NSScrollView alloc] initWithFrame:scrollViewRect];
	[sv2 setHasHorizontalScroller:YES];
	[sv2 setHasVerticalScroller:YES];
	[sv2 setDocumentView:matrix];
	[[window contentView] addSubview:sv2];
	
	/* Setup the matrix for different selection types */
	buttonCell = [[NSButtonCell new] autorelease];
	[buttonCell setButtonType:NSRadioButton];
	[buttonCell setBordered:NO];
	[buttonCell setImagePosition:NSImageLeft];			// for NS compatibility
	
	selectionMatrix = [[[NSMatrix alloc] initWithFrame:selectionMatrixRect
										mode:NSRadioModeMatrix
										prototype:buttonCell
										numberOfRows:4
										numberOfColumns:1]
										autorelease];
	[selectionMatrix setTarget:self];
	[selectionMatrix setAutosizesCells:YES];			// for NS compatibility
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
	
	addRowButton = [[NSButton alloc] initWithFrame:addRowRect];
	[addRowButton setTitle:@"Add row"];
	[addRowButton setTarget:self];
	[addRowButton setAction:@selector(addRow:)];
	[[window contentView] addSubview:addRowButton];
	
	removeRowButton = [[NSButton alloc] initWithFrame:removeRowRect];
	[removeRowButton setTitle:@"Remove row"];
	[removeRowButton setTarget:self];
	[removeRowButton setAction:@selector(removeRow:)];
	[[window contentView] addSubview:removeRowButton];
	
	addColButton = [[NSButton alloc] initWithFrame:addColRect];
	[addColButton setTitle:@"Add column"];
	[addColButton setTarget:self];
	[addColButton setAction:@selector(addColumn:)];
	[[window contentView] addSubview:addColButton];
	
	removeColButton = [[NSButton alloc] initWithFrame:removeColRect];
	[removeColButton setTitle:@"Remove column"];
	[removeColButton setTarget:self];
	[removeColButton setAction:@selector(removeColumn:)];
	[[window contentView] addSubview:removeColButton];
	
	[window setFrame:winRect display:NO];	// FIX ME fb fails to show 2nd window if YES
	[window orderFront:nil];
}

- (void) showView:(id)sender
{
	NSWindow *w0;
	NSRect wf0 = {{300, 100}, {500, 500}};

	w0 = [[NSWindow alloc] init];
	[w0 setTitle:@"Graphics Testing"];
	
	[w0 setContentView: [[TestView alloc] init]];
	[w0 setFrame:wf0 display:NO];
	[w0 display];
	[w0 orderFront:nil];
}

- (void) setScrollView:(id)aView
{
	ASSIGN(scrollView, aView);
	viewFrame = [[scrollView documentView] frame];
}

- (void) setZoomFactor:(id)sender
{
	int tag = [[sender selectedCell] tag];
	id docView = [scrollView documentView];
	float scale;

	switch (tag) 
		{
		default:
		case 1: scale = 1; break;
		case 2: scale = 1.5; break;
		case 3: scale = 2; break;
		case 4: scale = 4; break;
		}
	
	[docView setFrameSize:NSMakeSize (viewFrame.size.width * scale, 
						viewFrame.size.height * scale)];
	[docView setBoundsSize:viewFrame.size];
	[scrollView setNeedsDisplay:YES];
}

- (void) initScrollView
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	NSWindow *window = [[NSWindow alloc] init];
	NSButtonCell *buttonCell;
	NSButton *button;
	NSMatrix *zoomMatrix;
	NSRect scrollViewRect = {{10, 10}, {250, 300}};
	NSRect zoomMatrixRect = {{270, 10}, {120, 80}};
	NSRect winRect = {{100, 100}, {380, 350}};
	NSRect f = {{0, 0}, {500, 700}};
	TestView *view = [[[TestView alloc] initWithFrame:f] autorelease];

	scrollView = [[NSScrollView alloc] initWithFrame:scrollViewRect];
	[scrollView setHasHorizontalScroller:YES];
	[scrollView setHasVerticalScroller:YES];
	[scrollView setDocumentView:view];
	[[window contentView] addSubview:scrollView];
	
	[self setScrollView:scrollView];
	
	buttonCell = [[NSButtonCell new] autorelease];
	[buttonCell setButtonType:NSRadioButton];
	[buttonCell setBordered:NO];
	
	zoomMatrix = [[[NSMatrix alloc] initWithFrame:zoomMatrixRect
									mode:NSRadioModeMatrix
									prototype:buttonCell
									numberOfRows:4
									numberOfColumns:1]
									autorelease];
	[zoomMatrix setTarget:self];
	[zoomMatrix setAction:@selector(setZoomFactor:)];
	
	buttonCell = [zoomMatrix cellAtRow:0 column:0];
	[buttonCell setTitle:@"100%"];
	[buttonCell setTag:1];
	
	buttonCell = [zoomMatrix cellAtRow:1 column:0];
	[buttonCell setTitle:@"150%"];
	[buttonCell setTag:2];
	
	buttonCell = [zoomMatrix cellAtRow:2 column:0];
	[buttonCell setTitle:@"200%"];
	[buttonCell setTag:3];
	
	buttonCell = [zoomMatrix cellAtRow:3 column:0];
	[buttonCell setTitle:@"400%"];
	[buttonCell setTag:4];
	
	button = [[NSButton alloc] initWithFrame:(NSRect){{280,300},{80,20}}];
	[button setTitle: @"Show View"];
	[button setTarget:self];
	[button setAction:@selector(showView:)];
	[[window contentView] addSubview:button];
	
	[[window contentView] addSubview:zoomMatrix];
	
	[window setFrame:winRect display:YES];
	[window makeKeyAndOrderFront:nil];
	[window orderFront:nil];
}

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[self initScrollView2];
	[self initScrollView];
}

- (id) init
{
	[[NSApplication sharedApplication] setDelegate: self];	
}

@end

int
main(int argc, char **argv, char** env)
{
    return NSApplicationMain(argc, argv);
}
