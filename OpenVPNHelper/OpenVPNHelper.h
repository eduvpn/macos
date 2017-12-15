//
//  OpenVPNHelper.h
//  eduVPN
//
//  Created by Johan Kool on 03/07/2017.
//  Copyright © 2017 eduVPN. All rights reserved.
//

#import <Foundation/Foundation.h>

// kHelperToolMachServiceName is the Mach service name of the helper tool.  Note that the value
// here has to match the value in the MachServices dictionary in "HelperTool-Launchd.plist".

#define kHelperToolMachServiceName @"org.eduvpn.app.openvpnhelper"

// HelperToolProtocol is the NSXPCConnection-based protocol implemented by the helper tool
// and called by the app.

#import "Statistics.h"

@protocol OpenVPNHelperProtocol

@required

/**
 Returns the version number of the tool
 
 @param reply Handler taking version number
 */
- (void)getVersionWithReply:(void(^_Nonnull)(NSString *_Nonnull version))reply;

/**
 Strarts OpenVPN connection

 @param launchURL URL to openvpn binary
 @param config URL to config file
 @param authUserPass URL to auth-user-pass file
 @param reply Success or not
 */
- (void)startOpenVPNAtURL:(NSURL *_Nonnull)launchURL withConfig:(NSURL *_Nonnull)config authUserPass:(NSURL *_Nullable)authUserPass reply:(void(^_Nonnull)(BOOL))reply;

/**
 Closes OpenVPN connection

 @param reply Success
 */
- (void)closeWithReply:(void(^_Nonnull)(void))reply;

/**
 Retrieves statistics for the current OpenVPN connection
 
 @param reply Statistics or nil
 */
- (void)readStatisticsWithReply:(void(^_Nonnull)(Statistics * _Nullable statistics))reply;

@end

@protocol ClientProtocol <NSObject>

@required

- (void)taskTerminatedWithReply:(void(^_Nonnull)(void))reply;

@end


// The following is the interface to the class that implements the helper tool.
// It's called by the helper tool's main() function, but not by the app directly.

@interface OpenVPNHelper : NSObject

- (void)run;

@end
