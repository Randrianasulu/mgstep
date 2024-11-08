/*
   NSByteOrder.h

   Byte order swap functions

   Copyright (C) 1998 Free Software Foundation, Inc.

   Author:	Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date:	1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSByteOrder
#define _mGSTEP_H_NSByteOrder

#include <CoreFoundation/CFBase.h>

typedef unsigned long		NSSwappedFloat;
typedef unsigned long long	NSSwappedDouble;

typedef enum {
    NSLittleEndian,
    NSBigEndian
} NSByteOrder;


union _dbl_conv {
	double dbl;
	NSSwappedDouble sd;
};

union _fl_conv {
	float fl;
	NSSwappedFloat sf;
};

static inline NSSwappedDouble
NSConvertHostDoubleToSwapped(double n)
{
    return ((union _dbl_conv *)&n)->sd;
}

static inline NSSwappedFloat
NSConvertHostFloatToSwapped(float n)
{
    return ((union _fl_conv *)&n)->sf;
}

static inline double
NSConvertSwappedDoubleToHost(NSSwappedDouble n)
{
    return ((union _dbl_conv *)&n)->dbl;
}

static inline float
NSConvertSwappedFloatToHost(NSSwappedFloat n)
{
    return ((union _fl_conv *)&n)->fl;
}

static inline unsigned short
NSSwapShort(unsigned short n)
{
	union swap {
		unsigned short num;
		unsigned char  byt[2];
	} dst;

	union swap *src = (union swap *)&n;

    dst.byt[0] = src->byt[1];
    dst.byt[1] = src->byt[0];

    return dst.num;
}

static inline unsigned int
NSSwapInt(unsigned int n)
{
	union swap {
		unsigned int num;
		unsigned char byt[4];
	} dst;

    union swap *src = (union swap *)&n;

    dst.byt[0] = src->byt[3];
    dst.byt[1] = src->byt[2];
    dst.byt[2] = src->byt[1];
    dst.byt[3] = src->byt[0];

    return dst.num;
}

static inline unsigned long long
NSSwapLongLong(unsigned long long n)
{
	union swap {
		unsigned long long num;
		unsigned char byt[8];
	} dst;

	union swap *src = (union swap *)&n;

    dst.byt[0] = src->byt[7];
    dst.byt[1] = src->byt[6];
    dst.byt[2] = src->byt[5];
    dst.byt[3] = src->byt[4];
    dst.byt[4] = src->byt[3];
    dst.byt[5] = src->byt[2];
    dst.byt[6] = src->byt[1];
    dst.byt[7] = src->byt[0];

    return dst.num;
}

static inline unsigned long
NSSwapLong(unsigned long n)
{
#if defined (__x86_64__)
    return NSSwapLongLong((unsigned long long)n);
#else
    return NSSwapInt((unsigned int)n);
#endif
}

static inline NSSwappedDouble
NSSwapDouble(NSSwappedDouble n)				{ return NSSwapLongLong(n); }

static inline NSSwappedFloat
NSSwapFloat(NSSwappedFloat n)				{ return NSSwapInt(n); }


/* ****************************************************************************

	BIG ENDIAN

** ***************************************************************************/

#ifdef WORDS_BIGENDIAN

static inline NSByteOrder NSHostByteOrder(void)		{ return NSBigEndian; }


static inline double
NSSwapBigDoubleToHost(NSSwappedDouble n)
{
    return NSConvertSwappedDoubleToHost(n);
}

static inline float
NSSwapBigFloatToHost(NSSwappedFloat n)
{
    return NSConvertSwappedFloatToHost(n);
}

static inline unsigned int
NSSwapBigIntToHost(unsigned int n)					{ return n; }

static inline unsigned long long
NSSwapBigLongLongToHost(unsigned long long n)		{ return n; }

static inline unsigned long
NSSwapBigLongToHost(unsigned long n)				{ return n; }

static inline unsigned short
NSSwapBigShortToHost(unsigned short n)				{ return n; }

static inline NSSwappedDouble
NSSwapHostDoubleToBig(double n)						// Host to Big endian
{
    return NSConvertHostDoubleToSwapped(n);
}

static inline NSSwappedFloat
NSSwapHostFloatToBig(float n)
{
    return NSConvertHostFloatToSwapped(n);
}

static inline unsigned int
NSSwapHostIntToBig(unsigned int n)					{ return n; }

static inline unsigned long long
NSSwapHostLongLongToBig(unsigned long long n)		{ return n; }

static inline unsigned long
NSSwapHostLongToBig(unsigned long n)				{ return n; }

static inline unsigned short
NSSwapHostShortToBig(unsigned short n)				{ return n; }

static inline double
NSSwapLittleDoubleToHost(NSSwappedDouble n)			// Little endian to Host
{
    return NSConvertSwappedDoubleToHost( NSSwapDouble(n) );
}

