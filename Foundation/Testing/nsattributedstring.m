/* 
   test.m

   Test NSAttributedString and NSMutableAttributedString classes

   Copyright (C) 1997 Free Software Foundation, Inc.

   Author:	ANOQ of the sun <anoq@vip.cybercity.dk>
   Date:	June 1997
   
   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSAttributedString.h>
#include <Foundation/NSAutoreleasePool.h>

// These are normally defined in the AppKit
NSString *NSFontAttributeName = @"NSFont";
NSString *NSForegroundColorAttributeName = @"NSForegroundColor";
NSString *NSBackgroundColorAttributeName = @"NSBackgroundColor";

void
print(NSAttributedString *attrStr)
{
NSEnumerator *keyEnumerator;
NSString *tmpStr;
NSRange effectiveRange = NSMakeRange(0,0);
unsigned int tmpLength = [attrStr length];
  
	puts("Attributed string looks like this:");
	while(NSMaxRange(effectiveRange) < tmpLength)
		{
		NSDictionary *tmpAttrDict = [attrStr 
				attributesAtIndex:NSMaxRange(effectiveRange)
				effectiveRange:&effectiveRange];
		printf("String: '%s'  attributes: ",[[attrStr string] cString]);
		keyEnumerator = [tmpAttrDict keyEnumerator];
		while((tmpStr = [keyEnumerator nextObject]))
			printf("%s ",[tmpStr cString]);
		printf("location: %ld length: %ld\n", (long)effectiveRange.location,
												(long)effectiveRange.length);
		}
}

void
testAttributedString(void)
{
NSAttributedString *attrString;
NSMutableAttributedString *muAttrString,*muAttrString2;
NSMutableDictionary *attributes,*colorAttributes,*twoAttributes;
  
	attributes = [[[NSMutableDictionary alloc] init] autorelease];
	[attributes setObject:@"Helvetica 12-point"
				forKey:NSFontAttributeName];
	colorAttributes = [[[NSMutableDictionary alloc] init] autorelease];
	[colorAttributes setObject:@"black NSColor"
					 forKey:NSForegroundColorAttributeName];
	twoAttributes = [[[NSMutableDictionary alloc] init] autorelease];
	[twoAttributes addEntriesFromDictionary:attributes];
	[twoAttributes setObject:@"red NSColor"
				   forKey:NSBackgroundColorAttributeName];
	
	attrString = [[NSAttributedString alloc] 
		initWithString:@"Attributed string test" attributes:twoAttributes];
	[attrString autorelease];
	print(attrString);
	
	muAttrString = [[NSMutableAttributedString alloc] initWithString:
		@"Testing the Mutable version" attributes:colorAttributes];
	[muAttrString autorelease];
	print(muAttrString);
	
	[muAttrString setAttributes:attributes range:NSMakeRange(2,4)];
	print(muAttrString);
	
	[muAttrString setAttributes:attributes range:NSMakeRange(8,16)];
	print(muAttrString);
	
	[muAttrString addAttributes:colorAttributes range:NSMakeRange(5,12)];
	print(muAttrString);
	
	muAttrString2 = [muAttrString mutableCopy];
	print(muAttrString2);
	
	[muAttrString replaceCharactersInRange:NSMakeRange(5,15)
				  withAttributedString:attrString];
	print(muAttrString);
	
	[muAttrString2 replaceCharactersInRange:NSMakeRange(15,5)
				   withAttributedString:attrString];
	print(muAttrString2);
	
	print([muAttrString2 attributedSubstringFromRange:NSMakeRange(10,7)]);
}

int
main()
{
NSAutoreleasePool *p = [NSAutoreleasePool new];

	testAttributedString();
	[p release];
	printf("nsattributedstring test complete\n");
	
	exit(0);
}
