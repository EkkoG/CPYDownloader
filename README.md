[![CI Status](http://img.shields.io/travis/cielpy/CPYDownloader.svg?style=flat)](https://travis-ci.org/cielpy/CPYDownloader)
[![Version](https://img.shields.io/cocoapods/v/CPYDownloader.svg?style=flat)](http://cocoapods.org/pods/CPYDownloader)
[![License](https://img.shields.io/cocoapods/l/CPYDownloader.svg?style=flat)](http://cocoapods.org/pods/CPYDownloader)
[![Platform](https://img.shields.io/cocoapods/p/CPYDownloader.svg?style=flat)](http://cocoapods.org/pods/CPYDownloader)

CPYDownloader is a simple multi task file downloader inspire by AFImageDownloader. It build on [AFNetworking](https://github.com/AFNetworking/AFNetworking).

## Usage

```
[[CPYDownloader defaultInstance] downloadFileWithURL:[NSURL URLWithString:url] progress:^(NSProgress * _Nonnull progress, NSURLRequest * _Nullable request) {
    NSLog(@"progress %@", progress);
} validation:^BOOL(NSURL * _Nonnull fileURL, NSURLResponse * _Nullable response) {
	  // verify the downloaded file
    return YES;
} destination:^NSURL * _Nullable(NSURL * _Nonnull URL, NSURLResponse * _Nullable response) {
    // move the file to somewhere
    return nil;
} success:^(NSURLRequest * _Nullable request, NSHTTPURLResponse * _Nullable response, NSURL * _Nonnull URL) {
    
} failure:^(NSURLRequest * _Nullable request, NSHTTPURLResponse * _Nullable response, NSError * _Nonnull error) {
    
}];

```

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

- iOS 8+

## Installation

CPYDownloader is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'CPYDownloader'
```

## Author

cielpy, beijiu572@gmail.com

## License

CPYDownloader is available under the MIT license. See the LICENSE file for more info.


