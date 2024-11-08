/*
	mget.m

	gcc mget.m -o mget -framework Foundation -framework Security
*/

#include <Foundation/Foundation.h>
#include <Foundation/NSURLCredential.h>

#define NONE        "\033[0m"
#define CYAN        "\033[36;40m"
#define PGRN        "\033[32;40m"
#define FRED        "\033[31;40m"

static void DisplayBufferHEX(const void *buffer, unsigned int length);

BOOL __saveDownload = NO;

// NSString *__default_URL = @"https://www.cacert.org/images/cacert4.png";
// NSString *__default_URL = @"https://www.example.com";
#ifdef  ENABLE_OPENSSL
NSString *__default_URL = @"https://www.google.ch";
#else
NSString *__default_URL = @"http://www.google.ch";
#endif  /* ENABLE_OPENSSL */



@interface MGet : NSObject
{
	NSMutableData *_receivedData;
	NSURL *_url;
}

@end

@implementation MGet

- (id) initWithURL:(NSURL *)url
{
	NSLog(@"mget init\n");
							// Create Data obj that will hold received data
	_receivedData = [[NSMutableData data] retain];
	_url = [url retain];

	return self;
}

- (void) dealloc;
{
    [_receivedData release];
    [_url release];

	[super dealloc];
}

- (BOOL) shouldTrustProtectionSpace:(NSURLProtectionSpace *)protectionSpace
{
//	NSString *certPath = @"./cert.der";
	NSString *certPath = @"./www.cacert.org.cer";	// Load bundled certificate

	if (![[NSFileManager defaultManager] fileExistsAtPath:certPath])
    	return NO;

    NSData *certData = [[NSData alloc] initWithContentsOfFile:certPath];
    CFDataRef certDataRef = (CFDataRef)certData;
//  CFDataRef certDataRef = (__bridge_retained CFDataRef)certData;
    SecCertificateRef cert = SecCertificateCreateWithData(NULL, certDataRef);
	
	NSLog(@"Certificate Data: %@", certData);

    // Establish a chain of trust anchored on bundled certificate.
    CFArrayRef certArrayRef = CFArrayCreate(NULL, (void *)&cert, 1, NULL);
//  NSArray *certArrayRef = [[NSArray alloc] initWithObjects:(id*)&cert count:1];
    SecTrustRef serverTrust = [protectionSpace serverTrust];
    SecTrustSetAnchorCertificates(serverTrust, certArrayRef);

    SecTrustResultType trustResult;						// Verify trust
    SecTrustEvaluate(serverTrust, &trustResult);

    CFRelease(certArrayRef);
    CFRelease(cert);
    CFRelease(certDataRef);

	NSLog(@"Trust: %d", trustResult);

    return trustResult == kSecTrustResultUnspecified;
}

- (BOOL) connection:(NSURLConnection *)connection
		 canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)ps
{
	NSString *am = [ps authenticationMethod];
												// must verify server identity
	return [am isEqualToString: NSURLAuthenticationMethodServerTrust];
}

- (void) connection:(NSURLConnection *)connection
		 didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)ch
{
	NSURLProtectionSpace *ps = [ch protectionSpace];
	id sr = [ch sender];

    NSLog(@"Connection didReceiveAuthenticationChallenge from %@", [ps description]);
//  if ([[ps authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust])
//    if ([trustedHosts containsObject:challenge.protectionSpace.host])

    if ([self shouldTrustProtectionSpace: ps])
		{					// a credential based on certs the server provided
		NSURLCredential *cd = [ch proposedCredential];

		[sr useCredential:cd forAuthenticationChallenge:ch];	// trust it
		}
	else
		[sr continueWithoutCredentialForAuthenticationChallenge:ch];
//      [sr performDefaultHandlingForAuthenticationChallenge:ch];
//      [sr cancelAuthenticationChallenge:ch];
}

