/*
	Test the operation of the NSScanner class.
	All is well if this program produces no output.

	By default, double values differing by one least-significant-bit or
	less are assumed to be equal.  This behaviour can be changed with
	the `-e' flag.  For example, if you want only doubles that are exactly
	equal to be treated as equal, use `-e0'.

	Eric Norum <eric@skatter.usask.ca>
*/

#include <Foundation/NSScanner.h>
#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSString.h>

#include <limits.h>
#include <float.h>
#include <math.h>
#include <stdio.h>

/*
 * Doubles differing by this many least-significant-bits
 * or less are assumed to be `equal'.
 */
int DoubleCompareEqual = 1;

/*
 * Check that scan completely consumed string
 */
void
testFullScan (const char *message, NSString *string, NSScanner *scanner)
{
    unsigned int scanLocation;

    scanLocation = [scanner scanLocation];
    if (scanLocation != [string length])
	printf ("%s of `%s' moves scan location to %u.\n", message, 
						[string cString], scanLocation);
}

//
// scanInt:
//
void
testScanIntGood (int i)						// Test a valid scanInt operation
{
NSString *string;
NSScanner *scanner;
int value;

    string = [NSString stringWithFormat:@"%d", i];
    scanner = [NSScanner scannerWithString:string];
    if (![scanner scanInt:&value])
	printf ("scanInt of `%s' failed.\n", [string cString]);
    else if (value != i)
	printf ("scanInt of `%s' returned value %d.\n", [string cString], value);
    testFullScan ("scanInt", string, scanner);
}

/*
 * Verify that scanInt handles overflow
 */
void
testScanIntOverflow (double d)
{
    NSString *string;
    NSScanner *scanner;
    int value;

    string = [NSString stringWithFormat:@"%.0f", d];
    scanner = [NSScanner scannerWithString:string];
    if (![scanner scanInt:&value])
	printf ("scanInt of `%s' failed.\n", [string cString]);
    else if (value != ((d < 0) ? INT_MIN : INT_MAX))
	printf ("scanInt of `%s' didn't overflow, returned %d.\n", [string cString], value);
    testFullScan ("scanInt", string, scanner);
}

/*
 * Test scanInt operation
 */
void
testScanInt (void)
{
NSString *string;
NSScanner *scanner;
int i = INT_MAX-20;
int value;
unsigned int scanLocation;

    /*
     * Check values within range
     */
    for (;;) {
	testScanIntGood (i);
	if (i == INT_MAX)
		break;
	i++;
    }
    i = INT_MIN+20;
    for (;;) {
	testScanIntGood (i);
	if (i == INT_MIN)
		break;
	i--;
    }
    for (i = -20 ; i <= 20 ; i++)
	testScanIntGood (i);


    /*
     * Check overflow values
     */
    for (i = 1 ; i <= 20 ; i++) {
	testScanIntOverflow ((double)INT_MAX + i);
	testScanIntOverflow ((double)INT_MIN - i);
	testScanIntOverflow ((2.0 * (double)INT_MAX) + i);
	testScanIntOverflow ((2.0 * (double)INT_MIN) - i);
	testScanIntOverflow ((10.0 * (double)INT_MAX) + i);
	testScanIntOverflow ((10.0 * (double)INT_MIN) - i);
    }

    /*
     * Check that non-digits terminate the scan
     */
    string = @"1234FOO";
    scanner = [NSScanner scannerWithString:string];
    if (![scanner scanInt:&value])
	printf ("scanInt of `%s' failed.\n", [string cString]);
    scanLocation = [scanner scanLocation];
    if (scanLocation != 4)
	printf ("scanInt of `%s' moves scan location to %u.\n", [string cString], scanLocation);

    /*
     * Check that non-digits don't move the scan location
     */
    string = @"junk";
    scanner = [NSScanner scannerWithString:string];
    if ([scanner scanInt:&value])
	printf ("scanInt of `%s' succeeded with value %d.\n", [string cString], value);
    scanLocation = [scanner scanLocation];
    if (scanLocation != 0)
	printf ("scanInt of `%s' moves scan location to %u.\n", [string cString], scanLocation);

    /*
     * Check that non-digits don't consume characters to be skipped
     */
    string = @"    junk";
    scanner = [NSScanner scannerWithString:string];
    if ([scanner scanInt:&value])
	printf ("scanInt of `%s' succeeded with value %d.\n", [string cString], value);
    scanLocation = [scanner scanLocation];
    if (scanLocation != 0)
	printf ("scanInt of `%s' moves scan location to %u.\n", [string cString], scanLocation);
}

