/*
	DocumentReadWrite.m

	Copyright (c) 1995-1996, NeXT Software, Inc.
	All rights reserved.
	Author: Ali Ozer

	You may freely copy, distribute and reuse the code in this example.
	NeXT disclaims any warranty of any kind, expressed or implied,
	as to its fitness for any particular use.

	File I/O code, define a few convenience methods on NSAttributedString.
*/

#import <AppKit/AppKit.h>
#import "Document.h"
#import "Preferences.h"
#import <sys/stat.h>

#import <string.h>									// For memcmp()...


static float
defaultPadding(void) 
{
static float padding = -1;

    if (padding < 0.0) 
		{
//        NSTextContainer *container = [[NSTextContainer alloc] init];
//        padding = [container lineFragmentPadding];
		padding = 1;
//        [container release];
		}

    return padding;
}


@interface NSAttributedString (EditExtensions)

- (id) initWithRTF:(NSData *)data 
		  viewSize:(NSSize *)size 
 		  hyphenationFactor:(float *)factor;
- (id) initWithRTFDFile:(NSString *)path 
			   viewSize:(NSSize *)size 
			   hyphenationFactor:(float *)factor;
- (BOOL) writeRTFDToFile:(NSString *)path 
		 updateFilenames:(BOOL)flag 
		 viewSize:(NSSize)size 
		 hyphenationFactor:(float)factor;
- (NSData *) RTFFromRange:(NSRange)range 
				 viewSize:(NSSize)size 
				 hyphenationFactor:(float)factor;
@end

@implementation NSAttributedString (EditExtensions)

- (id) initWithRTF:(NSData *)data 
		  viewSize:(NSSize *)size 
		  hyphenationFactor:(float *)factor 
{
	NSDictionary *docAttrs;

    if (self = [self initWithRTF:data documentAttributes:&docAttrs]) 
		{
		NSValue *value;
		NSNumber *number;

        if (size && (value = [docAttrs objectForKey:@"PaperSize"])) 
			{								// The size has the 12 pt padding
            *size = [value sizeValue];		// from old Edit; compensate for 
											// that. Note that we should really
											// be getting the margins here!
            if (size->width > 0 && size->height > 0) 
				size->width = size->width - (6.0 * 2) + (defaultPadding() * 2);
			}
        if (factor && (number = [docAttrs objectForKey:@"HyphenationFactor"])) 
			*factor = [number floatValue];
		}

    return self; 
}

- (id) initWithRTFDFile:(NSString *)path 
			   viewSize:(NSSize *)size 
			   hyphenationFactor:(float *)factor 
{
	NSDictionary *docAttrs;

    if (self = [self initWithPath:path documentAttributes:&docAttrs]) 
		{
        NSValue *value;
		NSNumber *number;

        if (size && (value = [docAttrs objectForKey:@"PaperSize"])) 
			{								// The size has the 12 pt padding
            *size = [value sizeValue];		// from old Edit; compensate for 
											// that. Note that we should really
											// be getting the margins here!
            if (size->width > 0 && size->height > 0) 
				size->width = size->width - (6.0 * 2) + (defaultPadding() * 2);
			}
        if (factor && (number = [docAttrs objectForKey:@"HyphenationFactor"])) 
			*factor = [number floatValue];
		}

    return self;
}

- (BOOL) writeRTFDToFile:(NSString *)path 
		 updateFilenames:(BOOL)flag 
		 viewSize:(NSSize)size 
		 hyphenationFactor:(float)factor 
{
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithSize:NSMakeSize(size.width + (6.0 * 2) - (defaultPadding() * 2), size.height)], @"PaperSize", [NSNumber numberWithFloat:factor], @"HyphenationFactor", nil];
/*
NSFileWrapper *wrapper = [self RTFDFileWrapperFromRange:NSMakeRange(0, [self length]) documentAttributes:dict];

    if (wrapper) 
        return [wrapper writeToFile:path atomically:YES updateFilenames:flag];
	else 
*/
        return NO;
}

- (NSData *) RTFFromRange:(NSRange)range 
				 viewSize:(NSSize)size 
				 hyphenationFactor:(float)factor 
{
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithSize:NSMakeSize(size.width + (6.0 * 2) - (defaultPadding() * 2), size.height)], @"PaperSize", [NSNumber numberWithFloat:factor], @"HyphenationFactor", nil];

