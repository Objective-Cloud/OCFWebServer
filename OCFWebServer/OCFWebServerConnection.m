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

#import "OCFWebServerPrivate.h"
#import "OCFWebServerRequest.h"
#import "OCFWebServerResponse.h"

#define kHeadersReadBuffer 1024
#define kBodyWriteBufferSize (32 * 1024)

typedef void (^ReadBufferCompletionBlock)(dispatch_data_t buffer);
typedef void (^ReadDataCompletionBlock)(NSData* data);
typedef void (^ReadHeadersCompletionBlock)(NSData* extraData);
typedef void (^ReadBodyCompletionBlock)(BOOL success);

typedef void (^WriteBufferCompletionBlock)(BOOL success);
typedef void (^WriteDataCompletionBlock)(BOOL success);
typedef void (^WriteHeadersCompletionBlock)(BOOL success);
typedef void (^WriteBodyCompletionBlock)(BOOL success);

static NSData* _separatorData = nil;
static NSData* _continueData = nil;
static NSDateFormatter* _dateFormatter = nil;
static dispatch_queue_t _formatterQueue = NULL;

@interface OCFWebServerConnection ()

#pragma mark - Properties
@property (nonatomic, weak, readwrite) OCFWebServer* server;
@property (nonatomic, copy, readwrite) NSData *address;  // struct sockaddr
@property (nonatomic, readwrite) NSUInteger totalBytesRead;
@property (nonatomic, readwrite) NSUInteger totalBytesWritten;
@property (nonatomic, assign) CFSocketNativeHandle socket;
@property (nonatomic, assign) CFHTTPMessageRef requestMessage;
@property (nonatomic, strong) OCFWebServerRequest *request;
@property (nonatomic, strong) OCFWebServerHandler *handler;
@property (nonatomic, assign) CFHTTPMessageRef responseMessage;
@property (nonatomic, strong) OCFWebServerResponse *response;
@property (nonatomic, copy) OCFWebServerConnectionCompletionHandler completionHandler;

@end

@implementation OCFWebServerConnection (Read)

- (void)_readBufferWithLength:(NSUInteger)length completionBlock:(ReadBufferCompletionBlock)block {
  dispatch_read(self.socket, length, kOCFWebServerGCDQueue, ^(dispatch_data_t buffer, int error) {
    @autoreleasepool {
      if (error == 0) {
        size_t size = dispatch_data_get_size(buffer);
        if (size > 0) {
          LOG_DEBUG(@"Connection received %i bytes on socket %i", size, self.socket);
          self.totalBytesRead = self.totalBytesRead + size;
          block(buffer);
        } else {
          if (self.totalBytesRead > 0) {
            LOG_ERROR(@"No more data available on socket %i", self.socket);
          } else {
            LOG_WARNING(@"No data received from socket %i", self.socket);
          }
          block(NULL);
        }
      } else {
        LOG_ERROR(@"Error while reading from socket %i: %s (%i)", self.socket, strerror(error), error);
        block(NULL);
      }
    }
  });
}

- (void)_readDataWithCompletionBlock:(ReadDataCompletionBlock)block {
  [self _readBufferWithLength:SIZE_T_MAX completionBlock:^(dispatch_data_t buffer) {
    if(buffer) {
      NSMutableData* data = [[NSMutableData alloc] initWithCapacity:dispatch_data_get_size(buffer)];
      dispatch_data_apply(buffer, ^bool(dispatch_data_t region, size_t offset, const void* buffer, size_t size) {
        [data appendBytes:buffer length:size];
        return true;
      });
      block(data);
    } else {
      block(nil);
    }
  }];
}

- (void)_readHeadersWithCompletionBlock:(ReadHeadersCompletionBlock)block {
  DCHECK(self.requestMessage);
  [self _readBufferWithLength:SIZE_T_MAX completionBlock:^(dispatch_data_t buffer) {
    if(buffer) {
      NSMutableData* data = [NSMutableData dataWithCapacity:kHeadersReadBuffer];
      dispatch_data_apply(buffer, ^bool(dispatch_data_t region, size_t offset, const void* buffer, size_t size) {
        [data appendBytes:buffer length:size];
        return true;
      });
      NSRange range = [data rangeOfData:_separatorData options:0 range:NSMakeRange(0, data.length)];
      if (range.location == NSNotFound) {
        if (CFHTTPMessageAppendBytes(self.requestMessage, data.bytes, data.length)) {
          [self _readHeadersWithCompletionBlock:block];
        } else {
          LOG_ERROR(@"Failed appending request headers data from socket %i", self.socket);
          block(nil);
        }
      } else {
        NSUInteger length = range.location + range.length;
        if (CFHTTPMessageAppendBytes(self.requestMessage, data.bytes, length)) {
          if (CFHTTPMessageIsHeaderComplete(self.requestMessage)) {
            block([data subdataWithRange:NSMakeRange(length, data.length - length)]);
          } else {
            LOG_ERROR(@"Failed parsing request headers from socket %i", self.socket);
            block(nil);
          }
        } else {
          LOG_ERROR(@"Failed appending request headers data from socket %i", self.socket);
          block(nil);
        }
      }
    } else {
      block(nil);
    }
  }];
}

