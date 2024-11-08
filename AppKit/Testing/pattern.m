/*
   pattern.m

*/

#import <AppKit/AppKit.h>


#define H_PATTERN_SIZE 16
#define V_PATTERN_SIZE 18
#define H_PSIZE 16
#define V_PSIZE 18

void MyDrawColoredPattern (void *info, CGContextRef myContext)
{
    CGFloat subunit = 5; // the pattern cell itself is 16 by 18
 
    CGRect  myRect1 = {{0,0}, {subunit, subunit}},
            myRect2 = {{subunit, subunit}, {subunit, subunit}},
            myRect3 = {{0,subunit}, {subunit, subunit}},
            myRect4 = {{subunit,0}, {subunit, subunit}};
 
    CGContextSetRGBFillColor (myContext, 0, 0, 1, 0.5);
    CGContextFillRect (myContext, myRect1);
    CGContextSetRGBFillColor (myContext, 1, 0, 0, 0.5);
    CGContextFillRect (myContext, myRect2);
    CGContextSetRGBFillColor (myContext, 0, 1, 0, 0.5);
    CGContextFillRect (myContext, myRect3);
    CGContextSetRGBFillColor (myContext, .5, 0, .5, 0.5);
    CGContextFillRect (myContext, myRect4);
}

void MyColoredPatternPainting (CGContextRef myContext, CGRect rect)
{
    CGPatternRef    pattern;// 1
    CGFloat         alpha = 1,// 3
                    width, height;// 4
    static const    CGPatternCallbacks callbacks = {0, // 5
                                        &MyDrawColoredPattern,
                                        NULL};
     CGColorSpaceRef patternSpace = CGColorSpaceCreatePattern (NULL);// 2

    CGContextSaveGState (myContext);
//    patternSpace = CGColorSpaceCreatePattern (NULL);// 6
    CGContextSetFillColorSpace (myContext, patternSpace);// 7
    CGColorSpaceRelease (patternSpace);// 8
 
    pattern = CGPatternCreate (NULL, // 9
                    CGRectMake (0, 0, H_PSIZE, V_PSIZE),// 10
                    CGAffineTransformMake (1, 0, 0, 1, 0, 0),// 11
                    H_PATTERN_SIZE, // 12
                    V_PATTERN_SIZE, // 13
                    kCGPatternTilingConstantSpacing,// 14
                    YES, // 15
                    &callbacks);// 16
 
    CGContextSetFillPattern (myContext, pattern, &alpha);// 17
    CGPatternRelease (pattern);// 18
//    CGContextFillRect (myContext, rect);// 19

	CGContextBeginPath( myContext);
//	[[NSColor blackColor] setFill];
	CGContextFillEllipseInRect(myContext, (NSRect){50,50,50,40});
//	[[NSColor blackColor] setStroke];
//	CGContextStrokeEllipseInRect(myContext, (NSRect){50,50,50,40});

    CGContextRestoreGState (myContext);
}

//	"33 33 51 1",
static char * Atom_xpm[] = {
"                                 ",
"                                 ",
"                      ..+@.      ",
"        #$%&*       =-%;;$=@     ",
"       #>  %%=     >.;;   ;@     ",
"      ,$>  %+$'   )%$+    ;@     ",
"      =%!     $='+!~{     @@     ",
"      ,%>    >> *!$-      @      ",
"      ]%%   ^]*>%;>      ~.      ",
"       !%#  /]]((((     ]$       ",
"        =%%_^::<~[<@!  -%        ",
"        *%+}}}|<<<[1%%2+;        ",
"    3+4++4%5[[5}:665^-_;4+++4    ",
"   474+++4%55}[::6<}},-;44+4+72  ",
"  343     } 155|855[[1[     277  ",
" 333      } 155|]5555}[      234 ",
" 333       1>1}<<55}}~|      27- ",
"  37{      ~([~~<55|[1      772  ",
"   9{27++44-11+@$@1714244++4+    ",
"     234+%4%.+++%+4774+4444++    ",
"     0^!@~-6(<<(%;.' __!%(.      ",
"        ~@.:6<<<;;@    .@$       ",
"      ^!;      ~@@$     :#       ",
"      ^;      ~22,-#     (#      ",
"      a;     ~@@  _(%    1%      ",
"      ,%    ~-@     ($   !%      ",
"      9;  $~@b       _!>!(!      ",
"      @+;$.2-         !!!!       ",
"       _0@_                      ",
"                                 ",
"                                 ",
"                                 ",
"                                 "};

const void *getBytePointer(void *info)
{
    return (char *)info + 0;
}

size_t getBytesAtPosition(void *info, void *buffer, off_t position, size_t count)
{
	size_t i;

	memset (buffer, 0xff, count * 4);

	for (i = 0; i < count; i++)
		{
		char **lines = (char **)info;
		char *line = lines[position/count];
		char byte = line[i];

		memset ((char *)buffer + (i * 4), byte, 3);
		}

	return i;
}

void DrawDataProviderImage (CGContextRef cx, CGPoint p)
{
	int w = 33;
	int h = 33;
	off_t size = w * h * 4;
	int bpp = 4 * 8;
	int bytesPerRow = w * 4;
	CGDataProviderDirectCallbacks cb = { 0, getBytePointer, 0, getBytesAtPosition, 0 };
	CGDataProviderRef dp = CGDataProviderCreateDirect(Atom_xpm, size, &cb);
	CGImageRef img;
	CGRect rect = {p,{w,h}};
	
	img = CGImageCreate( w, h, 8, bpp, bytesPerRow,
						 CGColorSpaceCreateDeviceRGB(),
						 kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst,
						 dp, NULL, 0, 0);
	CGDataProviderRelease(dp);
	CGContextDrawImage(cx, rect, img);
	CGImageRelease(img);
}


@interface PatternView : NSView
@end

@implementation PatternView

- (void) drawRect:(NSRect)rect
{
	CGContextRef cx = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];

	[[NSColor brownColor] set];
	NSRectFill(rect);

	MyColoredPatternPainting (cx, rect);

//	DrawDataProviderImage (cx, (CGPoint){120,120});
}

@end


@interface Controller : NSObject
@end

@implementation Controller

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSWindow *win;
	NSRect wf = {{200, 100}, {400, 400}};
	PatternView *pv;

    NSLog(@"Starting the application\n");

	win = [[NSWindow alloc] initWithContentRect:wf
							styleMask:_NSCommonWindowMask
							backing:NSBackingStoreBuffered	
							defer:NO];

	[win setTitle:@"mGSTEP pattern"];

    pv = [[PatternView alloc] initWithFrame: (NSRect){{10, 10}, {200, 200}}];

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
