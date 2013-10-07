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

@class ZXBarcodeRow;

/**
 * Holds all of the information for a barcode in a format where it can be easily accessable
 */
@interface ZXBarcodeMatrix : NSObject

@property (nonatomic, assign, readonly) NSInteger height;
@property (nonatomic, assign, readonly) NSInteger width;

- (id)initWithHeight:(NSInteger)height width:(NSInteger)width;
- (void)setX:(NSInteger)x y:(NSInteger)y value:(int8_t)value;
- (void)setMatrixX:(NSInteger)x y:(NSInteger)y black:(BOOL)black;
- (void)startRow;
- (ZXBarcodeRow *)currentRow;
- (int8_t **)matrixWithHeight:(NSInteger *)height width:(NSInteger *)width;
- (int8_t **)scaledMatrixWithHeight:(NSInteger *)height width:(NSInteger *)width scale:(NSInteger)scale;
- (int8_t **)scaledMatrixWithHeight:(NSInteger *)height width:(NSInteger *)width xScale:(NSInteger)xScale yScale:(NSInteger)yScale;

@end
