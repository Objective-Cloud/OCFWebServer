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

#define kMultiPartBufferSize (256 * 1024)

typedef NS_ENUM(NSUInteger, OCFWebServerParserState) {
  OCFWebServerParserStateUndefined,
  OCFWebServerParserStateStart,
  OCFWebServerParserStateHeaders,
  OCFWebServerParserStateContent,
  OCFWebServerParserStateEnd
};

static NSData* _newlineData = nil;
static NSData* _newlinesData = nil;
static NSData* _dashNewlineData = nil;

static NSString* _ExtractHeaderParameter(NSString* header, NSString* attribute) {
  NSString* value = nil;
  if (header) {
    NSScanner* scanner = [[NSScanner alloc] initWithString:header];
    NSString* string = [NSString stringWithFormat:@"%@=", attribute];
    if ([scanner scanUpToString:string intoString:NULL]) {
      [scanner scanString:string intoString:NULL];
      if ([scanner scanString:@"\"" intoString:NULL]) {
        [scanner scanUpToString:@"\"" intoString:&value];
      } else {
        [scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&value];
      }
    }
  }
  return value;
}

// http://www.w3schools.com/tags/ref_charactersets.asp
static NSStringEncoding _StringEncodingFromCharset(NSString* charset) {
  NSStringEncoding encoding = kCFStringEncodingInvalidId;
  if (charset) {
    encoding = CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding((CFStringRef)charset));
  }
  return (encoding != kCFStringEncodingInvalidId ? encoding : NSUTF8StringEncoding);
}

@interface OCFWebServerRequest ()

#pragma mark - Properties
@property(nonatomic, copy, readwrite) NSString* method;
@property(nonatomic, copy, readwrite) NSURL* URL;
@property(nonatomic, copy, readwrite) NSDictionary* headers;
@property(nonatomic, copy, readwrite) NSString* path;
@property(nonatomic, copy, readwrite) NSDictionary* query;  // May be nil
@property(nonatomic, copy, readwrite) NSString* contentType;
@property(nonatomic, readwrite) NSUInteger contentLength;  // Automatically parsed from headers

@end

@implementation OCFWebServerRequest : NSObject

#pragma mark - Creating
- (instancetype)initWithMethod:(NSString*)method URL:(NSURL*)URL headers:(NSDictionary*)headers path:(NSString*)path query:(NSDictionary*)query {
  if((self = [super init])) {
    self.method = method;
    self.URL = URL;
    self.headers = headers;
    self.path = path;
    self.query = query;
    
    self.contentType = self.headers[@"Content-Type"];
    NSString *contentLengthString = self.headers[@"Content-Length"];
    if(contentLengthString == nil) {
      LOG_DEBUG(@"Request has no content length.");
      // FIXME: Check RFC. This does not seem to be correct.
      //        As far I know it is okay for requests to not
      //        have a content length header value at all.
      self.contentLength = 0;
    } else {
      // FIXME: Validate contents of contentLengthString: A malformed content length value
      //        may have bad side effects.
      NSInteger length = [contentLengthString integerValue];
      if(length < 0) {
        DNOT_REACHED();
        return nil;
      }
      self.contentLength = length;
    }
    
    if((self.contentLength > 0) && (self.contentType == nil)) {
      self.contentType = kOCFWebServerDefaultMimeType;
    }
  }
  return self;
}

- (BOOL)hasBody {
  return (self.contentType != nil ? YES : NO);
}

#pragma mark - Responding
- (void)respondWith:(OCFWebServerResponse *)response {
  self.responseBlock ? self.responseBlock(response) : nil;
}

@end

@implementation OCFWebServerRequest (Subclassing)

- (BOOL)open {
  [self doesNotRecognizeSelector:_cmd];
  return NO;
}

- (NSInteger)write:(const void*)buffer maxLength:(NSUInteger)length {
  [self doesNotRecognizeSelector:_cmd];
  return -1;
}

- (BOOL)close {
  [self doesNotRecognizeSelector:_cmd];
  return NO;
}

@end

@interface OCFWebServerDataRequest ()

#pragma mark - Properties
@property(nonatomic, copy, readwrite) NSData *data;  // Only valid after open / write / close sequence

@end

@implementation OCFWebServerDataRequest {
  NSMutableData* _data;
}

#pragma mark - Properties
- (NSData *)data {
  return [_data copy];
}

- (void)setData:(NSData *)data {
  _data = [data mutableCopy];
}

- (void)dealloc {
  DCHECK(self.data != nil);
}

