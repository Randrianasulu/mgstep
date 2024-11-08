/*
   MModelArchiving.m

   Copyright (C) 1996-2016 Free Software Foundation, Inc.

   Author:	Ovidiu Predescu <ovidiu@net-community.com>
   Date: 	November 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSArray.h>
#include <Foundation/NSException.h>

#include <AppKit/AppKit.h>


#define BOOL_VALUE	([v compare:@"YES" \
						options:NSCaseInsensitiveSearch] == NSOrderedSame)
#define INT_VALUE	([v intValue])

#define SET_BOOL(a,b)  if ((v = [(NSDictionary *)rep objectForKey: b])) \
							[self a BOOL_VALUE];
#define SET_INT(a,b)   if ((v = [(NSDictionary *)rep objectForKey: b])) \
							[self a INT_VALUE];


/* ****************************************************************************

	AppKit Model Archive  (obsolete keyed property list archive format)

** ***************************************************************************/

@interface NSApplication (GMArchiverMethods) <ModelCoding>  @end
@interface NSBox         (GMArchiverMethods) <ModelCoding>  @end
@interface NSButton      (GMArchiverMethods) <ModelCoding>  @end
@interface NSCell        (GMArchiverMethods) <ModelCoding>  @end
@interface NSClipView    (GMArchiverMethods) <ModelCoding>  @end
@interface NSColor       (GMArchiverMethods) <ModelCoding>  @end
@interface NSControl     (GMArchiverMethods) <ModelCoding>  @end
@interface NSFont        (GMArchiverMethods) <ModelCoding>  @end
@interface NSImage       (GMArchiverMethods) <ModelCoding>  @end
@interface NSMenuItem    (GMArchiverMethods) <ModelCoding>  @end
@interface NSMenu        (GMArchiverMethods) <ModelCoding>  @end
@interface NSPopUpButton (GMArchiverMethods) <ModelCoding>  @end
@interface NSResponder   (GMArchiverMethods) <ModelCoding>  @end
@interface NSTextField   (GMArchiverMethods) <ModelCoding>  @end
@interface NSView        (GMArchiverMethods) <ModelCoding>  @end
@interface NSWindow      (GMArchiverMethods) <ModelCoding>  @end
@interface NSPanel       (GMArchiverMethods) <ModelCoding>  @end
@interface NSSavePanel   (GMArchiverMethods) <ModelCoding>  @end
@interface NSBrowser     (GMArchiverMethods) <ModelCoding>  @end


@implementation NSApplication (GMArchiverMethods)

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver
{
	[archiver encodeObject:[self windows] withName:@"windows"];
	[archiver encodeObject:[self keyWindow] withName:@"keyWindow"];
	[archiver encodeObject:[self mainWindow] withName:@"mainWindow"];
	[archiver encodeObject:[self mainMenu] withName:@"mainMenu"];
	[archiver encodeObject:[self delegate] withName:@"delegate"];
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	NSWindow *keyWindow;
	NSWindow *mainWindow;
	NSArray *windows;
	NSMenu *mainMenu;
	id anObject;

	if ((mainMenu = [unarchiver decodeObjectWithName:@"mainMenu"]))
		[self setMainMenu:mainMenu];
	
	windows = [unarchiver decodeObjectWithName:@"windows"];
	keyWindow = [unarchiver decodeObjectWithName:@"keyWindow"];
	mainWindow = [unarchiver decodeObjectWithName:@"mainWindow"];
	
	if ((anObject = [unarchiver decodeObjectWithName:@"delegate"]))
		[self setDelegate:anObject];
	
	if ((mainMenu = [unarchiver decodeObjectWithName:@"mainMenu"]))
		[self setMainMenu:mainMenu];
	
	[keyWindow makeKeyWindow];
	[mainWindow makeMainWindow];
	
	return self;
}

- (void) awakeFromNib
{
	NSMenu *mainMenu = [self mainMenu];

	[mainMenu update];
	[mainMenu display];
}

+ (id) createObjectForModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	return [NSApplication sharedApplication];
}

@end /* NSApplication (GMArchiverMethods) */


@implementation NSBox (GMArchiverMethods)

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver
{
	[super encodeWithModelArchiver:archiver];
	
	[archiver encodeInt:[self borderType] withName:@"borderType"];
	[archiver encodeInt:[self titlePosition] withName:@"titlePosition"];
	[archiver encodeString:[self title] withName:@"title"];
	[archiver encodeObject:[self titleFont] withName:@"titleFont"];
	[archiver encodeObject:[self contentView] withName:@"contentView"];
//	[archiver encodeSize:[self contentViewMargins] withName:@"margins"];
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	id cv;

	self = [super initWithModelUnarchiver:unarchiver];
	
	[self setBorderType:[unarchiver decodeIntWithName:@"borderType"]];
	[self setTitlePosition:[unarchiver decodeIntWithName:@"titlePosition"]];
	[self setTitle:[unarchiver decodeStringWithName:@"title"]];
	[self setTitleFont:[unarchiver decodeObjectWithName:@"titleFont"]];
//	[self setContentViewMargins:[unarchiver decodeIntWithName:@"margins"]];
	if((cv = [unarchiver decodeObjectWithName:@"contentView"]))
		{
		if([cv class] != [NSView class])
			[self setContentView:cv];				// if decoded content view
		else										// is oridinary view just
			[cv release];							// use default content view
		}

	return self;
}