- (void)_readBodyWithRemainingLength:(NSUInteger)length completionBlock:(ReadBodyCompletionBlock)block {
  DCHECK([self.request hasBody]);
  [self _readBufferWithLength:length completionBlock:^(dispatch_data_t buffer) {
    
    if (buffer) {
      NSInteger remainingLength = length - dispatch_data_get_size(buffer);
      if (remainingLength >= 0) {
        bool success = dispatch_data_apply(buffer, ^bool(dispatch_data_t region, size_t offset, const void* buffer, size_t size) {
          NSInteger result = [self.request write:buffer maxLength:size];
          if (result != size) {
            LOG_ERROR(@"Failed writing request body on socket %i (error %i)", self.socket, (int)result);
            return false;
          }
          return true;
        });
        if (success) {
          if (remainingLength > 0) {
            [self _readBodyWithRemainingLength:remainingLength completionBlock:block];
          } else {
            block(YES);
          }
        } else {
          block(NO);
        }
      } else {
        DNOT_REACHED();
        block(NO);
      }
    } else {
      block(NO);
    }
    
  }];
}

@end

@implementation OCFWebServerConnection (Write)

- (void)_writeBuffer:(dispatch_data_t)buffer withCompletionBlock:(WriteBufferCompletionBlock)block {
  size_t size = dispatch_data_get_size(buffer);
  dispatch_write(self.socket, buffer, kOCFWebServerGCDQueue, ^(dispatch_data_t data, int error) {
    @autoreleasepool {
      if (error == 0) {
        DCHECK(data == NULL);
        LOG_DEBUG(@"Connection sent %i bytes on socket %i", size, self.socket);
        self.totalBytesWritten = self.totalBytesWritten + size;
        block(YES);
      } else {
        LOG_ERROR(@"Error while writing to socket %i: %s (%i)", self.socket, strerror(error), error);
        block(NO);
      }
    }
  });
}

- (void)_writeData:(NSData *)data withCompletionBlock:(WriteDataCompletionBlock)block {
  // Remarks by Christian:
  // data is either the serialized HTTP header or the serialized "continue" delimiter (\n\n).
  // If data is the serialized HTTP header then ARC wants to release this value at some point.
  // If we are not using data before the end of this scope ARC will release data.
  // Then data.bytes will become invalid and buffer will work with garbage.
  // We could work around this problem by having the serialized header as a ivar.
  // I have decided to not do that. Instead I am simply passing DISPATCH_DATA_DESTRUCTOR_DEFAULT as
  // the destructor block which causes dispatch_data_create to copy data.bytes immediately.
  // This is not so bad because data is usually very small (a header or HTTP continue).
  
  dispatch_data_t buffer = dispatch_data_create(data.bytes, data.length, kOCFWebServerGCDQueue, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
  [self _writeBuffer:buffer withCompletionBlock:block];
}

- (void)_writeHeadersWithCompletionBlock:(WriteHeadersCompletionBlock)block {
  DCHECK(self.responseMessage);
  CFDataRef message = CFHTTPMessageCopySerializedMessage(self.responseMessage);
  NSData *data = (__bridge_transfer NSData *)message;
  [self _writeData:data withCompletionBlock:block];
}

- (void)_writeBodyWithCompletionBlock:(WriteBodyCompletionBlock)block {
  DCHECK([self.response hasBody]);
  void *buffer = malloc(kBodyWriteBufferSize);
  NSInteger result = [self.response read:buffer maxLength:kBodyWriteBufferSize];
  if (result > 0) {
    dispatch_data_t wrapper = dispatch_data_create(buffer, result, kOCFWebServerGCDQueue, ^(){
      free(buffer);
    });
    [self _writeBuffer:wrapper withCompletionBlock:^(BOOL success) {
      if (success) {
        [self _writeBodyWithCompletionBlock:block];
      } else {
        block(NO);
      }
    }];
  } else if (result < 0) {
    LOG_ERROR(@"Failed reading response body on socket %i (error %i)", self.socket, (int)result);
    block(NO);
    free(buffer);
  } else {
    block(YES);
    free(buffer);
  }
}

@end

@implementation OCFWebServerConnection

+ (void)initialize {
  DCHECK([NSThread isMainThread]);  // NSDateFormatter should be initialized on main thread
  if (_separatorData == nil) {
    _separatorData = [[NSData alloc] initWithBytes:"\r\n\r\n" length:4];
    DCHECK(_separatorData);
  }
  if (_continueData == nil) {
    CFHTTPMessageRef message = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 100, NULL, kCFHTTPVersion1_1);
    _continueData = (NSData*)CFBridgingRelease(CFHTTPMessageCopySerializedMessage(message));
    CFRelease(message);
    DCHECK(_continueData);
  }
  if (_dateFormatter == nil) {
    _dateFormatter = [[NSDateFormatter alloc] init];
    _dateFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
    _dateFormatter.dateFormat = @"EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'";
    _dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    DCHECK(_dateFormatter);
  }
  if (_formatterQueue == NULL) {
    _formatterQueue = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL);
    DCHECK(_formatterQueue);
  }
}

