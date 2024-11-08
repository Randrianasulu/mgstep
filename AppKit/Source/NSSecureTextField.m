/*
   NSSecureTextField.m

   Secure Text field control class for data entry

   Copyright (C) 1996-2016 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Dec 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>
#include <Foundation/NSException.h>

#include <AppKit/NSSecureTextField.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSFont.h>


/* ****************************************************************************

		NSText (_SecureText)

** ***************************************************************************/

@interface NSText  (_SecureText)

- (void) _setSecure:(BOOL)flag;

@end

@implementation NSText  (_SecureText)

- (void) _setSecure:(BOOL)flag					{ _tx.secure = flag; }

@end

/* ****************************************************************************

		NSString  (_SecureString)

** ***************************************************************************/

@implementation _NSCString  (_SecureString)

- (void) _erase
{
	if (_cString)
		memset(_cString, '\0', _count);
}

@end

@implementation _NSUString  (_SecureString)

- (void) _erase
{
	if (_cString)
		memset(_cString, '\0', _count);
	if (_uniChars)
		memset(_uniChars, '\0', 2 * _count);
}

@end

@implementation NSString  (_SecureString)

- (void) _erase					{ }

@end

/* ****************************************************************************

		NSSecureTextFieldCell

** ***************************************************************************/

@implementation NSSecureTextFieldCell

- (id) initTextCell:(NSString *)aString
{
	_c.secure = YES;

	return [super initTextCell:aString];
}

- (NSText*) setUpFieldEditorAttributes:(NSText*)textObject
{
	[textObject _setSecure:YES];

	return [super setUpFieldEditorAttributes:textObject];
}

- (void) setStringValue:(NSString*)aString
{
	if (_contents && _contents != aString)
		[_contents _erase];

	[super setStringValue: aString];
}

- (void) dealloc
{
	[_contents _erase];
	[super dealloc];
}

@end /* NSSecureTextFieldCell */

/* ****************************************************************************

		NSSecureTextField

** ***************************************************************************/

@implementation NSSecureTextField

+ (Class) cellClass				{ return [NSSecureTextFieldCell class]; }

+ (void) setCellClass:(Class)class
{ 
	[NSException raise:NSInvalidArgumentException
				 format:@"NSSecureTextField must use NSSecureTextFieldCell"];
}

@end /* NSSecureTextField */
