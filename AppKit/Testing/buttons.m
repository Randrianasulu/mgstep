/*
   buttons.m
*/ 

#import <AppKit/AppKit.h>

#include <CoreText/CTFontManager.h>


@interface Controller : NSObject
{
	id textField;
	id textField1;
}

@end

@implementation Controller

- (id) init
{
	[[NSApplication sharedApplication] setDelegate: self];
	return self;
}

- (void) buttonAction:(id)sender
{
	NSLog (@"buttonAction:");
}

- (void) buttonAction2:(id)sender
{
	NSLog (@"buttonAction2:");
	[textField setStringValue:[sender intValue] ? @"on" : @"off"];
}

- (void) setTextField:(id)anObject
{
	if (anObject)
		[anObject retain];
	if (textField)
		[textField release];
	textField = anObject;
}

- (void) buttonPressed:sender
{
	NSLog (@"textfield value = %@", [textField1 stringValue]);
	[textField1 setStringValue: @"Hello"];
}

- (void) setTextField1:object
{
	textField1 = object;
}

- (void) buttonSwitchView:(id)sender
{
	NSLog (@"selected value = %@", [sender titleOfSelectedItem]);
}

- (void) comboBoxButton:(id)sender
{
	NSLog (@"selected value = %@", [sender objectValueOfSelectedItem]);
}

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSWindow *win;
	NSRect wf = {{100, 100}, {400, 400}};
	NSView *v;
	NSView* anotherView1;
	NSView* anotherView2;
	NSButton *mpush, *ponpoff, *toggle, *swtch, *radio, *mchange, *onoff, *light;
	NSButton *ponpoff1, *rswtch;
	NSRect bf0 = {{5, 5}, {200, 50}};
	NSRect bf1 = {{5, 65}, {90, 45}};
	NSRect bf10 = {{100, 65}, {90, 45}};
	NSRect bf2 = {{5, 115}, {90, 26}};
	NSRect bf3 = {{5, 170}, {90, 26}};
	NSRect bf5 = {{5, 280}, {200, 50}};
	NSRect bf6 = {{5, 10}, {100, 20}};
	NSRect bf7 = {{120, 115}, {90, 26}};
	NSRect anotherView1Frame = {{1, 335}, {200, 70}};
	NSRect anotherView2Frame = {{2, 10}, {180, 50}};
	NSRect textFieldRect = {{125, 10}, {60, 20}};
	NSTextField* txtField;
	id button;
	NSTextField* tfield;
	NSRect textRect = { {260, 100}, {100, 20} };
	NSRect buttonRect = { { 300, 130 }, { 53, 20 } };
	NSColorWell *colorWell;
	NSRect cwf = {{300, 30}, {40, 40}};
	NSRect frame = {{250, 200}, {100, 100}};
	NSForm* form;
	NSFormCell *c;
	NSPopUpButton *pushb;
	NSComboBox *combo;
	NSSegmentedControl *seg;

    NSLog(@"Starting the application\n");

	win = [[NSWindow alloc] initWithContentRect:wf
							styleMask:_NSCommonWindowMask
							backing:NSBackingStoreBuffered	
							defer:NO];

	[win setTitle:@"mGSTEP Buttons"];

    v = [win contentView];

    NSLog(@"Create the buttons\n");
    mpush = [[NSButton alloc] initWithFrame: bf0];
    [mpush setTitle: @"MomentaryPush"];
    [mpush setTarget:self];
    [mpush setAction:@selector(buttonAction:)];
    [mpush setContinuous:YES];

    ponpoff = [[NSButton alloc] initWithFrame: bf1];
    [ponpoff setButtonType:NSToggleButton];
    [ponpoff setTitle: @"Toggle"];
    [ponpoff setAlternateTitle: @"Alternate"];
    [ponpoff setImage:[NSImage imageNamed:@"NSSwitch"]];
    [ponpoff setAlternateImage:[NSImage imageNamed:@"NSHighlightedSwitch"]];
    [ponpoff setImagePosition:NSImageAbove];
    [ponpoff setAlignment:NSCenterTextAlignment];

    ponpoff1 = [[NSButton alloc] initWithFrame: bf10];
    [ponpoff1 setButtonType:NSToggleButton];
    [ponpoff1 setTitle: @"Toggle"];
    [ponpoff1 setAlternateTitle: @"Alternate"];
    [ponpoff1 setImage:[NSImage imageNamed:@"NSSwitch"]];
    [ponpoff1 setAlternateImage:[NSImage imageNamed:@"NSHighlightedSwitch"]];
    [ponpoff1 setImagePosition:NSImageBelow];
    [ponpoff1 setAlignment:NSCenterTextAlignment];

    toggle = [[NSButton alloc] initWithFrame: bf2];
    [toggle setButtonType: NSToggleButton];
    [toggle setTitle: @"Toggle"];

    light = [[NSButton alloc] initWithFrame: bf7];
    [light setButtonType: NSMomentaryLightButton];
    [light setTitle: @"Light"];

    swtch = [[NSButton alloc] initWithFrame: bf3];
    [swtch setButtonType: NSSwitchButton];
    [swtch setAllowsMixedState: YES];
    [swtch setBordered: NO];
    [swtch setTitle: @"Switch"];
    [swtch setAlternateTitle: @"Alternate"];

    radio = [[NSButton alloc] initWithFrame: (NSRect){{5, 225}, {90, 26}}];
    [radio setButtonType: NSRadioButton];
    [radio setBordered: NO];
    [radio setTitle: @"Radio"];
    [radio setAlternateTitle: @"Alternate"];

	bf3.origin.x += 100;
	bf3.size.width += 50;
    rswtch = [[NSButton alloc] initWithFrame: bf3];
    [[rswtch cell] setBezelStyle: NSRoundedBezelStyle];		// needed on OSX
    [rswtch setButtonType: NSMomentaryPushButton];
	[rswtch setImagePosition: NSImageRight];
	[rswtch setImage: [NSImage imageNamed: @"returnKey"]];
    [rswtch setTitle: @"Return"];
	[rswtch setKeyEquivalent: @"\r"];

    mchange = [[NSButton alloc] initWithFrame: bf5];
    [mchange setButtonType: NSMomentaryChangeButton];
    [mchange setTitle: @"MomentaryChange"];
    [mchange setAlternateTitle: @"Alternate"];

    anotherView1 = [[NSView alloc] initWithFrame:anotherView1Frame];
    anotherView2 = [[NSView alloc] initWithFrame:anotherView2Frame];

    onoff = [[NSButton alloc] initWithFrame: bf6];
    [onoff setButtonType: NSOnOffButton];
    [onoff setTitle: @"OnOff"];
    [onoff setTarget:self];
    [onoff setAction:@selector(buttonAction2:)];

    txtField = [[[NSTextField alloc] initWithFrame:textFieldRect] autorelease];
    [self setTextField:txtField];
    [txtField setStringValue:@"off"];

	colorWell = [[NSColorWell alloc] initWithFrame: cwf];
	[colorWell setColor:[NSColor greenColor]];

    tfield = [[NSTextField alloc] initWithFrame:textRect];
    [tfield setStringValue:@"abcdefghijklmnopqrstuvwxyz"];
    [tfield setAlignment:NSCenterTextAlignment];
    [tfield setNextText:txtField];
    [v addSubview:tfield];
	[win setInitialFirstResponder:tfield];

    [self setTextField1:tfield];
    [txtField setNextText:mchange];
    [mchange setNextKeyView:tfield];

	textRect.origin.y -= 25;
