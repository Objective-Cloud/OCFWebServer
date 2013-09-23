/*
 This file belongs to the OCFWebServer project. OCFWebServer is a fork of GCDWebServer (originally developed by
 Pierre-Olivier Latour). We have forked GCDWebServer because we made extensive and incompatible changes to it.
 To find out more have a look at README.md.
 
 Copyright (c) 2013, Christian Kienle / chris@objective-cloud.com
 All rights reserved.
 
 Original Copyright Statement:
 Copyright (c) 2012-2013, Pierre-Olivier Latour
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * Neither the name of the <organization> nor the
 names of its contributors may be used to endorse or promote products
 derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>
#import "OCFWebServerRequest_Types.h"

@class OCFWebServerResponse;

@interface OCFWebServerRequest : NSObject

#pragma mark - Properties
@property(nonatomic, copy, readonly) NSString *method;
@property(nonatomic, copy, readonly) NSURL *URL;
@property(nonatomic, copy, readonly) NSDictionary *headers;
@property(nonatomic, copy, readonly) NSString *path;
@property(nonatomic, copy, readonly) NSDictionary *query;  // May be nil
@property(nonatomic, copy, readonly) NSString *contentType;  // Automatically parsed from headers (nil if request has no body)
@property(nonatomic, readonly) NSUInteger contentLength;  // Automatically parsed from headers

#pragma mark - Creating
- (instancetype)initWithMethod:(NSString *)method URL:(NSURL *)url headers:(NSDictionary *)headers path:(NSString *)path query:(NSDictionary *)query;
- (BOOL)hasBody;  // Convenience method

#pragma mark - Responding
- (void)respondWith:(OCFWebServerResponse *)response;
@property (nonatomic, copy) OCFWebServerResponseBlock responseBlock;

@end

@interface OCFWebServerRequest (Subclassing)
- (BOOL)open;  // Implementation required
- (NSInteger)write:(const void*)buffer maxLength:(NSUInteger)length;  // Implementation required
- (BOOL)close;  // Implementation required
@end

@interface OCFWebServerDataRequest : OCFWebServerRequest

#pragma mark - Properties
@property(nonatomic, copy, readonly) NSData *data;  // Only valid after open / write / close sequence

@end

@interface OCFWebServerFileRequest : OCFWebServerRequest

#pragma mark - Properties
@property(nonatomic, copy, readonly) NSString *filePath;  // Only valid after open / write / close sequence

@end

@interface OCFWebServerURLEncodedFormRequest : OCFWebServerDataRequest

#pragma mark - Properties
@property(nonatomic, copy, readonly) NSDictionary* arguments;  // Only valid after open / write / close sequence

#pragma mark - Global Stuff
+ (NSString *)mimeType;

@end

@interface OCFWebServerMultiPart : NSObject

#pragma mark - Properties
@property(nonatomic, copy, readonly) NSString *contentType;  // May be nil
@property(nonatomic, copy, readonly) NSString *mimeType;  // Defaults to "text/plain" per specifications if undefined
@end

@interface OCFWebServerMultiPartArgument : OCFWebServerMultiPart

#pragma mark - Properties
@property(nonatomic, copy, readonly) NSData *data;
@property(nonatomic, copy, readonly) NSString *string;  // May be nil (only valid for text mime types

@end

@interface OCFWebServerMultiPartFile : OCFWebServerMultiPart

#pragma mark - Properties
@property(nonatomic, copy, readonly) NSString *fileName;  // May be nil
@property(nonatomic, copy, readonly) NSString *temporaryPath;

@end

@interface OCFWebServerMultiPartFormRequest : OCFWebServerRequest

#pragma mark - Properties
@property (nonatomic, copy, readonly) NSData *data;  // Only valid after open / write / close sequence
@property (nonatomic, copy, readonly) NSDictionary *arguments;  // Only valid after open / write / close sequence
@property (nonatomic, copy, readonly) NSDictionary *files;  // Only valid after open / write / close sequence

#pragma mark - Global Stuff
+ (NSString *)mimeType;

@end
