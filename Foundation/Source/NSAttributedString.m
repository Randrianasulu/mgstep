/*
   NSAttributedString.m

   Implementation of string class with attributes

   Copyright (C) 1997 Free Software Foundation, Inc.

   Author:	ANOQ of the sun <anoq@vip.cybercity.dk>
   Date:	November 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

//FIXME: 1) The NSMutableString object returned from the -mutableString method
//       in NSMutableAttributedString is NOT tracked for changes to update
//       NSMutableAttributedString's attributes as it should.

#include <Foundation/NSAttributedString.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSException.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSValue.h>

static Class __attrStrClass;
static Class __mutableAttrStrClass;


static void
_setAttributesFrom( NSAttributedString *attributedString,
					NSRange aRange,
					NSMutableArray *attributeArray,
					NSMutableArray *locateArray)
{				// always called immediately after -initWithString:attributes:
	NSRange effectiveRange;
	NSDictionary *attributeDict;
	NSUInteger m;

	if(aRange.length == 0)
		return;										// No attributes

	attributeDict = [attributedString attributesAtIndex:aRange.location
									  effectiveRange:&effectiveRange];
	[attributeArray replaceObjectAtIndex:0 withObject:attributeDict];
	
	while ((m = NSMaxRange(effectiveRange)) < NSMaxRange(aRange))
		{
		attributeDict = [attributedString attributesAtIndex:m
										  effectiveRange:&effectiveRange];
		[attributeArray addObject:attributeDict];
		[locateArray addObject: [NSNumber numberWithUnsignedInt: 
								effectiveRange.location - aRange.location]];
		}
}

static NSDictionary *
_attributesAtIndexEffectiveRange( NSUInteger index,
								  NSRange *aRange,
								  NSUInteger tmpLength,
								  NSMutableArray *attributeArray,
								  NSMutableArray *locateArray,
								  NSUInteger *foundIndex)
{
	NSUInteger low, high, used, cnt, foundLoc, nextLoc;
	NSDictionary *foundDict;

	if(index >= tmpLength)
		[NSException raise:NSRangeException format: @"index out of range in \
							_attributesAtIndexEffectiveRange()"];

				// Binary search for efficiency in huge attributed strings
	used = [attributeArray count];
	low = 0;
	high = used - 1;
	while(low <= high)
		{
		cnt = (low + high) / 2;
		foundDict = [attributeArray objectAtIndex:cnt];
		foundLoc = [[locateArray objectAtIndex:cnt] unsignedIntValue];

		if(foundLoc > index)
			high = cnt-1;
		else
			{
			if(cnt >= used - 1)
				nextLoc = tmpLength;
			else
				nextLoc = [[locateArray objectAtIndex:cnt+1] unsignedIntValue];

			if(foundLoc == index || index < nextLoc)
				{											// Found
				if(aRange)
					{
					aRange->location = foundLoc;
					aRange->length = nextLoc - foundLoc;
					}
				if(foundIndex)
					*foundIndex = cnt;

				return foundDict;
				}
			else
				low = cnt+1;
		}	}

	NSLog(@"Error in binary search algorithm");
// NSCAssert(NO,@"Error in binary search algorithm");

	return nil;
}

@implementation NSAttributedString

+ (void) initialize
{
	if (self == [NSAttributedString class])
		{
		__attrStrClass = [NSAttributedString class];
		__mutableAttrStrClass = [NSMutableAttributedString class];
		}
}

- (id) copy										// NSCopying protocol
{
	if ([self isKindOfClass: [NSMutableAttributedString class]])
		return [[NSAttributedString alloc] initWithAttributedString:self];

	return [self retain];
}
												// NSMutableCopying protocol
- (id) mutableCopy
{
	return [[NSMutableAttributedString alloc] initWithAttributedString:self];
}

- (id) init
{
	return [self initWithString:nil attributes:nil];
}

- (id) initWithString:(NSString *)aString
{
	return [self initWithString:aString attributes:nil];
}

- (id) initWithAttributedString:(NSAttributedString *)attributedString
{
	NSString *t;

	if (!attributedString)
		return [self initWithString:nil attributes:nil];

	t = [attributedString string];
	if ((self = [self initWithString:t attributes:nil]))
		_setAttributesFrom(attributedString, NSMakeRange(0,[t length]),
							_attributes, _locations);
	return self;
}

- (id) initWithString:(NSString *)aString attributes:(NSDictionary *)attributes
{
	_string = [[NSString alloc] initWithString: aString];
	_attributes = [[NSMutableArray alloc] init];
	_locations = [[NSMutableArray alloc] init];
	if(!attributes)
		attributes = [[[NSDictionary alloc] init] autorelease];
	[_attributes addObject:attributes];
	[_locations addObject:[NSNumber numberWithUnsignedInt:0]];

	return self;
}

- (void) dealloc
{
	[_string release];
	[_attributes release];
	[_locations release];
	[super dealloc];
}

- (NSUInteger) length						{ return [_string length]; }
- (NSString *) string						{ return _string; }

- (NSDictionary *) attributesAtIndex:(NSUInteger)index
					  effectiveRange:(NSRange *)aRange
{
	return _attributesAtIndexEffectiveRange( index, aRange, 
				[self length], _attributes, _locations, NULL);
}

- (NSDictionary *) attributesAtIndex:(NSUInteger)index 
				   longestEffectiveRange:(NSRange *)aRange 
				   inRange:(NSRange)rangeLimit
{
	NSDictionary *attrDictionary, *tmpDictionary;
	NSRange tmpRange;

	if(NSMaxRange(rangeLimit) > [self length])
		[NSException raise:NSRangeException 
					 format:@"in -attributesAtIndex:longestEff.."];

	attrDictionary = [self attributesAtIndex:index effectiveRange:aRange];
	if(!aRange)
		return attrDictionary;
  
	while(aRange->location > rangeLimit.location)
		{										// Check extend range backwards
		tmpDictionary = [self attributesAtIndex:aRange->location-1
							  effectiveRange:&tmpRange];
		if([tmpDictionary isEqualToDictionary:attrDictionary])
			aRange->location = tmpRange.location;
		}
	while(NSMaxRange(*aRange) < NSMaxRange(rangeLimit))
		{										// Check extend range forwards
		tmpDictionary = [self attributesAtIndex:NSMaxRange(*aRange)
							  effectiveRange:&tmpRange];
		if([tmpDictionary isEqualToDictionary:attrDictionary])
			aRange->length = NSMaxRange(tmpRange) - aRange->location;
		}
	*aRange = NSIntersectionRange(*aRange,rangeLimit);	// Clip to rangeLimit

	return attrDictionary;
}

- (id) attribute:(NSString *)attributeName 
		 atIndex:(NSUInteger)index 
		 effectiveRange:(NSRange *)aRange
{
	NSDictionary *tmpDictionary;
	id attrValue;

	tmpDictionary = [self attributesAtIndex:index effectiveRange:aRange];
								// Raises exception if index is out of range
	if(!attributeName)
		{
		if(aRange)
			*aRange = NSMakeRange(0,[self length]);

      // If attributeName is nil, then the attribute will not exist in the
      // entire text - therefore aRange of the entire text must be correct
    
		return nil;
		}

	return (attrValue = [tmpDictionary objectForKey:attributeName]);
}

- (id) attribute:(NSString *)attributeName 
		 atIndex:(NSUInteger)index 
		 longestEffectiveRange:(NSRange *)aRange 
		 inRange:(NSRange)rangeLimit
{
	NSDictionary *tmpDictionary;
	id attrValue, tmpAttrValue;
	NSRange tmpRange;

	if(NSMaxRange(rangeLimit) > [self length])
		[NSException raise:NSRangeException
					 format: @"in -attribute:atIndex:longestEf..."];

	attrValue = [self attribute:attributeName 
					  atIndex:index 
					  effectiveRange:aRange];
								// Raises exception if index is out of range
	if(!attributeName)
		return nil;		// attribute:atIndex:effectiveRange: handles this case.
	if(!aRange)
		return attrValue;
  
	while(aRange->location > rangeLimit.location)
		{										// Check extend range backwards
		tmpDictionary = [self attributesAtIndex:aRange->location - 1
							  effectiveRange:&tmpRange];
		tmpAttrValue = [tmpDictionary objectForKey:attributeName];
		if(tmpAttrValue == attrValue)
			aRange->location = tmpRange.location;
		}
	while(NSMaxRange(*aRange) < NSMaxRange(rangeLimit))
		{										// Check extend range forwards
		tmpDictionary = [self attributesAtIndex:NSMaxRange(*aRange)
							  effectiveRange:&tmpRange];
		tmpAttrValue = [tmpDictionary objectForKey:attributeName];
		if(tmpAttrValue == attrValue)
			aRange->length = NSMaxRange(tmpRange) - aRange->location;
		}

	*aRange = NSIntersectionRange(*aRange,rangeLimit);	// Clip to rangeLimit

	return attrValue;
}
												// Comparing attributed strings
- (BOOL) isEqualToAttributedString:(NSAttributedString *)otherString
{
	NSRange ownEffectiveRange, otherEffectiveRange;
	NSUInteger length;
	NSDictionary *ownDictionary,*otherDictionary;
	BOOL result;

	if(!otherString || ![[otherString string] isEqual:[self string]])
		return NO;

	if((length = [otherString length]) <= 0)
		return YES;

	ownDictionary = [self attributesAtIndex:0
						  effectiveRange:&ownEffectiveRange];
	otherDictionary = [otherString attributesAtIndex:0
								   effectiveRange:&otherEffectiveRange];
	result = YES;
    
	while(YES)
		{
		if(NSIntersectionRange(ownEffectiveRange,otherEffectiveRange).length >0 
				&& ![ownDictionary isEqualToDictionary:otherDictionary])
			{
			result = NO;
			break;
			}
		if(NSMaxRange(ownEffectiveRange) < NSMaxRange(otherEffectiveRange))
			{
			ownDictionary = [self
			attributesAtIndex:NSMaxRange(ownEffectiveRange)
			effectiveRange:&ownEffectiveRange];
			}
		else
			{
			if(NSMaxRange(otherEffectiveRange) >= length)
				break;										// End of strings
			otherDictionary = [otherString attributesAtIndex: 
										NSMaxRange(otherEffectiveRange)
										effectiveRange:&otherEffectiveRange];
		}	}

	return result;
}

- (BOOL) isEqual:(id)anObject
{
	if (anObject == self)
		return YES;
	if ([anObject isKindOfClass:[NSAttributedString class]])
		return [self isEqualToAttributedString:anObject];
	return NO;
}

- (NSAttributedString *) attributedSubstringFromRange:(NSRange)aRange
{
	NSAttributedString *newAttrString;					// Extract a substring

	if(NSMaxRange(aRange) > [self length])
		[NSException raise:NSRangeException
					 format:@"RangeError in -attributedSubstringFromRange:"];

	newAttrString = [NSAttributedString alloc];
	[[newAttrString initWithString:[_string substringWithRange:aRange] 
					attributes:nil] autorelease];
	_setAttributesFrom(newAttrString, aRange,
				((NSAttributedString *)newAttrString)->_attributes, 
				((NSAttributedString *)newAttrString)->_locations);

	return newAttrString;
}

- (void) encodeWithCoder:(NSCoder *)aCoder				// NSCoding protocol
{
	[super encodeWithCoder:aCoder];
	[aCoder encodeObject:_string];
	[aCoder encodeObject:_attributes];
	[aCoder encodeObject:_locations];
}

- (id) initWithCoder:(NSCoder *)aCoder
{
	self = [super initWithCoder:aCoder];
	[aCoder decodeValueOfObjCType: @encode(id) at: &_string];
	[aCoder decodeValueOfObjCType: @encode(id) at: &_attributes];
	[aCoder decodeValueOfObjCType: @encode(id) at: &_locations];

	return self;
}

- (Class) classForPortCoder							{ return [self class]; }

- (id) replacementObjectForPortCoder:(NSPortCoder*)coder	{ return self; }

@end /* NSAttributedString */