- (void) connection:(NSURLConnection *)connection		// NSURL delegate
		 didReceiveResponse:(NSURLResponse *)response
{
	NSDictionary *hd = [(NSHTTPURLResponse*)response allHeaderFields];
	NSInteger c = [(NSHTTPURLResponse *)response statusCode];
    // this method is called when the URL loading subsystem has determined that
    // it has enough information to create the NSURLResponse it can be called
	// multiple times, for example in the case of a redirect, so each time we
	// reset the recvieved data
    NSLog(@"Connection didReceiveResponse status: %d", c);
	NSLog(@"%@", [hd description]);
    [_receivedData setLength:0];
}

- (void) connection:(NSURLConnection *)connection
		 didReceiveData:(NSData *)data
{
    NSLog(@"Connection didReceiveData");
	DisplayBufferHEX([data bytes], [data length]);
//	NSLog(@"%s",[data bytes]);

    [_receivedData appendData:data];		// append new data to receivedData
}

- (void) connection:(NSURLConnection *)connection
		 didFailWithError:(NSError *)error
{
    [connection release];						// release connection

    NSLog(@"Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey: NSErrorFailingURLStringKey]);
}

- (void) connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSLog(@"Succeeded! Received %d bytes of data",[_receivedData length]);
 
	if (__saveDownload == YES && [_receivedData length] > 0)
		{
		NSString *dp = [_url lastPathComponent];
		NSString *path = [@"./" stringByAppendingPathComponent: dp];

//		NSLog(@"mget: Save URL as %@\n", path);
		[_receivedData writeToFile:path atomically:NO];
		}

    [connection release];						// release connection
}

@end


static void
DisplayBufferHEX(const void *buffer, unsigned int length)
{
	unsigned int i;

	printf ("Got %d chars:\n", length);

	for (i = 0; i < length;) 
		{
		unsigned int j;

		printf("  %04X  ", i);				// line start

		for (j = i; (j < length) && (j < i+16); j++) 
			{
			unsigned char c = *((char *)buffer + j);
			printf("%02hhX ",c);			// hex content
			if (j == i+7)
				printf(" ");
			}

		for (; j < i+16; j++)				// realign
			{
			printf("   ");
			if (j == i+7)
				printf(" ");
			}
		printf(" ");
											// char content
		for (j = i; (j < length) && (j < i+16); j++)
			{
			unsigned char c = *((char *)buffer + j);

			if ((c < 32) || (c > 126))
				c = '.';					// display unprintable chars as '.'
			printf("%c",c);
			}

		printf("\n");						// end line
		i = j;
		}

	if (length > 16)
		printf("\n");						// end line
}

