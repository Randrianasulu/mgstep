/* 
   fonts.m

   Test low-level text decoding and font rendering
*/ 

#include <Foundation/NSString.h>
#include <CoreFoundation/CFBase.h>
#include <CoreText/CTFont.h>

#import <AppKit/AppKit.h>
#include <CoreGraphics/CoreGraphics.h>

#ifndef __APPLE__
#include <CoreGraphics/Private/_CGFont.h>

#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_SFNT_NAMES_H
#include FT_TRUETYPE_TABLES_H
#include FT_TRUETYPE_IDS_H
#include FT_TYPE1_TABLES_H
#include FT_BDF_H
#include FT_TRUETYPE_TABLES_H
#endif

NSFont *__font = nil;


@interface FontView : NSView
@end

@implementation FontView

- (NSDictionary *) defaultAttributes
{	
	return [NSDictionary dictionaryWithObjectsAndKeys:
								  __font, NSFontAttributeName,
					[NSColor whiteColor], NSForegroundColorAttributeName, nil];
}

- (void) drawRect:(NSRect)rect
{
	double angle = ( 30.0 / 360 ) * 3.14159 * 2;      // 30 degress
//	unsigned char *english = "HelloHelloHelloHello";
	unsigned char *english = "Hello World";
//	unsigned char *english = "Hello at 30 degrees";
	unsigned char *chinese = "生活大爆炸";
	unsigned char *japanese = "新 あたら しい 記事 きじ を 書 か こうという 気持 きも ちになるまで ";
	unsigned char *korean = "모든 사람은 공동체의 문화생활에 자유롭게";
	unsigned char *greek = "κόσμε";
	CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
	int i;

	NSString *s = [NSString stringWithCString:"Starting the application"];

	CGAffineTransform tm = CGAffineTransformMake(1.0, 0.0, 0.0, 1.0, 0.0, 0.0);

	[[NSColor greenColor] set];
	NSRectFill([self bounds]);
	
	[__font set];

	[[NSColor colorWithCalibratedRed:0 green:0 blue:1 alpha:0.5] set];
//	[[NSColor blackColor] set];

//	CGContextSetTextDrawingMode(context, kCGTextFill);
//	CGContextSelectFont(context, "Helvetica", 16, kCGEncodingMacRoman);
//	CGContextSelectFont(context, "Helvetica", 16, kCGEncodingFontSpecific);
//	CGContextShowTextAtPoint (context, 30, 15, [m cString], [m length]);
	tm = CGAffineTransformRotate(tm, angle);		// ~30, .5233

	CGContextSetTextMatrix (context, tm);
	CGContextShowTextAtPoint (context, 30, 40, english, strlen(english));
	CGContextSetTextMatrix (context, CGAffineTransformIdentity);
	CGContextShowTextAtPoint (context, 30, 90, chinese, strlen(chinese));
	CGContextShowTextAtPoint (context, 30, 110, greek, strlen(greek));

	[s drawInRect:(NSRect){{30,5},{100,22}}
		withAttributes:[self defaultAttributes]];

	CGContextSetTextMatrix (context, tm);
	CGContextShowTextAtPoint (context, 32, 40, english, strlen(english));

	[[NSColor blackColor] set];
	[[NSFont fontWithName:@"Sans-Bold" size:12] set];
	CGContextSetTextMatrix (context, CGAffineTransformIdentity);
	CGContextShowTextAtPoint (context, 32, 140, "/bin/bash", strlen("/bin/bash"));

	[[NSFont fontWithName:@"song ti" size:16] set];
	CGContextShowTextAtPoint (context, 70, 160, chinese, strlen(chinese));


	NSFont *f = [NSFont userFixedPitchFontOfSize:13];	// font substitution
	unsigned char *subs = "sub-生活大爆炸-stitute";
//	unsigned char *subs = "sub-ちになるまで-stitute";		// japanese
//	unsigned char *subs = "sub-모든 사람은-stitute";		// korean
	NSString *cs = [NSString stringWithUTF8String:subs];
	NSUInteger len = [cs length];
	unichar *chars = alloca(sizeof(unichar) * (len + 1));
	CGGlyph glyphs[len];

	memset(glyphs, 0, len);
	memset(chars, 0, len*sizeof(unichar));

	[cs getCharacters:chars range:(NSRange){0,len}];

	[f set];

	if (CTFontGetGlyphsForCharacters( (CTFontRef)f, chars, glyphs, len ))
		CGContextShowGlyphsAtPoint(context, 20, 185, glyphs, len);
	else
		{
		CFString s = {0};
		CGPoint pen;

		s._uniChars = chars;
		s._count = len;

		for (i = 0; i < len; i++)			// count valid glyphs
			if (glyphs[i] == 0)
				break;
		CGContextShowGlyphsAtPoint(context, 20, 185, glyphs, i);
		pen = CGContextGetTextPosition( context);

		for (; i < len; i++)				// sub invalid glyphs
			{
			CTFontRef nf = NULL;
			CGGlyph sglyphs[2] = {0};
			const UniChar uc[] = { chars[i] };

			if (glyphs[i] == 0)
				{
				if ((nf = CTFontCreateForString( (CTFontRef)f, (CFStringRef)&s, (CFRange){i,1})))
					if (CTFontGetGlyphsForCharacters( nf, uc, sglyphs, 1 ))
						{
						CGContextSetFont(context, (CGFontRef)nf);
						CGContextShowGlyphsAtPoint(context, pen.x, pen.y, &sglyphs[0], 1);
						}
					else
						NSLog(@"Font substitution failed for unichar (%x)", chars[i]);
				}
			else
				CGContextShowGlyphsAtPoint(context, pen.x, pen.y, &glyphs[i], 1);

			pen = CGContextGetTextPosition( context);
			if (nf)
				CGContextSetFont(context, (CGFontRef)f);
			}
		}

	[[NSFont systemFontOfSize: 12] set];
	[__font release];								// test font release
	__font = [[NSFont systemFontOfSize: 16] retain];
}

