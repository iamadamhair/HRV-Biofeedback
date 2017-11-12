//
//  HelperFunctions.h
//  CameraAsPPG
//
//  Created by Roger Solis on 11/11/16.
//  Copyright © 2016 Roger Solis. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#include <Accelerate/Accelerate.h>

@interface HelperFunctions : NSObject{

}

+(UInt32) Mask8 : (UInt32)x;
+(UInt32) B : (UInt32)x;
+(UInt32) G : (UInt32)x;
+(UInt32) R : (UInt32)x;
+(float *)complexAbs:(COMPLEX_SPLIT) complexFFT withSize:(int) sz;
+(double *)complexAbsD:(DOUBLE_COMPLEX_SPLIT) complexFFT withSize:(int) sz;
+(NSMutableArray*) filterMovingAverage:(NSArray *) data withPoints:(int) n;
+(double)  std: (double []) array withSize: (int) arraySize;
@end
