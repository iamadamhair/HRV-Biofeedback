//
//  HelperFunctions.m
//  CameraAsPPG
//
//  Created by Roger Solis on 11/11/16.
//  Copyright © 2016 Roger Solis. All rights reserved.
//

#import "HelperFunctions.h"


@implementation HelperFunctions


//Functions to get RGB bits from a 32 bit string
+(UInt32) Mask8 : (UInt32)x {
    return (x) & 0xFF;
}

+(UInt32) B : (UInt32)x{
    return [self Mask8:x];
}

+(UInt32) G : (UInt32)x{
    return [self Mask8:(x >> 8)];
}

+(UInt32) R : (UInt32)x{
    return [self Mask8:(x >> 16)];
}


+(double)  std: (double []) array withSize: (int) arraySize {
    double mean = 0;
    
    for (int i = 0; i < arraySize; i++) {
        mean += array[i];
    }
    mean = mean / (arraySize + 0.0);
    
    double var = 0;
    for(int i = 0; i < arraySize; i++ )
    {
        var += (array[i] - mean) * (array[i] - mean);
    }
    var /= (arraySize + 0.0);
    return sqrt(var);
}

/**
 * Returns absolute value of a complex number
 */
+(float *)complexAbs:(COMPLEX_SPLIT) complexFFT withSize:(int) sz {
    float *absArray = malloc(sz * sizeof(float));
    for (int i=0; i< sz ; i++){
        absArray[i] = sqrtf(pow(complexFFT.realp[i],2) + pow(complexFFT.imagp[i],2));
    }
    return absArray;
}

+(double *)complexAbsD:(DOUBLE_COMPLEX_SPLIT) complexFFT withSize:(int) sz {
    double *absArray = malloc(sz * sizeof(double));
    for (int i = 0; i < sz; i++) {
        absArray[i] = sqrt(pow(complexFFT.realp[i],2) + pow(complexFFT.imagp[i],2));
    }
    return absArray;
}

/**
 *  Moving average smooth filter
 */
+(NSMutableArray*) filterMovingAverage:(NSArray *) data withPoints:(int) n{
    NSMutableArray* filteredData = [[NSMutableArray alloc]init];
    int dataLength = (int)[data count];
    
    for (int i = 0; i<dataLength-n; i++){
        float avrg = 0;
        for (int j = i; j<(i + n); j++){
            avrg += [data[j] floatValue];
        }
        avrg /= n;
        [filteredData addObject:[NSNumber numberWithFloat:avrg]];
    }
    
    return filteredData;
}


@end
