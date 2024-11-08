/*
   NSFontManager.m

   Font management and selection panel

   Copyright (C) 2006-2016 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    May 2006

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSException.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSError.h>
#include <Foundation/NSSet.h>
#include <Foundation/NSString.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSURL.h>

#include <AppKit/NSFontManager.h>
#include <AppKit/NSFontPanel.h>
#include <AppKit/NSFont.h>
#include <AppKit/NSMatrix.h>
#include <AppKit/NSBrowser.h>
#include <AppKit/NSBrowserCell.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSMenu.h>
#include <AppKit/NSSlider.h>
#include <AppKit/NSTextField.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSNibLoading.h>
#include <AppKit/NSScrollView.h>

#include <CoreText/CTFontManager.h>
#include <CoreGraphics/Private/_CGFont.h>


#define STRINGIFY(x)	@#x
#define FONTPATH(x)		STRINGIFY(x)

												// Font file search paths
NSString *__fontdirs[] = { FONTPATH(FONT_PREFIX/local/fonts.dir),
						   FONTPATH(FONT_PREFIX/TrueType/freefont/fonts.dir),
						   FONTPATH(FONT_PREFIX/TrueType/microsoft/fonts.dir),
						   FONTPATH(FONT_PREFIX/TrueType/liberation/fonts.dir),
						   FONTPATH(FONT_PREFIX/TrueType/dejavu/fonts.dir),
						   FONTPATH(FONT_PREFIX/truetype/freefont/fonts.dir),
						   FONTPATH(FONT_PREFIX/truetype/liberation/fonts.dir),
						   FONTPATH(FONT_PREFIX/truetype/dejavu/fonts.dir),
#ifdef USE_SYS_FREETYPE	   /* embedded FT lib supports only TTF and PCF */
						   FONTPATH(FONT_PREFIX/X11/Type1/fonts.dir),
#endif
						   FONTPATH(FONT_PREFIX/X11/TTF/fonts.dir),
						   FONTPATH(FONT_PREFIX/X11/misc/fonts.dir),
						   FONTPATH(FONT_PREFIX/misc/fonts.dir),
						   FONTPATH(FONT_PREFIX/X11/75dpi/fonts.dir),
						   FONTPATH(FONT_PREFIX/X11/100dpi/fonts.dir), 0 };

// Class variables
static NSFontManager *__sharedFontManager = nil;
static NSMutableArray *__localFonts = nil;
static NSFontPanel *__fontPanel = nil;
static Class __fontManagerClass = Nil;
static Class __fontPanelClass = Nil;



static const char *
_findField (int field, const char *record, char delim)
{
	while (field--)
		for (record++; *record && *record != delim; record++);
		
	return (*record == delim) ? ++record : NULL;
}

static int
_comparePatternToLine(const char *cpat, const char *fpat)
{
	int len, field;

	for (field = 0; field < 14; field++)			// checked pattern cannot
		{											// have NULL fields
		const char *p = _findField(field, cpat, '-');

		if (*p != '*')								// anything matches
			{
			const char *op = _findField(field, fpat, '-');

			if (*p == '\0' || !op || *op == '\0')
				return 1;
			if ((*op == '0' && *(op+1) == '-') || *op == '-' || *op == '*')
				continue;							// anything matches
			len = (field == 13) ? strcspn(op,"\n") : strcspn(op,"-");
			if (len > 80 || strncmp(p, op, len))
				return 1;
		}	}

	return 0;										// patterns match
}

NSString *											// returns absolute path to
_NSFontMatchingPattern(NSString *pat)				// matched font file or nil
{
	NSFileManager *fm = [NSFileManager defaultManager];
	const char *cpat = [pat cString];
	int i;

	for (i = 0; __fontdirs[i]; i++)
		{
		if ([fm fileExistsAtPath:__fontdirs[i]])
			{
			NSString *file = [NSString stringWithContentsOfFile:__fontdirs[i]];
			const char *cname = [file cString];
			const char *filename, *fpat, *base = cname;
			NSRange range;

			while (*cname)							// search a fonts.dir file
				{
				for (;*cname && *cname != '\n'; cname++);	// find filename
				filename = ++cname;
				range.location = filename - base;
				for (;*cname && *cname != ' '; cname++);	// find pattern col
				fpat = ++cname;

				if (*cname && !_comparePatternToLine(cpat, fpat))
					{
					const char *fe = filename;
					NSString *nfile = [__fontdirs[i] stringByDeletingLastPathComponent];

					for (;*fe && *fe != ' '; fe++);		// find filename end
					range.length = fe-filename;

					return [nfile stringByAppendingPathComponent: [file substringWithRange: range]];
		}	}	}	}

	if (__localFonts)
		{
		NSEnumerator *e = [__localFonts objectEnumerator];
		NSArray *fo;

		while ((fo = [e nextObject]) != nil)
			{
			const char *fpat = [[fo objectAtIndex: 0] cString];

			if (!_comparePatternToLine(cpat, fpat))
				return [fo objectAtIndex: 1];
			}
		}

	return nil;
}

