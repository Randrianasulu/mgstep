/*
   MKeyedArchiving.m

   NSKeyedArchiver coding without changes to existing classes

   Copyright (C) 2006-2016 Free Software Foundation, Inc.

   Dr. H. Nikolaus Schaller <hns@computer.org>
   Date: Jan 2006

   mGSTEP:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	October 2009

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSData.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSScanner.h>
#include <Foundation/NSException.h>
#include <Foundation/NSKeyedArchiver.h>
#include <Foundation/NSPropertyList.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSXMLParser.h>
#include <Foundation/NSNull.h>
#include <Foundation/NSSet.h>
#include <Foundation/NSFormatter.h>

#include <AppKit/AppKit.h>



@implementation NSObject  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)unarchiver
{
	return [self initWithCoder: unarchiver];
}

@end


@implementation NSArray  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
#if 0
	NSLog(@"%@ initWithKeyedCoder", NSStringFromClass([self class]));
#endif
	[self release];

	return [[aDecoder decodeObjectForKey:@"NS.objects"] retain];
}

@end


@implementation NSDictionary  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
#if 0
	NSLog(@"%@ initWithKeyedCoder", NSStringFromClass([self class]));
#endif
	[self release];

	NSArray *objs = [aDecoder decodeObjectForKey:@"NS.objects"];
	NSArray *keys = [aDecoder decodeObjectForKey:@"NS.keys"];

	return [self initWithObjects:objs forKeys:keys];
}

@end

/*
	NS.positiveformat,
	NS.negativeattrs,
	NS.nan,
	NS.decimal,
	NS.thousand,
	NS.max,
	NS.rounding,
	NS.localized,
	NS.min,
	NS.positiveattrs,
	NS.nil,
	NS.negativeformat,
	NS.zero,
	NS.hasthousands,
	NS.allowsfloats,
	NS.attributes
	) in {
		$class = "NSCFType (64)";
		NS.allowsfloats = 1;
		NS.attributes = "NSCFType (212)";
		NS.decimal = "NSCFType (232)";
		NS.hasthousands = 0;
		NS.localized = 0;
		NS.max = "NSCFType (235)";
		NS.min = "NSCFType (227)";
		NS.nan = "NSCFType (236)";
		NS.negativeattrs = "NSCFType (0)";
		NS.negativeformat = "NSCFType (233)";
		NS.nil = "NSCFType (234)";
		NS.positiveattrs = "NSCFType (0)";
		NS.positiveformat = "NSCFType (228)";
		NS.rounding = "NSCFType (0)";
		NS.thousand = "NSCFType (226)";
		NS.zero = "NSCFType (230)";
	}
*/

@implementation NSNumberFormatter  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
#if 0
	NSLog(@"%@ initWithKeyedCoder", NSStringFromClass([self class]));
#endif
	[self release];

	return [[aDecoder decodeObjectForKey:@"NS.objects"] retain];
}

@end

@implementation NSString  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
#if 0
	NSLog(@"%@ initWithKeyedCoder", NSStringFromClass([self class]));
#endif
	[self release];

	return [[aDecoder decodeObjectForKey:@"NS.string"] retain];
//	return [[aCoder decodeObjectForKey:@"NS.string"] mutableCopy];
}

@end


@implementation NSSet  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
#if 0
	NSLog(@"%@ initWithKeyedCoder", NSStringFromClass([self class]));
#endif
	return [self initWithArray:[aDecoder decodeObjectForKey:@"NS.objects"]];
}

@end

/* ****************************************************************************

	AppKit

** ***************************************************************************/

@interface NSResponder  (KeyedArchivingMethods)
- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder;
@end

@implementation NSResponder  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
	_nextResponder = [[aDecoder decodeObjectForKey:@"NSNextResponder"] retain];
//	_menu = [[aDecoder decodeObjectForKey:@"NSMenu"] retain];
	return self;
}

@end /* NSResponder (KeyedArchivingMethods) */


@interface NSView  (KeyedArchivingPrivateMethods)
- (void) _frameChanged;
@end

@implementation NSView  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{ // initialize, then subviews and finally superview
	unsigned int viewflags=[aDecoder decodeIntForKey:@"NSvFlags"];
#if 0
	NSLog(@"viewflags=%08x", viewflags);
//		NSLog(@"self=%@", self);
#endif
	if([aDecoder containsValueForKey:@"NSFrameSize"])
		self=[self initWithFrame:(NSRect){NSZeroPoint, [aDecoder decodeSizeForKey:@"NSFrameSize"]}];
	else
		self=[self initWithFrame:[aDecoder decodeRectForKey:@"NSFrame"]];
#if 0
	NSLog(@"initwithframe done");
	NSLog(@"self=%@", self);
#endif
///	self=[super initWithCoder:aDecoder];	// decode attributes defined by NSResponder
	self=[super _initWithKeyedCoder:aDecoder];	// decode attributes defined by NSResponder
#if 0
	NSLog(@"super initwithcoder done");
	NSLog(@"self=%@", self);
		NSLog(@"2. viewflags=%x", [aDecoder decodeIntForKey:@"NSvFlags"]);
#endif
	
#define RESIZINGMASK ((viewflags>>0) & 0x3f)	// 6 bit
	_v.autoresizingMask=RESIZINGMASK;
#if 0
	NSLog(@"%@ autoresizingMask=%02x", self, _v.autoresizingMask);
#endif
#define RESIZESUBVIEWS (((viewflags>>8)&1) != 0)
	_v.autoSizeSubviews=RESIZESUBVIEWS;
#if 0
	if(_v.autoresizingMask != 0 && !_v.autoSizeSubviews)
		NSLog(@"viewflags=%x viewflags>>8=%x (viewflags>>8)&1=%u autoresizesSubviews=NO and mask=%x: %@", viewflags, viewflags>>8, (viewflags>>8)&1, _v.autoresizingMask, self);
#endif
#define HIDDEN (((viewflags>>31)&1)!=0)
	_v.hidden=HIDDEN;

	// how to overwrite NSBounds? - does this occur anywhere?

///	if([aDecoder containsValueForKey:@"NSDragTypes"])		// produces a MutableSet not an Array
////		[self registerForDraggedTypes:[aDecoder decodeObjectForKey:@"NSDragTypes"]];
	_nextKeyView = [[aDecoder decodeObjectForKey:@"NSNextKeyView"] retain];
#if 1
	if([[aDecoder decodeObjectForKey:@"NSWindow"] isEqual:@"$null"])
		{
		NSLog(@"NSWindow $null!!! %@", aDecoder);
		}
#endif
//	[self _setWindow:[aDecoder decodeObjectForKey:@"NSWindow"]];
//		_window=[aDecoder decodeObjectForKey:@"NSWindow"];	// set new window before processing siblings - unless we are tearing down
	[self viewWillMoveToWindow:[aDecoder decodeObjectForKey:@"NSWindow"]];
		[self _frameChanged];	// FIX ME needed ???

#if 0
	NSLog(@"%@ initWithCoder:%@", self, aDecoder);
	NSLog(@"  NSvFlags=%08x", [aDecoder decodeIntForKey:@"NSvFlags"]);
#endif
		{ // this may recursively initialize ourselves
		NSArray *svs=[aDecoder decodeObjectForKey:@"NSSubviews"];	// decode subviews - and connect them to us
		NSEnumerator *e=[svs objectEnumerator];
		NSView *sv;
#if 0
		NSLog(@"subviews=%@", svs);
#endif
		while((sv=[e nextObject]))
			{
			if(![sv isKindOfClass:[NSView class]])
				NSLog(@"%@: subview is not derived from NSView: %@", self, sv);
			else
				[self addSubview:sv];	// and add us as the superview
			}
		}
	[aDecoder decodeObjectForKey:@"NSSuperview"];	// finally load superview (if not yet by somebody else)
#if 0
	NSLog(@"superview=%@", [aDecoder decodeObjectForKey:@"NSSuperview"]);
#endif
	[self setNeedsDisplay:YES];

	return self;
}

