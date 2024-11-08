/*
   NSUndoManager.h

   Record operations for later undo and redo

   Copyright (C) 2009 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	October 2009

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSUndoManager
#define _mGSTEP_H_NSUndoManager

#include <Foundation/NSObject.h>

@class NSInvocation;
@class NSMutableArray;
@class NSArray;
@class NSString;

/* ****************************************************************************

	Perform simple undo and redo by sending undo and redo messages to an
	NSUndoManager object.  An undo message closes the last open undo group
	and then applies all the undo operations in that group.  During the undo
	it records any received undo operations as redo operations instead.
	A redo message applies all the redo operations on the top redo group.

	The undo method is intended for undoing top-level groups and should not
	be used for nested undo groups. If any un-closed, nested undo groups are
	on the stack when undo is invoked an exception is raised. To undo nested
	groups, you must explicitly close the group with an endUndoGrouping
	message, then use undoNestedGroup to undo it.  Note also that if you
	turn off automatic grouping by event with setGroupsByEvent: you must
	explicitly close the current undo group with endUndoGrouping before
	invoking either undo method.

** ***************************************************************************/

@interface NSUndoManager : NSObject
{
	id _target;
	id _group;
	NSString *_actionName;
	NSMutableArray *_undoStack;
	NSMutableArray *_redoStack;
    NSArray *_runLoopModes;
	unsigned int _levelsOfUndo;
	int _disabled;

	struct __UndoFlags {
		unsigned int isUndoing:1;
		unsigned int isRedoing:1;
		unsigned int groupsByEvent:1;
		unsigned int postNotifications:1;
		unsigned int registeredCallback:1;
		unsigned int reserved:27;
	} _um;
}

- (void) undo;
- (void) redo;

- (void) beginUndoGrouping;
- (void) endUndoGrouping;

- (BOOL) groupsByEvent;		// groups all undos registered during a RunLoop
							// cycle into a top level group. enabled by default
- (BOOL) canUndo;
- (BOOL) canRedo;
- (BOOL) isUndoing;
- (BOOL) isRedoing;
											// restrict data capture to mode
- (void) setRunLoopModes:(NSArray *)runLoopModes;
- (NSArray *) runLoopModes;

- (void) enableUndoRegistration;
- (void) disableUndoRegistration;
- (BOOL) isUndoRegistrationEnabled;

- (void) setActionName:(NSString*)name;
- (NSString *) undoActionName;
- (NSString *) redoActionName;
- (NSString *) undoMenuItemTitle;
- (NSString *) redoMenuItemTitle;
- (NSString *) undoMenuTitleForUndoActionName:(NSString*)name;
- (NSString *) redoMenuTitleForUndoActionName:(NSString*)name;

- (void) setLevelsOfUndo:(unsigned int)levels;
- (unsigned int) levelsOfUndo;
- (unsigned int) groupingLevel;			// zero means no open groups

- (void) removeAllActions;
- (void) removeAllActionsWithTarget:(id)target;

- (void) registerUndoWithTarget:(id)target selector:(SEL)sel object:(id)obj;

- (id) prepareWithInvocationTarget:(id)target;

- (void) forwardInvocation:(NSInvocation *)invocation;

@end

		// NSRunLoop priority -- performSelector:target:argument:order:modes:
enum {
	NSUndoCloseGroupingRunLoopOrdering = 350000
};

#endif  /* _mGSTEP_H_NSUndoManager */
