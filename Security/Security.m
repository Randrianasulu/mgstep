/*
   Security.m

   SSL/TLS wrapper

   Copyright (C) 2016 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	Aug 2016

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSString.h>
#include <Foundation/NSURL.h>
#include <Foundation/NSURLCredential.h>

#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFRuntime.h>
#include <Security/Security.h>

#include <sys/socket.h>

#ifdef  ENABLE_OPENSSL

#include <openssl/rsa.h>
#include <openssl/crypto.h>
#include <openssl/x509.h>
#include <openssl/err.h>
#include <openssl/ssl.h>
#include <openssl/pem.h>


static BOOL __initializedSSL = NO;


/* ****************************************************************************

		SSLContext

** ***************************************************************************/

typedef struct SSLContext {

	void *class_pointer;
	void *cf_pointer;

	SecTrustRef _trust;

	NSInteger _port;
	NSString *_host;
	NSString *_protocol;
	NSString *_realm;
	NSString *_proxyType;
	NSString *_authenticationMethod;
	BOOL _receivesCredentialSecurely;

	SSL_CTX *_ctx;
	SSL *_ssl;
	int _sd;

	struct __SSLContextFlags {
		SSLProtocolSide            isClient:1;
		SSLConnectionType          isDatagram:1;
		SSLSessionOption           options:3;
		SSLSessionState            state:3;
		SSLProtocol                protocol:4;
		SSLClientCertificateState  certState:3;
		unsigned int               reserved:17;
	} _cf;

} SSLContext;


static void __SSLContextDeallocate(CFTypeRef cx)
{
	if (((SSLContextRef)cx)->cf_pointer)
		{
		if (((SSLContextRef)cx)->_ssl)
			SSL_free(((SSLContextRef)cx)->_ssl);
		if (((SSLContextRef)cx)->_ctx)
			SSL_CTX_free(((SSLContextRef)cx)->_ctx);
		}
	if (((SSLContextRef)cx)->_trust)
		CFRelease(((SSLContextRef)cx)->_trust);
		
	[((SSLContextRef)cx)->_host release];
	[((SSLContextRef)cx)->_protocol release];
	[((SSLContextRef)cx)->_proxyType release];
	[((SSLContextRef)cx)->_realm release];
}

static const CFRuntimeClass __SSLContextClass = {
	_CF_VERSION,
	"SSLContext",
	__SSLContextDeallocate
};


SSLContextRef
SSLCreateContext( CFAllocatorRef alloc,
				  SSLProtocolSide protocolSide,
				  SSLConnectionType connectionType)
{
	SSLContextRef cx = NULL;
	SSL_CTX *ctx;

	if (!__initializedSSL)
		{
		__initializedSSL = YES;
		SSL_load_error_strings();
		SSL_library_init();
		}

	if (protocolSide == kSSLClientSide)
		ctx = SSL_CTX_new(SSLv23_client_method());		// TLS_client_method
	else
		ctx = SSL_CTX_new(SSLv23_server_method());

	if (ctx == NULL)
		NSLog(@"SEC: error creating SSL context\n");
	else
		{
		cx = CFAllocatorAllocate(NULL, sizeof(struct SSLContext), 0);
		cx->cf_pointer = (void *)&__SSLContextClass;
		cx->class_pointer = [NSURLProtectionSpace class];	// poof, transform
		cx->_ctx = ctx;

		cx->_cf.isDatagram = connectionType;
		if ((cx->_cf.isClient = protocolSide) == kSSLClientSide)
			cx->_authenticationMethod = NSURLAuthenticationMethodServerTrust;
		else
			cx->_authenticationMethod = NSURLAuthenticationMethodDefault;
		cx->_receivesCredentialSecurely = YES;				// is SSL context
		}

	return cx;
}

OSStatus
SSLSetConnection (SSLContextRef cx, SSLConnectionRef connection)
{
	if ((cx->_ssl = SSL_new(cx->_ctx)))			// create SSL connect struct
		SSL_set_fd(cx->_ssl, PTR2INT(connection));
	cx->_sd = PTR2INT(connection);
												// set verification flags
	SSL_CTX_set_verify(cx->_ctx, SSL_VERIFY_NONE, NULL);

	return errSecSuccess;
}

