/* 
   coord.m

   Coordinate conversion
*/ 

#import <AppKit/AppKit.h>


@interface RectView : NSView
@end

@implementation RectView

- (void) drawRect:(NSRect)rect
{
	NSTimeInterval elapsed, start;
	NSRect r = {{10,10},{40,20}};
	NSRect c = {{10,25},{10,10}};

#if 0
	start = [[NSDate date] timeIntervalSinceReferenceDate];

	for (i = 0; i < 10000; i++)
		NSDrawButton (r, r);		

	elapsed = [[NSDate date] timeIntervalSinceReferenceDate] - start;
	printf ("elapsed time %f\n", elapsed);
#endif

 	CGContextSetBlendMode(_CGContext(), kCGBlendModeCopy);

	NSDrawButton (r, r);
	r.origin.x += 50;
	NSDrawGrayBezel (r, r);
	r.origin.x += 50;
	NSDrawWhiteBezel (r, r);
	r.origin.x += 50;
	NSDrawGroove (r, r);
	r.origin.x += 50;
	_NSImageFramePhoto (r, r);
	[[NSColor redColor] set];
	r.origin.x += 50;
	NSFrameRectWithWidth (r, 3.0);

	r = (NSRect){{20,15},{60,30}};			// test internal grab / draw image
	NSFrameRectWithWidth (r, 3.0);
	CGImageRef ip;
	if ((ip = _CGContextGetImage(_CGContext(), r)))
		{
		r = (NSRect){{120,40},{60,30}};
		CGContextDrawImage(_CGContext(), r, ip);
		NSFrameRectWithWidth (r, 3.0);

	NSBitmapImageRep *b = [[NSBitmapImageRep alloc] initWithFocusedViewRect: r];
	r = (NSRect){{25,50},{60,30}};
	if (![b drawInRect: r])
		NSLog(@"Failed to draw ImageRep");

		r = (NSRect){{200,40},{80,40}};
		CGContextDrawImage(_CGContext(), r, ip);
		NSFrameRectWithWidth (r, 3.0);
		}
}

@end

@interface FlippedRectView : NSView
@end

@implementation FlippedRectView

- (void) drawRect:(NSRect)rect	
{
	NSRect r = {{10,10},{40,20}};
	NSRect c = {{10,25},{10,10}};

	NSDrawButton (r, r);
	r.origin.x += 50;		
	NSDrawGrayBezel (r, r);
	r.origin.x += 50;		
	NSDrawWhiteBezel (r, r);
	r.origin.x += 50;		
	NSDrawGroove (r, r);
	r.origin.x += 50;		
	_NSImageFramePhoto (r, r);
	[[NSColor blackColor] set];
	r.origin.x += 50;		
	NSFrameRectWithWidth (r, 3.0);
}

- (BOOL) isFlipped								{ return YES; }

@end

@interface RFView : NSView
@end

@implementation RFView

- (void) drawRect:(NSRect)rect
{
	fprintf (stderr,
	"RFView:  (%1.2f, %1.2f), (%1.2f, %1.2f)\n",
				rect.origin.x, rect.origin.y,
				rect.size.width, rect.size.height);
	[[NSColor redColor] set];
	NSRectFill(rect);
}

- (BOOL) isFlipped								{ return YES; }

@end

@interface GFView : NSView
@end

@implementation GFView

- (void) drawRect:(NSRect)rect
{
	fprintf (stderr,
	"GFView: drawRect (%1.2f, %1.2f), (%1.2f, %1.2f)\n",
				rect.origin.x, rect.origin.y,
				rect.size.width, rect.size.height);
	[[NSColor greenColor] set];
	NSRectFill(rect);
}

- (BOOL) isFlipped								{ return YES; }

@end

@interface BNView : NSView
@end

@implementation BNView

- (void)drawRect:(NSRect)rect
{
	fprintf (stderr,
	"BNView: drawRect (%1.2f, %1.2f), (%1.2f, %1.2f)\n",
				rect.origin.x, rect.origin.y,
				rect.size.width, rect.size.height);
	[[NSColor blueColor] set];
	NSRectFill(rect);
}

@end

@interface RNView : NSView
@end

@implementation RNView

- (void) drawRect:(NSRect)rect
{
	fprintf (stderr,
	"RNView: drawRect (%1.2f, %1.2f), (%1.2f, %1.2f)\n",
				rect.origin.x, rect.origin.y,
				rect.size.width, rect.size.height);
	[[NSColor redColor] set];
	NSRectFill(rect);
}

