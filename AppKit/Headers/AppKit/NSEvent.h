/*
   NSEvent.h

   Event translation

   Copyright (C) 1996-2021 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
   Date: 1996

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSEvent
#define _mGSTEP_H_NSEvent

#include <Foundation/NSCoder.h>
#include <Foundation/NSGeometry.h>
#include <Foundation/NSDate.h>

@class NSString;
@class NSWindow;
@class NSGraphicsContext;


typedef enum _NSEventType {
	NSLeftMouseDown				= 1,
	NSLeftMouseUp				= 2,
	NSRightMouseDown			= 3,
	NSRightMouseUp				= 4,
    NSMouseMoved                = 5,
    NSLeftMouseDragged          = 6,
    NSRightMouseDragged         = 7,
    NSMouseEntered              = 8,
    NSMouseExited               = 9,
    NSKeyDown                   = 10,
    NSKeyUp                     = 11,
    NSFlagsChanged              = 12,
    NSAppKitDefined             = 13,
    NSSystemDefined             = 14,
    NSApplicationDefined        = 15,
    NSPeriodic                  = 16,
    NSCursorUpdate              = 17,

	NSEventTypeRotate			= 18,
	NSEventTypeBeginGesture		= 19,
	NSEventTypeEndGesture		= 20,

    NSScrollWheel               = 22,
    NSTabletPoint               = 23,
    NSTabletProximity           = 24,
    NSOtherMouseDown            = 25,
    NSOtherMouseUp              = 26,
    NSOtherMouseDragged         = 27,

	NSEventTypeGesture			= 29,
	NSEventTypeMagnify			= 30,
	NSEventTypeSwipe			= 31

} NSEventType;


typedef enum {
	NSLeftMouseDownMask 		= 1 << 1,				// t m
	NSLeftMouseUpMask 			= 1 << 2,				// t m
	NSRightMouseDownMask 		= 1 << 3,				// m
	NSRightMouseUpMask 			= 1 << 4,				// m
	NSMouseMovedMask 			= 1 << 5,				// t m
	NSLeftMouseDraggedMask 		= 1 << 6,				// t m
	NSRightMouseDraggedMask 	= 1 << 7,				// m
	NSMouseEnteredMask 			= 1 << 8,
	NSMouseExitedMask 			= 1 << 9,
	NSKeyDownMask 				= 1 << 10,				// k
	NSKeyUpMask 				= 1 << 11,				// k
	NSFlagsChangedMask 			= 1 << 12,				// k o
	NSAppKitDefinedMask			= 1 << 13,				// o
	NSSystemDefinedMask			= 1 << 14,				// o
	NSApplicationDefinedMask	= 1 << 15,				// o
	NSPeriodicMask 				= 1 << 16,				// t o
	NSCursorUpdateMask 			= 1 << 17,

	NSEventMaskRotate           = 1 << NSEventTypeRotate,
	NSEventMaskBeginGesture     = 1 << NSEventTypeBeginGesture,
	NSEventMaskEndGesture       = 1 << NSEventTypeEndGesture,

	NSScrollWheelMask			= 1 << NSScrollWheel,	// m
    NSTabletPointMask           = 1 << NSTabletPoint,
	NSOtherMouseDownMask 		= 1 << 25,				// m
	NSOtherMouseUpMask 			= 1 << 26,				// m
	NSOtherMouseDraggedMask 	= 1 << 27,				// m

	NSEventMaskGesture          = 1 << NSEventTypeGesture,
	NSEventMaskMagnify          = 1 << NSEventTypeMagnify,
	NSEventMaskSwipe            = 1 << NSEventTypeSwipe,

	_NSKeyEventsMask			= 0x1c00,				// (k)  key events
	_NSTrackingLoopMask			= 0x10066,				// (t)  tracking loops
	_NSOtherEventsMask			= 0x1f000,				// (o)  other events
	_NSMouseEventsMask			= 0xe4000fe,			// (m)  mouse events

	NSAnyEventMask 				= 0xffffffff			// s/b NSUIntegerMax

} NSEventMask;


enum {
	NSAlphaShiftKeyMask = 1,
	NSShiftKeyMask		= 2,
	NSControlKeyMask	= 4,
	NSAlternateKeyMask	= 8,
	NSCommandKeyMask	= 16,
	NSNumericPadKeyMask = 32,
	NSHelpKeyMask		= 64,
	NSFunctionKeyMask	= 128
};


@interface NSEvent : NSObject  <NSCoding>
{
	NSEventType _type;
	NSPoint _location;
	NSTimeInterval _timestamp;
	NSGraphicsContext *_context;
	unsigned int _modifierFlags;
	NSInteger _windowNumber;

	union {
		struct {
			int event_num;
			int click;
			float pressure;
            CGFloat deltaX;
            CGFloat deltaY;
		} mouse;

		struct {
			NSString *char_keys;
			NSString *unmodified_keys;
			unsigned short key_code;
			BOOL repeat;
		} key;

		struct {
			int event_num;
			int tracking_num;
			void *user_data;
		} tracking;

		struct {
			short sub_type;
			int data1;
			int data2;
		} misc;

	} _data;
}

+ (NSEvent *) enterExitEventWithType:(NSEventType)type	
							location:(NSPoint)location
							modifierFlags:(unsigned int)flags
							timestamp:(NSTimeInterval)time
							windowNumber:(NSInteger)n
							context:(NSGraphicsContext *)context	
							eventNumber:(int)eventNumber
							trackingNumber:(int)trackingNumber
							userData:(void *)userData; 

+ (NSEvent *) keyEventWithType:(NSEventType)type
					  location:(NSPoint)location
					  modifierFlags:(unsigned int)flags
					  timestamp:(NSTimeInterval)time
					  windowNumber:(NSInteger)n
					  context:(NSGraphicsContext *)context	
					  characters:(NSString *)keys	
					  charactersIgnoringModifiers:(NSString *)ukeys
					  isARepeat:(BOOL)repeats
					  keyCode:(unsigned short)code;

+ (NSEvent *) mouseEventWithType:(NSEventType)type	
					   location:(NSPoint)location
					   modifierFlags:(unsigned int)flags
					   timestamp:(NSTimeInterval)time
					   windowNumber:(NSInteger)n
					   context:(NSGraphicsContext *)context	
					   eventNumber:(int)eventNumber
					   clickCount:(int)clicks
					   pressure:(float)pressureValue;

+ (NSEvent *) otherEventWithType:(NSEventType)type	
					   location:(NSPoint)location
					   modifierFlags:(unsigned int)flags
					   timestamp:(NSTimeInterval)time
					   windowNumber:(NSInteger)n
					   context:(NSGraphicsContext *)context	
					   subtype:(short)subType	
					   data1:(int)data1	
					   data2:(int)data2;

+ (NSUInteger) modifierFlags;

+ (void) stopPeriodicEvents;							// Periodic Events
+ (void) startPeriodicEventsAfterDelay:(NSTimeInterval)delaySeconds
							withPeriod:(NSTimeInterval)periodSeconds;

- (NSGraphicsContext *) context;						// Event Information
- (NSPoint) locationInWindow;
- (unsigned int) modifierFlags;
- (NSTimeInterval) timestamp;
- (NSEventType) type;
- (NSWindow *) window;
- (NSInteger) windowNumber;

- (NSString *) characters;								// Key Event Info
- (NSString *) charactersIgnoringModifiers;
- (BOOL) isARepeat;
- (unsigned short) keyCode;

- (int) clickCount;										// Mouse Event Info
- (int) eventNumber;
- (float) pressure;

- (CGFloat) deltaX;
- (CGFloat) deltaY;

- (int) trackingNumber;									// Tracking Event Info
- (void *) userData;

- (int) data1;											// Special Events
- (int) data2;
- (short) subtype;

@end


@interface NSEvent (AppKitBackend)

+ (NSPoint) mouseLocation;

@end


@interface NSEvent (NotImplemented)

+ (NSUInteger) pressedMouseButtons;

+ (void) setMouseCoalescingEnabled:(BOOL)flag;			// mouse move events
+ (BOOL) isMouseCoalescingEnabled;

- (BOOL) hasPreciseScrollingDeltas;						// scroll wheel API
- (CGFloat) scrollingDeltaX;
- (CGFloat) scrollingDeltaY;

- (CGFloat) deltaZ;

- (CGFloat) magnification;								// NSEventTypeMagnify
- (float) rotation;										// NSTabletPoint... or
														// NSEventTypeRotate
@end


enum {
    NSBackspaceKey		= 8,
    NSCarriageReturnKey	= 13,
    NSDeleteKey			= 0x7f,
    NSBacktabKey		= 25
};

enum {
	NSUpArrowFunctionKey    = 0xF700,
	NSDownArrowFunctionKey  = 0xF701,
	NSLeftArrowFunctionKey  = 0xF702,
	NSRightArrowFunctionKey = 0xF703,
	NSF1FunctionKey  = 0xF704,
	NSF2FunctionKey  = 0xF705,
	NSF3FunctionKey  = 0xF706,
	NSF4FunctionKey  = 0xF707,
	NSF5FunctionKey  = 0xF708,
	NSF6FunctionKey  = 0xF709,
	NSF7FunctionKey  = 0xF70A,
	NSF8FunctionKey  = 0xF70B,
	NSF9FunctionKey  = 0xF70C,
	NSF10FunctionKey = 0xF70D,
	NSF11FunctionKey = 0xF70E,
	NSF12FunctionKey = 0xF70F,
	NSF13FunctionKey = 0xF710,
	NSF14FunctionKey = 0xF711,
	NSF15FunctionKey = 0xF712,
	NSF16FunctionKey = 0xF713,
	NSF17FunctionKey = 0xF714,
	NSF18FunctionKey = 0xF715,
	NSF19FunctionKey = 0xF716,
	NSF20FunctionKey = 0xF717,
	NSF21FunctionKey = 0xF718,
	NSF22FunctionKey = 0xF719,
	NSF23FunctionKey = 0xF71A,
	NSF24FunctionKey = 0xF71B,
	NSF25FunctionKey = 0xF71C,
	NSF26FunctionKey = 0xF71D,
	NSF27FunctionKey = 0xF71E,
	NSF28FunctionKey = 0xF71F,
	NSF29FunctionKey = 0xF720,
	NSF30FunctionKey = 0xF721,
	NSF31FunctionKey = 0xF722,
	NSF32FunctionKey = 0xF723,
	NSF33FunctionKey = 0xF724,
	NSF34FunctionKey = 0xF725,
	NSF35FunctionKey = 0xF726,
	NSInsertFunctionKey   = 0xF727,
	NSDeleteFunctionKey   = 0xF728,
	NSHomeFunctionKey     = 0xF729,
	NSBeginFunctionKey    = 0xF72A,
	NSEndFunctionKey      = 0xF72B,
	NSPageUpFunctionKey   = 0xF72C,
	NSPageDownFunctionKey = 0xF72D,
	NSPrintScreenFunctionKey = 0xF72E,
	NSScrollLockFunctionKey  = 0xF72F,
	NSPauseFunctionKey  = 0xF730,
	NSSysReqFunctionKey = 0xF731,
	NSBreakFunctionKey  = 0xF732,
	NSResetFunctionKey  = 0xF733,
	NSStopFunctionKey   = 0xF734,
	NSMenuFunctionKey   = 0xF735,
	NSUserFunctionKey   = 0xF736,
	NSSystemFunctionKey = 0xF737,
	NSPrintFunctionKey  = 0xF738,
	NSClearLineFunctionKey    = 0xF739,
	NSClearDisplayFunctionKey = 0xF73A,
	NSInsertLineFunctionKey = 0xF73B,
	NSDeleteLineFunctionKey = 0xF73C,
	NSInsertCharFunctionKey = 0xF73D,
	NSDeleteCharFunctionKey = 0xF73E,
	NSPrevFunctionKey = 0xF73F,
	NSNextFunctionKey = 0xF740,
	NSSelectFunctionKey  = 0xF741,
	NSExecuteFunctionKey = 0xF742,
	NSUndoFunctionKey = 0xF743,
	NSRedoFunctionKey = 0xF744,
	NSFindFunctionKey = 0xF745,
	NSHelpFunctionKey = 0xF746,
	NSModeSwitchFunctionKey = 0xF747
};
													// Event mask to event type
static inline NSUInteger NSEventMaskFromType(NSEventType t)	{ return (1 << t); }

#endif /* _mGSTEP_H_NSEvent */
