/* 
   quartz.m

   Quartz API demo
*/ 

#import <AppKit/AppKit.h>

#include <math.h>


static void
myCalculateShadingValues (void *info, const CGFloat *in, CGFloat *out)
{
	CGFloat v;
	size_t k, components;
	static const CGFloat c[] = {1, 0, .5, 0 };
 
    components = (size_t)info;
 
    v = 1.0 - *in;
//    v = *in;

    for (k = 0; k < components -1; k++)
        *out++ = c[k] * v;   
     *out++ = 1;
}

static CGFunctionRef
myGetFunction (CGColorSpaceRef colorspace)// 1
{
size_t components;
static const CGFloat input_value_range [2] = { 0, 1 };
static const CGFloat output_value_ranges [8] = { 0, 1, 0, 1, 0, 1, 0, 1 };
static const CGFunctionCallbacks callbacks = { 0, &myCalculateShadingValues, NULL};
 
    components = 1 + CGColorSpaceGetNumberOfComponents (colorspace);// 3

    return CGFunctionCreate ((void *) components, // 4
                                1, // 5
                                input_value_range, // 6
                                components, // 7
                                output_value_ranges, // 8
                                &callbacks);// 9
}

void
myPaintAxialShading (CGContextRef myContext, CGRect bounds)
{
	CGPoint startPoint = CGPointMake(0, 0.5);
	CGPoint endPoint = CGPointMake(1, 0.5);
	CGAffineTransform myTransform;
	CGFloat width = bounds.size.width;
	CGFloat height = bounds.size.height;
	CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
	CGFunctionRef myShadingFunction = myGetFunction(colorspace);
	CGShadingRef shading;

    startPoint = CGPointMake(1, .001); // 2
    endPoint = CGPointMake(.001, 1.0);// 3

    shading = CGShadingCreateAxial (colorspace, // 6
                                 startPoint, endPoint,
                                 myShadingFunction,
                                 NO, NO);
 
    myTransform = CGAffineTransformMakeScale (width, height);// 7
    CGContextConcatCTM (myContext, myTransform);// 8
    CGContextSaveGState (myContext);// 9
 
    CGContextClipToRect (myContext, CGRectMake(0, 0, 1, 1));// 10
    CGContextSetRGBFillColor (myContext, 1, 1, 1, 1);
    CGContextFillRect (myContext, CGRectMake(0, 0, 1, 1));
 
    CGContextBeginPath (myContext);// 11
    CGContextAddArc (myContext, .5, .5, .3, 0, M_PI, 0);
    CGContextClosePath (myContext);
    CGContextClip (myContext);

	CGRect bbox = CGContextGetPathBoundingBox(myContext);
	NSLog(@"BBox %f %f %f %f",bbox.origin.x, bbox.origin.y, bbox.size.width, bbox.size.height);
 
    CGContextDrawShading (myContext, shading);// 12
    CGColorSpaceRelease (colorspace);// 13
    CGShadingRelease (shading);
    CGFunctionRelease (myShadingFunction);
 
    CGContextRestoreGState (myContext); // 14
}

void
myPaintRadialShading (CGContextRef myContext, CGRect bounds)
{
	CGPoint startPoint, endPoint;
	CGFloat   startRadius,  endRadius;
	CGAffineTransform myTransform;
	CGFloat width = bounds.size.width;
	CGFloat height = bounds.size.height;
	CGFunctionRef myShadingFunction;
	CGColorSpaceRef colorspace;
	CGShadingRef shading;

    startPoint = CGPointMake(0.25,0.3); // 2
    startRadius = .01;  // 3
    endPoint = CGPointMake(.7,0.7); // 4
//    endPoint = CGPointMake(0.25,0.3); // 4
//    endPoint = CGPointMake(0.4,0.4); // 4
    endPoint = CGPointMake(0.4,0.6); // 4
    endRadius = .35; // 5
 
    colorspace = CGColorSpaceCreateDeviceRGB(); // 6
    myShadingFunction = myGetFunction (colorspace);// 7
 
    shading = CGShadingCreateRadial (colorspace, // 8
                            startPoint, startRadius,
                            endPoint, endRadius,
                            myShadingFunction,
                            NO, NO);
 
    myTransform = CGAffineTransformMakeScale (width, height);// 9
    CGContextConcatCTM (myContext, myTransform);// 10
    CGContextSaveGState (myContext);// 11
 
    CGContextClipToRect (myContext, CGRectMake(0, 0, 1, 1));
    CGContextSetRGBFillColor (myContext, 1, 1, 1, 1);// 12
    CGContextFillRect (myContext, CGRectMake(0, 0, 1, 1));
 
    CGContextDrawShading (myContext, shading);// 13
    CGColorSpaceRelease (colorspace);// 14
    CGShadingRelease (shading);
    CGFunctionRelease (myShadingFunction);
 
    CGContextRestoreGState (myContext); // 15
}