- (void)_initializeResponseHeadersWithStatusCode:(NSInteger)statusCode {
  self.responseMessage = CFHTTPMessageCreateResponse(kCFAllocatorDefault, statusCode, NULL, kCFHTTPVersion1_1);
  CFHTTPMessageSetHeaderFieldValue(self.responseMessage, CFSTR("Connection"), CFSTR("Close"));
  CFHTTPMessageSetHeaderFieldValue(self.responseMessage, CFSTR("Server"), (__bridge CFStringRef)[[self.server class] serverName]);
  dispatch_sync(_formatterQueue, ^{
    NSString* date = [_dateFormatter stringFromDate:[NSDate date]];
    CFStringRef cfDate = (CFStringRef)CFBridgingRetain(date);
    CFHTTPMessageSetHeaderFieldValue(self.responseMessage, CFSTR("Date"), cfDate);
    CFRelease(cfDate);
  });
}

- (void)_abortWithStatusCode:(NSUInteger)statusCode {
  DCHECK(self.responseMessage == NULL);
  DCHECK((statusCode >= 400) && (statusCode < 600));
  [self _initializeResponseHeadersWithStatusCode:statusCode];
  [self _writeHeadersWithCompletionBlock:^(BOOL success) {
    [self close];
  }];
  LOG_DEBUG(@"Connection aborted with status code %i on socket %i", statusCode, self.socket);
}

// http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html
// This method is already called on the dispatch queue of the web server so there is no need to dispatch again.
- (void)_processRequest {
  DCHECK(self.responseMessage == NULL);
  @try {
    __typeof__(self) __weak weakSelf = self;
    self.request.responseBlock = ^(OCFWebServerResponse *response) {
      if (![response hasBody] || [response open]) {
        weakSelf.response = response;
      }
      if (weakSelf.response) {
        [weakSelf _initializeResponseHeadersWithStatusCode:weakSelf.response.statusCode];
        NSUInteger maxAge = weakSelf.response.cacheControlMaxAge;
        if (maxAge > 0) {
          CFHTTPMessageSetHeaderFieldValue(weakSelf.responseMessage, CFSTR("Cache-Control"), (__bridge CFStringRef)[NSString stringWithFormat:@"max-age=%i, public", (int)maxAge]);
        } else {
          CFHTTPMessageSetHeaderFieldValue(weakSelf.responseMessage, CFSTR("Cache-Control"), CFSTR("no-cache"));
        }
        [weakSelf.response.additionalHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL* stop) {
          CFHTTPMessageSetHeaderFieldValue(weakSelf.responseMessage, (__bridge CFStringRef)(key), (__bridge CFStringRef)(obj));
        }];
        
        if ([weakSelf.response hasBody]) {
          CFHTTPMessageSetHeaderFieldValue(weakSelf.responseMessage, CFSTR("Content-Type"), (__bridge CFStringRef)weakSelf.response.contentType);
          CFHTTPMessageSetHeaderFieldValue(weakSelf.responseMessage, CFSTR("Content-Length"), (__bridge CFStringRef)[NSString stringWithFormat:@"%i", (int)weakSelf.response.contentLength]);
        }
        [weakSelf _writeHeadersWithCompletionBlock:^(BOOL success) {
          if (success) {
            if ([weakSelf.response hasBody]) {
              [weakSelf _writeBodyWithCompletionBlock:^(BOOL success) {
                [weakSelf.response close];  // Can't do anything with result anyway
                [weakSelf close];
              }];
            }
          } else if ([weakSelf.response hasBody]) {
            [weakSelf.response close];  // Can't do anything with result anyway
            [weakSelf close];
          }
        }];
      } else {
        [weakSelf _abortWithStatusCode:500];
      }
    };
    self.handler.processBlock(self.request);
  }
  @catch (NSException* exception) {
    LOG_EXCEPTION(exception);
    [self _abortWithStatusCode:500];
  }
  @finally {
    
  }
}

