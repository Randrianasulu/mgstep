/*
   combo.m
*/

#include <AppKit/AppKit.h>
#include <AppKit/NSTabView.h>
#include <AppKit/NSTabViewItem.h>
#include <CoreGraphics/Private/PSOperators.h>


@interface PSView : NSView
@end

@implementation PSView

- (void) drawRect:(NSRect)rect						
{
	int i;

	[[NSColor whiteColor] set];
	PSnewpath();
	PSmoveto(16,15);
	PScurveto(20, 15, 20, 31, 28, 31);
	PSrlineto(30,0);
	PSstroke ();
}

@end


@interface TabViewDelegate : NSObject

- (BOOL) tabView:(NSTabView *)tabView 
		 shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem;
- (void) tabView:(NSTabView *)tabView 
		 willSelectTabViewItem:(NSTabViewItem *)tabViewItem;
- (void) tabView:(NSTabView *)tabView 
		 didSelectTabViewItem:(NSTabViewItem *)tabViewItem;
- (void) tabViewDidChangeNumberOfTabViewItems:(NSTabView *)TabView;

@end

@implementation TabViewDelegate

- (BOOL) tabView:(NSTabView *)tabView 
		 shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	NSLog(@"shouldSelectTabViewItem: %@", [tabViewItem label]);
							// test to see if the delegate is doing its job.
	return ([[tabViewItem label] isEqual:@"Can't touch this"]) ? NO : YES;
}

- (void) tabView:(NSTabView *)tabView 
		 willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	NSLog(@"willSelectTabViewItem: %@", [tabViewItem label]);
}

- (void) tabView:(NSTabView *)tabView 
		 didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	NSLog(@"didSelectTabViewItem: %@", [tabViewItem label]);
}

- (void) tabViewDidChangeNumberOfTabViewItems:(NSTabView *)TabView
{
	NSLog(@"tabViewDidChangeNumberOfTabViewItems: %d", 
		  [TabView numberOfTabViewItems]);
}

@end

NSImageView *__v3;

@interface MyObject : NSObject
{
	NSLevelIndicator *_level;
}

- (void) setLevel:sender;

@end

@implementation MyObject

- (void) setLevel:(id)level
{
	_level = level;
}

- (void) action:sender
{
	NSLog (@"slider value = %f", [sender floatValue]);
	[_level setDoubleValue:[sender floatValue]/100];
}

- (void) action2:sender
{
	NSImage *image = [NSImage imageNamed: @"host.tiff"];

	[__v3 lockFocus];
	[[[__v3 window] backgroundColor] set];
	NSRectFill([__v3 bounds]);
	[image recache];
	[image dissolveToPoint:NSZeroPoint fraction:[sender floatValue]];
	[__v3 unlockFocus];
	[[__v3 window] flushWindow];
	NSLog (@"slider2 value = %f", [sender floatValue]);
}

@end


@interface View : NSView
@end

@implementation View

- (void) drawRect:(NSRect)rect
{
	[[NSColor redColor] set];
	NSRectFill(_bounds);
}

@end


@interface ColorView : NSView
{
	NSColor *the_color;
	NSCursor *the_cursor;
}

- (NSColor *) color;
- (void) setColor:(NSColor *)aColor;
- (void) setCursor:(NSCursor *)aCursor;
- (NSCursor *) cursor;

@end

@implementation ColorView

- (id) initWithFrame:(NSRect)rect
{
	[super initWithFrame: rect];
	
	the_color = [NSColor blackColor];
	the_cursor = [NSCursor IBeamCursor];
	
	return self;
}

- (void)setColor:(NSColor *)aColor			{ the_color = aColor; }
- (NSColor *)color							{ return the_color; }
- (void)setCursor:(NSCursor *)aCursor		{ the_cursor = aCursor; }
- (NSCursor *)cursor						{ return the_cursor; }

- (void)drawRect:(NSRect)rect
{
	[the_color set];
	NSRectFill([self bounds]);
}

- (void) mouseEntered:(NSEvent *)event		{ NSLog(@"Entered color view\n"); }

- (void) resetCursorRects
{
	NSLog(@"resetCursorRects: frame ((%f, %f) (%f, %f)), "
		  @"bounds ((%f, %f) (%f, %f))", 
		  NSMinX(_frame), NSMinY(_frame),
		  NSWidth(_frame), NSHeight(_frame),
		  NSMinX(_bounds), NSMinY(_bounds),
		  NSWidth(_bounds), NSHeight(_bounds));
	[self addCursorRect:_bounds cursor: the_cursor];
}

