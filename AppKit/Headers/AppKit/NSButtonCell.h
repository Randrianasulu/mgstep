/*
   NSButtonCell.h

   Button cell class for NSButton

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@pcmagic.net>
   Date:    June 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSButtonCell
#define _mGSTEP_H_NSButtonCell

#include <AppKit/NSActionCell.h>

@class NSFont;

typedef enum _NSButtonType {
    NSMomentaryLightButton = 0,
	NSPushOnPushOffButton,
	NSToggleButton,
	NSSwitchButton,
	NSRadioButton,
	NSMomentaryChangeButton,
	NSOnOffButton,
	NSMomentaryPushInButton,

    NSMomentaryPushButton = 0,				// old names
	NSMomentaryLight      = 7
} NSButtonType;


typedef enum {
    NSRoundedBezelStyle			  = 1,
    NSRegularSquareBezelStyle	  = 2,
    NSThickSquareBezelStyle		  = 3,
    NSThickerSquareBezelStyle	  = 4,
    NSDisclosureBezelStyle		  = 5,
    NSShadowlessSquareBezelStyle  = 6,
    NSCircularBezelStyle		  = 7,
    NSTexturedSquareBezelStyle	  = 8,
    NSHelpButtonBezelStyle		  = 9,
    NSSmallSquareBezelStyle		  = 10,
    NSTexturedRoundedBezelStyle	  = 11,
    NSRoundRectBezelStyle		  = 12,
    NSRecessedBezelStyle		  = 13,
    NSRoundedDisclosureBezelStyle = 14,
    NSInlineBezelStyle            = 15
} NSBezelStyle;


@interface NSButtonCell : NSActionCell  <NSCopying, NSCoding>
{
	NSImage *_normalImage;
	NSImage *_alternateImage;
	NSString *_alternateContents;
	NSString *_keyEquivalent;
	NSFont *_keyEquivalentFont;
	unsigned int _keyEquivalentModifierMask;
	unsigned int _highlightMask;
	unsigned int _stateMask;
    float _periodicDelay;
    float _periodicInterval;

    struct __ButtonCellFlags {
		unsigned int transparent:1;
		NSBezelStyle bezelStyle:4;
		unsigned int showsBorderOnlyWhileMI:1;
		unsigned int mouseInside:1;
		unsigned int reserved:1;
	} _bc;
}

- (NSString *) title;
- (NSString *) alternateTitle;
- (void) setTitle:(NSString *)aString;
- (void) setAlternateTitle:(NSString *)aString;
- (void) setFont:(NSFont *)fontObject;

- (NSImage *) alternateImage;
- (NSCellImagePosition) imagePosition;
- (void) setAlternateImage:(NSImage *)anImage;
- (void) setImagePosition:(NSCellImagePosition)aPosition;
															// Repeat Interval 
- (void) getPeriodicDelay:(float *)delay interval:(float *)interval;
- (void) setPeriodicDelay:(float)delay interval:(float)interval;

- (NSString *) keyEquivalent;								// Key Equivalent
- (unsigned int) keyEquivalentModifierMask;
- (void) setKeyEquivalent:(NSString *)aKeyEquivalent;
- (void) setKeyEquivalentModifierMask:(unsigned int)mask;
- (void) setKeyEquivalentFont:(NSFont *)fontObj;
- (void) setKeyEquivalentFont:(NSString *)fontName size:(float)fontSize;
- (NSFont *) keyEquivalentFont;

- (BOOL) isTransparent;
- (void) setTransparent:(BOOL)flag;
- (int) highlightsBy;
- (int) showsStateBy;
- (void) setHighlightsBy:(int)aType;
- (void) setShowsStateBy:(int)aType;
- (void) setButtonType:(NSButtonType)aType;
- (void) setBezelStyle:(NSBezelStyle)bezelStyle;
- (NSBezelStyle) bezelStyle;

- (void) performClick:(id)sender;							// Simulate a Click

@end

#endif /* _mGSTEP_H_NSButtonCell */
