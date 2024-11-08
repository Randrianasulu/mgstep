/*
   xdnd.m

   Xdnd protocol developed by John Lindal

   Copyright (C) 1998-2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    1998

   Derived from Xdnd reference implementation published by
   Copyright (C) 1998  Paul Sheer <psheer@obsidian.co.za>

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSString.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSCursor.h>
#include <AppKit/NSDragging.h>


#ifndef FB_GRAPHICS

#include <X11/Xatom.h>
#include "xdnd.h"


static DndClass __dnd = {0};

static XColor __xg;
static XColor __xb;
static XColor __xw;
static Atom __xDndActionType = -1;
static Cursor __cursor;


@interface NSCursor  (XRCursor)

- (Cursor) xCursor;

@end


static void
xdnd_init ( CGContext *cx )							// intern XDND atoms
{
	DndClass *dnd = &__dnd;
	Display *display = cx->_display->xDisplay;

    memset (dnd, 0, sizeof(*dnd));

    dnd->display = display;
    dnd->version = XDND_VERSION;
    dnd->XdndAware = XInternAtom (display, "XdndAware", False);
    dnd->XdndSelection = XInternAtom (display, "XdndSelection", False);
    dnd->XdndEnter = XInternAtom (display, "XdndEnter", False);
    dnd->XdndLeave = XInternAtom (display, "XdndLeave", False);
    dnd->XdndPosition = XInternAtom (display, "XdndPosition", False);
    dnd->XdndDrop = XInternAtom (display, "XdndDrop", False);
    dnd->XdndFinished = XInternAtom (display, "XdndFinished", False);
    dnd->XdndStatus = XInternAtom (display, "XdndStatus", False);
    dnd->XdndActionCopy = XInternAtom (display, "XdndActionCopy", False);
    dnd->XdndActionMove = XInternAtom (display, "XdndActionMove", False);
    dnd->XdndActionLink = XInternAtom (display, "XdndActionLink", False);
    dnd->XdndActionAsk = XInternAtom (display, "XdndActionAsk", False);
    dnd->XdndActionPrivate=XInternAtom(display,"XdndActionPrivate",False);
    dnd->XdndTypeList = XInternAtom (display, "XdndTypeList", False);
	dnd->types[0] = XInternAtom(display, "text/uri-list", False);
    dnd->dragging_version = 0;
    dnd->time = 0;

	NSColor *g = [NSColor greenColor];
	__xg = [g xColor];
//	__xg = [[NSColor greenColor] xColor];
	__xb = [[NSColor blackColor] xColor];
	__xw = [[NSColor whiteColor] xColor];
	__cursor = [[NSCursor arrowCursor] xCursor];
	cx->_mg->_dnd = &__dnd;
}

void
XRSetXDNDAware(CGContext *cx, Window window)
{
	DndClass *dnd = &__dnd;

	if (dnd->display == NULL)
		xdnd_init(cx);

	xdnd_set_dnd_aware(dnd, window, NULL);
}

BOOL
XRIsWindowXDNDAware(CGContext *cx, Window window)
{
	DndClass *dnd = &__dnd;

	if (dnd->display == NULL || window == None)
		return NO;

	return xdnd_is_dnd_aware(dnd, window, &__dnd.dragging_version, &__dnd.XdndAware);
}

void
xdnd_set_dnd_aware (DndClass *dnd, Window window, Atom *typelist)
{
    if (XChangeProperty (dnd->display, window, dnd->XdndAware,
						XA_ATOM, 32, PropModeReplace,
						(unsigned char *) &dnd->version, 1) == 0)
		{
		NSLog(@"xdnd_set_dnd_aware: XChangeProperty failed\n");
		return;
		}

    if (typelist && typelist[0])
		{
		int n;

		for (n = 0; typelist[n]; n++);
			if (XChangeProperty (dnd->display, window, dnd->XdndAware,
								XA_ATOM, 32, PropModeAppend,
								(unsigned char *)typelist, n) == 0)
			  NSLog(@"xdnd_set_dnd_aware: XChangeProperty (typelist) failed\n");
		}
}

int
xdnd_is_dnd_aware (DndClass *dnd, Window window, int *version, Atom *typelist)
{
	Atom actual;
	int format;
	unsigned long count, remaining;
	unsigned char *data = 0;
	Atom *types, *t;
	int result = 1;

	if(!dnd->display)
		return 0;

    *version = 0;
    if (XGetWindowProperty (dnd->display, window, dnd->XdndAware,
							0, 0x8000000L, False, XA_ATOM,
							&actual, &format,
							&count, &remaining, &data) != Success)
		NSLog(@"xdnd_is_dnd_aware: XGetWindowProperty failed");

    if (actual != XA_ATOM || format != 32 || count == 0 || !data) 
		{
		DBLog(@"xdnd_is_dnd_aware: XdndAware = %ld", dnd->XdndAware);

		if (data)
			XFree (data);

		return 0;
		}

    types = (Atom *)data;
    *version = dnd->version < types[0] ? dnd->version : types[0];	// minimum
    DBLog(@"Using XDND version %d", *version);

    if (count > 1) 
		{
		result = 0;
		for (t = typelist; *t; t++) 
			{
			int j;
			for (j = 1; j < count; j++) 
				{
				if (types[j] == *t) 
					{
					result = 1;
					break;
				}	}

			if (result)
				break;
		}	}
    XFree (data);

    return result;
}

void
xdnd_send_enter (DndClass *dnd, Window window, Window from, Atom *typelist)
{
	XEvent xevent;
	int n, i;

    memset (&xevent, 0, sizeof (xevent));

    xevent.xany.type = ClientMessage;
    xevent.xany.display = dnd->display;
    xevent.xclient.window = window;
    xevent.xclient.message_type = dnd->XdndEnter;
    xevent.xclient.format = 32;

    XDND_ENTER_SOURCE_WIN (&xevent) = from;
    for (n = 0; typelist[n]; n++);
    XDND_ENTER_THREE_TYPES_SET (&xevent, n > XDND_THREE);
    XDND_ENTER_VERSION_SET (&xevent, dnd->version);
    for (i = 0; i < n && i < XDND_THREE; i++)
		XDND_ENTER_TYPE (&xevent, i) = typelist[i];

	XSendEvent (dnd->display, window, 0, 0, &xevent);
}

void
xdnd_send_position (DndClass *dnd, 
					Window window, 
					Window from, 
					Atom action, 
					int x, int y, 
					unsigned long time)
{
	XEvent xevent;

    memset (&xevent, 0, sizeof (xevent));

    xevent.xany.type = ClientMessage;
    xevent.xany.display = dnd->display;
    xevent.xclient.window = window;
    xevent.xclient.message_type = dnd->XdndPosition;
    xevent.xclient.format = 32;

    XDND_POSITION_SOURCE_WIN (&xevent) = from;
    XDND_POSITION_ROOT_SET (&xevent, x, y);
    if (dnd->dragging_version >= 1)
		XDND_POSITION_TIME (&xevent) = time;
    if (dnd->dragging_version >= 2)
		XDND_POSITION_ACTION (&xevent) = action;

	XSendEvent (dnd->display, window, 0, 0, &xevent);
}

void
xdnd_send_status (DndClass *dnd, 
				  Window window, 
				  Window from, 
				  int x, int y, int w, int h, 
				  Atom action)
{
	XEvent xevent;

    memset (&xevent, 0, sizeof (xevent));

    xevent.xany.type = ClientMessage;
    xevent.xany.display = dnd->display;
    xevent.xclient.window = window;
    xevent.xclient.message_type = dnd->XdndStatus;
    xevent.xclient.format = 32;

    XDND_STATUS_TARGET_WIN (&xevent) = from;
    XDND_STATUS_WILL_ACCEPT_SET (&xevent, True);
	XDND_STATUS_WANT_POSITION_SET (&xevent, True);
	XDND_STATUS_RECT_SET (&xevent, x, y, w, h);
	XDND_STATUS_ACTION (&xevent) = action;

	XSendEvent (dnd->display, window, 0, 0, &xevent);
}

void
xdnd_send_leave (DndClass *dnd, Window window, Window from)
{
	XEvent xevent;

    memset (&xevent, 0, sizeof (xevent));

    xevent.xany.type = ClientMessage;
    xevent.xany.display = dnd->display;
    xevent.xclient.window = window;
    xevent.xclient.message_type = dnd->XdndLeave;
    xevent.xclient.format = 32;

    XDND_LEAVE_SOURCE_WIN (&xevent) = from;

	XSendEvent (dnd->display, window, 0, 0, &xevent);

	XDefineCursor(dnd->display, from, __cursor);
	XRecolorCursor(dnd->display, __cursor, &__xb, &__xw);
	__xDndActionType = -1;
}

void
xdnd_send_drop (DndClass *dnd, Window window, Window from, unsigned long time)
{
	XEvent xevent;

    memset (&xevent, 0, sizeof (xevent));

    xevent.xany.type = ClientMessage;
    xevent.xany.display = dnd->display;
    xevent.xclient.window = window;
    xevent.xclient.message_type = dnd->XdndDrop;
    xevent.xclient.format = 32;

    XDND_DROP_SOURCE_WIN (&xevent) = from;
    if (dnd->dragging_version >= 1)
		XDND_DROP_TIME (&xevent) = time;

	XSendEvent (dnd->display, window, 0, 0, &xevent);

	XDefineCursor(dnd->display, from, __cursor);
	XRecolorCursor(dnd->display, __cursor, &__xb, &__xw);
	__xDndActionType = -1;
}

void
xdnd_send_finished (DndClass *dnd, Window window, Window from, int error)
{
	XEvent xevent;								// error is not actually used,
												// I think future versions of 
    memset (&xevent, 0, sizeof (xevent));		// the protocol should return 
												// an error status to the
    xevent.xany.type = ClientMessage;			// calling window with the
    xevent.xany.display = dnd->display;			// XdndFinished client message
    xevent.xclient.window = window;				
    xevent.xclient.message_type = dnd->XdndFinished;
    xevent.xclient.format = 32;
    xevent.xclient.data.l[1] = error;

    XDND_FINISHED_TARGET_WIN (&xevent) = from;

	XSendEvent (dnd->display, window, 0, 0, &xevent);
}

int
xdnd_convert_selection (DndClass *dnd, 				// returns non-zero on 
						Window window, 				// error -- i.e. no
						Window requester, 			// selection owner set.
						Atom type)					// Type is of course 
{													// the mime type
    if (XGetSelectionOwner (dnd->display, dnd->XdndSelection) == None) 
		{
		NSLog(@"xdnd_convert_selection(): XGetSelectionOwner failed\n");
		return 1;
		}

    XConvertSelection (dnd->display, dnd->XdndSelection, type,
						type, requester, CurrentTime);
    return 0;
}

int
xdnd_set_selection_owner (DndClass *dnd, Window window, Atom type)
{
    if(!XSetSelectionOwner(dnd->display,dnd->XdndSelection,window,CurrentTime)) 	
		{
		NSLog(@"xdnd_set_selection_owner(): XSetSelectionOwner failed");
		return 1;								// returns non-zero on error
		}	

    return 0;
}

void
xdnd_selection_send (DndClass *dnd, 
					 XSelectionRequestEvent *request, 
					 unsigned const char *data, 
					 int length)
{
	XEvent xevent;

    DBLog(@" requestor = %ld", request->requestor);
    DBLog(@" property = %ld", request->property);
    DBLog(@" length = %d", length);

    if (XChangeProperty (dnd->display, request->requestor,
						 request->property, request->target, 8,
						 PropModeReplace, data, length) != Success)
		NSLog(@"xdnd_selection_send: XChangeProperty failed\n");

    xevent.xselection.type = SelectionNotify;
    xevent.xselection.property = request->property;
    xevent.xselection.display = request->display;
    xevent.xselection.requestor = request->requestor;
    xevent.xselection.selection = request->selection;
    xevent.xselection.target = request->target;
    xevent.xselection.time = request->time;

	XSendEvent (dnd->display, request->requestor, 0, 0, &xevent);
}

Atom
XRActionForDragOperation(unsigned int op)
{
	DBLog(@"XRActionForDragOperation %d\n",op);
	switch (op)
		{
		case NSDragOperationNone:		return None;
		case NSDragOperationCopy:		return __dnd.XdndActionCopy;
		case NSDragOperationLink:		return __dnd.XdndActionLink;
		case NSDragOperationPrivate:	return __dnd.XdndActionPrivate;
		default:
		case NSDragOperationGeneric:
		case NSDragOperationAll:		return __dnd.XdndActionMove;
		}
}

unsigned int
XRDragOperationForAction(Atom xaction)
{
	if (xaction == __dnd.XdndActionCopy)
		return NSDragOperationCopy;
	if (xaction == None)
		return NSDragOperationNone;
	if (xaction == __dnd.XdndActionLink)
		return NSDragOperationLink;
	if (xaction == __dnd.XdndActionAsk || (xaction == __dnd.XdndActionMove))
		return NSDragOperationGeneric;
	if (xaction == __dnd.XdndActionPrivate)
		return NSDragOperationPrivate;

	return NSDragOperationNone;
}

void
XRProcessXDNDStatus(Display *xDisplay, XEvent *xEvent)
{
	DBLog(@"XRProcessXDNDStatus\n");
	if(XDND_STATUS_ACTION(xEvent) != __xDndActionType)
		{
		__xDndActionType = XDND_STATUS_ACTION(xEvent);

		if(xEvent->xclient.window == None)
			{
			NSLog(@"XRProcessXDNDStatus(): xEvent->xclient.window == None\n");
			return;
			}

		switch (XRDragOperationForAction(__xDndActionType))
			{
			case NSDragOperationNone:
				{
				NSLog(@"xdnd NSDragOperationNone\n");
				XDefineCursor(xDisplay, xEvent->xclient.window, __cursor);
				XRecolorCursor(xDisplay, __cursor, &__xb, &__xw);
				break;
				}
			case NSDragOperationCopy:
				{
				Cursor xCursor = [[NSCursor dragCopyCursor] xCursor];

				NSLog(@"xdnd NSDragOperationCopy\n");
				XDefineCursor(xDisplay, xEvent->xclient.window, xCursor);
				break;
				}
			case NSDragOperationLink:
				{
				Cursor xCursor = [[NSCursor dragLinkCursor] xCursor];

				NSLog(@"xdnd NSDragOperationLink\n");
				XDefineCursor(xDisplay, xEvent->xclient.window, xCursor);
				break;
				}
			case NSDragOperationPrivate: 
			case NSDragOperationGeneric: 
			case NSDragOperationAll:
				{
				NSLog(@"xdnd NSDragOperationAll\n");
				XDefineCursor(xDisplay, xEvent->xclient.window, __cursor);
				XRecolorCursor(xDisplay, __cursor, &__xg, &__xb);
				break;
		}	}	}
}

#if 0	/* not used xdnd */