@end /* NSBox (GMArchiverMethods) */


@implementation NSButton (GMArchiverMethods)

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver
{
	float delay, interval;
	id c = [self cell];

	[self getPeriodicDelay:&delay interval:&interval];
	[archiver encodeInt:[self state] withName:@"state"];
	[archiver encodeFloat:delay withName:@"delay"];
	[archiver encodeFloat:interval withName:@"interval"];
	[archiver encodeString:[self title] withName:@"title"];
	[archiver encodeString:[self alternateTitle] withName:@"alternateTitle"];
	[archiver encodeObject:[self image] withName:@"image"];
	[archiver encodeObject:[self alternateImage] withName:@"alternateImage"];
	[archiver encodeInt:[self imagePosition] withName:@"imagePosition"];
	[archiver encodeBOOL:[self isBordered] withName:@"isBordered"];
	[archiver encodeBOOL:[self isTransparent] withName:@"isTransparent"];
	[archiver encodeString:[self keyEquivalent] withName:@"keyEquivalent"];
	[archiver encodeInt:[c highlightsBy] withName:@"highlightsBy"];
	[archiver encodeInt:[c showsStateBy] withName:@"showsStateBy"];
	
	[super encodeWithModelArchiver:archiver];
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	id c = [self cell];

	[super initWithModelUnarchiver:unarchiver];
	
	[c setState:[unarchiver decodeIntWithName:@"state"]];

	[c setPeriodicDelay:[unarchiver decodeFloatWithName:@"delay"]
	   interval:[unarchiver decodeFloatWithName:@"interval"]];
	
	[c setTitle:[unarchiver decodeStringWithName:@"title"]];
	[c setAlternateTitle:[unarchiver decodeStringWithName:@"alternateTitle"]];
	[c setImage:[unarchiver decodeObjectWithName:@"image"]];
	[c setAlternateImage:[unarchiver decodeObjectWithName:@"alternateImage"]];
	[c setImagePosition:[unarchiver decodeIntWithName:@"imagePosition"]];
	[c setBordered:[unarchiver decodeBOOLWithName:@"isBordered"]];
	[c setTransparent:[unarchiver decodeBOOLWithName:@"isTransparent"]];
	[c setKeyEquivalent:[unarchiver decodeStringWithName:@"keyEquivalent"]];
	[c setHighlightsBy:[unarchiver decodeIntWithName:@"highlightsBy"]];
	[c setShowsStateBy:[unarchiver decodeIntWithName:@"showsStateBy"]];
	
	return self;
}

@end /* NSButton (GMArchiverMethods) */


@implementation NSCell (GMArchiverMethods)

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver
{
	[archiver encodeObject:[self font] withName:@"font"];
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	NSFont *font = [unarchiver decodeObjectWithName:@"font"];

	if (font)
		[self setFont:font];

	return self;
}

@end /* NSCell (GMArchiverMethods) */


@implementation NSClipView (GMArchiverMethods)

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver
{
	[super encodeWithModelArchiver:archiver];
	
	[archiver encodeObject:[self documentView] withName:@"documentView"];
	[archiver encodeBOOL:[self copiesOnScroll] withName:@"copiesOnScroll"];
	[archiver encodeObject:[self backgroundColor] withName:@"backgroundColor"];
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	NSColor *color;

	self = [super initWithModelUnarchiver:unarchiver];
	
	[self setDocumentView:[unarchiver decodeObjectWithName:@"documentView"]];
	[self setCopiesOnScroll:[unarchiver decodeBOOLWithName:@"copiesOnScroll"]];
	if((color = [unarchiver decodeObjectWithName:@"backgroundColor"]))
		[self setBackgroundColor: color];

	return self;
}

@end /* NSClipView (GMArchiverMethods) */


@implementation NSColor (GMArchiverMethods)

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver
{
	NSString *colorSpaceName = [self colorSpaceName];

	[archiver encodeString:colorSpaceName withName:@"colorSpaceName"];

	if ([colorSpaceName isEqual:@"NSDeviceCMYKColorSpace"]) 
		{
		[archiver encodeFloat:[self cyanComponent] withName:@"cyan"];
		[archiver encodeFloat:[self magentaComponent] withName:@"magenta"];
		[archiver encodeFloat:[self yellowComponent] withName:@"yellow"];
		[archiver encodeFloat:[self blackComponent] withName:@"black"];
		[archiver encodeFloat:[self alphaComponent] withName:@"alpha"];
		}
	else if ([colorSpaceName isEqual:@"NSDeviceWhiteColorSpace"]
			|| [colorSpaceName isEqual:@"NSCalibratedWhiteColorSpace"]) 
		{
		[archiver encodeFloat:[self whiteComponent] withName:@"white"];
		[archiver encodeFloat:[self alphaComponent] withName:@"alpha"];
		}
	else if ([colorSpaceName isEqual:@"NSDeviceRGBColorSpace"]
			|| [colorSpaceName isEqual:@"NSCalibratedRGBColorSpace"]) 
		{
		[archiver encodeFloat:[self redComponent] withName:@"red"];
		[archiver encodeFloat:[self greenComponent] withName:@"green"];
		[archiver encodeFloat:[self blueComponent] withName:@"blue"];
		[archiver encodeFloat:[self alphaComponent] withName:@"alpha"];
		[archiver encodeFloat:[self hueComponent] withName:@"hue"];
		[archiver encodeFloat:[self saturationComponent] 
				  withName:@"saturation"];
		[archiver encodeFloat:[self brightnessComponent] 
				  withName:@"brightness"];
		}
	else if ([colorSpaceName isEqual:@"NSNamedColorSpace"]) 
		{
		[archiver encodeString:[self catalogNameComponent] 
				  withName:@"catalogName"];
    	[archiver encodeString:[self colorNameComponent] 
				  withName:@"colorName"];
		}
}