//
// scanLongLong:
//

#if defined (LONG_LONG_MAX)
/*
 * Quick hacks to convert a long long types.
 */
static char *
unsignedlonglongToString (unsigned long long n)
{
    static char cbuf[400];	/* Should be big enough!  */
    char *cp = &cbuf[400];

    *--cp = '\0';
    do {
	*--cp = (n % 10) + '0';
	n /= 10;
    } while (n);
    return cp;
}

static char *
longlongToString (long long i)
{
    unsigned long long n;
    char *cp;

    if (i < 0)
	n = -i;
    else
	n = i;
    cp = unsignedlonglongToString (n);
    if (i < 0)
	*--cp = '-';
    return cp;
}

/*
 * Test a valid scanLongLong operation
 */
void
testScanLongLongGood (long long i)
{
    NSString *string;
    NSScanner *scanner;
    long long value;

    string = [NSString stringWithFormat:@"%s", longlongToString (i)];
    scanner = [NSScanner scannerWithString:string];
    if (![scanner scanLongLong:&value])
	printf ("scanLongLong of `%s' failed.\n", [string cString]);
    else if (value != i)
	printf ("scanLongLong of `%s' returned value %s.\n", [string cString],
						longlongToString (value));
    testFullScan ("scanLongLong", string, scanner);
}

/*
 * Verify that scanLongLong handles overflow
 */
void
testScanLongLongOverflow (const char *sign, unsigned long long check, long long expect)
{
    NSString *string;
    NSScanner *scanner;
    long long value;

    string = [NSString stringWithFormat:@"%s%s", sign, unsignedlonglongToString (check)];
    scanner = [NSScanner scannerWithString:string];
    if (![scanner scanLongLong:&value])
	printf ("scanLongLong of `%s' failed.\n", [string cString]);
    else if (value != expect)
	printf ("scanLongLong of `%s' didn't overflow, returned %s.\n", [string cString],
						longlongToString (value));
    testFullScan ("scanLongLong", string, scanner);
}

/*
 * Test scanLongLong operation
 */
void
testScanLongLong (void)
{
    NSString *string;
    NSScanner *scanner;
    long long i;
    long long value;
    unsigned int scanLocation;

    /*
     * Check values within range
     */
    i = LONG_LONG_MAX-20;
    for (;;) {
	testScanLongLongGood (i);
	if (i == LONG_LONG_MAX)
		break;
	i++;
    }
    i = LONG_LONG_MIN+20;
    for (;;) {
	testScanLongLongGood (i);
	if (i == LONG_LONG_MIN)
		break;
	i--;
    }
    for (i = -20 ; i <= 20 ; i++)
	testScanLongLongGood (i);


    /*
     * Check overflow values
     */
    for (i = 1 ; i <= 20 ; i++) {
	testScanLongLongOverflow ("", LONG_LONG_MAX + i, LONG_LONG_MAX);
	testScanLongLongOverflow ("", ULONG_LONG_MAX - i + 1, LONG_LONG_MAX);
	if (i > 1)
	    testScanLongLongOverflow ("-", LONG_LONG_MAX + i, LONG_LONG_MIN);
    }

    /*
     * Check that non-digits terminate the scan
     */
    string = @"1234FOO";
    scanner = [NSScanner scannerWithString:string];
    if (![scanner scanLongLong:&value])
	printf ("scanLongLong of `%s' failed.\n", [string cString]);
    scanLocation = [scanner scanLocation];
    if (scanLocation != 4)
	printf ("scanLongLong of `%s' moves scan location to %u.\n", [string cString], scanLocation);

    /*
     * Check that non-digits don't move the scan location
     */
    string = @"junk";
    scanner = [NSScanner scannerWithString:string];
    if ([scanner scanLongLong:&value])
	printf ("scanLongLong of `%s' succeeded with value %s\n", [string cString],
						longlongToString (value));
    scanLocation = [scanner scanLocation];
    if (scanLocation != 0)
	printf ("scanLongLong of `%s' moves scan location to %u.\n", [string cString], scanLocation);
}
#endif /* defined (LONG_LONG_MAX) */