//    return [self RTFFromRange:range documentAttributes:dict];
    return nil;
}

@end /* NSAttributedString (EditExtensions) */


@implementation Document (ReadWrite)

/* ****************************************************************************

	Loads from the specified path, sets encoding and textStorage.
	Note: if the file looks like RTF or RTFD, this method will open
	the file in rich text mode, regardless of the encoding setting.

** ***************************************************************************/

- (BOOL) loadFromPath:(NSString *)fileName encoding:(int)encoding
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSData *fileContentsAsData = nil;
	NSDictionary *attrs;
	BOOL isDirectory;
	BOOL success = NO;

	if (!(attrs = [fm fileAttributesAtPath:fileName traverseLink:YES]))
		return NO;

    if ((isDirectory = [[attrs fileType] isEqualToString:NSFileTypeDirectory]))
		{									// If directory, should be .rtfd
        if (![@"rtfd" isEqual:[fileName pathExtension]])
			return NO;
        encoding = RichTextWithGraphicsStringEncoding;
		}
	else
		{
		NSNumber *fsize;
		NSUInteger sz;

		if ((fsize = [attrs objectForKey:NSFileSize]))
			if ((sz = [fsize unsignedLongLongValue] / 1000) > 1000)
				{
				NSString *a = [[NSProcessInfo processInfo] processName];

				if (NSRunAlertPanel(a, @"File: %@ is %1.2f MB", @"Continue",
									 @"Stop", NULL, [fileName lastPathComponent],
									 sz / 1000.0) != NSAlertDefaultReturn)
					return NO;
				}

		if ([@"rtf" isEqual:[fileName pathExtension]])
        	encoding = RichTextStringEncoding;			// file looks like RTF
		else											// ignore encoding
			if (encoding == UnknownStringEncoding) 
				{
        		if (fileContentsAsData = [[NSData alloc] initWithContentsOfFile:fileName])
					{
		unsigned len = [fileContentsAsData length];
		const unsigned char *bytes = [fileContentsAsData bytes];
		static const unsigned char bigUnicodeHeader[] = {0xff, 0xfe};
		static const unsigned char littleUnicodeHeader[] = {0xfe, 0xff};
		static const unsigned char rtfHeader[] = {'{', '\\', 'r', 't', 'f'};

            					// Unicode plain text files start with the 
								// Unicode BOM char; check for that first...
					if (((len & 1) == 0) && (len >= 2)
							&& (!memcmp(bytes, bigUnicodeHeader, 2)
							|| !memcmp(bytes, littleUnicodeHeader, 2)))
						{
						encoding = NSUnicodeStringEncoding;
						}
					else
						if (((len >= 6) && !memcmp(bytes, rtfHeader, 5)))
							{
							encoding = RichTextStringEncoding;
							}
					if (encoding == UnknownStringEncoding) 
						{
//						encoding = [[Preferences objectForKey: PlainTextEncoding] intValue];
						if (encoding == UnknownStringEncoding)
							encoding = [NSString defaultCStringEncoding];
						}
					}
				else
					{
					return NO;			// File couldn't be opened, I guess
					}
				}
		}

    if (encoding == RichTextWithGraphicsStringEncoding)
		{
		NSSize size = NSZeroSize;
		float factor = 0.0;
//		NSTextStorage *newTextStorage = [[NSTextStorage alloc]
//						initWithRTFDFile:fileName viewSize:&size 
//						hyphenationFactor:&factor];

//        if (newTextStorage)
			{
            [self setRichText:YES];
            if (size.width > 0 && size.height > 0 && ![self hasMultiplePages]) 
				[self setViewSize:size];
//			[self setHyphenationFactor:factor];
//            [[self layoutManager] replaceTextStorage:newTextStorage];
//            [textStorage release];
//            textStorage = newTextStorage;
            success = YES;
			}
		}
	else
		{
        if (!fileContentsAsData)
			fileContentsAsData = [[NSData alloc]initWithContentsOfFile:fileName];
        if (fileContentsAsData)
			{
            if (encoding == RichTextStringEncoding)
				{
                NSSize size = NSZeroSize;
				float factor = 0.0;
//				NSTextStorage *newTextStorage = [[NSTextStorage alloc] 
//									initWithRTF:fileContentsAsData 
//									viewSize:&size 
//									hyphenationFactor:&factor];
				NSAttributedString *a;

				a = [[NSAttributedString alloc] initWithRTF:fileContentsAsData
												documentAttributes:NULL];

//              if (newTextStorage) 
				if (a)
					{
                    [self setRichText:YES];
                    if (size.width > 0 && size.height > 0 && ![self hasMultiplePages])
						[self setViewSize:size];

///					[[self firstTextView] _replaceTextStorage:a];
					[[self firstTextView] setString:[a string]];	// FIX ME

//		    		[self setHyphenationFactor:factor];
//					[[self layoutManager] replaceTextStorage:newTextStorage];
//					[textStorage release];
//					textStorage = newTextStorage;
                    success = YES;
                	}
				}
			else
				{
                NSString *fileContents;
																	// FIX ME
				fileContents = [NSString stringWithContentsOfFile:fileName];

//				fileContents =[[NSString alloc] initWithData:fileContentsAsData 
//												encoding:encoding];
                if (fileContents)
					{
//					[textStorage beginEditing];
//					[[textStorage mutableString] setString:fileContents];

					[[self firstTextView] setString:fileContents];	// FIX ME

//					[self setRichText:NO];
//					[textStorage endEditing];
//					[fileContents release];

                    encodingIfPlainText = encoding;
                    success = YES;
		}	}	}	}

    [fileContentsAsData release];

    return success;
}

