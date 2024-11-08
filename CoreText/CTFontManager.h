/*
   CTFontManager.h

   mini Core Text font manager.

   Copyright (C) 2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jan 2018

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CTFontManager
#define _mGSTEP_H_CTFontManager

#include <CoreFoundation/CoreFoundation.h>


typedef enum _CTFontManagerScope {
    kCTFontManagerScopeNone    = 0,
    kCTFontManagerScopeProcess = 1,			// implicit scope, all ignored
    kCTFontManagerScopeUser    = 2,
    kCTFontManagerScopeSession = 3
} CTFontManagerScope;


extern BOOL CTFontManagerRegisterFontsForURL( CFURLRef fontURL,
											  CTFontManagerScope scope,
											  CFErrorRef *error );

extern BOOL CTFontManagerUnregisterFontsForURL( CFURLRef fontURL,
												CTFontManagerScope scope,
												CFErrorRef *error );
#endif  /* _mGSTEP_H_CTFontManager */