static NSString *
_fontFaceName(const char *pat, const char *slant)
{
	char buf[48] = {0};
	int i;

	if (*slant == 'i')
		return (!strncmp("bold", pat, 4)) ? @"bold italic" : @"italic";
	if (*slant == 'o')
		return (!strncmp("bold", pat, 4)) ? @"bold oblique" : @"oblique";
	if (!strncmp("medium", pat, 6))
		return @"medium";

	for (i = 0; *pat != '-' && *pat != '\0' && i < sizeof(buf);)
		buf[i++] = *pat++;

	if (*slant == 'i')
		return [NSString stringWithFormat: @"%s italic", buf];
	if (*slant == 'o')
		return [NSString stringWithFormat: @"%s oblique", buf];

	return [NSString stringWithFormat: @"%s", buf];
}

static NSArray *
_fontsMatching (unsigned int field, NSString *pat, NSString *fontsfile)
{
	NSMutableSet *files = nil;
	NSString *file = [NSString stringWithContentsOfFile: fontsfile];
	const char *cname = [file cString];
	const char *base = cname;
	const char *fpat = [pat cString];
	const char *cpat = [[NSString stringWithFormat: pat, @"*"] cString];
	int initial = 1;

	for (;*cname && *cname != '\n'; cname++);
	while (*cname)									// search a fonts.dir file
		{
		for (++cname; *cname && *cname != ' ' && *cname != '\n'; cname++);
		if (*cname)
			fpat = ++cname;								// find pattern col
		
		if (*cname && (_comparePatternToLine(cpat, fpat) != initial))
			{
			const char *fs, *fe = fpat;
			NSString *fam;
			NSRange range;
			int i = field;

			while (i--)
				for (fe++; *fe && *fe != '-'; fe++);	// find field start
			fs = ++fe;
			range.location = fs - base;
			for (;*fe && *fe != '-'; fe++);				// find field end
			range.length = fe - fs;

			if (!files)
				files = [NSMutableSet new];

			if (field == 2)
				[files addObject: _fontFaceName(fs, (fe+1))];
			else
				[files addObject: (fam = [file substringWithRange: range])];
if (field == 1)
			cpat = [[NSString stringWithFormat: pat, fam] cString];
			}

if (field == 1)
		initial = 0;
		for (;*cname && *cname != '\n'; cname++);
		}

	return (files) ? [files allObjects] : nil;
}

/* ****************************************************************************

		NSFontManager

** ***************************************************************************/

@implementation NSFontManager

+ (void) setFontManagerFactory:(Class)class		{ __fontManagerClass = class; }
+ (void) setFontPanelFactory:(Class)class		{ __fontPanelClass = class; }

+ (NSFontManager *) sharedFontManager
{
	if (!__sharedFontManager)
		{
		if (!__fontManagerClass)
			__fontManagerClass = self;
		__sharedFontManager = [__fontManagerClass new];
		}

	return __sharedFontManager;
}

- (id) init
{
	if ((self = [super init]))
		{
		if (!__fontPanelClass)
			__fontPanelClass = [NSFontPanel class];
		_action = @selector(changeFont:);
		}
	
	return self;
}

- (void) orderFrontFontPanel:(id)sender
{
	_target = sender;
	[[NSFontPanel sharedFontPanel] display];
	[[NSFontPanel sharedFontPanel] orderFront:sender];
}

- (NSFont *) convertFont:(NSFont *)font
{
	switch (_fm.senderTagMode)					// FIX ME incomplete actions
		{
		case NSViaPanelFontAction:
			return [__fontPanel panelConvertFont: font];
		case NSSizeUpFontAction:
		case NSSizeDownFontAction:
			return [self convertFont:font toSize: [_selectedFont pointSize]];
		case NSNoFontChangeAction:
			break;
		}

	return font;
}