@end /* NSView (KeyedArchivingMethods) */


@implementation NSControl  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
	self = [super _initWithKeyedCoder:aDecoder];
	
	_cell = [[aDecoder decodeObjectForKey:@"NSCell"] retain];
	[self setTag:[aDecoder decodeIntForKey:@"NSTag"]];	// might be different from cell's tag
	if([aDecoder containsValueForKey:@"NSTarget"])	// cell might not understand!
		[self setTarget:[aDecoder decodeObjectForKey:@"NSTarget"]];
	if([aDecoder containsValueForKey:@"NSAction"])
		[self setAction:NSSelectorFromString([aDecoder decodeObjectForKey:@"NSAction"])];
	if([aDecoder containsValueForKey:@"NSFont"])	// cell might not understand!
		[self setFont:[aDecoder decodeObjectForKey:@"NSFont"]];
	// FIXME: this appears to be broken or at least inconsistent...
	if([aDecoder containsValueForKey:@"NSEnabled"])
		{
	#if 0
		NSLog(@"NSControl initWithCoder %@", self);
		NSLog(@"[self isEnabled]=%@", [self isEnabled]?@"YES":@"NO");
		NSLog(@"NSEnabled=%@", [aDecoder decodeBoolForKey:@"NSEnabled"]?@"YES":@"NO");
	#endif
		[self setEnabled:[aDecoder decodeBoolForKey:@"NSEnabled"]];	// enable/disable current cell (unless setEnabled is overwritten)
		}

	return self;
}

@end /* NSControl (KeyedArchivingMethods) */


@implementation NSMatrix  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
	self = [super _initWithKeyedCoder:aDecoder];

	unsigned int matrixflags=[aDecoder decodeIntForKey:@"NSMatrixFlags"];
	
#define HIGHLIGHTMODE	((matrixflags&0x80000000) != 0)
#define RADIOMODE	((matrixflags&0x40000000) != 0)
#define LISTMODE	((matrixflags&0x20000000) != 0)
#define MODE	HIGHLIGHTMODE?NSHighlightModeMatrix:(RADIOMODE?NSRadioModeMatrix:(LISTMODE?NSListModeMatrix:NSTrackModeMatrix))
	_m.mode=MODE;
#define EMPTYSEL	((matrixflags&0x10000000) != 0)
	_m.allowsEmptySelect=EMPTYSEL;
#define AUTOSCROLL	((matrixflags&0x08000000) != 0)
	_m.autoscroll=AUTOSCROLL;
#define SELRECT	((matrixflags&0x04000000) != 0)
	_m.selectionByRect=SELRECT;
#define CELLBACKGROUND	((matrixflags&0x02000000) != 0)
	_m.drawsCellBackground=CELLBACKGROUND;
#define BACKGROUND	((matrixflags&0x01000000) != 0)
	_m.drawsBackground=BACKGROUND;
#define AUTOSIZE	((matrixflags&0x00800000) != 0)
	_m.autosizesCells=AUTOSIZE;
	
	_backgroundColor = [[aDecoder decodeObjectForKey:@"NSBackgroundColor"] retain];
#if 0
	NSLog(@"NSMatrix initWithCoder backgroundColor=%@", _backgroundColor);
#endif
	_cellBackgroundColor = [[aDecoder decodeObjectForKey:@"NSCellBackgroundColor"] retain];
	_cells = [[aDecoder decodeObjectForKey:@"NSCells"] retain];
	_cellClass = NSClassFromString([aDecoder decodeObjectForKey:@"NSCellClass"]);
	_cellSize = [aDecoder decodeSizeForKey:@"NSCellSize"];
	_interCell = [aDecoder decodeSizeForKey:@"NSIntercellSpacing"];
	_numCols = [aDecoder decodeIntForKey:@"NSNumCols"];
	_numRows = [aDecoder decodeIntForKey:@"NSNumRows"];
	if (_numRows && _numCols)
		[self renewRows:_numRows columns:_numCols];
	_cellPrototype = [[aDecoder decodeObjectForKey:@"NSProtoCell"] retain];
		// FIXME: I have seen the case that there is only a NSSelectedRow and a NSSelectedCell but no NSSelectedCol
	if([aDecoder containsValueForKey:@"NSSelectedRow"] || [aDecoder containsValueForKey:@"NSSelectedCol"])
		[self selectCellAtRow:[aDecoder decodeIntForKey:@"NSSelectedRow"] column:[aDecoder decodeIntForKey:@"NSSelectedCol"]];
	if([aDecoder containsValueForKey:@"NSSelectedCell"])
		[self selectCell:[aDecoder decodeObjectForKey:@"NSSelectedCell"]];
#if 0
	NSLog(@"%@ initWithCoder:%@", self, aDecoder]);
#endif
	return self;
}

@end /* NSMatrix (KeyedArchivingMethods) */


@interface NSBox  (KeyedArchivingPrivateMethods)
- (NSRect) _calcSizes;
@end

@implementation NSBox  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
	self = [super _initWithKeyedCoder:aDecoder];

	_offsets = [aDecoder decodeSizeForKey:@"NSOffsets"];
	_bx.borderType = [aDecoder decodeIntForKey:@"NSBorderType"];
