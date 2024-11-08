/*
   NSUndoManager.m

   Record operations for later undo and redo

   Copyright (C) 2009 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	Sep 2009

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSUndoManager.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSException.h>
#include <Foundation/NSInvocation.h>


// class variables
NSArray *__runLoopModes = nil;

NSString * const NSUndoManagerCheckpointNotification = @"UndoCheckpoint";

NSString * const NSUndoManagerWillUndoChangeNotification = @"WillUndoChange";
NSString * const NSUndoManagerWillRedoChangeNotification = @"WillRedoChange";

NSString * const NSUndoManagerDidUndoChangeNotification = @"DidUndoChange";
NSString * const NSUndoManagerDidRedoChangeNotification = @"DidRedoChange";

NSString * const NSUndoManagerDidOpenUndoGroupNotification = @"DidOpenUndoGroup";
NSString * const NSUndoManagerWillCloseUndoGroupNotification = @"WillCloseUndoGroup";


/* ****************************************************************************

	UndoGroup -- Private

** ***************************************************************************/

@interface UndoGroup : NSObject
{
	SEL _selector;
	id _target;
	id _argument;

    UndoGroup *_superUndoGroup;
    NSMutableArray *_actions;
	NSString *_actionName;
}

- (id) initWithSuperUndoGroup:(UndoGroup*)parent;

- (void) addObject:(id)object;
- (void) addUndoWithTarget:(id)target selector:(SEL)sel object:(id)obj;

- (void) undoNestedGroup;
- (void) performUndoAction;

- (NSMutableArray*) actions;
- (id) target;

- (UndoGroup *) superUndoGroup;

- (BOOL) removeActionsWithTarget:(id)target;

- (void) setActionName:(NSString*)name;

@end


@implementation	UndoGroup

- (id) initWithSuperUndoGroup:(UndoGroup*)group
{
	if (self = [super init])
		_superUndoGroup = group;					// top level has nil super

	return self;
}

- (void) addObject:(id)object
{
	if (!_actions)
		_actions = [[NSMutableArray alloc] initWithCapacity: 2];

	[_actions addObject: object];
}

- (void) addUndoWithTarget:(id)target selector:(SEL)sel object:(id)obj
{
	UndoGroup *g = [UndoGroup alloc];

	g->_selector = sel;
	g->_target = target;
	g->_argument = [obj retain];

	if (!_actions)
		_actions = [[NSMutableArray alloc] initWithCapacity: 2];

	[_actions addObject: g];
}

- (void) performUndoAction
{
	[_target performSelector:_selector withObject:_argument];
}

- (void) dealloc
{
	ASSIGN(_argument, nil);
	[_actions release];
	[super dealloc];
}

- (NSMutableArray*) actions					{ return _actions; }
- (id) target								{ return _target; }
- (UndoGroup *) superUndoGroup				{ return _superUndoGroup; }
- (void) setActionName:(NSString*)name		{ ASSIGN(_actionName, name); }

- (void) undoNestedGroup
{
	if (_actions)
		{
		unsigned i = [_actions count];

		while (i-- > 0)
			{
			id obj = [_actions objectAtIndex: i];

			if ([obj isKindOfClass: [NSInvocation class]])
				[obj invoke];
			else if ([obj superUndoGroup])		// recurse if nested group
				[obj undoNestedGroup];
			else
				[obj performUndoAction];
			}
		}
}

- (BOOL) removeActionsWithTarget:(id)target
{
	if (_actions)
		{
		unsigned i = [_actions count];

		while (i-- > 0)
			{
			id ot, obj = [_actions objectAtIndex: i];

			if ((ot = [obj target]) == target)
			  	[_actions removeObjectAtIndex: i];
			else if (!ot)						// nested group (nil target)
				{
				if (![obj removeActionsWithTarget: target])
			  		[_actions removeObjectAtIndex: i];
				}
			}

		if ([_actions count] > 0)
			return YES;
		}

	return NO;
}

@end  /* UndoGroup */

/* ****************************************************************************

	NSUndoManager

** ***************************************************************************/

@implementation NSUndoManager

