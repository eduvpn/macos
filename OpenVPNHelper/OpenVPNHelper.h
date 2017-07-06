//
//  OpenVPNHelper.h
//  EduVPN
//
//  Created by Johan Kool on 03/07/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

#import <Foundation/Foundation.h>

// kHelperToolMachServiceName is the Mach service name of the helper tool.  Note that the value
// here has to match the value in the MachServices dictionary in "HelperTool-Launchd.plist".

#define kHelperToolMachServiceName @"nl.eduvpn.app.macos.openvpnhelper"

// HelperToolProtocol is the NSXPCConnection-based protocol implemented by the helper tool
// and called by the app.

@protocol OpenVPNHelperProtocol

typedef NS_ENUM(NSInteger, OpenVPNState) {
    OpenVPNStateUnknown,
    OpenVPNStateIdle,
    OpenVPNStateConnecting,
    OpenVPNStateConnected,
};

typedef NS_ENUM(NSInteger, OpenVPNError) {
    OpenVPNErrorNone,
    OpenVPNErrorUnknown,
    OpenVPNErrorAlreadyConnected,
};

@required

- (void)getVersionWithReply:(void(^)(NSString * version))reply;
// This command simply returns the version number of the tool.  It's a good idea to include a
// command line this so you can handle app upgrades cleanly.

//// The next two commands imagine an app that needs to store a license key in some global location
//// that's not writable by all users; thus, setting the license key requires elevated privileges.
//// To manage this there's a 'read' command--which by default can be used by everyone--to return
//// the key and a 'write' command--which requires admin authentication--to set the key.
//
//- (void)readLicenseKeyAuthorization:(NSData *)authData withReply:(void(^)(NSError * error, NSString * licenseKey))reply;
//// Reads the current license key.  authData must be an AuthorizationExternalForm embedded
//// in an NSData.
//
//- (void)writeLicenseKey:(NSString *)licenseKey authorization:(NSData *)authData withReply:(void(^)(NSError * error))reply;
//// Writes a new license key.  licenseKey is the new license key string.  authData must be
//// an AuthorizationExternalForm embedded in an NSData.
//
//- (void)bindToLowNumberPortAuthorization:(NSData *)authData withReply:(void(^)(NSError * error, NSFileHandle * ipv4Handle, NSFileHandle * ipv6Handle))reply;
//// This command imagines an app that contains an embedded web server.  A web server has to
//// bind to port 80, which is a privileged operation.  This command lets the app request that
//// the privileged helper tool create sockets bound to port 80 and then pass them back to the
//// app, thereby minimising the amount of code that has to run with elevated privileges.
//// authData must be an AuthorizationExternalForm embedded in an NSData and the sockets are
//// returned wrapped up in NSFileHandles.

- (void)startOpenVPNAtURL:(NSURL *)launchURL withConfig:(NSURL *)config reply:(void(^)(NSString *))reply;

- (void)closeWithReply:(void(^)())reply;

@end

@protocol ClientProtocol <NSObject>

- (void)stateChanged:(OpenVPNState)state reply:(void(^)())reply;


@end


// The following is the interface to the class that implements the helper tool.
// It's called by the helper tool's main() function, but not by the app directly.

@interface OpenVPNHelper : NSObject

- (id)init;

- (void)run;

@end