- (void)_readRequestBody:(NSData*)initialData {
  if ([self.request open]) {
    NSInteger length = self.request.contentLength;
    if (initialData.length) {
      NSInteger result = [self.request write:initialData.bytes maxLength:initialData.length];
      if (result == initialData.length) {
        length -= initialData.length;
        DCHECK(length >= 0);
      } else {
        LOG_ERROR(@"Failed writing request body on socket %i (error %i)", self.socket, (int)result);
        length = -1;
      }
    }
    if (length > 0) {
      [self _readBodyWithRemainingLength:length completionBlock:^(BOOL success) {
        
        if (![self.request close]) {
          success = NO;
        }
        if (success) {
          [self _processRequest];
        } else {
          [self _abortWithStatusCode:500];
        }
        
      }];
    } else if (length == 0) {
      if ([self.request close]) {
        [self _processRequest];
      } else {
        [self _abortWithStatusCode:500];
      }
    } else {
      [self.request close];  // Can't do anything with result anyway
      [self _abortWithStatusCode:500];
    }
  } else {
    [self _abortWithStatusCode:500];
  }
}

- (void)_readRequestHeaders {
  self.requestMessage = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, true);
  [self _readHeadersWithCompletionBlock:^(NSData* extraData) {
    if (extraData) {
      NSString* requestMethod = [(id)CFBridgingRelease(CFHTTPMessageCopyRequestMethod(self.requestMessage)) uppercaseString];
      DCHECK(requestMethod);
      NSURL* requestURL = (id)CFBridgingRelease(CFHTTPMessageCopyRequestURL(self.requestMessage));
      DCHECK(requestURL);
      NSString* requestPath = OCFWebServerUnescapeURLString((id)CFBridgingRelease(CFURLCopyPath((CFURLRef)requestURL)));  // Don't use -[NSURL path] which strips the ending slash
      DCHECK(requestPath);
      NSDictionary* requestQuery = nil;
      NSString* queryString = (id)CFBridgingRelease(CFURLCopyQueryString((CFURLRef)requestURL, NULL));  // Don't use -[NSURL query] to make sure query is not unescaped;
      if (queryString.length) {
        requestQuery = OCFWebServerParseURLEncodedForm(queryString);
        DCHECK(requestQuery);
      }
      NSDictionary* requestHeaders = (id)CFBridgingRelease(CFHTTPMessageCopyAllHeaderFields(self.requestMessage));
      DCHECK(requestHeaders);
      for (OCFWebServerHandler *handler in self.server.handlers) {
        self.request = handler.matchBlock(requestMethod, requestURL, requestHeaders, requestPath, requestQuery);
        if (self.request) {
          self.handler = handler;
          break;
        }
      }
      if (self.request) {
        if (self.request.hasBody) {
          if (extraData.length <= self.request.contentLength) {
            NSString* expectHeader = (id)CFBridgingRelease(CFHTTPMessageCopyHeaderFieldValue(self.requestMessage, CFSTR("Expect")));
            if (expectHeader) {
              if ([expectHeader caseInsensitiveCompare:@"100-continue"] == NSOrderedSame) {
                [self _writeData:_continueData withCompletionBlock:^(BOOL success) {
                  if (success) {
                    [self _readRequestBody:extraData];
                  }
                }];
              } else {
                LOG_ERROR(@"Unsupported 'Expect' / 'Content-Length' header combination on socket %i", self.socket);
                [self _abortWithStatusCode:417];
              }
            } else {
              [self _readRequestBody:extraData];
            }
          } else {
            LOG_ERROR(@"Unexpected 'Content-Length' header value on socket %i", self.socket);
            [self _abortWithStatusCode:400];
          }
        } else {
          [self _processRequest];
        }
      } else {
        [self _abortWithStatusCode:405];
      }
    } else {
      [self _abortWithStatusCode:500];
    }
  }];
}

- (instancetype)initWithServer:(OCFWebServer *)server address:(NSData *)address socket:(CFSocketNativeHandle)socket {
  if((self = [super init])) {
    self.totalBytesRead = 0;
    self.totalBytesWritten = 0;
    self.server = server;
    self.address = address;
    self.socket = socket;
  }
  return self;
}

- (void)dealloc {
  if(self.requestMessage) {
    CFRelease(self.requestMessage);
  }
  if(self.responseMessage) {
    CFRelease(self.responseMessage);
  }
}

@end

@implementation OCFWebServerConnection (Subclassing)

- (void)openWithCompletionHandler:(OCFWebServerConnectionCompletionHandler)completionHandler {
  LOG_DEBUG(@"Did open connection on socket %i", self.socket);
  self.completionHandler = completionHandler;
  [self _readRequestHeaders];
}

- (void)close {
  int result = close(self.socket);
  if (result != 0) {
    LOG_ERROR(@"Failed closing socket %i for connection (%i): %s", self.socket, errno, strerror(errno));
  }
  LOG_DEBUG(@"Did close connection on socket %i", self.socket);
  self.completionHandler ? self.completionHandler() : nil;
}

@end