static inline float
NSSwapLittleFloatToHost(NSSwappedFloat n)
{
    return NSConvertSwappedFloatToHost( NSSwapFloat(n) );
}

static inline unsigned int
NSSwapLittleIntToHost(unsigned int n)
{
    return NSSwapInt(n);
}

static inline unsigned long long
NSSwapLittleLongLongToHost(unsigned long long n)
{
    return NSSwapLongLong(n);
}

static inline unsigned long
NSSwapLittleLongToHost(unsigned long n)
{
    return NSSwapLong(n);
}

static inline unsigned short
NSSwapLittleShortToHost(unsigned short n)
{
    return NSSwapShort(n);
}

static inline NSSwappedDouble
NSSwapHostDoubleToLittle(double n)					// Host to Little endian
{
    return NSSwapDouble( NSConvertHostDoubleToSwapped(n) );
}

static inline NSSwappedFloat
NSSwapHostFloatToLittle(float n)
{
    return NSSwapFloat( NSConvertHostFloatToSwapped(n) );
}

static inline unsigned int
NSSwapHostIntToLittle(unsigned int n)
{
    return NSSwapInt(n);
}

static inline unsigned long long
NSSwapHostLongLongToLittle(unsigned long long n)
{
    return NSSwapLongLong(n);
}

static inline unsigned long
NSSwapHostLongToLittle(unsigned long n)
{
    return NSSwapLong(n);
}

static inline unsigned short
NSSwapHostShortToLittle(unsigned short n)				
{
	return NSSwapShort(n);
}

#else

/* ****************************************************************************

	LITTLE ENDIAN

** ***************************************************************************/

static inline NSByteOrder NSHostByteOrder(void)		{ return NSLittleEndian; }

static inline double
NSSwapBigDoubleToHost(NSSwappedDouble n)			//	Big endian to host
{
    return NSConvertSwappedDoubleToHost(NSSwapDouble(n));
}

static inline float
NSSwapBigFloatToHost(NSSwappedFloat n)
{
    return NSConvertSwappedFloatToHost(NSSwapFloat(n));
}

static inline unsigned int
NSSwapBigIntToHost(unsigned int n)				{ return NSSwapInt(n); }

static inline unsigned long long
NSSwapBigLongLongToHost(unsigned long long n)
{
    return NSSwapLongLong(n);
}

static inline unsigned long
NSSwapBigLongToHost(unsigned long n)			{ return NSSwapLong(n); }

static inline unsigned short
NSSwapBigShortToHost(unsigned short n)			{ return NSSwapShort(n);}

static inline NSSwappedDouble
NSSwapHostDoubleToBig(double n)						// Host to Big endian
{
    return NSSwapDouble( NSConvertHostDoubleToSwapped(n) );
}

static inline NSSwappedFloat
NSSwapHostFloatToBig(float n)
{
    return NSSwapFloat( NSConvertHostFloatToSwapped(n) );
}

static inline unsigned int
NSSwapHostIntToBig(unsigned int n)				{ return NSSwapInt(n); }

static inline unsigned long long
NSSwapHostLongLongToBig(unsigned long long n)		
{ 
	return NSSwapLongLong(n);
}

static inline unsigned long
NSSwapHostLongToBig(unsigned long n)			{ return NSSwapLong(n); }

static inline unsigned short
NSSwapHostShortToBig(unsigned short n)			{ return NSSwapShort(n);}

static inline double
NSSwapLittleDoubleToHost(NSSwappedDouble n)			// Little endian to Host
{
    return NSConvertSwappedDoubleToHost(n);
}

static inline float
NSSwapLittleFloatToHost(NSSwappedFloat n)
{
    return NSConvertSwappedFloatToHost(n);
}

static inline unsigned int
NSSwapLittleIntToHost(unsigned int n)				{ return n; }

static inline unsigned long long
NSSwapLittleLongLongToHost(unsigned long long n)	{ return n; }

static inline unsigned long
NSSwapLittleLongToHost(unsigned long n)				{ return n; }

static inline unsigned short
NSSwapLittleShortToHost(unsigned short n)			{ return n; }

static inline NSSwappedDouble
NSSwapHostDoubleToLittle(double n)					// Host to Little endian
{
    return NSConvertHostDoubleToSwapped(n);
}

static inline NSSwappedFloat
NSSwapHostFloatToLittle(float n)
{
    return NSConvertHostFloatToSwapped(n);
}

static inline unsigned int
NSSwapHostIntToLittle(unsigned int n)				{ return n; }

static inline unsigned long long
NSSwapHostLongLongToLittle(unsigned long long n)	{ return n; }

static inline unsigned long
NSSwapHostLongToLittle(unsigned long n)				{ return n; }

static inline unsigned short
NSSwapHostShortToLittle(unsigned short n)			{ return n; }

#endif

#endif /* _mGSTEP_H_NSByteOrder */
