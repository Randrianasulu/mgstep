/*
   _CGEventFB.m

   FrameBuffer event processing

   Copyright (C) 2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jan 2020

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSWindow.h>
#include <AppKit/NSImage.h>

#ifdef FB_GRAPHICS

#include <linux/kd.h>
#include <linux/vt.h>
#include <termios.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/mman.h>


#define CTX				((CGContext *)cx)
#define CURSOR_RBUF		CTX->_mg->_cursorRestoreBuf
#define CURSOR_W		CTX->_mg->_curorWidth
#define CURSOR_H		CTX->_mg->_curorHeight
#define SCREENHEIGHT	CTX->_display->_frame.size.height
#define SCREEN			CTX->_display
#define APP_QUEUE		CTX->_mg->_appEventQueue

#define SCREEN_HEIGHT	((CGDisplay *)CTX->_display)->_vinfo.yres
#define SCREEN_WIDTH	((CGDisplay *)CTX->_display)->_vinfo.xres

typedef struct  { @defs(NSEvent); } _NSEvent;

typedef struct _fb_event {
	char data[3];
	NSPoint pos;								// device coords
	NSPoint base;								// NS screen base
	NSEventType type;
	NSWindow *window;							// top window if any
} FBEvent;


static unsigned int __flags = 0;
static int __x = 100;
static int __y = 100;
static int __rw = 0;
static int __rh = 0;

static NSTimeInterval __timeOfLastClick = 0;
static unsigned long __eventSequence = 0;
static unsigned int  __modifierFlags = 0;

static NSEvent *__lastMotionEvent = nil;		// event processing cache
static NSWindow *__window = nil;
static NSInteger __windowNumber = 0;
static int __clickCount = 0;
static NSRect __xFrame;


NSEventType FBMouseEventPS2(CGContextRef cx, FBEvent *event);
NSPoint     FBLocation(CGContextRef cx, FBEvent *event);


/* ****************************************************************************

	FBGetNSKeyCode

	Translate to NS Function Key code.  Generated from dumpkeys output.

** ***************************************************************************/

static unsigned short
FBGetNSKeyCode(unsigned int key, unsigned int *ModFlags)
{
	unsigned short keyCode = 0;

	if ((key == 28) || (key == 96))						// Return or Enter
		return 0x0d;

	switch(key) 
		{
		case 14:	keyCode = NSBackspaceKey;			break;
		case 59:	keyCode = NSF1FunctionKey;			break;
		case 60:	keyCode = NSF2FunctionKey;			break;
		case 61:	keyCode = NSF3FunctionKey;			break;
		case 62:	keyCode = NSF4FunctionKey;			break;
		case 63:	keyCode = NSF5FunctionKey;			break;
		case 64:	keyCode = NSF6FunctionKey;			break;
		case 65:	keyCode = NSF7FunctionKey;			break;
		case 66:	keyCode = NSF8FunctionKey;			break;
		case 67:	keyCode = NSF9FunctionKey;			break;
		case 68:	keyCode = NSF10FunctionKey;			break;

		case 87:	keyCode = NSF11FunctionKey;			break;
		case 88:	keyCode = NSF12FunctionKey;			break;

		case 101:	keyCode = NSBreakFunctionKey;		break;
		case 102:	keyCode = NSHomeFunctionKey;		break;
//			case 102:	keyCode = NSFindFunctionKey; break;
		case 103:	keyCode = NSUpArrowFunctionKey;		break;
		case 104:	keyCode = NSPrevFunctionKey;		break;
		case 105:	keyCode = NSLeftArrowFunctionKey;	break;
		case 106:	keyCode = NSRightArrowFunctionKey;	break;
		case 107:	keyCode = NSEndFunctionKey;			break;
		case 108:	keyCode = NSDownArrowFunctionKey;	break;
		case 109:	keyCode = NSNextFunctionKey;		break;
		case 110:	keyCode = NSInsertFunctionKey;		break;
		case 111:	keyCode = NSDeleteFunctionKey;		break;
		case 115:	keyCode = NSHelpFunctionKey;		break;
		case 119:	keyCode = NSPauseFunctionKey;		break;
//			case F13:	keyCode = NSF13FunctionKey; break;
//			case F14:	keyCode = NSF14FunctionKey; break;
//			case F15:	keyCode = NSF15FunctionKey; break;
//			case F16:	keyCode = NSF16FunctionKey; break;
		default:								 break;
		}

	if(keyCode)
		*ModFlags |= NSFunctionKeyMask;

	if ((key > 70) && (key < 84))					// key press from key pad
		{
		*ModFlags |= NSNumericPadKeyMask;

		switch(key) 
			{
			case 71:	keyCode = NSHomeFunctionKey;		break;
			case 72:	keyCode = NSUpArrowFunctionKey;		break;
			case 73:	keyCode = NSPageUpFunctionKey;		break;
			case 75:	keyCode = NSLeftArrowFunctionKey;	break;
			case 77:	keyCode = NSRightArrowFunctionKey;	break;
			case 79:	keyCode = NSEndFunctionKey;			break;
			case 80:	keyCode = NSDownArrowFunctionKey;	break;
			case 81:	keyCode = NSPageDownFunctionKey;	break;
			case 82:	keyCode = NSInsertFunctionKey;		break;
			case 83:	keyCode = NSDeleteFunctionKey;		break;
			default:												 break;
    	}	}

	if ((((key > 89) && (key <= 95)) || key > 120))
		{	
		}													// Not processed 

	return keyCode;
}