///	_bx.boxType = [aDecoder decodeIntForKey:@"NSBoxType"];
	_bx.titlePosition = [aDecoder decodeIntForKey:@"NSTitlePosition"];
	_bx.transparent=[aDecoder decodeBoolForKey:@"NSTransparent"];
#if 0
	NSLog(@"offsets=%@", NSStringFromSize(_offsets));
	NSLog(@"borderType=%d", _bx.borderType);
	NSLog(@"boxType=%d", _bx.boxType);
	NSLog(@"titlePosition=%d", _bx.titlePosition);
	NSLog(@"transparent=%d", _bx.transparent);
#endif
	[self setContentView:[aDecoder decodeObjectForKey:@"NSContentView"]];		// decode and insert
	_titleCell = [[aDecoder decodeObjectForKey:@"NSTitleCell"] retain];
	[_titleCell setDrawsBackground: YES];		// FIX ME background s/b NIB set
//	[_titleCell setBackgroundColor: [_window backgroundColor]];
#if 0
	NSLog(@"_contentView=%@", [_contentView _subtreeDescription]);
#endif		
///	[self _calcSizes];	// recalculate _titleRect with latest _titleCell
	_bx.needsTile = YES;

	return self;
}

@end /* NSBox (KeyedArchivingMethods) */


@implementation NSTextField  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
	return [super _initWithKeyedCoder:aDecoder];
}

@end /* NSTextField (KeyedArchivingMethods) */


@interface NSCell  (KeyedArchivingMethods)
- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder;
@end /* NSCell (KeyedArchivingMethods) */

@implementation NSCell  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
	self=[self init];

	long cellflags=[aDecoder decodeInt32ForKey:@"NSCellFlags"];
	long cellflags2=[aDecoder decodeInt32ForKey:@"NSCellFlags2"];
	
#define STATE ((cellflags&0x80000000)!=0)
	_c.state=STATE;
#define HIGHLIGHTED ((cellflags&0x40000000)!=0)
	_c.highlighted=HIGHLIGHTED;
#define ENABLED ((cellflags&0x20000000)==0)		// or NSEnabled???
	_c.enabled=ENABLED;
#define EDITABLE ((cellflags&0x10000000)!=0)
	_c.editable=EDITABLE;
#define CELLTYPE ((cellflags&0x0c000000)>>26)
	_c.type=CELLTYPE;
#define CBORDERED ((cellflags&0x00800000)!=0)
	_c.bordered=CBORDERED;
#define BEZELED ((cellflags&0x00400000)!=0)
	_c.bezeled=BEZELED;
#define SELECTABLE ((cellflags&0x00200000)!=0)
	_c.selectable=SELECTABLE;
#define SCROLLABLE ((cellflags&0x00100000)!=0)
	_c.scrollable=SCROLLABLE;
#define ACTDOWN ((cellflags&0x00040000)!=0)
	_c.actOnMouseDown=ACTDOWN;
#define LEAF ((cellflags&0x00020000)!=0)
///	_d.isLeaf=LEAF;
#define LINEBREAKMODE ((cellflags&0x00007000)>>12)
///	[self setLineBreakMode:LINEBREAKMODE];
#define ACTDRAG ((cellflags&0x00000100)!=0)
	_c.actOnMouseDragged=ACTDRAG;
#define LOADED ((cellflags&0x00000080)!=0)
///	_d.isLoaded=LOADED;
#define ACTUP ((cellflags&0x00000020)==0)
///	_c.actOnMouseUp=ACTUP;
#define SHOWSFIRSTRESPONDER ((cellflags&0x00000004)!=0)
	_c.showsFirstResponder=SHOWSFIRSTRESPONDER;
///#define CONTINUOUS ((cellflags&0x00080000)!=0)
#define CONTINUOUS ((cellflags&0x00080000)!=0 || (ACTDOWN && ACTDRAG))
	_c.continuous=CONTINUOUS;
#define FOCUSRINGTYPE ((cellflags&0x00000003)>>0)
///	_d.focusRingType=FOCUSRINGTYPE;
	
#define ALLOWSEDITINGTEXTATTRIBS ((cellflags2&0x20000000)!=0)
///	_d.allowsEditingTextAttributes=ALLOWSEDITINGTEXTATTRIBS;
#define IMPORTSGRAPHICS ((cellflags2&0x10000000)!=0)	// does not match bitfield definitions but works
///	_d.importsGraphics=IMPORTSGRAPHICS;
#define ALIGNMENT ((cellflags2&0x1c000000)>>26)
	[self setAlignment:ALIGNMENT];
///#define REFUSESFIRSTRESPONDER ((cellflags2&0x00010000)!=0)
#define REFUSESFIRSTRESPONDER	((cellflags2 & 0x02000000) != 0)
	_c.refusesFirstResponder=REFUSESFIRSTRESPONDER;
#define ALLOWSUNDO ((cellflags2&0x00004000)==0)
///	_d.allowsUndo=ALLOWSUNDO;
#define ALLOWSMIXEDSTATE ((cellflags2&0x01000000)!=0)
///	_c.allowsMixed=ALLOWSMIXEDSTATE;
#define MIXEDSTATE ((cellflags2&0x00000800)!=0)
///	if(_c.allowsMixed && MIXEDSTATE) _c.state=NSMixedState;	// overwrite state
#define SENDSACTIONONEDITING ((cellflags2&0x00000400)!=0)
///	_d.sendsActionOnEndEditing=SENDSACTIONONEDITING;
#define CONTROLTINT ((cellflags2&0x000000e0)>>5)
///	_d.controlTint=CONTROLTINT;
#if HOWITSHOULDBE
#define CONTROLSIZE ((cellflags2&0x00000018)>>3)
///	_d.controlSize=CONTROLSIZE;
#endif
#ifndef HOWITWORKS
#define CONTROLSIZE ((cellflags2&0x000e0000)>>17)
///	_d.controlSize=CONTROLSIZE;
#endif
	_c.drawsBackground = [aDecoder decodeBoolForKey:@"NSDrawsBackground"];
	
	// _c.imagePosition=?	// defined for/by ButtonCell
	// _c.entryType=?;
///	if([aDecoder containsValueForKey:@"NSScale"])
///		_d.imageScaling=[aDecoder decodeIntForKey:@"NSScale"];	// NSButtonCell
///	else
///		_d.imageScaling=NSScaleNone;
	