@end


@interface Controller : NSObject
{
	NSMatrix *matrix;
	NSBox *the_box;
}

- (void) cycleTitle;
- (void) cycleBorder;

@end

@implementation Controller

- (id) init
{
	[[NSApplication sharedApplication] setDelegate: self];	
}

- (void) cycleTitle
{
	NSTitlePosition pos = [the_box titlePosition];

	NSLog(@"Position at: %d\n", pos);
	if (pos == NSNoTitle) pos = NSAboveTop;
	else if (pos == NSAboveTop) pos = NSAtTop;
	else if (pos == NSAtTop) pos = NSBelowTop;
	else if (pos == NSBelowTop) pos = NSAboveBottom;
	else if (pos == NSAboveBottom) pos = NSAtBottom;
	else if (pos == NSAtBottom) pos = NSBelowBottom;
	else if (pos == NSBelowBottom) pos = NSNoTitle;
	
	NSLog(@"Setting to position: %d\n", pos);
	[the_box setTitlePosition: pos];
	[the_box display];
}

- (void) cycleBorder
{
	NSBorderType bt = [the_box borderType];

	if (bt == NSNoBorder) bt = NSLineBorder;
	else if (bt == NSLineBorder) bt = NSBezelBorder;
	else if (bt == NSBezelBorder) bt = NSGrooveBorder;
	else if (bt == NSGrooveBorder) bt = NSNoBorder;
	
	[the_box setBorderType: bt];
	[the_box display];
}

- (void) setMatrix:(NSMatrix*)anObject
{
	matrix = anObject;
}

- (void)setMatrixMode:sender
{
	[matrix setMode:[[sender selectedCell] tag]];
}

- (void)setSelectionByRect:sender
{
	[matrix setSelectionByRect:[sender state]];
}

- (void) scrollerAction:(id)sender
{
//	NSLog (@"scroller value = %f", [sender floatValue]);
}

- (void) doDoubleClick:(id)sender
{
	[[[sender superview] superview] flashScrollers];
}

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSWindow *window = [[NSWindow alloc] init];
	NSView *v = [window contentView];
	NSRect winRect = {{100, 150}, {600, 600}};
	NSRect scrollViewRect = {{20, 250}, {150, 230}};
	NSRect matrixRect = {{0, 0}, {100, 450}};
	NSBrowserCell *browserCell;
	NSScrollView *scrollView;
	NSSize cs, ms;
	NSRect mr;
	MyObject *target;
														// nsbrowsercell
	browserCell = [[NSBrowserCell new] autorelease];
	[browserCell setStringValue:@"aTitle"];				// for NS compatibility

	matrix = [[[NSMatrix alloc] initWithFrame:matrixRect
							  	mode:NSRadioModeMatrix	// or NSListModeMatrix
								prototype:browserCell
								numberOfRows:30
								numberOfColumns:1]
								autorelease];