- (NSFont *) convertFont:(NSFont *)font toFamily:(NSString *)family
{
	return nil;
}

- (NSFont *) convertFont:(NSFont *)font toFace:(NSString *)typeface
{
	return nil;
}

- (NSFont *) convertFont:(NSFont *)font toHaveTrait:(NSFontTraitMask)trait
{
	return nil;	
}

- (NSFont *) convertFont:(NSFont *)font toNotHaveTrait:(NSFontTraitMask)trait
{
	const char *p = [((CGFont *)font)->_descriptor cString];
	const char *weight = "medium";
	const CGFloat *matrix = [font matrix];
	int size = (int)matrix[0];
	NSString *cf = nil;
	NSString *mf = nil;
	CGFont *nf = NULL;		// FIX ME incomplete, only handles glyph width trait
							// FIX ME common CJK widths 160, 180, 240
	if (trait & NSNarrowFontMask)
		{
//		NSLog(@"** sub for pattern: %s\n", p);
		if (!strstr(p, "courier") || !strstr(p, "fixed"))
			cf = @"-misc-fixed-medium-r-*-*-*-120-*-*-c-120-iso10646-1";
		else
			cf = @"-*-*-medium-r-*-*-*-120-*-*-*-*-iso10646-1";
		}

	if (cf && (mf = _NSFontMatchingPattern(cf)))
		if ((nf = (CGFont *)_NSFontFind(mf, weight, size)) && !nf->_name)
			{
			nf->_name = [font copy];			// set font attr's
			nf->_descriptor = [cf retain];
			memcpy (nf->_matrix, matrix, sizeof(nf->_matrix));
			}

	return (NSFont *)nf;
}

- (NSFont *) convertFont:(NSFont *)font toSize:(float)size
{
	return nil;
}

- (NSFont *) convertWeight:(BOOL)upFlag ofFont:(NSFont *)fontObject
{
	return nil;	
}

- (NSFont *) fontWithFamily:(NSString *)family
					 traits:(NSFontTraitMask)traits
					 weight:(int)weight			// 0-15 hint, 5 normal, 9 bold
					 size:(float)size
{
	NSString *w = (traits & NSBoldFontMask || weight >= 9) ? @"bold" : @"medium";
	NSString *ff;

	if (traits & NSItalicFontMask)
		ff = [NSString stringWithFormat: @"%@-%@ italic", family, w];
	else
		ff = [NSString stringWithFormat: @"%@-%@", family, w];

	return [NSFont fontWithName:ff size:size];
}

- (NSFontPanel *) fontPanel:(BOOL)create
{
	return (!__fontPanel) && (create) ? [__fontPanelClass new] : __fontPanel;
}

- (NSMenu *) fontMenu:(BOOL)create
{
	return (!_fontMenu) && (create) ? _fontMenu = [[NSMenu new] retain] : _fontMenu;
}

- (NSArray *) availableFonts
{
	if (!_availableFonts)							// FIX ME not implmented
		_availableFonts = [NSMutableArray array];

	return _availableFonts;
}

- (void) setFontMenu:(NSMenu *)newMenu			{ ASSIGN(_fontMenu, newMenu); }
- (BOOL) isEnabled								{ return _fm.isEnabled; }
- (BOOL) isMultiple								{ return _fm.multipleFont; }
- (void) setEnabled:(BOOL)flag					{ _fm.isEnabled = flag; }
- (void) setAction:(SEL)aSelector				{ _action = aSelector; }
- (SEL) action									{ return _action; }
- (int) weightOfFont:(NSFont *)f				{ return 0; }
- (NSFont *) selectedFont						{ return _selectedFont; }

- (void) setSelectedFont:(NSFont *)font isMultiple:(BOOL)flag
{								// not to be called during changeFont: handling
	_selectedFont = font;
	_fm.multipleFont = flag;
	[__fontPanel setPanelFont:font isMultiple:flag];
}

- (NSFontTraitMask) traitsOfFont:(NSFont *)font
{
	return (NSFontTraitMask)0;
}

- (BOOL) sendAction
{
	if (!_target)
		_target = [NSApp targetForAction:_action];

	return [NSApp sendAction:_action to:_target from:self];
}