///	[self setFont:[aDecoder decodeObjectForKey:@"NSSupport"]];		// font
///	_menu=[[aDecoder decodeObjectForKey:@"NSMenu"] retain];
///	if([aDecoder containsValueForKey:@"NSTextColor"])
///		[self _setTextColor:[aDecoder decodeObjectForKey:@"NSTextColor"]];
	_formatter=[[aDecoder decodeObjectForKey:@"NSFormatter"] retain];
	if([aDecoder containsValueForKey:@"NSState"])
		_c.state = [aDecoder decodeIntForKey:@"NSState"];	// overwrite state
	if([aDecoder containsValueForKey:@"NSContents"])
		[self setTitle:[aDecoder decodeObjectForKey:@"NSContents"]];		// define sets title for buttons and stringValue for standard cells
	[aDecoder decodeObjectForKey:@"NSAccessibilityOverriddenAttributes"];	// just reference - should save and merge with superclass
	_controlView=[aDecoder decodeObjectForKey:@"NSControlView"];		// might be a class-swapped object!
#if 0
	NSLog(@"%@ initWithCoder:%@", self, aDecoder);
	NSLog(@"  NSCellFlags=%08x", [aDecoder decodeIntForKey:@"NSCellFlags"]);
	NSLog(@"  NSCellFlags2=%08x", [aDecoder decodeIntForKey:@"NSCellFlags2"]);
	NSLog(@"  textColor=%@", _textColor);
	NSLog(@"  drawsbackground=%d", _c.drawsBackground);
	NSLog(@"  alignment=%d", _c.alignment);
	NSLog(@"  state=%d", _c.state);
	NSLog(@"  contents=%@", _contents);
#endif

	return self;
}

@end /* NSCell (KeyedArchivingMethods) */


@implementation NSActionCell  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
	self = [super _initWithKeyedCoder:aDecoder];

	tag = [aDecoder decodeIntForKey:@"NSTag"];
#if 0
	NSLog(@"NSActionCell - tag=%d", tag);
#endif
	target = [[aDecoder decodeObjectForKey:@"NSTarget"] retain];
	action = NSSelectorFromString([aDecoder decodeObjectForKey:@"NSAction"]);

	return self;
}

@end /* NSActionCell (KeyedArchivingMethods) */


@implementation NSTextFieldCell  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
	self = [super _initWithKeyedCoder:aDecoder];
		// done in NSCell:	_c.drawsBackground = [aDecoder decodeBoolObjectForKey:@"NSDrawsBackground"];
		[self setTextColor:[aDecoder decodeObjectForKey:@"NSTextColor"]];
	_backgroundColor = [[aDecoder decodeObjectForKey:@"NSBackgroundColor"] retain];
	_placeholderString=[[aDecoder decodeObjectForKey:@"NSPlaceholderString"] retain];

	if (_c.editable)
		_c.bordered = _c.bezeled = YES;
//	_tc.bezelStyle = [aDecoder decodeIntForKey:@"NSTextBezelStyle"];
//	_delegate = [aDecoder decodeObjectForKey:@"NSDelegate"];
#if 0
	NSLog(@"editable=%@", _c.editable?@"YES":@"NO");
	NSLog(@"editing=%@", _c.editing?@"YES":@"NO");
	NSLog(@"bezeled=%@", _c.bezeled?@"YES":@"NO");
	NSLog(@"bordered=%@", _c.bordered?@"YES":@"NO");
	NSLog(@"drawsBackground=%@", _c.drawsBackground?@"YES":@"NO");
	NSLog(@"_backgroundColor=%@", _backgroundColor);
#endif
	return self;
}

@end /* NSTextFieldCell (KeyedArchivingMethods) */


@implementation NSColor  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
#if 0
	NSLog(@"%@ initWithCoder:%@", NSStringFromClass([self class]), aDecoder);
	NSLog(@"NSColorSpace=%d", [aDecoder decodeIntForKey:@"NSColorSpace"]);
	NSLog(@"NSColor=%@", [aDecoder decodeObjectForKey:@"NSColor"]);	// is this a subcolor or alternate color?
#endif
#if 1	// reference once for NSKeyedArchiver debugging
	[aDecoder decodeObjectForKey:@"NSColor"];
#endif
	switch([aDecoder decodeIntForKey:@"NSColorSpace"])
		{
		case 6:	// Catalog
			{
				NSColor *c=[isa colorWithCatalogName:[aDecoder decodeObjectForKey:@"NSCatalogName"] colorName:[aDecoder decodeObjectForKey:@"NSColorName"]];
				if(!c)
					{
					NSLog(@"substitute %@/%@", [aDecoder decodeObjectForKey:@"NSCatalogName"], [aDecoder decodeObjectForKey:@"NSColorName"]);
					c=[aDecoder decodeObjectForKey:@"NSColor"];	// try to substitute if not in catalog
					}
				[self release];
#if 0
				NSLog(@"initWithCoder -> %@", c);
#endif
				return [c retain];
			}
		case 3:	// Gray
			{
				NSColor *c;
///				unsigned int len;
				NSUInteger len;
				float white=0.0, alpha=1.0;
				char *s=(char *)[aDecoder decodeBytesForKey:@"NSWhite" returnedLength:&len];
				if(s)
					sscanf(s, "%f %f", &white, &alpha);
				else
					NSLog(@"NSColor initWithCoder: can't decode NSWhite (%@)", aDecoder);
				c=[isa colorWithCalibratedWhite:white alpha:alpha];
				[self release];
#if 0
				NSLog(@"initWithCoder -> %@", c);
#endif
				return [c retain];
			}
		case 2:	// RGB
		case 1:	// RGB
			{
				NSColor *c;
///				unsigned int len;
				NSUInteger len;
				float red=0.0, green=0.0, blue=0.0, alpha=1.0;
				char *s=(char *)[aDecoder decodeBytesForKey:@"NSRGB" returnedLength:&len];
				if(s)
					sscanf(s, "%f %f %f %f", &red, &green, &blue, &alpha);	// alpha might be missing
				else
					NSLog(@"NSColor initWithCoder: can't decode NSRGB (%@)", aDecoder);
				c=[isa colorWithCalibratedRed:red green:green blue:blue alpha:alpha];
				[self release];
#if 0
				NSLog(@"initWithCoder -> %@", c);
#endif
				return [c retain];
			}
		default:
			NSLog(@"unimplemented initWithCoder: for color space model %d (coder=%@)", [aDecoder decodeIntForKey:@"NSColorSpace"], aDecoder);
			[self autorelease];
			return [[isa grayColor] retain];
		}

	return self;
}

@end /* NSResponder (KeyedArchivingMethods) */


@implementation NSButton  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
	return [super _initWithKeyedCoder:aDecoder];
}

@end /* NSButton (KeyedArchivingMethods) */


