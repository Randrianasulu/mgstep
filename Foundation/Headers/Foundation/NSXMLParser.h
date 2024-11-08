/*
   NSXMLParser.h

   XML Parser

   Copyright (c) 2004 DSITRI.
   
   Author:  Dr. H. Nikolaus Schaller
   Date:	Oct 05 2004

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef mySTEP_NSXMLPARSER_H
#define mySTEP_NSXMLPARSER_H

#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>

@class NSMutableArray;
@class NSError;
@class NSURL;


extern NSString *const NSXMLParserErrorDomain;

typedef enum _NSXMLParserError
{
	NSXMLParserInternalError              = 1,
    NSXMLParserParsedEntityRefNoNameError = 24,
    NSXMLParserAttributeNotStartedError   = 39,
    NSXMLParserAttributeHasNoValueError   = 41,
    NSXMLParserLTRequiredError            = 72,
    NSXMLParserGTRequiredError            = 73,
    NSXMLParserNotWellBalancedError       = 85,
    NSXMLParserEntityBoundaryError        = 90,
	NSXMLParserDelegateAbortedParseError  = 512
} NSXMLParserError;

// private extension

typedef enum _NSXMLParserReadMode
{
	_NSXMLParserStandardReadMode,	// decode embedded tags
	_NSXMLParserPlainReadMode,		// read characters (even entities) as they are until we find a closing tag: e.g. <script>...</script>
	_NSXMLParserEntityOnlyReadMode,	// read characters until we find a matching closing tag but still translate entities: e.g. <pre>...</pre>
} _NSXMLParserReadMode;


@interface NSString (NSXMLParser)
- (NSString *) _stringByExpandingXMLEntities;
@end


@interface NSXMLParser : NSObject
{
	id delegate;					// the current delegate (not retained)
	NSMutableArray *tagPath;		// hierarchy of tags
	NSError *error;					// will also abort parsing process
	NSData *data;					// if initialized with initWithData:
	NSURL *url;						// if initialized with initWithContentsOfURL:
	NSData *buffer;					// buffer
	const char *cp;					// pointer into current buffer
	int line;						// current line (counts from 0)
	int column;						// current column (counts from 0)
	NSStringEncoding encoding;		// current read mode
	_NSXMLParserReadMode readMode;
	BOOL isStalled;					// queue up incoming NSData and don't call delegate methods
	BOOL done;						// done with incremental input
	BOOL shouldProcessNamespaces;
	BOOL shouldReportNamespacePrefixes;
	BOOL shouldResolveExternalEntities;
	BOOL acceptHTML;				// be lazy with bad tag nesting and be not case sensitive
}

- (void) abortParsing;
- (int) columnNumber;
- (id) delegate;
- (id) initWithContentsOfURL:(NSURL *) url;
- (id) initWithData:(NSData *) str;
- (int) lineNumber;
- (BOOL) parse;
- (NSError *) parserError;
- (NSString *) publicID;
- (void) setDelegate:(id) del;
- (void) setShouldProcessNamespaces:(BOOL) flag;
- (void) setShouldReportNamespacePrefixes:(BOOL) flag;
- (void) setShouldResolveExternalEntities:(BOOL) flag;
- (BOOL) shouldProcessNamespaces;
- (BOOL) shouldReportNamespacePrefixes;
- (BOOL) shouldResolveExternalEntities;
- (NSString *) systemID;

@end


@interface NSObject (NSXMLParserDelegate)

- (void) parser:(NSXMLParser *) parser didEndElement:(NSString *) tag namespaceURI:(NSString *) URI qualifiedName:(NSString *) name;
- (void) parser:(NSXMLParser *) parser didEndMappingPrefix:(NSString *) prefix;
- (void) parser:(NSXMLParser *) parser didStartElement:(NSString *) tag namespaceURI:(NSString *) URI qualifiedName:(NSString *) name attributes:(NSDictionary *) attributes;
- (void) parser:(NSXMLParser *) parser didStartMappingPrefix:(NSString *)prefix toURI:(NSString *) URI;
- (void) parser:(NSXMLParser *) parser foundAttributeDeclarationWithName:(NSString *) name forElement:(NSString *) element type:(NSString *) type defaultValue:(NSString *) val;
- (void) parser:(NSXMLParser *) parser foundCDATA:(NSData *) CDATABlock;
- (void) parser:(NSXMLParser *) parser foundCharacters:(NSString *) string;
- (void) parser:(NSXMLParser *) parser foundComment:(NSString *) comment;
- (void) parser:(NSXMLParser *) parser foundElementDeclarationWithName:(NSString *) element model:(NSString *) model;
- (void) parser:(NSXMLParser *) parser foundExternalEntityDeclarationWithName:(NSString *) entity publicID:(NSString *) pub systemID:(NSString *) sys;
- (void) parser:(NSXMLParser *) parser foundIgnorableWhitespace:(NSString *) whitespaceString;
- (void) parser:(NSXMLParser *) parser foundInternalEntityDeclarationWithName:(NSString *) name value:(NSString *) val;
- (void) parser:(NSXMLParser *) parser foundNotationDeclarationWithName:(NSString *) name publicID:(NSString *) pub systemID:(NSString *) sys;
- (void) parser:(NSXMLParser *) parser foundProcessingInstructionWithTarget:(NSString *) target data:(NSString *) data;
- (void) parser:(NSXMLParser *) parser foundUnparsedEntityDeclarationWithName:(NSString *) name publicID:(NSString *) pub systemID:(NSString *) sys notationName:(NSString *) notation;
- (void) parser:(NSXMLParser *) parser parseErrorOccurred:(NSError *) parseError;
- (NSData *) parser:(NSXMLParser *) parser resolveExternalEntityName:(NSString *) entity systemID:(NSString *) sys;
- (void) parser:(NSXMLParser *) parser validationErrorOccurred:(NSError *) error;
- (void) parserDidEndDocument:(NSXMLParser *) parser;
- (void) parserDidStartDocument:(NSXMLParser *) parser;

@end

#endif /* mySTEP_NSXMLPARSER_H */
