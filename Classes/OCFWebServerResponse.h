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

@interface OCFWebServerResponse : NSObject

#pragma mark - Properties
@property(nonatomic, copy, readonly) NSString *contentType;
@property(nonatomic, readonly) NSUInteger contentLength;
@property(nonatomic, assign, readwrite) NSInteger statusCode;  // Default is 200
@property(nonatomic) NSUInteger cacheControlMaxAge;  // Default is 0 seconds i.e. "no-cache"
@property(nonatomic, readonly, copy) NSDictionary *additionalHeaders;
@property (nonatomic, copy) NSDictionary *userInfo;

#pragma mark - Creating
+ (instancetype)response;
- (instancetype)init;
- (instancetype)initWithContentType:(NSString*)type contentLength:(NSUInteger)length;  // Pass nil contentType to indicate empty body

#pragma mark - Working with the Response
- (void)setValue:(NSString*)value forAdditionalHeader:(NSString*)header;
- (BOOL)hasBody;  // Convenience method
@end

@interface OCFWebServerResponse (Subclassing)
- (BOOL)open;  // Implementation required
- (NSInteger)read:(void *)buffer maxLength:(NSUInteger)length;  // Implementation required
- (BOOL)close;  // Implementation required
@end

@interface OCFWebServerResponse (Extensions)

#pragma mark - Creating
+ (instancetype)responseWithStatusCode:(NSInteger)statusCode;
+ (instancetype)responseWithRedirect:(NSURL*)location permanent:(BOOL)permanent;
- (instancetype)initWithStatusCode:(NSInteger)statusCode;
- (instancetype)initWithRedirect:(NSURL*)location permanent:(BOOL)permanent;

@end

@interface OCFWebServerDataResponse : OCFWebServerResponse
@property (nonatomic, copy) NSData *data;

#pragma mark - Creating
+ (instancetype)responseWithData:(NSData*)data contentType:(NSString*)type;
- (instancetype)initWithData:(NSData*)data contentType:(NSString*)type;

@end

@interface OCFWebServerDataResponse (Extensions)

#pragma mark - Creating
+ (instancetype)responseWithText:(NSString*)text;
+ (instancetype)responseWithHTML:(NSString*)html;
+ (instancetype)responseWithHTMLTemplate:(NSString*)path variables:(NSDictionary*)variables;
- (instancetype)initWithText:(NSString*)text;  // Encodes using UTF-8
- (instancetype)initWithHTML:(NSString*)html;  // Encodes using UTF-8
- (instancetype)initWithHTMLTemplate:(NSString*)path variables:(NSDictionary*)variables;  // Simple template system that replaces all occurences of "%variable%" with corresponding value (encodes using UTF-8)

@end

@interface OCFWebServerFileResponse : OCFWebServerResponse

#pragma mark - Creating
+ (instancetype)responseWithFile:(NSString*)path;
+ (instancetype)responseWithFile:(NSString*)path isAttachment:(BOOL)attachment;
- (instancetype)initWithFile:(NSString*)path;
- (instancetype)initWithFile:(NSString*)path isAttachment:(BOOL)attachment;
@end