@implementation NSButtonCell  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
	self = [super _initWithKeyedCoder:aDecoder];

	unsigned int buttonflags=[aDecoder decodeIntForKey:@"NSButtonFlags"];
	unsigned int buttonflags2=[aDecoder decodeIntForKey:@"NSButtonFlags2"];
///	_buttonType=-1;	// we don't know
#if 0
	NSLog(@"%@ controlSize=%d", self, [self controlSize]);
#endif
	// the encoding is quite weird
	// stateby mapping
	//		bit 0 <-> bit 30
	//		bit 1 <- always 0
	//		bit 2,3 <-> bit 28,29
#define STATEBY (((buttonflags&(1<<30))>>(30-0))+((buttonflags&(3<<28))>>(28-2)))
	_stateMask=STATEBY;
	// highlightsby mapping
	//		bit 0 <-> bit 27
	//		bit 1 <-> bit 31
	//		bit 2,3 <-> bit 25,26
#define HIGHLIGHTSBY (((buttonflags&(1<<27))>>(27-0))+((buttonflags&(1<<31))>>(31-1))+((buttonflags&(3<<25))>>(25-2)))
	_highlightMask=HIGHLIGHTSBY;
#define DRAWING ((buttonflags&(1<<24))!=0)
	// ignored
#define BORDERED ((buttonflags&(1<<23))!=0)
	_c.bordered |= BORDERED;	// combine with cell border (meaning isBezeled...)
#define OVERLAPS ((buttonflags&0x00400000)!=0)
#define IMAGEPOSITION (NSImageAbove-((buttonflags&0x00300000)>>20))
#define IMAGEANDTEXT ((buttonflags&0x00080000)!=0)
#define IMAGESIZEDIFF ((buttonflags&0x00040000)!=0)
#define KEYEQUIVNOIMAGE ((buttonflags&0x00020000)!=0)

	if(OVERLAPS)
		_c.imagePosition=IMAGEANDTEXT?NSImageOverlaps:NSImageOnly;
	else if(IMAGEANDTEXT)
		_c.imagePosition=IMAGEPOSITION;
	else
		_c.imagePosition=NSNoImage;

#define TRANSPARENT ((buttonflags&0x00008000)!=0)
	_bc.transparent=TRANSPARENT;
#define INSET ((buttonflags&0x00006000)>>13)
#define DIMSWHENDISABLED ((buttonflags&0x00001000)==0)
///	_dimsWhenDisabled=DIMSWHENDISABLED;
#define GRADIENTTYPE ((buttonflags&(7<<9))>>9)
#define ALTERNATEMNEMONICLOC ((buttonflags&0x000000ff)>>0)	// 0xff=none

#define KEYEQUIVALENTMASK ((buttonflags2>>8)&0x00ff)
	_keyEquivalentModifierMask = KEYEQUIVALENTMASK;	// if encoded by flags
#define BORDERWHILEMOUSEINSIDE ((buttonflags2&0x00000010)!=0)
#define BEZELSTYLE (((buttonflags2&(7<<0))>>0)+((buttonflags2&(8<<2))>>2))
	_bc.bezelStyle=BEZELSTYLE;
	
	ASSIGN(_alternateContents, [aDecoder decodeObjectForKey:@"NSAlternateContents"]);
	ASSIGN(_normalImage, [aDecoder decodeObjectForKey:@"NSNormalImage"]);
	ASSIGN(_alternateImage, [aDecoder decodeObjectForKey:@"NSAlternateImage"]);

//	if([[_normalImage name] isEqualToString:@"NSSwitch"])
//		ASSIGN(_alternateImage, [NSImage imageNamed:@"NSHighlightedSwitch"]);
	if([_alternateContents isEqualToString:@""])
		ASSIGN(_alternateContents, nil);

#if 1
	if ([[_normalImage name] isEqualToString:@"NSRadioButton"])
		ASSIGN(_alternateImage, [NSImage imageNamed:@"NSHighlightedRadioButton"]);
	else
		{
		if([_alternateImage isKindOfClass:[NSFont class]])
			{ // bug (or feature?) in IB archiver
			[self setFont:(NSFont *)_alternateImage];
  #if 1
			NSLog(@"strange NSAlternateImage %@", _alternateImage);
  #endif
			[_alternateImage release], _alternateImage=nil;
		}	}

	if([_normalImage isKindOfClass:[NSFont class]])
		{
		[self setFont:(NSFont *)_alternateImage];
  #if 1
		NSLog(@"strange NSNormalImage %@", _normalImage);
  #endif
		[_normalImage release], _normalImage=nil;
		}
#endif
//	if([_alternateImage isKindOfClass:[NSButtonImageSource class]] || (!_normalImage && _alternateImage))
	if(!_normalImage && _alternateImage)
		{ // no (relevant) normal image but alternate
#if 0
		NSLog(@"no NSNormalImage %@ substituting alternate %@", _normalImage, _alternateImage);
#endif
		ASSIGN(_normalImage, _alternateImage), [_alternateImage release], _alternateImage=nil;
		}
	if(_normalImage)
		{ // try to deduce the button type from the image name
			NSString *name;
#if 0
			NSLog(@"normalImage=%@", _normalImage);
#endif
			name=[_normalImage name];
///			if([name isEqualToString:@"NSRadioButton"])
///				_buttonType=NSRadioButton/*, _d.imageScaling=NSImageScaleProportionallyDown*/;
///			else if([name isEqualToString:@"NSSwitch"])
///				_buttonType=NSSwitchButton/*, _d.imageScaling=NSImageScaleProportionallyDown*/;
		}
	ASSIGN(_keyEquivalent, [aDecoder decodeObjectForKey:@"NSKeyEquivalent"]);
	if([aDecoder containsValueForKey:@"NSKeyEquiv"])
		ASSIGN(_keyEquivalent, [aDecoder decodeObjectForKey:@"NSKeyEquiv"]);
	if([aDecoder containsValueForKey:@"NSKeyEquivModMask"])
		_keyEquivalentModifierMask = [aDecoder decodeIntForKey:@"NSKeyEquivModMask"];
///	if([aDecoder containsValueForKey:@"NSAttributedTitle"])
///		[self setAttributedTitle:[aDecoder decodeObjectForKey:@"NSAttributedTitle"]];	// overwrite
	_periodicDelay = 0.001*[aDecoder decodeIntForKey:@"NSPeriodicDelay"];
	_periodicInterval = 0.001*[aDecoder decodeIntForKey:@"NSPeriodicInterval"];