- (void) modifyFont:(id)sender
{
	_fm.senderTagMode = (NSFontAction) [sender tag];
	[self sendAction];						// send action thru responder chain
}

- (void) modifyFontViaPanel:(id)sender
{
	_fm.senderTagMode = NSViaPanelFontAction;
	[self sendAction];
}

@end  /* NSFontManager */

/* ****************************************************************************

		NSFontPanel

** ***************************************************************************/

@implementation NSFontPanel

+ (NSFontPanel *) sharedFontPanel
{	
	if ((!__fontPanel) && ![GMModel loadMibFile:@"FontPanel" owner:NSApp]) 
		[NSException raise: NSInternalInconsistencyException 
					 format: @"Unable to open font panel mib model file."];

    return __fontPanel;
}

+ (id) alloc
{ 
	return __fontPanel ? __fontPanel
					   : (__fontPanel = (NSFontPanel *)NSAllocateObject(self));
}

- (void) setPanelFont:(NSFont *)fontObject isMultiple:(BOOL)flag
{
	[_fontDemo setFont: fontObject];
	[_fontDescription setStringValue: [fontObject fontName]];
}

- (NSFont *) panelConvertFont:(NSFont *)fontObject
{												// convert font per current
	NSFont *f = [_fontDemo font];				// state of panel

//	f = [__sharedFontManager convertFont:fontObject toFamily:[f familyName]];

	return (f) ? f : fontObject;
}

- (NSView *) accessoryView							{ return nil; }
- (BOOL) isEnabled									{ return NO; }
- (BOOL) worksWhenModal								{ return NO; }
- (void) setAccessoryView:(NSView *)aView			{}
- (void) setEnabled:(BOOL)flag						{}

@end  /* NSFontPanel */


@implementation NSFontPanel (FontPanelDelegate)

- (void) browser:(NSBrowser*)sender 				// browser delegate
		 createRowsForColumn:(int)column
		 inMatrix:(NSMatrix*)matrix
{
	id cell;
	NSArray *files = nil;
	NSString *s;
	int i, j, count;

	if (column == 0)
		{
		NSFileManager *fm = [NSFileManager defaultManager];

		for (i = 0; __fontdirs[i]; i++);

		[matrix renewRows:i columns:1];				// create necessary cells

		for (i = 0, j = 0; __fontdirs[i]; i++)
			{
			if ([fm fileExistsAtPath:__fontdirs[i]])
				{
				NSString *n = [__fontdirs[i] stringByDeletingLastPathComponent];
				id cell = [matrix cellAtRow:j++ column:0];

				[cell setStringValue: [n lastPathComponent]];
				[cell setTag: i];
				}
			}

		[matrix renewRows:j columns:1];				// create necessary cells
		[matrix sizeToCells];

		return;
		}

	cell = [sender selectedCellInColumn: 0];
	s = __fontdirs[[cell tag]];

	if (column == 1)
		{
		files = _fontsMatching(1, @"-*-%@-*-*-*-*-*-*-*-*-*-*-*-*", s);
			
		NSLog(@"createRowsForColumn  ********* 1");
		}

	if (column == 2)
		{
		NSString *fmt = @"-*-%@-%s-*-*-*-*-*-*-*-*-*-*-*";
		NSFont *font;

		if (!(cell = [sender selectedCellInColumn: 1]))
			return;

		fmt = [NSString stringWithFormat: fmt, [cell stringValue], "%@"];
		files = _fontsMatching(2, fmt, s);
			
		NSLog(@"createRowsForColumn  ********* 2");
			
		font = [NSFont fontWithName:[cell stringValue] size:[_fontSize intValue]];
		[self setPanelFont:font isMultiple:NO];
		[__sharedFontManager modifyFontViaPanel: self];
		}

	if (column == 3)
		{
		NSString *fmt = @"-*-%@-%@-%s-*-*-*-*-*-*-*-*-*-*";
		NSFont *font;
		NSString *fam = [[sender selectedCellInColumn: 1] stringValue];

		cell = [sender selectedCellInColumn: 2];
		fmt = [NSString stringWithFormat: fmt, fam, [cell stringValue], "%@"];
		NSLog(@"createRowsForColumn  match ********* '%@'", fmt);
		files = _fontsMatching(3, fmt, s);
			
		NSLog(@"createRowsForColumn  ********* 3");

		fmt = [NSString stringWithFormat: @"%@-%@", fam, [cell stringValue]];
		font = [NSFont fontWithName:fmt size:[_fontSize intValue]];
		[self setPanelFont:font isMultiple:NO];
		[__sharedFontManager modifyFontViaPanel: self];
		}

	if (!files)
		return;
	count = [files count];
	[matrix renewRows:count columns:1];				// create necessary cells
	[matrix sizeToCells];

	if (count == 0)
		return;

    for (i = 0; i < count; ++i) 
		{
		cell = [matrix cellAtRow: i column: 0];
		[cell setStringValue: [files objectAtIndex: i]];
		}
}

