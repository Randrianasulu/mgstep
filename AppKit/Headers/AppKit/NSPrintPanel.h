/*
   NSPrintPanel.h

   Standard printer panel

   Copyright (C) 2009 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Nov 2009

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSPrintPanel
#define _mGSTEP_H_NSPrintPanel

#include <AppKit/NSPanel.h>

@class NSPrintInfo;


@interface NSPrintPanel : NSPanel

+ (NSPrintPanel *) printPanel;

- (int) runModal;

@end


@interface NSPageLayout : NSPanel
@end

@interface NSPageLayout  (NotImplemented)

+ (NSPageLayout *) pageLayout;

- (int) runModal;
- (int) runModalWithPrintInfo:(NSPrintInfo *)pInfo;

- (NSPrintInfo *) printInfo;
- (void) readPrintInfo;
- (void) writePrintInfo;

@end

#endif /* _mGSTEP_H_NSPrintPanel */