#if 0
	NSLog(@"initWithCoder final: %@", self);
	NSLog(@"  title=%@", _title);
	NSLog(@"  normalImage=%@", _normalImage);
	NSLog(@"  alternateImage=%@", _alternateImage);
	NSLog(@"  NSButtonFlags=%08x", [aDecoder decodeIntForKey:@"NSButtonFlags"]);	// encodes the button type&style
	NSLog(@"  NSButtonFlags2=%08x", [aDecoder decodeIntForKey:@"NSButtonFlags2"]);
	NSLog(@"  bezelstyle=%d", _bezelStyle);
	NSLog(@"  buttontype=%d", _buttonType);
	NSLog(@"  transparent=%d", _transparent);
	NSLog(@"  stateMask=%d", _stateMask);
	NSLog(@"  highlightMask=%d", _highlightMask);
	NSLog(@"  dimsWhenDisabled=%d", _dimsWhenDisabled);
#endif
	return self;
}

@end /* NSButtonCell (KeyedArchivingMethods) */


@implementation NSPopUpButtonCell  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
	self = [super _initWithKeyedCoder:aDecoder];

	_menu=[[aDecoder decodeObjectForKey:@"NSMenu"] retain];
	_controlView = [aDecoder decodeObjectForKey:@"NSControlView"];
	NSLog(@"NSPopUpButtonCell control view=%@", _controlView);
	[(NSPopUpButton *)_controlView setMenu: _menu];

#if 0
	NSLog(@"NSPopUpButtonCell menu=%@", _menu);
	NSLog(@"NSPopUpButtonCell items=%@", [_menu itemArray]);
#endif
	_pbc.altersStateOfSelectedItem=[aDecoder decodeBoolForKey:@"NSAltersState"];
	_pbc.usesItemFromMenu=[aDecoder decodeBoolForKey:@"NSUsesItemFromMenu"];
	_pbc.pullsDown=[aDecoder decodeBoolForKey:@"NSPullDown"];
	_pbc.arrowPosition=[aDecoder decodeIntForKey:@"NSArrowPosition"];
	_pbc.preferredEdge=[aDecoder decodeIntForKey:@"NSPreferredEdge"];
	
/*	_respectAlignment= */[aDecoder decodeObjectForKey:@"NSMenuItemRespectAlignment"];

	// _autoenablesItems=?
	if([aDecoder containsValueForKey:@"NSSelectedIndex"])
		[self selectItemAtIndex:[aDecoder decodeIntForKey:@"NSSelectedIndex"]];	// try to select

	return self;
}

/*
 * Checkme: this is a workaround for the following problem:
 * the popupbuttoncell's NSMenu has an array of items
 * when decoding this menu, all items are decoded
 * each menu-item has this popupButtonCell as it's target
 * the target is also decoded
 * depending on some ordering, this may lead to either complete or incomplete menu initialization
 *
 * we may need a fundamental solution for such recursive decoding of NIBs
 */

- (void) awakeFromNib
{
	NSLog(@"NSPopUpButtonCell awakeFromNib");
	if (_pbc.usesItemFromMenu)	// pull down popUps show first item if true
		[(NSPopUpButton *)_controlView selectItemAtIndex:0];
	[(NSPopUpButton *)_controlView displayIfNeeded];
///	if(menuItem)
///		[self selectItem:menuItem];
}

@end /* NSPopUpButtonCell (KeyedArchivingMethods) */


@implementation NSMenu  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{ 
	NSString *name;
	NSEnumerator *e;
	NSMenuItem *i;

	self=[self init];
	_title = [[aDecoder decodeObjectForKey:@"NSTitle"] retain];
//		self=[self initWithTitle: _title];

///	menuFont=[aDecoder decodeObjectForKey:@"NSMenuFont"];	// new in 10.6
	name=[aDecoder decodeObjectForKey:@"NSName"];
	e=[[aDecoder decodeObjectForKey:@"NSMenuItems"] objectEnumerator];	// decode items
	while((i=[e nextObject]))
		[self addItem:i];	// add menu items
	if([name length] > 0)
		{
#if 0
		NSLog(@"menu (name=%@): %@ title: %@", name, self, _title);
#endif
		if([name isEqualToString:@"_NSMainMenu"])
			[[NSApplication sharedApplication] setMainMenu:self];
#if 0
		else if([name isEqualToString:@"_NSAppleMenu"])
			[[NSApplication sharedApplication] setAppleMenu:self];
		else if([name isEqualToString:@"_NSServicesMenu"])
			[[NSApplication sharedApplication] setServicesMenu:self];
		else if([name isEqualToString:@"_NSFontMenu"])
			[[NSFontManager sharedFontManager] setFontMenu:self];
		else if([name isEqualToString:@"_NSRecentDocumentsMenu"])
			[[NSDocumentController sharedDocumentController] _setOpenRecentMenu:self];
		else if([name isEqualToString:@"_NSOpenDocumentsMenu"])
			[[NSDocumentController sharedDocumentController] _setOpenRecentMenu:self];
#endif
		else if([name isEqualToString:@"_NSWindowsMenu"])
			[[NSApplication sharedApplication] setWindowsMenu:self];
		else
			NSLog(@"unknown menu (name=%@): %@", name, self);
		}
	if(_mn.menuHasChanged)		// resize if menu has been changed
		[self sizeToFit];
#if 0
	NSLog(@"initializedWithCoder: %@", [self _longDescription]);
#endif

	return self;
}

@end /* NSMenu (KeyedArchivingMethods) */


@implementation NSMenuItem  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
	NSMenu *subMenu;

	self = [super _initWithKeyedCoder:aDecoder];

	_contents = [[aDecoder decodeObjectForKey:@"NSTitle"] retain];
	_menu = [[aDecoder decodeObjectForKey:@"NSMenu"] retain];
	if ((subMenu = [aDecoder decodeObjectForKey:@"NSSubmenu"]))
		[_menu setSubmenu:[subMenu retain] forItem:self];

//	NSLog(@"NSMenuItem NSTag - tag=%d", tag);

///	self = [[aDecoder decodeObjectForKey:@"NSMenuItem"] retain];
///	[menuItem setMixedStateImage:[aDecoder decodeObjectForKey:@"NSMixedImage"]];
///	[menuItem setOnStateImage:[aDecoder decodeObjectForKey:@"NSOnImage"]];

	return self;
}

@end /* NSMenuItem (KeyedArchivingMethods) */


@implementation NSSegmentedCell  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)decoder
{
	self = [super _initWithKeyedCoder:decoder];

	[self setAlignment:NSCenterTextAlignment];
	_segments = [[decoder decodeObjectForKey:@"NSSegmentImages"] retain];	// array of segments
///	count = [_segments count];
	_c.enabled=YES;

	return self;
}

@end /* NSSegmentedCell (KeyedArchivingMethods) */


