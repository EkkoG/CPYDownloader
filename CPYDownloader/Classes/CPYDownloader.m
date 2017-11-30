//
//  CPYDownloader.m
//  Pods
//
//  Created by ciel on 2017/11/26.
//

#import "CPYDownloader.h"
#import <AFNetworking/AFNetworking.h>

@interface CPYDownloaderResponseHandler : NSObject

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) CPYDownloadProgressBlock progressBlock;
@property (nonatomic, copy) CPYDownloadDestinationBlock destinationBlock;
@property (nonatomic, copy) CPYDownloadValidationBlock validationBlock;
@property (nonatomic, copy) CPYDownloadSuccessBlock successBlock;
@property (nonatomic, copy) CPYDownloadFailureBlock failureBlock;

@end

@implementation CPYDownloaderResponseHandler

- (instancetype)initWithIdentifier:(NSString * _Nullable)identifier
                          progress:(CPYDownloadProgressBlock)progress
                        validation:(CPYDownloadValidationBlock)validation
                       destination:(CPYDownloadDestinationBlock)destination
                           success:(CPYDownloadSuccessBlock)success
                           failure:(CPYDownloadFailureBlock)failure {
    self = [super init];
    if (self) {
        self.identifier = identifier;
        self.progressBlock = progress;
        self.validationBlock = validation;
        self.destinationBlock = destination;
        self.successBlock = success;
        self.failureBlock = failure;
    }
    return self;
}

@end

@interface CPYDownloaderTask : NSObject        

@property (nonatomic, strong) NSURLSessionDownloadTask *task;
@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, strong) NSMutableArray <CPYDownloaderResponseHandler *> *responseHandlers;

@end

@implementation CPYDownloaderTask

- (instancetype)initWithURL:(NSURL *)URL identifier:(NSString *)identifier task:(NSURLSessionDownloadTask *)task
{
    self = [super init];
    if (self) {
        self.URL = URL;
        self.identifier = identifier;
        self.task = task;
        self.responseHandlers = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)addResponseHandler:(CPYDownloaderResponseHandler *)handler {
    [self.responseHandlers addObject:handler];
}

- (void)removeResponseHandler:(CPYDownloaderResponseHandler *)handler {
    [self.responseHandlers removeObject:handler];
}

@end

@interface CPYDownloadReceipt ()

@property (nonatomic, assign, readwrite) NSURLSessionTaskState state;
@property (nonatomic, strong, readwrite) NSURLSessionDownloadTask *task;
@property (nonatomic, copy, readwrite) NSString *receiptID;

@end

@implementation CPYDownloadReceipt

- (instancetype)initWithReceiptID:(NSString *)receiptID task:(NSURLSessionDownloadTask *)task {
    self = [super init];
    if (self) {
        self.receiptID = receiptID;
        self.task = task;
    }
    return self;
}

- (NSURLSessionTaskState)state {
    return self.task.state;
}

@end

@interface CPYDownloader ()

@property (nonatomic, strong) dispatch_queue_t synchronizationQueue;
@property (nonatomic, strong) dispatch_queue_t responseQueue;

@property (nonatomic, strong, readwrite) AFHTTPSessionManager *sessionManager;
@property (nonatomic, assign, readwrite) CPYDownloadPrioritization downloadPrioritization;

@property (nonatomic, assign, readwrite) NSUInteger maximumActiveDownloads;
@property (nonatomic, assign, readwrite) NSInteger activeDownloadTaskCount;
@property (nonatomic, strong, readwrite) NSMutableArray *queuedMergedTasks;
@property (nonatomic, strong, readwrite) NSMutableDictionary *mergedTasks;

@end

@implementation CPYDownloader

+ (instancetype)defaultInstance {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    NSURLSessionConfiguration *defaultConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    AFHTTPSessionManager *sessionManager = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:defaultConfiguration];
    sessionManager.responseSerializer = [AFHTTPResponseSerializer serializer];

    return [self initWithSessionManager:sessionManager downloadPrioritization:CPYDownloadPrioritizationFIFO maximumActiveDownloads:3];
}

