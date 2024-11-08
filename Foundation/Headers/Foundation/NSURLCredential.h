/*
   NSURLCredential.h

   URL trust establishment classes

   Copyright (C) 2009-2016 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	August 2016

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSURLCredential
#define _mGSTEP_H_NSURLCredential

#include <Foundation/NSObject.h>
#include <CoreFoundation/CoreFoundation.h>
#include <Security/Security.h>


/* ****************************************************************************

	NSURLCredential

** ***************************************************************************/

typedef enum _NSURLCredentialPersistence {
	NSURLCredentialPersistenceNone,
	NSURLCredentialPersistenceForSession,
	NSURLCredentialPersistencePermanent,
	NSURLCredentialPersistenceSynchronizable
} NSURLCredentialPersistence;


@interface NSURLCredential : NSObject  <NSCoding, NSCopying>
{
	NSString *_user;
	NSString *_password;

	SecTrustRef    _trust;
	SecIdentityRef _identity;

	NSArray *_certificates;

	NSURLCredentialPersistence _persistence;
}

- (NSURLCredentialPersistence) persistence;

@end


@interface NSURLCredential (NSInternetPassword)		// create from user/pwd

+ (NSURLCredential *) credentialWithUser:(NSString *)user
								password:(NSString *)password
								persistence:(NSURLCredentialPersistence)pers;

- (id) initWithUser:(NSString *)user
		   password:(NSString *)password
		   persistence:(NSURLCredentialPersistence)persistence;

- (NSString *) user;
- (NSString *) password;		// can be nil if pwd is external and declined

- (BOOL) hasPassword;			// returns YES if user/pwd cred

@end


@interface NSURLCredential (NSClientCertificate)	// create from client certs

+ (NSURLCredential *) credentialWithIdentity:(SecIdentityRef)identity
								certificates:(NSArray *)certs
								persistence:(NSURLCredentialPersistence)pers;

- (id) initWithIdentity:(SecIdentityRef)identity
		   certificates:(NSArray *)certs
		   persistence:(NSURLCredentialPersistence)persistence;

- (NSArray *) certificates;							// Null if UNP credential
- (SecIdentityRef) identity;

@end


@interface NSURLCredential (NSServerTrust)

+ (NSURLCredential *) credentialForTrust:(SecTrustRef)trust;

- (id) initWithTrust:(SecTrustRef)trust;			// init w/accepted Trust

@end

/* ****************************************************************************

	NSURLProtectionSpace  --  bridged to SSLContext, layout must match

	NSURLAuthenticationMethodDefault        : use default auth for protocol
    NSURLAuthenticationMethodNegotiate      : negotiate Kerberos or NTLM auth
	..AuthenticationMethodClientCertificate : Auth with client certificate
	NSURLAuthenticationMethodServerTrust    : Validate server's certificate

** ***************************************************************************/

extern NSString * NSURLAuthenticationMethodDefault;			// auth methods
extern NSString * NSURLAuthenticationMethodHTTPBasic;
extern NSString * NSURLAuthenticationMethodHTTPDigest;
extern NSString * NSURLAuthenticationMethodHTMLForm;
extern NSString * NSURLAuthenticationMethodNTLM;
extern NSString * NSURLAuthenticationMethodNegotiate;
extern NSString * NSURLAuthenticationMethodClientCertificate;
extern NSString * NSURLAuthenticationMethodServerTrust;

extern NSString * const NSURLProtectionSpaceHTTP;			// host protocols
extern NSString * const NSURLProtectionSpaceHTTPS;
extern NSString * const NSURLProtectionSpaceFTP;

extern NSString * const NSURLProtectionSpaceHTTPProxy;		// proxy types
extern NSString * const NSURLProtectionSpaceHTTPSProxy;
extern NSString * const NSURLProtectionSpaceFTPProxy;
extern NSString * const NSURLProtectionSpaceSOCKSProxy;



@interface NSURLProtectionSpace : NSObject  <NSCopying>
{
	void *cf_pointer;

	SecTrustRef _trust;

	NSInteger _port;
	NSString *_host;
	NSString *_protocol;
	NSString *_realm;
	NSString *_proxyType;
	NSString *_authenticationMethod;
	BOOL _receivesCredentialSecurely;
}

- (id) initWithHost:(NSString *)host
			   port:(NSInteger)port
			   protocol:(NSString *)protocol
			   realm:(NSString *)realm
			   authenticationMethod:(NSString *)authMethod;

- (id) initWithProxyHost:(NSString *)host
					port:(NSInteger)port
					type:(NSString *)type
					realm:(NSString *)realm
					authenticationMethod:(NSString *)authMethod;

- (NSString *) host;						// URL host or proxy host
- (NSString *) authenticationMethod;		// auth method to be used
- (NSString *) protocol;					// proto type or nil if proxy
- (NSString *) proxyType;					// type of space, nil if not proxy
- (NSString *) realm;

- (NSInteger) port;							// URL port or proxy port

- (BOOL) isProxy;
- (BOOL) receivesCredentialSecurely;		// is pwd transport secure

@end

/* ****************************************************************************

	NSURLProtectionSpace (ClientCertificateSpace)
	
	Array of acceptable certificate issuing authorities for client cert auth.
	Issuers are identified by their distinguished names returned as DER encoded
	in NSData.  Nil if auth is not NSURLAuthenticationMethodClientCertificate.
	
** ***************************************************************************/

@interface NSURLProtectionSpace (NSClientCertificateSpace)

- (NSArray *) distinguishedNames;

@end

/* ****************************************************************************

	NSURLProtectionSpace (NSServerTrustValidationSpace)
	
	Returned SecTrustRef represents state of server's SSL transaction state.
	Nil if authenticationMethod is not NSURLAuthenticationMethodServerTrust.
	
** ***************************************************************************/

@interface NSURLProtectionSpace (NSServerTrustValidationSpace)

- (SecTrustRef) serverTrust;

@end

#endif  /* _mGSTEP_H_NSURLCredential */
