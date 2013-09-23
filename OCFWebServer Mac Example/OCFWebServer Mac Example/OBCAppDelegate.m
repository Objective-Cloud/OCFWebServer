//
//  OBCAppDelegate.m
//  OCFWebServer Mac Example
//
//  Created by cmk on 8/3/13.
//  Copyright (c) 2013 Objective-Cloud.com. All rights reserved.
//

#import "OBCAppDelegate.h"

#import "OCFWebServer.h"

@interface OBCAppDelegate ()
@property (nonatomic, strong) OCFWebServer *server;
@end

@implementation OBCAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  self.server = [OCFWebServer new];
  
  // Add a request handler for every possible GET request
  
  [self.server addDefaultHandlerForMethod:@"GET"
                             requestClass:[OCFWebServerRequest class]
                             processBlock:^void(OCFWebServerRequest *request,
                                                OCFWebServerResponseBlock respondWith) {
                               // Create your response and pass it to respondWith(...)
                               respondWith([OCFWebServerDataResponse responseWithHTML:@"Hello World"]);
                             }];
  
  // Run the server on port 8080
  [self.server startWithPort:8080 bonjourName:nil];
  
  NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
  NSString *serverURLString = [NSString stringWithFormat:@"http://127.0.0.1:%lu", self.server.port];
  NSURL *URL = [NSURL URLWithString:serverURLString];
  [workspace openURL:URL];
}

@end
