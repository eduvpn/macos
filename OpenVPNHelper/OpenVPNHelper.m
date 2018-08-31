//
//  OpenVPNHelper.m
//  eduVPN
//
//  Created by Johan Kool on 03/07/2017.
//  Copyright © 2017 eduVPN. All rights reserved.
//

#import "OpenVPNHelper.h"
#include <syslog.h>

@interface OpenVPNHelper () <NSXPCListenerDelegate, OpenVPNHelperProtocol>

@property (atomic, strong, readwrite) NSXPCListener *listener;
@property (atomic, strong) NSTask *openVPNTask;
@property (atomic, copy) NSString *logFilePath;
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

- (void)startOpenVPNAtURL:(NSURL *_Nonnull)launchURL withConfig:(NSURL *_Nonnull)config upScript:(NSURL *_Nullable)upScript downScript:(NSURL *_Nullable)downScript scriptOptions:(NSArray <NSString *>*_Nullable)scriptOptions reply:(void(^_Nonnull)(BOOL))reply {
    // Verify that binary at URL is signed by me
    SecStaticCodeRef staticCodeRef = 0;
    OSStatus status = SecStaticCodeCreateWithPath((__bridge CFURLRef _Nonnull)(launchURL), kSecCSDefaultFlags, &staticCodeRef);
    if (status != errSecSuccess) {
        syslog(LOG_ERR, "Static code error %d", status);
        reply(NO);
        return;
    }

    NSString *requirement = @"anchor apple generic and identifier openvpn and certificate leaf[subject.OU] = ZYJ4TZX4UU";
    SecRequirementRef requirementRef = 0;
    status = SecRequirementCreateWithString((__bridge CFStringRef _Nonnull)requirement, kSecCSDefaultFlags, &requirementRef);
    if (status != errSecSuccess) {
        syslog(LOG_ERR, "Requirement error %d", status);
        reply(NO);
        return;
    }
    
    status = SecStaticCodeCheckValidity(staticCodeRef, kSecCSDefaultFlags, requirementRef);
    if (status != errSecSuccess) {
        syslog(LOG_ERR, "Validity error %d", status);
        reply(NO);
        return;
    }
    
    syslog(LOG_NOTICE, "Launching task");
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = launchURL.path;
    NSString *logFilePath = [config.path stringByAppendingString:@".log"];
    NSString *socketPath = @"/private/tmp/eduvpn.socket";
    
    NSMutableArray *arguments = [NSMutableArray arrayWithArray:@[@"--config", [self pathWithSpacesEscaped:config.path],
                       @"--log", [self pathWithSpacesEscaped:logFilePath],
                       @"--management", [self pathWithSpacesEscaped:socketPath], @"unix",
                       @"--management-external-key",
                       @"--management-external-cert", @"macosx-keychain",
                       @"--management-query-passwords",
                       @"--management-forget-disconnect"]];
    
    if (upScript.path) {
        [arguments addObjectsFromArray:@[@"--up", [self scriptPath:upScript.path withOptions:scriptOptions]]];
    }
    if (downScript.path) {
        [arguments addObjectsFromArray:@[@"--down", [self scriptPath:downScript.path withOptions:scriptOptions]]];
    }
    if (upScript.path || downScript.path) {
        // 2 -- allow calling of built-ins and scripts
        [arguments addObjectsFromArray:@[@"--script-security", @"2"]];
    }
    task.arguments = arguments;
    [task setTerminationHandler:^(NSTask *task){
        [[NSFileManager defaultManager] removeItemAtPath:socketPath error:NULL];
        [self.remoteObject taskTerminatedWithReply:^{
            syslog(LOG_NOTICE, "Terminated task");
        }];
    }];
    [task launch];
    
    // Create and make log file readable
    NSError *error;
    [[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
    if (![[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions: [NSNumber numberWithShort:0644]} ofItemAtPath:logFilePath error:&error]) {
        syslog(LOG_WARNING, "Error making log file %s readable (chmod 644): %s", logFilePath.UTF8String, error.description.UTF8String);
    }
    
    self.openVPNTask = task;
    self.logFilePath = logFilePath;
    
    reply(task.isRunning);
}

- (void)closeWithReply:(void(^)(void))reply {
    [self.openVPNTask interrupt];
    self.openVPNTask = nil;
    reply();
}

- (NSString *)pathWithSpacesEscaped:(NSString *)path {
    return [path stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
}
    
- (NSString *)scriptPath:(NSString *)path withOptions:(NSArray <NSString *>*)scriptOptions {
    if (scriptOptions && [scriptOptions count] > 0) {
        NSString *escapedPath = [self pathWithSpacesEscaped:path];
        return [NSString stringWithFormat:@"%@ %@", escapedPath, [scriptOptions componentsJoinedByString:@" "]];
    } else {
        NSString *escapedPath = [self pathWithSpacesEscaped:path];
        return escapedPath;
    }
}

@end
