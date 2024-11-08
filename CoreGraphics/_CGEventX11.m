/*
   _CGEventX11.m

   X11 event processing

   Copyright (C) 2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jan 2018

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSWindow.h>
#include <AppKit/NSApplication.h>


#ifndef FB_GRAPHICS

#define CTX				((CGContext *)cx)
#define XROOTWIN		CTX->_display->xRootWindow
#define XDISPLAY		CTX->_display->xDisplay
#define APP_QUEUE		CTX->_mg->_appEventQueue
#define XAPPTILE		CTX->_display->xAppTileWindow


typedef struct  { @defs(NSEvent); } _NSEvent;


static NSEvent *__lastMotionEvent = nil;		// event processing cache
static NSWindow *__window = nil;
static NSInteger __windowNumber = 0;
static int __clickCount = 0;
static NSRect __xFrame;

static Time __timeOfLastClick = {0};
static Window __lastXWindow = None;

static NSEvent *__focusInEvent = nil;
static NSEvent *__focusOutEvent = nil;



/* ****************************************************************************

	XR Event

** ***************************************************************************/

static NSPoint
XRLocation(CGContext *cx, XEvent xe)
{
	if (xe.xbutton.window != __lastXWindow)
		{
		__lastXWindow = xe.xbutton.window;
		__windowNumber = 0;

		if ((__window = XRWindowWithXWindow(xe.xbutton.window)))
			{
			__windowNumber = [__window windowNumber];
			__xFrame = [__window xFrame];
			}
		else
			__xFrame.size = [[NSScreen mainScreen] frame].size;
		}

	return (NSPoint){xe.xbutton.x, (__xFrame.size.height - xe.xbutton.y)};
}

