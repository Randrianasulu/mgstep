/*
   NSCell.h

   Display contents and performs actions for a view.

   Copyright (C) 2000-2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    June 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSCell
#define _mGSTEP_H_NSCell

#include <Foundation/NSObject.h>
#include <Foundation/NSGeometry.h>
#include <AppKit/NSText.h>

@class NSString;
@class NSFormatter;
@class NSView;
@class NSFont;
@class NSMenu;

typedef enum {
	NSNullCellType  = 0,
	NSTextCellType  = 1,
	NSImageCellType = 2
} NSCellType;

typedef enum {
	NSNoImage = 0,
	NSImageOnly,
	NSImageLeft,
	NSImageRight,
	NSImageBelow,
	NSImageAbove,
	NSImageOverlaps
} NSCellImagePosition;

typedef enum {
	NSCellDisabled,
	NSCellState,
	NSPushInCell,
	NSCellEditable,
	NSChangeGrayCell,
	NSCellHighlighted,   
	NSCellLightsByContents,  
	NSCellLightsByGray,   
	NSChangeBackgroundCell,  
	NSCellLightsByBackground,  
	NSCellIsBordered,  
	NSCellHasOverlappingImage,  
	NSCellHasImageHorizontal,  
	NSCellHasImageOnLeftOrBottom, 
	NSCellChangesContents,  
	NSCellIsInsetButton
//  NSCellAllowsMixedState = 16
} NSCellAttribute;

typedef enum {
	NSMixedState = -1,			// NSInteger
	NSOffState	 =  0,
	NSOnState	 =  1
} NSCellStateValue;

enum {
	NSNoCellMask				= 0,
	NSContentsCellMask			= 1,
	NSPushInCellMask			= 2,
	NSChangeGrayCellMask		= 4,
	NSChangeBackgroundCellMask	= 8
};


@interface NSCell : NSObject  <NSCopying, NSCoding>
{
	id _contents;
	id _controlView;
	id _representedObject;

	NSFont *_font;
	NSFormatter *_formatter;

	struct __CellFlags {
		unsigned int state:2;
		unsigned int highlighted:1;
		unsigned int enabled:1;
		unsigned int editable:1;
		unsigned int bordered:1;
		unsigned int bezeled:1;
		unsigned int scrollable:1;
		unsigned int selectable:1;
		unsigned int continuous:1;
		unsigned int actOnMouseDown:1;
		unsigned int actOnMouseDragged:1;
		unsigned int dontActOnMouseUp:1;
		unsigned int cellSubclass:1;
		NSCellType type:2;
		NSTextAlignment alignment:3;
		NSCellImagePosition imagePosition:3;
		unsigned int editing:1;
		unsigned int secure:1;
		unsigned int isLoaded:1;
		unsigned int isLeaf:1;
		unsigned int drawsBackground:1;
		unsigned int allowsMixedState:1;
//		unsigned int entryType:2;						// OS X deprecated
		unsigned int wraps:1;
		unsigned int showsFirstResponder:1;
		unsigned int refusesFirstResponder:1;
		unsigned int reserved:1;
	} _c;
}

- (id) initImageCell:(NSImage*)anImage;
- (id) initTextCell:(NSString*)aString;

- (void) calcDrawInfo:(NSRect)aRect;					// Component sizes
- (NSSize) cellSize;
- (NSSize) cellSizeForBounds:(NSRect)aRect;
- (NSRect) drawingRectForBounds:(NSRect)theRect;
- (NSRect) imageRectForBounds:(NSRect)theRect;
- (NSRect) titleRectForBounds:(NSRect)theRect;

- (void) setType:(NSCellType)aType;
- (NSCellType) type;

- (void) setState:(int)value;
- (int) state;

- (BOOL) isEnabled;
- (void) setEnabled:(BOOL)flag;

- (NSImage*) image;
- (void) setImage:(NSImage *)anImage;

- (NSString *) title;
- (void) setTitle:(NSString *)title;

- (double) doubleValue;
- (float) floatValue;
- (int) intValue;
- (id) objectValue;
- (NSString*) stringValue;

- (void) setDoubleValue:(double)aDouble;
- (void) setFloatValue:(float)aFloat;
- (void) setIntValue:(int)anInt;
- (void) setObjectValue:(id)anObject;
- (void) setStringValue:(NSString*)aString;

- (void) takeDoubleValueFrom:(id)sender;				// Cell Interaction
- (void) takeFloatValueFrom:(id)sender;
- (void) takeIntValueFrom:(id)sender;
- (void) takeObjectValueFrom:(id)sender;
- (void) takeStringValueFrom:(id)sender;

- (NSTextAlignment) alignment;							// Text Attributes
- (NSFont*) font;
- (BOOL) isEditable;
- (BOOL) isSelectable;
- (BOOL) isScrollable;
- (void) setAlignment:(NSTextAlignment)mode;
- (void) setEditable:(BOOL)flag;
- (void) setFont:(NSFont *)fontObject;
- (void) setSelectable:(BOOL)flag;
- (void) setScrollable:(BOOL)flag;
- (NSText*) setUpFieldEditorAttributes:(NSText*)textObject;
- (void) setWraps:(BOOL)flag;
- (BOOL) wraps;

- (void) editWithFrame:(NSRect)aRect					// Text Editing
				inView:(NSView*)controlView	
				editor:(NSText*)textObject	
				delegate:(id)anObject	
				event:(NSEvent*)event;
- (void) endEditing:(NSText*)textObject;
- (void) selectWithFrame:(NSRect)aRect
				  inView:(NSView*)controlView	 
				  editor:(NSText*)textObject	 
				  delegate:(id)anObject	 
				  start:(int)selStart	 
				  length:(int)selLength;

- (void) setFormatter:(NSFormatter*)newFormatter;		// Formatting Data
- (id) formatter;

- (BOOL) hasValidObjectValue;
- (BOOL) isEntryAcceptable:(NSString*)aString;			// OSX deprecated

- (BOOL) isBezeled;										// Graphic Attributes
- (BOOL) isBordered;
- (BOOL) isOpaque;
- (void) setBezeled:(BOOL)flag;
- (void) setBordered:(BOOL)flag;

- (int) cellAttribute:(NSCellAttribute)aParameter;		// Setting Parameters
- (void) setCellAttribute:(NSCellAttribute)aParameter to:(int)value;

- (void) highlight:(BOOL)lit							// Drawing the cell
		 withFrame:(NSRect)cellFrame
		 inView:(NSView*)controlView;
- (BOOL) isHighlighted;
- (void) setHighlighted:(BOOL)flag;

- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView*)controlView;
- (void) drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView*)controlView;

- (NSView *) controlView;

- (SEL) action;											// Target / Action
- (BOOL) isContinuous;
- (int) sendActionOn:(int)mask;
- (void) performClick:(id)sender;
- (void) setAction:(SEL)aSelector;
- (void) setContinuous:(BOOL)flag;
- (void) setTarget:(id)anObject;
- (id) target;

- (void) setTag:(int)anInt;								// Assigning a Tag
- (int) tag;

- (NSString*) keyEquivalent;							// Keyboard Alternative

+ (BOOL) prefersTrackingUntilMouseUp;					// Tracking the Mouse
- (BOOL) continueTracking:(NSPoint)lastPoint
					   at:(NSPoint)currentPoint
					   inView:(NSView*)controlView;
- (int) mouseDownFlags;
- (void) getPeriodicDelay:(float*)delay interval:(float*)interval;
- (BOOL) startTrackingAt:(NSPoint)startPoint inView:(NSView*)controlView;
- (void) stopTracking:(NSPoint)lastPoint
				   at:(NSPoint)stopPoint
				   inView:(NSView*)controlView
				   mouseIsUp:(BOOL)flag;
- (BOOL) trackMouse:(NSEvent*)event
			 inRect:(NSRect)cellFrame
			 ofView:(NSView*)controlView
			 untilMouseUp:(BOOL)flag;
														// Managing the Cursor 
- (void) resetCursorRect:(NSRect)cellFrame inView:(NSView*)controlView;

- (NSComparisonResult) compare:(id)otherCell;			// Compare NSCell's

- (id) representedObject;								// Represent an Object
- (void) setRepresentedObject:(id)anObject;

+ (NSMenu *) defaultMenu;								// Context menus
- (NSMenu *) menu;
- (NSMenu *) menuForEvent:(NSEvent *)event
				   inRect:(NSRect)cellFrame
				   ofView:(NSView *)view;
- (void) setMenu:(NSMenu *)aMenu;

@end


@interface NSCell (NSKeyboardUI)

- (void) setRefusesFirstResponder:(BOOL)flag;
- (BOOL) refusesFirstResponder;
- (BOOL) acceptsFirstResponder;
- (BOOL) showsFirstResponder;
- (void) setShowsFirstResponder:(BOOL)flag;

@end


@interface NSCell (NSCellMixedState)

- (BOOL) allowsMixedState;
- (void) setAllowsMixedState:(BOOL)flag;
- (void) setNextState;
- (NSInteger) nextState;

@end


@interface NSCell (NotImplemented)

+ (NSFocusRingType) defaultFocusRingType;
- (NSFocusRingType) focusRingType;
- (void) setFocusRingType:(NSFocusRingType)type;
- (void) drawFocusRingMaskWithFrame:(NSRect)cellFrame inView:(NSView *)control;
- (NSRect) focusRingMaskBoundsForFrame:(NSRect)cellFrame inView:(NSView *)cv;

- (void) setTruncatesLastVisibleLine:(BOOL)flag;		// trunc with ellipsis
- (void) setSendsActionOnEndEditing:(BOOL)flag;
- (void) setUsesSingleLineMode:(BOOL)flag;
//- (void) setBaseWritingDirection:(NSWritingDirection)writingDirection;
//- (void) setLineBreakMode:(NSLineBreakMode)mode;
- (void) setAllowsUndo:(BOOL)allowsUndo;

- (BOOL) allowsUndo;
- (BOOL) usesSingleLineMode;
- (BOOL) sendsActionOnEndEditing;
- (BOOL) truncatesLastVisibleLine;
//- (NSWritingDirection) baseWritingDirection;
//- (NSLineBreakMode) lineBreakMode;

@end


enum {
	NSCellHitNone             = 0,			// empty or no hit
	NSCellHitContentArea      = 1 << 0,		// hit in cell contents area
	NSCellHitEditableTextArea = 1 << 1,
	NSCellHitTrackableArea    = 1 << 2,
};

@interface NSCell (NSCellHitTest)

- (NSUInteger) hitTestForEvent:(NSEvent *)event
			   inRect:(NSRect)cellFrame
			   ofView:(NSView *)controlView;
@end

#endif /* _mGSTEP_H_NSCell */
