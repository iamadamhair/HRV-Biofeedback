//
//  FFTBeatDetection.m
//  CameraAsPPG
//
//  Created by Adam Hair on 12/3/16.
//  Copyright © 2016 Adam Hair. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include "FFTBeatDetection.h"
#include "ViewController.h"

// Constants
double earlyTolerancePercentage = 0.50;
double lateTolerancePercentage = 0.5;
int numPeaks = 3;

// Variables
int countedPeaks = 0;
int targetBreaths = 8;
int peakDetectionRate = 0;
double frequency = 0;
double frequencies[5];
NSNumber *history[3];
NSTimer *beatTimer;
UIView *circle;
bool isSessionRunning = true;
float timeCount = 0;
bool shouldLogPPG = false;
bool calculateBeatTiming = false;
int fs = 32;
int animationCount = 0;
ViewController *cameraController;
NSUserDefaults *userDefaults;


// Peak detection variables
float ppgAvg = 0;
float highestPoint = 0;
double highestPointTime = 0;
float prevPointValue = 0;
double prevPointTime = 0;
int pointCount = 0;
float prevPrevPointValue = 0;
double prevPrevPointTime = 0;
float previousSampleValues[5];
double previousSampleTimes[5];
int sampleCount = 0;
bool fiveSamples = false;
bool firstPeak = false;
int delay = 0;
int numBeatsIn;
int numBeatsOut;
bool numBeatsSet = false;
NSDateFormatter *dateFormatter;

@implementation FFTBeatDetection
@synthesize circle;
@synthesize filePathBeats;
@synthesize filePathAddedBeats;
@synthesize filePathActivity;
@synthesize filePathPeakMaxSearch;
@synthesize createFile;


// Getters and setters
-(void) setFs: (int) newFs {
    fs = newFs;
}

-(BOOL) firstPeakFound {
    return firstPeak;
}


-(void) setCircle: (UIView *) circleView {
    circle = circleView;
}


-(int) getPeakCount {
    return countedPeaks;
}


-(void) setFrequency:(double) freq {
    for(int i = 4; i > 0; i--)
        frequencies[i] = frequencies[i-1];
    frequencies[0] = freq;
    
    double frequencySum = 0;
    
    for(int i = 0; i < 5; i++)
        frequencySum += frequencies[i];
    
    frequency = frequencySum / 5.0;
}


-(void) setCalulateBeats: (BOOL) doCalculateBeats {
    calculateBeatTiming = doCalculateBeats;
    NSLog(@"Calculate beats changed");
}


-(void) setLogging: (BOOL) doLog {
    shouldLogPPG = doLog;
}


-(void) setInOutBeats {
    
    if([[[userDefaults dictionaryRepresentation] allKeys] containsObject:@"beatsIn"]) {
        numBeatsIn = (int)[userDefaults integerForKey:@"beatsIn"];
        numBeatsOut = (int)[userDefaults integerForKey:@"beatsOut"];
    } else {
        numBeatsIn = 6;
        numBeatsOut = 6;
    }
}


-(void) setTargetBreath: (int) target {
    targetBreaths = target;
}