@implementation NSSliderCell  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)decoder
{
	self = [super _initWithKeyedCoder:decoder];

	_minValue=[decoder decodeDoubleForKey:@"NSMinValue"];
	_maxValue=[decoder decodeDoubleForKey:@"NSMaxValue"];
	_sc.isVertical=[decoder decodeBoolForKey:@"NSVertical"];
///	_initializedVertical=!_isVertical;	// force initialization of image
///	_altIncrementValue=[decoder decodeDoubleForKey:@"NSAltIncValue"];
	[self setFloatValue:[decoder decodeFloatForKey:@"NSValue"]];
//		[self setDoubleValue:[decoder decodeDoubleForKey:@"NSValue"]];
	_sc.sliderType=[decoder decodeIntForKey:@"NSSliderType"];
	_numberOfTickMarks=[decoder decodeIntForKey:@"NSNumberOfTickMarks"];
///	_allowTickMarkValuesOnly=[decoder decodeBoolForKey:@"NSAllowsTickMarkValuesOnly"];
///	_tickMarkPosition=[decoder decodeIntForKey:@"NSTickMarkPosition"];

	return self;
}

@end /* NSSliderCell (KeyedArchivingMethods) */


@implementation NSLevelIndicatorCell  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
	self = [super _initWithKeyedCoder:aDecoder];

	_minValue=[aDecoder decodeDoubleForKey:@"NSMinValue"];
	_warningValue=[aDecoder decodeDoubleForKey:@"NSWarningValue"];
	_criticalValue=[aDecoder decodeDoubleForKey:@"NSCriticalValue"];
	_maxValue=[aDecoder decodeDoubleForKey:@"NSMaxValue"];
	_value=[aDecoder decodeDoubleForKey:@"NSValue"];
	_lc.style=[aDecoder decodeIntForKey:@"NSIndicatorStyle"];
	_numberOfMajorTickMarks=[aDecoder decodeIntForKey:@"NSNumberOfMajorTickMarks"];
	_numberOfTickMarks=[aDecoder decodeIntForKey:@"NSNumberOfTickMarks"];
	_tickMarkPosition=[aDecoder decodeIntForKey:@"NSTickMarkPosition"];

	return self;
}

@end /* NSLevelIndicatorCell (KeyedArchivingMethods) */


@implementation NSFont  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
	self=[self init];

	return [NSFont userFontOfSize:12];	// FIX ME w/o this the font backend is not init'd
}										// also font shows up as alt image

@end /* NSFont (KeyedArchivingMethods) */


@implementation NSScrollView  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)coder
{
/*
NSScrollAmts,
NSMagnification,
NSMinMagnification,
NSMaxMagnification
*/
	unsigned int svflags;

	self = [super _initWithKeyedCoder:coder];

	_horizScroller = [[coder decodeObjectForKey:@"NSHScroller"] retain];
	_vertScroller = [[coder decodeObjectForKey:@"NSVScroller"] retain];
	_headerClipView = [[coder decodeObjectForKey:@"NSHeaderClipView"] retain];
	_contentView = [[coder decodeObjectForKey:@"NSContentView"] retain];
	svflags = [coder decodeIntForKey:@"NSsFlags"];

#define BORDERTYPE			((svflags & 0x0003) >> 0)
#define VSCROLLER			((svflags & 0x0010) != 0)
#define HSCROLLER			((svflags & 0x0020) != 0)
#define AUTOHIDE			((svflags & 0x0200) != 0)
	_sv.borderType = BORDERTYPE;
	_sv.hasHorizScroller = HSCROLLER;
	_sv.hasVertScroller = VSCROLLER;
	_sv.autohidesScrollers = AUTOHIDE;
//	[self setHasVerticalScroller:VSCROLLER];
//	[self setHasHorizontalScroller:HSCROLLER];
	[self tile];

	return self;
}

@end /* NSScrollView (KeyedArchivingMethods) */


@implementation NSClipView  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
	unsigned int cvFlags;
	NSView *docView;

	self = [super _initWithKeyedCoder:aDecoder];

	_backgroundColor = [[aDecoder decodeObjectForKey:@"NSBGColor"] retain];

//	cvFlags = [aDecoder decodeInt32ForKey:@"NScvFlags"];
	cvFlags = [aDecoder decodeIntForKey:@"NScvFlags"];
#define COPIESONSCROLL  ((cvFlags & 0x02) == 0)
#define DRAWSBACKGROUND ((cvFlags & 0x04) != 0)
	_cv.drawsBackground = DRAWSBACKGROUND;
	_cv.copiesOnScroll = COPIESONSCROLL;

#if 1
		NSLog(@"cvFlags=%08lx", cvFlags);
#endif

//	_cursor = [[aDecoder decodeObjectForKey:@"NSCursor"] retain];
	if ((docView = [aDecoder decodeObjectForKey:@"NSDocView"]))
		[self setDocumentView: docView];

	return self;
}

@end /* NSClipView (KeyedArchivingMethods) */


@implementation NSSplitView  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
	_dividerStyle = [aDecoder decodeIntForKey:@"NSDividerStyle"];
	_isVertical = [aDecoder decodeIntForKey:@"NSIsVertical"];

	return [super _initWithKeyedCoder:aDecoder];
}

@end /* NSSplitView (KeyedArchivingMethods) */


#if 1
@interface _NSCornerView : NSView
@end
@implementation _NSCornerView
@end /* _NSCornerView */
#endif


@implementation NSOutlineView  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
/*
NSIntercellSpacingHeight,
NSControlAllowsExpansionToolTips,
NSGridColor,
NSAllowsTypeSelect,
NSDraggingSourceMaskForLocal,
NSAllowsLogicalLayoutDirection,
NSIntercellSpacingWidth,
NSTableViewDraggingDestinationStyle,
NSTableViewGroupRowStyle,
NSDraggingSourceMaskForNonLocal,
NSColumnAutoresizingStyle
*/
	self = [super _initWithKeyedCoder:aDecoder];

	_rowHeight = [aDecoder decodeFloatForKey:@"NSRowHeight"];
	_cornerView = [[aDecoder decodeObjectForKey:@"NSCornerView"] retain];
	_headerView = [[aDecoder decodeObjectForKey:@"NSHeaderView"] retain];
	_delegate = [[aDecoder decodeObjectForKey:@"NSDelegate"] retain];
	_dataSource = [[aDecoder decodeObjectForKey:@"NSDataSource"] retain];
	_tableColumns = [[aDecoder decodeObjectForKey:@"NSTableColumns"] retain];
	_backgroundColor = [[aDecoder decodeObjectForKey:@"NSBackgroundColor"] retain];

	unsigned int tViewflags = [aDecoder decodeIntForKey:@"NSTvFlags"];
