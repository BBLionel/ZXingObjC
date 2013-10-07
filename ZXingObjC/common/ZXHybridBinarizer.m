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

#import "ZXHybridBinarizer.h"

// This class uses 5x5 blocks to compute local luminance, where each block is 8x8 pixels.
// So this is the smallest dimension in each axis we can accept.
const NSInteger BLOCK_SIZE_POWER = 3;
const NSInteger BLOCK_SIZE = 1 << BLOCK_SIZE_POWER; // ...0100...00
const NSInteger BLOCK_SIZE_MASK = BLOCK_SIZE - 1;   // ...0011...11
const NSInteger MINIMUM_DIMENSION = BLOCK_SIZE * 5;
const NSInteger MIN_DYNAMIC_RANGE = 24;

@interface ZXHybridBinarizer ()

@property (nonatomic, strong) ZXBitMatrix *matrix;

@end

@implementation ZXHybridBinarizer

/**
 * Calculates the final BitMatrix once for all requests. This could be called once from the
 * constructor instead, but there are some advantages to doing it lazily, such as making
 * profiling easier, and not doing heavy lifting when callers don't expect it.
 */
- (ZXBitMatrix *)blackMatrixWithError:(NSError **)error {
  if (self.matrix != nil) {
    return self.matrix;
  }
  ZXLuminanceSource *source = [self luminanceSource];
  NSInteger width = source.width;
  NSInteger height = source.height;
  if (width >= MINIMUM_DIMENSION && height >= MINIMUM_DIMENSION) {
    int8_t *_luminances = source.matrix;
    NSInteger subWidth = width >> BLOCK_SIZE_POWER;
    if ((width & BLOCK_SIZE_MASK) != 0) {
      subWidth++;
    }
    NSInteger subHeight = height >> BLOCK_SIZE_POWER;
    if ((height & BLOCK_SIZE_MASK) != 0) {
      subHeight++;
    }
    NSInteger **blackPoints = [self calculateBlackPoints:_luminances subWidth:subWidth subHeight:subHeight width:width height:height];

    ZXBitMatrix *newMatrix = [[ZXBitMatrix alloc] initWithWidth:width height:height];
    [self calculateThresholdForBlock:_luminances subWidth:subWidth subHeight:subHeight width:width height:height blackPoints:blackPoints matrix:newMatrix];
    self.matrix = newMatrix;

    free(_luminances);

    for (NSInteger i = 0; i < subHeight; i++) {
      free(blackPoints[i]);
    }
    free(blackPoints);
  } else {
    // If the image is too small, fall back to the global histogram approach.
    self.matrix = [super blackMatrixWithError:error];
  }
  return self.matrix;
}

- (ZXBinarizer *)createBinarizer:(ZXLuminanceSource *)source {
  return [[ZXHybridBinarizer alloc] initWithSource:source];
}

/**
 * For each block in the image, calculate the average black point using a 5x5 grid
 * of the blocks around it. Also handles the corner cases (fractional blocks are computed based
 * on the last pixels in the row/column which are also used in the previous block).
 */
- (void)calculateThresholdForBlock:(int8_t *)luminances
                          subWidth:(NSInteger)subWidth
                         subHeight:(NSInteger)subHeight
                             width:(NSInteger)width
                            height:(NSInteger)height
                       blackPoints:(NSInteger **)blackPoints
                            matrix:(ZXBitMatrix *)matrix {
  for (NSInteger y = 0; y < subHeight; y++) {
    NSInteger yoffset = y << BLOCK_SIZE_POWER;
    NSInteger maxYOffset = height - BLOCK_SIZE;
    if (yoffset > maxYOffset) {
      yoffset = maxYOffset;
    }
    for (NSInteger x = 0; x < subWidth; x++) {
      NSInteger xoffset = x << BLOCK_SIZE_POWER;
      NSInteger maxXOffset = width - BLOCK_SIZE;
      if (xoffset > maxXOffset) {
        xoffset = maxXOffset;
      }
      NSInteger left = [self cap:x min:2 max:subWidth - 3];
      NSInteger top = [self cap:y min:2 max:subHeight - 3];
      NSInteger sum = 0;
      for (NSInteger z = -2; z <= 2; z++) {
        NSInteger *blackRow = blackPoints[top + z];
        sum += blackRow[left - 2] + blackRow[left - 1] + blackRow[left] + blackRow[left + 1] + blackRow[left + 2];
      }
      NSInteger average = sum / 25;
      [self thresholdBlock:luminances xoffset:xoffset yoffset:yoffset threshold:average stride:width matrix:matrix];
    }
  }
}