static unsigned short
XRKeyCode(XEvent *xEvent, KeySym ks, unsigned int *eventModFlags)
{
	unsigned short keyCode = 0;

	if ((ks == XK_Return) || (ks == XK_KP_Enter) || (ks == XK_Linefeed))
		return 0x0d;

	if ((ks >= XK_F1) && (ks <= XK_F35)) 					// function key ?
		{
		*eventModFlags |= NSFunctionKeyMask;
	
		switch (ks)
			{
			case XK_F1:  keyCode = NSF1FunctionKey;  break;
			case XK_F2:  keyCode = NSF2FunctionKey;  break;
			case XK_F3:  keyCode = NSF3FunctionKey;  break;
			case XK_F4:  keyCode = NSF4FunctionKey;  break;
			case XK_F5:  keyCode = NSF5FunctionKey;  break;
			case XK_F6:  keyCode = NSF6FunctionKey;  break;
			case XK_F7:  keyCode = NSF7FunctionKey;  break;
			case XK_F8:  keyCode = NSF8FunctionKey;  break;
			case XK_F9:  keyCode = NSF9FunctionKey;  break;
			case XK_F10: keyCode = NSF10FunctionKey; break;
			case XK_F11: keyCode = NSF11FunctionKey; break;
			case XK_F12: keyCode = NSF12FunctionKey; break;
			case XK_F13: keyCode = NSF13FunctionKey; break;
			case XK_F14: keyCode = NSF14FunctionKey; break;
			case XK_F15: keyCode = NSF15FunctionKey; break;
			case XK_F16: keyCode = NSF16FunctionKey; break;
			case XK_F17: keyCode = NSF17FunctionKey; break;
			case XK_F18: keyCode = NSF18FunctionKey; break;
			case XK_F19: keyCode = NSF19FunctionKey; break;
			case XK_F20: keyCode = NSF20FunctionKey; break;
			case XK_F21: keyCode = NSF21FunctionKey; break;
			case XK_F22: keyCode = NSF22FunctionKey; break;
			case XK_F23: keyCode = NSF23FunctionKey; break;
			case XK_F24: keyCode = NSF24FunctionKey; break;
			case XK_F25: keyCode = NSF25FunctionKey; break;
			case XK_F26: keyCode = NSF26FunctionKey; break;
			case XK_F27: keyCode = NSF27FunctionKey; break;
			case XK_F28: keyCode = NSF28FunctionKey; break;
			case XK_F29: keyCode = NSF29FunctionKey; break;
			case XK_F30: keyCode = NSF30FunctionKey; break;
			case XK_F31: keyCode = NSF31FunctionKey; break;
			case XK_F32: keyCode = NSF32FunctionKey; break;
			case XK_F33: keyCode = NSF33FunctionKey; break;
			case XK_F34: keyCode = NSF34FunctionKey; break;
			case XK_F35: keyCode = NSF35FunctionKey; break;
			default:								 break;
		}	}
	else 
		{
		switch (ks)
			{
			case XK_BackSpace:  keyCode = NSBackspaceKey;			break;
			case XK_Delete: 	keyCode = NSDeleteFunctionKey;		break;
			case XK_Home:		keyCode = NSHomeFunctionKey;		break;
			case XK_Left:		keyCode = NSLeftArrowFunctionKey;	break;
			case XK_Up:  		keyCode = NSUpArrowFunctionKey;		break;
			case XK_Right:		keyCode = NSRightArrowFunctionKey;	break;
			case XK_Down:		keyCode = NSDownArrowFunctionKey;	break;
			case XK_Prior:		keyCode = NSPageUpFunctionKey;		break;
			case XK_Next:  		keyCode = NSPageDownFunctionKey;	break;
			case XK_End:  		keyCode = NSEndFunctionKey;			break;
			case XK_Begin:  	keyCode = NSBeginFunctionKey;		break;
			case XK_Select:		keyCode = NSSelectFunctionKey;		break;
			case XK_Print:  	keyCode = NSPrintFunctionKey;		break;
			case XK_Execute:  	keyCode = NSExecuteFunctionKey;		break;
			case XK_Insert:  	keyCode = NSInsertFunctionKey;		break;
			case XK_Undo: 		keyCode = NSUndoFunctionKey;		break;
			case XK_Redo:		keyCode = NSRedoFunctionKey;		break;
			case XK_Menu:		keyCode = NSMenuFunctionKey;		break;
			case XK_Find:  		keyCode = NSFindFunctionKey;		break;
			case XK_Help:		keyCode = NSHelpFunctionKey;		break;
			case XK_Break:  	keyCode = NSBreakFunctionKey;		break;
			case XK_Mode_switch:keyCode = NSModeSwitchFunctionKey;	break;
			case XK_Sys_Req:	keyCode = NSSysReqFunctionKey;		break;
			case XK_Scroll_Lock:keyCode = NSScrollLockFunctionKey;	break;
			case XK_Pause:  	keyCode = NSPauseFunctionKey;		break;
			case XK_Clear:		keyCode = NSClearDisplayFunctionKey;break;
			default:												break;
			}

		if (keyCode)
			*eventModFlags |= NSFunctionKeyMask;
		else
			{
			if ((ks == XK_Shift_L) || (ks == XK_Shift_R))
				*eventModFlags |= NSShiftKeyMask; 
			else if ((ks == XK_Control_L) || (ks == XK_Control_R))
				*eventModFlags |= NSControlKeyMask; 
			else if ((ks == XK_Alt_R) || (ks == XK_Meta_R))
				*eventModFlags |= NSAlternateKeyMask;
			else if ((ks == XK_Alt_L) || (ks == XK_Meta_L))
				*eventModFlags |= NSCommandKeyMask | NSAlternateKeyMask; 
			else if (ks == XK_Tab)
				keyCode = 0x09;
			else if (ks == XK_space)
				keyCode = 0x20;
		}	}

	if ((ks > XK_KP_Space) && (ks < XK_KP_9)) 		// key press from key pad
		{
		*eventModFlags |= NSNumericPadKeyMask;

		switch(ks) 
			{
			case XK_KP_F1:        keyCode = NSF1FunctionKey;         break;
			case XK_KP_F2:        keyCode = NSF2FunctionKey;         break;
			case XK_KP_F3:        keyCode = NSF3FunctionKey;         break;
			case XK_KP_F4:        keyCode = NSF4FunctionKey;         break;
			case XK_KP_Home:      keyCode = NSHomeFunctionKey;       break;
			case XK_KP_Left:      keyCode = NSLeftArrowFunctionKey;  break;
			case XK_KP_Up:        keyCode = NSUpArrowFunctionKey;    break;
			case XK_KP_Right:     keyCode = NSRightArrowFunctionKey; break;
			case XK_KP_Down:      keyCode = NSDownArrowFunctionKey;  break;
			case XK_KP_Page_Up:   keyCode = NSPageUpFunctionKey;     break;
			case XK_KP_Page_Down: keyCode = NSPageDownFunctionKey;   break;
			case XK_KP_End:       keyCode = NSEndFunctionKey;        break;
			case XK_KP_Begin:     keyCode = NSBeginFunctionKey;      break;
			case XK_KP_Insert:    keyCode = NSInsertFunctionKey;     break;
			case XK_KP_Delete:    keyCode = NSDeleteFunctionKey;     break;
			default:												 break;
    	}	}

	if (((ks > XK_KP_Space) && (ks <= XK_KP_9))
			|| ((ks > XK_space) && (ks <= XK_asciitilde)))
		{	
		}													// Not processed 

	return keyCode;
}

