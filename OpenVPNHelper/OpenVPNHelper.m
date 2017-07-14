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
    assert(newConnection != nil);
    
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(OpenVPNHelperProtocol)];
    newConnection.exportedObject = self;
    newConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(ClientProtocol)];
    self.remoteObject = newConnection.remoteObjectProxy;
    [newConnection resume];
    
    return YES;
}

- (void)getVersionWithReply:(void(^)(NSString * version))reply {
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?";
    NSString *buildVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"?";
    reply([NSString stringWithFormat:@"%@-%@", version, buildVersion]);
}

- (void)startOpenVPNAtURL:(NSURL *)launchURL withConfig:(NSURL *)config reply:(void(^)(BOOL))reply {
    // Verify that binary at URL is signed by me
    SecStaticCodeRef staticCodeRef = 0;
    OSStatus status = SecStaticCodeCreateWithPath((__bridge CFURLRef _Nonnull)(launchURL), kSecCSDefaultFlags, &staticCodeRef);
    if (status != errSecSuccess) {
        reply(NO);
        return;
    }
    
    SecRequirementRef requirementRef = 0;
    status = SecRequirementCreateWithString((__bridge CFStringRef _Nonnull)@"anchor apple generic and certificate leaf[subject.CN] = \"Mac Developer: Johan Kool (2W662WXNRW)\" and certificate 1[field.1.2.840.113635.100.6.2.1]", kSecCSDefaultFlags, &requirementRef);
    if (status != errSecSuccess) {
        reply(NO);
        return;
    }
    
    status = SecStaticCodeCheckValidity(staticCodeRef, kSecCSDefaultFlags, requirementRef);
    if (status != errSecSuccess) {
        reply(NO);
        return;
    }
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = launchURL.path;
    task.arguments = @[@"--config", config.path];
    [task setTerminationHandler:^(NSTask *task){
        [self.remoteObject taskTerminatedWithReply:^{
           NSLog(@"task terminated");
        }];
    }];
    [task launch];
    
    self.openVPNTask = task;

    reply(YES);
}

- (void)closeWithReply:(void(^)())reply {
    [self.openVPNTask terminate];
    self.openVPNTask = nil;
    reply();
}

@end
