/*
   AXExterns.m

   External constant string definitions

   Copyright (C) 1997 Free Software Foundation, Inc.

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>


// Global strings
NSString *NSModalPanelRunLoopMode = @"ModalPanelMode";
NSString *NSEventTrackingRunLoopMode = @"EventTrackingMode";
NSString *NSApplicationIcon = @"NSApplicationIcon";        

//
// Global Exception Strings 
//
NSString *NSAbortModalException = @"NSAbortModalException";
NSString *NSAppKitIgnoredException = @"AppKitIgnored";
NSString *NSAppKitVirtualMemoryException = @"AppKitVirtualMemory";
NSString *NSBadBitmapParametersException = @"BadBitmapParameters";
NSString *NSBadComparisonException = @"BadComparison";
NSString *NSBadRTFColorTableException = @"BadRTFColorTable";
NSString *NSBadRTFDirectiveException = @"BadRTFDirective";
NSString *NSBadRTFFontTableException = @"BadRTFFontTable";
NSString *NSBadRTFStyleSheetException = @"BadRTFStyleSheet";
NSString *NSBrowserIllegalDelegateException = @"BrowserIllegalDelegate";
NSString *NSColorListNotEditableException = @"ColorListNotEditable";
NSString *NSDraggingException = @"Draggin";
NSString *NSFontUnavailableException = @"FontUnavailable";
NSString *NSIllegalSelectorException = @"IllegalSelector";
NSString *NSImageCacheException = @"ImageCache";
NSString *NSNibLoadingException = @"NibLoading";
NSString *NSPasteboardCommunicationException = @"PasteboardCommunication";
NSString *NSRTFPropertyStackOverflowException = @"RTFPropertyStackOverflow";
NSString *NSTIFFException = @"TIFF";
NSString *NSTextLineTooLongException = @"TextLineTooLong";
NSString *NSTextNoSelectionException = @"TextNoSelection";
NSString *NSTextReadException = @"TextRead";
NSString *NSTextWriteException = @"TextWrite";
NSString *NSTypedStreamVersionException = @"TypedStreamVersion";
NSString *NSWordTablesReadException = @"WordTablesRead";
NSString *NSWordTablesWriteException = @"WordTablesWrite";

// NSColor Global strings
NSString *NSCalibratedWhiteColorSpace = @"NSCalibratedWhiteColorSpace";
NSString *NSCalibratedBlackColorSpace = @"NSCalibratedBlackColorSpace";
NSString *NSCalibratedRGBColorSpace = @"NSCalibratedRGBColorSpace";
NSString *NSDeviceWhiteColorSpace = @"NSDeviceWhiteColorSpace";
NSString *NSDeviceBlackColorSpace = @"NSDeviceBlackColorSpace";
NSString *NSDeviceRGBColorSpace = @"NSDeviceRGBColorSpace";
NSString *NSDeviceCMYKColorSpace = @"NSDeviceCMYKColorSpace";
NSString *NSNamedColorSpace = @"NSNamedColorSpace";
NSString *NSCustomColorSpace = @"NSCustomColorSpace";

// NSDataLink global strings
NSString *NSDataLinkFileNameExtension = @"dlf";

// NSScreen Global device dictionary key strings
NSString *NSDeviceResolution = @"Resolution";
NSString *NSDeviceColorSpaceName = @"ColorSpaceName";
NSString *NSDeviceBitsPerSample = @"BitsPerSample";
NSString *NSDeviceIsScreen = @"IsScreen";
NSString *NSDeviceIsPrinter = @"IsPrinter";
NSString *NSDeviceSize = @"Size";

// Pasteboard Type Globals 
NSString *NSStringPboardType		= @"NSStringPboardType";
NSString *NSColorPboardType			= @"NSColorPboardType";
NSString *NSFileContentsPboardType	= @"NSFileContentsPboardType";
NSString *NSFilenamesPboardType		= @"NSFilenamesPboardType";
NSString *NSFontPboardType			= @"NSFontPboardType";
NSString *NSRulerPboardType			= @"NSRulerPboardType";
NSString *NSPostScriptPboardType	= @"NSPostScriptPboardType";
NSString *NSTabularTextPboardType	= @"NSTabularTextPboardType";
NSString *NSRTFPboardType			= @"NSRTFPboardType";
NSString *NSRTFDPboardType			= @"NSRTFDPboardType";
NSString *NSTIFFPboardType			= @"NSTIFFPboardType";
NSString *NSDataLinkPboardType		= @"NSDataLinkPboardType";
NSString *NSGeneralPboardType		= @"NSGeneralPboardType";

// Pasteboard Name Globals 
NSString *NSDragPboard    			= @"NSDragPboard";
NSString *NSFindPboard    			= @"NSFindPboard";
NSString *NSFontPboard 	  			= @"NSFontPboard";
NSString *NSGeneralPboard 			= @"NSGeneralPboard";
NSString *NSRulerPboard   			= @"NSRulerPboard";


#if 0 		// BIG_NON_EMBEDDED_BUILD

NSString *NSAbortPrintingException = @"AbortPrinting";
NSString *NSPPDIncludeNotFoundException = @"PPDIncludeNotFound";
NSString *NSPPDIncludeStackOverflowException = @"PPDIncludeStackOverflow";
NSString *NSPPDIncludeStackUnderflowException = @"PPDIncludeStackUnderflow";
NSString *NSPrintOperationExistsException = @"PrintOperationExists";
NSString *NSPrintPackageException = @"PrintPackage";
NSString *NSPrintingCommunicationException = @"PrintingCommunication";

// Printing Information Dictionary Keys
NSString *NSPrintAllPages = @"PrintAllPages";
NSString *NSPrintBottomMargin = @"PrintBottomMargin";
NSString *NSPrintCopies = @"PrintCopies";
NSString *NSPrintFaxCoverSheetName = @"PrintFaxCoverSheetName";
NSString *NSPrintFaxHighResolution = @"PrintFaxHighResolution";
NSString *NSPrintFaxModem = @"PrintFaxModem";
NSString *NSPrintFaxReceiverNames = @"PrintFaxReceiverNames";
NSString *NSPrintFaxReceiverNumbers = @"PrintFaxReceiverNumbers";
NSString *NSPrintFaxReturnReceipt = @"PrintFaxReturnReceipt";
NSString *NSPrintFaxSendTime = @"PrintFaxSendTime";
NSString *NSPrintFaxTrimPageEnds = @"PrintFaxTrimPageEnds";
NSString *NSPrintFaxUseCoverSheet = @"PrintFaxUseCoverSheet";
NSString *NSPrintFirstPage = @"PrintFirstPage";
NSString *NSPrintHorizonalPagination = @"PrintHorizonalPagination";
NSString *NSPrintHorizontallyCentered = @"PrintHorizontallyCentered";
NSString *NSPrintJobFeatures = @"PrintJobFeatures";
NSString *NSPrintLastPage = @"PrintLastPage";
NSString *NSPrintManualFeed = @"PrintManualFeed";
NSString *NSPrintOrientation = @"PrintOrientation";
NSString *NSPrintPagesPerSheet = @"PrintPagesPerSheet";
NSString *NSPrintPaperFeed = @"PrintPaperFeed";
NSString *NSPrintPaperName = @"PrintPaperName";
NSString *NSPrintPaperSize = @"PrintPaperSize";
NSString *NSPrintReversePageOrder = @"PrintReversePageOrder";
NSString *NSPrintRightMargin = @"PrintRightMargin";
NSString *NSPrintSavePath = @"PrintSavePath";
NSString *NSPrintScalingFactor = @"PrintScalingFactor";
NSString *NSPrintTopMargin = @"PrintTopMargin";
NSString *NSPrintHorizontalPagination = @"PrintHorizontalPagination";
NSString *NSPrintVerticallyCentered = @"PrintVerticallyCentered";

// Print Job Disposition Values 
NSString *NSPrintCancelJob 	= @"PrintCancelJob";
NSString *NSPrintFaxJob 	= @"PrintFaxJob";
NSString *NSPrintPreviewJob = @"PrintPreviewJob";
NSString *NSPrintSaveJob 	= @"PrintSaveJob";
NSString *NSPrintSpoolJob 	= @"PrintSpoolJob";

#endif /* BIG_NON_EMBEDDED_BUILD */