void
myPaintAxialGradient (CGContextRef myContext, CGRect bounds)
{
	CGGradientRef myGradient;
	CGColorSpaceRef myColorspace;
	size_t num_locations = 2;
	CGFloat locations[2] = { 0.0, 1.0 };
	CGFloat components[8] = { 1.0, 0.5, 0.4, 1.0,  // Start color
							  0.8, 0.8, 0.3, 1.0 }; // End color

	CGFloat width = bounds.size.width;
	CGFloat height = bounds.size.height;
	CGAffineTransform myTransform;

	myColorspace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
	myGradient = CGGradientCreateWithColorComponents (myColorspace, components,
							  locations, num_locations);

	CGPoint myStartPoint, myEndPoint;
	myStartPoint.x = 0.0;
	myStartPoint.y = 0.0;
	myEndPoint.x = 1.0;
	myEndPoint.y = 1.0;

    myTransform = CGAffineTransformMakeScale (width, height);// 9
    CGContextConcatCTM (myContext, myTransform);// 10
    CGContextSaveGState (myContext);// 11

    CGContextClipToRect (myContext, CGRectMake(0, 0, 1, 1));
    CGContextSetRGBFillColor (myContext, 1, 1, 1, 1);// 12
    CGContextFillRect (myContext, CGRectMake(0, 0, 1, 1));

	CGContextDrawLinearGradient (myContext, myGradient, myStartPoint, myEndPoint, 0);

	CGGradientRelease(myGradient);

    CGContextRestoreGState (myContext); // 15
}

void
myPaintAxialGradientGray (CGContextRef myContext, CGRect bounds)
{
	CGGradientRef myGradient;
	CGColorSpaceRef myColorspace;
	size_t num_locations = 3;
	CGFloat locations[3] = { 0.0, 0.5, 1.0};
	CGFloat components[12] = {  1.0, 1.0, 1.0, 1.0,
								0.5, 0.5, 0.5, 1.0,
								1.0, 1.0, 1.0, 1.0 };
	CGFloat width = bounds.size.width;
	CGFloat height = bounds.size.height;
	CGAffineTransform myTransform;

	myColorspace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
	myGradient = CGGradientCreateWithColorComponents (myColorspace, components,
							  locations, num_locations);

	CGPoint myStartPoint, myEndPoint;
	myStartPoint.x = 0.0;
	myStartPoint.y = 0.0;
	myEndPoint.x = 1.0;
	myEndPoint.y = 1.0;

    myTransform = CGAffineTransformMakeScale (width, height);// 9
    CGContextConcatCTM (myContext, myTransform);// 10
    CGContextSaveGState (myContext);// 11

//    CGContextClipToRect (myContext, CGRectMake(0, 0, 1, 1));
    CGContextSetRGBFillColor (myContext, 1, 1, 1, 1);// 12
//    CGContextFillRect (myContext, CGRectMake(0, 0, 1, 1));

	CGContextDrawLinearGradient (myContext, myGradient, myStartPoint, myEndPoint, 0);

    CGContextRestoreGState (myContext); // 15
}

void
myPaintRadialGradient (CGContextRef myContext, CGRect bounds)
{
	CGGradientRef myGradient;
	CGColorSpaceRef myColorspace;
	size_t num_locations = 2;
	CGFloat locations[2] = { 0.0, 1.0 };
	CGFloat components[8] = { 1.0, 0.5, 0.4, 1.0,  // Start color
							  0.8, 0.8, 0.3, 1.0 }; // End color

	CGFloat width = bounds.size.width;
	CGFloat height = bounds.size.height;
	CGAffineTransform myTransform;

	myColorspace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
	myGradient = CGGradientCreateWithColorComponents (myColorspace, components,
							  locations, num_locations);

	CGPoint myStartPoint, myEndPoint;
	CGFloat myStartRadius, myEndRadius;
	myStartPoint.x = 0.15;
	myStartPoint.y = 0.15;
	myEndPoint.x = 0.5;
	myEndPoint.y = 0.5;
	myStartRadius = 0.1;
	myEndRadius = 0.25;


    myTransform = CGAffineTransformMakeScale (width, height);// 9
    CGContextConcatCTM (myContext, myTransform);// 10
    CGContextSaveGState (myContext);// 11

    CGContextClipToRect (myContext, CGRectMake(0, 0, 1, 1));
    CGContextSetRGBFillColor (myContext, 1, 1, 1, 1);// 12
    CGContextFillRect (myContext, CGRectMake(0, 0, 1, 1));

	CGContextDrawRadialGradient (myContext, myGradient, myStartPoint,
							 myStartRadius, myEndPoint, myEndRadius,
							 kCGGradientDrawsAfterEndLocation);

    CGContextRestoreGState (myContext); // 15
}