static unsigned int
FBKeyModifierFlags(unsigned int key, NSEventType type, int *map)
{												// Determine which modifier
	unsigned int flag = 0;						// keys (Command, CTRL, ALT
												// Shift, etc..) were held down
	switch (key)								// while the event occured.
		{
		case 29:
		case 97:
			flag = NSControlKeyMask;		break;		// Control
		case 42:
		case 54:
			flag = NSShiftKeyMask;			break;		// Shift
		case 56:
		case 100:
			flag = NSAlternateKeyMask;		break;		// Alt
		case 58:
			if (type == NSKeyDown)						// Alpha Shift Lock
				{
				if (__flags & NSAlphaShiftKeyMask)
					__flags &= ~NSAlphaShiftKeyMask;
				else
					__flags |= NSAlphaShiftKeyMask;
				}
			break;
		case 110:
			flag = NSHelpKeyMask;			break;		// Help
		case 125:
		case 126:
			flag = NSCommandKeyMask;		break;		// Command
		}

	if (type == NSKeyUp)
		__flags &= ~flag;
	else
		__flags |= flag;
		
	if (__flags & NSAlphaShiftKeyMask)
		*map = (__flags & NSShiftKeyMask) ? 0 : 1;
	else
		*map = (__flags & NSShiftKeyMask) ? 1 : 0;
	if (__flags & NSAlternateKeyMask)					// AltGr == 2, Alt == 8
		*map |= 2;
	if (__flags & NSControlKeyMask)
		*map |= 4;

	return __flags;
}