- (id) init
{
	_um.groupsByEvent = YES;
	if (!_undoStack)
		_undoStack = [[NSMutableArray alloc] initWithCapacity: 10];
	if (!_redoStack)
		_redoStack = [[NSMutableArray alloc] initWithCapacity: 10];

	if (!__runLoopModes)
		__runLoopModes = [NSArray arrayWithObjects: NSDefaultRunLoopMode, nil];
	[self setRunLoopModes: __runLoopModes];

	return self;
}

- (void) dealloc
{
	[_undoStack release];
	[_redoStack release];
	[self setRunLoopModes: nil];

	[super dealloc];
}

/* ****************************************************************************

	Performs undo operations in the last undo group (top-level or nested)
	while recording the operations on the redo stack as a single group.

	Raises NSInternalInconsistencyException if any undo operations have been
	registered since the last enableUndoRegistration message.

	Posts:
	NSUndoManagerCheckpointNotification  and 
	NSUndoManagerWillUndoChangeNotification before it performs the undo ops.
	NSUndoManagerDidUndoChangeNotification after it performs the undo ops.

** ***************************************************************************/

- (void) undoNestedGroup
{
	NSNotificationCenter *n = [NSNotificationCenter defaultCenter];
	UndoGroup *g;

	if (_um.registeredCallback || _group)
		[NSException raise: NSInternalInconsistencyException
					 format: @"undoNestedGroup before endUndoGrouping"];

	if (_um.isUndoing)
		[NSException raise: NSInternalInconsistencyException
					 format: @"undoNestedGroup while undoing"];

	if ([_undoStack count] == 0)
		return;

	[n postNotificationName: NSUndoManagerCheckpointNotification object: self];
	[n postNotificationName: NSUndoManagerWillUndoChangeNotification object:self];

	_um.isUndoing = YES;
	g = [_undoStack lastObject];
	[g undoNestedGroup];
	[_undoStack removeLastObject];

	if (!_um.registeredCallback)				// nothing was registered
		_um.isUndoing = NO;

	[n postNotificationName: NSUndoManagerDidUndoChangeNotification object:self];
}

/* ****************************************************************************

	Closes the top-level undo group if necessary and invokes undoNestedGroup.
	Also invokes endUndoGrouping if the nesting level is 1. Raises an 
	NSInternalInconsistencyException if more than one undo group is open
	(that is, if the last group isn’t at the top level).

	This method posts an NSUndoManagerCheckpointNotification.

** ***************************************************************************/

- (void) undo
{
	if ([self groupingLevel] == 1)
		[self endUndoGrouping];

	[self undoNestedGroup];
}

/* ****************************************************************************

	Perform operations in the last group on the redo stack, if any, recording
	them on the undo stack as a single group.  

** ***************************************************************************/

- (void) redo
{
	NSNotificationCenter *n = [NSNotificationCenter defaultCenter];
	UndoGroup *g;

	if (_um.isUndoing)
		[NSException raise: NSInternalInconsistencyException
					 format: @"redo while undoing"];

	if ([_redoStack count] == 0)
		return;

	[n postNotificationName: NSUndoManagerCheckpointNotification object: self];
	[n postNotificationName: NSUndoManagerWillRedoChangeNotification object: self];

	_um.isRedoing = YES;
	g = [_redoStack lastObject];
	[g undoNestedGroup];						// sent directly to Undo group
	[_redoStack removeLastObject];

	if (!_um.registeredCallback)				// nothing was registered
		_um.isRedoing = NO;

	[n postNotificationName: NSUndoManagerDidRedoChangeNotification object: self];
}

- (void) setActionName:(NSString*)name           { ASSIGN(_actionName, name); }

- (NSString *) undoActionName  { return ([self canUndo]) ? _actionName : nil; }
- (NSString *) redoActionName  { return ([self canRedo]) ? _actionName : nil; }

- (NSString *) undoMenuItemTitle
{
	return [self undoMenuTitleForUndoActionName: [self undoActionName]];
}

- (NSString *) redoMenuItemTitle
{
	return [self redoMenuTitleForUndoActionName: [self redoActionName]];
}

- (NSString *) undoMenuTitleForUndoActionName:(NSString*)name
{
	if (!name || [name isEqual: @""])
		return @"Undo";

	return [NSString stringWithFormat: @"Undo %@", name];
}

