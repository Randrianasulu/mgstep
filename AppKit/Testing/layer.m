/*
   layer.m

*/

#include <AppKit/AppKit.h>
#include <QuartzCore/CALayer.h>
#include <QuartzCore/CAConstraintLayoutManager.h>


@interface TopLayer : CALayer
@end

@implementation TopLayer

- (void) display
{
	[super display];
}

- (void) drawInContext:(CGContextRef)cx
{
	[super drawInContext:cx];		// calls view's drawLayer:inContext:
}

@end


@interface LayerView : NSView

- (CGImageRef) convertImage:(NSImage *)image;

@end

@implementation LayerView

#if 0
- (BOOL) wantsUpdateLayer {return YES;}

- (void) updateLayer
{
	[super updateLayer];
}
#endif

- (id) initWithFrame:(NSRect)r
{
	if ((self = [super initWithFrame:r]))
		{
		CALayer *topLayer = [TopLayer layer];
		CAConstraint *c;

		[topLayer setName:@"top"];
		[topLayer setDelegate:self];
		[topLayer setBounds:[self bounds]];
		[topLayer setBorderWidth:4.0];
		[topLayer setLayoutManager:[CAConstraintLayoutManager layoutManager]];

		CALayer *imageLayer = [CALayer layer];
		[imageLayer setName:@"image"];

//		CGImageRef image = [self convertImage:[NSImage imageNamed:@"hal"]];
		CGImageRef image = [[[NSImage imageNamed:@"g0"] bestRepresentationForDevice: nil] CGImage];
		[imageLayer setBounds:CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image))];
		[imageLayer setContents:(id)image];

		c = [CAConstraint constraintWithAttribute: kCAConstraintMidY
						  relativeTo: @"superlayer"
						  attribute: kCAConstraintMidY];
		[imageLayer addConstraint:c];
		c = [CAConstraint constraintWithAttribute: kCAConstraintMidX
						  relativeTo: @"superlayer"
						  attribute: kCAConstraintMidX];
		[imageLayer addConstraint:c];

		CFRelease(image);

		[topLayer addSublayer:imageLayer];
		[topLayer setNeedsDisplay];

		[self setLayer:topLayer];
		[self setWantsLayer:YES];
		}

	return self;
}

- (void) drawLayer:(CALayer *)layer inContext:(CGContextRef)context
{
//	CGContextSetRGBFillColor(context, 1.0, .5, .5, 1);		// OSX
	CGContextSetRGBFillColor(context, .5, .5, 1.0, 1);
	CGContextFillRect(context, [layer bounds]);
}

- (CGImageRef) convertImage:(NSImage *)image
{
#if 0
	CGImageSourceRef s = CGImageSourceCreateWithData((CFDataRef)[image TIFFRepresentation],NULL);
	CGImageRef imageRef = CGImageSourceCreateImageAtIndex(s, 0,NULL);
	CFRelease(s);

	return imageRef;
#endif
	return NULL;
}

@end


@interface Controller : NSObject
{
	LayerView *_lv;
}
@end


@implementation Controller

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSArray *arguments = [[NSProcessInfo processInfo] arguments];
	NSWindow *win;
	NSRect wf = {{100,300}, {320,240}};
	NSSize aspect = {1,1};

	_lv = [[LayerView alloc] initWithFrame:(NSRect){NSZeroPoint,wf.size}];
	[_lv setAutoresizingMask: NSViewHeightSizable | NSViewWidthSizable];

	win = [[NSWindow alloc] initWithContentRect:wf
							styleMask:NSTitledWindowMask|NSResizableWindowMask|NSClosableWindowMask
							backing:NSBackingStoreBuffered	
							defer:NO];

	if (wf.size.width > wf.size.height)
		aspect.width = wf.size.width / wf.size.height;
	else
		aspect.height = wf.size.height / wf.size.width;
	[win setAspectRatio: aspect];
	[win setTitle:@"mGSTEP layer"];

//  [[win contentView] addSubview:_lv];
    [win setContentView:_lv];
	[[win contentView] display];
	[win orderFront:nil];
}

- (void) applicationWillTerminate:(NSNotification *)aNotification
{
}

- (id) init
{
	[[NSApplication sharedApplication] setDelegate: self];

	return self;
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
main(int argc, const char **argv, char **env)
{
    return NSApplicationMain(argc, argv);
}
