/*
   NSButton.h

   Button control class

   Copyright (C) 1996-2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@pcmagic.net>
   Date:    June 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSButton
#define _mGSTEP_H_NSButton

#include <AppKit/NSControl.h>
#include <AppKit/NSButtonCell.h>

@class NSString;
@class NSEvent;


@interface NSButton : NSControl  <NSCoding>

+ (Class) cellClass;
+ (void) setCellClass:(Class)aClass;

- (void) setButtonType:(NSButtonType)aType;

- (void) setState:(int)value;
- (int) state;
														// Repeat interval 
- (void) getPeriodicDelay:(float *)delay interval:(float *)interval;
- (void) setPeriodicDelay:(float)delay interval:(float)interval;

- (void) setTitle:(NSString *)aString;
- (void) setAlternateTitle:(NSString *)aString;
- (NSString *) alternateTitle;
- (NSString *) title;

- (void) setImage:(NSImage *)anImage;
- (void) setAlternateImage:(NSImage *)anImage;
- (void) setImagePosition:(NSCellImagePosition)aPosition;
- (NSImage *) alternateImage;
- (NSImage *) image;
- (NSCellImagePosition) imagePosition;

- (BOOL) isBordered;									// Graphic attributes
- (BOOL) isTransparent;
- (void) setBordered:(BOOL)flag;
- (void) setTransparent:(BOOL)flag;
- (void) highlight:(BOOL)flag;

- (NSString *) keyEquivalent;							// Key equivalent
- (unsigned int) keyEquivalentModifierMask;
- (void) setKeyEquivalent:(NSString *)aKeyEquivalent;
- (void) setKeyEquivalentModifierMask:(unsigned int)mask;
- (BOOL) performKeyEquivalent:(NSEvent *)anEvent;		// Simulate user action

@end


@interface NSButton (NSButtonMixedState)

- (void) setNextState;
- (void) setAllowsMixedState:(BOOL)flag;
- (BOOL) allowsMixedState;

@end

@interface NSButton (NSButtonAttributedStringMethods)

//- (NSAttributedString *) attributedTitle;
//- (NSAttributedString *) attributedAlternateTitle;
//- (void) setAttributedTitle:(NSAttributedString *)aString;
//- (void) setAttributedAlternateTitle:(NSAttributedString *)aString;

@end

@interface NSButton (NSButtonBorder)

- (void) setShowsBorderOnlyWhileMouseInside:(BOOL)show;
- (BOOL) showsBorderOnlyWhileMouseInside;

@end

@interface NSButton (NSButtonSoundExtensions)

//- (void) setSound:(NSSound *)aSound;
//- (NSSound *) sound;

@end

#endif /* _mGSTEP_H_NSButton */
