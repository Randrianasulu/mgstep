/*
   Security.h

   Authentication and certificate handling functions

   Copyright (C) 2016 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	August 2016

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_Security
#define _mGSTEP_H_Security

	// conceptually a thread of execution which invokes its jobs in FIFO order
typedef struct _opaqueDispatchQueue  dispatch_queue_t;	// dispatch/queue.h

/* ****************************************************************************

	SecBase  (FIX ME incomplete Security Error Codes)

** ***************************************************************************/

enum
{
    errSecSuccess        = 0,       // No error
    errSecUnimplemented  = -4,      // Function or operation not implemented
    errSecIO             = -36,     // I/O error
    errSecAuthFailed     = -25293,	// user name or pwd entered is not correct
	errSecInvalidRoot    = -67612,	// root or anchor certificate is not valid
	errSecCRLNotFound    = -67615,	// CRL was not found
	errSecCRLNotTrusted  = -67620,	// CRL is not trusted
};

typedef int  OSStatus;				// OSTypes.h

									// opaque trust management structures
typedef const struct __SecCertificateRef *SecCertificateRef;
typedef const struct __SecIdentityRef    *SecIdentityRef;
typedef const struct __SecPolicyRef      *SecPolicyRef;
typedef const struct __SecTrustRef       *SecTrustRef;

/* ****************************************************************************

	SecCertificate

** ***************************************************************************/

		// create a cert ref given its DER encoded X.509 rep in an NSData
SecCertificateRef SecCertificateCreateWithData( CFAllocatorRef a, CFDataRef d);

/* ****************************************************************************

	SecTrust

** ***************************************************************************/

typedef enum {
    kSecTrustResultInvalid                 = 0,
    kSecTrustResultProceed                 = 1,
    kSecTrustResultConfirm                 = 2,  // user confirm is required
    kSecTrustResultDeny                    = 3,  // do not proceed, user denied
    kSecTrustResultUnspecified             = 4,  // user intent unknown, ask
    kSecTrustResultRecoverableTrustFailure = 5,  // error in input data args
    kSecTrustResultFatalTrustFailure       = 6,  // fatal error
    kSecTrustResultOtherError              = 7
} SecTrustResultType;


CFTypeID SecTrustGetTypeID(void);

/*
	SecTrustEvaluate()    synchronous evaluation of a trust ref

	complete evaluation of trust before returning, possibly including network
	access to fetch intermediate certificates or to perform revocation checking.
	This function can block so call it from within a function that is placed
	on a dispatch queue or in a separate thread from app's main run loop.
*/
OSStatus SecTrustEvaluate(SecTrustRef trust, SecTrustResultType *result);


typedef void (*SecTrustCallback)( SecTrustRef t, SecTrustResultType r);

/*
	Evaluate trust reference asynchronously.  queue is a dispatch queue on
	which the result callback should be executed. Set NULL to use the current
	dispatch queue. SecTrustCallback block which will be executed when
	trust evaluation is complete.
*/
OSStatus SecTrustEvaluateAsync( SecTrustRef trust,
								dispatch_queue_t queue,
								SecTrustCallback result);

/* ****************************************************************************

    SecTrustCreateWithCertificates()
	
    Creates a trust object based on the given certificates and policies.
    Returns a result code, see "Security Error Codes" (SecBase.h).

    certificates :  SecCertificateRef cert or an array of certs to verify
    policies     :  SecPolicyRef policy or an array of one or more policies.
	trust        :  returns a pointer to the trust reference.

    ** If multiple policies, all must be valid for chain to be considered valid

** ***************************************************************************/

OSStatus SecTrustCreateWithCertificates( CFTypeRef certificates,
										 CFTypeRef policies,
										 SecTrustRef *trust);

			// sets the anchor certificates for the trust
OSStatus SecTrustSetAnchorCertificates( SecTrustRef trust,
										CFArrayRef anchorCertificates);
			// set SecPolicyRef policy (or array of) for trust
OSStatus SecTrustSetPolicies(SecTrustRef trust, CFTypeRef policies);