/* ****************************************************************************

 		NSMutableAttributedString

** ***************************************************************************/

@implementation NSMutableAttributedString

- (id) initWithString:(NSString *)aString attributes:(NSDictionary *)attributes
{
	_string = [[NSMutableString alloc] initWithString: aString];
	_attributes = [[NSMutableArray alloc] init];
	_locations = [[NSMutableArray alloc] init];
	if(!attributes)
		attributes = [[[NSDictionary alloc] init] autorelease];
	[_attributes addObject:attributes];
	[_locations addObject:[NSNumber numberWithUnsignedInt:0]];

	return self;
}

- (NSAttributedString *) attributedSubstringFromRange:(NSRange)aRange
{
	NSAttributedString *newAttrString;					// Extract a substring
	NSString *newSubstring;

	if(NSMaxRange(aRange) > [self length])
		[NSException raise:NSRangeException
					 format:@"in -attributedSubstringFromRange:"];
	
	newSubstring = [[self string] substringWithRange:aRange];
	newAttrString = [[NSAttributedString alloc] initWithString:newSubstring 
												attributes:nil];
	[newAttrString autorelease];
	_setAttributesFrom(self, aRange, 
				((NSMutableAttributedString *)newAttrString)->_attributes, 
				((NSMutableAttributedString *)newAttrString)->_locations);

	return newAttrString;
}