+ (id) createObjectForModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	NSString *colorSpaceName = [unarchiver decodeStringWithName:@"colorSpaceName"];

	if ([colorSpaceName isEqual:@"NSDeviceCMYKColorSpace"]) 
		{
		float cyan = [unarchiver decodeFloatWithName:@"cyan"];
		float magenta = [unarchiver decodeFloatWithName:@"magenta"];
		float yellow = [unarchiver decodeFloatWithName:@"yellow"];
		float black = [unarchiver decodeFloatWithName:@"black"];
		float alpha = [unarchiver decodeFloatWithName:@"alpha"];
	
		return [NSColor colorWithDeviceCyan:cyan
						magenta:magenta
						yellow:yellow
						black:black
						alpha:alpha];
		}
	else if ([colorSpaceName isEqual:@"NSDeviceWhiteColorSpace"]) 
		{
		float white = [unarchiver decodeFloatWithName:@"white"];
		float alpha = [unarchiver decodeFloatWithName:@"alpha"];

		return [NSColor colorWithDeviceWhite:white alpha:alpha];
		}
	else if ([colorSpaceName isEqual:@"NSCalibratedWhiteColorSpace"]) 
		{
		float white = [unarchiver decodeFloatWithName:@"white"];
		float alpha = [unarchiver decodeFloatWithName:@"alpha"];
	
		return [NSColor colorWithCalibratedWhite:white alpha:alpha];
		}
	else if ([colorSpaceName isEqual:@"NSDeviceRGBColorSpace"]) 
		{
		float red = [unarchiver decodeFloatWithName:@"red"];
		float green = [unarchiver decodeFloatWithName:@"green"];
		float blue = [unarchiver decodeFloatWithName:@"blue"];
		float alpha = [unarchiver decodeFloatWithName:@"alpha"];
	
		return [self colorWithDeviceRed:red green:green blue:blue alpha:alpha];
		}
	else if ([colorSpaceName isEqual:@"NSCalibratedRGBColorSpace"]) 
		{
		float red = [unarchiver decodeFloatWithName:@"red"];
		float g = [unarchiver decodeFloatWithName:@"green"];
		float blue = [unarchiver decodeFloatWithName:@"blue"];
		float alpha = [unarchiver decodeFloatWithName:@"alpha"];
	
		return [self colorWithCalibratedRed:red green:g blue:blue alpha:alpha];
		}
	else if ([colorSpaceName isEqual:@"NSNamedColorSpace"]) 
		{
		NSAssert (0, @"Named color spaces not supported yet!");
		NSLog(@"Named color spaces are not yet supported!");
		}

	return nil;
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver  { return self; }
- (Class) classForModelArchiver						{ return [NSColor class]; }

@end /* NSColor (GMArchiverMethods) */


@implementation NSColorWell (GMArchiverMethods)

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver
{
	[archiver encodeBOOL:[self isBordered] withName:@"isBordered"];
	[archiver encodeObject:[self color] withName:@"color"];

	[super encodeWithModelArchiver:archiver];
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	NSString *v;
	id rep;

	self = [super initWithModelUnarchiver:unarchiver];
	
	rep = [unarchiver decodedObjectRepresentation];
	SET_BOOL(setBordered:, @"isBordered")
	if ((rep = [unarchiver decodeObjectWithName:@"color"]))
		[self setColor: rep];

	return self;
}

@end /* NSColorWell (GMArchiverMethods) */


@implementation NSControl (GMArchiverMethods)

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver
{
	id target;
	SEL action;

	if ((target = [self target]))
		[archiver encodeObject:target withName:@"target"];
	if ((action = [self action]))
		[archiver encodeSelector:action withName:@"action"];
	
	[archiver encodeBOOL:[self isEnabled] withName:@"isEnabled"];
	[archiver encodeInt:[self alignment] withName:@"alignment"];
	[archiver encodeObject:[self font] withName:@"font"];
	[archiver encodeBOOL:[self isContinuous] withName:@"isContinuous"];
	[archiver encodeInt:[self tag] withName:@"tag"];
  [archiver encodeBOOL:[self ignoresMultiClick] withName:@"ignoresMultiClick"];
	
	[super encodeWithModelArchiver:archiver];
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	NSFont *font;
	NSString *v;
	id rep;

	self = [super initWithModelUnarchiver:unarchiver];
	
	rep = [unarchiver decodedObjectRepresentation];
	SET_BOOL(setEnabled:, 			@"isEnabled")
	SET_BOOL(setIgnoresMultiClick:, @"ignoresMultiClick")
	SET_BOOL(setContinuous:, 		@"isContinuous")

	SET_INT(setAlignment:,			@"alignment")
	SET_INT(setTag:,				@"tag")

	[self setTarget:[unarchiver decodeObjectWithName:@"target"]];
	[self setAction:[unarchiver decodeSelectorWithName:@"action"]];

	if ((font = [unarchiver decodeObjectWithName:@"font"]))
		[self setFont:font];

	return self;
}

