#import "OneDReader.h"

int const INTEGER_MATH_SHIFT = 8;
int const PATTERN_MATCH_RESULT_SCALE_FACTOR = 1 << INTEGER_MATH_SHIFT;

@implementation OneDReader

- (Result *) decode:(BinaryBitmap *)image {
  return [self decode:image hints:nil];
}

- (Result *) decode:(BinaryBitmap *)image hints:(NSMutableDictionary *)hints {

  @try {
    return [self doDecode:image hints:hints];
  }
  @catch (NotFoundException * nfe) {
    BOOL tryHarder = hints != nil && [hints containsKey:DecodeHintType.TRY_HARDER];
    if (tryHarder && [image rotateSupported]) {
      BinaryBitmap * rotatedImage = [image rotateCounterClockwise];
      Result * result = [self doDecode:rotatedImage hints:hints];
      NSMutableDictionary * metadata = [result resultMetadata];
      int orientation = 270;
      if (metadata != nil && [metadata containsKey:ResultMetadataType.ORIENTATION]) {
        orientation = (orientation + [((NSNumber *)[metadata objectForKey:ResultMetadataType.ORIENTATION]) intValue]) % 360;
      }
      [result putMetadata:ResultMetadataType.ORIENTATION param1:[[[NSNumber alloc] init:orientation] autorelease]];
      NSArray * points = [result resultPoints];
      int height = [rotatedImage height];

      for (int i = 0; i < points.length; i++) {
        points[i] = [[[ResultPoint alloc] init:height - [points[i] y] - 1 param1:[points[i] x]] autorelease];
      }

      return result;
    }
     else {
      @throw nfe;
    }
  }
}

- (void) reset {
}


/**
 * We're going to examine rows from the middle outward, searching alternately above and below the
 * middle, and farther out each time. rowStep is the number of rows between each successive
 * attempt above and below the middle. So we'd scan row middle, then middle - rowStep, then
 * middle + rowStep, then middle - (2 * rowStep), etc.
 * rowStep is bigger as the image is taller, but is always at least 1. We've somewhat arbitrarily
 * decided that moving up and down by about 1/16 of the image is pretty good; we try more of the
 * image if "trying harder".
 * 
 * @param image The image to decode
 * @param hints Any hints that were requested
 * @return The contents of the decoded barcode
 * @throws NotFoundException Any spontaneous errors which occur
 */
- (Result *) doDecode:(BinaryBitmap *)image hints:(NSMutableDictionary *)hints {
  int width = [image width];
  int height = [image height];
  BitArray * row = [[[BitArray alloc] init:width] autorelease];
  int middle = height >> 1;
  BOOL tryHarder = hints != nil && [hints containsKey:DecodeHintType.TRY_HARDER];
  int rowStep = [Math max:1 param1:height >> (tryHarder ? 8 : 5)];
  int maxLines;
  if (tryHarder) {
    maxLines = height;
  }
   else {
    maxLines = 15;
  }

  for (int x = 0; x < maxLines; x++) {
    int rowStepsAboveOrBelow = (x + 1) >> 1;
    BOOL isAbove = (x & 0x01) == 0;
    int rowNumber = middle + rowStep * (isAbove ? rowStepsAboveOrBelow : -rowStepsAboveOrBelow);
    if (rowNumber < 0 || rowNumber >= height) {
      break;
    }

    @try {
      row = [image getBlackRow:rowNumber param1:row];
    }
    @catch (NotFoundException * nfe) {
      continue;
    }

    for (int attempt = 0; attempt < 2; attempt++) {
      if (attempt == 1) {
        [row reverse];
        if (hints != nil && [hints containsKey:DecodeHintType.NEED_RESULT_POINT_CALLBACK]) {
          NSMutableDictionary * newHints = [[[NSMutableDictionary alloc] init] autorelease];
          NSEnumerator * hintEnum = [hints keys];

          while ([hintEnum hasMoreElements]) {
            NSObject * key = [hintEnum nextObject];
            if (![key isEqualTo:DecodeHintType.NEED_RESULT_POINT_CALLBACK]) {
              [newHints setObject:key param1:[hints objectForKey:key]];
            }
          }

          hints = newHints;
        }
      }

      @try {
        Result * result = [self decodeRow:rowNumber row:row hints:hints];
        if (attempt == 1) {
          [result putMetadata:ResultMetadataType.ORIENTATION param1:[[[NSNumber alloc] init:180] autorelease]];
          NSArray * points = [result resultPoints];
          points[0] = [[[ResultPoint alloc] init:width - [points[0] x] - 1 param1:[points[0] y]] autorelease];
          points[1] = [[[ResultPoint alloc] init:width - [points[1] x] - 1 param1:[points[1] y]] autorelease];
        }
        return result;
      }
      @catch (ReaderException * re) {
      }
    }

  }

  @throw [NotFoundException notFoundInstance];
}