@end

@interface CView : NSView
@end

@implementation CView

- (NSRect) selectWithRubberBand:(NSEvent*)event
{
	NSEventType type;
	NSPoint op, cp = [event locationInWindow];
	NSPoint t, p = [self convertPoint:cp fromView:nil];
	NSRect nr = (NSRect){p,{0,0}};
	NSRect or = nr;

	[[NSColor blackColor] set];

	while((type = [event type]) != NSLeftMouseUp)
		{
		if (type == NSPeriodic)
			{
			if (!NSEqualPoints(op, cp))
				{
				op = cp;
				t = nr.origin = [self convertPoint:cp fromView:nil];

				nr.size = (NSSize){MAX(p.x - nr.origin.x, nr.origin.x - p.x),
								   MAX(p.y - nr.origin.y, nr.origin.y - p.y)};
				if (nr.origin.x > p.x)
					nr.origin.x = p.x;
				if (nr.origin.y > p.y)
					nr.origin.y = p.y;

nr = NSIntegralRect(nr);
NSLog(@"OLD %f %f %f %f", or.origin.x,or.origin.y,or.size.width,or.size.height);
NSLog(@"NEW %f %f %f %f", nr.origin.x,nr.origin.y,nr.size.width,nr.size.height);
				if(or.size.width != 0)
		[_window restoreCachedImage];
//					NSFrameRectWithWidthUsingOperation(or,1., NSCompositeXOR);
//				[self scrollRectToVisible:(NSRect){t,{2.,2.}}];
				if(nr.size.width != 0)
					NSFrameRectWithWidthUsingOperation(nr,1., NSCompositeSourceOver);
				[_window flushWindow];
				or = nr;
			}	}
		else
			cp = [event locationInWindow];

		event = [NSApp nextEventMatchingMask:NSLeftMouseUpMask|NSMouseMovedMask|NSLeftMouseDraggedMask|NSPeriodicMask
					   untilDate:[NSDate distantFuture]
					   inMode:NSEventTrackingRunLoopMode 
					   dequeue:YES];
		}

	if(or.size.width != 0)
		{
		NSFrameRectWithWidthUsingOperation(or,1., NSCompositeXOR);
		[_window flushWindow];
		}

	return nr;
}

- (void) mouseDown:(NSEvent*)event
{
	if ([event type] == NSLeftMouseDown && [event clickCount] == 1)			// not in matrix rubberband
		{
		[NSEvent startPeriodicEventsAfterDelay:0.03 withPeriod:0.03];

		[_window cacheImageInRect:_bounds];

		[self lockFocus];
		[self selectWithRubberBand:event];
		[NSEvent stopPeriodicEvents];
		[self unlockFocus];

		[_window restoreCachedImage];
		[_window flushWindowIfNeeded];
		}
}

@end


@interface PPView : NSView
@end

@implementation PPView

- (void)drawRect:(NSRect)rect
{
	fprintf (stderr,
	"PPView: drawRect (%1.2f, %1.2f), (%1.2f, %1.2f)\n",
				rect.origin.x, rect.origin.y,
				rect.size.width, rect.size.height);
	[[NSColor purpleColor] set];
	NSRectFill(rect);
	
	NSImage *select = [NSImage imageNamed: @"select.tiff"];
	NSImage *gate = [NSImage imageNamed: @"g4.tiff"];

	[select compositeToPoint:(NSPoint){10,10} operation:NSCompositeSourceOver];
	[gate compositeToPoint:(NSPoint){30,20} operation:NSCompositeSourceOver];
}

@end


@interface Controller : NSObject
@end

@implementation Controller

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

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSPoint point;
	NSWindow *win;
	NSView *v;
	NSScrollView *t;
	NSView *a, *b, *c;
	NSRect rect;
	NSView *anotherView2;

    NSLog(@"Starting the application\n");

	win = [[NSWindow alloc] initWithContentRect:(NSRect){{100, 100},{500, 500}}
							styleMask:_NSCommonWindowMask
							backing:NSBackingStoreBuffered	
							defer:NO];