@end /* NSControl (GMArchiverMethods) */


@implementation NSFont (GMArchiverMethods)

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver
{
	[archiver encodeString:[self fontName] withName:@"name"];
	[archiver encodeFloat:[self pointSize] withName:@"size"];
}

+ (id) createObjectForModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	return [NSFont fontWithName:[unarchiver decodeStringWithName:@"name"]
				   size:[unarchiver decodeFloatWithName:@"size"]];
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	return self;
}

@end /* NSFont (GMArchiverMethods) */


@implementation NSImage (GMArchiverMethods)

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver
{
	[archiver encodeString:[self name] withName:@"name"];
	[archiver encodeSize:[self size] withName:@"size"];
}

+ (id) createObjectForModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	id image = [NSImage imageNamed:[unarchiver decodeStringWithName:@"name"]];

	return image ? image : [NSImage imageNamed:@"NSRadioButton"];
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	[self setSize:[unarchiver decodeSizeWithName:@"size"]];
	return self;
}

@end /* NSImage (GMArchiverMethods) */


@implementation NSMenuItem (GMArchiverMethods)

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver
{
	[super encodeWithModelArchiver:archiver];
	
	[archiver encodeObject:[self target] withName:@"target"];
	[archiver encodeSelector:[self action] withName:@"action"];
	[archiver encodeString:[self title] withName:@"title"];
	[archiver encodeInt:[self tag] withName:@"tag"];
	[archiver encodeBOOL:[self isEnabled] withName:@"isEnabled"];
	[archiver encodeString:[self keyEquivalent] withName:@"keyEquivalent"];
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	self = [super initWithModelUnarchiver:unarchiver];
	
	[self setTarget:[unarchiver decodeObjectWithName:@"target"]];
	[self setAction:[unarchiver decodeSelectorWithName:@"action"]];
	[self setTitle:[unarchiver decodeStringWithName:@"title"]];
	[self setTag:[unarchiver decodeIntWithName:@"tag"]];
	[self setEnabled:[unarchiver decodeBOOLWithName:@"isEnabled"]];
	[self setKeyEquivalent:[unarchiver decodeStringWithName:@"keyEquivalent"]];

	return self;
}

@end /* NSMenuItem (GMArchiverMethods) */


@implementation NSMenu (GMArchiverMethods)

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver
{
	[archiver encodeObject:[self itemArray] withName:@"itemArray"];
	[archiver encodeBOOL:[self autoenablesItems] withName:@"autoenablesItems"];
	[archiver encodeString:[self title] withName:@"title"];
}
		// Define this method here because on OPENSTEP 4.x NSMenu is inherited 
		// from NSWindow and we don't want the NSWindow's method to be called.
+ (id) createObjectForModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
NSString *theTitle = [unarchiver decodeStringWithName:@"title"];

	return [[[self alloc] initWithTitle:theTitle] autorelease];
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	int i, count;
	NSMutableArray *itemArray = (NSMutableArray *)[self itemArray];
	NSMutableArray *decodedItems = [unarchiver decodeObjectWithName:@"itemArray"];

	for (i = 0, count = [decodedItems count]; i < count; i++)
		[self addItemWithTitle:@"dummy" action:NULL keyEquivalent:@""];

	[itemArray replaceObjectsInRange:NSMakeRange(0, count)
			   withObjectsFromArray:decodedItems];

	for (i = 0; i < count; i++) 
		{
		id item = [itemArray objectAtIndex:i];
		id target = [item target];

		if ([target isKindOfClass:[NSMenu class]])
			[self setSubmenu:target forItem:item];
		}

	[self setAutoenablesItems: [unarchiver 
								decodeBOOLWithName:@"autoenablesItems"]];
	[self sizeToFit];

	return self;
}

@end /* NSMenu (GMArchiverMethods) */


@implementation NSPopUpButton (GMArchiverMethods)

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver
{
	[archiver encodeBOOL:[self pullsDown] withName:@"pullsDown"];
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	int i, count;
	NSMutableArray *decodedItems = [unarchiver decodeObjectWithName:@"itemArray"];

	self = [super initWithModelUnarchiver:unarchiver];

	if (decodedItems) 
		{
		for (i = 0, count = [decodedItems count]; i < count; i++) 
			{
			id item = [decodedItems objectAtIndex:i];
			id myItem;
	  
			[self addItemWithTitle:[item title]];
			myItem = [self itemAtIndex:i];
			[myItem setTarget:[item target]];
			[myItem setAction:[item action]];
			[myItem setEnabled:[item isEnabled]];
			[myItem setTag:[item tag]];
			[myItem setKeyEquivalent:[item keyEquivalent]];
		}	}

	[self selectItemWithTitle:[unarchiver decodeStringWithName:@"selectedItem"]];
	[self synchronizeTitleAndSelectedItem];

	return self;
}