//
// scanDouble:
//

/*
 * Compare two doubles for `almost' equality
 */
static double
areDoublesEqual (double d1, double d2)
{
    if (d1 == d2)
	return 0;
    if (d1 == 0)
	return (fabs (d2) /DBL_EPSILON);
    if (d2 == 0)
	return (fabs (d1) /DBL_EPSILON);
    d1 = fabs(d1);
    d2 = fabs(d2);
    if (d1 > d2)
	return fabs (1.0 - (d1 / d2)) / DBL_EPSILON;
    else
	return fabs (1.0 - (d2 / d1)) / DBL_EPSILON;
}
	
/*
 * Test a scanDouble operation
 */
void
testScanDoubleGood (NSString *string, double expect)
{
    NSScanner *scanner;
    double value, error;

    scanner = [NSScanner scannerWithString:string];
    if (![scanner scanDouble:&value])
	printf ("scanDouble of `%s' failed.\n", [string cString]);
    else if ((error = areDoublesEqual (value, expect)) > DoubleCompareEqual)
	printf ("scanDouble of `%s' returned value %.*e (%g LSB different).\n",
				[string cString], DBL_DIG + 2, value, error);
    testFullScan ("scanDouble", string, scanner);
}

static void
testScanDoubleOneDigit (NSString *format, int digit, double expect)
{
    NSString *string = [NSString stringWithFormat:format, digit];
    testScanDoubleGood (string, expect);
}

static void
testScanDoubleShort (NSString *string, double expect, unsigned int length)
{
    NSScanner *scanner;
    double value, error;
    unsigned int scanLocation;

    scanner = [NSScanner scannerWithString:string];
    if (![scanner scanDouble:&value])
	printf ("scanDouble of `%s' failed.\n", [string cString]);
    else if ((error = areDoublesEqual (value, expect)) > DoubleCompareEqual)
	printf ("scanDouble of `%s' returned value %.*e (%g LSB different).\n",
				[string cString], DBL_DIG + 2, value, error);
    scanLocation = [scanner scanLocation];
    if (scanLocation != length)
	printf ("scanDouble of `%s' moves scan location to %u.\n", [string cString], scanLocation);
}

void
testScanDoubleBad (NSString *string)
{
    NSScanner *scanner = [NSScanner scannerWithString:string];
    double value;
    unsigned int scanLocation;

    if ([scanner scanDouble:&value])
		printf ("scanDouble of `%s' succeeded with value %g\n", [string cString], value);
    scanLocation = [scanner scanLocation];
    if (scanLocation != 0)
		printf ("scanDouble of `%s' moves scan location to %u.\n", [string cString], scanLocation);
}

/*
 * Test scanDouble operations
 */
