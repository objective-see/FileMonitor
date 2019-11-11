//
//  FileMonitor.h
//  FileMonitor
//
//  Created by Patrick Wardle on 9/1/19.
//  Copyright © 2019 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <EndpointSecurity/EndpointSecurity.h>

/* CONSTS */

//code signing keys
#define KEY_SIGNATURE_CDHASH @"cdHash"
#define KEY_SIGNATURE_FLAGS @"csFlags"
#define KEY_SIGNATURE_IDENTIFIER @"signatureIdentifier"
#define KEY_SIGNATURE_TEAM_IDENTIFIER @"teamIdentifier"
#define KEY_SIGNATURE_PLATFORM_BINARY @"isPlatformBinary"

/* CLASSES */
@class File;
@class Process;

/* TYPEDEFS */

//block for library
typedef void (^FileCallbackBlock)(File* _Nonnull);

@interface FileMonitor : NSObject

//start monitoring
-(BOOL)start:(FileCallbackBlock _Nonnull )callback;

//stop monitoring
-(BOOL)stop;

@end

/* OBJECT: FILE */

@interface File : NSObject

/* PROPERTIES */

//event
// create, write, etc...
@property u_int32_t event;

//src path
@property(nonatomic, retain)NSString* _Nullable sourcePath;

//dest path
@property(nonatomic, retain)NSString* _Nullable destinationPath;

//process
@property(nonatomic, retain)Process* _Nullable process;

/* METHODS */

//init
-(id _Nullable)init:(es_message_t* _Nonnull)message;

@end


/* OBJECT: PROCESS */

@interface Process : NSObject

/* PROPERTIES */

//pid
@property pid_t pid;

//ppid
@property pid_t ppid;

//user id
@property uid_t uid;

//event
// exec, fork, exit
@property u_int32_t event;

//exit code
@property int exit;

//path
@property(nonatomic, retain)NSString* _Nullable path;

//args
@property(nonatomic, retain)NSMutableArray* _Nonnull arguments;

//ancestors
@property(nonatomic, retain)NSMutableArray* _Nonnull ancestors;

//signing info
@property(nonatomic, retain)NSMutableDictionary* _Nonnull signingInfo;

//timestamp
@property(nonatomic, retain)NSDate* _Nonnull timestamp;

/* METHODS */

//init
-(id _Nullable)init:(es_message_t* _Nonnull)message;

@end
