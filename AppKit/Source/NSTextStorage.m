/*
   NSTextStorage.m

   Text storage extensions to NSAttributedString

   Copyright (C) 2001 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Oct 2001

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <AppKit/AppKit.h>


extern int _ParseRTF (const char *f, char *outBuf);


@implementation NSAttributedString  (NSAttributedStringAdditions)

- (id) initWithPath:(NSString *)path documentAttributes:(NSDictionary **)dict
{
	BOOL isDir = NO;
	NSData *d;

	if ([[NSFileManager defaultManager] fileExistsAtPath: path 
										isDirectory: &isDir])
		{
		if (isDir)
			{							// should probably use FileWrapper
//			NSFileWrapper *w = [[NSFileWrapper alloc] initWithPath:path];

//			return [self initWithRTFDFileWrapper:w documentAttributes:dict];
			}
		else
			if ((d = [NSData dataWithContentsOfFile: path]))
				return [self initWithRTF:d documentAttributes:dict];
		}
	
	NSLog(@"file does not exist at specified path");
	[self release];

	return nil;
}

- (id) initWithRTF:(NSData *)data documentAttributes:(NSDictionary **)dict
{
	char *buf;
	int rc, len;

	if (!data || !(len = [data length]))
		return _NSInitError(self, @"-initWithRTF: passed a nil data object");

	buf = calloc(len, 1);

	if ((rc = _ParseRTF([data bytes], buf)) != 0)	// ecOK
		NSLog(@"Error parsing RTF (%d)", rc);

	_string = [[NSString alloc] initWithCStringNoCopy: buf
								length: strlen(buf)
								freeWhenDone: YES];
#if 0
	NSMutableDictionary *colorAttributes = [[[NSMutableDictionary alloc] init] autorelease];
	[colorAttributes setObject:[NSColor redColor] forKey:NSForegroundColorAttributeName];
	_attributes = [[NSMutableArray alloc] init];
	_locations = [[NSMutableArray alloc] init];
	[_attributes addObject:colorAttributes];
	[_locations addObject:[NSNumber numberWithUnsignedInt:0]];
#endif
	return self;
}

- (id) initWithRTFD:(NSData *)data documentAttributes:(NSDictionary **)dict
{
	return self;
}

- (id) initWithRTFDFileWrapper:(NSFileWrapper *)wrapper 
			documentAttributes:(NSDictionary **)dict
{
	NSData *d = nil; //[wrapper serializedRepresentation];

	return [self initWithRTFD:d documentAttributes:dict];
}

/* ****************************************************************************

	RTF/D create methods which can take an optional dict describing doc wide
	attributes to write out.  Current attributes are PaperSize, LeftMargin, 
	RightMargin, TopMargin, BottomMargin, and HyphenationFactor.
	First is NSSize (NSValue) others are floats (NSNumber).

** ***************************************************************************/

- (NSData *) RTFFromRange:(NSRange)range documentAttributes:(NSDictionary *)d
{
	return nil;
}

- (NSData *) RTFDFromRange:(NSRange)range documentAttributes:(NSDictionary *)d
{
	return nil;
}

- (NSFileWrapper *) RTFDFileWrapperFromRange:(NSRange)range 
						  documentAttributes:(NSDictionary *)dict
{
	return nil;
}

- (NSDictionary *) fontAttributesInRange:(NSRange)range
{
	return nil;
}

- (NSDictionary *) rulerAttributesInRange:(NSRange)range
{
	return nil;
}

- (BOOL) containsAttachments
{
	return NO;
}
					// return first char to go on the next line or NSNotFound
					// if the speciefied range does not contain a line break
- (unsigned) lineBreakBeforeIndex:(unsigned)location
					  withinRange:(NSRange)aRange
{
	return 0;
}

- (NSRange) doubleClickAtIndex:(unsigned)location
{
	return (NSRange){0,0};
}

- (unsigned) nextWordFromIndex:(unsigned)location forward:(BOOL)isForward
{
	return 0;
}

@end


@implementation NSMutableAttributedString  (NSMutableAttributedStringAdditions)

- (void) superscriptRange:(NSRange)range
{
}

- (void) subscriptRange:(NSRange)range
{
}

- (void) unscriptRange:(NSRange)range			// Undo previous superscripting
{
}

- (void) applyFontTraits:(NSFontTraitMask)traitMask range:(NSRange)range
{
}

- (void) setAlignment:(NSTextAlignment)alignment range:(NSRange)range
{
}
					// Methods (NOT automagically called) to "fix" attributes
					// after changes are made.  Range is specified in terms of 
					// the final string.
- (void) fixAttributesInRange:(NSRange)range			// master fix method
{
}

- (void) fixFontAttributeInRange:(NSRange)range
{
}

- (void) fixParagraphStyleAttributeInRange:(NSRange)range
{
}

- (void) fixAttachmentAttributeInRange:(NSRange)range
{
}

@end


@implementation NSTextStorage

- (void) addLayoutManager:(NSLayoutManager *)lym
{
	[_layoutManagers addObject: lym];
}

- (void) removeLayoutManager:(NSLayoutManager *)lym
{
	[_layoutManagers removeObject: lym];
}

- (NSArray *) layoutManagers				{ return _layoutManagers; }

- (void) edited:(unsigned)editedMask 
		 range:(NSRange)range 
		 changeInLength:(int)delta
{
	_changeDelta = delta;
	_editedRange = range;
}

- (void) processEditing						{}
- (unsigned) editedMask						{ return 0; }
- (NSRange) editedRange						{ return _editedRange; }
- (int) changeInLength						{ return _changeDelta; }

- (void) setDelegate:(id)delegate			{ _delegate = delegate; }
- (id) delegate								{ return _delegate; }

@end
