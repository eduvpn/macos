//
//  OpenVPNHelper.m
//  eduVPN
//
//  Created by Johan Kool on 03/07/2017.
//  Copyright © 2017 eduVPN. All rights reserved.
//

#import "OpenVPNHelper.h"

@interface OpenVPNHelper () <NSXPCListenerDelegate, OpenVPNHelperProtocol>

@property (atomic, strong, readwrite) NSXPCListener *listener;
@property (atomic, strong) NSTask *openVPNTask;
@property (atomic, strong) NSDate *startDate;
@property (atomic, copy) NSString *statisticsPath;
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
        NSLog(@"Static code error %d", status);
        reply(NO);
        return;
    }
    
    SecRequirementRef requirementRef = 0;
    status = SecRequirementCreateWithString((__bridge CFStringRef _Nonnull)@"anchor apple generic and certificate leaf[subject.CN] = \"Mac Developer: Johan Kool (2W662WXNRW)\" and certificate 1[field.1.2.840.113635.100.6.2.1]", kSecCSDefaultFlags, &requirementRef);
    if (status != errSecSuccess) {
        NSLog(@"Requirement error %d", status);
        reply(NO);
        return;
    }
    
    status = SecStaticCodeCheckValidity(staticCodeRef, kSecCSDefaultFlags, requirementRef);
    if (status != errSecSuccess) {
        NSLog(@"Validity error %d", status);
        reply(NO);
        return;
    }
    
    NSLog(@"Launching task");
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = launchURL.path;
    NSString *logFilePath = [config.path stringByAppendingString:@".log"];
    NSString *statisticsPath = [config.path stringByAppendingString:@".status"];
    task.arguments = @[@"--config", config.path,
                       @"--log", logFilePath,
                       @"--status", statisticsPath, @"1"];
    [task setTerminationHandler:^(NSTask *task){
        [self.remoteObject taskTerminatedWithReply:^{
           NSLog(@"task terminated");
        }];
    }];
    [task launch];
    
    // Make log file readable
    NSError *error;
    if (![[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions: [NSNumber numberWithShort:0644]} ofItemAtPath:logFilePath error:&error]) {
        NSLog(@"Error making log file %@ readable (chmod 644): %@", logFilePath, error);
    }
    
    self.openVPNTask = task;
    self.startDate = [NSDate date];
    self.statisticsPath = statisticsPath;
    
    reply(task.isRunning);
}

- (void)closeWithReply:(void(^)(void))reply {
    [self.openVPNTask terminate];
    self.openVPNTask = nil;
    reply();
}

- (void)readStatisticsWithReply:(void (^)(Statistics * _Nullable))reply {
    if (self.openVPNTask && self.statisticsPath) {
        NSError *error = nil;
        NSString *string = [NSString stringWithContentsOfFile:self.statisticsPath encoding:NSUTF8StringEncoding error:&error];
        if (string == nil) {
            NSLog(@"Read statistics file error: %@", error);
            reply(nil);
            return;
        }
        
        // Sample file:
        
//        OpenVPN STATISTICS
//        Updated,Wed Aug  9 12:32:46 2017
//        TUN/TAP read bytes,151771
//        TUN/TAP write bytes,269590
//        TCP/UDP read bytes,290152
//        TCP/UDP write bytes,176751
//        Auth read bytes,269590
//        pre-compress bytes,0
//        post-compress bytes,0
//        pre-decompress bytes,0
//        post-decompress bytes,0
//        END
        
        NSScanner *scanner = [[NSScanner alloc] initWithString:string];
        [scanner scanString:@"OpenVPN STATISTICS" intoString:NULL];
        NSString *dateString;
        [scanner scanString:@"Updated," intoString:&dateString];
        [scanner scanUpToString:@"\n" intoString:&dateString];
        
        NSDateComponents *duration = [[NSCalendar currentCalendar] components:NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:self.startDate toDate:[NSDate date] options:0];
        
        Statistics *statistics = [[Statistics alloc] initWithDuration:duration
                                                      tunTapReadBytes:[self bytesForKey:@"TUN/TAP read bytes," inScanner:scanner]
                                                     tunTapWriteBytes:[self bytesForKey:@"TUN/TAP write bytes," inScanner:scanner]
                                                      tcpUdpReadBytes:[self bytesForKey:@"TCP/UDP read bytes," inScanner:scanner]
                                                     tcpUdpWriteBytes:[self bytesForKey:@"TCP/UDP write bytes," inScanner:scanner]
                                                        authReadBytes:[self bytesForKey:@"Auth read bytes," inScanner:scanner]
                                                     precompressBytes:[self bytesForKey:@"pre-compress bytes," inScanner:scanner]
                                                    postcompressBytes:[self bytesForKey:@"post-compress bytes," inScanner:scanner]
                                                   predecompressBytes:[self bytesForKey:@"pre-decompress bytes," inScanner:scanner]
                                                  postdecompressBytes:[self bytesForKey:@"post-decompress bytes," inScanner:scanner]];
        reply(statistics);
    } else {
        reply(nil);
    }
}

- (NSInteger)bytesForKey:(NSString *)key inScanner:(NSScanner *)scanner {
    if (![scanner scanString:key intoString:NULL]) {
        return 0;
    }
    NSInteger bytes = 0;
    if (![scanner scanInteger:&bytes]) {
        return 0;
    } else {
        return bytes;
    }
}

@end