int xerr_catcher( Display *dpy, XErrorEvent *xe )
{
	int shouldWait = 1;
	printf( "xdnd_is_dnd_aware FAILED ****************  WAIT for debugger.\n" );
	while(shouldWait)
		sleep(1);
	return 0;
}

void
xdnd_set_type_list (DndClass *dnd, Window window, Atom *typelist)
{
	int n;

    for (n = 0; typelist[n]; n++);
    XChangeProperty (dnd->display, window, dnd->XdndTypeList, XA_ATOM, 32,
		     		PropModeReplace, (unsigned char *) typelist, n);
}

void
xdnd_get_type_list (DndClass *dnd, Window window, Atom **typelist)
{
	Atom type, *a;									// result must be free'd
	int format, i;
	unsigned long count, remaining;
	unsigned char *data = NULL;

    *typelist = 0;

    XGetWindowProperty (dnd->display, window, dnd->XdndTypeList,
						0, 0x8000000L, False, XA_ATOM,
						&type, &format, &count, &remaining, &data);

    if (type != XA_ATOM || format != 32 || count == 0 || !data)
		{
		if (data)
			XFree (data);
		NSLog(@"XGetWindowProperty failed in xdnd_get_type_list - \
					dnd->XdndTypeList = %ld", dnd->XdndTypeList);
		return;
		}
    *typelist = malloc ((count + 1) * sizeof (Atom));
    a = (Atom *) data;
    for (i = 0; i < count; i++)
		(*typelist)[i] = a[i];
    (*typelist)[count] = 0;

    XFree (data);
}

#endif  /* not used xdnd */

#endif  /* !FB_GRAPHICS */
