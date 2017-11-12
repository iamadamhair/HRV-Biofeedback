//
//  ViewController.h
//  HR Breathing
//
//  Created by Adam Hair on 5/23/17.
//  Copyright © 2017 Adam Hair. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Accelerate/Accelerate.h>
#import "CorePlot-CocoaTouch.h"
#include "HelperFunctions.h"
#import <EmpaLink-ios-0.7-full/EmpaticaAPI-0.7.h>

#define UIColorFromRGB(rgbValue) \
[UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 \
green:((float)((rgbValue & 0x00FF00) >>  8))/255.0 \
blue:((float)((rgbValue & 0x0000FF) >>  0))/255.0 \
alpha:1.0]

@class ViewController;

@interface ViewController : UIViewController <CPTPlotDataSource, EmpaticaDelegate, EmpaticaDeviceDelegate>

@property (weak, nonatomic) IBOutlet CPTGraphHostingView *graphHostView;
@property (nonatomic, readwrite, strong) CPTXYGraph *graph;
@property (weak, nonatomic) IBOutlet CPTGraphHostingView *instantHRMiniView;
@property (nonatomic, readwrite, strong) CPTXYGraph *instantHRGraph;
@property (weak, nonatomic) IBOutlet CPTGraphHostingView *hrvGraphHostView;
@property (nonatomic, readwrite, strong) CPTXYGraph *hrvGraph;
@property (weak, nonatomic) IBOutlet UIButton *startButtonOutlet;
@property (weak, nonatomic) IBOutlet UIButton *connectButtonOutlet;
@property (weak, nonatomic) IBOutlet UISwitch *logSwitchOutlet;
@property (nonatomic, readwrite, assign) NSTimer *plotTimer;


@property (nonatomic, readwrite, assign) NSTimer *fftTimer;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *connectingUIActivityIndicatorOutlet;
@property (weak, nonatomic) IBOutlet UISegmentedControl *visualizationSelectorSegmentedControlOutlet;
@property (weak, nonatomic) IBOutlet UISwitch *timeSwitchOutlet;
@property (weak, nonatomic) IBOutlet UISwitch *ihrSwitchOutlet;
@property (weak, nonatomic) IBOutlet UISwitch *hrvSwitchOutlet;
@property (nonatomic, readwrite, strong) NSString *filePathPPG;
@property (nonatomic, readwrite, strong) NSString *filePathIIR;
@property (nonatomic, readwrite, strong) NSString *filePathSine;
@property (nonatomic, readwrite, strong) NSString *filePathHRV;


//Graph axes data
@property (nonatomic, readwrite) double xRangeStart;
@property (nonatomic, readwrite) double xRangeEnd;
@property (nonatomic, readwrite) double yRangeStart;
@property (nonatomic, readwrite) double yRangeEnd;
@property (nonatomic, readwrite) double xRangeStartIhr;
@property (nonatomic, readwrite) double xRangeEndIhr;
@property (nonatomic, readwrite) double yRangeStartIhr;
@property (nonatomic, readwrite) double yRangeEndIhr;
@property (nonatomic, readwrite) double xRangeStartHrv;
@property (nonatomic, readwrite) double xRangeEndHrv;
@property (nonatomic, readwrite) double yRangeStartHrv;
@property (nonatomic, readwrite) double yRangeEndHrv;

-(NSMutableArray *) getPPGCollectedData;

-(NSMutableArray *) getPPGCollectedDataTimeStamps;

-(void) updateBeatHistory: (double) timestamp;


@end