//  [matrix _test];

	scrollView = [[NSScrollView alloc] initWithFrame:scrollViewRect];
	[scrollView setHasHorizontalScroller:NO];
	[scrollView setHasVerticalScroller:YES];

	cs = [scrollView contentSize];
	ms = [matrix cellSize];
	ms.width = cs.width - [matrix intercellSpacing].width;
	[matrix setCellSize: ms];
	[matrix sizeToCells];								// for NS compatibility

	[matrix setDoubleAction: @selector(doDoubleClick:)];
	[matrix setTarget: self];

	[scrollView setScrollerStyle:NSScrollerStyleOverlay];

	[scrollView setDocumentView:matrix];
	[v addSubview:scrollView];

	__v3 = [[NSImageView alloc] initWithFrame: NSMakeRect(40, 520, 48, 48)];					
	[__v3 setImage:[NSImage imageNamed: @"host.tiff"]];
	[v addSubview: __v3];

	{
	NSButton *b0, *b1;											// nsbox
	NSRect bf0 = {{161, 91}, {80, 20}};
	NSRect bf1 = {{161, 51}, {80, 20}};
	NSBox *aBox;
	NSRect boxf = {{10, 10}, {130, 130}};
	View *myView;

	aBox = [[NSBox alloc] initWithFrame: boxf];
	[aBox setTitle: @"Push the Button"];
	[aBox setTitlePosition: NSNoTitle];
	[v addSubview: aBox];
	
	the_box = aBox;
	
	myView = [[View alloc] initWithFrame: boxf];
	[aBox addSubview: myView];
	
	// Button to change the title position
	b0 = [[NSButton alloc] initWithFrame: bf0];
	[b0 setTarget: self];
	[b0 setAction: @selector(cycleTitle)];
	[b0 setTitle: @"Cycle Title"];
	[v addSubview: b0];
	[b0 setToolTip: @"Button that changes the title position"];
	
	// Button to change the border type
	b1 = [[NSButton alloc] initWithFrame: bf1];
	[b1 setTarget: self];
	[b1 setAction: @selector(cycleBorder)];
	[b1 setTitle: @"Cycle Border"];
	[v addSubview: b1];
	[b1 setToolTip: @"Button that cycles the border"];
	}


	{															// textfield
	NSRect textRect = {{10, 160}, {280, 60}};
	NSTextField *tfield;

    tfield = [[NSTextField alloc] initWithFrame:textRect];
    [tfield setStringValue:@"Francesco Sforza became Duke of Milan from being a private citizen because he was armed; his successors, since they avoided the inconveniences of arms, became private citizens after having been dukes."];
//    [tfield setAlignment:NSCenterTextAlignment];
//    [tfield setNextText:txtField];
    [tfield setBezeled:NO];
    [[tfield cell] setWraps:YES];
    [tfield setBackgroundColor:[window backgroundColor]];
    [v addSubview:tfield];
	}


	{															// nscursor
	NSRect cf = {{310, 110}, {150, 100}};
	NSColorWell *c = [[NSColorWell alloc] initWithFrame: cf];
	NSCursor *arrow, *beam;
	ColorView *cv0;
	NSRect cvf0 = {{310, 220}, {150, 100}};

	[c setColor:[NSColor blueColor]];
	[v addSubview: c];
	cv0 = [[ColorView alloc] initWithFrame: cvf0];
	[cv0 setColor:[NSColor greenColor]];
	[v addSubview: cv0];

	arrow = [NSCursor arrowCursor];	
	beam = [NSCursor dragCopyCursor];
	[beam setOnMouseEntered: YES];
	[arrow setOnMouseExited: YES];
	cf.origin = NSZeroPoint;
	[c addTrackingRect:cf owner:beam userData:NULL assumeInside: YES];
	[c addTrackingRect:cf owner:arrow userData:NULL assumeInside: YES];
	}


	{															// slider
	NSSlider *slider1;
	NSSlider *slider2;
	NSRect sliderRect1 = {{300, 10}, {250, 18}};
	NSRect sliderRect2 = {{550, 40}, {18, 200}};

	target = [MyObject new];

	slider1 = [[NSSlider alloc] initWithFrame:sliderRect1];
	[slider1 setMinValue:100];
	[slider1 setMaxValue:1000];
	[slider1 setContinuous:YES];
	[slider1 setTarget:target];
	[slider1 setAction:@selector(action:)];
	[v addSubview:slider1];
	
	slider2 = [[NSSlider alloc] initWithFrame:sliderRect2];
	[slider2 setMinValue:0];
	[slider2 setMaxValue:1];
	[slider2 setContinuous:NO];
	[slider2 setTarget:target];
	[slider2 setAction:@selector(action2:)];
	[v addSubview:slider2];
	}


	{															// level bar
	NSLevelIndicator *level;
	NSRect levelRect = {{300, 70}, {200, 12}};

	level = [[NSLevelIndicator alloc] initWithFrame:levelRect];
	[level setMinValue:1];
	[level setMaxValue:10];
	[level setDoubleValue:5];
	[level setContinuous:YES];
	[target setLevel:level];
	[v addSubview:level];
	}


	{															// nsscroller
	NSScroller *s0, *s1, *s2, *s3, *s4, *s5;
	NSRect sf0 = {{400, 340}, {150, 20}};
	NSRect sf1 = {{400, 370}, {150, 20}};
	NSRect sf2 = {{400, 400}, {150, 20}};
	NSRect sf3 = {{460, 430}, {20, 150}};
	NSRect sf4 = {{490, 430}, {20, 150}};
	NSRect sf5 = {{520, 430}, {20, 150}};

	s0 = [[NSScroller alloc] initWithFrame: sf0];
	[s0 setArrowsPosition: NSScrollerArrowsMaxEnd];
	[s0 setEnabled:YES];
	[s0 setTarget:self];
	[s0 setAction:@selector(scrollerAction:)];
	[v addSubview: s0];
	
	s1 = [[NSScroller alloc] initWithFrame: sf1];
	[s1 setArrowsPosition: NSScrollerArrowsMinEnd];
	[s1 setEnabled:YES];
	[s1 setTarget:self];
	[s1 setAction:@selector(scrollerAction:)];
	[v addSubview: s1];
	
	s2 = [[NSScroller alloc] initWithFrame: sf2];
	[s2 setArrowsPosition: NSScrollerArrowsNone];
	[s2 setEnabled:YES];
	[s2 setTarget:self];
	[s2 setAction:@selector(scrollerAction:)];
	[v addSubview: s2];
	
	s3 = [[NSScroller alloc] initWithFrame: sf3];
	[s3 setArrowsPosition: NSScrollerArrowsMaxEnd];
	[s3 setEnabled:YES];
	[s3 setFloatValue:0.5 knobProportion:0.4];
	[s3 setTarget:self];
	[s3 setAction:@selector(scrollerAction:)];
	[v addSubview: s3];
	
	s4 = [[NSScroller alloc] initWithFrame: sf4];
	[s4 setArrowsPosition: NSScrollerArrowsMinEnd];
	[s4 setEnabled:YES];
	[s4 setTarget:self];
	[s4 setAction:@selector(scrollerAction:)];
	[v addSubview: s4];
	
	s5 = [[NSScroller alloc] initWithFrame: sf5];
	[s5 setArrowsPosition: NSScrollerArrowsNone];
	[s5 setEnabled:YES];
	[s5 setTarget:self];
	[s5 setAction:@selector(scrollerAction:)];
	[v addSubview: s5];
	}

	{															// nstabview
	NSTabView *tabView;
	NSTabViewItem *item;
	NSRect tabViewRect = {{140, 500}, {280, 80}};
	id aView;
	id label;
	
	tabView = [[NSTabView alloc] initWithFrame:tabViewRect];
//	[tabView setTabViewType:NSBottomTabsBezelBorder];
	[tabView setDelegate:[TabViewDelegate new]];
	[v addSubview:tabView];

	aView = [[NSView alloc] initWithFrame:[tabView contentRect]];
	item = [[NSTabViewItem alloc] initWithIdentifier:@"itemOne"];
	[item setLabel:@"Can't touch this"];
	[item setView:aView];
	[tabView addTabViewItem:item];

	aView = [[NSView alloc] initWithFrame:[tabView contentRect]];
	item = [[NSTabViewItem alloc] initWithIdentifier:@"itemTwo"];
	[item setLabel:@"Item Number Two"];
	[item setView:aView];
	[tabView addTabViewItem:item];

	aView = [[PSView alloc] initWithFrame:[tabView contentRect]];
	item = [[NSTabViewItem alloc] initWithIdentifier:@"itemThree"];
	[item _setImage:[NSImage imageNamed:@"dotBlue"]];
	[item setLabel:@"Tee"];
	[item setView:aView];
	[tabView addTabViewItem:item];
	[tabView selectTabViewItemAtIndex:1];
	}

	{															// nsimageview
	NSImage *im = [NSImage imageNamed:@"dotBlue"];
	NSRect imr = {{220, 350}, {22,22}};
	NSImageView *iv;
	int i;

	for (i = 0; i < 9; i++)
		{
		if (i > 0)
			{
			if (i % 3)
				 imr.origin.x += 30;
			else
				imr.origin = (NSPoint){220, NSMaxY(imr) + 10};
			}
		iv = [[NSImageView alloc] initWithFrame: imr];
		[iv setImage:im];
		[iv setImageAlignment: (NSImageAlignment)i];
		[iv setImageFrameStyle: NSImageFramePhoto];
		[iv setImageScaling: NSScaleNone];
		[v addSubview: iv];
		}

	iv = [[NSImageView alloc] initWithFrame: (NSRect){{220, 450},{150,15}}];
	[iv setImage:[NSImage imageNamed:@"meter"]];
	[iv setImageFrameStyle: NSImageFrameGrayBezel];
	[iv setImageAlignment: NSImageAlignLeft];
	[iv setImageScaling: NSScaleProportionally];
	[v addSubview: iv];
	}

	[window setTitle:@"Combo Controls"];
	[window setFrame:winRect display:YES];
	[window orderFront:nil];
}

@end

int
main(int argc, char **argv, char** env)
{
    return NSApplicationMain(argc, argv);
}