- (NSMutableString *) mutableString			{ return [_string mutableCopy]; }
- (void) beginEditing						{ SUBCLASS }
- (void) endEditing							{ SUBCLASS }

- (void) deleteCharactersInRange:(NSRange)aRange
{
	[self replaceCharactersInRange:aRange withString:nil];
}

/* ****************************************************************************

	Primitive method! Sets attributes and values for a given range of
	characters, replacing any previous attributes and values for that range.

	Sets the attributes for the characters in aRange to attributes. These new
	attributes replace any attributes previously associated with the characters 
	aRange. Raises an NSRangeException if any part of aRange lies beyond the 
	end of the receiver's characters. 
	See also: - addAtributes:range:, - removeAttributes:range:

** ***************************************************************************/

- (void) setAttributes:(NSDictionary *)attributes range:(NSRange)range
{
	NSUInteger tmpLength, arrayIndex, arraySize, location;
	NSRange effectiveRange;
	NSNumber *afterRangeLocation, *beginRangeLocation;
	NSDictionary *attrs;
  
	if(!attributes)
		attributes = [NSDictionary dictionary];
	if(NSMaxRange(range) > (tmpLength = [self length]))
		[NSException raise:NSRangeException format:@"in setAttributes:range:"];

	arraySize = [_locations count];
	if(NSMaxRange(range) < tmpLength)
		{
		attrs = _attributesAtIndexEffectiveRange( NSMaxRange(range),
			&effectiveRange,tmpLength,_attributes,_locations,&arrayIndex);

		afterRangeLocation = [NSNumber numberWithUnsignedInt: 
								NSMaxRange(range)];
		if(effectiveRange.location > range.location)
			[_locations replaceObjectAtIndex:arrayIndex
							withObject:afterRangeLocation];
		else
			{
			arrayIndex++;
			[_attributes insertObject:attrs atIndex:arrayIndex];
			[_locations insertObject:afterRangeLocation atIndex:arrayIndex];
			}
		arrayIndex--;
		}
	else
		arrayIndex = arraySize - 1;
  
	while(arrayIndex > 0
		&& [[_locations objectAtIndex:arrayIndex-1] unsignedIntValue] >= range.location)
		{
		[_locations removeObjectAtIndex:arrayIndex];
		[_attributes removeObjectAtIndex:arrayIndex];
		arrayIndex--;
		}
	beginRangeLocation = [NSNumber numberWithUnsignedInt:range.location];
	location = [[_locations objectAtIndex:arrayIndex] unsignedIntValue];
	if(location >= range.location)
		{
		if(location > range.location)
			[_locations replaceObjectAtIndex:arrayIndex
						 withObject:beginRangeLocation];

		[_attributes replaceObjectAtIndex:arrayIndex withObject:attributes];
		}
	else
		{
		arrayIndex++;
		[_attributes insertObject:attributes atIndex:arrayIndex];
		[_locations insertObject:beginRangeLocation atIndex:arrayIndex];
		}
}

