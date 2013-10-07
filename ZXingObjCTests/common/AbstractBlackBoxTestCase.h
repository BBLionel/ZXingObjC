/*
 * Copyright 2012 ZXing authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <SenTestingKit/SenTestingKit.h>

@interface AbstractBlackBoxTestCase : SenTestCase

@property (nonatomic, strong, readonly) id<ZXReader> barcodeReader;

- (id)initWithInvocation:(NSInvocation *)invocation testBasePathSuffix:(NSString *)testBasePathSuffix barcodeReader:(id<ZXReader>)barcodeReader expectedFormat:(ZXBarcodeFormat)expectedFormat;
+ (NSString *)barcodeFormatAsString:(ZXBarcodeFormat)format;
- (void)addTest:(NSInteger)mustPassCount tryHarderCount:(NSInteger)tryHarderCount rotation:(float)rotation;
- (void)addTest:(NSInteger)mustPassCount tryHarderCount:(NSInteger)tryHarderCount maxMisreads:(NSInteger)maxMisreads maxTryHarderMisreads:(NSInteger)maxTryHarderMisreads rotation:(float)rotation;
- (void)runTests;

- (NSArray *)imageFiles;
- (ZXImage *)rotateImage:(ZXImage *)original degrees:(float)degrees;

@end
