/*
   NSAttributedString.h

   String class with attributes

   Copyright (C) 1997 Free Software Foundation, Inc.

   Author:	ANOQ of the sun <anoq@vip.cybercity.dk>
   Date:	November 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSAttributedString
#define _mGSTEP_H_NSAttributedString

#include <Foundation/NSObject.h>
#include <Foundation/NSRange.h>

@class NSString;
@class NSArray;
@class NSMutableArray;
@class NSDictionary;
@class NSMutableString;


@interface NSAttributedString : NSObject  <NSCoding,NSCopying,NSMutableCopying>
{
	id _string;
	NSMutableArray *_attributes;
	NSMutableArray *_locations;
}

- (id) initWithString:(NSString*)aString;
- (id) initWithAttributedString:(NSAttributedString*)attributedString;
- (id) initWithString:(NSString*)aString attributes:(NSDictionary*)attributes;

- (NSUInteger) length;										// character info
- (NSString *) string;

- (NSDictionary*) attributesAtIndex:(NSUInteger)index 		// attribute info
					 effectiveRange:(NSRange *)aRange;
- (NSDictionary*) attributesAtIndex:(NSUInteger)index 
				  longestEffectiveRange:(NSRange *)aRange 
				  inRange:(NSRange)rangeLimit;
- (id) attribute:(NSString *)attributeName 
		 atIndex:(NSUInteger)index 
		 effectiveRange:(NSRange *)aRange;
- (id) attribute:(NSString *)attributeName 
		 atIndex:(NSUInteger)index 
		 longestEffectiveRange:(NSRange *)aRange 
		 inRange:(NSRange)rangeLimit;
												// Compare attributed strings
- (BOOL) isEqualToAttributedString:(NSAttributedString *)otherString;
												// Extract substring
- (NSAttributedString *) attributedSubstringFromRange:(NSRange)aRange;

@end


@interface NSMutableAttributedString : NSAttributedString

- (NSMutableString *) mutableString;				// Retrieve char info

- (void) deleteCharactersInRange:(NSRange)aRange;	// Change chars

- (void) setAttributes:(NSDictionary *)attributes range:(NSRange)aRange;
- (void) addAttribute:(NSString *)name value:(id)value range:(NSRange)aRange;
- (void) addAttributes:(NSDictionary *)attributes range:(NSRange)aRange;
- (void) removeAttribute:(NSString *)name range:(NSRange)aRange;

													// Change chars and attribs
- (void) appendAttributedString:(NSAttributedString *)attributedString;
- (void) insertAttributedString:(NSAttributedString *)attributedString 
						atIndex:(NSUInteger)index;
- (void) replaceCharactersInRange:(NSRange)aRange 
			 withAttributedString:(NSAttributedString *)attributedString;
- (void) replaceCharactersInRange:(NSRange)aRange 
					   withString:(NSString *)aString;
- (void) setAttributedString:(NSAttributedString *)attributedString;

- (void) beginEditing;								// Group changes
- (void) endEditing;

@end

#endif /* _mGSTEP_H_NSAttributedString */
