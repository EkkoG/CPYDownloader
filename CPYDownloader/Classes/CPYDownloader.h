//
//  CPYDownloader.h
//  Pods
//
//  Created by ciel on 2017/11/26.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class CPYDownloadReceipt;
@class AFHTTPSessionManager;

static NSString *const CPYDownloaderErrorDomain = @"CPYDownloaderErrorDomain";

typedef NS_ENUM(NSUInteger, CPYDownloaderError) {
    CPYDownloaderErrorInvalid,
    CPYDownloaderErrorFailToMoveFile,
};

/** The download prioritization */
typedef NS_ENUM(NSInteger, CPYDownloadPrioritization) {
    CPYDownloadPrioritizationFIFO,  /** first in first out */
    CPYDownloadPrioritizationLIFO   /** last in first out */
};

typedef void (^CPYDownloadSuccessBlock)(NSURLRequest * _Nullable request, NSHTTPURLResponse * _Nullable response, NSURL * _Nonnull URL);
typedef void (^CPYDownloadProgressBlock)(NSProgress * _Nonnull progress, NSURLRequest * _Nullable request);
typedef NSURL* _Nullable (^CPYDownloadDestinationBlock)(NSURL * _Nonnull URL, NSURLResponse *_Nullable response);
typedef BOOL (^CPYDownloadValidationBlock)(NSURL * _Nonnull fileURL, NSURLResponse *_Nullable response);
typedef void (^CPYDownloadFailureBlock)(NSURLRequest * _Nullable request, NSHTTPURLResponse * _Nullable response,  NSError * _Nonnull error);

@interface CPYDownloadReceipt : NSObject

@property (nonatomic, assign, readonly) NSURLSessionTaskState state;
/**
 The data task created by the `CPYDownloader`.
 
 WARMING!!! DO NOT CALL ANY METHOD DIRECTLY ON THE TASK ITSELF!!!
 */
@property (nonatomic, strong, readonly) NSURLSessionDownloadTask *task;

/**
 The unique identifier for the success and failure blocks when duplicate requests are made.
 */
@property (nonatomic, copy, readonly) NSString *receiptID;

@end

@interface CPYDownloader : NSObject

@property (nonatomic, strong, readonly) AFHTTPSessionManager *sessionManager;
@property (nonatomic, assign, readonly) CPYDownloadPrioritization downloadPrioritization;
@property (nonatomic, assign, readonly) NSUInteger maximumActiveDownloads;

@property (nonatomic, assign, readonly) NSInteger activeDownloadTaskCount;

@property (nonatomic, strong) dispatch_queue_t callbackQueue;

@property (nonatomic, assign) NSInteger remainingTask;

+ (instancetype)defaultInstance;

- (instancetype)init;

- (instancetype)initWithSessionManager:(AFHTTPSessionManager *)sessionManager
                downloadPrioritization:(CPYDownloadPrioritization)downloadPrioritization
                maximumActiveDownloads:(NSUInteger)maximumActiveDownloads NS_DESIGNATED_INITIALIZER;

- (CPYDownloadReceipt *)downloadFileWithURL:(NSURL *)URL
                                   progress:(CPYDownloadProgressBlock)progress
                                 validation:(CPYDownloadValidationBlock)validation
                                destination:(CPYDownloadDestinationBlock)destination
                                    success:(CPYDownloadSuccessBlock)success
                                    failure:(CPYDownloadFailureBlock)failure;

- (void)cancelDownloadWithReceipt:(CPYDownloadReceipt *)receipt;

@end

NS_ASSUME_NONNULL_END