void
myPaintRadialGradientAlpha (CGContextRef myContext, CGRect bounds)
{
	CGGradientRef myGradient;
	CGColorSpaceRef myColorspace;
	CGPoint myStartPoint, myEndPoint;
	CGFloat myStartRadius, myEndRadius;
	myStartPoint.x = 0.2;
	myStartPoint.y = 0.5;
	myEndPoint.x = 0.65;
	myEndPoint.y = 0.5;
	myStartRadius = 0.1;
	myEndRadius = 0.25;
	size_t num_locations = 2;
	CGFloat locations[2] = { 0, 1.0 };
	CGFloat components[8] = { 0.95, 0.3, 0.4, 1.0,
							  0.95, 0.3, 0.4, 0.1 };

	CGFloat width = bounds.size.width;
	CGFloat height = bounds.size.height;
	CGAffineTransform myTransform;

	myColorspace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
	myGradient = CGGradientCreateWithColorComponents (myColorspace, components,
							  locations, num_locations);

    myTransform = CGAffineTransformMakeScale (width, height);// 9
    CGContextConcatCTM (myContext, myTransform);// 10
    CGContextSaveGState (myContext);// 11

    CGContextClipToRect (myContext, CGRectMake(0, 0, 1, 1));
    CGContextSetRGBFillColor (myContext, 1, 1, 1, 1);// 12
    CGContextFillRect (myContext, CGRectMake(0, 0, 1, 1));

	CGContextDrawRadialGradient (myContext, myGradient, myStartPoint,
							 myStartRadius, myEndPoint, myEndRadius,
							 kCGGradientDrawsAfterEndLocation);
//							 kCGGradientDrawsAfterEndLocation|kCGGradientDrawsBeforeStartLocation);

    CGContextRestoreGState (myContext); // 15
}

void
myDrawWithShadows (CGContextRef myContext, CGFloat wd, CGFloat ht)
{
    CGSize myShadowOffset = CGSizeMake (-15,  20);		// 2
    CGFloat myColorValues[] = {1, 0, 0, .6};			// 3
    CGColorRef myColor;									// 4
    CGColorSpaceRef myColorSpace;						// 5
 
    CGContextSaveGState(myContext);// 6
 
 	CGContextSetBlendMode(myContext, kCGBlendModeCopy);

    CGContextSetShadow (myContext, myShadowOffset, 5); // 7
    // Your drawing code here// 8
    CGContextSetRGBFillColor (myContext, 0, 1, 0, 1);
    CGContextFillRect (myContext, CGRectMake (wd/3 + 75, ht/2 , wd/4, ht/4));
 
    myColorSpace = CGColorSpaceCreateDeviceRGB ();// 9
    myColor = CGColorCreate (myColorSpace, myColorValues);// 10
    CGContextSetShadowWithColor (myContext, myShadowOffset, 5, myColor);// 11
    // Your drawing code here// 12
    CGContextSetRGBFillColor (myContext, 0, 0, 1, 1);
    CGContextFillRect (myContext, CGRectMake (wd/3-75,ht/2-100,wd/4,ht/4));
 
    CGColorRelease (myColor);// 13
    CGColorSpaceRelease (myColorSpace); // 14
 
    CGContextRestoreGState(myContext);// 15
}

static void
MenuShadingValues (void *info, const CGFloat *in, CGFloat *out)
{
	CGFloat v = *in;
	size_t k, components = (size_t)info;
	static const CGFloat c[] = {.75, .75, .75, 0};

    for (k = 0; k < components - 1; k++)
        *out++ = c[k] * v;
     *out++ = 1;						// alpha
}

extern CGFunctionRef _CreateShadingFunction (CGColorSpaceRef cs, CGFunctionCallbacks *cb);