/* ****************************************************************************

	SecureTransport

** ***************************************************************************/

struct                      SSLContext;			// opaque SSL context
typedef struct SSLContext * SSLContextRef;

typedef const void *		SSLConnectionRef;	// opaque ref to endpoint socket


typedef enum {                // SSL Protocol version

	kSSLProtocolUnknown = 0,  // no proto negotiated or specified, use default
	kSSLProtocol3       = 2,  // SSL 3.0
	kTLSProtocol1       = 4,  // TLS 1.0
    kTLSProtocol11      = 7,  // TLS 1.1
    kTLSProtocol12      = 8,  // TLS 1.2
    kDTLSProtocol1      = 9,  // DTLS 1.0
											// Deprecated on iOS
    kSSLProtocol2       = 1,  // SSL 2.0
    kSSLProtocol3Only   = 3,  // SSL 3.0 only
    kTLSProtocol1Only   = 5,  // TLS 1.0 only
    kSSLProtocolAll     = 6,  // all TLS supported protocols

} SSLProtocol;


typedef enum {
	 	// Enable return from SSLHandshake when server auth portion of handshake
		// is complete.  Disables cert validation, allows app specific
	kSSLSessionOptionBreakOnServerAuth,		// ret: errSSLServerAuthCompleted
	 	// Enable return from SSLHandshake when server requests client cert
	kSSLSessionOptionBreakOnCertRequested,	// ret: errSSLClientCertRequested
     	// same as kSSLSessionOptionBreakOnServerAuth but applies to server when
	 	// the client has presented its certificates allowing server to verify
	 	// whether these should be allowed to authenticate.
    kSSLSessionOptionBreakOnClientAuth,
// Enable/Disable TLS False Start will only be performed if adequate cipher-suite
//    kSSLSessionOptionFalseStart,
// Enable/Disable 1/n-1 record splitting for BEAST attack mitigation.
//    kSSLSessionOptionSendOneByteRecord,
// Allow/Disallow server identity change on renegotiation. Disallow by default
//    kSSLSessionOptionAllowServerIdentityChange,

} SSLSessionOption;

							// client cert exchange state (optional)
typedef enum {
	kSSLClientCertNone,
	kSSLClientCertRequested,
	kSSLClientCertSent,		// server: client cert valid; client: cert sent
	kSSLClientCertRejected
} SSLClientCertificateState;


typedef enum {				// SSLSession state

	kSSLIdle,				// no I/O performed yet
	kSSLHandshake,			// SSL handshake in progress
	kSSLConnected,			// Handshake complete, ready for normal I/O
	kSSLClosed,				// connection closed normally
	kSSLAborted				// connection aborted

} SSLSessionState;


typedef enum {
    kSSLServerSide,
    kSSLClientSide
} SSLProtocolSide;

typedef enum {
    kSSLStreamType,
    kSSLDatagramType
} SSLConnectionType;


// CFTypeID  SSLContextGetTypeID(void);

SSLContextRef  SSLCreateContext( CFAllocatorRef alloc,
								 SSLProtocolSide protocolSide,
								 SSLConnectionType connectionType);

OSStatus SSLGetSessionState (SSLContextRef cx, SSLSessionState *state);
OSStatus SSLSetSessionOption (SSLContextRef cx, SSLSessionOption o, BOOL v);
OSStatus SSLGetSessionOption (SSLContextRef cx, SSLSessionOption o, BOOL *v);

		// set context cert, mandatory for servers, opt for clients
OSStatus SSLSetCertificate (SSLContextRef context, CFArrayRef certRefs);

		// specify I/O connection.  Assumes comm is established if client and
		// that an incoming client request is established if a server
OSStatus SSLSetConnection (SSLContextRef cx, SSLConnectionRef connection);
OSStatus SSLGetConnection (SSLContextRef cx, SSLConnectionRef *connection);

		// Perform SSL handshake. Session is ready for normal secure I/O with
		// SSLWrite and SSLRead upon successful return.  An errSSLWouldBlock
		// return indicates retries are needed til something else is returned
		// ** SSL session is active between calls to SSLHandshake and SSLClose
