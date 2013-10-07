/*
 * Copyright 2013 ZXing authors
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

#import "ZXPDF417BarcodeMetadata.h"
#import "ZXPDF417BarcodeValue.h"
#import "ZXPDF417BoundingBox.h"
#import "ZXPDF417Codeword.h"
#import "ZXPDF417DetectionResult.h"
#import "ZXPDF417DetectionResultRowIndicatorColumn.h"
#import "ZXResultPoint.h"

const NSInteger MIN_BARCODE_ROWS = 3;
const NSInteger MAX_BARCODE_ROWS = 90;

@interface ZXPDF417DetectionResultRowIndicatorColumn ()

@property (nonatomic, assign) BOOL isLeft;

@end

@implementation ZXPDF417DetectionResultRowIndicatorColumn

- (id)initWithBoundingBox:(ZXPDF417BoundingBox *)boundingBox isLeft:(BOOL)isLeft {
  self = [super initWithBoundingBox:boundingBox];
  if (self) {
    _isLeft = isLeft;
  }

  return self;
}

- (void)setRowNumbers {
  for (ZXPDF417Codeword *codeword in [self codewords]) {
    if ((id)codeword != [NSNull null]) {
      [codeword setRowNumberAsRowIndicatorColumn];
    }
  }
}

- (NSArray *)rowHeights {
  ZXPDF417BarcodeMetadata *barcodeMetadata = [self barcodeMetadata];
  if (!barcodeMetadata) {
    return nil;
  }
  [self adjustIndicatorColumnRowNumbers:barcodeMetadata];
  NSMutableArray *result = [NSMutableArray arrayWithCapacity:barcodeMetadata.rowCount];
  for (NSInteger i = 0; i < barcodeMetadata.rowCount; i++) {
    [result addObject:@0];
  }

  for (ZXPDF417Codeword *codeword in [self codewords]) {
    if ((id)codeword != [NSNull null]) {
      result[codeword.rowNumber] = @([result[codeword.rowNumber] intValue] + 1);
    }
  }
  return result;

}

// TODO maybe we should add missing codewords to store the correct row number to make
// finding row numbers for other columns easier
// use row height count to make detection of invalid row numbers more reliable
- (NSInteger)adjustIndicatorColumnRowNumbers:(ZXPDF417BarcodeMetadata *)barcodeMetadata {
  ZXResultPoint *top = self.isLeft ? self.boundingBox.topLeft : self.boundingBox.topRight;
  ZXResultPoint *bottom = self.isLeft ? self.boundingBox.bottomLeft : self.boundingBox.bottomRight;
  NSInteger firstRow = [self codewordsIndex:(NSInteger) top.y];
  NSInteger lastRow = [self codewordsIndex:(NSInteger) bottom.y];
  float averageRowHeight = (lastRow - firstRow) / (float) barcodeMetadata.rowCount;
  NSInteger barcodeRow = -1;
  NSInteger maxRowHeight = 1;
  NSInteger currentRowHeight = 0;
  for (NSInteger codewordsRow = firstRow; codewordsRow < lastRow; codewordsRow++) {
    if (self.codewords[codewordsRow] == [NSNull null]) {
      continue;
    }
    ZXPDF417Codeword *codeword = self.codewords[codewordsRow];

    [codeword setRowNumberAsRowIndicatorColumn];

    // This only works if we have a complete RI column. If the RI column is cut off at the top or bottom, it
    // will calculate the wrong numbers and delete correct codewords. Could be used once the barcode height has
    // been calculated properly.
    //      float expectedRowNumber = (codewordsRow - firstRow) / averageRowHeight;
    //      if (Math.abs(codeword.getRowNumber() - expectedRowNumber) > 2) {
    //        SimpleLog.log(LEVEL.WARNING,
    //            "Removing codeword, rowNumberSkew too high, codeword[" + codewordsRow + "]: Expected Row: " +
    //                expectedRowNumber + ", RealRow: " + codeword.getRowNumber() + ", value: " + codeword.getValue());
    //        codewords[codewordsRow] = null;
    //      }

    NSInteger rowDifference = codeword.rowNumber - barcodeRow;

    // TODO improve handling with case where first row indicator doesn't start with 0

    if (rowDifference == 0) {
      currentRowHeight++;
    } else if (rowDifference == 1) {
      maxRowHeight = MAX(maxRowHeight, currentRowHeight);
      currentRowHeight = 1;
      barcodeRow = codeword.rowNumber;
    } else if (rowDifference < 0) {
      self.codewords[codewordsRow] = [NSNull null];
    } else if (codeword.rowNumber >= barcodeMetadata.rowCount) {
      self.codewords[codewordsRow] = [NSNull null];
    } else if (rowDifference > codewordsRow) {
      self.codewords[codewordsRow] = [NSNull null];
    } else {
      NSInteger checkedRows;
      if (maxRowHeight > 2) {
        checkedRows = (maxRowHeight - 2) * rowDifference;
      } else {
        checkedRows = rowDifference;
      }
      BOOL closePreviousCodewordFound = checkedRows >= codewordsRow;
      for (NSInteger i = 1; i <= checkedRows && !closePreviousCodewordFound; i++) {
        // there must be (height * rowDifference) number of codewords missing. For now we assume height = 1.
        // This should hopefully get rid of most problems already.
        closePreviousCodewordFound = self.codewords[codewordsRow - i] != [NSNull null];
      }
      if (closePreviousCodewordFound) {
        self.codewords[codewordsRow] = [NSNull null];
      } else {
        barcodeRow = codeword.rowNumber;
        currentRowHeight = 1;
      }
    }
  }
  return (NSInteger) (averageRowHeight + 0.5);
}

- (ZXPDF417BarcodeMetadata *)barcodeMetadata {
  ZXPDF417BarcodeValue *barcodeColumnCount = [[ZXPDF417BarcodeValue alloc] init];
  ZXPDF417BarcodeValue *barcodeRowCountUpperPart = [[ZXPDF417BarcodeValue alloc] init];
  ZXPDF417BarcodeValue *barcodeRowCountLowerPart = [[ZXPDF417BarcodeValue alloc] init];
  ZXPDF417BarcodeValue *barcodeECLevel = [[ZXPDF417BarcodeValue alloc] init];
  for (ZXPDF417Codeword *codeword in self.codewords) {
    if ((id)codeword == [NSNull null]) {
      continue;
    }
    [codeword setRowNumberAsRowIndicatorColumn];
    NSInteger rowIndicatorValue = codeword.value % 30;
    NSInteger codewordRowNumber = codeword.rowNumber;
    if (!self.isLeft) {
      codewordRowNumber += 2;
    }
    switch (codewordRowNumber % 3) {
      case 0:
        [barcodeRowCountUpperPart setValue:rowIndicatorValue * 3 + 1];
        break;
      case 1:
        [barcodeECLevel setValue:rowIndicatorValue / 3];
        [barcodeRowCountLowerPart setValue:rowIndicatorValue % 3];
        break;
      case 2:
        [barcodeColumnCount setValue:rowIndicatorValue + 1];
        break;
    }
  }
  if (![barcodeColumnCount value] || ![barcodeRowCountUpperPart value] ||
      ![barcodeRowCountLowerPart value] || ![barcodeECLevel value] ||
      [[barcodeColumnCount value] intValue] < 1 ||
      [[barcodeRowCountUpperPart value] intValue] + [[barcodeRowCountLowerPart value] intValue] < MIN_BARCODE_ROWS ||
      [[barcodeRowCountUpperPart value] intValue] + [[barcodeRowCountLowerPart value] intValue] > MAX_BARCODE_ROWS) {
    return nil;
  }
  ZXPDF417BarcodeMetadata *barcodeMetadata = [[ZXPDF417BarcodeMetadata alloc] initWithColumnCount:[[barcodeColumnCount value] intValue]
                                                                                rowCountUpperPart:[[barcodeRowCountUpperPart value] intValue]
                                                                                rowCountLowerPart:[[barcodeRowCountLowerPart value] intValue]
                                                                             errorCorrectionLevel:[[barcodeECLevel value] intValue]];
  [self removeIncorrectCodewords:barcodeMetadata];
  return barcodeMetadata;
}

- (void)removeIncorrectCodewords:(ZXPDF417BarcodeMetadata *)barcodeMetadata {
  // Remove codewords which do not match the metadata
  // TODO Maybe we should keep the incorrect codewords for the start and end positions?
  for (NSInteger codewordRow = 0; codewordRow < [self.codewords count]; codewordRow++) {
    ZXPDF417Codeword *codeword = self.codewords[codewordRow];
    if (self.codewords[codewordRow] == [NSNull null]) {
      continue;
    }
    NSInteger rowIndicatorValue = codeword.value % 30;
    NSInteger codewordRowNumber = codeword.rowNumber;
    if (codewordRowNumber > barcodeMetadata.rowCount) {
      self.codewords[codewordRow] = [NSNull null];
      continue;
    }
    if (!self.isLeft) {
      codewordRowNumber += 2;
    }
    switch (codewordRowNumber % 3) {
      case 0:
        if (rowIndicatorValue * 3 + 1 != barcodeMetadata.rowCountUpperPart) {
          self.codewords[codewordRow] = [NSNull null];
        }
        break;
      case 1:
        if (rowIndicatorValue / 3 != barcodeMetadata.errorCorrectionLevel ||
            rowIndicatorValue % 3 != barcodeMetadata.rowCountLowerPart) {
          self.codewords[codewordRow] = [NSNull null];
        }
        break;
      case 2:
        if (rowIndicatorValue + 1 != barcodeMetadata.columnCount) {
          self.codewords[codewordRow] = [NSNull null];
        }
        break;
    }
  }
}

@end