static NSEvent *
FBKeyEvent(CGContext *context, char *buf, int nread)
{
	unsigned int modFlags;
	unsigned short keyCode = 0;
	NSString *keys = @"";
	NSEventType type;
	struct kbentry kbent;
	unsigned int flags;
	unsigned int count = 0;
	char str[32];
	int kc = 0;
	int i = 0;

	DBLog(@"FBKeyEvent()");

	while (i < nread)
		{
		int map = 0;

		type = (buf[i] & 0x80) ? NSKeyUp : NSKeyDown;

		if (i+2 < nread && (buf[i] & 0x7f) == 0 && (buf[i+1] & 0x80) != 0
				&& (buf[i+2] & 0x80) != 0)
			{
			kc = ((buf[i+1] & 0x7f) << 7) | (buf[i+2] & 0x7f);
			i += 3;
			}
		else
			{
			kc = (buf[i] & 0x7f);
			i++;
			}

		printf("keycode %3d  %s\n", kc, (type == NSKeyUp) ? "KeyUp":"KeyDown");
//		printf("Modifier flags %d  %d\n", modFlags, flags);

		flags = __flags;
		if ((modFlags = FBKeyModifierFlags(kc, type, &map)) == flags)
			{
			kbent.kb_table = map;			// Keyboard map at table element
			kbent.kb_index = kc;			// Index into keyboard map

			if (kc == 58)					// FIX ME Cap Lock sucks
				continue;

			if (ioctl(context->_mg->_console, KDGKBENT, &kbent) == -1)
				printf("ioctl error KDGKBENT\n");
			printf("Table: %d, Index: %d, ", kbent.kb_table, kbent.kb_index);
			printf("Key: '%c' (0x%x)\n", kbent.kb_value, kbent.kb_value);
			str[count++] = kbent.kb_value;
		}	}
	str[count++] = '\0';					// FIX ME count almost always > 1

	if((keyCode = FBGetNSKeyCode(kc, &flags)) != 0 || count > 1)
		{
		if (keyCode != 0)					// FIX ME
			str[0] = keyCode;
		if (!(__flags & NSControlKeyMask))
			{
			if (keyCode < 256)
				keys = [NSString stringWithCString:str];
			else
				keys = [NSString stringWithCharacters:&keyCode length:1];
		}	}
	else
		{
		if (type == NSKeyUp)
			modFlags &= ~flags;
		else
			modFlags |= flags;

		type = NSFlagsChanged;
		}

	return [NSEvent keyEventWithType: type
					location: (NSPoint){0,0}
					modifierFlags: (__modifierFlags = modFlags)
					timestamp: [NSDate timeIntervalSinceReferenceDate]
					windowNumber: __windowNumber	// FIX ME s/b key window
					context: (NSGraphicsContext *)context
					characters: keys
					charactersIgnoringModifiers: keys		// FIX ME
					isARepeat: NO
					keyCode: (!keyCode) ? kbent.kb_value : keyCode];
}

NSWindow *
FBWindowAtLocation(CGContextRef cx, NSPoint *location)
{
	typedef struct  { @defs(NSWindow); } _NSWindow;
	NSWindow *w = SCREEN->_visibleWindowList;

	for (; w; w = ((_NSWindow *)w)->_below)
		{
//		printf("Is Mouse %f %f in Window Frame ************ %f %f %f %f\n",
//					location->x, location->y,
//					NSMinX(w->_frame), NSMinY(w->_frame),
//					NSWidth(w->_frame), NSHeight(w->_frame));
		if (NSMouseInRect(*location, ((_NSWindow *)w)->_frame, NO))
			{
//			printf("Mouse in Window %d\n", [w windowNumber]);
			return NSMapGet(CTX->_mg->_winToTag, INT2PTR([w windowNumber]));
			}
		}

	return nil;
}

NSPoint
FBLocation(CGContextRef cx, FBEvent *e)
{
	if (e->window)
		{
		if (e->window != __window && e->type != NSRightMouseDragged
				&& e->type != NSLeftMouseDragged)
			{
			__window = e->window;
			__windowNumber = [__window windowNumber];
			__xFrame = [__window frame];
#if 0
			printf("Mouse in Window Frame ************ %f %f %f %f\n",
					NSMinX(__xFrame), NSMinY(__xFrame),
					NSWidth(__xFrame), NSHeight(__xFrame));
#endif
		}	}

#if 0
	printf("Mouse location NS screen %f %f  win base  ************ %f %f\n",
			e->pos.x, e->pos.y,
			e->pos.x - __xFrame.origin.x, e->base.y - __xFrame.origin.y);
#endif

	return (NSPoint){e->pos.x - __xFrame.origin.x, e->base.y - __xFrame.origin.y};
}

void FBGetKeyEvent(CGContextRef cx)
{
	NSEvent *e;
	char buf[32];
	int n;

 fprintf(stderr, "FBContext console\n");
	while ((n = read(CTX->_mg->_console, buf, sizeof(buf))) != -1)
		if((e = FBKeyEvent((CGContext *)cx, buf, n)) != nil)
			[APP_QUEUE addObject: e];				// add event to app queue
}