- (NSString *) redoMenuTitleForUndoActionName:(NSString*)name
{
	if (!name || [name isEqual: @""])
		return @"Redo";

	return [NSString stringWithFormat: @"Redo %@", name];
}

/* ****************************************************************************

	Undo groups are begun automatically when ops are registered for recording.
	All undo operations until a subsequent endUndoGrouping message are grouped
	together and can be reverted by a later undo message.   Nested groups can
	be created within other groups by invoking this method directly. 

	Posts:
	NSUndoManagerCheckpointNotification unless a top-level undo is in progress.
	NSUndoManagerDidOpenUndoGroupNotification if a new group was created.

** ***************************************************************************/

- (void) beginUndoGrouping
{
	NSNotificationCenter *n = [NSNotificationCenter defaultCenter];

	if (!_um.isUndoing)
		[n postNotificationName: NSUndoManagerCheckpointNotification object: self];

	if ((_group = [[UndoGroup alloc] initWithSuperUndoGroup: _group]))
		[n postNotificationName: NSUndoManagerDidOpenUndoGroupNotification object: self];
	else
		[NSException raise: NSInternalInconsistencyException
					 format: @"beginUndoGrouping failed to begin a new group"];
}

- (void) endUndoGrouping
{
	NSNotificationCenter *n = [NSNotificationCenter defaultCenter];
	UndoGroup *g = _group;

	if (!_group)
		[NSException raise: NSInternalInconsistencyException
					 format: @"endUndoGrouping no open group"];

	[n postNotificationName: NSUndoManagerCheckpointNotification object: self];
	[n postNotificationName: NSUndoManagerWillCloseUndoGroupNotification object: self];

	if ((_group = [_group superUndoGroup]) == nil)		// top level, no super
		{
		if (_um.isUndoing)
			{
			if (_levelsOfUndo > 0 && [_redoStack count] == _levelsOfUndo)
				[_redoStack removeObjectAtIndex: 0];
			[_redoStack addObject: g];
			}
		else
			{
			if (_levelsOfUndo > 0 && [_undoStack count] == _levelsOfUndo)
				[_undoStack removeObjectAtIndex: 0];
			[_undoStack addObject: g];
			}
		}
	else if ([g actions] != nil)		// clase sub groups by adding them to
		[_group addObject: g];			// their super group
		
	_um.isUndoing = _um.isRedoing = NO;
}

- (BOOL) canUndo			{ return ([_undoStack count] > 0); }
- (BOOL) canRedo			{ return ([_redoStack count] > 0); }
- (BOOL) isUndoing			{ return _um.isUndoing; }
- (BOOL) isRedoing			{ return _um.isRedoing; }
- (BOOL) groupsByEvent		{ return _um.groupsByEvent; }

- (unsigned int) groupingLevel
{
	UndoGroup *g = (UndoGroup*)_group;
	unsigned glevel;

	for (glevel = 0; g != nil; g = [g superUndoGroup], glevel++);

	return glevel;							// zero means no open groups
}

/* ****************************************************************************

	_closeUndoGroup:

	The Undo manager registers this callback to automatically close undo
	groups during each cycle of the RunLoop if groupsByEvent is YES (default).  
	If automatic grouping is disabled, groups must be manually closed before
	invoking either undo or undoNestedGroup.

** ***************************************************************************/

- (void) _closeUndoGroup:(id)sender
{
	if (_um.groupsByEvent && _group)
		[self endUndoGrouping];
	_um.registeredCallback = NO;
}

- (void) setRunLoopModes:(NSArray *)runLoopModes
{
	if (!runLoopModes || ![runLoopModes isEqualToArray:  _runLoopModes])
		{
		NSRunLoop *rl = [NSRunLoop currentRunLoop];
		SEL s = @selector(_closeUndoGroup:);

		if (_runLoopModes && _um.registeredCallback)
			[rl cancelPerformSelector:s target:self argument:nil];
		
		if (runLoopModes && _um.registeredCallback)
			[rl performSelector: s
				target: self
				argument: rl
				order: NSUndoCloseGroupingRunLoopOrdering
				modes: runLoopModes];
		ASSIGN(_runLoopModes, runLoopModes);
		}
}

