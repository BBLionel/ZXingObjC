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

#import "ZXAI01392xDecoder.h"
#import "ZXBitArray.h"
#import "ZXDecodedInformation.h"
#import "ZXErrors.h"
#import "ZXGeneralAppIdDecoder.h"

NSInteger const AI01392x_HEADER_SIZE = 5 + 1 + 2;
NSInteger const AI01392x_LAST_DIGIT_SIZE = 2;

@implementation ZXAI01392xDecoder

- (NSString *)parseInformationWithError:(NSError **)error {
  if (self.information.size < AI01392x_HEADER_SIZE + GTIN_SIZE) {
    if (error) *error = NotFoundErrorInstance();
    return nil;
  }
  NSMutableString *buf = [NSMutableString string];
  [self encodeCompressedGtin:buf currentPos:AI01392x_HEADER_SIZE];
  NSInteger lastAIdigit = [self.generalDecoder extractNumericValueFromBitArray:AI01392x_HEADER_SIZE + GTIN_SIZE bits:AI01392x_LAST_DIGIT_SIZE];
  [buf appendFormat:@"(392%ld)", (long)lastAIdigit];
  ZXDecodedInformation *decodedInformation = [self.generalDecoder decodeGeneralPurposeField:AI01392x_HEADER_SIZE + GTIN_SIZE + AI01392x_LAST_DIGIT_SIZE remaining:nil];
  [buf appendString:decodedInformation.theNewString];
  return buf;
}

@end
