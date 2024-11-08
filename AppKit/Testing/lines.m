/*
   lines.m
*/ 

#import <AppKit/AppKit.h>

#include <math.h>



void _CGContextAddRoundRect(CGContextRef context, CGRect rect, float radius)
{
//	CGContextRef context = UIGraphicsGetCurrentContext();
//	[[UIColor whiteColor] set];
	[[NSColor blackColor] set];
	CGContextMoveToPoint(context, rect.origin.x, rect.origin.y + radius);
	CGContextAddLineToPoint(context, rect.origin.x, rect.origin.y + rect.size.height - radius);
	CGContextAddArc(context, rect.origin.x + radius, rect.origin.y + rect.size.height - radius, 
		radius, M_PI, M_PI / 2, 1);
	CGContextAddLineToPoint(context, rect.origin.x + rect.size.width - radius, 
		rect.origin.y + rect.size.height);
	CGContextAddArc(context, rect.origin.x + rect.size.width - radius, 
		rect.origin.y + rect.size.height - radius, radius, M_PI / 2, 0.0f, 1);
	CGContextAddLineToPoint(context, rect.origin.x + rect.size.width, rect.origin.y + radius);
	CGContextAddArc(context, rect.origin.x + rect.size.width - radius, rect.origin.y + radius, 
		radius, 0.0f, -M_PI / 2, 1);
	CGContextAddLineToPoint(context, rect.origin.x + radius, rect.origin.y);
	CGContextAddArc(context, rect.origin.x + radius, rect.origin.y + radius, radius, 
		-M_PI / 2, M_PI, 1);
}

_CGContextStrokeCappedRect(CGContextRef cc, NSRect r, CGVector o, float radius)
{
	CGContextBeginPath(cc);
	CGContextSetLineWidth(cc, 2);
	CGContextMoveToPoint(cc, r.origin.x, r.origin.y + o.dy);
CGContextAddArcToPoint( cc, r.origin.x, 	 NSMaxY(r) + o.dy + radius,
					r.origin.x + radius, NSMaxY(r) + o.dy + radius, radius);
	CGContextAddLineToPoint(cc, NSMaxX(r) + radius, NSMaxY(r) + o.dy + radius);
	CGContextStrokePath(cc);

	CGContextBeginPath(cc);
	CGContextSetLineWidth(cc, 4);
	CGContextMoveToPoint(cc, r.origin.x + o.dx, r.origin.y);
CGContextAddArcToPoint( cc, NSMaxX(r) + o.dx + radius, r.origin.y,
						NSMaxX(r) + o.dx + radius, r.origin.y + radius, radius);
	CGContextAddLineToPoint(cc, NSMaxX(r) + o.dx + radius, NSMaxY(r) + radius);
	CGContextStrokePath(cc);
}

void
path_test0( CGContextRef context, CGFloat tx, CGFloat ty)
{
	CGPoint poly[] = {{1,1},{9,1},{9,9},{3,9},{3,5},{7,5},{7,3},{5,3},{5,12},{1,12}};
	int i, count = sizeof(poly) / sizeof(CGPoint);
	CGMutablePathRef p1 = CGPathCreateMutable();

	CGPathMoveToPoint(p1, NULL, poly[0].x, poly[0].y);
	for (i = 1; i < count; i++)
		CGPathAddLineToPoint(p1, NULL, poly[i].x, poly[i].y);
	CGPathCloseSubpath(p1);

	{
	CGAffineTransform at = CGAffineTransformMakeScale (4, 4);

	at = CGAffineTransformTranslate( at, tx, ty);
    CGContextConcatCTM (context, at);
	CGContextSetLineWidth(context, 1.0);

	CGContextAddPath( context, p1);
	CGContextEOFillPath( context);
//	CGContextFillPath( context);
	}
}

@interface BezierView : NSView
{
    NSColor *lineColor, *fillColor, *backgroundColor;
    NSBezierPath *path;
    float lineWidth, angle, dashCount;
//    BezierPathType pathType;
//    CapStyleType capStyle;
    BOOL filled;
    float dashArray[3];
    
    // Outlets
    id lineColorWell;
    id fillColorWell;
    id backgroundColorWell;
    id lineWidthSlider;
    id pathTypeMatrix;
    id filledBox;
    id angleSlider;
    id capStyleMatrix;
    id zoomSlider;
    id lineTypeMatrix;
}

@end

@implementation BezierView

#if 0
- (void) wedge:(CGContextRef)cc
{
	CGContextBeginPath(cc);
	CGContextMoveToPoint(cc, 0, 0);
	CGContextTranslateCTM(cc, 1, 0);
	CGContextRotateCTM(cc, .2624);		// 15 rotate
	CGContextTranslateCTM(cc, 0, sin(.2624));	// 0 15 sin translate
	CGContextAddArc(cc, 0, 0, sin(.2624), M_PI / 2, -M_PI / 2, 1);
	CGContextClosePath(cc);
}