- (BOOL)open {
  DCHECK(self.data == nil);
  self.data = [NSMutableData dataWithCapacity:self.contentLength];
  return _data ? YES : NO;
}

- (NSInteger)write:(const void*)buffer maxLength:(NSUInteger)length {
  DCHECK(_data != nil);
  [_data appendBytes:buffer length:length];
  return length;
}

- (BOOL)close {
  DCHECK(_data != nil);
  return YES;
}

@end


@interface OCFWebServerFileRequest ()

#pragma mark - Properties
@property (nonatomic, copy, readwrite) NSString *filePath;
@property (nonatomic, assign) int file;

@end

@implementation OCFWebServerFileRequest

#pragma mark - Creating
- (instancetype)initWithMethod:(NSString*)method URL:(NSURL*)URL headers:(NSDictionary*)headers path:(NSString*)path query:(NSDictionary*)query {
  if((self = [super initWithMethod:method URL:URL headers:headers path:path query:query])) {
    self.filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    self.file = 0;
  }
  return self;
}

- (void)dealloc {
  DCHECK(self.file < 0);
  unlink([self.filePath fileSystemRepresentation]);
}

- (BOOL)open {
  DCHECK(self.file == 0);
  self.file = open([self.filePath fileSystemRepresentation], O_CREAT | O_TRUNC | O_WRONLY, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
  return (self.file > 0 ? YES : NO);
}

- (NSInteger)write:(const void*)buffer maxLength:(NSUInteger)length {
  DCHECK(self.file > 0);
  return write(self.file, buffer, length);
}

- (BOOL)close {
  DCHECK(self.file > 0);
  int result = close(self.file);
  self.file = -1;
  return (result == 0 ? YES : NO);
}

@end

@interface OCFWebServerURLEncodedFormRequest ()

#pragma mark - Properties
@property(nonatomic, copy, readwrite) NSDictionary *arguments;

@end

@implementation OCFWebServerURLEncodedFormRequest

#pragma mark - Global Stuff
+ (NSString*)mimeType {
  return @"application/x-www-form-urlencoded";
}

#pragma mark - OCFWebServerRequest
- (BOOL)close {
  if (![super close]) {
    return NO;
  }
  
  NSString *charset = _ExtractHeaderParameter(self.contentType, @"charset");
  NSString *string = [[NSString alloc] initWithData:self.data encoding:_StringEncodingFromCharset(charset)];
  self.arguments = OCFWebServerParseURLEncodedForm(string);
  
  return (self.arguments ? YES : NO);
}

@end

@interface OCFWebServerMultiPart ()

#pragma mark - Properties
@property(nonatomic, copy, readwrite) NSString *contentType;
@property(nonatomic, copy, readwrite) NSString *mimeType;

@end

@implementation OCFWebServerMultiPart

#pragma mark - Creating
- (instancetype)initWithContentType:(NSString*)contentType {
  if((self = [super init])) {
    self.contentType = contentType;
    NSArray *components = [self.contentType componentsSeparatedByString:@";"];
    if(components.count > 0) {
      self.mimeType = [components[0] lowercaseString];
    }
    if (self.mimeType == nil) {
      self.mimeType = @"text/plain";
    }
  }
  return self;
}

@end

@interface OCFWebServerMultiPartArgument ()

#pragma mark - Properties
@property(nonatomic, copy, readwrite) NSData *data;
@property(nonatomic, copy, readwrite) NSString *string;

@end

@implementation OCFWebServerMultiPartArgument

#pragma mark - Creating
- (instancetype)initWithContentType:(NSString*)contentType data:(NSData*)data {
  if((self = [super initWithContentType:contentType])) {
    self.data = data;
    if([self.mimeType hasPrefix:@"text/"]) {
      NSString* charset = _ExtractHeaderParameter(self.contentType, @"charset");
      self.string = [[NSString alloc] initWithData:_data encoding:_StringEncodingFromCharset(charset)];
    }
  }
  return self;
}

#pragma mark - NSObject
- (NSString *)description {
  return [NSString stringWithFormat:@"<%@ | '%@' | %i bytes>", [self class], self.mimeType, (int)_data.length];
}

@end

@interface OCFWebServerMultiPartFile ()

#pragma mark - Properties
@property(nonatomic, copy, readwrite) NSString *fileName;
@property(nonatomic, copy, readwrite) NSString *temporaryPath;

@end

@implementation OCFWebServerMultiPartFile

#pragma mark - Creating
- (instancetype)initWithContentType:(NSString*)contentType fileName:(NSString*)fileName temporaryPath:(NSString*)temporaryPath {
  if((self = [super initWithContentType:contentType])) {
    self.fileName = fileName;
    self.temporaryPath = temporaryPath;
  }
  return self;
}

#pragma mark - NSObject
- (void)dealloc {
  unlink([self.temporaryPath fileSystemRepresentation]);
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@ | '%@' | '%@>'", [self class], self.mimeType, self.fileName];
}

@end

@interface OCFWebServerMultiPartFormRequest ()

#pragma mark - Properties
@property (nonatomic, copy, readwrite) NSDictionary *arguments;
@property (nonatomic, copy, readwrite) NSDictionary *files;
@property (nonatomic, copy, readwrite) NSData *parserData;
@property (nonatomic, copy) NSData *boundary;
@property (nonatomic, assign) OCFWebServerParserState parserState;
@property (nonatomic, copy) NSString *controlName;
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, copy) NSString *tmpPath;
@property (nonatomic, assign) int tmpFile;
@property (nonatomic, copy, readwrite) NSData *data;

