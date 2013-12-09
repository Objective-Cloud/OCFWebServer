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

#import "OCFWebServerRequest_Types.h"

@class OCFWebServerRequest;

typedef OCFWebServerRequest*(^OCFWebServerMatchBlock)(NSString* requestMethod, NSURL* requestURL, NSDictionary* requestHeaders, NSString* urlPath, NSDictionary* urlQuery);
typedef void(^OCFWebServerProcessBlock)(OCFWebServerRequest* request);

@interface OCFWebServer : NSObject

#pragma mark - Properties
@property (nonatomic, assign, readonly, getter=isRunning) BOOL running;
@property (nonatomic, assign, readonly) NSUInteger port;
@property (nonatomic, assign, readonly) NSUInteger maxPendingConnections; // default: 16

#pragma mark - OCFWebServer
- (void)addHandlerWithMatchBlock:(OCFWebServerMatchBlock)matchBlock processBlock:(OCFWebServerProcessBlock)processBlock;
- (void)removeAllHandlers;

- (BOOL)start;  // Default is 8080 port and computer name
- (BOOL)startWithPort:(NSUInteger)port bonjourName:(NSString*)name;  // Pass nil name to disable Bonjour or empty string to use computer name
- (BOOL)startWithPort:(NSUInteger)port bonjourName:(NSString*)name maxPendingConnections:(NSUInteger)maxPendingConnections;
- (void)stop;

@end

@interface OCFWebServer (Subclassing)
+ (Class)connectionClass;
+ (NSString*)serverName;  // Default is class name
@end

@interface OCFWebServer (Extensions)
- (BOOL)runWithPort:(NSUInteger)port;  // Starts then automatically stops on SIGINT i.e. Ctrl-C (use on main thread only)
@end

@interface OCFWebServer (Handlers)
- (void)addDefaultHandlerForMethod:(NSString*)method requestClass:(Class)class processBlock:(OCFWebServerProcessBlock)block;
- (void)addHandlerForBasePath:(NSString*)basePath localPath:(NSString*)localPath indexFilename:(NSString*)indexFilename cacheAge:(NSUInteger)cacheAge;  // Base path is recursive and case-sensitive
- (void)addHandlerForMethod:(NSString*)method path:(NSString*)path requestClass:(Class)class processBlock:(OCFWebServerProcessBlock)block;  // Path is case-insensitive
- (void)addHandlerForMethod:(NSString*)method pathRegex:(NSString*)regex requestClass:(Class)class processBlock:(OCFWebServerProcessBlock)block;  // Regular expression is case-insensitive
@end