static OSStatus
_LogErrorSSL(OSStatus error, int err_code)
{
	char buf[256] = {0};

	SSL_load_error_strings();
	ERR_error_string(err_code, buf);
	NSLog(@"SEC: SSL error *** (%d): %s\n", err_code, buf);
	
	return error;
}

OSStatus
SSLHandshake (SSLContextRef cx)					// have TCP connection
{
	int e, r;

	if ((r = SSL_connect(cx->_ssl)) <= 0)		// initiate TLS/SSL handshake
		{
		e = SSL_get_error(cx->_ssl, r);

		if (e == SSL_ERROR_WANT_READ || e == SSL_ERROR_WANT_WRITE)
			return errSSLWouldBlock;

		NSLog(@"SEC: error performing SSL handshake (%d)\n", r);
		
		return _LogErrorSSL(errSSLProtocol, e);
		}

	return errSecSuccess;
}

OSStatus
SSLWrite ( SSLContextRef cx, const void	*data, size_t len, size_t *bytes_wr)
{
	int e, wr;

	*bytes_wr = 0;
	if ((wr = SSL_write(cx->_ssl, data, len)) <= 0)
		{
		e = SSL_get_error(cx->_ssl, wr);

		if (e == SSL_ERROR_SYSCALL && errno == 0)
			return errSecSuccess;
		if (e == SSL_ERROR_WANT_READ || e == SSL_ERROR_WANT_WRITE)
			return errSSLWouldBlock;

		if (e == SSL_ERROR_SYSCALL)
			NSLog(@"SEC: SSL socket errno (%d) %s\n", errno, strerror(errno));
		else
			NSLog(@"SEC: error writing to SSL socket (%d)\n", wr);

		return _LogErrorSSL(errSSLProtocol, e);
		}
	*bytes_wr = wr;

	return errSecSuccess;
}

OSStatus
SSLRead (SSLContextRef cx, void *data, size_t len, size_t *bytes_read)
{
	int e, rd;

	*bytes_read = 0;
	if ((rd = SSL_read(cx->_ssl, data, len)) <= 0)
		{
		e = SSL_get_error(cx->_ssl, rd);

		if (e == SSL_ERROR_SYSCALL && errno == 0)
			return errSecSuccess;
		if (e == SSL_ERROR_WANT_READ || e == SSL_ERROR_WANT_WRITE)
			return errSSLWouldBlock;

		if (e == SSL_ERROR_SYSCALL)
			NSLog(@"SEC: SSL socket errno (%d) %s\n", errno, strerror(errno));
		else
			NSLog(@"SEC: error reading from SSL socket (%d)\n", rd);

		return _LogErrorSSL(errSSLProtocol, e);
		}
	*bytes_read = rd;

	return errSecSuccess;
}

OSStatus
SSLClose (SSLContextRef cx)
{
	if (cx->_sd)
		{
		shutdown(cx->_sd, 1);			// Half close, send EOF to server
		close(cx->_sd);
		}

	return 0;
}

/* ****************************************************************************

	SecCertificate

** ***************************************************************************/

typedef struct _SecCertificate {

	void *class_pointer;
	void *cf_pointer;

	CFDataRef _certData;

	struct __SecCertificateFlags {
		unsigned int reserved:8;
	} _cf;

} SecCertificate;

static void __SecCertificateDeallocate(CFTypeRef cx)
{
	if ( ((SecCertificate *)cx)->_certData)
		CFRelease( ((SecCertificate *)cx)->_certData);
}

static const CFRuntimeClass __SecCertificateClass = {
	_CF_VERSION,
	"SecCertificate",
	__SecCertificateDeallocate
};

SecCertificateRef
SecCertificateCreateWithData( CFAllocatorRef allocator, CFDataRef data)
{
	SecCertificate *sc = CFAllocatorAllocate(NULL, sizeof(SecCertificate), 0);
											// create a cert ref given its DER
	sc->_certData = CFRetain(data);			// encoded X.509 stored in NSData
	sc->cf_pointer = (void *)&__SecCertificateClass;

	return (SecCertificateRef)sc;
}

