//
//  FFTBeatDetection.h
//  CameraAsPPG
//
//  Created by Adam Hair on 12/3/16.
//  Copyright © 2016 Adam Hair. All rights reserved.
//

#ifndef FFTBeatDetection_h
#define FFTBeatDetection_h


#endif /* FFTBeatDetection_h */

@class ViewController;

@interface FFTBeatDetection: NSObject

@property (nonatomic, readwrite, assign) UIView* circle;
@property (nonatomic, readwrite, strong) NSString *filePathBeats;
@property (nonatomic, readwrite, strong) NSString *filePathAddedBeats;
@property (nonatomic, readwrite, strong) NSString *filePathActivity;
@property (nonatomic, readwrite, strong) NSString *filePathPeakMaxSearch;
@property (nonatomic, readwrite, assign) BOOL createFile;

-(BOOL) firstPeakFound;

-(void) setLogging: (BOOL) doLog;

-(void) setCalulateBeats: (BOOL) doCalculateBeats;

-(void) setTargetBreath: (int) target;

-(void) setFs: (int) newFs;

-(void) setCircle: (UIView *) circleView;

-(void) initWithParams:(int) peakRate withPPG:(NSMutableArray *) ppgData withCameraController:(ViewController *) camController withTime:(NSMutableArray *) ppgTime withFreq:(double) freq;

-(int) getPeakCount;

-(bool) isPeakArrayFull;

-(void) setFrequency:(double) freq;

-(void) changeStatus;

-(void) detectBeat: (float) incomingPPG withTimestamp: (double) timestamp;

@end