NSString *NSPrintPrinter = @"PrintPrinter";
NSString *NSPrintLeftMargin = @"PrintLeftMargin";
NSString *NSPrintJobDisposition = @"PrintJobDisposition";
NSString *NSPrintVerticalPagination = @"PrintVerticalPagination";

//
// Notifications
//
#define NOTE(n_name)   NSString *NS##n_name##Notification

// NSApplication notifications
NOTE(ApplicationDidBecomeActive)		= @"ApplicationDidBecomeActive";
NOTE(ApplicationDidFinishLaunching)		= @"ApplicationDidFinishLaunching";
NOTE(ApplicationDidHide)				= @"ApplicationDidHide";
NOTE(ApplicationDidResignActive)		= @"ApplicationDidResignActive";
NOTE(ApplicationDidUnhide)				= @"ApplicationDidUnhide";
NOTE(ApplicationDidUpdate)				= @"ApplicationDidUpdate";
NOTE(ApplicationWillBecomeActive)		= @"ApplicationWillBecomeActive";
NOTE(ApplicationWillFinishLaunching)	= @"ApplicationWillFinishLaunching";
NOTE(ApplicationWillTerminate)			= @"ApplicationWillTerminate";
NOTE(ApplicationWillHide)				= @"ApplicationWillHide";
NOTE(ApplicationWillResignActive)		= @"ApplicationWillResignActive";
NOTE(ApplicationWillUnhide)				= @"ApplicationWillUnhide";
NOTE(ApplicationWillUpdate)				= @"ApplicationWillUpdate";