@end

@implementation OCFWebServerMultiPartFormRequest {
  NSMutableDictionary *_arguments;
  NSMutableDictionary *_files;
  NSMutableData *_parserData;
  NSMutableData* _data;
}

#pragma mark - Properties
- (void)setArguments:(NSDictionary *)arguments {
  _arguments = [arguments mutableCopy];
}

- (NSDictionary *)arguments {
  return [_arguments copy];
}

- (void)setFiles:(NSDictionary *)files {
  _files = [files mutableCopy];
}

- (NSDictionary *)files {
  return [_files copy];
}

- (void)setParserData:(NSData *)parserData {
  _parserData = [parserData mutableCopy];
}

- (NSData *)parserData {
  return [_parserData copy];
}

- (NSData *)data {
  return [_data copy];
}

- (void)setData:(NSData *)data {
  _data = [data mutableCopy];
}

#pragma mark - Creating
- (instancetype)initWithMethod:(NSString*)method URL:(NSURL*)URL headers:(NSDictionary*)headers path:(NSString*)path query:(NSDictionary*)query {
  if((self = [super initWithMethod:method URL:URL headers:headers path:path query:query])) {
    NSString *boundary = _ExtractHeaderParameter(self.contentType, @"boundary");
    if(boundary) {
      self.boundary = [[NSString stringWithFormat:@"--%@", boundary] dataUsingEncoding:NSASCIIStringEncoding];
    }
    if(self.boundary == nil) {
      DNOT_REACHED();
      return nil;
    }
    self.arguments = @{};
    self.files = @{};
    self.parserState = OCFWebServerParserStateUndefined;
  }
  return self;
}

- (NSInteger)write:(const void*)buffer maxLength:(NSUInteger)length {
  DCHECK(_parserData != nil);
  [_parserData appendBytes:buffer length:length];
  
  DCHECK(_data != nil);
  [_data appendBytes:buffer length:length];
  return ([self _parseData] ? length : -1);
}

- (BOOL)open {
  DCHECK(self.parserData == nil);
  DCHECK(self.data == nil);
  self.data = [NSMutableData dataWithCapacity:self.contentLength];
  
  self.parserData = [[NSMutableData alloc] initWithCapacity:kMultiPartBufferSize];
  self.parserState = OCFWebServerParserStateStart;
  return YES;
}

