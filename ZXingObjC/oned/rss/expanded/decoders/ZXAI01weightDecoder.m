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

#import "ZXAI01weightDecoder.h"
#import "ZXGeneralAppIdDecoder.h"

@implementation ZXAI01weightDecoder

- (void)encodeCompressedWeight:(NSMutableString *)buf currentPos:(NSInteger)currentPos weightSize:(NSInteger)weightSize {
  NSInteger originalWeightNumeric = [self.generalDecoder extractNumericValueFromBitArray:currentPos bits:weightSize];
  [self addWeightCode:buf weight:originalWeightNumeric];

  NSInteger weightNumeric = [self checkWeight:originalWeightNumeric];

  NSInteger currentDivisor = 100000;
  for (NSInteger i = 0; i < 5; ++i) {
    if (weightNumeric / currentDivisor == 0) {
      [buf appendString:@"0"];
    }
    currentDivisor /= 10;
  }

  [buf appendFormat:@"%ld", (long)weightNumeric];
}

- (void)addWeightCode:(NSMutableString *)buf weight:(NSInteger)weight {
  @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                 reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
                               userInfo:nil];
}

- (NSInteger)checkWeight:(NSInteger)weight {
  @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                 reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
                               userInfo:nil];
}

@end