@end /* NSPopUpButton (GMArchiverMethods) */


@implementation NSResponder (GMArchiverMethods)

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver
{
	id nextResponder;

	if ((nextResponder = [self nextResponder]))
		[archiver encodeObject:nextResponder withName:@"nextResponder"];
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	[self setNextResponder:[unarchiver decodeObjectWithName:@"nextResponder"]];

	return self;
}

@end /* NSResponder (GMArchiverMethods) */


@implementation NSScrollView (GMArchiverMethods)

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver
{
	[super encodeWithModelArchiver:archiver];
	
	[archiver encodeInt:[self borderType] withName:@"borderType"];
	[archiver encodeFloat:[self lineScroll] withName:@"lineScroll"];
	[archiver encodeBOOL:[self hasVerticalScroller] 
			  withName:@"hasVerticalScroller"];
	[archiver encodeBOOL:[self hasHorizontalScroller] 
			  withName:@"hasHorizontalScroller"];
	[archiver encodeObject:[self documentView] withName:@"documentView"];
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	id cv;

	self = [super initWithModelUnarchiver:unarchiver];
	
	[self setBorderType:[unarchiver decodeIntWithName:@"borderType"]];
	[self setLineScroll:[unarchiver decodeFloatWithName:@"lineScroll"]];
	[self setHasVerticalScroller:
			[unarchiver decodeBOOLWithName:@"hasVerticalScroller"]];
	[self setHasHorizontalScroller:
			[unarchiver decodeBOOLWithName:@"hasHorizontalScroller"]];

	if((cv = [unarchiver decodeObjectWithName:@"documentView"]))
		{
		if([cv class] != [NSView class])
			[self setDocumentView:cv];				// if decoded content view
		else										// is oridinary view just
			[cv release];							// use default content view
		}
	
	return self;
}

@end /* NSScrollView (GMArchiverMethods) */


@implementation NSSlider (GMArchiverMethods)

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver
{
	[super encodeWithModelArchiver:archiver];
	[archiver encodeBOOL:[_cell isBezeled] withName:@"isBezeled"];
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	self = [super initWithModelUnarchiver:unarchiver];

	[_cell setBezeled: [unarchiver decodeBOOLWithName:@"isBezeled"]];

	return self;
}

@end /* NSSlider (GMArchiverMethods) */


@implementation NSTextField (GMArchiverMethods)

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver
{
	id c = [self cell];

	[super encodeWithModelArchiver:archiver];
	
	[archiver encodeBOOL:[self isSelectable] withName:@"isSelectable"];
	[archiver encodeSelector:[self errorAction] withName:@"errorAction"];
	[archiver encodeObject:[self textColor] withName:@"textColor"];
	[archiver encodeObject:[self backgroundColor] withName:@"backgroundColor"];
	[archiver encodeBOOL:[self drawsBackground] withName:@"drawsBackground"];
	[archiver encodeBOOL:[self isBordered] withName:@"isBordered"];
	[archiver encodeBOOL:[self isBezeled] withName:@"isBezeled"];
	[archiver encodeObject:[self nextText] withName:@"nextText"];
	[archiver encodeObject:[self previousText] withName:@"previousText"];
	[archiver encodeObject:[self delegate] withName:@"delegate"];
	[archiver encodeString:[self stringValue] withName:@"stringValue"];
	[archiver encodeString:[c placeholderString] withName:@"placeholderString"];
	[archiver encodeBOOL:[self isEditable] withName:@"isEditable"];
	[archiver encodeBOOL:[c isScrollable] withName:@"isScrollable"];
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	id c = [self cell];
	NSColor *color;

	self = [super initWithModelUnarchiver:unarchiver];
	
	[self setSelectable:[unarchiver decodeBOOLWithName:@"isSelectable"]];
	[self setErrorAction:[unarchiver decodeSelectorWithName:@"errorAction"]];
	if((color = [unarchiver decodeObjectWithName:@"textColor"]))
		[self setTextColor: color];
	if((color = [unarchiver decodeObjectWithName:@"backgroundColor"]))
		[self setBackgroundColor: color];
	if([unarchiver decodeBOOLWithName:@"drawsBackground"] == NO)
		[self setDrawsBackground: NO];
	
	[self setBordered:[unarchiver decodeBOOLWithName:@"isBordered"]];
	[self setBezeled:[unarchiver decodeBOOLWithName:@"isBezeled"]];
	
	[self setNextText:[unarchiver decodeObjectWithName:@"nextText"]];
	[self setPreviousText:[unarchiver decodeObjectWithName:@"previousText"]];
	[self setDelegate:[unarchiver decodeObjectWithName:@"delegate"]];
	[c setStringValue:[unarchiver decodeStringWithName:@"stringValue"]];
	[c setPlaceholderString:[unarchiver decodeStringWithName:@"placeholderString"]];
	[self setEditable:[unarchiver decodeBOOLWithName:@"isEditable"]];
	[c setScrollable:[unarchiver decodeBOOLWithName:@"isScrollable"]];

	return self;
}

