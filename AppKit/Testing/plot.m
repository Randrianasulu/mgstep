/*
   plot.m

*/

#import <AppKit/AppKit.h>


typedef struct _PVCandleStick * CandleStickRef;


@interface PVCandleStick : NSObject
{
	CGFloat open;
	CGFloat high;
	CGFloat low;
	CGFloat close;
	NSUInteger volume;
}

@end

typedef struct	{ @defs(PVCandleStick); } CandleStick;

@implementation PVCandleStick
@end

static DrawGrid(CGContextRef cx, NSRect rect)
{
	CGFloat ytick;
	CGFloat xtick;

	[[NSColor blackColor] set];
	NSRectFill(rect);

	[[NSColor lightGrayColor] setStroke];
	CGContextBeginPath(cx);

	for (ytick = 30; ytick < rect.size.height; ytick += 30)
		{
		CGContextMoveToPoint(cx, 0., ytick + 0.5);
		CGContextAddLineToPoint(cx, rect.size.width, ytick + 0.5);
		}
//	CGContextSetLineWidth(cx, .5);
	CGContextSetLineDash( cx, 3, (CGFloat []){2,3}, 2);		// 2 on, 3 off

	CGContextStrokePath(cx);

	CGContextSetRGBStrokeColor(cx, 0.3, 0.3, 0.3, 1.0);
	for (xtick = 80; xtick < rect.size.width; xtick += 80)
		{
		CGContextMoveToPoint(cx, xtick + 0.5, 0 + 0.5);
		CGContextAddLineToPoint(cx, xtick + 0.5, rect.size.height - 0.5);
		}
	CGContextSetLineDash( cx, 0, NULL, 0);
	CGContextStrokePath(cx);
}


@interface PlotView : NSView
{
	NSMutableArray *data;
	NSUInteger maxValue;
}

- (void) setData:(NSMutableArray *)plotData;
- (void) setMaxValue:(NSUInteger)max;

@end

@implementation PlotView

- (void) setData:(NSMutableArray *)plotData			{ data = plotData; }
- (void) setMaxValue:(NSUInteger)max				{ maxValue = max; }

@end


@interface CandleView : PlotView
@end

@implementation CandleView

- (void) drawRect:(NSRect)rect
{
	CGContextRef cx = [[NSGraphicsContext currentContext] graphicsPort];

	DrawGrid(cx, rect);

	if (data)
		{
		NSUInteger i, count = [data count];

		for (i = 0; i < count; i++ )
			{
			CandleStick *c = (CandleStick *)[data objectAtIndex: i];
			CGFloat yo = (c->open - floor(c->open)) * 100;
			CGFloat yc = (c->close - floor(c->close)) * 100;
			CGFloat h = ABS(yo-yc);
			CGFloat y = (yo > yc) ? yc : yo;
			CGFloat tx = 200.;
			CGFloat sx = 7.;

			CGFloat yh = (c->high - floor(c->high)) * 100;
			CGFloat yl = (c->low - floor(c->low)) * 100;

			if (yo > yc)
				[[NSColor redColor] setStroke];
			else
				[[NSColor greenColor] setStroke];

//printf("YO %f  YC %f  H %f  ", yo,yc,h);
			NSFrameRectWithWidth((NSRect){{10 * (i+1), y*sx-tx}, {4, MAX(1.0, h*sx)}}, 1.0);

			CGContextBeginPath(cx);
			CGContextMoveToPoint(cx, 10 * (i+1) + 2, yh*sx-tx);
			CGContextAddLineToPoint(cx, 10 * (i+1) + 2, yl*sx-tx);
			CGContextStrokePath(cx);
//printf("YH %f  YL %f\n", yh,yl);
		}	}
}

@end


@interface BarView : PlotView
@end

@implementation BarView

- (void) drawRect:(NSRect)rect
{
	DrawGrid([[NSGraphicsContext currentContext] graphicsPort], rect);

	if (data)
		{
		NSUInteger i, count = [data count];

		for (i = 0; i < count; i++ )
			{
			CandleStick *c = (CandleStick *)[data objectAtIndex: i];
			CGFloat yo = (c->open - floor(c->open)) * 100;
			CGFloat yc = (c->close - floor(c->close)) * 100;
			CGFloat h = ABS(yo-yc);
			CGFloat y = (yo > yc) ? yc : yo;
			CGFloat tx = 300.;
			CGFloat sx = 9.;
			CGFloat scale = maxValue / rect.size.height;

			if (yo > yc)
				[[NSColor redColor] setFill];
			else
				[[NSColor greenColor] setFill];

//printf("YO %f  YC %f  H %f\n", yo,yc,h);
			NSRectFill((NSRect){{10 * (i+1), 0}, {4,MAX(1.0, c->volume/scale)}});
		}	}
}

@end


@interface Controller : NSObject
{
	NSMutableArray *plotData;
	NSUInteger maxVolume;
}
@end

@implementation Controller

- (void) generateData
{
    if ( !plotData )
		{
		NSUInteger i;
		CGFloat close = 0.0;

		plotData = [NSMutableArray array];

		for (i = 0; i < 32; i++ )
			{
///			NSTimeInterval x = oneDay * i;
			CandleStick *c = (CandleStick *)[PVCandleStick alloc];

			if (close > 0.0)
				c->open = close;
			else
				c->open = 3.0 * rand()/(double)RAND_MAX + 1.0;
			close = c->close = (rand()/(double)RAND_MAX - 0.5) * 0.125 + c->open;
			c->high = MAX(c->open, MAX(c->close, (rand()/(double)RAND_MAX - 0.5) * 0.5 + c->open));
			c->low = MIN(c->open, MIN(c->close, (rand()/(double)RAND_MAX - 0.5) * 0.5 + c->open));
			c->volume = rand() % 100000;
			
			maxVolume = MAX(maxVolume, c->volume);
			
			[plotData addObject:(PVCandleStick *)c];
			}
		
		plotData = [plotData retain];
		}
}

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSWindow *win;
	NSRect wf = {{200, 300}, {600, 450}};
	CandleView *pv;

    NSLog(@"Starting the application\n");

	win = [[NSWindow alloc] initWithContentRect:wf
							styleMask:_NSCommonWindowMask
							backing:NSBackingStoreBuffered	
							defer:NO];

	[win setTitle:@"mGSTEP plot"];

	[self generateData];

    pv = [[BarView alloc] initWithFrame: (NSRect){{10, 10}, {580,140}}];
	[pv setAutoresizingMask:  NSViewWidthSizable];
	[pv setData: plotData];
	[pv setMaxValue: maxVolume];
    [[win contentView] addSubview: pv];

    pv = [[CandleView alloc] initWithFrame: (NSRect){{10, 155}, {580,285}}];
	[pv setAutoresizingMask: NSViewHeightSizable | NSViewWidthSizable];
	[pv setData: plotData];
    [[win contentView] addSubview: pv];
	[win makeKeyAndOrderFront:nil];
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