- (void) _setPanelFont:(id)sender
{
	NSFont *f = [NSFont fontWithName: [_fontDescription stringValue]
								size: [_fontSize intValue]];

	[self setPanelFont:f isMultiple:NO];
	[self update];
}

- (void) _setPanelFontSize:(id)sender
{
	[_fontSize setIntValue: MAX(8, 28 * [sender floatValue])];
	[self _setPanelFont: sender];
}

@end  /* NSFontPanel (FontPanelDelegate) */


@interface _NSFontBrowser     : NSBrowser		@end
@interface _NSFontBrowserCell : NSBrowserCell
{
	int tag;
}
@end


@implementation _NSFontBrowserCell

- (void) setTag:(int)anInt				{ tag = anInt; }
- (int) tag								{ return tag; }
- (BOOL) isLeaf							{ return NO; }

@end  /* _NSFontBrowserCell */


@implementation _NSFontBrowser

+ (Class) cellClass						{ return [_NSFontBrowserCell class]; }

- (void) scrollColumnToVisible:(int)column		{}
- (void) scrollColumnsRightBy:(int)shiftAmount	{}

- (void) addColumn
{
	if ([_columns count] < 3)
		{
		NSScrollView *sc;

		[super addColumn];

		sc = [_columns lastObject];
		[[sc verticalScroller] setArrowsPosition: NSScrollerArrowsNone];
		[sc setVerticalScrollElasticity: NSScrollElasticityNone];
		}
}

- (void) reloadColumn:(int)column
{
	if (column < 3)
		[super reloadColumn: column];
	else
		[_delegate browser:self createRowsForColumn:3 inMatrix:nil];
}

- (void) doClick:(id)sender					// handle a single click in a cell
{
	[super doClick: sender];
	[[self window] update];
}

@end  /* _NSFontBrowser */


BOOL CTFontManagerRegisterFontsForURL( CFURLRef fontURL,
									   CTFontManagerScope scope,
									   CFErrorRef *error )
{
	NSString *cf = [(NSURL *)fontURL lastPathComponent];
	NSString *FontName = [[cf stringByDeletingPathExtension] lowercaseString];
	NSArray *lf;

	if (error)
		{
		NSFileManager *fm = [NSFileManager defaultManager];

		if (![fm fileExistsAtPath: [(NSURL *)fontURL path]])
			{
			*error = (CFErrorRef)_NSError(nil, -1, @"bad font path");

			return NO;
		}	}

	cf = [NSString stringWithFormat: @"-*-%@-*-*-*-*-*-*-*-*-*-*-*-*", FontName];
	lf = [NSArray arrayWithObjects: cf, [(NSURL *)fontURL path], nil];

	if (!__localFonts)
		__localFonts = [NSMutableArray array];
	[__localFonts addObject: lf];

	return YES;
}

BOOL CTFontManagerUnregisterFontsForURL( CFURLRef fontURL,
										 CTFontManagerScope scope,
										 CFErrorRef *error )
{
	return YES;
}

CGFontRef
CTFontCreateForString( CGFontRef f, CFStringRef string, CFRange r)
{
	CFString *s = (CFString *)string;
	unichar ch = (s && s->_uniChars) ? s->_uniChars[r.location] : 0;
	NSFont *nf = nil;	// FIX ME incomplete, should detect unicode range and
						// try to select best font, this works for basic CJK
	if (ch >= 0x2E80)
		nf = [[NSFontManager sharedFontManager] convertFont:(NSFont *)f
											 toNotHaveTrait:NSNarrowFontMask];
	return (CGFontRef)nf;
}