@end /* NSTextField (GMArchiverMethods) */


@implementation NSView (GMArchiverMethods)

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver
{
	[super encodeWithModelArchiver:archiver];
	
	[archiver encodeConditionalObject:[self superview] withName:@"superview"];
	[archiver encodeObject:[self subviews] withName:@"subviews"];
	[archiver encodeRect:[self frame] withName:@"frame"];
	[archiver encodeRect:[self bounds] withName:@"bounds"];
	[archiver encodeBOOL:[self postsFrameChangedNotifications]
			  withName:@"postsFrameChangedNotifications"];
	[archiver encodeBOOL:[self postsBoundsChangedNotifications]
			  withName:@"postsBoundsChangedNotifications"];
	[archiver encodeBOOL:[self autoresizesSubviews]
			  withName:@"autoresizesSubviews"];
	[archiver encodeUnsignedInt:[self autoresizingMask]
			  withName:@"autoresizingMask"];
}

+ (id) createObjectForModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	NSRect aRect = [unarchiver decodeRectWithName:@"frame"];

	return [[[self alloc] initWithFrame:aRect] autorelease];
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	NSArray *subviews;
	id k, superview, rep;
	NSString *v;

	superview = [unarchiver decodeObjectWithName:@"superview"];
	[superview addSubview:self];
	subviews = [unarchiver decodeObjectWithName:@"subviews"];
	[self setBounds:[unarchiver decodeRectWithName:@"bounds"]];

	rep = [unarchiver decodedObjectRepresentation];
	SET_BOOL(setPostsFrameChangedNotifications:,
			 @"postsFrameChangedNotifications")
	SET_BOOL(setPostsBoundsChangedNotifications:, 
			 @"postsBoundsChangedNotifications")
	SET_BOOL(setAutoresizesSubviews:, @"autoresizesSubviews")
	SET_INT(setAutoresizingMask:,	  @"autoresizingMask")
	if((k = [unarchiver decodeObjectWithName:@"nextKeyView"]))
		[self setNextKeyView: k];

	return [super initWithModelUnarchiver:unarchiver];
}

@end /* NSView (GMArchiverMethods) */


@implementation NSWindow (GMArchiverMethods)

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver
{
	[archiver encodeRect:[self frame] withName:@"frame"];
	[archiver encodeSize:[self maxSize] withName:@"maxSize"];
	[archiver encodeSize:[self minSize] withName:@"minSize"];
	[archiver encodeString:[self frameAutosaveName]
			  withName:@"frameAutosaveName"];
	[archiver encodeInt:[self level] withName:@"level"];
	[archiver encodeBOOL:[self isVisible] withName:@"isVisible"];
	[archiver encodeBOOL:[self isAutodisplay] withName:@"isAutodisplay"];
	[archiver encodeString:[self title] withName:@"title"];
	[archiver encodeString:[self representedFilename]
			  withName:@"representedFilename"];
	[archiver encodeBOOL:[self isReleasedWhenClosed]
			  withName:@"isReleasedWhenClosed"];
	[archiver encodeObject:[self contentView] withName:@"contentView"];
	[archiver encodeBOOL:[self hidesOnDeactivate]
			  withName:@"hidesOnDeactivate"];
	[archiver encodeObject:[self backgroundColor] withName:@"backgroundColor"];
	[archiver encodeUnsignedInt:[self styleMask] withName:@"styleMask"];
	[archiver encodeUnsignedInt:[self backingType] withName:@"backingType"];
}

+ (id) createObjectForModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	NSWindow *w = [self alloc];

	return [w initWithContentRect:[unarchiver decodeRectWithName:@"frame"]
			  styleMask:[unarchiver decodeUnsignedIntWithName:@"styleMask"] 
			  backing:[unarchiver decodeUnsignedIntWithName: @"backingType"] 
			  defer:YES
			  screen:nil];
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	NSString *v;
	NSColor *color;
	id initial, rep;

	[self setContentView:[unarchiver decodeObjectWithName:@"contentView"]];
	[self setMaxSize:[unarchiver decodeSizeWithName:@"maxSize"]];
	[self setMinSize:[unarchiver decodeSizeWithName:@"minSize"]];
	
	if ((v = [unarchiver decodeStringWithName:@"frameAutosaveName"]))
		[self setFrameAutosaveName: v];
	
	rep = [unarchiver decodedObjectRepresentation];
	SET_BOOL(setAutodisplay:,		 @"isAutodisplay")
	SET_BOOL(setReleasedWhenClosed:, @"isReleasedWhenClosed")
	SET_BOOL(setHidesOnDeactivate:,	 @"hidesOnDeactivate")
	SET_INT(setLevel:,				 @"level")

	[self setTitle:[unarchiver decodeStringWithName:@"title"]];
	if ((v = [unarchiver decodeStringWithName:@"representedFilename"]))
		[self setRepresentedFilename: v];
	if((initial = [unarchiver decodeObjectWithName:@"initialFirstResponder"]))
		[self setInitialFirstResponder: initial];
	if((color = [unarchiver decodeObjectWithName:@"backgroundColor"]))
		[self setBackgroundColor: color];

	return self;
}