static unsigned int								// determine the modifier keys
XRKeyModifierFlags(unsigned int state)			// (Command, Control, Shift, ..)
{												// held down during the event
	unsigned int flags = 0;

	if (state & ControlMask || state & Mod5Mask)
		flags |= NSControlKeyMask;

	if (state & ShiftMask)
		flags |= NSShiftKeyMask;

	if (state & Mod1Mask)
		flags |= NSAlternateKeyMask;

	if (state & Mod2Mask) 
		flags |= NSCommandKeyMask; 

	if (state & LockMask) 
		flags |= NSAlphaShiftKeyMask;

	if (state & Mod4Mask) 
		flags |= NSHelpKeyMask; 

	return flags;
}

static NSEvent *
XRKeyEvent(CGContext *cx, XEvent *xEvent, NSEventType eventType)
{
	KeySym ksym;
	char buf[256];
	XComposeStatus cs;
	NSString *keys = @"";
	unsigned short keyCode = 0;
	static Window xWindow = None;
	static NSInteger windowNumber = 0;
	unsigned int count = XLookupString((XKeyEvent*)xEvent, buf, 256, &ksym, &cs);
	unsigned int modFlags = XRKeyModifierFlags(xEvent->xkey.state);
	unsigned int flags = 0;

	DBLog(@"XRKeyEvent()");

	if (xEvent->xkey.window != xWindow)
		{
		xWindow = xEvent->xkey.window;
		windowNumber = [XRWindowWithXWindow(xWindow) windowNumber];
		}

	buf[MIN(count,255)] = '\0';					// Terminate string properly
	if((keyCode = XRKeyCode(xEvent, ksym, &flags)) != 0 || count != 0)
		{
		if (count != 0)
			keys = [NSString stringWithCString:buf];
		else
			keys = [NSString stringWithCharacters:&keyCode length:1];
		}
	else
		{
		if (eventType == NSKeyUp)
			modFlags &= ~flags;
		else
			modFlags |= flags;

		eventType = NSFlagsChanged;
		}

	return [NSEvent keyEventWithType:eventType
					location:(NSPoint){0,0}
					modifierFlags:modFlags
					timestamp:(NSTimeInterval)xEvent->xkey.time/1000.0
					windowNumber:windowNumber
					context:(NSGraphicsContext *)cx
					characters:keys
					charactersIgnoringModifiers:keys		// FIX ME
					isARepeat:NO
					keyCode:keyCode];
}

static Window
HaveFocus(CGContext *cx, XEvent *xe)				// check if focus is in
{													// one of our windows
	NSWindow *w;
	Window focus;
	int revert_to;						// RevertTo{Parent, PointerRoot, None}

	XSync(XDISPLAY, False);
	XGetInputFocus(XDISPLAY, &focus, &revert_to);
	if (focus != PointerRoot && !(w = XRWindowWithXWindow(focus)))
		{
		NSLog(@"Focus NOT in app (%lx)\n", focus);

		return None;
		}

	NSLog(@"Focus in app (%lx)\n", focus);

	return focus;
}

