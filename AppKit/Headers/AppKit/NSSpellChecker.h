/*
   NSSpellChecker.h

   Interface to spell-checking service

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
   Author:  Simon Frankau <sgf@frankau.demon.co.uk>
   Date:    1996

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSSpellChecker
#define _mGSTEP_H_NSSpellChecker

#include <Foundation/NSObject.h>
#include <Foundation/NSRange.h>

@class NSString;
@class NSArray;
@class NSView;
@class NSPanel;


@interface NSSpellChecker : NSObject
{
    id _guessBrowser;
}

+ (NSSpellChecker *) sharedSpellChecker;
+ (BOOL) sharedSpellCheckerExists;

- (NSView *) accessoryView;								// Manage Spell Panel
- (void) setAccessoryView:(NSView *)aView;
- (NSPanel *) spellingPanel;
														// Checking Spelling 
- (NSInteger) countWordsInString:(NSString *)aString language:(NSString *)lang;
- (NSRange) checkSpellingOfString:(NSString *)stringToCheck
					   startingAt:(int)startingOffset;
- (NSRange) checkSpellingOfString:(NSString *)stringToCheck
					   startingAt:(int)startingOffset
					   language:(NSString *)language
					   wrap:(BOOL)wrapFlag
					   inSpellDocumentWithTag:(int)tag
					   wordCount:(int *)wordCount;

- (NSString *) language;								// Language 
- (BOOL) setLanguage:(NSString *)aLanguage;

+ (int) uniqueSpellDocumentTag;							// Manage Spell Check
- (void) closeSpellDocumentWithTag:(int)tag;
- (void) ignoreWord:(NSString *)wordToIgnore
		 inSpellDocumentWithTag:(int)tag;
- (NSArray *) ignoredWordsInSpellDocumentWithTag:(int)tag;
- (void) setIgnoredWords:(NSArray *)someWords
		 inSpellDocumentWithTag:(int)tag;
- (void) setWordFieldStringValue:(NSString *)aString;
- (void) updateSpellingPanelWithMisspelledWord:(NSString *)word;

@end


@protocol NSChangeSpelling			// implemented by object that supports spell
									// correction, msg is sent down responder
- (void) changeSpelling:(id)sender;	// chain, reciever should ask sender for its
									// selectedCell's stringValue (correction)
@end


@protocol NSIgnoreMisspelledWords

- (void) ignoreSpelling:(id)sender;

@end

#endif /* _mGSTEP_H_NSSpellChecker */