- (void) drawRectO:(NSRect)rect
{
	CGContextRef cc = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
/*
	{ newpath
	  0 0 moveto
	  1 0 translate
	  15 rotate
	  0 15 sin translate
	  0 0 15 sin -90 90 arc
	  closepath

gsave
  3.75 inch 7.25 inch translate
  1 inch 1 inch scale
  wedge 0.02 setlinewidth stroke
grestore
*/
	CGContextTranslateCTM(cc, 100, 200);
CGContextScaleCTM(cc, 72, 72);		//   1 inch 1 inch scale
CGContextSetLineWidth(cc, 0.02);
//CGContextScaleCTM(cc, 1.75, 1.75);

	[self wedge:cc];
    CGContextStrokePath(cc);
}
#endif

- (void) drawRect:(NSRect)rect
{
    NSRect bounds = [self bounds];
	CGContextRef cc = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];

////CGDisplayCapture( CGMainDisplayID() );
///	CGContextRef cc = CGDisplayGetDrawingContext( CGMainDisplayID() );

    NSAffineTransform *rotation    = [NSAffineTransform transform];
    NSAffineTransform *translation = [NSAffineTransform transform];

    [[NSColor whiteColor] set];
//    [backgroundColor set];
    NSRectFill([self bounds]);
 //   [lineColor set];
    [[NSColor blackColor] set];

//CGContextSetFillColorWithColor(cc, CGColorGetConstantColor(kCGColorBlack));
//CGContextSetStrokeColorWithColor(cc, CGColorGetConstantColor(kCGColorBlack));
#if 1
	
      CGContextBeginPath(cc);
_CGContextAddRoundRect( cc, CGRectMake(250, 20, 80, 60), 10);
//CGContextFillPath(cc);
	CGContextDrawPath(cc, kCGPathFillStroke);

      CGContextBeginPath(cc);
_CGContextAddRoundRect( cc, CGRectMake(250, 20, 80, 60), 10);
    [[NSColor greenColor] set];
	CGContextDrawPath(cc, kCGPathStroke);

    [[NSColor blackColor] set];

		CGContextMoveToPoint(cc, 100, 230);

//CGContextSetLineWidth(currentContext, 5);
	CGContextAddArc(cc, (float)120, (float)230, 30.0, M_PI / 4, M_PI / 2, 1);
    CGContextStrokePath(cc);

	CGContextMoveToPoint(cc, 10, 250);
CGContextAddQuadCurveToPoint( cc, 1, 300, 50, 280);
    CGContextStrokePath(cc);

	CGContextMoveToPoint(cc, 20, 230);
CGContextAddCurveToPoint( cc, 20, 252, 50, 252, 50, 230 );
//		CGContextAddLineToPoint(cc, 60, 240);
    CGContextStrokePath(cc);

		CGContextBeginPath(cc);
	CGContextMoveToPoint(cc, 15, 228);						// underline curve
		CGContextAddLineToPoint(cc, 60, 228);
	CGRect bbox = CGContextGetPathBoundingBox(cc);
	NSLog(@"BBox %f %f %f %f",bbox.origin.x, bbox.origin.y, bbox.size.width, bbox.size.height);
    CGContextStrokePath(cc);
	bbox = CGContextGetPathBoundingBox(cc);
	NSLog(@"BBox %f %f %f %f",bbox.origin.x, bbox.origin.y, bbox.size.width, bbox.size.height);

//	CGContextMoveToPoint(cc, 20, 200);
//CGContextAddCurveToPoint( cc, 20, 222, 20, 222, 35, 222 );
///CGContextAddCurveToPoint( cc, 20, 222, 50, 222, 50, 200 );
//    CGContextStrokePath(cc);

	[[NSBezierPath bezierPathWithOvalInRect: (NSRect){200,10,40,30}] stroke];
//	CGRect bbox = CGContextGetPathBoundingBox(cc);
//	NSLog(@"BBox %f %f %f %f",bbox.origin.x, bbox.origin.y, bbox.size.width, bbox.size.height);

	{														// line width
	int lineWidthTests = 5;
	float llineWidth = 1;
	float yOffset= 10;
	
	for (;lineWidthTests--; yOffset += 10, llineWidth++)
		{
		CGContextBeginPath(cc);
		CGContextMoveToPoint(cc, 10, yOffset);
		CGContextAddLineToPoint(cc, 40, yOffset);
		CGContextSetLineWidth(cc, llineWidth);
		CGContextStrokePath(cc);
		}
	}

	{														// line cap style
	int lineWidthTests = 3;
	float llineWidth = 10;
	float yOffset= 20;
	unsigned cap = 0;	// kCGLineCapButt, kCGLineCapRound, kCGLineCapSquare
	
	for (;lineWidthTests--; yOffset += 20, cap++)
		{
		CGContextBeginPath(cc);
		CGContextMoveToPoint(cc, 60, yOffset);
		CGContextAddLineToPoint(cc, 100, yOffset);
		CGContextSetLineWidth(cc, llineWidth);
		CGContextSetLineCap(cc, (CGLineCap)cap);
		CGContextStrokePath(cc);
		}
	}

	{														// line joing
	int i = 0;
	float llineWidth = 10;
	float xOffset = 0;
	float yOffset = 140;
	unsigned joint[] = { kCGLineJoinMiter, kCGLineJoinRound, kCGLineJoinBevel };
	
	for (;i < 3; yOffset -= 20, xOffset += 30, i++)
		{
		CGContextBeginPath(cc);
		CGContextMoveToPoint(cc, 10 + xOffset, yOffset);
		CGContextAddLineToPoint(cc, 60 + xOffset, yOffset);
		CGContextAddLineToPoint(cc, 40 + xOffset, yOffset+50);
		CGContextSetLineWidth(cc, llineWidth);
		CGContextSetLineJoin(cc, (CGLineJoin)joint[i]);
		CGContextStrokePath(cc);
		}
	}
