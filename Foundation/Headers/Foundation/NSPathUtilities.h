/*
   NSPathUtilities.h

   File path utilities

   Copyright (C) 1996-2018 Free Software Foundation, Inc.

   Author:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date:	May 1996

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSPathUtilities
#define _mGSTEP_H_NSPathUtilities

@class NSString;

extern NSString *NSUserName(void);
extern NSString *NSHomeDirectory(void);
extern NSString *NSHomeDirectoryForUser(NSString *login_name);

//extern NSString *NSFullUserName(void);
//extern NSString *NSTemporaryDirectory(void);

#endif /* _mGSTEP_H_NSPathUtilities */