@end /* NSWindow (GMArchiverMethods) */


@implementation NSPanel (GMArchiverMethods)

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver
{
	[super encodeWithModelArchiver:archiver];
    [archiver encodeBOOL:[self isFloatingPanel] withName:@"isFloatingPanel"];
    [archiver encodeBOOL:[self becomesKeyOnlyIfNeeded]
			  withName:@"becomesKeyOnlyIfNeeded"];
    [archiver encodeBOOL:[self worksWhenModal] withName:@"worksWhenModal"];
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver *)unarchiver
{
	id rep = [unarchiver decodedObjectRepresentation];
	NSString *v;

	SET_BOOL(setFloatingPanel:,			 @"isFloatingPanel")
	SET_BOOL(setBecomesKeyOnlyIfNeeded:, @"becomesKeyOnlyIfNeeded")
	SET_BOOL(setWorksWhenModal:,		 @"setWorksWhenModal")

    return [super initWithModelUnarchiver:unarchiver];
}

@end  /* NSPanel (GMArchiverMethods) */


@implementation NSSavePanel (GMArchiverMethods)

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver
{
	[super encodeWithModelArchiver:archiver];
    [archiver encodeString:[self prompt] withName:@"prompt"];
    [archiver encodeObject:[self accessoryView] withName:@"accessoryView"];
    [archiver encodeString:[self requiredFileType]
			  withName:@"requiredFileType"];
    [archiver encodeBOOL:[self treatsFilePackagesAsDirectories]
			  withName:@"treatsFilePackagesAsDirectories"];
    [archiver encodeString:[self directory] withName:@"directory"];
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver *)unarchiver
{
    [self setPrompt:[unarchiver decodeStringWithName:@"prompt"]];
    [self setAccessoryView:[unarchiver decodeObjectWithName:@"accessoryView"]];
    [self setRequiredFileType:
          [unarchiver decodeStringWithName:@"requiredFileType"]];
    [self setTreatsFilePackagesAsDirectories:
          [unarchiver decodeBOOLWithName:@"treatsFilePackagesAsDirectories"]];
    [self setDirectory:[unarchiver decodeStringWithName:@"directory"]];

    return [super initWithModelUnarchiver:unarchiver];
}

@end  /* NSSavePanel (GMArchiverMethods) */


@implementation NSBrowser (GMArchiverMethods)

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver
{
    [super encodeWithModelArchiver:archiver];
																// NSBrowser
    [archiver encodeString:[self path] withName:@"path"];
    [archiver encodeString:[self pathSeparator] withName:@"pathSeparator"];
    [archiver encodeBOOL:[self allowsBranchSelection] 
			  withName:@"allowsBranchSelection"];
    [archiver encodeBOOL:[self allowsEmptySelection]
			  withName:@"allowsEmptySelection"];
    [archiver encodeBOOL:[self allowsMultipleSelection]
			  withName:@"allowsMultipleSelection"];
    [archiver encodeBOOL:[self reusesColumns] withName:@"reusesColumns"];
    [archiver encodeUnsignedInt:[self maxVisibleColumns]
			  withName:@"maxVisibleColumns"];
    [archiver encodeUnsignedInt:[self minColumnWidth]
			  withName:@"minColumnWidth"];
    [archiver encodeBOOL:[self separatesColumns]
			  withName:@"separatesColumns"];
    [archiver encodeBOOL:[self takesTitleFromPreviousColumn]
			  withName:@"takesTitleFromPreviousColumn"];
    [archiver encodeBOOL:[self isTitled] withName:@"isTitled"];
    [archiver encodeBOOL:[self hasHorizontalScroller]
			  withName:@"hasHorizontalScroller"];
    [archiver encodeBOOL:[self autohidesScroller]
			  withName:@"autohidesScroller"];
    [archiver encodeBOOL:[self sendsActionOnArrowKeys]
			  withName:@"sendsActionOnArrowKeys"];

    [archiver encodeObject:[self delegate] withName:@"delegate"];
    [archiver encodeSelector:[self doubleAction] withName:@"doubleAction"];
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver *)unarchiver
{
	id delegate, rep;
	NSString *v;

    [self setPath:[unarchiver decodeStringWithName:@"path"]];
    [self setPathSeparator:[unarchiver decodeStringWithName:@"pathSeparator"]];

	rep = [unarchiver decodedObjectRepresentation];
	SET_BOOL(setTakesTitleFromPreviousColumn:, @"takesTitleFromPreviousColumn")
	SET_BOOL(setAllowsBranchSelection:,		   @"allowsBranchSelection")
	SET_BOOL(setAllowsEmptySelection:,		   @"allowsEmptySelection")
	SET_BOOL(setAllowsMultipleSelection:,	   @"allowsMultipleSelection")
	SET_BOOL(setReusesColumns:,				   @"reusesColumns")
	SET_BOOL(setSeparatesColumns:,			   @"separatesColumns")
	SET_BOOL(setTitled:,					   @"isTitled")
	SET_BOOL(setHasHorizontalScroller:,		   @"hasHorizontalScroller")
	SET_BOOL(setAutohidesScroller:,			   @"autohidesScroller")
	SET_BOOL(setSendsActionOnArrowKeys:,	   @"sendsActionOnArrowKeys")

	SET_INT(setMaxVisibleColumns:,			   @"maxVisibleColumns")
	SET_INT(setMinColumnWidth:,				   @"minColumnWidth")

    if ((delegate = [unarchiver decodeObjectWithName:@"delegate"]))
		[self setDelegate:delegate];

    [self setDoubleAction:[unarchiver decodeSelectorWithName:@"doubleAction"]];

    return [super initWithModelUnarchiver:unarchiver];
}