//	NSLog(@"tViewflags=%08x", tViewflags);
#define ALTCOLORS  ((tViewflags & 0x00800000) >> 23)
	_tv.alternatingRowColor = ALTCOLORS;

	if (_tableColumns)		// FIX ME data cell s/b already configured
		{
		NSUInteger i, count = [_tableColumns count];

		for (i = 0; i < count; i++)
			[[[_tableColumns objectAtIndex:i] dataCell] setBezeled: NO];
		}

	return self;
}

@end /* NSOutlineView (KeyedArchivingMethods) */


@implementation NSTableColumn  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
// NSResizingMask,
	_tableView = [[aDecoder decodeObjectForKey:@"NSTableView"] retain];
	_dataCell = [[aDecoder decodeObjectForKey:@"NSDataCell"] retain];
	_headerCell = [[aDecoder decodeObjectForKey:@"NSHeaderCell"] retain];
	_width = [aDecoder decodeFloatForKey:@"NSWidth"];
	_minWidth = [aDecoder decodeFloatForKey:@"NSMinWidth"];
	_maxWidth = [aDecoder decodeFloatForKey:@"NSMaxWidth"];
	_tc.isEditable = [aDecoder decodeBoolForKey:@"NSIsEditable"];
	_tc.isResizable = [aDecoder decodeBoolForKey:@"NSIsResizeable"];

	return self;
}

@end /* NSTableColumn (KeyedArchivingMethods) */


@implementation NSTableHeaderView  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
	self = [super _initWithKeyedCoder:aDecoder];

	_tableView = [[aDecoder decodeObjectForKey:@"NSTableView"] retain];

	return self;
}

@end /* NSTableHeaderView (KeyedArchivingMethods) */


@implementation NSSearchFieldCell  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
	const unsigned char *sfFlags;
	NSUInteger len;

	self = [super _initWithKeyedCoder:aDecoder];

	if([aDecoder containsValueForKey:@"NSSearchFieldFlags"])
		{
		sfFlags=[aDecoder decodeBytesForKey:@"NSSearchFieldFlags" returnedLength:&len];
#define FLAG (sfFlags[0] != 0)
		_sf.sendsWholeSearchString=FLAG;	// ????
		}
	/*	_cancelButtonCell = */ [[aDecoder decodeObjectForKey:@"NSCancelButtonCell"] retain];
	/*	_searchButtonCell = */ [[aDecoder decodeObjectForKey:@"NSSearchButtonCell"] retain];
	maxRecents = [aDecoder decodeIntForKey:@"NSMaximumRecents"];
	_sf.sendsWholeSearchString = [aDecoder decodeBoolForKey:@"NSSendsWholeSearchString"];
	// NSSearchFieldFlags - NSData (?)

	return self;
}

@end /* NSSearchFieldCell (KeyedArchivingMethods) */


@implementation NSSegmentedControl  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
	self = [super _initWithKeyedCoder:aDecoder];

//	[aDecoder decodeIntForKey:@"NSAllowsLogicalLayoutDirection"];

	return self;
}

@end /* NSSegmentedControl (KeyedArchivingMethods) */


@implementation NSSegmentItem  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
///	self = [super _initWithKeyedCoder:aDecoder];

	_label = [[aDecoder decodeObjectForKey:@"NSSegmentItemLabel"] retain];
	_image = [[aDecoder decodeObjectForKey:@"NSSegmentItemImage"] retain];
	_menu = [[aDecoder decodeObjectForKey:@"NSSegmentItemMenu"] retain];
	// NSSegmentItemImageScaling
	if([aDecoder containsValueForKey:@"NSSegmentItemEnabled"])
		_enabled = [aDecoder decodeBoolForKey:@"NSSegmentItemEnabled"];
	else
		_enabled=YES;	// default
	if([aDecoder decodeBoolForKey:@"NSSegmentItemDisabled"])
		_enabled=NO;	// override
	_selected = [aDecoder decodeBoolForKey:@"NSSegmentItemSelected"];
	_width = [aDecoder decodeFloatForKey:@"NSSegmentItemWidth"];
	_tag = [aDecoder decodeIntForKey:@"NSSegmentItemTag"];

	return self;
}

@end /* NSSegmentedControl (KeyedArchivingMethods) */


@implementation NSTabView  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
	int vFlags;

	self = [super _initWithKeyedCoder:aDecoder];

	vFlags=[aDecoder decodeIntForKey:@"NSTvFlags"];

#define NEEDSLAYOUT ((vFlags&0x80000000)!=0)
///#define CONTROLTINT ((vFlags>>28)&7)	// ???
///		_controlTint=CONTROLTINT;
///#define CONTROLSIZE ((vFlags>>27)&3)
///		_controlSize=CONTROLSIZE;
#if 0
	NSLog(@"vFlags=%08x controlSize=%d", vFlags, _controlSize);
#endif
#define TABTYPE ((vFlags>>0)&0x00000007)
	_tabViewType=TABTYPE;

	_tabViewItems = [[aDecoder decodeObjectForKey:@"NSTabViewItems"] retain];
	_selectedTabViewItem = [[aDecoder decodeObjectForKey:@"NSSelectedTabViewItem"] retain];
	_font = [[aDecoder decodeObjectForKey:@"NSFont"] retain];
	_drawsBackground = [aDecoder decodeBoolForKey:@"NSDrawsBackground"];
	_allowTruncatedLabels = [aDecoder decodeBoolForKey:@"NSAllowTruncatedLabels"];

	return self;
}

@end /* NSTabViewItem (KeyedArchivingMethods) */


@implementation NSTabViewItem  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
	_tabState = NSBackgroundTab;
	_view = [[aDecoder decodeObjectForKey:@"NSView"] retain];
	_tabView = [[aDecoder decodeObjectForKey:@"NSTabView"] retain];
	_color = [[aDecoder decodeObjectForKey:@"NSColor"] retain];
	_label = [[aDecoder decodeObjectForKey:@"NSLabel"] retain];

	return self;
}

@end /* NSTabViewItem (KeyedArchivingMethods) */


@implementation NSColorWell  (KeyedArchivingMethods)

- (id) _initWithKeyedCoder:(NSKeyedUnarchiver*)aDecoder
{
	self = [super _initWithKeyedCoder:aDecoder];

	_color = [[aDecoder decodeObjectForKey:@"NSColor"] retain];
	_cell = [NSActionCell new];

	return self;
}

@end /* NSColorWell (KeyedArchivingMethods) */
