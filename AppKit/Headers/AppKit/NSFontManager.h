/*
   NSFontManager.h

   Manages system and user fonts

   Copyright (C) 1996-2016 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
   Date:	1996

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSFontManager
#define _mGSTEP_H_NSFontManager

#include <Foundation/NSObject.h>

@class NSString;
@class NSArray;
@class NSFont;
@class NSMenu;
@class NSFontPanel;


typedef NSUInteger NSFontTraitMask;  enum {
	NSItalicFontMask     = 1,
	NSBoldFontMask       = 2,
	NSUnboldFontMask     = 4,
	NSNonStandardCharacterSetFontMask = 8,
	NSNarrowFontMask     = 16,
	NSExpandedFontMask   = 32,
	NSCondensedFontMask  = 64,
	NSSmallCapsFontMask  = 128,
	NSPosterFontMask     = 256,
	NSCompressedFontMask = 512,
	NSUnitalicFontMask   = 1024
};

typedef NSUInteger NSFontAction;  enum {	// Font menu cell tags (actions)
	NSNoFontChangeAction    = 0,
	NSViaPanelFontAction    = 1,
	NSAddTraitFontAction    = 2,
	NSSizeUpFontAction      = 3,
	NSSizeDownFontAction    = 4,
	NSHeavierFontAction     = 5,
	NSLighterFontAction     = 6,
	NSRemoveTraitFontAction = 7
};


@interface NSFontManager : NSObject
{
    id _target;
	SEL _action;
	NSFont *_selectedFont;
	NSArray *_availableFonts;
	NSMenu *_fontMenu;

	struct __FontManagerFlags {
        unsigned int senderTagMode:3;
		unsigned int isEnabled:1;
		unsigned int multipleFont:1;
		unsigned int reserved:27;
	} _fm;
}

+ (NSFontManager *) sharedFontManager;

+ (void) setFontManagerFactory:(Class)cls;
+ (void) setFontPanelFactory:(Class)cls;

- (NSFont *) convertFont:(NSFont *)fontObject;
- (NSFont *) convertFont:(NSFont *)fontObject toFamily:(NSString *)family;
- (NSFont *) convertFont:(NSFont *)fontObject toFace:(NSString *)typeface;
- (NSFont *) convertFont:(NSFont *)fontObject toHaveTrait:(NSFontTraitMask)t;
- (NSFont *) convertFont:(NSFont *)fontObject toNotHaveTrait:(NSFontTraitMask)t;
- (NSFont *) convertFont:(NSFont *)fontObject toSize:(float)size;
- (NSFont *) convertWeight:(BOOL)upFlag ofFont:(NSFont *)fontObject;
- (NSFont *) fontWithFamily:(NSString *)family
					 traits:(NSFontTraitMask)traits
					 weight:(int)weight
					 size:(float)size;
- (SEL) action;
- (void) setAction:(SEL)aSelector;

- (BOOL) isEnabled;
- (BOOL) isMultiple;
- (void) setEnabled:(BOOL)flag;
- (void) setFontMenu:(NSMenu *)newMenu;
- (NSFontTraitMask) traitsOfFont:(NSFont *)fontObject;
- (int) weightOfFont:(NSFont *)fontObject;

- (void) setSelectedFont:(NSFont *)fontObject isMultiple:(BOOL)flag;
- (NSFont *) selectedFont;

- (BOOL) sendAction;

- (NSArray *) availableFonts;
- (NSMenu *) fontMenu:(BOOL)create;
- (NSFontPanel *) fontPanel:(BOOL)create;

@end


@interface NSFontManager  (NSFontManagerMenuActionMethods)

- (void) orderFrontFontPanel:(id)sender;
- (void) orderFrontStylesPanel:(id)sender;

- (void) modifyFont:(id)sender;							// sends default action
- (void) modifyFontViaPanel:(id)sender;					// changeFont:

- (void) addFontTrait:(id)sender;
- (void) removeFontTrait:(id)sender;

@end


@interface NSObject  (NSFontManagerResponderMethod)		// OSX deprecated 10.14

- (void) changeFont:(id)fontManager;

@end

#endif /* _mGSTEP_H_NSFontManager */