// Functions
-(void) initWithParams:(int) peakRate withPPG:(NSMutableArray *) ppgData withCameraController:(ViewController *) camController withTime:(NSMutableArray *) ppgTime withFreq:(double) freq {
    
    dateFormatter=[[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
    
    peakDetectionRate = peakRate;
    frequency = freq;
    cameraController = camController;
    userDefaults = [NSUserDefaults standardUserDefaults];
    [self calculateRatio];
    
    int tempVal = floor(60 * 0.9375 / (8 + 0.0));
    NSLog(@"beat count %d", tempVal);
    
    int tempIn = floor(tempVal / 2.0);
    NSLog(@"in %d", tempIn);
    
    int tempOut = ceil(tempVal / 2.0);
    NSLog(@"out %d", tempOut);
}


-(void) calculateRatio {
    float beatCount = 60 * frequency / (double)targetBreaths;
    NSLog(@"%f beats, HR %f, target %d", beatCount, 60 * frequency, targetBreaths);
    
    if (fmod(beatCount,2) == 0) {
        numBeatsIn = (int)(beatCount / 2 - 1);
        numBeatsOut = (int)(beatCount - numBeatsIn);
    } else {
        numBeatsIn = floor(beatCount / 2.0);
        numBeatsOut = numBeatsIn + 1;
    }
    
    NSLog(@"%d in, %d out", numBeatsIn, numBeatsOut);
    
    if(self.createFile) {
        [self writeToEndOfFileActivity: [NSString stringWithFormat:@"Ratio updated to %d in : %d out, frequency %f\n", numBeatsIn, numBeatsOut, frequency]];
    }
    
}


-(void) resetCircle {
    circle.transform = CGAffineTransformIdentity;
    animationCount = 0;
    timeCount = 0;
    numBeatsSet = false;
}


-(void) animateVisualization {
    if (animationCount < numBeatsIn) {
        animationCount++;
        
        float increment = 100.0 / numBeatsIn;
        float variableIncreases[numBeatsIn];
        
        for (int i = 0; i < numBeatsIn; i++) {
            variableIncreases[i] = (50.0 + increment * (i + 1)) / (50 + increment * i);
        }
        
        CGAffineTransform transform = circle.transform;
        transform = CGAffineTransformScale(transform, variableIncreases[animationCount-1], variableIncreases[animationCount-1]);
        
        circle.transform = transform;
    } else {
        if(self.createFile)
            if (animationCount == numBeatsIn) {
                // Log midpoint of breathing cycle
                [self writeToEndOfFileActivity: [NSString stringWithFormat:@"Last inhale beat at %f\n", prevPointTime]];
            }
        
        animationCount++;
        
        float increment = 100.0 / numBeatsOut;
        float variableDecreases[numBeatsOut];
        
        int arrayIndex = numBeatsOut - 1;
        for (int i = 0; i < numBeatsOut; i++) {
            variableDecreases[arrayIndex - i] = 1 / ((50.0 + increment * (i + 1)) / (50 + increment * i));
        }
        int index = animationCount - numBeatsIn - 1;
        
        CGAffineTransform transform = circle.transform;
        transform = CGAffineTransformScale(transform, variableDecreases[index], variableDecreases[index]);
        circle.transform = transform;
        
        
        if (animationCount == numBeatsIn + numBeatsOut) {
            animationCount = 0;
            
            //Log end of breathing cycle
            if(self.createFile)
                [self writeToEndOfFileActivity: [NSString stringWithFormat:@"Last exhale beat at %f\n", prevPointTime]];
        }
    }
}


-(bool) isPeakArrayFull {
    return numPeaks <= countedPeaks;
}


-(void) detectBeat: (float) incomingPPG withTimestamp: (double) timestamp {
    
    // Update arrays
    for (int i = 4; i > 0; i--) {
        previousSampleValues[i] = previousSampleValues[i-1];
        previousSampleTimes[i] = previousSampleTimes[i-1];
    }
    previousSampleValues[0] = incomingPPG;
    previousSampleTimes[0] = timestamp;

    
    // Need five samples to detect a peak, so wait until we have enough
    if(fiveSamples) {
        bool peak = previousSampleValues[2] > previousSampleValues[1] && previousSampleValues[2] > previousSampleValues[0] && previousSampleValues[2] > previousSampleValues[3] && previousSampleValues[2] > previousSampleValues[4];
        
        if(firstPeak) {
            timeCount += timestamp - prevPointTime;
            
            double timeRangeStart = 1 / frequency * earlyTolerancePercentage;
            double timeRangeStop = 1 / frequency * (2.0 - lateTolerancePercentage);
            
            // Make sure the beat isn't too far away
            [self writeToEndOfFileMaxSearchDist: [NSString stringWithFormat:@"%f\n", timeRangeStop + highestPointTime]];
            if (previousSampleTimes[2] <= timeRangeStop + highestPointTime) { // Was timestamp <= timeRangeStop
                
                // Make sure beat is far enough away from previous beat
                if (previousSampleTimes[2] >= timeRangeStart + highestPointTime) {
                    if (peak && previousSampleValues[2] > [[cameraController.getPPGCollectedData valueForKeyPath:@"@avg.self"] floatValue]) {
                    //if(peak) { // No height requirements
                        if(isSessionRunning && timeCount > delay) {
                            if(!numBeatsSet && calculateBeatTiming)  {
                                numBeatsSet = true;
                                [self calculateRatio];
                            }
                            [cameraController updateBeatHistory:previousSampleTimes[2]];
                            if (self.createFile)
                                [self writeToEndOfFileBeats: [NSString stringWithFormat:@"%f, %f, %f\n", previousSampleTimes[2], frequency, [[cameraController.getPPGCollectedData valueForKeyPath:@"@avg.self"] floatValue]]];
                        }
                        highestPoint = previousSampleValues[2];
                        highestPointTime = previousSampleTimes[2];
                    } else if (peak) {
                        NSLog(@"Peak but too low: %f < %f avg", previousSampleValues[2], [[cameraController.getPPGCollectedData valueForKeyPath:@"@avg.self"] floatValue]);
                    }
                }
            } else {
                NSLog(@"Added peak new method, old %f new %f", highestPointTime, previousSampleTimes[2]);
                // Add a beat where we expect it to be based on frequency
                /**
                 * May not need this, the beat detection is pretty reliable and by the time we detect
                 * a missing beat, it'll be somewhat close to the new one given that we've expanded
                 * the error range
                 */
                highestPointTime = highestPointTime + 1 / frequency;
                if (isSessionRunning && timeCount > delay) {
                    //[self animateVisualization];
                    if (self.createFile)
                        [self writeToEndOfFileAddedBeats: [NSString stringWithFormat:@"%f\n", highestPointTime]];
                }
            }
            
            // Either way, save the incoming values as the new previous
            prevPointValue = incomingPPG;
            prevPointTime = timestamp;
        } else {
            // Find peak without distance and height thresholds
            if(peak) {
                highestPoint = previousSampleValues[2];
                highestPointTime = previousSampleTimes[2];
                firstPeak = true;
                NSLog(@"Found first peak");
                [cameraController updateBeatHistory:highestPointTime];
                //[cameraController updateBeatHistory:highestPointTime];
            }
            //prevPrevPointValue = prevPointValue;
            //prevPrevPointTime = prevPointTime;
            prevPointValue = incomingPPG;
            prevPointTime = timestamp;
        }
    } else {
        sampleCount++;
        if(sampleCount >= 5)
            fiveSamples = true;
    }
    
}


-(void) changeStatus {
    if (isSessionRunning) {
        //[self startCounting:false];
        isSessionRunning = false;
        
        [self resetCircle];
        
        if(self.createFile) {
            NSString *currentDate = [dateFormatter stringFromDate:[NSDate date]];
            [self writeToEndOfFileActivity: [NSString stringWithFormat:@"%@: Stopping DB\n", currentDate]];
        }
        
    } else {
        [self setInOutBeats];
        if(shouldLogPPG)
            [self createFiles:YES];
        if(self.createFile) {
            NSString *currentDate = [dateFormatter stringFromDate:[NSDate date]];
            [self writeToEndOfFileActivity: [NSString stringWithFormat:@"%@: Starting DB, delay is %d seconds, ratio is %d in : %d out\n", currentDate, delay, numBeatsIn, numBeatsOut]];
        }
        isSessionRunning = true;
    }
}

-(void) createActivityFile {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    NSString *currentDate = [dateFormatter stringFromDate:[NSDate date]];
    
    self.filePathActivity = [documentsDirectory stringByAppendingPathComponent:[[@"activity" stringByAppendingString: currentDate] stringByAppendingString:@".txt"]];
    NSLog(@"Created file %@", self.filePathActivity);
    
    [[NSFileManager defaultManager] createFileAtPath:self.filePathActivity contents:nil attributes:nil];
    [@"" writeToFile:self.filePathActivity atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

-(void) createFiles:(BOOL) create {
    
    self.createFile = create;
    //Getting the documents path to write the file
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    //Getting the date to format the document name
    NSString *currentDate = [dateFormatter stringFromDate:[NSDate date]];
    
    
    //Documents path
    self.filePathBeats = [documentsDirectory stringByAppendingPathComponent:[[@"bpmPeaks" stringByAppendingString: currentDate] stringByAppendingString:@".txt"]];
    NSLog(@"Created file: %@", self.filePathBeats);
    self.filePathAddedBeats = [documentsDirectory stringByAppendingPathComponent:[[@"addedPeaks" stringByAppendingString: currentDate] stringByAppendingString:@".txt"]];
    NSLog(@"Created file: %@", self.filePathAddedBeats);
    //self.filePathPeakMaxSearch = [documentsDirectory stringByAppendingPathComponent:[[@"maxSearchDist" stringByAppendingString:currentDate] stringByAppendingString:@".txt"]];
    //NSLog(@"Created file: %@", self.filePathPeakMaxSearch);

    
    
    //Handler to write into file
    [[NSFileManager defaultManager] createFileAtPath:self.filePathBeats contents:nil attributes:nil];
    [@"" writeToFile:self.filePathBeats atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    [[NSFileManager defaultManager] createFileAtPath:self.filePathAddedBeats contents:nil attributes:nil];
    [@"" writeToFile:self.filePathAddedBeats atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    //[[NSFileManager defaultManager] createFileAtPath:self.filePathPeakMaxSearch contents:nil attributes:nil];
    //[@"" writeToFile:self.filePathPeakMaxSearch atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    [self createActivityFile];
}


-(void) writeToEndOfFileBeats: (NSString *) str{
    NSFileHandle *myh= [NSFileHandle fileHandleForWritingAtPath:self.filePathBeats];
    [myh seekToEndOfFile];
    [myh writeData:[str dataUsingEncoding:NSUTF8StringEncoding]];
}


-(void) writeToEndOfFileAddedBeats: (NSString *) str{
    NSFileHandle *myh= [NSFileHandle fileHandleForWritingAtPath:self.filePathAddedBeats];
    [myh seekToEndOfFile];
    [myh writeData:[str dataUsingEncoding:NSUTF8StringEncoding]];
}

-(void) writeToEndOfFileActivity: (NSString *) str {
    NSFileHandle *myh = [NSFileHandle fileHandleForWritingAtPath:self.filePathActivity];
    [myh seekToEndOfFile];
    [myh writeData:[str dataUsingEncoding:NSUTF8StringEncoding]];
}

-(void) writeToEndOfFileMaxSearchDist: (NSString *) str {
    NSFileHandle *myh = [NSFileHandle fileHandleForWritingAtPath:self.filePathPeakMaxSearch];
    [myh seekToEndOfFile];
    [myh writeData:[str dataUsingEncoding:NSUTF8StringEncoding]];
}

@end
