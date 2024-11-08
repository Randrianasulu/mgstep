/*
   NSStringDrawing.h

   Draw and Measure categories of NSString and NSAttributedString 

   Copyright (C) 1997 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@ix.netcom.com>
   Date:    Aug 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSStringDrawing
#define _mGSTEP_H_NSStringDrawing

#include <Foundation/NSString.h>
#include <Foundation/NSAttributedString.h>
#include <Foundation/NSGeometry.h>

						// global NSString attribute names used in ascessing  
						// the respective property in a text attributes 
						// dictionary.  if the key is not in the dictionary 	
						// the default value is assumed  											
extern NSString *NSFontAttributeName;    			// NSFont, Helvetica 12
extern NSString *NSParagraphStyleAttributeName;	 	// defaultParagraphStyle
extern NSString *NSForegroundColorAttributeName; 	// NSColor, blackColor
extern NSString *NSUnderlineStyleAttributeName;   	// NSNumber int, 0 no line 	 
extern NSString *NSSuperscriptAttributeName;      	// NSNumber int, 0		 
extern NSString *NSBackgroundColorAttributeName;	// NSColor, nil	
extern NSString *NSAttachmentAttributeName;         // NSTextAttachment, nil	 
extern NSString *NSLigatureAttributeName;			// NSNumber int, 1 
extern NSString *NSBaselineOffsetAttributeName;  	// NSNumber float, 0 points 
extern NSString *NSKernAttributeName;				// NSNumber float, 0
//
//	Extended definitions:
//
//		NSParagraphStyleAttributeName		NSParagraphStyle, default is 
//											defaultParagraphStyle
//
//		NSKernAttributeName					NSNumber float, offset from 
//		 									baseline, amount to modify default 
//											kerning, if 0 kerning is off		 	 

enum 									
{											// Currently supported values for
    NSSingleUnderlineStyle = 1				// NSUnderlineStyleAttributeName
};


@interface NSString (GSStringDrawing)

- (void) drawAtPoint:(NSPoint)point withAttributes:(NSDictionary *)attrs;
- (void) drawInRect:(NSRect)rect withAttributes:(NSDictionary *)attrs;
- (NSSize) sizeWithAttributes:(NSDictionary *)attrs;

@end


@interface NSAttributedString (GSStringDrawing)

- (void) drawAtPoint:(NSPoint)point;
- (void) drawInRect:(NSRect)rect;
- (NSSize) size;

@end

#endif /* _mGSTEP_H_NSStringDrawing */
