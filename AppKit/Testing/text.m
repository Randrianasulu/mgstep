/*
   text.m
   
   NSTextStorage -> NSLayoutManager -> NSTextContainer -> NSTextView
      GlyphGenerator <--> || <--> NSTypeSetter
      ParagraphStyle <--> |
             TextTab <--> |
*/

#import <AppKit/AppKit.h>


@interface Controller : NSObject
{
}

@end

@implementation Controller

- (id) init
{
	[[NSApplication sharedApplication] setDelegate: self];
	return self;
}

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSWindow *win;
	NSRect wf = {{100, 100}, {400, 400}};
	NSView *v;

	NSTextStorage *textStorage;
	NSLayoutManager *layoutManager;
	NSTextContainer *textContainer;
	NSTextView *textView;

    NSLog(@"Starting the application\n");

	win = [[NSWindow alloc] initWithContentRect:wf
							styleMask:_NSCommonWindowMask
							backing:NSBackingStoreBuffered	
							defer:NO];

	[win setTitle:@"mGSTEP Text"];

	textStorage = [[NSTextStorage alloc] initWithString:@"Here's to the ones who see things different."];

	layoutManager = [[NSLayoutManager alloc] init];
	[textStorage addLayoutManager:layoutManager];

//	textContainer = [[NSTextContainer alloc] initWithContainerSize:self.windowView.frame.size];
	textContainer = [[NSTextContainer alloc] initWithContainerSize: wf.size];
	[layoutManager addTextContainer:textContainer];

//	textView = [[NSTextView alloc] initWithFrame:self.windowView.frame
	textView = [[NSTextView alloc] initWithFrame:(NSRect){NSZeroPoint, wf.size}
								   textContainer:textContainer];
    v = [win contentView];

    [v addSubview: textView];
	[win makeKeyAndOrderFront:nil];
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
