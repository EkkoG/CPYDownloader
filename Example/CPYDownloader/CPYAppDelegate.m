//
//  CPYAppDelegate.m
//  CPYDownloader
//
//  Created by cielpy on 11/26/2017.
//  Copyright (c) 2017 cielpy. All rights reserved.
//

#import "CPYAppDelegate.h"
#import <CPYDownloader/CPYDownloader.h>

@interface CPYAppDelegate ()

@end

@implementation CPYAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSArray *arr = @[
                     @"https://github.com/AFNetworking/AFNetworking/archive/master.zip",
                     @"https://wx2.sinaimg.cn/mw690/625aa557gy1flvutnodiaj22bc17su0y.jpg",
                     @"https://wx1.sinaimg.cn/mw690/b7cd25degy1flvv7pel1lj21kw11x10e.jpg",
                     @"https://wx2.sinaimg.cn/mw690/b7cd25degy1flvv7rh8f5j21kw11xjz6.jpg",
                     @"https://wx3.sinaimg.cn/mw690/61e89b74ly1flvv1ysznkj20c80lqac1.jpg",
                     @"https://wx1.sinaimg.cn/mw690/677e4af2ly1flvg1c3wmsj20j60j5dj7.jpg"
                     ];
    NSMutableArray *receipts = [NSMutableArray array];
    for (NSString *url in arr) {
        [[CPYDownloader defaultInstance] setLogLevel:CPYDownloaderLogLevelDebug];
        CPYDownloadReceipt *receipt = [[CPYDownloader defaultInstance] downloadFileWithURL:[NSURL URLWithString:url] progress:^(NSProgress * _Nonnull progress, NSURLRequest * _Nullable request) {
            
            NSLog(@"progress %@", progress);
        } validation:^BOOL(NSURL * _Nonnull fileURL, NSURLResponse * _Nullable response) {
            return YES;
        } destination:^NSURL * _Nullable(NSURL * _Nonnull URL, NSURLResponse * _Nullable response) {
            return nil;
        } success:^(NSURLRequest * _Nullable request, NSHTTPURLResponse * _Nullable response, NSURL * _Nonnull URL) {
            
        } failure:^(NSURLRequest * _Nullable request, NSHTTPURLResponse * _Nullable response, NSError * _Nonnull error) {
            
        }];
        [receipts addObject:receipt];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[CPYDownloader defaultInstance] cancelDownloadWithReceipt:receipts.firstObject];
    });
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