void
testScanDouble (void)
{
    int i;

    /*
     * Check all digits before and after decimal point
     */
    for (i = 0 ; i < 10 ; i++) {
	testScanDoubleOneDigit (@"%d", i, i);
	testScanDoubleOneDigit (@"%d.", i, i);
	testScanDoubleOneDigit (@"%d.0", i, i);
	testScanDoubleOneDigit (@"0%d.0", i, i);
	testScanDoubleOneDigit (@".%d", i, i / 10.0);
	testScanDoubleOneDigit (@"0.%d", i, i / 10.0);

	testScanDoubleOneDigit (@"-%d", i, -i);
	testScanDoubleOneDigit (@"-%d.", i, -i);
	testScanDoubleOneDigit (@"-%d.0", i, -i);
	testScanDoubleOneDigit (@"-0%d.0", i, -i);
	testScanDoubleOneDigit (@"-.%d", i, -i / 10.0);
	testScanDoubleOneDigit (@"-0.%d", i, -i / 10.0);
    }

    /*
     * Check exponents
     */
    testScanDoubleGood (@"1e0", 1);
    testScanDoubleGood (@"1e1", 10);
    testScanDoubleGood (@"1e+1", 10);
    testScanDoubleGood (@"1e10", 1e10);
    testScanDoubleGood (@"1e+10", 1e10);
    testScanDoubleGood (@"1e-0", 1);
    testScanDoubleGood (@"1e-1", 1e-1);
    testScanDoubleGood (@"1e-1", 1e-1);
    testScanDoubleGood (@"1e-10", 1e-10);
    testScanDoubleGood (@"1e-10", 1e-10);

    /*
     * Check a few other values
     */
    testScanDoubleGood (@"123.456", 123.456);
    testScanDoubleGood (@"123.4567890123456789012345678901234567890123456789",
                          123.4567890123456789012345678901234567890123456789);
    testScanDoubleGood (@"1234567890123456789012345678.9",
                          1234567890123456789012345678.9);
    testScanDoubleGood (@"1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890e-99",
                          1.234567890123456789012345678901234567890123456789);
    testScanDoubleGood (@"0.000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000123456789e+100",
                                               1.23456789);

    /*
     * Check some overflow values (for IEEE double-precision)
     */
    testScanDoubleGood (@"12345678901234567890123456789012345678901234567890e300", HUGE_VAL);
    testScanDoubleGood (@"-12345678901234567890123456789012345678901234567890e300", -HUGE_VAL);
    testScanDoubleGood (@"1e999", HUGE_VAL);
    testScanDoubleGood (@"-1e999", -HUGE_VAL);

    /*
     * Check some underflow values
     */
    testScanDoubleGood (@"0.00000000000000000000000000000123456789e-300", 0);
    testScanDoubleGood (@"-0.00000000000000000000000000000123456789e-300", 0);
    testScanDoubleGood (@"1e-999", 0);
    testScanDoubleGood (@"-1e-999", 0);

    /*
     * Check that non-digits terminate the scan
     */
    testScanDoubleShort (@"1234FOO", 1234, 4);
    testScanDoubleShort (@"1234.FOO", 1234, 5);
    testScanDoubleShort (@"1234.0FOO", 1234, 6);
    testScanDoubleShort (@"1234..FOO", 1234, 5);
    testScanDoubleShort (@"1234.5.FOO", 1234.5, 6);

    /*
     * Check that non-digits don't move the scan location
     */
    testScanDoubleBad (@".foo");
    testScanDoubleBad (@"efoo");
    testScanDoubleBad (@".efoo");
    testScanDoubleBad (@"1234.5e.FOO");
    testScanDoubleBad (@"1234.5e.FOO");
    testScanDoubleBad (@"1234.5e 1");
}

//
// scanString:
//