// NSColor notifications
NOTE(SystemColorsDidChange)				= @"SystemColorsDidChange";

// NSColorList notifications
NOTE(ColorListDidChange)				= @"ColorListDidChange";

// NSColorPanel notifications
NOTE(ColorPanelColorChanged)			= @"ColorPanelColorChanged";

// NSComboBox notifications
NOTE(ComboBoxWillPopUp)					= @"ComboBoxWillPopUp";
NOTE(ComboBoxWillDismiss)				= @"ComboBoxWillDismiss";
NOTE(ComboBoxSelectionDidChange)		= @"ComboBoxSelectionDidChange";
NOTE(ComboBoxSelectionIsChanging)		= @"ComboBoxSelectionIsChanging";

// NSControl notifications
NOTE(ControlTextDidBeginEditing)		= @"ControlTextDidBeginEditing";
NOTE(ControlTextDidEndEditing)			= @"ControlTextDidEndEditing";
NOTE(ControlTextDidChange)				= @"ControlTextDidChange";

// NSImageRep notifications
NOTE(ImageRepRegistryChanged)			= @"ImageRepRegistryChanged";

// NSOutlineView notifications
NOTE(OutlineViewSelectionDidChange)		= @"OutlineViewSelectionDidChange";
NOTE(OutlineViewSelectionIsChanging)	= @"OutlineViewSelectionIsChanging";
NOTE(OutlineViewColumnDidResize)		= @"OutlineViewColumnDidResize";
NOTE(OutlineViewColumnDidMove)			= @"OutlineViewColumnDidMove";
NOTE(OutlineViewItemWillExpand)			= @"OutlineViewItemWillExpand";
NOTE(OutlineViewItemDidExpand)			= @"OutlineViewItemDidExpand";
NOTE(OutlineViewItemWillCollapse)		= @"OutlineViewItemWillCollapse";
NOTE(OutlineViewItemDidCollapse)		= @"OutlineViewItemDidCollapse";

// NSSplitView notifications
NOTE(SplitViewDidResizeSubviews)		= @"SplitViewDidResizeSubviews";
NOTE(SplitViewWillResizeSubviews)		= @"SplitViewWillResizeSubviews";

// NSTableView notifications
NOTE(TableViewSelectionDidChange)		= @"TableViewSelectionDidChange";
NOTE(TableViewSelectionIsChanging)		= @"TableViewSelectionIsChanging";
NOTE(TableViewColumnDidResize)			= @"TableViewColumnDidResize";
NOTE(TableViewColumnDidMove)			= @"TableViewColumnDidMove";

// NSText notifications
NOTE(TextDidBeginEditing)				= @"TextDidBeginEditing";
NOTE(TextDidEndEditing)					= @"TextDidEndEditing";
NOTE(TextDidChange)						= @"TextDidChange";

// NSView notifications
NOTE(ViewFocusDidChange)				= @"ViewFocusDidChange";
NOTE(ViewFrameDidChange)				= @"ViewFrameDidChange";
NOTE(ViewBoundsDidChange)				= @"ViewBoundsDidChange";

