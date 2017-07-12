//
//  OpenVPNHelper.m
//  EduVPN
//
//  Created by Johan Kool on 03/07/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

#import "OpenVPNHelper.h"

@interface OpenVPNHelper () <NSXPCListenerDelegate, OpenVPNHelperProtocol>

@property (atomic, strong, readwrite) NSXPCListener *listener;
@property (atomic, strong) NSTask *openVPNTask;
@property (atomic, strong) id <ClientProtocol> remoteObject;

@end

@implementation OpenVPNHelper


- (id)init {
    self = [super init];
    if (self != nil) {
        // Set up our XPC listener to handle requests on our Mach service.
        self->_listener = [[NSXPCListener alloc] initWithMachServiceName:kHelperToolMachServiceName];
        self->_listener.delegate = self;
    }
    return self;
}

- (void)run {
    // Tell the XPC listener to start processing requests.
    
    [self.listener resume];
    
    // Run the run loop forever.
    
    [[NSRunLoop currentRunLoop] run];
}

// Called by our XPC listener when a new connection comes in.  We configure the connection
// with our protocol and ourselves as the main object.
- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    assert(listener == self.listener);
#pragma unused(listener)
    assert(newConnection != nil);
    
    
    
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(OpenVPNHelperProtocol)];
    newConnection.exportedObject = self;
    self.remoteObject = newConnection.remoteObjectProxy;
    [newConnection resume];
    
    return YES;
}



- (void)getVersionWithReply:(void(^)(NSString * version))reply
// Part of the HelperToolProtocol.  Returns the version number of the tool.  Note that never
// requires authorization.
{
    // We specifically don't check for authorization here.  Everyone is always allowed to get
    // the version of the helper tool.
    reply([[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]);
}

- (void)startOpenVPNAtURL:(NSURL *)launchURL withConfig:(NSURL *)config reply:(void(^)(NSString * version))reply {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = launchURL.path;
    task.arguments = @[@"--config", config.path];
    [task setTerminationHandler:^(NSTask *task){
        [self.remoteObject stateChanged:OpenVPNStateUnknown reply:^{
            NSLog(@"state changed");
        }];
    }];
    [task launch];
    
    self.openVPNTask = task;

    reply(@"Connected!");
}

- (void)closeWithReply:(void(^)())reply {
    [self.openVPNTask terminate];
    self.openVPNTask = nil;
    reply();
}

@end