void FBGetMouseEvent(CGContextRef cx)
{
	FBEvent d;

	while (read(CTX->_mg->_mouse, d.data, 3) == 3)
		{											// loop & grab mouse events
		NSEventType type;
		NSEvent *e = nil;
		float pressure = 0;
		NSWindow *w;
		NSTimeInterval t;
		NSPoint location;

		switch (type = FBMouseEventPS2((CGContextRef)cx, &d))
			{										// mouse button events
			case NSLeftMouseDown:
			case NSRightMouseDown:
			case NSOtherMouseDown:
				t = [NSDate timeIntervalSinceReferenceDate];
				DBLog(@"MouseButtonDown: time %f timeOfLastClick %f \n", 
							t, __timeOfLastClick);

				if (t > (__timeOfLastClick + 0.1) || type == NSScrollWheel)
					__clickCount = (t < __timeOfLastClick + 0.3) ? ++__clickCount : 1;
#if 0
				type = NSScrollWheel;
				pressure = (float)__clickCount;
				pressure = -(float)__clickCount;
#endif
				location = FBLocation((CGContextRef)cx, &d);
				e = [NSEvent mouseEventWithType:type
							 location:location
							 modifierFlags:__modifierFlags
							 timestamp: (__timeOfLastClick = t)
							 windowNumber:__windowNumber
							 context:(NSGraphicsContext *)cx
							 eventNumber:__eventSequence++
							 clickCount:__clickCount
							 pressure:pressure];
				break;

			case NSLeftMouseUp:
			case NSRightMouseUp:
			case NSOtherMouseUp:
				t = [NSDate timeIntervalSinceReferenceDate];
				NSLog(@"MouseButtonUp");

				location = FBLocation((CGContextRef)cx, &d);
				e = [NSEvent mouseEventWithType:type
							 location:location
							 modifierFlags:__modifierFlags
							 timestamp: t
							 windowNumber:__windowNumber
							 context:(NSGraphicsContext *)cx
							 eventNumber:__eventSequence++
							 clickCount:__clickCount
							 pressure:1.0];
				break;

			case NSMouseMoved: 						// the mouse has moved
				if (!d.window)
					{
					NSLog(@"NSMouseMoved no window **********");
					break;
					}
			
			case NSLeftMouseDragged:
			case NSRightMouseDragged:
				t = [NSDate timeIntervalSinceReferenceDate];
				DBLog(@"NSMouseMoved");

				if ([APP_QUEUE indexOfObjectIdenticalTo: __lastMotionEvent] != NSNotFound
						&& [__lastMotionEvent window] == __window
						&& [__lastMotionEvent type] == type)
					{
					_NSEvent *a = (_NSEvent *)__lastMotionEvent;
									// coalesce: reuse existing queued event
					a->_location = FBLocation((CGContextRef)cx, &d);
					a->_modifierFlags = __modifierFlags;
					a->_timestamp = t;
					a->_data.mouse.event_num = __eventSequence++;
					break;
					}

				location = FBLocation((CGContextRef)cx, &d);
				e = [NSEvent mouseEventWithType:type
							 location:location
							 modifierFlags:__modifierFlags
							 timestamp:t
							 windowNumber:__windowNumber
							 context:(NSGraphicsContext *)cx
							 eventNumber:__eventSequence++
							 clickCount:__clickCount
							 pressure:1.0];
				__lastMotionEvent = e;
				break;

			default:								// should not get here
				NSLog(@"Received an untrapped event\n");
				break;
			} 				/* end of event type switch */

		if(e != nil)
			[APP_QUEUE addObject: e];				// add event to app queue
		}
}

/* ****************************************************************************

	FBMouseEventPS2

	PS/2 protocol description:

	3 Bytes per packet

	bit 1 of data[0]:	Left Button Down
	bit 2 of data[0]:	Right Down
	bit 3 of data[0]:	Middle Down
	bit 4 of data[0]:	Always 1
	bit 5 of data[0]:   X Sign
	bit 6 of data[0]:	Y Sign
	bit 7 of data[0]:	X Overflow
	bit 8 of data[0]:	Y Overflow

	data[1]:	X Axis Movement
	data[2]:	Y Axis Movement

** ***************************************************************************/

