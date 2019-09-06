//
//  FileMonitor.m
//  FileMonitor
//
//  Created by Patrick Wardle on 9/1/19.
//  Copyright © 2019 Objective-See. All rights reserved.
//

//  Inspired by https://gist.github.com/Omar-Ikram/8e6721d8e83a3da69b31d4c2612a68ba
//  NOTE: requires a) root b) the 'com.apple.developer.endpoint-security.client' entitlement

#import "utilities.h"
#import "FileMonitor.h"

#import <Foundation/Foundation.h>
#import <EndpointSecurity/EndpointSecurity.h>

//endpoint
es_client_t *endpointClient = nil;

//file events of interest
NSDictionary* eventsOfInterest = nil;

@implementation FileMonitor

//init
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //init events of interest
        eventsOfInterest = @{[NSNumber numberWithInt:ES_EVENT_TYPE_NOTIFY_CREATE]:@"ES_EVENT_TYPE_NOTIFY_CREATE",
                            [NSNumber numberWithInt:ES_EVENT_TYPE_NOTIFY_OPEN]:@"ES_EVENT_TYPE_NOTIFY_OPEN",
                            [NSNumber numberWithInt:ES_EVENT_TYPE_NOTIFY_WRITE]:@"ES_EVENT_TYPE_NOTIFY_WRITE",
                            [NSNumber numberWithInt:ES_EVENT_TYPE_NOTIFY_CLOSE]:@"ES_EVENT_TYPE_NOTIFY_CLOSE",
                            [NSNumber numberWithInt:ES_EVENT_TYPE_NOTIFY_RENAME]:@"ES_EVENT_TYPE_NOTIFY_RENAME",
                            [NSNumber numberWithInt:ES_EVENT_TYPE_NOTIFY_LINK]:@"ES_EVENT_TYPE_NOTIFY_LINK",
                            [NSNumber numberWithInt:ES_EVENT_TYPE_NOTIFY_UNLINK]:@"ES_EVENT_TYPE_NOTIFY_UNLINK"};
        }
    
    return self;
}

//start monitoring
-(BOOL)start:(FileCallbackBlock)callback
{
    //flag
    BOOL started = NO;
    
    //events (as array)
    es_event_type_t* events = NULL;
    
    //result
    es_new_client_result_t result = 0;
    
    //alloc events
    events = malloc(sizeof(es_event_type_t) * eventsOfInterest.count);
    
    //init events
    // es_* APIs expect a C-array...
    for(int i = 0; i < eventsOfInterest.count; i++)
    {
        //add event
        events[i] = [eventsOfInterest.allKeys[i] intValue];
    }
    
    //sync
    @synchronized (self)
    {
    
    //create client
    // callback invokes (user) callback for new processes
    result = es_new_client(&endpointClient, ^(es_client_t *cleint, const es_message_t *message)
    {
        //new file event
        File* file = nil;
        
        //ignore non-notify messages
        if(ES_ACTION_TYPE_NOTIFY != message->action_type)
        {
            //ignore
            return;
        }
        
        //ignore non-msg's of interest
        if(nil == [eventsOfInterest objectForKey:[NSNumber numberWithInt:message->event_type]])
        {
            //ignore
            return;
        }
        
        //init process obj
        file = [[File alloc] init:(es_message_t* _Nonnull)message];
        if(nil != file)
        {
            //invoke user callback
            callback(file);
        }
    });
    
    //error?
    if(ES_NEW_CLIENT_RESULT_SUCCESS != result)
    {
        //err msg
        NSLog(@"ERROR: es_new_client() failed with %d", result);
        
        //bail
        goto bail;
    }
    
    //clear cache
    if(ES_CLEAR_CACHE_RESULT_SUCCESS != es_clear_cache(endpointClient))
    {
        //err msg
        NSLog(@"ERROR: es_clear_cache() failed");
        
        //bail
        goto bail;
    }
    
    //mute self
    // note: you might not want this, but for a cmdline-based filemonitor
    //       this ensures we don't constantly report writes to /dev/tty
    es_mute_path_literal(endpointClient, [NSProcessInfo.processInfo.arguments[0] UTF8String]);
    
    //subscribe
    if(ES_RETURN_SUCCESS != es_subscribe(endpointClient, events, (u_int32_t)eventsOfInterest.count))
    {
        //err msg
        NSLog(@"ERROR: es_subscribe() failed");
        
        //bail
        goto bail;
    }
        
    } //sync
    
    //happy
    started = YES;
    
bail:
    
    //free events
    if(NULL != events)
    {
        //free
        free(events);
        events = NULL;
    }
    
    return started;
}

//stop
-(BOOL)stop
{
    //flag
    BOOL stopped = NO;
    
    //sync
    @synchronized (self)
    {
        
    //unsubscribe & delete
    if(NULL != endpointClient)
    {
       //unsubscribe
       if(ES_RETURN_SUCCESS != es_unsubscribe_all(endpointClient))
       {
           //err msg
           NSLog(@"ERROR: es_unsubscribe_all() failed");
           
           //bail
           goto bail;
       }
       
       //delete
       if(ES_RETURN_SUCCESS != es_delete_client(endpointClient))
       {
           //err msg
           NSLog(@"ERROR: es_delete_client() failed");
           
           //bail
           goto bail;
       }
       
       //unset
       endpointClient = NULL;
       
       //happy
       stopped = YES;
    }
        
    } //sync
    
bail:
    
    return stopped;
}

@end

//helper function
// convert es_string_token_t to string
NSString* convertStringToken(es_string_token_t* stringToken)
{
    //string
    NSString* string = nil;
    
    //init to empty string
    string = [NSString string];
    
    //sanity check(s)
    if( (NULL == stringToken) ||
        (0 == stringToken->length) ||
        (NULL == stringToken->data) )
    {
        //bail
        goto bail;
    }
        
    //convert to data, then to string
    string = [NSString stringWithUTF8String:[[NSData dataWithBytes:stringToken->data length:stringToken->length] bytes]];
    
bail:
    
    return string;
}
