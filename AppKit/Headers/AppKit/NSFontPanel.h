/*
   NSFontPanel.h

   System font selection and preview panel.

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
   Date: 1996

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSFontPanel
#define _mGSTEP_H_NSFontPanel

#include <AppKit/NSPanel.h>

@class NSFont;
@class NSView;
@class NSMatrix;
@class NSTextField;


@interface NSFontPanel : NSPanel
{
    NSTextField *_fontDemo;
    NSTextField *_fontDescription;
    NSTextField *_fontSize;
    NSMatrix    *_fontSizes;
}

+ (NSFontPanel *) sharedFontPanel;

- (void) setPanelFont:(NSFont *)fontObject isMultiple:(BOOL)flag;

- (NSFont *) panelConvertFont:(NSFont *)fontObject;

- (NSView *) accessoryView;								// Panel configuration
- (void) setAccessoryView:(NSView *)aView;
- (void) setEnabled:(BOOL)flag;
- (BOOL) isEnabled;
- (BOOL) worksWhenModal;

@end

#endif /* _mGSTEP_H_NSFontPanel */