/* ****************************************************************************

	XRHandleFocusIn()

	Return a fake mouse down event if window becomes key  (titlebar clicked)

** ***************************************************************************/

static NSEvent *
XRHandleFocusIn (CGContext *cx, XEvent *xe)
{
	NSEvent *e = nil;
	NSWindow *w = XRWindowWithXWindow(xe->xfocus.window);
	NSWindow *mw = nil;						// should not lose focus
											// while modal
	if ((mw = [NSApp modalWindow]) && mw != w)
		[mw xSetInputFocus];

	NSLog(@"FocusIn %d\n", xe->xfocus.detail);			// 0-7

	if (!HaveFocus(cx, xe))
		return e;

	NSLog(@"FocusIn ***  fake mouse event\n");

	if (!__focusInEvent)
		__focusInEvent = [[NSEvent otherEventWithType:NSAppKitDefined
								   location:NSZeroPoint
								   modifierFlags:0
								   timestamp:(NSTimeInterval)0
								   windowNumber:0
								   context:(NSGraphicsContext *)cx
								   subtype:0xf0c1
								   data1:1
								   data2:0] retain];

	e = __focusInEvent;  // may trigger oscillation if focus follows mouse
	((_NSEvent *)e)->_windowNumber = [w windowNumber];
	((_NSEvent *)e)->_timestamp = [NSDate timeIntervalSinceReferenceDate];
	((_NSEvent *)e)->_data.misc.data1 = xe->xfocus.detail;

	return e;
}

static NSEvent *
XRHandleFocusOut (CGContext *cx, XEvent *xe)
{
	NSWindow *w = XRWindowWithXWindow(xe->xfocus.window);

NSLog(@"FocusOut %d \n", xe->xfocus.detail);

	if (!__focusOutEvent)
		__focusOutEvent = [[NSEvent otherEventWithType:NSSystemDefined
									location:NSZeroPoint
									modifierFlags:0
									timestamp:(NSTimeInterval)0
									windowNumber:0
									context:(NSGraphicsContext *)cx
									subtype:0xf0c0
									data1:xe->xfocus.detail
									data2:xe->xfocus.serial] retain];

	((_NSEvent *)__focusOutEvent)->_windowNumber = [w windowNumber];

	return __focusOutEvent;
}

static Bool
__xConfigureWindowPredicate(Display *display, XEvent *e, XPointer arg)
{
	if (e->type == ConfigureNotify && e->xany.window == (Window)arg)
		return True;

	return False;
}

