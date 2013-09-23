//
//  OBCAppDelegate.m
//  OCFWebServer Mac Example
//
//  Created by cmk on 8/3/13.
//  Copyright (c) 2013 Objective-Cloud.com. All rights reserved.
//

#import "OBCAppDelegate.h"

#import "OCFWebServer.h"
#import "OCFWebServerRequest.h"
#import "OCFWebServerResponse.h"

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
                             processBlock:^(OCFWebServerRequest *request) {
                               // Create your response and pass it to respondWith(...)
                               OCFWebServerResponse *response = [OCFWebServerDataResponse responseWithHTML:@"Hello World"];
                               [request respondWith:response];
                             }];
  
  // Run the server on port 8080
  [self.server startWithPort:8080 bonjourName:nil];
  
  NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
  NSString *serverURLString = [NSString stringWithFormat:@"http://127.0.0.1:%lu", self.server.port];
  NSURL *URL = [NSURL URLWithString:serverURLString];
  [workspace openURL:URL];
}

@end
