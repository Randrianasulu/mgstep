/*
   NSActionCell.m

   Abstract cell class for target/action paradigm

   Copyright (C) 1996-2016 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
   Date:    1996

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSCoder.h>
#include <AppKit/NSActionCell.h>
#include <AppKit/NSControl.h>


// Class variables
static Class __controlClass;


@implementation NSActionCell

+ (void) initialize
{
	if (self == [NSActionCell class])
		__controlClass = [NSControl class];
}

- (void) setAlignment:(NSTextAlignment)mode
{
	[super setAlignment:mode];
	if (_controlView && ([_controlView isKindOfClass: __controlClass]))
		[(NSControl *)_controlView updateCell: self];
}

- (void) setBezeled:(BOOL)flag
{
	[super setBezeled:flag];
	if (_controlView && ([_controlView isKindOfClass: __controlClass]))
		[(NSControl *)_controlView updateCell: self];
}

- (void) setBordered:(BOOL)flag
{
	[super setBordered:flag];
	if (_controlView && ([_controlView isKindOfClass: __controlClass]))
		[(NSControl *)_controlView updateCell: self];
}

- (void) setEnabled:(BOOL)flag
{
	[super setEnabled:flag];
	if (_controlView && ([_controlView isKindOfClass: __controlClass]))
		[(NSControl *)_controlView updateCell: self];
}

- (void) setFont:(NSFont *)fontObject
{
	[super setFont:fontObject];
	if (_controlView && ([_controlView isKindOfClass: __controlClass]))
		[(NSControl *)_controlView updateCell: self];
}

- (void) setImage:(NSImage *)image
{
	[super setImage:image];
	if (_controlView && ([_controlView isKindOfClass: __controlClass]))
		[(NSControl *)_controlView updateCell: self];
}

- (void) setStringValue:(NSString *)aString
{
	[super setStringValue:aString];
	if (_controlView && ([_controlView isKindOfClass: __controlClass]))
		[(NSControl *)_controlView updateCell: self];
}

- (void) setDoubleValue:(double)aDouble
{
	[super setDoubleValue:aDouble];
	if (_controlView && ([_controlView isKindOfClass: __controlClass]))
		[(NSControl *)_controlView updateCell: self];
}

- (void) setFloatValue:(float)aFloat
{
	[super setFloatValue:aFloat];
	if (_controlView && ([_controlView isKindOfClass: __controlClass]))
		[(NSControl *)_controlView updateCell: self];
}

- (void) setIntValue:(int)anInt
{
	[super setIntValue:anInt];
	if (_controlView && ([_controlView isKindOfClass: __controlClass]))
		[(NSControl *)_controlView updateCell: self];
}
															// Target / Action
- (id) target							{ return target; }
- (SEL) action							{ return action; }
- (void) setAction:(SEL)aSelector		{ action = aSelector; }
- (void) setTarget:(id)anObject			{ target = anObject; }
- (void) setTag:(int)anInt				{ tag = anInt; }
- (int) tag								{ return tag; }

- (id) copy
{
	NSActionCell *c = [super copy];

	c->tag = tag;
	c->target = target;
	c->action = action;
	
	return c;
}

- (void) encodeWithCoder:(NSCoder*)aCoder				// NSCoding protocol
{
	[super encodeWithCoder:aCoder];
	[aCoder encodeValueOfObjCType:"i" at:&tag];
	[aCoder encodeConditionalObject:target];
	[aCoder encodeValueOfObjCType:@encode(SEL) at:&action];
}

- (id) initWithCoder:(NSCoder*)aDecoder
{
	[super initWithCoder:aDecoder];
	[aDecoder decodeValueOfObjCType:"i" at:&tag];
	target = [aDecoder decodeObject];
	[aDecoder decodeValueOfObjCType:@encode(SEL) at:&action];

	return self;
}

@end /* NSActionCell */