- (instancetype)initWithSessionManager:(AFHTTPSessionManager *)sessionManager
                downloadPrioritization:(CPYDownloadPrioritization)downloadPrioritization
                maximumActiveDownloads:(NSUInteger)maximumActiveDownloads {
    self = [super init];
    if (self) {
        self.sessionManager = sessionManager;
        self.downloadPrioritization = downloadPrioritization;
        self.maximumActiveDownloads = maximumActiveDownloads;
        
        self.queuedMergedTasks = [[NSMutableArray alloc] init];
        self.mergedTasks = [[NSMutableDictionary alloc] init];
        self.activeDownloadTaskCount = 0;
        
        NSString *name = [NSString stringWithFormat:@"com.cielpy.downloader.synchronizationqueue-%@", [[NSUUID UUID] UUIDString]];
        self.synchronizationQueue = dispatch_queue_create([name cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_SERIAL);
        
        name = [NSString stringWithFormat:@"com.cielpy.downloader.responsequeue-%@", [[NSUUID UUID] UUIDString]];
        self.responseQueue = dispatch_queue_create([name cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}


- (CPYDownloadReceipt *)downloadFileWithURL:(NSURL *)URL
                                   progress:(CPYDownloadProgressBlock)progress
                                 validation:(CPYDownloadValidationBlock)validation
                                destination:(CPYDownloadDestinationBlock)destination
                                    success:(CPYDownloadSuccessBlock)success
                                    failure:(CPYDownloadFailureBlock)failure {
    __block NSURLSessionDownloadTask *task;
    
    NSString *receiptIdentifier = [NSUUID UUID].UUIDString;

    dispatch_sync(self.synchronizationQueue, ^{
        NSString *taskIdentifier = [NSUUID UUID].UUIDString;
        
        CPYDownloaderTask *existingTask = [self taskForURL:URL];
        if (existingTask) {
            CPYDownloaderResponseHandler *handler = [[CPYDownloaderResponseHandler alloc] initWithIdentifier:receiptIdentifier progress:progress validation:validation destination:destination success:success failure:failure];
            [existingTask addResponseHandler:handler];
            task = existingTask.task;
            return;
        }
        
        NSURLRequest *request = [NSURLRequest requestWithURL:URL];
        
        NSURLSessionDownloadTask *downloadTask = [self createTaskWithRequest:request identifier:taskIdentifier progress:progress validation:validation destination:destination success:success failure:failure];
        
        CPYDownloaderTask *mergedTask = [[CPYDownloaderTask alloc] initWithURL:URL identifier:taskIdentifier task:downloadTask];
        CPYDownloaderResponseHandler *handler = [[CPYDownloaderResponseHandler alloc] initWithIdentifier:taskIdentifier progress:progress validation:validation destination:destination success:success failure:failure];
        [mergedTask addResponseHandler:handler];
        
        self.mergedTasks[URL.absoluteString] = mergedTask;

        if ([self isActiveRequestCountBelowMaximumLimit]) {
            [self startTask:mergedTask];
        }
        else {
            [self enqueueTask:mergedTask];
        }
        
        task = downloadTask;
    });

    if (task) {
        CPYDownloadReceipt *receipt = [[CPYDownloadReceipt alloc] initWithReceiptID:receiptIdentifier task:task];
        
        return receipt;
    }
    return nil;
}

- (NSURLSessionDownloadTask *)createTaskWithRequest:(NSURLRequest *)request
                                         identifier:(NSString *)identifier
                                           progress:(CPYDownloadProgressBlock)progress
                                         validation:(CPYDownloadValidationBlock)validation
                                        destination:(CPYDownloadDestinationBlock)destination
                                            success:(CPYDownloadSuccessBlock)success
                                            failure:(CPYDownloadFailureBlock)failure {
    return [self.sessionManager downloadTaskWithRequest:request progress:^(NSProgress *downloadProgress) {
        CPYDownloaderTask *task = [self taskForURL:request.URL];
        for (CPYDownloaderResponseHandler *handler in task.responseHandlers) {
            dispatch_async(self.callbackQueue, ^{
                handler.progressBlock(downloadProgress, request);
            });
        }
    } destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
        return [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:[response suggestedFilename]];
    } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
        dispatch_async(self.responseQueue, ^{
            CPYDownloaderTask *task = self.mergedTasks[request.URL.absoluteString];
            if (![task.identifier isEqualToString:identifier]) {
                return;
            }
            
            [self removeTaskWithURL:request.URL];
            
            if (error) {
                for (CPYDownloaderResponseHandler *handler in task.responseHandlers) {
                    dispatch_async(self.callbackQueue, ^{
                        handler.failureBlock(request, (NSHTTPURLResponse *)response, error);
                    });
                }
                return;
            }
            for (CPYDownloaderResponseHandler *handler in task.responseHandlers) {
                void (^moveFileIfNeedBlock)(void) = ^{
                    if (!handler.destinationBlock) {
                        dispatch_async(self.callbackQueue, ^{
                            handler.successBlock(request, (NSHTTPURLResponse *)response, request.URL);
                        });
                        return;
                    }
                    
                    NSURL *destinationURL = handler.destinationBlock(filePath, response);
                    if (!destinationURL) {
                        dispatch_async(self.callbackQueue, ^{
                            handler.successBlock(request, (NSHTTPURLResponse *)response, request.URL);
                        });
                        return;
                    }
                    
                    NSError *fileManagerError;
                    if ([[NSFileManager defaultManager] fileExistsAtPath:destinationURL.path]) {
                        [[NSFileManager defaultManager] removeItemAtPath:destinationURL.path error:&fileManagerError];
                    }
                    
                    if (fileManagerError) {
                        dispatch_async(self.callbackQueue, ^{
                            handler.failureBlock(request, (NSHTTPURLResponse *)response, [NSError errorWithDomain:CPYDownloaderErrorDomain code:CPYDownloaderErrorFailToMoveFile userInfo:fileManagerError.userInfo]);
                        });
                        return;
                    }
                    
                    [[NSFileManager defaultManager] moveItemAtURL:filePath toURL:destinationURL error:&fileManagerError];
                    if (fileManagerError) {
                        dispatch_async(self.callbackQueue, ^{
                            handler.failureBlock(request, (NSHTTPURLResponse *)response, [NSError errorWithDomain:CPYDownloaderErrorDomain code:CPYDownloaderErrorFailToMoveFile userInfo:fileManagerError.userInfo]);
                        });
                        return;
                    }
                    
                    dispatch_async(self.callbackQueue, ^{
                        handler.successBlock(request, (NSHTTPURLResponse *)response, request.URL);
                    });
                };
                
                if (!handler.validationBlock) {
                    moveFileIfNeedBlock();
                    break;
                }
                
                __block BOOL valid = NO;
                dispatch_sync(self.callbackQueue, ^{
                   valid = handler.validationBlock(filePath, (NSHTTPURLResponse *)response);
                });
                
                if (!valid) {
                    dispatch_async(self.callbackQueue, ^{
                        NSString *failureReason = [NSString stringWithFormat:@"File validation failed: %@", request.URL];
                        NSDictionary *userInfo = @{NSLocalizedFailureReasonErrorKey:failureReason};
                        NSError *error = [NSError errorWithDomain:CPYDownloaderErrorDomain code:CPYDownloaderErrorInvalid userInfo:userInfo];
                        handler.failureBlock(request, (NSHTTPURLResponse *)response, error);
                    });
                    break;
                }
                
                moveFileIfNeedBlock();
            }
            [self finishTask:task];
            [self startNextTask];
        });
    }];
}

- (void)cancelDownloadWithReceipt:(CPYDownloadReceipt *)receipt {
    dispatch_sync(self.synchronizationQueue, ^{
        NSURL *URL = receipt.task.originalRequest.URL;
        CPYDownloaderTask *task = [self taskForURL:URL];
        NSUInteger index = [task.responseHandlers indexOfObjectPassingTest:^BOOL(CPYDownloaderResponseHandler * _Nonnull handler, NSUInteger idx, BOOL * _Nonnull stop) {
            return [handler.identifier isEqualToString:receipt.receiptID];
        }];
        
        if (index != NSNotFound) {
            CPYDownloaderResponseHandler *handler = task.responseHandlers[index];
            [task removeResponseHandler:handler];
            
            NSString *failureReason = [NSString stringWithFormat:@"Downloader cancelled URL request: %@",receipt.task.originalRequest.URL.absoluteString];
            NSDictionary *userInfo = @{NSLocalizedFailureReasonErrorKey:failureReason};
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:userInfo];
            if (handler.failureBlock) {
                dispatch_async(self.callbackQueue, ^{
                    handler.failureBlock(receipt.task.originalRequest, nil, error);
                });
            }
        }
        
        if (task.responseHandlers.count == 0 && task.task.state == NSURLSessionTaskStateSuspended) {
            [task.task cancel];
            [self removeTaskWithURL:URL];
        }
    });
}

#pragma mark - private

- (void)finishTask:(CPYDownloaderTask *)task {
    dispatch_sync(self.synchronizationQueue, ^{
        if (self.activeDownloadTaskCount > 0) {
            self.activeDownloadTaskCount -= 1;
        }
    });
}

- (void)startNextTask {
    dispatch_sync(self.synchronizationQueue, ^{
        if (![self isActiveRequestCountBelowMaximumLimit]) {
            return;
        }
        
        while (self.queuedMergedTasks.count > 0) {
            CPYDownloaderTask *task = [self dequeueTask];
            if (task.task.state == NSURLSessionTaskStateSuspended) {
                [self startTask:task];
                break;
            }
        }
    });
}

- (void)startTask:(CPYDownloaderTask *)task {
    [task.task resume];
    self.activeDownloadTaskCount += 1;
}

- (void)enqueueTask:(CPYDownloaderTask *)task {
    switch (self.downloadPrioritization) {
        case CPYDownloadPrioritizationFIFO:
            [self.queuedMergedTasks addObject:task];
            break;
        case CPYDownloadPrioritizationLIFO:
            [self.queuedMergedTasks insertObject:task atIndex:0];
            break;
            
        default:
            break;
    }
}

- (CPYDownloaderTask *)dequeueTask {
    CPYDownloaderTask *task = self.queuedMergedTasks.firstObject;
    [self.queuedMergedTasks removeObject:task];
    return task;
}

- (CPYDownloaderTask *)taskForURL:(NSURL *)URL {
    return self.mergedTasks[URL.absoluteString];
}

- (BOOL)isActiveRequestCountBelowMaximumLimit {
    return self.activeDownloadTaskCount < self.maximumActiveDownloads;
}

- (CPYDownloaderTask *)removeTaskWithURL:(NSURL *)URL {
    __block CPYDownloaderTask *task;
    dispatch_sync(self.synchronizationQueue, ^{
        task = [self removeMergedTaskWithURL:URL];
    });
    return task;
}

- (CPYDownloaderTask *)removeMergedTaskWithURL:(NSURL *)URL {
    CPYDownloaderTask *task = [self taskForURL:URL];
    self.mergedTasks[URL.absoluteString] = nil;
    return task;
}

- (dispatch_queue_t)callbackQueue {
    if (!_callbackQueue) {
        return dispatch_get_main_queue();
    }
    return _callbackQueue;
}

@end