OSStatus SSLHandshake (SSLContextRef context);

		// terminate SSL session
OSStatus SSLClose (SSLContextRef context);

		// App read / write.  Both can return errSSLWouldBlock possibly
		// indicating a partially completed transfer or even zero transferred.
OSStatus  SSLWrite ( SSLContextRef context,
					 const void * data,
					 size_t       dataLength,
					 size_t     * processed);		// return value

		// data is allocated by caller, specify size in dataLength
		// actual number of bytes read is returned in *processed
OSStatus  SSLRead ( SSLContextRef context,
					 void       * data,				// return value
					 size_t       dataLength,
					 size_t     * processed);		// return value

typedef OSStatus  (*SSLReadFunc) (SSLConnectionRef cx,
								  void *data, // owned by caller, data returned
								  size_t *dataLength);	// in / out
typedef OSStatus  (*SSLWriteFunc) (SSLConnectionRef cx,
								  const void *data,
								  size_t *dataLength);	// in / out

OSStatus SSLSetIOFuncs (SSLContextRef cx, SSLReadFunc rd, SSLWriteFunc wr);

/* ****************************************************************************

    SSLCopyPeerTrust()

	Returns a SecTrustRef representing the peer's certificates.  Caller must
	release the SecTrustRef which will have already been evaluated unless:

	- Automatic certificate verification was disabled, by calling
      SSLSetSessionOption to set kSSLSessionOptionBreakOnServerAuth to true.
	- SSLSetPeerID was called, and this session has been resumed from an
      earlier cached session.

	Call SecTrustEvaluate prior to examining the peer certificate chain or
	trust results if trust eval was disabled.

	**Returns NULL if SSLHandshake has not been called previously for context.

** ***************************************************************************/

OSStatus SSLCopyPeerTrust( SSLContextRef cx, SecTrustRef *trust);


/* ****************************************************************************

    SSLCopyDistinguishedNames()

	Returns CFData array of DER encoded distinguised names provided by server
	if SSLContextRef is configured as a client. 
	Returns array set by SSLSetCertificateAuthorities if configured as a server.

** ***************************************************************************/

OSStatus SSLCopyDistinguishedNames( SSLContextRef cx, CFArrayRef *names);


/* ****************************************************************************

    SSLHandshake errors (abort):

    errSSLUnknownRootCert:   Peer had a valid cert chain but root is unknown
    errSSLNoRootCert:        Peer had a cert chain which did not end in a root
    errSSLCertExpired:       Peer's cert chain had one or more expired certs
    errSSLXCertChainInvalid: Peer had an invalid cert chain or no certs
 
    SSLHandshake errors (can recover):

    errSSLPeerAuthCompleted:  Peer's cert chain is valid, or was ignored if
		cert verification was disabled via SSLSetEnableCertVerify.  Continue
		with handshake by calling SSLHandshake again or close the connection.

    errSSLClientCertRequested:  Server has requested a client certificate.
		Client may choose to examine server's certificate and distinguished
		name list, then optionally call SSLSetCertificate prior to resuming
		the handshake by calling SSLHandshake again.

	FIX ME most codes are not used and would require translation from OpenSSL

** ***************************************************************************/

									// SecureTransport OSStatus return values
enum {
	errSSLProtocol				= -9800,	// SSL protocol error
	errSSLNegotiation			= -9801,	// Cipher Suite negotiation failure
	errSSLFatalAlert			= -9802,	// Fatal alert
	errSSLWouldBlock			= -9803,	// I/O would block (not fatal)
	errSSLSessionNotFound 		= -9804,	// attempt to restore an unknown session
	errSSLClosedGraceful 		= -9805,	// connection closed gracefully
	errSSLClosedAbort 			= -9806,	// connection closed via error
	errSSLXCertChainInvalid 	= -9807,	// invalid certificate chain
	errSSLBadCert				= -9808,	// bad certificate format
	errSSLCrypto				= -9809,	// underlying cryptographic error
	errSSLInternal				= -9810,	// Internal error
	errSSLModuleAttach			= -9811,	// module attach failure
	errSSLUnknownRootCert		= -9812,	// valid cert chain, untrusted root
	errSSLNoRootCert			= -9813,	// cert chain not verified by root
	errSSLCertExpired			= -9814,	// chain had an expired cert
	errSSLCertNotYetValid		= -9815,	// chain had a cert not yet valid
	errSSLClosedNoNotify		= -9816,	// server closed session with no notification
	errSSLBufferOverflow		= -9817,	// insufficient buffer provided
	errSSLBadCipherSuite		= -9818,	// bad SSLCipherSuite

