/*
   NSPrinter.h

   Classes representing a printer and its print jobs

   Copyright (C) 1996-2018 Free Software Foundation, Inc.

   Authors:  Simon Frankau <sgf@frankau.demon.co.uk>
   Date: June 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSPrinter
#define _mGSTEP_H_NSPrinter

#include <Foundation/NSCoder.h>
#include <Foundation/NSGeometry.h>

@class NSString;
@class NSArray;
@class NSDictionary;
@class NSMutableDictionary;
@class NSGraphicsContext;
@class NSPrintPanel;
@class NSView;

typedef enum {
	NSPrinterTableOK,
	NSPrinterTableNotFound,
	NSPrinterTableError
} NSPrinterTableStatus;


@interface NSPrinter : NSObject
{
	NSString *printerName;
	NSString *printerType;
}

@end


@interface NSPrinter  (NotImplemented)

+ (NSPrinter *) printerWithName:(NSString *)name;
+ (NSPrinter *) printerWithType:(NSString *)type;

+ (NSArray *) printerNames;
+ (NSArray *) printerTypes;

- (NSString *) name;
- (NSString *) type;

- (NSSize) pageSizeForPaper:(NSString *)paperName;
- (int) languageLevel;

- (NSDictionary *) deviceDescription;

@end

/* ****************************************************************************

	NSPrintInfo

** ***************************************************************************/

typedef enum _NSPrintingOrientation {
	NSPortraitOrientation,
	NSLandscapeOrientation
} NSPrintingOrientation;

typedef enum _NSPrintingPaginationMode {
	NSAutoPagination,
	NSFitPagination,
	NSClipPagination
} NSPrintingPaginationMode;


@interface NSPrintInfo : NSObject  <NSCoding>
{
	NSMutableDictionary *_info;
}

+ (NSPrintInfo *) sharedPrintInfo;
+ (void) setSharedPrintInfo:(NSPrintInfo *)printInfo;

- (id) initWithDictionary:(NSDictionary *)d;

@end


@interface NSPrintInfo  (NotImplemented)

- (float) topMargin;
- (float) bottomMargin;
- (float) leftMargin;
- (float) rightMargin;

- (NSPrintingOrientation) orientation;
- (NSString *) paperName;
- (NSSize) paperSize;

- (void) setBottomMargin:(float)value;
- (void) setLeftMargin:(float)value;
- (void) setOrientation:(NSPrintingOrientation)mode;
- (void) setPaperName:(NSString *)name;
- (void) setPaperSize:(NSSize)size;
- (void) setRightMargin:(float)value;
- (void) setTopMargin:(float)value;

- (NSPrintingPaginationMode) verticalPagination;			// Pagination
- (NSPrintingPaginationMode) horizontalPagination;
- (void) setHorizontalPagination:(NSPrintingPaginationMode)mode;
- (void) setVerticalPagination:(NSPrintingPaginationMode)mode;

- (BOOL) isHorizontallyCentered;							// Image position
- (BOOL) isVerticallyCentered;
- (void) setHorizontallyCentered:(BOOL)flag;
- (void) setVerticallyCentered:(BOOL)flag;

+ (NSPrinter*) defaultPrinter;
- (NSPrinter*) printer;
- (void) setPrinter:(NSPrinter *)aPrinter;

- (NSString*) jobDisposition;								// Printer control
- (void) setJobDisposition:(NSString *)disposition;
- (void) setUpPrintOperationDefaultValues;

//
// Accessing the NSPrintInfo Object's Dictionary
//
- (NSMutableDictionary*) dictionary;

@end

//
// Printing Information Dictionary Keys 
//
extern NSString *NSPrintAllPages;
extern NSString *NSPrintBottomMargin;
extern NSString *NSPrintCopies;
extern NSString *NSPrintFaxCoverSheetName;
extern NSString *NSPrintFaxHighResolution;
extern NSString *NSPrintFaxModem;
extern NSString *NSPrintFaxReceiverNames;
extern NSString *NSPrintFaxReceiverNumbers;
extern NSString *NSPrintFaxReturnReceipt;
extern NSString *NSPrintFaxSendTime;
extern NSString *NSPrintFaxTrimPageEnds;
extern NSString *NSPrintFaxUseCoverSheet;
extern NSString *NSPrintFirstPage;
extern NSString *NSPrintHorizontalPagination;
extern NSString *NSPrintHorizontallyCentered;
extern NSString *NSPrintJobDisposition;
extern NSString *NSPrintLastPage;
extern NSString *NSPrintLeftMargin;
extern NSString *NSPrintOrientation;
extern NSString *NSPrintPackageException;
extern NSString *NSPrintPaperName;
extern NSString *NSPrintPaperSize;
extern NSString *NSPrintPrinter;
extern NSString *NSPrintReversePageOrder;
extern NSString *NSPrintRightMargin;
extern NSString *NSPrintScalingFactor;
extern NSString *NSPrintTopMargin;
extern NSString *NSPrintVerticalPagination;
extern NSString *NSPrintVerticallyCentered;

//
// Print Job Disposition Values 
//
extern NSString *NSPrintCancelJob;
extern NSString *NSPrintFaxJob;
extern NSString *NSPrintPreviewJob;
extern NSString *NSPrintSaveJob;
extern NSString *NSPrintSpoolJob;

/* ****************************************************************************

	NSPrintOperation

** ***************************************************************************/

typedef enum {
	NSDescendingPageOrder,
	NSSpecialPageOrder,
	NSAscendingPageOrder,
	NSUnknownPageOrder
} NSPrintingPageOrder;


@interface NSPrintOperation : NSObject
@end


@interface NSPrintOperation  (NotImplemented)

+ (NSPrintOperation *) printOperationWithView:(NSView *)aView;
+ (NSPrintOperation *) printOperationWithView:(NSView *)aView
									printInfo:(NSPrintInfo *)aPrintInfo;

+ (NSPrintOperation *) currentOperation;
+ (void) setCurrentOperation:(NSPrintOperation *)operation;

- (void) setShowsPrintPanel:(BOOL)flag;
- (BOOL) showsPrintPanel;

- (NSPrintPanel *) printPanel;
- (void) setPrintPanel:(NSPrintPanel *) panel;

- (NSGraphicsContext *) createContext;					// Graphics Context
- (NSGraphicsContext *) context;
- (void) destroyContext;

- (int) currentPage;									// Page Information
- (NSPrintingPageOrder) pageOrder;
- (void) setPageOrder:(NSPrintingPageOrder)order;

- (void) cleanUpOperation;
- (BOOL) deliverResult;
- (BOOL) runOperation;

- (NSPrintInfo *) printInfo;
- (void) setPrintInfo:(NSPrintInfo *)aPrintInfo;

- (NSView *) view;

@end

#endif /* _mGSTEP_H_NSPrinter */