- (BOOL) saveToPath:(NSString *)fileName
		   encoding:(int)encoding
		   updateFilenames:(BOOL)updateFileNamesFlag
{
	BOOL success = NO;
	NSFileManager *fm = [NSFileManager defaultManager];
	NSDictionary *attributes = [fm fileAttributesAtPath:fileName traverseLink:YES];
	NSString *actualFileNameToSave = [fileName stringByResolvingSymlinksInPath];

	encoding = NSISOLatin1StringEncoding;	// FIX ME

    if (attributes)
		{	/* If not nil, the file exists... */
        NSString *backupFileName = [actualFileNameToSave
										stringByAppendingString:@"~"];
								// If there was a backup file name, delete it 
        if ([fm fileExistsAtPath:backupFileName])
			{
            (void)[fm removeFileAtPath:backupFileName handler:nil];
        	}
        // If the user wishes to keep backups, simply remove the old file aside
//		if (![[Preferences objectForKey:DeleteBackup] boolValue]) 
			{
//			(void)[fm movePath:actualFileNameToSave 
//							   toPath:backupFileName 
//							   handler:nil];
			}
		}

    switch (encoding)
		{
        case RichTextWithGraphicsStringEncoding:
			{
//          success = [textStorage writeRTFDToFile:actualFileNameToSave 
//								   updateFilenames:updateFileNamesFlag 
//								   viewSize:[self viewSize] 
//								   hyphenationFactor:[self hyphenationFactor]];
            break;
			}
        case RichTextStringEncoding:
			{
//            NSData *data = [textStorage RTFFromRange:NSMakeRange(0, 
//														[textStorage length]) 
//								viewSize:[self viewSize] 
//								hyphenationFactor:[self hyphenationFactor]];
//			success = data && [data writeToFile:actualFileNameToSave 
//									atomically:YES];
            break;
			}
        default:
			{
//          NSData *data = [[textStorage string] dataUsingEncoding:encoding];
			NSTextView *textView = [self firstTextView];
            NSData *data = [[textView string] dataUsingEncoding:encoding];

NSLog(@"Save to '%@'", actualFileNameToSave);

	    	success = data && [data writeToFile:actualFileNameToSave 
									atomically:YES];
            break;
			}
    }
    							// Apply the original permissions to the new
								// file. Also make it writable if needed.
    if (success && attributes)
		{
		id permissions = [attributes objectForKey:NSFilePosixPermissions];

        if (permissions)
			{
//          if ([[Preferences objectForKey:SaveFilesWritable] boolValue]) 
				{
                permissions = [NSNumber numberWithUnsignedLong:([permissions unsignedLongValue] | 0200)];
            	}
	    	[fm changeFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:permissions, NSFilePosixPermissions, nil] atPath:actualFileNameToSave];
        }
    }

    return success;
}

@end /* Document (ReadWrite) */