NSEventType
FBMouseEventPS2(CGContextRef cx, FBEvent *event)
{
  static NSEventType lastType = 0;

	event->type = NSMouseMoved;
	if(event->data[0] & 0x01)
		{
//		printf("left button click\n");
		if (lastType == NSLeftMouseDown || lastType == NSLeftMouseDragged)
			event->type = NSLeftMouseDragged;
		else
			event->type = NSLeftMouseDown;
		}
	else if(event->data[0] & 0x02)
		{
//		printf("right button click\n");
		if (lastType == NSRightMouseDown || lastType == NSRightMouseDragged)
			event->type = NSRightMouseDragged;
		else
			event->type = NSRightMouseDown;
		}
	else if(event->data[0] & 0x04)
		{
//		printf("middle button click\n");
		event->type = NSOtherMouseDown;
		}
	else
		{
		switch (lastType)
			{
			case NSLeftMouseDown:		event->type = NSLeftMouseUp;	break;
			case NSLeftMouseDragged:	event->type = NSLeftMouseUp;	break;
			case NSRightMouseDown:		event->type = NSRightMouseUp;	break;
			case NSRightMouseDragged:	event->type = NSRightMouseUp;	break;
			case NSOtherMouseDown:		event->type = NSOtherMouseUp;
			default:	break;
			}
		}

	FBRestoreCursorRect(cx, (NSRect){__x, __y, __rw, __rh});

	__x += event->data[1];
	__y -= event->data[2];
	__x = __x < 0 ? 0 : __x;
	__y = __y < 0 ? 0 : __y;
	
	if (__x > SCREEN_WIDTH)
		__x = SCREEN_WIDTH - 1;
	if (__y > SCREEN_HEIGHT)
		__y = SCREEN_HEIGHT - 1;

#if 0
  printf("REL  %d %d\n", (unsigned)event->data[1], (unsigned)event->data[2]);
  printf("ABS  %d %d\n", __x, __y);
#endif

	FBDrawCursor(cx);

//printf("FBMouseEventPS2 of type %d  lastType %d\n", event->type, lastType);

	event->pos = (NSPoint){__x, __y};
	event->base = (NSPoint){event->pos.x, SCREENHEIGHT - event->pos.y};
	event->window = FBWindowAtLocation(cx, &event->base);
	lastType = event->type;

	return event->type;
}

void
FBFlushCursor(CGContextRef cx)
{
	FBRestoreCursorRect(cx, (NSRect){__x, __y, __rw, __rh});
}

void
FBDrawCursor(CGContextRef cx)
{
	if (CURSOR_H != __rh || CURSOR_W != __rw)	// malloc a restore buffer and
		{										// resize it for diff cursors
		int sz = CURSOR_W * CURSOR_H * 3+8;
		
		if (sz > CTX->_mg->_cursorRestoreSize)
			CURSOR_RBUF = realloc(CURSOR_RBUF,CTX->_mg->_cursorRestoreSize = sz);
		}

	if (__x + CURSOR_W > SCREEN_WIDTH)
		__rw = SCREEN_WIDTH - __x;
	else
		__rw = CURSOR_W;
	if (__y + CURSOR_H > SCREEN_HEIGHT)
		__rh = SCREEN_HEIGHT - __y;
	else
		__rh = CURSOR_H;

	FBDrawCursorRect(cx, (NSRect){__x, __y, __rw, __rh});
}

/* ****************************************************************************

	NSEvent  (AppKitBackend)

** ***************************************************************************/

@implementation NSEvent  (AppKitBackend)

+ (NSPoint) mouseLocation
{													
	return (NSPoint){__x, __y};
}

@end

#endif  /* !FB_GRAPHICS   */


#if 0

#include <linux/input.h>						// FIX ME Linux evdev support

int
FBMouseEventEvdev(CGContextRef context, struct input_event *thisevent)
{
	struct input_event thisevent;

	(void) memcpy(&thisevent, data, sizeof(struct input_event));

	printf("mouse_evdev_event\n");
	
	if(thisevent->type == EV_REL)
		{
		printf("EV_REL ---> ");
      if(thisevent->code == REL_X)
			printf("REL_X %d\n", (signed char) thisevent->value);
      else if(thisevent->code == REL_Y)
			printf("REL_Y %d\n", (signed char) thisevent->value);
		}
	else if(thisevent->type == EV_KEY)
		{
		  switch (thisevent->code) {
			 case BTN_LEFT:
				printf("BTN_LEFT\n");
				break;
			 case BTN_MIDDLE:
				printf("BTN_MIDDLE\n");
				break;
			 case BTN_RIGHT:
				printf("BTN_RIGHT\n");
				break;
			 case BTN_SIDE:
				printf("BTN_SIDE\n");
				break;
		  }
   }
   return 0;
}
#endif