- (NSInteger)cap:(NSInteger)value min:(NSInteger)min max:(NSInteger)max {
  return value < min ? min : value > max ? max : value;
}

/**
 * Applies a single threshold to a block of pixels.
 */
- (void)thresholdBlock:(int8_t *)luminances
               xoffset:(NSInteger)xoffset
               yoffset:(NSInteger)yoffset
             threshold:(NSInteger)threshold
                stride:(NSInteger)stride
                matrix:(ZXBitMatrix *)matrix {
  for (NSInteger y = 0, offset = yoffset * stride + xoffset; y < BLOCK_SIZE; y++, offset += stride) {
    for (NSInteger x = 0; x < BLOCK_SIZE; x++) {
      // Comparison needs to be <= so that black == 0 pixels are black even if the threshold is 0
      if ((luminances[offset + x] & 0xFF) <= threshold) {
        [matrix setX:xoffset + x y:yoffset + y];
      }
    }
  }
}

/**
 * Calculates a single black point for each block of pixels and saves it away.
 * See the following thread for a discussion of this algorithm:
 *  http://groups.google.com/group/zxing/browse_thread/thread/d06efa2c35a7ddc0
 */
- (NSInteger **)calculateBlackPoints:(int8_t *)_luminances
                         subWidth:(NSInteger)subWidth
                        subHeight:(NSInteger)subHeight
                            width:(NSInteger)width
                           height:(NSInteger)height {
  NSInteger **blackPoints = (NSInteger **)malloc(subHeight * sizeof(NSInteger *));
  for (NSInteger y = 0; y < subHeight; y++) {
    blackPoints[y] = (NSInteger *)malloc(subWidth * sizeof(NSInteger));

    NSInteger yoffset = y << BLOCK_SIZE_POWER;
    NSInteger maxYOffset = height - BLOCK_SIZE;
    if (yoffset > maxYOffset) {
      yoffset = maxYOffset;
    }
    for (NSInteger x = 0; x < subWidth; x++) {
      NSInteger xoffset = x << BLOCK_SIZE_POWER;
      NSInteger maxXOffset = width - BLOCK_SIZE;
      if (xoffset > maxXOffset) {
        xoffset = maxXOffset;
      }
      NSInteger sum = 0;
      NSInteger min = 0xFF;
      NSInteger max = 0;
      for (NSInteger yy = 0, offset = yoffset * width + xoffset; yy < BLOCK_SIZE; yy++, offset += width) {
        for (NSInteger xx = 0; xx < BLOCK_SIZE; xx++) {
          NSInteger pixel = _luminances[offset + xx] & 0xFF;
          sum += pixel;
          // still looking for good contrast
          if (pixel < min) {
            min = pixel;
          }
          if (pixel > max) {
            max = pixel;
          }
        }
        // short-circuit min/max tests once dynamic range is met
        if (max - min > MIN_DYNAMIC_RANGE) {
          // finish the rest of the rows quickly
          for (yy++, offset += width; yy < BLOCK_SIZE; yy++, offset += width) {
            for (NSInteger xx = 0; xx < BLOCK_SIZE; xx++) {
              sum += _luminances[offset + xx] & 0xFF;
            }
          }
        }
      }

      // The default estimate is the average of the values in the block.
      NSInteger average = sum >> (BLOCK_SIZE_POWER * 2);
      if (max - min <= MIN_DYNAMIC_RANGE) {
        // If variation within the block is low, assume this is a block with only light or only
        // dark pixels. In that case we do not want to use the average, as it would divide this
        // low contrast area into black and white pixels, essentially creating data out of noise.
        //
        // The default assumption is that the block is light/background. Since no estimate for
        // the level of dark pixels exists locally, use half the min for the block.
        average = min >> 1;

        if (y > 0 && x > 0) {
          // Correct the "white background" assumption for blocks that have neighbors by comparing
          // the pixels in this block to the previously calculated black points. This is based on
          // the fact that dark barcode symbology is always surrounded by some amount of light
          // background for which reasonable black point estimates were made. The bp estimated at
          // the boundaries is used for the interior.

          // The (min < bp) is arbitrary but works better than other heuristics that were tried.
          NSInteger averageNeighborBlackPoint = (blackPoints[y - 1][x] + (2 * blackPoints[y][x - 1]) +
                                           blackPoints[y - 1][x - 1]) >> 2;
          if (min < averageNeighborBlackPoint) {
            average = averageNeighborBlackPoint;
          }
        }
      }
      blackPoints[y][x] = average;
    }
  }
  return blackPoints;
}

@end