@end  /* NSBrowser (GMArchiverMethods) */


@implementation NSImageView (GMArchiverMethods)

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver
{
	[archiver encodeObject:[self image] withName:@"image"];
	[archiver encodeUnsignedInt:[self imageScaling] withName:@"scaling"];
	[archiver encodeUnsignedInt:[self imageAlignment] withName:@"alignment"];
	[archiver encodeUnsignedInt:[self imageFrameStyle] withName:@"frameStyle"];

	[super encodeWithModelArchiver:archiver];
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	NSString *v;
	id rep;

	self = [super initWithModelUnarchiver:unarchiver];
	
	[self setImage:[unarchiver decodeObjectWithName:@"image"]];
	rep = [unarchiver decodedObjectRepresentation];
	SET_INT(setImageScaling:,			@"scaling")
	SET_INT(setImageAlignment:,			@"alignment")
	SET_INT(setImageFrameStyle:,		@"frameStyle")

	return self;
}

@end /* NSImageView (GMArchiverMethods) */


@implementation NSForm (GMArchiverMethods)

- (void) encodeWithModelArchiver:(NSKeyedArchiver*)archiver
{
	[super encodeWithModelArchiver:archiver];
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	return (self = [super initWithModelUnarchiver:unarchiver]);
}

@end /* NSForm (GMArchiverMethods) */

/* ****************************************************************************

	Foundation Model Archive  (obsolete keyed property list archive format)

	Declare categories to various OpenStep classes so they get archived
	correctly by NSKeyedArchiver (Model). The main things deal with encoding
	in place of some objects like immutable strings, arrays, dictionaries
	and data objects (basically the property list classes).
	
	Included by NSKeyedArchiver rather than compiled as a separate file
	because of the linking problems with categories (they are not linked into
	the executable even if you refer a method from category; you should refer
	a symbol from the category's file in order to force it link.

** ***************************************************************************/


@implementation NSObject (ModelArchivingMethods)

- (id) replacementObjectForModelArchiver:(NSKeyedArchiver*)archiver
{
	return [self replacementObjectForCoder:nil];
}

- (Class) classForModelArchiver				{ return [self classForCoder]; }

+ (id) createObjectForModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	return [[[self alloc] init] autorelease];
}

@end


@implementation NSString (ModelArchivingMethods)

- (void) encodeWithModelArchiver:(id)archiver
{
	[archiver encodeString:self withName:@"string"];
}

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	return [unarchiver decodeStringWithName:@"string"];
}

- (Class) classForModelArchiver				{ return [NSString class]; }

@end


@implementation NSMutableString (ModelArchivingMethods)

- (Class) classForModelArchiver			{ return [NSMutableString class]; }

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)u
{
	return [[[u decodeStringWithName:@"string"] mutableCopy] autorelease];
}

@end


@implementation NSArray (ModelArchivingMethods)

- (void) encodeWithModelArchiver:(id)archiver
{
	[archiver encodeArray:self withName:@"elements"];
}

- (Class) classForModelArchiver			{ return [NSMutableArray class]; }

@end


@implementation NSMutableArray (ModelArchivingMethods)

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	id array = [unarchiver decodeArrayWithName:@"elements"];
	int i, count;

	for (i = 0, count = [array count]; i < count; i++)
		[self addObject:[array objectAtIndex:i]];

	return self;
}

@end


@implementation NSDictionary (ModelArchivingMethods)

- (void) encodeWithModelArchiver:(id)archiver
{
	[archiver encodeDictionary:self withName:@"elements"];
}

- (Class) classForModelArchiver		{ return [NSMutableDictionary class]; }

@end


@implementation NSMutableDictionary (ModelArchivingMethods)

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	id dictionary = [unarchiver decodeDictionaryWithName:@"elements"];
	id key, enumerator = [dictionary keyEnumerator];

	while ((key = [enumerator nextObject])) 
		[self setObject:[dictionary objectForKey:key] forKey:key];

	return self;
}

@end


@implementation NSData (ModelArchivingMethods)

- (void) encodeWithModelArchiver:(id)archiver
{
	[archiver encodeData:self withName:@"data"];
}

- (Class) classForModelArchiver			{ return [NSMutableData class]; }

@end


@implementation NSMutableData (ModelArchivingMethods)

- (id) initWithModelUnarchiver:(NSKeyedUnarchiver*)unarchiver
{
	[self appendData:[unarchiver decodeDataWithName:@"data"]];

	return self;
}

@end