/**
 * Records the size of successive runs of white and black pixels in a row, starting at a given point.
 * The values are recorded in the given array, and the number of runs recorded is equal to the size
 * of the array. If the row starts on a white pixel at the given start point, then the first count
 * recorded is the run of white pixels starting from that point; likewise it is the count of a run
 * of black pixels if the row begin on a black pixels at that point.
 * 
 * @param row row to count from
 * @param start offset into row to start at
 * @param counters array into which to record counts
 * @throws NotFoundException if counters cannot be filled entirely from row before running out
 * of pixels
 */
+ (void) recordPattern:(BitArray *)row start:(int)start counters:(NSArray *)counters {
  int numCounters = counters.length;

  for (int i = 0; i < numCounters; i++) {
    counters[i] = 0;
  }

  int end = [row size];
  if (start >= end) {
    @throw [NotFoundException notFoundInstance];
  }
  BOOL isWhite = ![row get:start];
  int counterPosition = 0;
  int i = start;

  while (i < end) {
    BOOL pixel = [row get:i];
    if (pixel ^ isWhite) {
      counters[counterPosition]++;
    }
     else {
      counterPosition++;
      if (counterPosition == numCounters) {
        break;
      }
       else {
        counters[counterPosition] = 1;
        isWhite = !isWhite;
      }
    }
    i++;
  }

  if (!(counterPosition == numCounters || (counterPosition == numCounters - 1 && i == end))) {
    @throw [NotFoundException notFoundInstance];
  }
}

+ (void) recordPatternInReverse:(BitArray *)row start:(int)start counters:(NSArray *)counters {
  int numTransitionsLeft = counters.length;
  BOOL last = [row get:start];

  while (start > 0 && numTransitionsLeft >= 0) {
    if ([row get:--start] != last) {
      numTransitionsLeft--;
      last = !last;
    }
  }

  if (numTransitionsLeft >= 0) {
    @throw [NotFoundException notFoundInstance];
  }
  [self recordPattern:row start:start + 1 counters:counters];
}


/**
 * Determines how closely a set of observed counts of runs of black/white values matches a given
 * target pattern. This is reported as the ratio of the total variance from the expected pattern
 * proportions across all pattern elements, to the length of the pattern.
 * 
 * @param counters observed counters
 * @param pattern expected pattern
 * @param maxIndividualVariance The most any counter can differ before we give up
 * @return ratio of total variance between counters and pattern compared to total pattern size,
 * where the ratio has been multiplied by 256. So, 0 means no variance (perfect match); 256 means
 * the total variance between counters and patterns equals the pattern length, higher values mean
 * even more variance
 */
+ (int) patternMatchVariance:(NSArray *)counters pattern:(NSArray *)pattern maxIndividualVariance:(int)maxIndividualVariance {
  int numCounters = counters.length;
  int total = 0;
  int patternLength = 0;

  for (int i = 0; i < numCounters; i++) {
    total += counters[i];
    patternLength += pattern[i];
  }

  if (total < patternLength) {
    return Integer.MAX_VALUE;
  }
  int unitBarWidth = (total << INTEGER_MATH_SHIFT) / patternLength;
  maxIndividualVariance = (maxIndividualVariance * unitBarWidth) >> INTEGER_MATH_SHIFT;
  int totalVariance = 0;

  for (int x = 0; x < numCounters; x++) {
    int counter = counters[x] << INTEGER_MATH_SHIFT;
    int scaledPattern = pattern[x] * unitBarWidth;
    int variance = counter > scaledPattern ? counter - scaledPattern : scaledPattern - counter;
    if (variance > maxIndividualVariance) {
      return Integer.MAX_VALUE;
    }
    totalVariance += variance;
  }

  return totalVariance / total;
}


/**
 * <p>Attempts to decode a one-dimensional barcode format given a single row of
 * an image.</p>
 * 
 * @param rowNumber row number from top of the row
 * @param row the black/white pixel data of the row
 * @param hints decode hints
 * @return {@link Result} containing encoded string and start/end of barcode
 * @throws NotFoundException if an error occurs or barcode cannot be found
 */
- (Result *) decodeRow:(int)rowNumber row:(BitArray *)row hints:(NSMutableDictionary *)hints {
}

@end