- (NSArray *) runLoopModes				{ return _runLoopModes; }
- (BOOL) isUndoRegistrationEnabled		{ return (_disabled == 0); }

/* ****************************************************************************

	Registration is enabled by default.  This method can be called multiple 
	times and is used to balance a prior disableUndoRegistration message.
	Undo registration is not re-enabled until the count reaches zero.
	
** ***************************************************************************/

- (void) enableUndoRegistration
{
	if (_disabled == 0)
		[NSException raise: NSInternalInconsistencyException
					 format: @"enableUndoRegistration already enabled"];

	if (--_disabled == 0)
		[self setRunLoopModes: __runLoopModes];
}

- (void) disableUndoRegistration
{
	if (_disabled++ == 0)
		[self setRunLoopModes: nil];
}

- (unsigned int) levelsOfUndo			{ return _levelsOfUndo; }

- (void) setLevelsOfUndo:(unsigned int)levels
{
	_levelsOfUndo = levels;
	
	if (_levelsOfUndo > 0 && [_undoStack count] > _levelsOfUndo)
		{
		unsigned int i = [_undoStack count] - _levelsOfUndo;
		
		while (i--)
			[_undoStack removeObjectAtIndex: 0];
		}
}

- (void) registerUndoWithTarget:(id)target selector:(SEL)sel object:(id)obj
{
	if (_um.groupsByEvent && _runLoopModes && !_um.registeredCallback)
		{
		NSRunLoop *rl = [NSRunLoop currentRunLoop];

		[self beginUndoGrouping];

		if (!_group)
			[NSException raise: NSInternalInconsistencyException
						 format: @"registerUndoWithTarget no open group"];

		[rl performSelector: @selector(_closeUndoGroup:)
			target: self
			argument: rl
			order: NSUndoCloseGroupingRunLoopOrdering
			modes: _runLoopModes];
		_um.registeredCallback = YES;
		}

	[_group addUndoWithTarget:target selector:sel object:obj];

	if (!_um.isUndoing && !_um.isRedoing)
		[_redoStack removeAllObjects];
}

/* ****************************************************************************

	prepareWithInvocationTarget -- prepare to recieve a forwardInvocation:
	
	called as: [[undoManager prepareWithInvocationTarget:self] setFont: oldFont
                                                               color: oldColor]
	Later when undo is called, the specified target will be called with:
	[target setFont:oldFont color:oldColor]

** ***************************************************************************/

- (id) prepareWithInvocationTarget:(id)target
{
	_target = target;

	if (_um.groupsByEvent && _runLoopModes && !_um.registeredCallback)
		{
		NSRunLoop *rl = [NSRunLoop currentRunLoop];

		[self beginUndoGrouping];

		if (!_group)
			[NSException raise: NSInternalInconsistencyException
						 format: @"prepareWithInvocationTarget no open group"];

		[rl performSelector: @selector(_closeUndoGroup:)
			target: self
			argument: rl
			order: NSUndoCloseGroupingRunLoopOrdering
			modes: _runLoopModes];
		_um.registeredCallback = YES;
		}

	if (!_um.isUndoing && !_um.isRedoing)
		[_redoStack removeAllObjects];

	return self;
}

- (void) forwardInvocation:(NSInvocation *)invocation
{
	if (!_target)
		[NSException raise: NSInternalInconsistencyException
					 format: @"forwardInvocation not prepared with target"];

	[invocation setTarget: _target];
	[_group addObject: invocation];
	_target = nil;
}

- (void) removeAllActions
{
	[_redoStack removeAllObjects];
	[_undoStack removeAllObjects];
	_um.isUndoing = NO;
	_um.isRedoing = NO;
}

- (void) removeAllActionsWithTarget:(id)target
{
	unsigned i;

	for (i = [_redoStack count]; i > 0; i--)
		if (![[_redoStack objectAtIndex: i] removeActionsWithTarget: target])
			[_redoStack removeObjectAtIndex: i];

	for (i = [_undoStack count]; i > 0; i--)
		if (![[_undoStack objectAtIndex: i] removeActionsWithTarget: target])
			[_undoStack removeObjectAtIndex: i];
}

@end