- (void) addAttribute:(NSString *)name value:(id)value range:(NSRange)aRange
{
	NSRange effectiveRange;
	NSDictionary *attrDict;
	NSMutableDictionary *newDict;
	NSUInteger tmpLength = [self length];

	if(NSMaxRange(aRange) > tmpLength)
		[NSException raise:NSRangeException
					 format:@"in -addAttribute:value:range:"];

	attrDict = [self attributesAtIndex:aRange.location
					 effectiveRange:&effectiveRange];

	while(effectiveRange.location < NSMaxRange(aRange))
		{
		effectiveRange = NSIntersectionRange(aRange,effectiveRange);
		
		newDict = [[NSMutableDictionary alloc] initWithDictionary:attrDict];
		[newDict autorelease];
		[newDict setObject:value forKey:name];
		[self setAttributes:newDict range:effectiveRange];
		
		if(NSMaxRange(effectiveRange) >= NSMaxRange(aRange))
			effectiveRange.location = NSMaxRange(aRange);	// stops the loop
		else
			if(NSMaxRange(effectiveRange) < tmpLength)
				attrDict = [self attributesAtIndex:NSMaxRange(effectiveRange)
								 effectiveRange:&effectiveRange];
		}
}

- (void) addAttributes:(NSDictionary *)attributes range:(NSRange)aRange
{
	NSRange effectiveRange;
	NSDictionary *attrDict;
	NSMutableDictionary *newDict;
	NSUInteger tmpLength;
  
// cant use NSParameterAssert hereif is has to be an NSInvalidArgumentException
	if(!attributes)
		[NSException raise:NSInvalidArgumentException
					 format:@"-addAttributes:range: nil attributes"];

	tmpLength = [self length];
	if(NSMaxRange(aRange) > tmpLength)
   		[NSException raise:NSRangeException format:@"-addAttribute:range:"];
  
	attrDict = [self attributesAtIndex:aRange.location
					 effectiveRange:&effectiveRange];

	while(effectiveRange.location < NSMaxRange(aRange))
		{
		effectiveRange = NSIntersectionRange(aRange,effectiveRange);
		
		newDict = [[NSMutableDictionary alloc] initWithDictionary:attrDict];
		[newDict autorelease];
		[newDict addEntriesFromDictionary:attributes];
		[self setAttributes:newDict range:effectiveRange];
		
		if(NSMaxRange(effectiveRange) >= NSMaxRange(aRange))
			effectiveRange.location = NSMaxRange(aRange); // stops the loop...
		else
			if(NSMaxRange(effectiveRange) < tmpLength)
				attrDict = [self attributesAtIndex:NSMaxRange(effectiveRange)
								 effectiveRange:&effectiveRange];
		}
}