// NSWindow notifications
NOTE(WindowDidBecomeKey)				= @"WindowDidBecomeKey";
NOTE(WindowDidBecomeMain)				= @"WindowDidBecomeMain";
NOTE(WindowDidChangeScreen)				= @"WindowDidChangeScreen";
NOTE(WindowDidDeminiaturize)			= @"WindowDidDeminiaturize";
NOTE(WindowDidExpose)					= @"WindowDidExpose";
NOTE(WindowDidMiniaturize)				= @"WindowDidMiniaturize";
NOTE(WindowDidMove)						= @"WindowDidMove";
NOTE(WindowDidResignKey)				= @"WindowDidResignKey";
NOTE(WindowDidResignMain)				= @"WindowDidResignMain";
NOTE(WindowDidResize)					= @"WindowDidResize";
NOTE(WindowDidUpdate)					= @"WindowDidUpdate";
NOTE(WindowWillClose)					= @"WindowWillClose";
NOTE(WindowWillMiniaturize)				= @"WindowWillMiniaturize";
NOTE(WindowWillMove)					= @"WindowWillMove";

// NSWorkspace notifications
NOTE(WorkspaceDidLaunchApplication)		= @"WorkspaceDidLaunchApplication";
NOTE(WorkspaceDidMount)					= @"WorkspaceDidMount";
NOTE(WorkspaceDidPerformFileOperation)	= @"WorkspaceDidPerformFileOperation";
NOTE(WorkspaceDidTerminateApplication)	= @"WorkspaceDidTerminateApplication";
NOTE(WorkspaceDidUnmount)				= @"WorkspaceDidUnmount";
NOTE(WorkspaceWillLaunchApplication)	= @"WorkspaceWillLaunchApplication";
NOTE(WorkspaceWillPowerOff)				= @"WorkspaceWillPowerOff";
NOTE(WorkspaceWillUnmount)				= @"WorkspaceWillUnmount";

// Workspace File Type Globals 
NSString *NSPlainFileType 				= @"NSPlainFileType";
NSString *NSDirectoryFileType 			= @"NSDirectoryFileType";
NSString *NSApplicationFileType 		= @"NSApplicationFileType";
NSString *NSFilesystemFileType 			= @"NSFilesystemFileType";
NSString *NSShellCommandFileType 		= @"NSShellCommandFileType";

// Workspace File Operation Globals 
NSString *NSWorkspaceCompressOperation 	 = @"NSWorkspaceCompressOperation";
NSString *NSWorkspaceCopyOperation 		 = @"NSWorkspaceCopyOperation";
NSString *NSWorkspaceDecompressOperation = @"NSWorkspaceDecompressOperation";
NSString *NSWorkspaceDecryptOperation 	 = @"NSWorkspaceDecryptOperation";
NSString *NSWorkspaceDestroyOperation 	 = @"NSWorkspaceDestroyOperation";
NSString *NSWorkspaceDuplicateOperation  = @"NSWorkspaceDuplicateOperation";
NSString *NSWorkspaceEncryptOperation 	 = @"NSWorkspaceEncryptOperation";
NSString *NSWorkspaceLinkOperation 		 = @"NSWorkspaceLinkOperation";
NSString *NSWorkspaceMoveOperation 		 = @"NSWorkspaceMoveOperation";
NSString *NSWorkspaceRecycleOperation 	 = @"NSWorkspaceRecycleOperation";

// NSStringDrawing NSString additions
NSString *NSFontAttributeName			 = @"NSFontAttributeName";    	
NSString *NSParagraphStyleAttributeName  = @"NSParagraphStyleAttributeName";	 
NSString *NSForegroundColorAttributeName = @"NSForegroundColorAttributeName"; 
NSString *NSUnderlineStyleAttributeName	 = @"NSUnderlineStyleAttributeName";
NSString *NSSuperscriptAttributeName 	 = @"NSSuperscriptAttributeName"; 	 
NSString *NSBackgroundColorAttributeName = @"NSBackgroundColorAttributeName";		
NSString *NSAttachmentAttributeName		 = @"NSAttachmentAttributeName";	 
NSString *NSLigatureAttributeName		 = @"NSLigatureAttributeName";			
NSString *NSBaselineOffsetAttributeName	 = @"NSBaselineOffsetAttributeName"; 
NSString *NSKernAttributeName 			 = @"NSKernAttributeName";        

NSString *NSPopUpButtonCellWillPopUpNotification = @"NSPopUpButtonCellWillPopUpNotification";
NSString *NSLinkAttributeName			= @"NSLink";
NSString *NSCursorAttributeName			= @"NSCursor";
