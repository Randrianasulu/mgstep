/*
   NSEvent.m

   Event translation

   Copyright (C) 1998-2021 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    November 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSException.h>
#include <Foundation/NSGeometry.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSEvent.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSGraphicsContext.h>
#include <AppKit/NSScreen.h>



static NSString	*__timers = @"NSEventTimersKey";
static NSEvent	*__periodic = nil;
static NSInteger __lastWindowNum = -1;
static NSPoint   __lastLocation = (NSPoint){0,0};
static unsigned int __modifierFlags = 0;



@implementation NSEvent

+ (NSUInteger) modifierFlags		{ return __modifierFlags; }

+ (NSEvent *) enterExitEventWithType:(NSEventType)t
							location:(NSPoint)location
							modifierFlags:(unsigned int)flags
							timestamp:(NSTimeInterval)timestamp
							windowNumber:(NSInteger)windowNum
							context:(NSGraphicsContext *)context	
							eventNumber:(int)eventNum
							trackingNumber:(int)trackingNum
							userData:(void *)userData
{
	NSEvent *e = [[NSEvent new] autorelease];

	if(t != NSMouseEntered && t != NSMouseExited && t != NSCursorUpdate)
		[NSException raise:NSInvalidArgumentException 
					 format:@"Not an enter or exit event"];

	e->_type = t;
	e->_location = location;
	e->_modifierFlags = flags;
	e->_timestamp = timestamp;
	e->_windowNumber = windowNum;
	e->_context = context;
	e->_data.tracking.event_num = eventNum;
	e->_data.tracking.tracking_num = trackingNum;
	e->_data.tracking.user_data = userData;

	return e;
}

+ (NSEvent *) keyEventWithType:(NSEventType)type
					  location:(NSPoint)location
					  modifierFlags:(unsigned int)flags
					  timestamp:(NSTimeInterval)timestamp
					  windowNumber:(NSInteger)windowNum
					  context:(NSGraphicsContext *)context	
					  characters:(NSString *)keys	
					  charactersIgnoringModifiers:(NSString *)ukeys
					  isARepeat:(BOOL)repeatKey	
					  keyCode:(unsigned short)code
{
	NSEvent *e = [[NSEvent new] autorelease];

	if ((type < NSKeyDown) || (type > NSFlagsChanged))
		[NSException raise:NSInvalidArgumentException format:@"Not key event"];

	e->_type = type;
	e->_location = location;
	e->_modifierFlags = __modifierFlags = flags;
	e->_timestamp = timestamp;
	e->_windowNumber = windowNum;
	e->_context = context;
	e->_data.key.char_keys = [keys retain];
	e->_data.key.unmodified_keys = [ukeys retain];
	e->_data.key.repeat = repeatKey;
	e->_data.key.key_code = code;

	return e;
}

+ (NSEvent *) mouseEventWithType:(NSEventType)t	
						location:(NSPoint)l
						modifierFlags:(unsigned int)flags
						timestamp:(NSTimeInterval)timestamp
						windowNumber:(NSInteger)windowNum
						context:(NSGraphicsContext *)context 
						eventNumber:(int)eventNum	
						clickCount:(int)clickNum	
						pressure:(float)pressureValue
{
	NSEvent *e = [[NSEvent new] autorelease];

	if (!(NSEventMaskFromType(t) & _NSMouseEventsMask))
		[NSException raise:NSInvalidArgumentException format:@"Not mouse event"];

	e->_type = t;
	e->_location = l;
	e->_modifierFlags = flags;
	e->_timestamp = timestamp;
	e->_windowNumber = windowNum;
	e->_context = context;
	e->_data.mouse.event_num = eventNum;
	e->_data.mouse.click = clickNum;
	e->_data.mouse.pressure = pressureValue;

	if (windowNum == __lastWindowNum)
	  	if (ABS(l.x -__lastLocation.x) < 40 && ABS(__lastLocation.y - l.y) < 40)
			{
			e->_data.mouse.deltaX = l.x - __lastLocation.x;
			e->_data.mouse.deltaY = __lastLocation.y - l.y;
			}
	__lastWindowNum = windowNum;
	__lastLocation = l;

	return e;
}

+ (NSEvent *) otherEventWithType:(NSEventType)t	
						location:(NSPoint)location
						modifierFlags:(unsigned int)flags
						timestamp:(NSTimeInterval)timestamp
						windowNumber:(NSInteger)windowNum
						context:(NSGraphicsContext *)context 
						subtype:(short)subType	
						data1:(int)data1	
						data2:(int)data2
{
	NSEvent *e = [[NSEvent new] autorelease];

	if (!(NSEventMaskFromType(t) & _NSOtherEventsMask))
		[NSException raise:NSInvalidArgumentException 
					 format:@"Invalid other event type"];

	e->_type = t;
	e->_location = location;
	e->_modifierFlags = flags;
	e->_timestamp = timestamp;
	e->_windowNumber = windowNum;
	e->_context = context;
	e->_data.misc.sub_type = subType;
	e->_data.misc.data1 = data1;
	e->_data.misc.data2 = data2;

	return e;
}
															
+ (void) startPeriodicEventsAfterDelay:(NSTimeInterval)delaySeconds
							withPeriod:(NSTimeInterval)periodSeconds
{
	NSMutableDictionary *d = [[NSThread currentThread] threadDictionary];
	NSTimer *t;

	DBLog(@"startPeriodicEventsAfterDelay:withPeriod:");
														// Check this thread 
	if ([d objectForKey: __timers])						// for a pending timer
		[NSException raise:NSInternalInconsistencyException
					 format:@"Periodic events are already being generated for "
					 @"this thread %x", [NSThread currentThread]];

							// If delay time is 0 register timer immediately.
	if (!delaySeconds)		// Otherwise register a one shot timer to do it.
		t = [NSTimer timerWithTimeInterval:periodSeconds	// register an
					 target:self							// immediate
					 selector:@selector(_timerFired:)		// timer
					 userInfo:nil
					 repeats:YES];
	else													// register a one
		t = [NSTimer timerWithTimeInterval:delaySeconds 	// shot timer to 
					 target:self							// register a timer 
					 selector:@selector(_registerRealTimer:)
					 userInfo:[NSNumber numberWithDouble:periodSeconds]
					 repeats:NO];

	[[NSRunLoop currentRunLoop] addTimer:t forMode:NSEventTrackingRunLoopMode];
	[d setObject:t forKey:__timers];
}

+ (void) _timerFired:(NSTimer*)timer
{
	if (!__periodic)
		__periodic = [[self otherEventWithType:NSPeriodic
							location:NSZeroPoint
							modifierFlags:0
							timestamp:0
							windowNumber:0
							context:[NSApp context]
							subtype:0
							data1:0
							data2:0] retain];
	DBLog(@"_timerFired:");
	__periodic->_timestamp = [[NSDate date] timeIntervalSinceReferenceDate];

	[NSApp postEvent:__periodic atStart:NO];	// queue up the periodic event
}

+ (void) _registerRealTimer:(NSTimer*)timer		// provides a way to delay the
{												// start of periodic events
	NSTimer *t = [NSTimer timerWithTimeInterval:[[timer userInfo] doubleValue]
						  target:self
						  selector:@selector(_timerFired:)
						  userInfo:nil
						  repeats:YES];			// Add real timer to the timers
												// dictionary and to run loop
	[[[NSThread currentThread] threadDictionary] setObject:t forKey:__timers];		
	[[NSRunLoop currentRunLoop] addTimer:t forMode:NSEventTrackingRunLoopMode];
}

+ (void) stopPeriodicEvents
{
	NSMutableDictionary *d = [[NSThread currentThread] threadDictionary];

	DBLog(@"stopPeriodicEvents");
	[[d objectForKey: __timers] invalidate];	// Remove any existing timer
	[d removeObjectForKey: __timers];			// for this thread
}

- (void) dealloc
{
	if ((_type == NSKeyUp) || (_type == NSKeyDown))
		{
		[_data.key.char_keys release];
		[_data.key.unmodified_keys release];
		}

	[super dealloc];
}

- (NSGraphicsContext *) context		{ return _context; }
- (NSPoint) locationInWindow		{ return _location; }
- (unsigned int) modifierFlags		{ return _modifierFlags; }
- (NSTimeInterval) timestamp		{ return _timestamp; }
- (NSEventType) type				{ return _type; }
- (NSInteger) windowNumber			{ return _windowNumber; }

- (NSWindow *) window
{
	return [NSApp windowWithWindowNumber:_windowNumber];
}

- (NSString *) characters								// Key Event Info
{
	if ((_type != NSKeyUp) && (_type != NSKeyDown))
		return nil;

	return _data.key.char_keys;
}

- (NSString *) charactersIgnoringModifiers
{
	if ((_type != NSKeyUp) && (_type != NSKeyDown))
		return nil;

	return _data.key.unmodified_keys;
}

- (BOOL) isARepeat
{
	if ((_type != NSKeyUp) && (_type != NSKeyDown))
		return NO;

	return _data.key.repeat;
}

- (unsigned short) keyCode
{
	if ((_type != NSKeyUp) && (_type != NSKeyDown))
		return 0;

	return _data.key.key_code;
}

- (int) clickCount										// Mouse Event Info
{
	if (!(NSEventMaskFromType(_type) & _NSMouseEventsMask))
		return 0;										// must be mouse event

	return _data.mouse.click;
}

- (int) eventNumber
{
	if ((_type == NSMouseEntered) || (_type == NSMouseExited))
		return _data.tracking.event_num;

	if (!(NSEventMaskFromType(_type) & _NSMouseEventsMask))
		return 0;

	return _data.mouse.event_num;
}

- (CGFloat) deltaX
{
	if (!(NSEventMaskFromType(_type) & _NSMouseEventsMask))
		return 0;

	return _data.mouse.deltaX;
}

- (CGFloat) deltaY
{
	if (!(NSEventMaskFromType(_type) & _NSMouseEventsMask))
		return 0;

	return _data.mouse.deltaY;
}

- (float) pressure
{
	if (!(NSEventMaskFromType(_type) & _NSMouseEventsMask))
		return 0;

	return _data.mouse.pressure;
}

- (int) trackingNumber									// Tracking Event Info
{
	if ((_type != NSMouseEntered) && (_type != NSMouseExited)
			&& (_type != NSCursorUpdate))
		return 0;

	return _data.tracking.tracking_num;
}

- (void *) userData
{
	if ((_type != NSMouseEntered) && (_type != NSMouseExited)
			&& (_type != NSCursorUpdate))
		return NULL;

	return _data.tracking.user_data;
}

- (int) data1						{ return _data.misc.data1; }
- (int) data2						{ return _data.misc.data2; }
- (short) subtype					{ return _data.misc.sub_type; }

- (void) encodeWithCoder:(NSCoder*)aCoder				// NSCoding protocol
{
	[aCoder encodeValueOfObjCType: @encode(NSEventType) at: &_type];
	[aCoder encodePoint: _location];
	[aCoder encodeValueOfObjCType: "I" at: &_modifierFlags];
	[aCoder encodeValueOfObjCType: @encode(NSTimeInterval) at: &_timestamp];
	[aCoder encodeValueOfObjCType: "i" at: &_windowNumber];
	
	switch (_type)								// Encode the event date based
		{										// upon the event type
		case NSLeftMouseDown:
		case NSLeftMouseUp:
		case NSRightMouseDown:
		case NSRightMouseUp:
		case NSMouseMoved:
		case NSLeftMouseDragged:
		case NSRightMouseDragged:
			[aCoder encodeValuesOfObjCTypes: "iif", &_data.mouse.event_num,
													&_data.mouse.click,
													&_data.mouse.pressure];
			break;
		
		case NSMouseEntered:
		case NSMouseExited:
		case NSCursorUpdate:		// Can't do anything with the user_data!?
			[aCoder encodeValuesOfObjCTypes:"ii", &_data.tracking.event_num,
												  &_data.tracking.tracking_num];
			break;
		
		case NSKeyDown:
		case NSKeyUp:
			[aCoder encodeValueOfObjCType: @encode(BOOL) at: &_data.key.repeat];
			[aCoder encodeObject: _data.key.char_keys];
			[aCoder encodeObject: _data.key.unmodified_keys];
			[aCoder encodeValueOfObjCType: "S" at: &_data.key.key_code];
			break;
		
		case NSFlagsChanged:
		case NSPeriodic:
			[aCoder encodeValuesOfObjCTypes: "sii", &_data.misc.sub_type,
													&_data.misc.data1,
													&_data.misc.data2];
		default:
			break;
		}
}

- (id) initWithCoder:(NSCoder*)aDecoder
{
	[aDecoder decodeValueOfObjCType: @encode(NSEventType) at: &_type];
	_location = [aDecoder decodePoint];
	[aDecoder decodeValueOfObjCType: "I" at: &_modifierFlags];
	[aDecoder decodeValueOfObjCType: @encode(NSTimeInterval) at: &_timestamp];
	[aDecoder decodeValueOfObjCType: "i" at: &_windowNumber];

	switch (_type)								// Decode the event date based
		{										// upon the event type
		case NSLeftMouseDown:
		case NSLeftMouseUp:
		case NSRightMouseDown:
		case NSRightMouseUp:
		case NSMouseMoved:
		case NSLeftMouseDragged:
		case NSRightMouseDragged:
			[aDecoder decodeValuesOfObjCTypes:"iif", &_data.mouse.event_num,
													 &_data.mouse.click,
													 &_data.mouse.pressure];
			break;
	
		case NSMouseEntered:
		case NSMouseExited:
		case NSCursorUpdate:
			[aDecoder decodeValuesOfObjCTypes:"ii", &_data.tracking.event_num,
												    &_data.tracking.tracking_num];
			break;
	
		case NSKeyDown:
		case NSKeyUp:
			[aDecoder decodeValueOfObjCType: @encode(BOOL) 
					  at: &_data.key.repeat];
			_data.key.char_keys = [aDecoder decodeObject];
			_data.key.unmodified_keys = [aDecoder decodeObject];
			[aDecoder decodeValueOfObjCType: "S" at: &_data.key.key_code];
			break;
	
		case NSFlagsChanged:
		case NSPeriodic:
			[aDecoder decodeValuesOfObjCTypes:"sii", &_data.misc.sub_type, 
													 &_data.misc.data1, 
													 &_data.misc.data2];
		default:
			break;
		}

	return self;
}

- (NSString*) description
{
	const char *str[] = { "LeftMouseDown", "LeftMouseUp",    "RightMouseDown",
						  "RightMouseUp",  "OtherMouseDown", "OtherMouseUp",
						  "MouseMoved", "LeftMouseDragged", "RightMouseDragged",
						  "OtherMouseDragged", "MouseEntered", "MouseExited",
						  "KeyDown", "KeyUp", "FlagsChanged", "Periodic",
						  "CursorUpdate",  "AppKitDefined", "SystemDefined",
						  "ApplicationDefined", "scrollWheel" };
	switch (_type)
		{
		case NSLeftMouseDown:
		case NSLeftMouseUp:
		case NSRightMouseDown:
		case NSRightMouseUp:
		case NSMouseMoved:
		case NSLeftMouseDragged:
		case NSRightMouseDragged:
		case NSScrollWheel:
			return [NSString stringWithFormat:
				@"NSEvent: type = %s, point = { %f, %f }, modifiers = %u,"
				@" time = %f, window = %d, context = %p,"
				@" event number = %d, click = %d, pressure = %f",
				str[_type - 1], _location.x, _location.y,
				_modifierFlags, _timestamp, _windowNumber, _context,
				_data.mouse.event_num, _data.mouse.click, _data.mouse.pressure];

		case NSMouseEntered:
		case NSMouseExited:
			return [NSString stringWithFormat:
				@"NSEvent: type = %s, point = { %f, %f }, modifiers = %u,"
				@" time = %f, window = %d, context = %p,"
				@" event number = %d, tracking number = %d, user data = %p",
				str[_type - 1], _location.x, _location.y,
				_modifierFlags, _timestamp, _windowNumber, _context,
				_data.tracking.event_num, _data.tracking.tracking_num,
				_data.tracking.user_data];

		case NSKeyDown:
		case NSKeyUp:
			return [NSString stringWithFormat:
				@"NSEvent: type = %s, point = { %f, %f }, modifiers = %u,"
				@" time = %f, window = %d, context = %p,"
				@" repeat = %s, keys = %@, ukeys = %@, keyCode = 0x%x",
				str[_type - 1], _location.x, _location.y,
				_modifierFlags, _timestamp, _windowNumber, _context,
				(_data.key.repeat ? "YES" : "NO"), _data.key.char_keys,
				_data.key.unmodified_keys, _data.key.key_code];

		case NSFlagsChanged:
		case NSPeriodic:
		case NSCursorUpdate:
		case NSAppKitDefined:
		case NSSystemDefined:
			return [NSString stringWithFormat:
				@"NSEvent: type = %s, point = { %f, %f }, modifiers = %u,"
				@" time = %f, window = %d, context = %p,"
				@" subtype = %d, data1 = %p, data2 = %p",
				str[_type - 1], _location.x, _location.y,
				_modifierFlags, _timestamp, _windowNumber, _context,
				_data.misc.sub_type, _data.misc.data1, _data.misc.data2];
		default:
			break;
		}

	return @"NSEvent: error unknown event type";
}

@end
