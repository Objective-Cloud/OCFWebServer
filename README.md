# Overview
OCFWebServer is a lightweight, modern and asynchronous HTTP (version 1.1) server. It was forked from [GCDWebServer](https://raw.github.com/swisspol/GCDWebServer) and modified to fit the needs of [Objective-Cloud.com](http://objective-cloud.com) and hopefully other people's needs as well.

# Who is using OCFWebServer?
OCFWebServer is used by OCFWeb which is a framework for developing web applications with Objective-C. OCFWeb and OCFWebServer are both used by [Objective-Cloud.com](http://objective-cloud.com). Are you using OCFWebServer as well? [Let us know](mailto:team@objective-cloud.com) and we will link your app/project right here.

# Goals
OCFWebServer was developed to be used for Objective-Cloud.com. This does not mean that the goals we had while developing it are incompatible with the needs of developers of `regular` apps. These are the goals we had in mind while working on OCFWebServer:

* Easy to use in your own application: Embedding OCFWebServer should be done with just a few lines of code.
* Be *truly* asynchronous: Use GCD/dispatch_io everywhere and make it easy to let the user write asynchronous request handlers.
* Many concurrent requests: We wanted to be able to have a minimum of 128 concurrent requests per OCFWebServer instance. OCFWebServer can do more but out of the box is supports up to 128 concurrent requests. This is enough for [Objective-Cloud.com](http://objective-cloud.com) and probably also enough for your needs as well.
* Don't do everything: If you need a simple HTTP server in your app OCFWebServer is made for you. Please do not try to run an instance of OCFWebServer, publicly on the internet. Your machine will be hacked. At [Objective-Cloud.com](http://objective-cloud.com) we always have at least one proxy server in front of our instances of OCFWebServer. 

# Examples and getting started
You can simply download the source code of OCFWebServer and add every header and implementation file to your own project. 

Remark: All of the following examples are adapted from the GCDWebServer README file and slightly modified to reflect the changes made by OCFWebServer. Some of the explaining texts have also been adopted. Credits: Pierre-Olivier Latour (Thank you so much Pierre!)

## Example: Hello World

Setting up OCFWebServer is easy:

    #import "OCFWebServer.h"
    
    int main(int argc, const char* argv[]) {
      @autoreleasepool {
        OCFWebServer *server = [OCFWebServer new];
        
        // Add a request handler for every possible GET request
        
        [server addDefaultHandlerForMethod:@"GET"
                              requestClass:[OCFWebServerRequest class]
                              processBlock:^void(OCFWebServerRequest *request, 
                                                 OCFWebServerResponseBlock respondWith) {
                                         
          // Create your response and pass it to respondWith(...) 
          OCFWebServerResponse *response = [OCFWebServerDataResponse responseWithHTML:@"Hello World"];
          [request respondWith:response];
        }];
        
        // Run the server on port 8080
        [server runWithPort:8080];
		 
      }
    return EXIT_SUCCESS;

The example above assumes that you have a console based application. If you have a Cocoa or Cocoa Touch application then you might want to have a `@property (nonatomic, strong) OCFWebServer *server` in one of your controllers and use one of the `start` methods instead of `runWithPort:`. If you pass `0` as the port then OCFWebServer will automatically ask the operating system for a free port and use that.

## Example: Redirects
Here's an example handler that redirects `/` to `/index.html` using the convenience method on 'OCFWebServerResponse' (it sets the HTTP status code and 'Location' header automatically):

    [self addHandlerForMethod:@"GET"
                         path:@"/"
                 requestClass:[OCFWebServerRequest class]
             processBlock:^void(OCFWebServerRequest* request) {
      NSURL *toURL = [NSURL URLWithString:@"index.html" relativeToURL:request.URL];
      
      respondWith([OCFWebServerResponse responseWithRedirect:toURL
                                                   permanent:NO]);
    }];

## Example: Forms
To implement an HTTP form, you need a pair of handlers:

* The GET handler does not expect any body in the HTTP request and therefore uses the 'OCFWebServerRequest' class. The handler generates a response containing a simple HTML form.
* The POST handler expects the form values to be in the body of the HTTP request and percent-encoded. Fortunately, OCFWebServer provides the request class 'OCFWebServerURLEncodedFormRequest' which can automatically parse such bodies. The handler simply echoes back the value from the user submitted form.

Here we go:

    [server addHandlerForMethod:@"GET"
                           path:@"/"
                   requestClass:[OCFWebServerRequest class]
                   processBlock:^void(OCFWebServerRequest* request) {
  
      NSString* html = @"<html><body> \
                         <form name=\"input\" action=\"/\" \
                         method=\"post\" enctype=\"application/x-www-form-urlencoded\"> \
                         Value: <input type=\"text\" name=\"value\"> \
                         <input type=\"submit\" value=\"Submit\"> \
                         </form> \
                         </body></html>";
                         
      [request respondWith:[OCFWebServerDataResponse responseWithHTML:html]];
    }];

    [server addHandlerForMethod:@"POST"
                           path:@"/"
                   requestClass:[OCFWebServerURLEncodedFormRequest class]
                   processBlock:^void(OCFWebServerRequest* request) {
  
      NSString *value = [(OCFWebServerURLEncodedFormRequest*)request arguments][@"value"];
      NSString* html = [NSString stringWithFormat:@"<p>%@</p>", value];
      
      [request respondWith:[OCFWebServerDataResponse responseWithHTML:html]];
    }];

# Handlers
As shown in the examples, you can add more than one handler to an instance of OCFWebServer. The handlers are sorted and matched in a last in, first out fashion. 

# Requirements and Dependencies
OCFWebServer runs on

* OS X 10.8+
* iOS 6+

and has no third party dependencies. 

# Notes

OCFWebServer is a fork of GCDWebServer. The author of GCDWebServer has done a fantastic job. That is why we picked GCDWebServer as the foundation for OCFWebServer. In the process of making Objective-Cloud.com we realized that GCDWebServer in an incompatible fashion in order to work better. That is why we have forked GCDWebServer and improved it. OCFWebServer is not inherently better than GCDWebServer. It is different.

If you want to learn more about the architecture of OCFWebServer you can have a look at the [README of GCDWebServer](https://github.com/swisspol/GCDWebServer/blob/master/README.md). OCFWebServer has almost the same architecture than GCDWebServer.

## Asynchronous: Front to Back

In OCFWebServer your request handler does not have to return anything immediately. OCFWebServer will pass the request to your request handler. The request gives you access to a lot of HTTP request specific properties. Now it is your turn to compute a response. Once that is done you should let the request object know about your response by calling `-respondWith:` (class: OCFRequest) and pass it the response.  Here is an example:

    [server addDefaultHandlerForMethod:@"GET"
                      requestClass:[OCFWebServerRequest class]
                      processBlock:^void(OCFWebServerRequest *request) {
      dispatch_async(myQueue, ^() {
          OCFWebServerDataResponse *response = [OCFWebServerDataResponse responseWithHTML:@"Hello World"];
          [request respondWith:response];
      });
    }];  

As you can see your request handler can do anything it wants. You do not have to call `dispatch_async` but you can if you need to. Some APIs require you to do something asynchronously (NSURLConnection, XPC, …). 


By the way: Migrating your GCDWebServer related code to OCFWebServer is very easy: Simply replace `return response;` with `[request respondWith:response], return;` and you are done.

## Many concurrent requests
At the time of writing GCDWebServer can only handle 16 concurrent requests. You can increase that by changing a constant in GCDWebServer's source code but in OCFWebServer the default maximum number of concurrent request is automatically set to the maximum of what is possible. If you are running OS X and not fine tune the settings this will mean that OCFWebServer can handle up to 128 concurrent requests at a time. If you tune the settings of OS X then this value can be increased and we are already working on a better queuing system which should further increase the number of concurrent requests.

## Modern code base
True: This is an implementation detail but important to mention. OCFWebServer is using ARC, dispatch objects (`OS_OBJECT_USE_OBJC`), modern runtime and the existing code base of GCDWebServer has been cleaned up and made more POSIX compatible.

## No support for < OS X 10.8 and < iOS 6
OCFWebServer does only support OS X 10.8+ and iOS 6+. If you want to use it on older versions of OS X/iOS then you should use GCDWebServer.

# More Convenience
If you want even more convenience for your HTTP server related needs you should also have a look at OCFWeb. OCFWeb is a framework that let's you develop web applications in Objective-C. OCFWeb is using OCFWebServer internally and adds a lot of nice stuff to it like a template engine, nicer syntax for handlers and a lot more.

# How to contribute
Development of OCFWebServer takes place on GitHub. If you find a bug, suspect a bug or have a question feel free to open an issue. Pull requests are very welcome and will be accepted as fast as possible.

# License

OCFWebServer is available under the New BSD License - just like GCDWebServer.

    This file belongs to the OCFWebServer project. 
    OCFWebServer is a fork of GCDWebServer (originally developed by
    Pierre-Olivier Latour). 
    
    We have forked GCDWebServer because we made extensive and 
    incompatible changes to it.
    
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
	