#endif
#if 1
	{
	int i;
        // Draw wheel of lines.
printf("DRAW WHEEL LINE ************************* \n");
	for ( i = 0; i < 40; ++i)
		{
		CGContextBeginPath(cc);
		CGContextMoveToPoint(cc, 280 + 20 * sin(i * M_PI / 20), 200 + 20 * cos(i * M_PI / 20));
		CGContextAddLineToPoint(cc, 280 + 100 * sin(i * M_PI / 20), 200 + 100 * cos(i * M_PI / 20));
		CGContextSetLineWidth(cc, 2);	// FB renders poorly if not 1.0
		CGContextStrokePath(cc);
		}
printf("END !! DRAW WHEEL LINE ************************* \n");
	}
#endif
#if 1
	{
	int i;								// Draw row of straight lines.
printf("DRAW STRAIGHT LINE ************************* \n");
	for (i = 0; i < 20; ++i)
		{
		CGContextBeginPath(cc);
		CGContextMoveToPoint(cc, 20 + 15 * i, 310);
		CGContextAddLineToPoint(cc, 60 + 15 * i, 360);
		CGContextSetLineWidth(cc, .3 * (i + 1));
		CGContextStrokePath(cc);
		}
printf("END !! DRAW STRAIGHT LINE ************************* \n");
	}
#endif

#if 1
//CGContextConcatCTM(cc, CGAffineTransformMakeRotation(M_PI / 4));
CGContextStrokeRectWithWidth(cc, (CGRect){160,100,25,10}, 3.0);

_CGContextStrokeCappedRect(cc, (NSRect){{70, 270},{20,20}}, (CGVector){10,-10}, 5.0);

	CGContextBeginPath(cc);					// parallel line test
		CGContextSetLineWidth(cc, 10);
	CGContextMoveToPoint(cc, 140, 270);
//CGContextAddArcToPoint( cc, 140, 270, 140, 280, 1);
CGContextAddArcToPoint( cc, 140, 270, 140, 300, 1);
	CGContextStrokePath(cc);

	CGContextBeginPath(cc);
		CGContextSetLineWidth(cc, 1);
	CGContextMoveToPoint(cc, 130, 290);
CGContextAddArcToPoint( cc, 140, 300, 150, 290, 20);
	CGContextStrokePath(cc);

	CGContextBeginPath(cc);									// dashed rect
	CGContextSetLineWidth(cc, 1.0);
	CGContextSetLineDash( cc, 3, (CGFloat []){2,3}, 2);		// 2 on, 3 off
//	CGContextSetLineDash( cc, 3, (CGFloat []){0,2,3}, 3);	// cairo
	CGContextAddRect(cc, (CGRect){{150, 60},{40,20}});
	CGContextStrokePath(cc);

	CGContextBeginPath(cc);
	CGContextSetLineWidth(cc, 1.0);
	CGContextSetLineDash( cc, 3, (CGFloat []){1,3,4,2}, 4);
	CGContextAddRect(cc, (CGRect){{170, 50},{40,20}});
	CGContextStrokePath(cc);

	CGContextSetLineDash( cc, 0, NULL, 0);

	path_test0(cc, 30, 1);
#endif

	[[self window] flushWindow];

//	_CGImageWritePNM(((CGContext *)cc)->_bitmap, "BITMAP_DBG", 0);
}

@end

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
}

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSWindow *win;
	NSRect wf = {{100, 100}, {400, 400}};
	BezierView *c;
	NSView *v;

    NSLog(@"Starting the application\n");

	win = [[NSWindow alloc] initWithContentRect:wf
							styleMask:_NSCommonWindowMask
							backing:NSBackingStoreBuffered	
							defer:NO];

	[win setTitle:@"mGSTEP Lines"];

    v = [win contentView];

	c = [[BezierView alloc] initWithFrame:(NSRect){0,10,350,350}];
	[c setAutoresizingMask: NSViewMinYMargin|NSViewMinXMargin];
    [v addSubview:c];

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