@end


@interface Controller : NSObject
@end

@implementation Controller

- (id) init
{
	[[NSApplication sharedApplication] setDelegate: self];	
}

- (void) enumerateFontsAtPath:(NSString *)path
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSDirectoryEnumerator *en = [fm enumeratorAtPath: path];
	NSString *file;

	while (file = [en nextObject])
		{
		const char *s = [file cString];

		if (!strstr(s, "fonts."))
			printf("  %s\n", s);
		}
}

#ifndef __APPLE__
- (NSFont *) getPlatformFont
{
	const char *xFontName; 										// font family
	char *xfontWeight = "medium"; 								// font weight
	NSString *xf = nil;
	const char *cname = NULL; 									// font family 

	AXFontInt *fnti;
	NSFont *font;

//	xFontName = "/usr/X11/share/fonts/X11/misc/7x13-ISO8859-1.pcf.gz";
//	xFontName = "/usr/X11/share/fonts/X11/75dpi/helvR12-ISO8859-1.pcf.gz";
	xFontName = "/usr/X11/share/fonts/TrueType/liberation/LiberationSans-Regular.ttf";
//	xFontName = "/usr/X11/share/fonts/TrueType/freefont/FreeMono.ttf";
//	xFontName = "/usr/X11/share/fonts/X11/misc/gb16fs.pcf.gz";
//	xFontName = "/usr/X11/share/fonts/X11/misc/gb16st.pcf.gz";		// Song ti

	xf = [NSString stringWithFormat: @"%c-%03d-%s", *xfontWeight, (int)0, xFontName];
	cname = [xf cString];

	if (!(fnti = _CGOpenFont(xFontName, 16)))
		{
		NSLog(@"Unable to open font: %@\n", xf);
		return nil;
		}
	font = (NSFont *)CGFontCreateWithPlatformFont (fnti);

	{
	FT_Face face = fnti->face;
	int i, w, h, xres, yres;
	int a;
	BOOL isBitmap = ((face->face_flags & FT_FACE_FLAG_SCALABLE) == 0);
	PS_FontInfoRec *t1info, t1info_rec;
	int rc;

    rc = FT_Get_PS_Font_Info(face, &t1info_rec);
    if(rc == 0)
        t1info = &t1info_rec;

	for(i = 0; i < face->num_fixed_sizes; i++)
		{
		w = face->available_sizes[i].width;
		h = face->available_sizes[i].height;
		xres = 75;
		yres = (double)h / w * xres;
		a = (int)(h / (double)yres * 72.27 * 10 + 0.5);
		if(isBitmap)
			{
			BDF_PropertyRec prop;
			rc = FT_Get_BDF_Property(face, "FONT", &prop);
			if(rc == 0 && prop.type == BDF_PROPERTY_TYPE_ATOM)
				{
//                    strcpy(xlfd_name, prop.u.atom);
/*
(gdb) print prop
$1 = {type = BDF_PROPERTY_TYPE_ATOM,
u = {atom = 0x8175218 "-Adobe-Helvetica-Medium-R-Normal--12-120-75-75-P-67-ISO8859-1\000"..., 
integer = 135746072, cardinal = 135746072}}
*/
				}
			}
		NSLog(@"Family name %s\n", fnti->face->family_name);
		}
	}

	return font;
}
#endif

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSView *c;
	NSWindow *win;

    NSLog(@"Starting the application\n");

//	[self enumerateFontsAtPath:@"/usr/X11/share/fonts/X11/misc"];
//	[self enumerateFontsAtPath:@"/usr/X11/share/fonts/TTF"];
//	[self enumerateFontsAtPath:@"/usr/X11/lib/X11/fonts/local"];
//	[self enumerateFontsAtPath:@"/usr/X11/lib/X11/fonts/Type1"];
//	[self enumerateFontsAtPath:@"/usr/X11/lib/X11/fonts/75dpi"];

#ifndef __APPLE__
	__font = [self getPlatformFont];
#else
	__font = [[NSFont systemFontOfSize: 16] retain];
#endif

	win = [[NSWindow alloc] initWithContentRect:(NSRect){{100, 100},{300, 300}}
							styleMask:_NSCommonWindowMask
							backing:NSBackingStoreBuffered	
							defer:NO];

    c = [[FontView alloc] initWithFrame: (NSRect){{10, 10}, {200, 200}}];
    [[win contentView] addSubview:c];

	[[win contentView] display];
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
