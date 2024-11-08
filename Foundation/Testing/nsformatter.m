#import <Foundation/Foundation.h>

#import <Foundation/NSNumberFormatter.h>
#import <Foundation/NSDateFormatter.h>
#import <Foundation/NSLocale.h>

void initWithFormat (NSString *format, ...);


int main (void)
{
	id pool = [[NSAutoreleasePool alloc] init];

    NSNumberFormatter *fmt;
    NSNumber *num;
    NSNumber *zero;
    NSString *str;
    NSString *error;
	NSLocale *nlLocale;

  printf("NSNumberFormatter tests\n");

    fmt = [[[NSNumberFormatter alloc] init] autorelease];
    num = [[[NSNumber alloc] initWithFloat: -1234.567] autorelease];
    zero = [[[NSNumber alloc] initWithFloat: 0.0] autorelease];

	printf("formattedNumberString: %s\n", [[fmt stringForObjectValue: num] cString]);
	printf("formattedNumberString: %s\n", [[fmt stringForObjectValue: zero] cString]);
[fmt setPositiveFormat:@"###0.##"];
	printf("formattedNumberString: %s\n", [[fmt stringForObjectValue: num] cString]);
	printf("formattedNumberString: %s\n", [[fmt stringForObjectValue: zero] cString]);

[fmt setPositiveFormat:@"#,##0.##"];
	printf("formattedNumberString: %s\n", [[fmt stringFromNumber: num] cString]);

[fmt setPositiveFormat:@"¤#,##0.##"];
	printf("formattedNumberString: %s\n", [[fmt stringFromNumber: num] cString]);

[fmt setNegativeFormat:@"#,##0.##"];
	printf("formattedNumberString: %s [-]\n", [[fmt stringFromNumber: num] cString]);

	nlLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"nl_NL"];
	[fmt setLocale:nlLocale];
    num = [[[NSNumber alloc] initWithFloat: 122344.4563] autorelease];
	printf("formattedNumberString NL: %s\n", [[fmt stringFromNumber: num] UTF8String]);

[fmt setPositiveFormat:@"#,##0.##"];
	str = [fmt stringFromNumber: num];
	printf("formattedNumberString NL+: %s\n", [[fmt stringFromNumber: num] cString]);

    num = [[[NSNumber alloc] initWithFloat: -122344.4563] autorelease];
[fmt setNegativeFormat:@"(###0.##)"];
	printf("stringFromNumber: %s\n", [[fmt stringFromNumber: num] cString]);
//[fmt setNegativeFormat:@"(###0.###)"];  // s/b ignored except for prefix/suffix
[fmt setPositiveFormat:@"#,##0.###"];
	printf("stringFromNumber: %s\n", [[fmt stringFromNumber: num] cString]);

[fmt setMinusSign:@"+"];
	printf("numberFromString: %s\n", [[[fmt numberFromString: str] stringValue] cString]);

[fmt setNegativePrefix:@"\033[31;40m"];
[fmt setNegativeSuffix:@"\033[0m"];
	printf("numberFromString: %s\n", [[fmt stringFromNumber: num] cString]);

    fmt = [[[NSNumberFormatter alloc] init] autorelease];
	printf("currencySymbol: %s\n", [[fmt currencySymbol] cString]);

	initWithFormat (@"A float %f another %f trail", 123.45, 148.99);

    num = [[[NSNumber alloc] initWithLong: LONG_MAX] autorelease];
    fmt = [[[NSNumberFormatter alloc] init] autorelease];
	printf("stringFromNumber LONG: %s\n", [[fmt stringFromNumber: num] cString]);
[fmt setPositiveFormat:@"#,##0"];
	printf("stringFromNumber LONG: %s\n", [[fmt stringFromNumber: num] cString]);

    num = [[[NSNumber alloc] initWithLong: INT_MAX] autorelease];
	printf("stringFromNumber INT: %s\n", [[fmt stringFromNumber: num] cString]);

[fmt setPositivePrefix:@"\033[36;40m"];
[fmt setPositiveSuffix:@"\033[0m"];
	printf("stringFromNumber INT: %s\n", [[fmt stringFromNumber: num] cString]);

    num = [[[NSNumber alloc] initWithLong: -INT_MAX] autorelease];
	printf("stringFromNumber INT: %s\n", [[fmt stringFromNumber: num] cString]);

[fmt setMinusSign:@"0 > "];
	printf("stringFromNumber INT: %s\n", [[fmt stringFromNumber: num] cString]);

	[pool release];

  printf("nsformatter test complete\n");

    return 0;
}

void
initWithFormat (NSString *format, ...)
{
    NSString *str;
	va_list ap;

	va_start (ap, format);
	str = [[NSString alloc] initWithFormat:format
							locale:[[NSLocale alloc] initWithLocaleIdentifier:@"nl_NL"]
							arguments:ap];
	va_end (ap);

	printf("initWithFormat NL: %s\n", [str cString]);
}
