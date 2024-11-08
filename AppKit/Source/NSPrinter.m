/*
   NSPrinter.m

   Standard printer panels and related classes.
   NSPrinter, NSPrintInfo, NSPrintPanel, NSPageLayout, NSPrintOperation

   Copyright (C) 1996-2018 Free Software Foundation, Inc.

   Authors:  Simon Frankau <sgf@frankau.demon.co.uk>
   Date:	 June 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSValue.h>

#include <AppKit/NSGraphics.h>
#include <AppKit/NSPrinter.h>
#include <AppKit/NSPrintInfo.h>
#include <AppKit/NSPrintPanel.h>
#include <AppKit/NSPrintOperation.h>


// Class variables
static NSPrintInfo *__sharedPrintInfoObject = nil;


/* ****************************************************************************

	NSPrinter

** ***************************************************************************/

@implementation NSPrinter
@end

/* ****************************************************************************

	NSPrintInfo

** ***************************************************************************/

@implementation NSPrintInfo

+ (void) setSharedPrintInfo:(NSPrintInfo *)printInfo
{
	[__sharedPrintInfoObject release];
	__sharedPrintInfoObject = printInfo;
}

+ (NSPrintInfo *) sharedPrintInfo
{
	if (!__sharedPrintInfoObject)
		{
		NSDictionary *d = [[NSDictionary new] autorelease];

		__sharedPrintInfoObject = [[NSPrintInfo alloc] initWithDictionary:d];
		}

	return __sharedPrintInfoObject;
}

- (id) initWithDictionary:(NSDictionary *)aDict
{
	if ((self = [super init]))
		_info = [aDict retain];

	return self;
}

- (NSMutableDictionary *) dictionary			{ return [_info mutableCopy]; }

- (float) leftMargin
{
	return [(NSNumber*)[_info objectForKey:NSPrintLeftMargin] floatValue];
}

- (NSPrintingPaginationMode) verticalPagination
{
	return [(NSNumber*)[_info objectForKey:NSPrintVerticalPagination] intValue];
}

- (NSPrinter *) printer
{
	return [_info objectForKey:NSPrintPrinter];
}

- (void) setPrinter:(NSPrinter *)aPrinter
{
	[_info setObject:aPrinter forKey:NSPrintPrinter];
}

- (NSString *) jobDisposition
{
	return [_info objectForKey:NSPrintJobDisposition];
}

- (void) setJobDisposition:(NSString *)disposition
{
	[_info setObject:disposition forKey:NSPrintJobDisposition];
}

- (id) initWithCoder:(NSCoder*)aDecoder					// NSCoding protocol
{
	_info = [aDecoder decodePropertyList];
	return self;
}

- (void) encodeWithCoder:(NSCoder*)aCoder
{
	[aCoder encodePropertyList:_info];
}

@end  /* NSPrintInfo */

/* ****************************************************************************

	NSPrintPanel

** ***************************************************************************/

@implementation NSPrintPanel

+ (NSPrintPanel *) printPanel						{ return nil; }
- (int) runModal									{ return 0; }

@end

/* ****************************************************************************

	NSPageLayout

** ***************************************************************************/

@implementation NSPageLayout
@end

/* ****************************************************************************

	NSPrintOperation

** ***************************************************************************/

@implementation NSPrintOperation
@end