/* ****************************************************************************

	SecTrust

** ***************************************************************************/

typedef struct _SecTrust {

	void *class_pointer;
	void *cf_pointer;

	CFArrayRef _certArrayRef;
	SSLContextRef _ctx;
	
	X509 *_cert;

} SecTrust;

static void __SecTrustDeallocate(CFTypeRef cx)
{
	if ( ((SecTrust *)cx)->_certArrayRef )
		CFRelease( ((SecTrust *)cx)->_certArrayRef );
	if ( ((SecTrust *)cx)->_cert )
		X509_free (((SecTrust *)cx)->_cert), ((SecTrust *)cx)->_cert = NULL;
}

static const CFRuntimeClass __SecTrustClass = {
	_CF_VERSION,
	"SecTrust",
	__SecTrustDeallocate
};

/* ****************************************************************************

	NSURLProtectionSpace

** ***************************************************************************/

@implementation NSURLProtectionSpace

- (NSString *) authenticationMethod		{ return _authenticationMethod; }
- (NSString *) host						{ return _host; }
- (NSString *) protocol					{ return _protocol; }
- (NSString *) proxyType				{ return _proxyType; }
- (NSString *) realm					{ return _realm; }
- (NSInteger) port						{ return _port; }
- (BOOL) receivesCredentialSecurely		{ return _receivesCredentialSecurely; }
- (BOOL) isProxy						{ return _proxyType != nil; }

- (id) init								{ return nil; }
- (id) copy								{ return [self retain]; }

- (id) initWithHost:(NSString *) host
			   port:(NSInteger)  port
			   protocol:(NSString *) protocol
			   realm:(NSString *) realm
			   authenticationMethod:(NSString *) method
{
	_host = [host retain];
	_port = port;
	_protocol = [protocol retain];
	_realm = [realm retain];
	_authenticationMethod = method;

	return self;
}

- (id) initWithProxyHost:(NSString *) host
					port:(NSInteger)  port
					type:(NSString *) proxyType
				   realm:(NSString *) realm
	authenticationMethod:(NSString *) method
{
	_host = [host retain];
	_port = port;
	_proxyType = [proxyType retain];
	_realm = [realm retain];
	_authenticationMethod = method;

	return self;
}

- (void) dealloc
{
	__SSLContextDeallocate((CFTypeRef)self);

	[super dealloc];
}

- (NSArray *) distinguishedNames
{
	if (_authenticationMethod == NSURLAuthenticationMethodClientCertificate)
		{	/* array of NSData objects with acceptable certificate issuing
		authorities for client certification authentication. Issuers are
		identified by their distinguished name returned as DER encoded data. */
		
// OSStatus SSLCopyDistinguishedNames (SSLContextRef context, CFArrayRef *names)
		}

	return nil;
}

- (SecTrustRef) serverTrust
{
	if (_authenticationMethod == NSURLAuthenticationMethodServerTrust)
		if (!_trust)
			SSLCopyPeerTrust ((SSLContextRef)self, &_trust);

	return _trust;			// represents state of SSL transaction state
}

- (NSString *) description;
{
	return [NSString stringWithFormat:@"%@ host=%@ port=%d proxy=%@ realm=%@ %@",
						NSStringFromClass(isa), _host, _port,
						_proxyType, _realm, _authenticationMethod];
}

@end  /* NSURLProtectionSpace */


OSStatus
SecTrustCreateWithCertificates( CFTypeRef certificates,
								CFTypeRef policies,
								SecTrustRef *trust)
{
	*trust = CFAllocatorAllocate(NULL, sizeof(SecTrust), 0);
	((SecTrust *)(*trust))->cf_pointer = (void *)&__SecTrustClass;

	if (certificates)	// FIX ME should also accept a single SecCertificateRef
		((SecTrust *)(*trust))->_certArrayRef = CFRetain(certificates);

	return 0;
}

OSStatus
SSLCopyPeerTrust ( SSLContextRef context, SecTrustRef *trust)
{
	if (((SSLContext *)context)->_trust)
		*trust = CFRetain(((SSLContext *)context)->_trust);
	else
		{
		if (!SecTrustCreateWithCertificates(NULL, NULL, trust))
			((SecTrust *)(*trust))->_ctx = context;
		((SSLContext *)context)->_trust = CFRetain(*trust);
		}

	return 0;
}