//  tfield = [[NSTextField alloc] initWithFrame:textRect];
    tfield = [[NSSecureTextField alloc] initWithFrame:textRect];
    [tfield setStringValue:@"abcdefghijklmnopqrstuvwxyz"];
    [tfield setAlignment:NSCenterTextAlignment];
    [[tfield cell] setScrollable:NO];
    [v addSubview:tfield];

	{
	CFErrorRef error = NULL;
	NSURL *fontURL = [[NSBundle mainBundle] URLForResource:@"Glyphter"
											withExtension:@"ttf"
											subdirectory:nil];

	if (!CTFontManagerRegisterFontsForURL((CFURLRef)fontURL, 1, &error))
//	if (!CTFontManagerRegisterFontsForURL((CFURLRef)fontURL, kCTFontManagerScopeProcess, &error))
		CFShow(error);
	else
		[tfield setFont:[[NSFont fontWithName:@"Glyphter" size:12.0] retain]];
	}

    button = [[NSButton alloc] initWithFrame:buttonRect];
    [button setButtonType:NSMomentaryPushButton];
    [[button cell] setShowsBorderOnlyWhileMouseInside: YES];
//    [[button cell] setBezelStyle: NSInlineBezelStyle];
    [v addSubview:button];
    [button setTarget:self];
    [button setAction:@selector(buttonPressed:)];

	form = [[NSForm alloc] initWithFrame:frame];
	c = [form addEntry:@"Field1"];
	[c setEditable:YES];
	[c setStringValue:@"Test"];
	[form addEntry:@"Field2"];
	[form addEntry:@"Field3"];
	[form setCellSize:(NSSize){90,20}];				// needed on OSX
	[form sizeToCells];
	[v addSubview:form];

	pushb = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(200,375,80,22) 
								   pullsDown:YES];
	[pushb addItemWithTitle:@"Devices"];
	[pushb addItemWithTitle:@"Network"];
	[pushb addItemWithTitle:@"Printers"];
	[pushb addItemWithTitle:@"Austin"];
	[pushb addItemWithTitle:@"Powers"];
	[pushb addItemWithTitle:@"Shag"];
	[pushb setTarget:self];
	[pushb setAction:@selector(buttonSwitchView:)];
	[v addSubview:pushb];

	pushb = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(300,375,80,22)];
	[pushb addItemWithTitle:@"Devices"];
	[pushb addItemWithTitle:@"Network"];
	[pushb addItemWithTitle:@"Printers"];
	[pushb addItemWithTitle:@"Austin"];
	[pushb addItemWithTitle:@"Powers"];
	[pushb addItemWithTitle:@"Shag"];
	[pushb setTarget:self];
	[pushb setAction:@selector(buttonSwitchView:)];
	[v addSubview:pushb];

	combo = [[NSComboBox alloc] initWithFrame:NSMakeRect(300,330,80,24)];
	[combo setTarget:self];
	[combo setAction:@selector(comboBoxButton:)];
	[combo addItemWithObjectValue: @"lady"];
	[combo addItemWithObjectValue: @"3Jane"];
	[combo addItemWithObjectValue: @"Turing"];
	[v addSubview:combo];

	seg = [[NSSegmentedControl alloc] initWithFrame:NSMakeRect(240,290,120,24)];
	[seg setSegmentCount: 3];
	[seg setSelectedSegment: 1];
	int i;
	NSString *labels[] = {@"one", @"two", @"three" };
	for (i = 0; i < 3; i++)
		[[seg cell] setTag:i forSegment:i];
	for (i = 0; i < 3; i++)
		[[seg cell] setLabel:labels[i] forSegment:i];
	[v addSubview:seg];

    NSLog(@"Make the buttons subviews\n");
    [v addSubview: mpush];
    [v addSubview: ponpoff];
    [v addSubview: ponpoff1];
    [v addSubview: toggle];
    [v addSubview: swtch];
    [v addSubview: radio];
    [v addSubview: rswtch];
    [v addSubview: mchange];
    [v addSubview:anotherView1];
    [anotherView1 addSubview:anotherView2];
    [anotherView2 addSubview:onoff];
    [anotherView1 addSubview:txtField];
    [v addSubview:light];
	[v addSubview: colorWell];

    [v display];
    [win orderFront:nil];
}

#ifdef __APPLE__
+ (NSApplication *) sharedApplication
{
	[Controller new];
	
	return [NSApplication sharedApplication];
}
#endif /* __APPLE__ */

@end

int
main(int argc, const char **argv, char** env)
{
    return NSApplicationMain(argc, argv);
}