	// fatal errors detected by peer
	errSSLPeerUnexpectedMsg		= -9819,	// unexpected message received
	errSSLPeerBadRecordMac		= -9820,	// bad MAC
	errSSLPeerDecryptionFail	= -9821,	// decryption failed
	errSSLPeerRecordOverflow	= -9822,	// record overflow
	errSSLPeerDecompressFail	= -9823,	// decompression failure
	errSSLPeerHandshakeFail		= -9824,	// handshake failure
	errSSLPeerBadCert			= -9825,	// misc. bad certificate
	errSSLPeerUnsupportedCert	= -9826,	// bad unsupported cert format
	errSSLPeerCertRevoked		= -9827,	// certificate revoked
	errSSLPeerCertExpired		= -9828,	// certificate expired
	errSSLPeerCertUnknown		= -9829,	// unknown certificate
	errSSLIllegalParam			= -9830,	// illegal parameter
	errSSLPeerUnknownCA 		= -9831,	// unknown Cert Authority
	errSSLPeerAccessDenied		= -9832,	// access denied
	errSSLPeerDecodeError		= -9833,	// decoding error
	errSSLPeerDecryptError		= -9834,	// decryption error
	errSSLPeerExportRestriction	= -9835,	// export restriction
	errSSLPeerProtocolVersion	= -9836,	// bad protocol version
	errSSLPeerInsufficientSecurity = -9837,	// insufficient security
	errSSLPeerInternalError		= -9838,	// internal error
	errSSLPeerUserCancelled		= -9839,	// user canceled
	errSSLPeerNoRenegotiation	= -9840,	// no renegotiation allowed

	// non-fatal result codes
	errSSLPeerAuthCompleted     = -9841,    // peer cert is valid or verification disabled
	errSSLClientCertRequested	= -9842,	// server requested a client cert

	// other errors detected
	errSSLHostNameMismatch		= -9843,	// peer host name mismatch
	errSSLConnectionRefused		= -9844,	// peer dropped connection before responding
	errSSLDecryptionFail		= -9845,	// decryption failure
	errSSLBadRecordMac			= -9846,	// bad MAC
	errSSLRecordOverflow		= -9847,	// record overflow
	errSSLBadConfiguration		= -9848,	// configuration error
	errSSLUnexpectedRecord      = -9849,	// unexpected (skipped) record in DTLS
};

/* ****************************************************************************

    Server side  (Not Implemented)


** ***************************************************************************/

OSStatus SSLSetEncryptionCertificate (SSLContextRef cx, CFArrayRef certRefs);

typedef enum {
	kNeverAuthenticate,   // no client auth
	kAlwaysAuthenticate,  // require client auth
	kTryAuthenticate	  // try to auth, not error if client doesn't have cert
} SSLAuthenticate;

OSStatus SSLSetClientSideAuthenticate (SSLContextRef cx, SSLAuthenticate auth);

	// add SecCertificateRef or array of them to server's list of CA
OSStatus SSLSetCertificateAuthorities(SSLContextRef context,
									  CFTypeRef certificateOrArray,
									  BOOL replaceExisting);

/* ****************************************************************************

	SecPolicy

** ***************************************************************************/

extern CFTypeRef  kSecPolicyName;		// name which must be matched
extern CFTypeRef  kSecPolicyClient;		// eval for a client cert


SecPolicyRef SecPolicyCreateSSL(BOOL server, CFStringRef hostname);


#endif  /* _mGSTEP_H_Security */
