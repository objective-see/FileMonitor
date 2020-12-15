//
//  File.m
//  FileMonitor
//
//  Created by Patrick Wardle on 9/1/19.
//  Copyright © 2020 Objective-See. All rights reserved.
//

#import <libproc.h>
#import <bsm/libbsm.h>
#import <sys/sysctl.h>

#import "utilities.h"
#import "FileMonitor.h"

/* GLOBALS */

//process cache
extern NSCache* processCache;

/* FUNCTIONS */

@implementation File

@synthesize process;
@synthesize timestamp;
@synthesize sourcePath;
@synthesize destinationPath;

//init
-(id)init:(es_message_t*)message csOption:(NSUInteger)csOption
{
    //process audit token
    NSData* auditToken = nil;
    
    //init super
    self = [super init];
    if(nil != self)
    {
        //set type
        self.event = message->event_type;
        
        //set timestamp
        self.timestamp = [NSDate date];
        
        //sync for process creation
        @synchronized (processCache) {
            
            //init audit token
            auditToken = [NSData dataWithBytes:&message->process->audit_token length:sizeof(audit_token_t)];
            
            //check cache for process
            // not found? create process obj...
            self.process = [processCache objectForKey:auditToken];
            if(nil == self.process)
            {
                //create process
                self.process = [[Process alloc] init:message csOption:csOption];
            }
    
            //sanity check
            // process creation failed?
            if(nil == process)
            {
                //unset
                self = nil;
            
                //bail
                goto bail;
            }
            
            //add to cache
            [processCache setObject:process forKey:auditToken];
        }
        
        //extract file path(s)
        // logic is specific to event
        [self extractPaths:message];
    }
    
bail:
    
    return self;
}

//extract source & destination path
// this requires event specific logic
-(void)extractPaths:(es_message_t*)message
{
    //event specific logic
    switch (message->event_type) {
        
        //create
        case ES_EVENT_TYPE_NOTIFY_CREATE:
        {
            //directory
            NSString* directory = nil;
            
            //file name
            NSString* fileName = nil;
            
            //existing file?
            // grab file path
            if(ES_DESTINATION_TYPE_EXISTING_FILE == message->event.create.destination_type)
            {
                //set path
                self.destinationPath = convertStringToken(&message->event.create.destination.existing_file->path);
            }
            //new file
            // build file path from directory + name
            else
            {
                //extract directory
                directory = convertStringToken(&message->event.create.destination.new_path.dir->path);
                
                //extact file name
                fileName = convertStringToken(&message->event.create.destination.new_path.filename);
                
                //combine
                self.destinationPath = [directory stringByAppendingPathComponent:fileName];
            }
            
            break;
        }
            
        //open
        case ES_EVENT_TYPE_NOTIFY_OPEN:
            
            //set path
            self.destinationPath = convertStringToken(&message->event.open.file->path);
            
            break;
            
        //write
        case ES_EVENT_TYPE_NOTIFY_WRITE:
            
            //set path
            self.destinationPath = convertStringToken(&message->event.write.target->path);
            
            break;
            
        //close
        case ES_EVENT_TYPE_NOTIFY_CLOSE:
            
            //set path
            self.destinationPath = convertStringToken(&message->event.close.target->path);
            
            break;
            
        //link
        case ES_EVENT_TYPE_NOTIFY_LINK:
            
            //set (src) path
            self.sourcePath = convertStringToken(&message->event.link.source->path);
            
            //set (dest) path
            // combine dest dir + dest file
            self.destinationPath = [convertStringToken(&message->event.link.target_dir->path) stringByAppendingPathComponent:convertStringToken(&message->event.link.target_filename)];
            
            break;
            
        //rename
        case ES_EVENT_TYPE_NOTIFY_RENAME:
                
            //set (src) path
            self.sourcePath = convertStringToken(&message->event.rename.source->path);
            
            //existing file ('ES_DESTINATION_TYPE_EXISTING_FILE')
            if(ES_DESTINATION_TYPE_EXISTING_FILE == message->event.rename.destination_type)
            {
                //set (dest) file
                self.destinationPath = convertStringToken(&message->event.rename.destination.existing_file->path);
            }
            //new path ('ES_DESTINATION_TYPE_NEW_PATH')
            else
            {
                //set (dest) path
                // combine dest dir + dest file
                self.destinationPath = [convertStringToken(&message->event.rename.destination.new_path.dir->path) stringByAppendingPathComponent:convertStringToken(&message->event.rename.destination.new_path.filename)];
            }
            
            break;
            
        //unlink
        case ES_EVENT_TYPE_NOTIFY_UNLINK:
                
            //set path
            self.destinationPath = convertStringToken(&message->event.unlink.target->path);
                
            break;
            
            
        default:
            break;
    }
    
    return;
}


//for pretty printing
// though we convert to JSON
-(NSString *)description
{
    //description
    NSMutableString* description = nil;

    //init output string
    description = [NSMutableString string];
    
    //start JSON
    [description appendString:@"{"];
    
    //add event
    [description appendString:@"\"event\":"];
    
    //add event
    switch(self.event)
    {
        //create
        case ES_EVENT_TYPE_NOTIFY_CREATE:
            [description appendString:@"\"ES_EVENT_TYPE_NOTIFY_CREATE\","];
            break;
            
        //open
        case ES_EVENT_TYPE_NOTIFY_OPEN:
            [description appendString:@"\"ES_EVENT_TYPE_NOTIFY_OPEN\","];
            break;
            
        //write
        case ES_EVENT_TYPE_NOTIFY_WRITE:
            [description appendString:@"\"ES_EVENT_TYPE_NOTIFY_WRITE\","];
            break;
            
        //close
        case ES_EVENT_TYPE_NOTIFY_CLOSE:
            [description appendString:@"\"ES_EVENT_TYPE_NOTIFY_CLOSE\","];
            break;
            
        //rename
        case ES_EVENT_TYPE_NOTIFY_RENAME:
            [description appendString:@"\"ES_EVENT_TYPE_NOTIFY_RENAME\","];
            break;
            
        //link
        case ES_EVENT_TYPE_NOTIFY_LINK:
            [description appendString:@"\"ES_EVENT_TYPE_NOTIFY_LINK\","];
            break;
            
        //unlink
        case ES_EVENT_TYPE_NOTIFY_UNLINK:
            [description appendString:@"\"ES_EVENT_TYPE_NOTIFY_UNLINK\","];
            break;
            
        default:
            break;
    }
    
    //add timestamp
    [description appendFormat:@"\"timestamp\":\"%@\",", self.timestamp];
    
    //start file
    [description appendString:@"\"file\":{"];
    
    //src path
    // option, so check
    if(0 != self.sourcePath)
    {
        //add
        [description appendFormat: @"\"source\":\"%@\",", self.sourcePath];
    }
   
    //dest path
    [description appendFormat: @"\"destination\":\"%@\",", self.destinationPath];
    
    //add process
    [description appendFormat: @"%@", self.process];
    
    //terminate file
    [description appendString:@"}"];
    
    //terminate entire JSON
    [description appendString:@"}"];

    return description;
}

@end
