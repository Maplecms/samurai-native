//
//     ____    _                        __     _      _____
//    / ___\  /_\     /\/\    /\ /\    /__\   /_\     \_   \
//    \ \    //_\\   /    \  / / \ \  / \//  //_\\     / /\/
//  /\_\ \  /  _  \ / /\/\ \ \ \_/ / / _  \ /  _  \ /\/ /_
//  \____/  \_/ \_/ \/    \/  \___/  \/ \_/ \_/ \_/ \____/
//
//	Copyright Samurai development team and other contributors
//
//	http://www.samurai-framework.com
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights
//	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//	copies of the Software, and to permit persons to whom the Software is
//	furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in
//	all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//	THE SOFTWARE.
//

#import "STIHTTPNetwork.h"
#import "AutoCoding.h"
#import "NSObject+AutoCoding.h"
#import "AFNetworking.h"

#pragma mark -

@implementation STIHTTPBaseObject

- (BOOL)isValidated
{
    return YES;
}

- (NSString *)description
{
    return [[self dictionaryRepresentation] description];
}

@end

#pragma mark -

static STIHTTPSessionManager * kGlobalHTTPSessionManager = nil;

@implementation STIHTTPApi

+ (void)setGlobalHTTPSessionManager:(STIHTTPSessionManager *)HTTPSessionManager
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kGlobalHTTPSessionManager = HTTPSessionManager;
    });
}

- (void)dealloc
{
    [self cancel];
}

- (STIHTTPSessionManager *)HTTPSessionManager
{
    if ( _HTTPSessionManager == nil ) {
        return kGlobalHTTPSessionManager;
    }
    // TODO: nil check
    return _HTTPSessionManager;
}

- (id)processedDataWithResponseObject:(id)responseObject task:(NSURLSessionDataTask *)task
{
    // By default, just make the HTTPSessionManager process data
    return [self.HTTPSessionManager processedDataWithResponseObject:responseObject task:task];
}

- (void)handleError:(NSError *)error responseObject:(id)responseObject task:(NSURLSessionDataTask *)task failureBlock:(void (^)(id, id))failureBlock
{
    // By default, just make the HTTPSessionManager handle error
    [self.HTTPSessionManager handleError:error responseObject:responseObject task:task failureBlock:failureBlock];
}

- (void)send
{
    if ( self.HTTPSessionManager.setup ) {
        self.HTTPSessionManager.setup(nil);
    }

    self.task = [self.HTTPSessionManager method:self.req.method
                           endpoint:self.req.endpoint
                         parameters:self.req.parameters
                            success:^(NSURLSessionDataTask *task, id responseObject) {
                                self.resp = [self.req.responseClass ac_objectWithAny:[self processedDataWithResponseObject:responseObject task:task]];
                                self.responseObject = responseObject;
                                if ( self.whenUpdated ) {
                                    self.whenUpdated( self.resp, nil );
                                }
                            }
                            failure:^(NSURLSessionDataTask *task, id responseObject, NSError *error) {
                                if ( NSURLErrorCancelled == error.code )
                                {
                                    if ( self.whenCanceled )
                                    {
                                        self.whenCanceled();
                                    }
                                }
                                else
                                {
                                    [self.HTTPSessionManager handleError:error responseObject:responseObject task:task failureBlock:self.whenUpdated];
                                }
                            }];
}

- (void)cancel
{
    if ( self.task )
    {
        switch ( self.task.state )
        {
            case NSURLSessionTaskStateRunning:
            case NSURLSessionTaskStateSuspended:
                [self.task cancel];
                break;
            case NSURLSessionTaskStateCanceling:
            case NSURLSessionTaskStateCompleted:
                break;
        }
    }
}

@end

#pragma mark -

@interface STIHTTPRequest()
@end

#pragma mark -

@implementation STIHTTPRequest

@synthesize method = _method;
@synthesize endpoint = _endpoint;

- (instancetype)init
{
    self = [super init];
    if (self) {
        NSAssert(NO, @"You should use [STIHTTPRequest initWithEndpoint:] instead.");
    }
    return self;
}

- (instancetype)initWithEndpoint:(NSString *)endpoint method:(STIHTTPRequestMethod)method
{
    self = [super init];
    if (self) {
        _endpoint = endpoint;
        _method = method;
    }
    return self;
}

+ (instancetype)requestWithEndpoint:(NSString *)endpoint method:(STIHTTPRequestMethod)method
{
    return [[self alloc] initWithEndpoint:endpoint method:method];
}

- (NSDictionary *)parameters
{
    NSDictionary * parameters = [self dictionaryRepresentation];
	return parameters.count ? parameters : nil;
}

- (NSString *)endpoint
{
    NSAssert(_endpoint && _endpoint.length, @"Are you kiding ?! The URI endpoint for requset should not be empty");

    if ( [_endpoint hasPrefix:@"/"] ) {
        _endpoint = [_endpoint substringFromIndex:1];
    }
    
    NSArray * partials = [_endpoint componentsSeparatedByString:@"/"];

    NSArray * targets = [partials filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF beginswith[c] ':'"]];

    __block NSMutableString * path = [_endpoint mutableCopy];
    
    [targets enumerateObjectsUsingBlock:^(NSString * str, __unused NSUInteger idx, __unused BOOL *stop) {
        
        NSString * keyPath = [str stringByReplacingOccurrencesOfString:@":" withString:@""];
        keyPath = [keyPath stringByDeletingPathExtension];
        
        NSString * param = [self valueForKeyPath:keyPath];
        
        [path replaceOccurrencesOfString:str
                              withString:[param description]
                                 options:NSCaseInsensitiveSearch
                                   range:NSMakeRange(0, path.length)];
    }];
    
    return path;
}

@end

#pragma mark -

@implementation STIHTTPResponse

- (BOOL)isValidated
{
    return YES;
}

@end

#pragma mark -

@implementation STIHTTPResponseError
@end