void
self_test(void)
{
	printf (CYAN "NSURL self test" NONE "\n");
	NSURL *mal1 = [NSURL URLWithString: @"https//john:p4ssw0rd@www.example.com:443/"]; // malformed URL
	NSURL *url1 = [NSURL URLWithString: @"https://john:p4ssw0rd@www.example.com:443/script.ext;param=value?query=value#ref"];
	NSURL *url2 = [NSURL URLWithString: @"https://john:p4ssw1rd@www.example.com:443/script.ext;param=value?query=value#ref"];
	NSURL *url3 = [NSURL URLWithString: @"data:text/html;charset=utf-8,ASF123"];
	NSURL *url4 = [NSURL URLWithString: @"data:image/jpeg;base64,ASFB="];
	NSURL *url5 = [NSURL URLWithString: @"https://john:p4ssw0rd@www.example.com:443/script.ext"];
	NSURL *url6 = [NSURL URLWithString: @"https://john:p4ssw0rd@www.example.com:443"];
	NSURL *url7 = [NSURL URLWithString: @"/script.ext" relativeToURL: url6];
	NSURL *url8 = [NSURL URLWithString: @"http://[::FFFF:129.144.52.38]:8080/index.html"];
	NSURL *url9 = [NSURL URLWithString: @"http://[1080::8:800:200C:417A]/foo"];
	NSURL *u10x = [NSURL URLWithString: @"https://www.example.com:443/script.ext?query=value#ref"];

	if (mal1 == nil)
		printf (PGRN "PASS: malformed URL rejected\n" NONE);
	else
		printf (FRED "FAIL: malformed URL accepted\n" NONE);

	if ([url1 isEqual: url2])
		printf (FRED "FAIL: URL password %s != %s\n" NONE,
				[[url1 password] cString], [[url2 password] cString]);
	if (![url5 isEqual: url7])
		printf (PGRN "PASS: relative URL not equal to absolute\n" NONE);
	else
		printf (FRED "FAIL: relative URL equal to absolute %s %s\n" NONE,
				[[url7 description] cString], [[url5 description] cString]);
	if ([[url5 absoluteURL] isEqual: [url7 absoluteURL]])
		printf (PGRN "PASS: absolute URL equal to absolute\n" NONE);
	else
		printf (FRED "FAIL: absolute URL not equal to absolute %s %s\n" NONE,
				[[[url7 absoluteURL] description] cString], [[[url5 absoluteURL] description] cString]);

	if ([url3 isEqual: url4])
		printf (FRED "FAIL: URL data scheme equal %s %s\n" NONE,
				[[url3 absoluteString] cString], [[url4 absoluteString] cString]);

	if (![[url3 path] isEqualToString: @"text/html;charset=utf-8,ASF123"])
		printf (FRED "FAIL: URL data scheme path %s != %s\n" NONE,
				[[url3 path] cString], "text/html;charset=utf-8,ASF123");

	printf ("URL Param: \"%s\" Query: \"%s\" Fragment: \"%s\"\n",
			[[url1 parameterString] cString], [[url1 query] cString], [[url1 fragment] cString]);
	printf ("URL Param: \"%s\" Query: \"%s\" Fragment: \"%s\"\n",
			[[u10x parameterString] cString], [[u10x query] cString], [[u10x fragment] cString]);

	printf ("URL IPv6: \"%s\" port: %d\n", [[url8 host] cString], [[url8 port] intValue]);
	printf ("URL IPv6: \"%s\" port: %d Path: \"%s\"\n",
			[[url9 host] cString], [[url9 port] intValue], [[url9 path] cString]);

	printf ("URL hash %d %d\n", [url1 hash], [url2 hash]);
	printf ("URL hash %d %d\n", [url5 hash], [url7 hash]);
}

void
usage(char *err_msg, int exit_status)
{
	if (exit_status)
		fprintf(stdout, "\n Invalid command, %s\n\n Usage:\t", err_msg);
	else
		fprintf(stdout, "\n %s\n\n", err_msg);

	fprintf(stdout, " mget [-s]  <URL-1> <URL-2> ...\n");
	fprintf(stdout, "  -s  Save URL\n");
	fprintf(stdout, "\n");

	exit(exit_status);
}

void
run_client(int i)
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	NSArray *args = [[NSProcessInfo processInfo] arguments];
	int c;

	if (i == 0)
		self_test();

	for (c = [args count]; i < c; i++)
		{
		NSString *s = (i == 0) ? __default_URL : [args objectAtIndex: i];
		NSURL *u;

		if (u = [NSURL URLWithString: s])
			{
			NSURLConnection *c;
			NSURLRequest *r = [NSURLRequest requestWithURL: u
											cachePolicy:NSURLRequestUseProtocolCachePolicy
											timeoutInterval:15.0];
			MGet *mg = [[[MGet alloc] initWithURL: u] autorelease];
						// create  connection with  request and start loading data
			if (!(c = [[NSURLConnection alloc] initWithRequest:r delegate:mg]))
				NSLog(@"mget: Invalid NSURLConnection\n");
			}
		else
			NSLog(@"mget: Invalid URL str %@\n", s);
		}

	[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow:3]];

    [pool release];
}

int
main(int argc, char **argv, char **env)
{
	extern int optind;
	int c;

	while ((c = getopt(argc, argv, "+shv")) != -1)		// don't permute args
		switch (c)
			{
			case 's':
				__saveDownload = YES;
				if (optind == argc)						// detect missing arg
					usage("expected argument after option: -s", 1);
				break;
			case 'h':	usage("mget HTTP client tool help:", 0);
			case 'v':	usage("mGSTEP mget v0.004", 0);
			};

	if (optind > argc)
		usage("expected argument after options: ", 1);

	run_client( (optind == argc) ? 0 : optind );
	printf("mget test complete\n");

	exit(0);
}
