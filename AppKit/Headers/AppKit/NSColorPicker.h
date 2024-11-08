/*
   NSColorPicker.h

   Color picker class and associated protocols

   Copyright (C) 1997 Free Software Foundation, Inc.

   Author:  Simon Frankau <sgf@frankau.demon.co.uk>
   Date: 	1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSColorPicker
#define _mGSTEP_H_NSColorPicker

#include <Foundation/NSObject.h>
#include <Foundation/Protocol.h>

@class NSColorPanel;
@class NSView;
@class NSColorList;
@class NSImage;
@class NSButtonCell;


@protocol NSColorPickingCustom

- (int) currentMode;
- (BOOL) supportsMode:(int)mode;
- (NSView *) provideNewView:(BOOL)firstRequest;
- (void) setColor:(NSColor *)aColor;

@end


@protocol NSColorPickingDefault

- (id) initWithPickerMask:(int)mask colorPanel:(NSColorPanel *)colorPanel;

- (void) insertNewButtonImage:(NSImage *)newImage 
						   in:(NSButtonCell *)newButtonCell;
- (NSImage *) provideNewButtonImage;
- (void) setMode:(int)mode;

- (void) attachColorList:(NSColorList *)aColorList;				// Color Lists
- (void) detachColorList:(NSColorList *)aColorList;

- (void) alphaControlAddedOrRemoved:(id)sender;
- (void) viewSizeChanged:(id)sender;

@end


@interface NSColorPicker : NSObject <NSColorPickingDefault>
{
	NSColorPanel *_colorPanel;
}

- (id) initWithPickerMask:(int)aMask colorPanel:(NSColorPanel *)colorPanel;

- (NSColorPanel *) colorPanel;

- (void) insertNewButtonImage:(NSImage *)newImage 
						   in:(NSButtonCell *)newButtonCell;
- (NSImage *) provideNewButtonImage;

- (void) setMode:(int)mode;
- (void) attachColorList:(NSColorList *)colorList;
- (void) detachColorList:(NSColorList *)colorList;
- (void) alphaControlAddedOrRemoved:(id)sender;
- (void) viewSizeChanged:(id)sender;

@end

#endif /* _mGSTEP_H_NSColorPicker */