OSStatus
SecTrustEvaluate(SecTrustRef trust, SecTrustResultType *result)
{
	X509 *cert;
	SSL *ssl = ((SecTrust *)trust)->_ctx->_ssl;		// get from ctx
	char *str;
	int r;

	*result = kSecTrustResultOtherError;
													// optinal: Get the cipher
	NSLog(@"SSL connection using %s\n", SSL_get_cipher (ssl));

	if ((cert = SSL_get_peer_certificate (ssl)) == NULL)
		{
		NSLog(@"SEC: error getting peer's certificate\n");
		return errSSLPeerBadCert;
		}
	((SecTrust *)trust)->_cert = cert;
	
	// result of cert verification process can be checked after TLS/SSL handshake
	if ((r = SSL_get_verify_result(ssl)) != X509_V_OK)
		{
		*result = kSecTrustResultInvalid;

		if ( r == X509_V_ERR_UNABLE_TO_DECRYPT_CERT_SIGNATURE)
			return errSSLPeerDecryptError;
		if ( r == X509_V_ERR_CRL_SIGNATURE_FAILURE
				|| r == X509_V_ERR_CERT_SIGNATURE_FAILURE)
			return errSSLCrypto;
		if (r == X509_V_ERR_CERT_HAS_EXPIRED)
			return errSSLCertExpired;
		if (r == X509_V_ERR_CERT_REVOKED)
			return errSSLPeerCertRevoked;
		if (r == X509_V_ERR_UNABLE_TO_DECODE_ISSUER_PUBLIC_KEY)
			return errSSLPeerDecodeError;
		if (r == X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT)
			return errSSLNoRootCert;

		*result = kSecTrustResultUnspecified;

		if (r == X509_V_ERR_INVALID_PURPOSE)
			return errSSLPeerAuthCompleted;
		if (r == X509_V_ERR_SELF_SIGNED_CERT_IN_CHAIN)
			return errSSLUnknownRootCert;

		*result = kSecTrustResultRecoverableTrustFailure;

		if (r == X509_V_ERR_CERT_NOT_YET_VALID)
			return errSSLCertNotYetValid;
		}

	*result = kSecTrustResultProceed;

	if((str = X509_NAME_oneline(X509_get_subject_name(cert), NULL, 0)) == NULL)
		NSLog(@"SEC: unable to determine certificate subject\n");
	else
		printf ("Server certificate:\n  subject: %s\n", str);
	free (str);
	
	if((str = X509_NAME_oneline(X509_get_issuer_name(cert), NULL, 0)) == NULL)
		NSLog(@"SEC: unable to determine certificate issuer\n");
	else
		printf ("  issuer: %s\n", str);
	free (str);

	return 0;
}

OSStatus
SecTrustSetAnchorCertificates(SecTrustRef trust, CFArrayRef anchorCertificates)
{
	((SecTrust *)trust)->_certArrayRef = CFRetain(anchorCertificates);

	return 0;
}

#else   /* OPENSSL DISABLED ************************************************ */

SSLContextRef
SSLCreateContext( CFAllocatorRef a, SSLProtocolSide ps, SSLConnectionType c)
{
	return NULL;
}

SecCertificateRef
SecCertificateCreateWithData( CFAllocatorRef a, CFDataRef d)   { return NULL; }

OSStatus
SSLWrite (SSLContextRef c, const void *d, size_t l, size_t *b)	  { return 0; }
OSStatus SSLRead (SSLContextRef c, void *d, size_t l, size_t *b)  { return 0; }
OSStatus SSLHandshake (SSLContextRef c)							  { return 0; }
OSStatus SSLSetConnection (SSLContextRef x, SSLConnectionRef c)   { return 0; }
OSStatus SecTrustEvaluate(SecTrustRef t, SecTrustResultType *r)   { return 0; }
OSStatus SecTrustSetAnchorCertificates(SecTrustRef t,CFArrayRef a){ return 0; }

#endif  /* ENABLE_OPENSSL */