//    v = [win contentView];
    v = [[CView alloc] initWithFrame: (NSRect){{0, 0}, {500, 500}}];
	[win setContentView: v];

    c = [[RFView alloc] initWithFrame: (NSRect){{10, 10}, {100, 100}}];
    b = [[GFView alloc] initWithFrame: (NSRect){{0, 0}, {90, 90}}];
    [c addSubview:b];
    a = [[BNView alloc] initWithFrame: (NSRect){{0, 80}, {80, 80}}];
    [b addSubview:a];
    [v addSubview:c];
												// flipped scrollview
	t = [[NSScrollView alloc] initWithFrame: (NSRect){{150, 100}, {200, 200}}];
	[t setHasVerticalScroller:YES];
    b = [[GFView alloc] initWithFrame: (NSRect){{0, 0}, {180, 1500}}];
    a = [[BNView alloc] initWithFrame: (NSRect){{10, 80}, {80, 80}}];
    [b addSubview:a];
    [a addSubview:[[GFView alloc] initWithFrame: (NSRect){{10, 10}, {18, 15}}]];
    [a addSubview:[[RNView alloc] initWithFrame: (NSRect){{20, 20}, {18, 15}}]];
	[t setDocumentView:b];
	[[t contentView] setBoundsOrigin:(NSPoint){0,50}];
	[v addSubview:t];

	point = [b convertPoint:NSZeroPoint toView:nil];
	fprintf(stderr, "green 1 -- 0,0: (%1.2f, %1.2f)\n", point.x, point.y);
	point = [b convertPoint:(NSPoint){0,80} toView:nil];
	fprintf(stderr, "green 2 -- 0,80: (%1.2f, %1.2f)\n", point.x, point.y);
	rect = [b visibleRect];
	fprintf(stderr, "green visible: (%1.2f, %1.2f) (%1.2f, %1.2f)\n", 
			rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);

//	[[t contentView] scrollToPoint:(NSPoint){0,21}];

												// unflipped scrollview
	t = [[NSScrollView alloc] initWithFrame: (NSRect){{10, 200}, {100, 200}}];
	[t setHasVerticalScroller:YES];
    b = [[RNView alloc] initWithFrame: (NSRect){{0, 0}, {80, 1000}}];
    a = [[BNView alloc] initWithFrame: (NSRect){{10, 80}, {40, 40}}];
    [b addSubview:a];
	[t setDocumentView:b];
	[[t contentView] setBoundsOrigin:(NSPoint){0,40}];
	[v addSubview:t];

	point = [b convertPoint:NSZeroPoint toView:nil];
	fprintf(stderr, "red 1 -- 0,0: (%1.2f, %1.2f)\n", point.x, point.y);
	point = [b convertPoint:(NSPoint){0,80} toView:nil];
	fprintf(stderr, "red 2 -- 0,80: (%1.2f, %1.2f)\n", point.x, point.y);
	rect = [b visibleRect];
	fprintf(stderr, "red visible: (%1.2f, %1.2f) (%1.2f, %1.2f)\n", 
			rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);


    c = [[RectView alloc] initWithFrame:(NSRect){{150,400},{350, 100}}];
	[v addSubview:c];
    c = [[FlippedRectView alloc] initWithFrame:(NSRect){{150,300},{350, 100}}];
	[v addSubview:c];

    c = [[PPView alloc] initWithFrame: (NSRect){{450, -30}, {100, 100}}];
	[v addSubview:c];

	[v display];
    [win orderFront:nil];

/*
	point = [c convertPoint:NSZeroPoint toView:nil];
	fprintf(stderr, "red 10 -- 0,0: (%1.2f, %1.2f)\n", point.x, point.y);
	point = [c convertPoint:(NSPoint){0,5} toView:nil];
	fprintf(stderr, "red 20 -- 0,5: (%1.2f, %1.2f)\n", point.x, point.y);

	point = [b convertPoint:NSZeroPoint toView:nil];
	fprintf(stderr, "green 10 -- 0,0: (%1.2f, %1.2f)\n", point.x, point.y);
	point = [b convertPoint:(NSPoint){0,80} toView:nil];
	fprintf(stderr, "green 20 -- 0,80: (%1.2f, %1.2f)\n", point.x, point.y);
	point = [a convertPoint:(NSPoint){0,72} toView:nil];
	fprintf(stderr, "blue 10 -- 0,72: (%1.2f, %1.2f)\n", point.x, point.y);
*/
	{
	NSAffineTransform *rotation = [NSAffineTransform transform];

    [rotation rotateByDegrees:-30];
	NSLog(@"rotation %f", [rotation rotationAngle]);
	}
}

@end

int
main(int argc, const char **argv, char** env)
{
    return NSApplicationMain(argc, argv);
}