void
testScanStringGood (NSString *string, NSString *search, NSString *match,
			BOOL caseSensitive, unsigned int goodScanLocation)
{
    NSScanner *scanner = [NSScanner scannerWithString:string];
	NSString *s;

	[scanner setCaseSensitive:caseSensitive];
	if ([scanner scanString:search intoString:&s]) {
		if (([scanner scanLocation] != goodScanLocation)
		 || ![s isEqualToString:match])
			printf ("Case-%ssensitive scanString `%s' of `%s' gives `%s', scanLocation %d.\n",
													caseSensitive ? "" : "in",
													[search cString],
													[string cString],
													[s cString],
													[scanner scanLocation]);
	}
	else {
		printf ("Case-%ssensitive scanString:`%s' of `%s' failed.\n",
													caseSensitive ? "" : "in",
													[search cString],
													[string cString]);
	}
}

void
testScanStringBad (NSString *string, NSString *search, BOOL caseSensitive)
{
    NSScanner *scanner = [NSScanner scannerWithString:string];
	NSString *s;

	[scanner setCaseSensitive:caseSensitive];
	if ([scanner scanString:search intoString:&s]) {
		printf ("Case-%ssensitive scanString `%s' of `%s' gives `%s'.\n",
													caseSensitive ? "" : "in",
													[search cString],
													[string cString],
													[s cString]);
	}
	else {
		if ([scanner scanLocation] != 0)
			printf ("Case-%ssensitive scanString `%s' of `%s' moves scan location to `%d'.\n",
													caseSensitive ? "" : "in",
													[search cString],
													[string cString],
													[scanner scanLocation]);
	}
}

void
testScanString (void)
{
	testScanStringGood (@"a", @"a", @"a", NO, 1);
	testScanStringGood (@"a", @"a", @"a", YES, 1);
	testScanStringGood (@"a", @"A", @"a", NO, 1);
	testScanStringGood (@"   abcdefg", @"aBcD", @"abcd", NO, 7);
	testScanStringGood (@"   ABCdEFG", @"aBcD", @"ABCd", NO, 7);
	testScanStringBad (@"a", @"A", YES);
	testScanStringBad (@"    a", @"A", YES);
	testScanStringBad (@"    aA", @"A", YES);
	testScanStringBad (@"    aAb", @"b", NO);
}

//
// scanUpToString:
//

void
testScanUpToStringGood (NSString *string, NSString *search, NSString *match, BOOL caseSensitive)
{
    NSScanner *scanner = [NSScanner scannerWithString:string];
	NSString *s;

	[scanner setCaseSensitive:caseSensitive];
	if ([scanner scanUpToString:search intoString:&s]) {
		if (![s isEqualToString:match])
			printf ("Case-%ssensitive scanUpToString `%s' of `%s' gives `%s'.\n",
													caseSensitive ? "" : "in",
													[search cString],
													[string cString],
													[s cString]);
	}
	else {
		printf ("Case-%ssensitive scanUpToString:`%s' of `%s' failed.\n",
													caseSensitive ? "" : "in",
													[search cString],
													[string cString]);
	}
}

void
testScanUpToString (void)
{
	testScanUpToStringGood (@"abcdefg", @"d", @"abc", NO);
	testScanUpToStringGood (@"abcdefg", @"de", @"abc", NO);
	testScanUpToStringGood (@"abcdefg", @"DeF", @"abcdefg", YES);
	testScanUpToStringGood (@"abcdefgDeFg", @"DeF", @"abc", NO);
	testScanUpToStringGood (@"abcdefgDeFg", @"DeF", @"abcdefg", YES);
}

//
// scanCharactersFromSet:
//

void
testScanCharactersFromSetGood (NSString *string, NSCharacterSet *set,
			NSString *match, unsigned int goodScanLocation)
{
    NSScanner *scanner = [NSScanner scannerWithString:string];
	NSString *s;

	if ([scanner scanCharactersFromSet:set intoString:&s]) {
		if (([scanner scanLocation] != goodScanLocation)
		 || ![s isEqualToString:match])
			printf ("scanCharactersFromSet of `%s' gives `%s', scanLocation %d.\n",
													[string cString],
													[s cString],
													[scanner scanLocation]);
	}
	else {
		printf ("scanCharactersFromSet of `%s' failed.\n", [string cString]);
	}
}