static CGShadingRef
_MenuShading(void)
{
	static CGFunctionRef fn;
	static CGShadingRef shading = NULL;
	static CGFunctionCallbacks callbacks = { 0, &MenuShadingValues, NULL };

	if (!shading)
		{
		CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
#if 0
		CGPoint s = CGPointMake(0.0, 1.0);		// vertical gradient white top
		CGPoint e = CGPointMake(0.0, 0.0);
		CGPoint s = CGPointMake(0.0, 0.0);		// vertical gradient black top
		CGPoint e = CGPointMake(0.0, 1.0);
		CGPoint s = CGPointMake(0.0, 1.0);		// diag gradient white left top
		CGPoint e = CGPointMake(1.0, 0.0);
		CGPoint s = CGPointMake(1.0, 0.0);		// diag gradient black left top
		CGPoint e = CGPointMake(0.0, 1.0);
		CGPoint s = CGPointMake(0.0, 0.0);		// horiz gradient black left
		CGPoint e = CGPointMake(1.0, 0.0);
#endif
		CGPoint s = CGPointMake(1.0, 0.0);		// horiz gradient white left
		CGPoint e = CGPointMake(0.0, 0.0);

		fn = _CreateShadingFunction(colorspace, &callbacks);
		shading = CGShadingCreateAxial(colorspace, s, e, fn, NO, NO);
		}

 	return shading;
}

void
myPaintAxialGradientGrayMenu (CGContextRef myContext, CGRect bounds)
{
	CGFloat width = bounds.size.width;
	CGFloat height = bounds.size.height;
	CGAffineTransform at = CGAffineTransformMakeScale (width, height);

	CGContextSaveGState (myContext);
	CGContextConcatCTM (myContext, at);
	CGContextDrawShading(myContext, _MenuShading());
    CGContextRestoreGState (myContext); // 15
}


@interface PSView : NSView
{
	unsigned int _num;
}

- (void) setDemoNumber:(int)newNum;

@end

@implementation PSView

- (void) drawRect:(NSRect)rect						
{
	CGContextRef gc = [[NSGraphicsContext currentContext] graphicsPort];

	switch (_num)
		{
		case 0:
			myPaintAxialShading (gc, rect);
			break;
		case 1:
			myPaintRadialShading (gc, rect);
			break;
		case 2:
			myPaintAxialGradient (gc, rect);
			break;
		case 3:
			myPaintRadialGradient (gc, rect);
			break;
		case 4:
			myPaintRadialGradientAlpha (gc, rect);
			break;
		case 5:
			myPaintAxialGradientGray (gc, rect);
			break;
		case 6:
			myDrawWithShadows (gc, rect.size.width, rect.size.height);
			break;
		case 7:
			myPaintAxialGradientGrayMenu (gc, rect);
			break;
        default:
            NSLog(@"Invalid item");
		}
}

- (void) setDemoNumber:(int)newNum
{
    _num = newNum;
}

@end


@interface Controller : NSObject
{
	NSPopUpButton *popup;
	id demoView;
}
@end

@implementation Controller

- (void) selectDemo:(id)sender
{
    [demoView setDemoNumber:[popup indexOfSelectedItem]];
    [demoView setNeedsDisplay:YES];
}

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSWindow *win;
	NSView *v;
	id title = nil;

	NSArray *titles = [NSArray arrayWithObjects:
								@"Axial Shading",
								@"Radial Shading",
								@"Axial Gradient",
								@"Radial Gradient",
								@"Radial Gradient Alpha",
								@"Axial Gradient Gray",
								@"Shadows",
								@"Menu",
								nil];
	NSEnumerator *titleEnum = [titles objectEnumerator];

	win = [[NSWindow alloc] initWithContentRect:(NSRect){{100, 100},{500, 400}}
							styleMask:_NSCommonWindowMask
							backing:NSBackingStoreBuffered	
							defer:NO];
	[win setTitle:@"mGSTEP Quartz"];

    v = [win contentView];

	popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(200,360,120,20)];
    [[popup cell] setWraps:YES];
	[popup setTarget:self];
	[popup setAction:@selector(selectDemo:)];
    while (title = [titleEnum nextObject])
        [popup addItemWithTitle:title];

    demoView = [[PSView alloc] initWithFrame: (NSRect){{10, 10}, {462, 325}}];
    [v addSubview:demoView];
    [v addSubview:popup];
    [demoView setDemoNumber:0];
	[popup selectItemAtIndex:0];

	[v display];
    [win orderFront:nil];
}

@end /* Controller */


int 
main(int argc, char** argv, char** env)
{
	id pool = [NSAutoreleasePool new];

	[[NSApplication sharedApplication] setDelegate: [Controller new]];
	[NSApp run];
	[pool release];

	return 0;
}
