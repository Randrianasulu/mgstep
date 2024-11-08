/* 
   Test Class for NSBundle.

   Copyright (C) 1993,1994,1995 Free Software Foundation, Inc.

   Author:  Adam Fedor <fedor@boulder.colorado.edu>
   Date:	Jul 1995

   This file is part of the mGSTEP Base Library.
*/

#include <stdio.h>
#include "LoadMe.h"
#include <Foundation/NSString.h>

@implementation LoadMe 

- init
{
    [super init];
    var = 10;
    return self;
}

- afterLoad
{
    printf("%s's instance variable is %i\n", [[self description] cString],var);
    return self;
}

@end

@implementation SecondClass 

- init
{
    [super init];
    h = 25;
    return self;
}

- printName
{
    printf("Hi my name is %s\n", [[self description] cString]);
    return self;
}

@end

@implementation NSObject (MyCategory)

- printMyName
{
 printf("Class %s had MyCategory added to it\n", [[self description] cString]);
	return self;
}

@end