void
testScanCharactersFromSetBad (NSString *string, NSCharacterSet *set)
{
    NSScanner *scanner = [NSScanner scannerWithString:string];
	NSString *s;

	if ([scanner scanCharactersFromSet:set intoString:&s]) {
		printf ("scanCharactersFromSet of `%s' gives `%s'.\n",
													[string cString],
													[s cString]);
	}
	else {
		if ([scanner scanLocation] != 0)
			printf ("scanCharactersFromSet of `%s' moves scan location to `%d'.\n",
													[string cString],
													[scanner scanLocation]);
	}
}

void
testScanCharactersFromSet (void)
{
	NSCharacterSet *set = [NSCharacterSet uppercaseLetterCharacterSet];

	testScanCharactersFromSetGood (@"A", set, @"A", 1);
	testScanCharactersFromSetGood (@"ABCde", set, @"ABC", 3);
	testScanCharactersFromSetGood (@"ABC", set, @"ABC", 3);
	testScanCharactersFromSetGood (@"  AB12", set, @"AB", 4);
	testScanCharactersFromSetBad (@"a", set);
	testScanCharactersFromSetBad (@"  abc", set);
}

//
// scanUpToCharactersFromSet:
//

void
testScanUpToCharactersFromSetGood (NSString *string, NSCharacterSet *set,
			NSString *match, unsigned int goodScanLocation)
{
    NSScanner *scanner = [NSScanner scannerWithString:string];
	NSString *s;

	if ([scanner scanUpToCharactersFromSet:set intoString:&s]) {
		if (([scanner scanLocation] != goodScanLocation)
		 || ![s isEqualToString:match])
			printf ("scanUpToCharactersFromSet of `%s' gives `%s', scanLocation %d.\n",
													[string cString],
													[s cString],
													[scanner scanLocation]);
	}
	else {
		printf ("scanUpToCharactersFromSet of `%s' failed.\n", [string cString]);
	}
}

void
testScanUpToCharactersFromSetBad (NSString *string, NSCharacterSet *set)
{
    NSScanner *scanner = [NSScanner scannerWithString:string];
	NSString *s;

	if ([scanner scanUpToCharactersFromSet:set intoString:&s]) {
		printf ("scanUpToCharactersFromSet of `%s' gives `%s'.\n",
													[string cString],
													[s cString]);
	}
	else {
		if ([scanner scanLocation] != 0)
			printf ("scanUpToCharactersFromSet of `%s' moves scan location to `%d'.\n",
													[string cString],
													[scanner scanLocation]);
	}
}

void
testScanUpToCharactersFromSet (void)
{
	NSCharacterSet *set = [NSCharacterSet uppercaseLetterCharacterSet];

	testScanUpToCharactersFromSetGood (@"aA", set, @"a", 1);
	testScanUpToCharactersFromSetGood (@"  aABCde", set, @"a", 3);
	testScanUpToCharactersFromSetGood (@"abc", set, @"abc", 3);
	testScanUpToCharactersFromSetGood (@"  abAB12", set, @"ab", 4);
	testScanUpToCharactersFromSetBad (@"A", set);
	testScanUpToCharactersFromSetBad (@"  Abc", set);
}


int
main (int argc, char **argv)
{
extern char *optarg;
int c;
NSAutoreleasePool *arp = [NSAutoreleasePool new];

	while ((c = getopt (argc, argv, "e:")) != EOF) {
		switch (c) {
		case 'e':
			DoubleCompareEqual = atoi (optarg);
			break;
		}
	}

    testScanInt ();
#if defined (LONG_LONG_MAX)
    testScanLongLong ();
#endif
    testScanDouble ();
	testScanString ();
	testScanUpToString ();
	testScanCharactersFromSet ();
	testScanUpToCharactersFromSet ();
    [arp release];
	printf("nsscanner test complete\n");
	exit (0);
}