- (void) removeAttribute:(NSString *)name range:(NSRange)aRange
{
	NSRange effectiveRange;
	NSDictionary *attrDict;
	NSMutableDictionary *newDict;
	NSUInteger tmpLength = [self length];
  
	if(NSMaxRange(aRange) > tmpLength)
		[NSException raise:NSRangeException format:@"-removeAttribute:range:"];

	attrDict = [self attributesAtIndex:aRange.location
    effectiveRange:&effectiveRange];

	while(effectiveRange.location < NSMaxRange(aRange))
		{
		effectiveRange = NSIntersectionRange(aRange,effectiveRange);
    
		newDict = [[NSMutableDictionary alloc] initWithDictionary:attrDict];
		[newDict autorelease];
		[newDict removeObjectForKey:name];
		[self setAttributes:newDict range:effectiveRange];
		
		if(NSMaxRange(effectiveRange) >= NSMaxRange(aRange))
			effectiveRange.location = NSMaxRange(aRange); // stops the loop...
		else
			if(NSMaxRange(effectiveRange) < tmpLength)
				attrDict = [self attributesAtIndex:NSMaxRange(effectiveRange)
								 effectiveRange:&effectiveRange];
		}
}
										// Changing characters and attributes
- (void) appendAttributedString:(NSAttributedString *)attributedString
{
	[self replaceCharactersInRange:NSMakeRange([self length],0)
		  withAttributedString:attributedString];
}

