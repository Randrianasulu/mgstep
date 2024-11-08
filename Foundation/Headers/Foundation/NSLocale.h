/*
   NSLocale.h

   Cultural conventions class  (formats, currency, keyboard, ...)

   Copyright (C) 2016-2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	May 2016

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSLocale
#define _mGSTEP_H_NSLocale

#include <Foundation/NSObject.h>

@class NSArray;
@class NSDictionary;
@class NSMutableDictionary;


@interface NSLocale : NSObject  <NSCopying, NSCoding>
{
    NSString *_identifier;
    NSDictionary *_cache;
    NSMutableDictionary *_overrides;
}

+ (id) localeWithLocaleIdentifier:(NSString *)string;

- (id) objectForKey:(id)key;

@end


@interface NSLocale  (NSLocaleCreation)

+ (id) currentLocale;
+ (id) systemLocale;

- (id) initWithLocaleIdentifier:(NSString *)string;

@end


@interface NSLocale  (NSLocaleGeneralInfo)

+ (NSArray *) availableLocaleIdentifiers;
+ (NSDictionary *) componentsFromLocaleIdentifier:(NSString *)string;

- (NSString *) localeIdentifier;

@end


@interface NSLocale  (NotImplemented)

+ (NSString *) localeIdentifierFromComponents:(NSDictionary *)dictionary;

+ (id) autoupdatingCurrentLocale;

+ (NSArray *) ISOLanguageCodes;
+ (NSArray *) ISOCountryCodes;
+ (NSArray *) ISOCurrencyCodes;
+ (NSArray *) commonISOCurrencyCodes;
+ (NSArray *) preferredLanguages;

- (NSString *) displayNameForKey:(id)key value:(id)value;

@end


extern NSString * const NSCurrentLocaleDidChangeNotification;

extern NSString * const NSLocaleIdentifier;            // NSString
extern NSString * const NSLocaleLanguageCode;
extern NSString * const NSLocaleCountryCode;
extern NSString * const NSLocaleScriptCode;
extern NSString * const NSLocaleVariantCode;
extern NSString * const NSLocaleCollationIdentifier;
extern NSString * const NSLocaleMeasurementSystem;
extern NSString * const NSLocaleDecimalSeparator;
extern NSString * const NSLocaleGroupingSeparator;
extern NSString * const NSLocaleCurrencySymbol;
extern NSString * const NSLocaleCurrencyCode;
extern NSString * const NSLocaleCollatorIdentifier;
extern NSString * const NSLocaleQuotationBeginDelimiterKey;
extern NSString * const NSLocaleQuotationEndDelimiterKey;

extern NSString * const NSLocaleExemplarCharacterSet; // NSCharacterSet
extern NSString * const NSLocaleCalendar;			  // NSCalendar
extern NSString * const NSLocaleUsesMetricSystem;	  // NSNumber Bool


#endif  /* _mGSTEP_H_NSLocale */
