/*
   xdnd.h

   Xdnd protocol developed by John Lindal
   http://www.cco.caltech.edu/~jafl/xdnd/

   Xdnd protocol routines derived from code published by
   Copyright (C) 1998  Paul Sheer <psheer@obsidian.co.za>

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _X_DND_H
#define _X_DND_H

#define XDND_VERSION 3
#define XDND_MAX_SUPPORTED_TYPES 2

																// XdndEnter
#define XDND_THREE 3
#define XDND_ENTER_SOURCE_WIN(e)		((e)->xclient.data.l[0])
#define XDND_ENTER_THREE_TYPES(e)		(((e)->xclient.data.l[1] & 0x1UL) == 0)
#define XDND_ENTER_THREE_TYPES_SET(e,b)	(e)->xclient.data.l[1] = ((e)->xclient.data.l[1] & ~0x1UL) | (((b) == 0) ? 0 : 0x1UL)
#define XDND_ENTER_VERSION(e)			((e)->xclient.data.l[1] >> 24)
#define XDND_ENTER_VERSION_SET(e,v)		(e)->xclient.data.l[1] = ((e)->xclient.data.l[1] & ~(0xFF << 24)) | ((v) << 24)
#define XDND_ENTER_TYPE(e,i)			((e)->xclient.data.l[2 + i])	/* i => (0, 1, 2) */

																// XdndPosition
#define XDND_POSITION_SOURCE_WIN(e)		((e)->xclient.data.l[0])
#define XDND_POSITION_ROOT_X(e)			((e)->xclient.data.l[2] >> 16)
#define XDND_POSITION_ROOT_Y(e)			((e)->xclient.data.l[2] & 0xFFFFUL)
#define XDND_POSITION_ROOT_SET(e,x,y)	(e)->xclient.data.l[2]  = ((x) << 16) | ((y) & 0xFFFFUL)
#define XDND_POSITION_TIME(e)			((e)->xclient.data.l[3])
#define XDND_POSITION_ACTION(e)			((e)->xclient.data.l[4])

																// XdndStatus
#define XDND_STATUS_TARGET_WIN(e)			((e)->xclient.data.l[0])
#define XDND_STATUS_WILL_ACCEPT(e)			((e)->xclient.data.l[1] & 0x1L)
#define XDND_STATUS_WILL_ACCEPT_SET(e,b)	(e)->xclient.data.l[1] = ((e)->xclient.data.l[1] & ~0x1UL) | (((b) == 0) ? 0 : 0x1UL)
#define XDND_STATUS_WANT_POSITION(e)		((e)->xclient.data.l[1] & 0x2UL)
#define XDND_STATUS_WANT_POSITION_SET(e,b)	(e)->xclient.data.l[1] = ((e)->xclient.data.l[1] & ~0x2UL) | (((b) == 0) ? 0 : 0x2UL)
#define XDND_STATUS_RECT_X(e)				((e)->xclient.data.l[2] >> 16)
#define XDND_STATUS_RECT_Y(e)				((e)->xclient.data.l[2] & 0xFFFFL)
#define XDND_STATUS_RECT_WIDTH(e)			((e)->xclient.data.l[3] >> 16)
#define XDND_STATUS_RECT_HEIGHT(e)			((e)->xclient.data.l[3] & 0xFFFFL)
#define XDND_STATUS_RECT_SET(e,x,y,w,h)		{(e)->xclient.data.l[2] = ((x) << 16) | ((y) & 0xFFFFUL); (e)->xclient.data.l[3] = ((w) << 16) | ((h) & 0xFFFFUL); }
#define XDND_STATUS_ACTION(e)				((e)->xclient.data.l[4])

																// XdndLeave
#define XDND_LEAVE_SOURCE_WIN(e)	((e)->xclient.data.l[0])

																// XdndDrop
#define XDND_DROP_SOURCE_WIN(e)		((e)->xclient.data.l[0])
#define XDND_DROP_TIME(e)			((e)->xclient.data.l[2])

																// XdndFinished
#define XDND_FINISHED_TARGET_WIN(e)	((e)->xclient.data.l[0])

typedef struct _DndClass DndClass;

struct _DndClass {

    Display *display;

    Atom XdndAware;
    Atom XdndSelection;
    Atom XdndEnter;
    Atom XdndLeave;
    Atom XdndPosition;
    Atom XdndDrop;
    Atom XdndFinished;
    Atom XdndStatus;
    Atom XdndActionCopy;
    Atom XdndActionMove;
    Atom XdndActionLink;
    Atom XdndActionAsk;
    Atom XdndActionPrivate;
    Atom XdndTypeList;
    Atom types[XDND_MAX_SUPPORTED_TYPES];
    Atom version;

    int dragging_version;
    Time time;
};

void xdnd_set_dnd_aware (DndClass *dnd, Window window, Atom *typelist);

int xdnd_is_dnd_aware (DndClass *dnd, 
					   Window window, 
					   int *version, 
					   Atom *typelist);

void xdnd_set_type_list (DndClass *dnd, Window window, Atom *typelist);

int xdnd_convert_selection (DndClass *dnd, 
							Window window, 
							Window requester, 
							Atom type);

void xdnd_selection_send (DndClass *dnd, 
						  XSelectionRequestEvent * request, 
						  unsigned const char *data, 
						  int length);

void xdnd_send_enter (DndClass *dnd, 				// messages sent to target
					  Window window,				// by the source
					  Window from, 
					  Atom *typelist);

void xdnd_send_position (DndClass *dnd, 
						 Window window, 
						 Window from, 
						 Atom action, 
						 int x, int y, 
						 unsigned long etime);

void xdnd_send_leave (DndClass *dnd, Window window, Window from);

void xdnd_send_drop (DndClass *dnd, 
					 Window window, 
					 Window from, 
					 unsigned long etime);

void xdnd_send_status (DndClass *dnd,				// messages returned from
					   Window window, 				// target to the source
					   Window from, 
					   int x, int y, int w, int h, 
					   Atom action);

void xdnd_send_finished (DndClass *dnd, 
						 Window window, 
						 Window from, 
						 int error);

/* ****************************************************************************

   XR XDND

** ***************************************************************************/

Atom XRActionForDragOperation(unsigned int op);
unsigned int XRDragOperationForAction(Atom xaction);
void XRProcessXDNDStatus(Display *xDisplay, XEvent *xEvent);
void XRProcessXDND(CGContextRef cx, XEvent *xEvent);

void XRSetXDNDAware(CGContext *cx, Window window);
BOOL XRIsWindowXDNDAware(CGContext *cx, Window window);

#endif 	/* !_X_DND_H */