- (void) insertAttributedString:(NSAttributedString *)attributedString 
					   atIndex:(NSUInteger)index
{
	[self replaceCharactersInRange:NSMakeRange(index,0)
		  withAttributedString:attributedString];
}

- (void) replaceCharactersInRange:(NSRange)aRange 
			 withAttributedString:(NSAttributedString *)attributedString
{
	NSRange effectiveRange, clipRange, ownRange;
	NSDictionary *attrDict;
	NSString *tmpStr = [attributedString string];
  
	[self replaceCharactersInRange:aRange withString:tmpStr];
	effectiveRange = NSMakeRange(0,0);
	clipRange = NSMakeRange(0,[tmpStr length]);

	while(NSMaxRange(effectiveRange) < NSMaxRange(clipRange))
		{
		attrDict = [attributedString attributesAtIndex:effectiveRange.location
									 effectiveRange:&effectiveRange];
		ownRange = NSIntersectionRange(clipRange,effectiveRange);
		ownRange.location += aRange.location;
		[self setAttributes:attrDict range:ownRange];
		}
}

- (void) replaceCharactersInRange:(NSRange)range
		 			   withString:(NSString *)aString
{
	NSUInteger tmpLength, arrayIndex, arraySize, cnt, location, moveLocations;
	NSRange effectiveRange;
	NSDictionary *attrs;
	NSNumber *afterRangeLocation;

	if(!aString)
		aString = @"";
	if(NSMaxRange(range) > (tmpLength = [self length]))
		[NSException raise:NSRangeException
					 format:@"-replaceCharactersInRange:withString:"];

	arraySize = [_locations count];
	if(NSMaxRange(range) < tmpLength)
		{
		attrs = _attributesAtIndexEffectiveRange( NSMaxRange(range),
			&effectiveRange,tmpLength,_attributes,_locations,&arrayIndex);
    
		moveLocations = [aString length] - range.length;
		afterRangeLocation =
			[NSNumber numberWithUnsignedInt:NSMaxRange(range)+moveLocations];
    
		if(effectiveRange.location > range.location)
			[_locations replaceObjectAtIndex:arrayIndex
						 withObject:afterRangeLocation];
		else
			{
			arrayIndex++;
			[_attributes insertObject:attrs atIndex:arrayIndex];
			[_locations insertObject:afterRangeLocation atIndex:arrayIndex];
			}
    
		for(cnt = arrayIndex + 1; cnt < arraySize; cnt++)
			{
			location = [[_locations objectAtIndex:cnt] unsignedIntValue]
					+ moveLocations;
			[_locations replaceObjectAtIndex:cnt
						 withObject:[NSNumber numberWithUnsignedInt:location]];
			}
		arrayIndex--;
		}
	else
		arrayIndex = arraySize - 1;

	while(arrayIndex > 0 &&
    [[_locations objectAtIndex:arrayIndex] unsignedIntValue] > range.location)
		{
		[_locations removeObjectAtIndex:arrayIndex];
		[_attributes removeObjectAtIndex:arrayIndex];
		arrayIndex--;
		}
	[_string replaceCharactersInRange:range withString:aString];
}

- (void) setAttributedString:(NSAttributedString *)attributedString
{
	[self replaceCharactersInRange:NSMakeRange(0,[self length])
		  withAttributedString:attributedString];
}

@end /* NSMutableAttributedString */