void XRProcessEvent(CGContext *cx, XEvent *event)
{
	NSPoint location;							// events from the X queue
	NSEventType type;
	NSEvent *e = nil;
	NSWindow *w = nil;
	XEvent xe = *event;

	switch (xe.type)
		{										// mouse button events
		case ButtonPress:
			{
			float pressure;

			if (xe.xbutton.button == Button4 || xe.xbutton.button == Button5)
				type = NSScrollWheel;
			else if (xe.xbutton.time < (__timeOfLastClick + 60))
				break;							// de-bounce delay

			if (xe.xbutton.time < (__timeOfLastClick + 250))
				__clickCount++;
			else
				__clickCount = 1;				// reset click cnt

			DBLog(@"ButtonPress: time %u timeOfLastClick %u clickCount %u\n",
					xe.xbutton.time, __timeOfLastClick, __clickCount);

			switch (xe.xbutton.button)
				{
				case Button4:   pressure = (float)__clickCount;	  break;
				case Button5:   pressure = -(float)__clickCount;  break;
				case Button1:   type = NSLeftMouseDown;           break;
				case Button3:   type = NSRightMouseDown;          break;
				default:        type = NSOtherMouseDown;          break;
				}

			__timeOfLastClick = xe.xbutton.time;
			location = XRLocation(cx, xe);

			if (__focusInEvent)
				{
				NSTimeInterval ct = [NSDate timeIntervalSinceReferenceDate];

				if (ct < (((_NSEvent *)__focusInEvent)->_timestamp + .2))
					[__window xTossFirstEvent];
				}

			e = [NSEvent mouseEventWithType:type
						 location:location
						 modifierFlags:XRKeyModifierFlags(xe.xbutton.state)
						 timestamp:(NSTimeInterval)xe.xbutton.time/1000.0
						 windowNumber:__windowNumber
						 context:(NSGraphicsContext *)cx
						 eventNumber:xe.xbutton.serial
						 clickCount:__clickCount
						 pressure:pressure];
			}
			break;

		case ButtonRelease:							// de-bounce reject might
			DBLog(@"ButtonRelease");				// produce multiple MouseUp
			switch (xe.xbutton.button)
				{
				case Button1:	type = NSLeftMouseUp;		break;
				case Button3:	type = NSRightMouseUp;		break;
				default:		type = NSOtherMouseUp;		break;
				}

			__timeOfLastClick = xe.xbutton.time;
			location = XRLocation(cx, xe);
			e = [NSEvent mouseEventWithType:type
						 location:location
						 modifierFlags:XRKeyModifierFlags(xe.xbutton.state)
						 timestamp:(NSTimeInterval)xe.xbutton.time/1000.0
						 windowNumber:__windowNumber
						 context:(NSGraphicsContext *)cx
						 eventNumber:xe.xbutton.serial
						 clickCount:__clickCount
						 pressure:1.0];
			break;

		case CirculateNotify:							// a change to the 
			DBLog(@"CirculateNotify\n");				// stacking order
			break;

		case CirculateRequest:
			DBLog(@"CirculateRequest");
			break;

		case ClientMessage:								// client events
			DBLog(@"ClientMessage\n");
			if (xe.xclient.message_type == cx->_display->_protocolsAtom)
				{
				if (xe.xclient.data.l[0] == cx->_display->_deleteWindowAtom)
					{
					w = [NSApp modalWindow];
					if (w && [w xWindow] != xe.xclient.window)
						break;
														// WM is asking us
					NSLog(@"WM_DELETE_WINDOW\n");		// to close window
					w = XRWindowWithXWindow(xe.xclient.window);
					[w performClose:(id)cx];
					}
				else if (xe.xclient.data.l[0] == cx->_display->_takeFocusAtom)
					{
					Window xfw;
					NSLog(@"WM_TAKE_FOCUS\n");
					e = XRHandleFocusOut(cx, event);
					if (!(xfw = HaveFocus(cx, event)) || xfw == PointerRoot)
						[NSApp deactivate];
				  	}
				}
			else
				XRProcessXDND(cx, &xe);			// handle X DND
			break;

		case ColormapNotify:					// colormap attribute chg
			DBLog(@"ColormapNotify\n");
			break;

		case ConfigureNotify:					// window has been resized
			DBLog(@"ConfigureNotify\n");
			if (!xe.xconfigure.override_redirect
					|| xe.xconfigure.window == XAPPTILE)
				{
				NSRect f;

				if (!(w = XRWindowWithXWindow(xe.xconfigure.window)))
					if (xe.xconfigure.window == XAPPTILE)
						w = XRWindowWithXWindow(XAPPTILE);

				while (XCheckIfEvent(XDISPLAY,
									 &xe,
									 &__xConfigureWindowPredicate,
									 (void *)xe.xconfigure.window));
				f = (NSRect){{(float)xe.xconfigure.x,
							  (float)xe.xconfigure.y},
							 {(float)xe.xconfigure.width,
							  (float)xe.xconfigure.height}};

				if (!xe.xconfigure.override_redirect)
					if (xe.xconfigure.send_event == 0)	// add title bar offset
						f.origin.y += ((CGContext *)cx)->_yOffset;    // ~22
				if (xe.xconfigure.above == 0)
					f.origin = [w xFrame].origin;

				if (xe.xconfigure.width == 0)			// FIX ME should not be
					f.size.width = [w xFrame].size.width;	// possible.  WM ?
				if (xe.xconfigure.height == 0)
					f.size.height = [w xFrame].size.height;
				if (xe.xconfigure.width == 0 || xe.xconfigure.height == 0)
					NSLog(@"ConfigureNotify size is NOT sane !! *********\n");

				if (xe.xconfigure.send_event)			// ignore if not WM
					[w _setFrame:f withHint:0];
				}

			if (xe.xconfigure.window == __lastXWindow)
				__xFrame = (NSRect){{(float)xe.xconfigure.x,
									(float)xe.xconfigure.y},
									{(float)xe.xconfigure.width,
									(float)xe.xconfigure.height}};
			break;
												// same as ConfigureNotify		
		case ConfigureRequest:					// but we get this event
			DBLog(@"ConfigureRequest\n");		// before the change has
			break;								// occurred (only WM gets this)

		case CreateNotify:						// a window has been created
			DBLog(@"CreateNotify\n");
			break;

		case DestroyNotify:						// a window has been destroyed
			DBLog(@"DestroyNotify\n");
			break;

		case EnterNotify:						// pointer enters a window
			DBLog(@"EnterNotify\n");
			break;

		case LeaveNotify:						// pointer leaves a window
			DBLog(@"LeaveNotify\n");
			break;

		case Expose:							// portion of window has become
			{									// visible and needs redisplay
			NSWindow *xp = XRWindowWithXWindow(xe.xexpose.window);
			XRectangle r = (XRectangle) {xe.xexpose.x, xe.xexpose.y,
							  			 xe.xexpose.width, xe.xexpose.height};
			if (![xp xExposedRectangle: r])
				if (xe.xexpose.count == 0)
					[xp xProcessExposedRectangles];
			break;
			}
												// keyboard focus entered
		case FocusIn:							// one of our windows	
			e = XRHandleFocusIn(cx, event);
			break;

		case FocusOut:							// keyboard focus left
			NSLog(@"FocusOut\n");				// one of our windows
			e = XRHandleFocusOut(cx, event);
			if (!HaveFocus(cx, event))
				[NSApp deactivate];
			break;

		case GraphicsExpose:
			DBLog(@"GraphicsExpose\n");
			break;

		case NoExpose:
			DBLog(@"NoExpose\n");
			break;

		case GravityNotify:						// window is moved because
			DBLog(@"GravityNotify\n");			// of a change in the size
			break;								// of its parent

		case KeyPress:							// a key has been pressed
			e = XRKeyEvent(cx, &xe, NSKeyDown);
			break;

		case KeyRelease:						// a key has been released
			e = XRKeyEvent(cx, &xe, NSKeyUp);
			break;

		case KeymapNotify:						// reports the state of the
			DBLog(@"KeymapNotify\n");			// keyboard when pointer or
			break;								// focus enters a window

		case MapNotify:							// window state changed from
			DBLog(@"MapNotify\n");				// ummapped to mapped
			[XRWindowWithXWindow(xe.xmap.window) xSetMapped: YES];
			break;								 

		case UnmapNotify:						// window state changed and
			DBLog(@"UnmapNotify\n");			// is no longer visible
			[XRWindowWithXWindow(xe.xunmap.window) xSetMapped: NO];
			break;

		case MapRequest:						// like MapNotify but
			DBLog(@"MapRequest\n");				// occurs before the
			break;								// request is carried out

		case MappingNotify:						// keyboard or mouse   
			DBLog(@"MappingNotify\n");			// mapping has been changed
			break;								// by another client

		case MotionNotify: 						// the mouse has moved
			DBLog(@"MotionNotify");
			if (!xe.xmotion.window)				// should not happen, but does
				break;
			if (xe.xmotion.state & Button1Mask)
				type = NSLeftMouseDragged;	
			else
				type = (xe.xmotion.state & (Button3Mask|Button2Mask)) 
					 ? NSRightMouseDragged : NSMouseMoved;

			location = XRLocation(cx, xe);

			if ([APP_QUEUE indexOfObjectIdenticalTo: __lastMotionEvent] != NSNotFound
					&& [__lastMotionEvent window] == __window
					&& [__lastMotionEvent type] == type)
				{
				_NSEvent *a = (_NSEvent *)__lastMotionEvent;
														// reuse existing
				a->_location = location;				// queued event
				a->_modifierFlags = XRKeyModifierFlags(xe.xmotion.state);
				a->_timestamp = (NSTimeInterval)xe.xmotion.time/1000.0;
				a->_data.mouse.event_num = xe.xmotion.serial;
				break;
				}

			e = [NSEvent mouseEventWithType:type		// create NSEvent
						 location:location
						 modifierFlags:XRKeyModifierFlags(xe.xmotion.state)
						 timestamp:(NSTimeInterval)xe.xmotion.time/1000.0
						 windowNumber:__windowNumber
						 context:(NSGraphicsContext *)cx
						 eventNumber:xe.xmotion.serial
						 clickCount:1
						 pressure:1.0];
			__lastMotionEvent = e;
			break;

		case PropertyNotify:					// a window property has
			DBLog(@"PropertyNotify\n");			// changed or been deleted
			if(cx->_display->_stateAtom == xe.xproperty.atom)
				{
				Atom target;
				unsigned long number_items, bytes_remaining;
				unsigned char *data = NULL;
				int status, format;

				if(!(w = XRWindowWithXWindow(xe.xproperty.window)))
					break;
				status = XGetWindowProperty(XDISPLAY,
											xe.xproperty.window, 
											xe.xproperty.atom, 
											0, 1, False, cx->_display->_stateAtom,
											&target, &format, 
											&number_items, &bytes_remaining,
											(unsigned char **)&data);
				if (status != Success || !data) 
					break;
				if (*data == IconicState)
					[w miniaturize:(id)cx];
				else if (*data == NormalState)
					[w deminiaturize:(id)cx];
				if (number_items > 0)
					XFree(data);
				}
#ifdef DEBUG
			if(_stateAtom == xe.xproperty.atom)
			{
			char *data = XGetAtomName(xDisplay, xe.xproperty.atom);
			fprintf(stderr," atom name is '%s' \n", data);
			XFree(data);
			}
#endif /* DEBUG */
			break;

		case ReparentNotify:					// a client successfully
			DBLog(@"ReparentNotify\n");			// reparents a window
			if (XAPPTILE == xe.xreparent.window)
				{								// WM reparenting appicon
				NSWindow *w = XRWindowWithXWindow(XAPPTILE);

				XAPPTILE = xe.xreparent.parent;
				[w _setFrame:[w xFrame] withHint:0];
				XSelectInput(XDISPLAY, XAPPTILE, StructureNotifyMask);
				}
			else
				[XRWindowWithXWindow(xe.xreparent.window) xParentOffset];
			break;

		case ResizeRequest:						// another client attempts
			DBLog(@"ResizeRequest\n");			// to change window size
			break;

		case SelectionNotify:
			NSLog(@"SelectionNotify\n");
			e = [NSEvent otherEventWithType:NSFlagsChanged
						 location:NSMakePoint(0,0)
						 modifierFlags:0
						 timestamp:(NSTimeInterval)xe.xbutton.time/1000.0
						 windowNumber:__windowNumber
						 context:(NSGraphicsContext *)cx
						 subtype:0
						 data1:0
						 data2:0];
			XRSelectionNotify(cx, (XSelectionEvent*)&xe);
			break;

		case SelectionClear:						// X selection events 
			NSLog(@"SelectionClear");
			break;

		case SelectionRequest:
			NSLog(@"SelectionRequest");
			XRSelectionRequest(cx, (XSelectionRequestEvent*)&xe);
			break;

		case VisibilityNotify:						// window's visibility 
			DBLog(@"VisibilityNotify\n");			// has changed
			break;

		default:									// should not get here
			NSLog(@"Received an untrapped event\n");
			break;
		} 				/* end of event type switch */

	if(e != nil)
		[APP_QUEUE addObject: e];					// add event to app queue
}

/* ****************************************************************************

	NSEvent  (AppKitBackend)

** ***************************************************************************/

@implementation NSEvent  (AppKitBackend)

+ (NSPoint) mouseLocation
{													
	CGContextRef cx = _CGContext();
	Window win;										// Return mouse location in
	int x, y, wx, wy;								// root window coords
	unsigned mask;									// ignoring the event loop

	if (!XQueryPointer(XDISPLAY, XROOTWIN, &win, &win, &x,&y, &wx,&wy, &mask))
		return NSZeroPoint;

	return NSMakePoint(x, y);
}

@end

#endif  /* !FB_GRAPHICS   */