// http://www.w3.org/TR/html401/interact/forms.html#h-17.13.4
- (BOOL)_parseData {
  BOOL success = YES;
  
  if (self.parserState == OCFWebServerParserStateHeaders) {
    NSRange range = [_parserData rangeOfData:_newlinesData options:0 range:NSMakeRange(0, _parserData.length)];
    if (range.location != NSNotFound) {
      
      self.controlName = nil;
      self.fileName = nil;
      self.contentType = nil;
      self.tmpPath = nil;
      CFHTTPMessageRef message = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, true);
      const char* temp = "GET / HTTP/1.0\r\n";
      CFHTTPMessageAppendBytes(message, (const UInt8*)temp, strlen(temp));
      CFHTTPMessageAppendBytes(message, _parserData.bytes, range.location + range.length);
      if (CFHTTPMessageIsHeaderComplete(message)) {
        NSString* controlName = nil;
        NSString* fileName = nil;
        NSDictionary* headers = (id)CFBridgingRelease(CFHTTPMessageCopyAllHeaderFields(message));
        NSString* contentDisposition = headers[@"Content-Disposition"];
        if ([[contentDisposition lowercaseString] hasPrefix:@"form-data;"]) {
          controlName = _ExtractHeaderParameter(contentDisposition, @"name");
          fileName = _ExtractHeaderParameter(contentDisposition, @"filename");
        }
        self.controlName = controlName;
        self.fileName = fileName;
        self.contentType = headers[@"Content-Type"];
      }
      CFRelease(message);
      if (self.controlName) {
        if (self.fileName) {
          NSString* path = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
          self.tmpFile = open([path fileSystemRepresentation], O_CREAT | O_TRUNC | O_WRONLY, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
          if (self.tmpFile > 0) {
            self.tmpPath = path;
          } else {
            DNOT_REACHED();
            success = NO;
          }
        }
      } else {
        DNOT_REACHED();
        success = NO;
      }
      
      [_parserData replaceBytesInRange:NSMakeRange(0, range.location + range.length) withBytes:NULL length:0];
      self.parserState = OCFWebServerParserStateContent;
    }
  }
  
  if ((self.parserState == OCFWebServerParserStateStart) || (self.parserState == OCFWebServerParserStateContent)) {
    NSRange range = [_parserData rangeOfData:_boundary options:0 range:NSMakeRange(0, _parserData.length)];
    if (range.location != NSNotFound) {
      NSRange subRange = NSMakeRange(range.location + range.length, _parserData.length - range.location - range.length);
      NSRange subRange1 = [_parserData rangeOfData:_newlineData options:NSDataSearchAnchored range:subRange];
      NSRange subRange2 = [_parserData rangeOfData:_dashNewlineData options:NSDataSearchAnchored range:subRange];
      if ((subRange1.location != NSNotFound) || (subRange2.location != NSNotFound)) {
        
        if (self.parserState == OCFWebServerParserStateContent) {
          const void* dataBytes = _parserData.bytes;
          NSUInteger dataLength = range.location - 2;
          if (self.tmpPath) {
            ssize_t result = write(self.tmpFile, dataBytes, (size_t)dataLength);
            if (result == dataLength) {
              if (close(self.tmpFile) == 0) {
                self.tmpFile = 0;
                OCFWebServerMultiPartFile *file = [[OCFWebServerMultiPartFile alloc] initWithContentType:self.contentType fileName:self.fileName temporaryPath:self.tmpPath];
                _files[self.controlName] = file;
              } else {
                DNOT_REACHED();
                success = NO;
              }
            } else {
              DNOT_REACHED();
              success = NO;
            }
            self.tmpPath = nil;
          } else {
            NSData *data = [[NSData alloc] initWithBytesNoCopy:(void*)dataBytes length:dataLength freeWhenDone:NO];
            OCFWebServerMultiPartArgument *argument = [[OCFWebServerMultiPartArgument alloc] initWithContentType:self.contentType data:data];
            _arguments[self.controlName] = argument;
          }
        }
        
        if (subRange1.location != NSNotFound) {
          [_parserData replaceBytesInRange:NSMakeRange(0, subRange1.location + subRange1.length) withBytes:NULL length:0];
          self.parserState = OCFWebServerParserStateHeaders;
          success = [self _parseData];
        } else {
          self.parserState = OCFWebServerParserStateEnd;
        }
      }
    } else {
      NSUInteger margin = 2 * self.boundary.length;
      if (self.tmpPath && (_parserData.length > margin)) {
        NSUInteger length = _parserData.length - margin;
        ssize_t result = write(self.tmpFile, _parserData.bytes, length);
        if (result == length) {
          [_parserData replaceBytesInRange:NSMakeRange(0, length) withBytes:NULL length:0];
        } else {
          DNOT_REACHED();
          success = NO;
        }
      }
    }
  }
  return success;
}

- (BOOL)close {
  DCHECK(_parserData != nil);
  self.parserData = nil;
  if (self.tmpFile > 0) {
    close(self.tmpFile);
    unlink([self.tmpPath fileSystemRepresentation]);
  }
  return (self.parserState == OCFWebServerParserStateEnd ? YES : NO);
}

#pragma mark - Global Stuff
+ (void)initialize {
  if (_newlineData == nil) {
    _newlineData = [[NSData alloc] initWithBytes:"\r\n" length:2];
    DCHECK(_newlineData);
  }
  if (_newlinesData == nil) {
    _newlinesData = [[NSData alloc] initWithBytes:"\r\n\r\n" length:4];
    DCHECK(_newlinesData);
  }
  if (_dashNewlineData == nil) {
    _dashNewlineData = [[NSData alloc] initWithBytes:"--\r\n" length:4];
    DCHECK(_dashNewlineData);
  }
}

+ (NSString *)mimeType {
  return @"multipart/form-data";
}

#pragma mark - NSObject
- (void)dealloc {
  DCHECK(_parserData == nil);
}

@end
