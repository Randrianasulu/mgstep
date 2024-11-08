/*
   NSPropertyList.h

   XML property list serialization

   Copyright (c) 2003 DSITRI.

   Author:  Dr. H. Nikolaus Schaller
   Date:	Jul 14 2003

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSPropertyList
#define _mGSTEP_H_NSPropertyList

#include <Foundation/NSObject.h>

@class NSData;
@class NSString;
@class NSError;

typedef enum {
	NSPropertyListImmutable = 0,
	NSPropertyListMutableContainers,
	NSPropertyListMutableContainersAndLeaves
} NSPropertyListMutabilityOptions;			// NSPropertyListReadOptions

typedef enum {
	NSPropertyListOpenStepFormat = 0,		// OPENSTEP ASCII prop list
	NSPropertyListXMLFormat_v1_0,			// XML kCFPropertyListXMLFormat_v1_0
	NSPropertyListBinaryFormat_v1_0			// kCFPropertyListBinaryFormat_v1_0
} NSPropertyListFormat;


typedef NSUInteger NSPropertyListReadOptions;
typedef NSUInteger NSPropertyListWriteOptions;



@interface NSPropertyListSerialization : NSObject
{
}

+ (NSData *) dataWithPropertyList:(id)plist
						   format:(NSPropertyListFormat)format
						   options:(NSPropertyListWriteOptions)options
						   error:(NSError **)error;

+ (id) propertyListWithData:(NSData *) data
					options:(NSPropertyListReadOptions) opt
					format:(NSPropertyListFormat *) format
					error:(NSError **)error;

+ (BOOL) propertyList:(id)plist isValidForFormat:(NSPropertyListFormat)format;

@end


@interface NSCFType : NSObject
{ // used to read CF$UID values from (binary) keyedarchived property list
	unsigned value;
}

+ (id) CFUIDwithValue:(unsigned)value;
- (unsigned) uid;

@end

#endif /* _mGSTEP_H_NSPropertyList */
