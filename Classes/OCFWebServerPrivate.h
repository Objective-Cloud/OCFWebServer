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

#import "OCFWebServerConnection.h"

#ifdef __GCDWEBSERVER_LOGGING_HEADER__

// Define __GCDWEBSERVER_LOGGING_HEADER__ as a preprocessor constant to redirect GCDWebServer logging to your own system
#import __GCDWEBSERVER_LOGGING_HEADER__

#else

static inline void __LogMessage(long level, NSString* format, ...) {
  static const char* levelNames[] = {"DEBUG", "VERBOSE", "INFO", "WARNING", "ERROR", "EXCEPTION"};
  static long minLevel = -1;
  if (minLevel < 0) {
    const char* logLevel = getenv("logLevel");
    minLevel = logLevel ? atoi(logLevel) : 0;
  }
  if (level >= minLevel) {
    va_list arguments;
    va_start(arguments, format);
    NSString* message = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    printf("[%s] %s\n", levelNames[level], [message UTF8String]);
  }
}

#define LOG_VERBOSE(...) __LogMessage(1, __VA_ARGS__)
#define LOG_INFO(...) __LogMessage(2, __VA_ARGS__)
#define LOG_WARNING(...) __LogMessage(3, __VA_ARGS__)
#define LOG_ERROR(...) __LogMessage(4, __VA_ARGS__)
#define LOG_EXCEPTION(__EXCEPTION__) __LogMessage(5, @"%@", __EXCEPTION__)

#ifdef NDEBUG

#define DCHECK(__CONDITION__)
#define DNOT_REACHED()
#define LOG_DEBUG(...)

#else

#define DCHECK(__CONDITION__) \
  do { \
    if (!(__CONDITION__)) { \
      abort(); \
    } \
  } while (0)
#define DNOT_REACHED() abort()
#define LOG_DEBUG(...) __LogMessage(0, __VA_ARGS__)

#endif

#endif

#define kOCFWebServerDefaultMimeType @"application/octet-stream"
#define kOCFWebServerGCDQueue dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)

#ifdef __cplusplus
extern "C" {
#endif

NSString* OCFWebServerGetMimeTypeForExtension(NSString* extension);
NSString* OCFWebServerUnescapeURLString(NSString* string);
NSDictionary* OCFWebServerParseURLEncodedForm(NSString* form);

#ifdef __cplusplus
}
#endif


@interface OCFWebServerConnection ()
- (instancetype)initWithServer:(OCFWebServer *)server address:(NSData *)address socket:(CFSocketNativeHandle)socket;
@end

@interface OCFWebServer ()

#pragma mark - Properties
@property (nonatomic, copy, readonly) NSArray* handlers;
@property (nonatomic, assign, readwrite) NSUInteger maxPendingConnections;
@property (assign, readwrite, setter = setHeaderLoggingEnabled:) BOOL headerLoggingEnabled;

@end

@interface OCFWebServerHandler : NSObject
@property(nonatomic, copy, readonly) OCFWebServerMatchBlock matchBlock;
@property(nonatomic, copy, readonly) OCFWebServerProcessBlock processBlock;
- (id)initWithMatchBlock:(OCFWebServerMatchBlock)matchBlock processBlock:(OCFWebServerProcessBlock)processBlock;
@end
