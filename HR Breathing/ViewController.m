//
//  ViewController.m
//  HR Breathing
//
//  Created by Adam Hair on 5/23/17.
//  Copyright © 2017 Adam Hair. All rights reserved.
//

#import "ViewController.h"
#import "FFTBeatDetection.h"

@interface ViewController ()


@end

@implementation ViewController

// Graphs and their hosts
@synthesize graphHostView;
@synthesize graph;
@synthesize instantHRGraph;
@synthesize instantHRMiniView;
@synthesize hrvGraphHostView;
@synthesize hrvGraph;

// Outlets
@synthesize startButtonOutlet;
@synthesize connectButtonOutlet;
@synthesize logSwitchOutlet;
@synthesize connectingUIActivityIndicatorOutlet;
@synthesize visualizationSelectorSegmentedControlOutlet;
@synthesize timeSwitchOutlet;
@synthesize ihrSwitchOutlet;
@synthesize hrvSwitchOutlet;

// Log file paths
@synthesize filePathPPG;
@synthesize filePathIIR;
@synthesize filePathSine;
@synthesize filePathHRV;

// Graph parameters
@synthesize xRangeStart;
@synthesize xRangeEnd;
@synthesize yRangeStart;
@synthesize yRangeEnd;
@synthesize xRangeStartIhr;
@synthesize xRangeEndIhr;
@synthesize yRangeStartIhr;
@synthesize yRangeEndIhr;
@synthesize xRangeStartHrv;
@synthesize xRangeEndHrv;
@synthesize yRangeStartHrv;
@synthesize yRangeEndHrv;

// Repeating timers
@synthesize plotTimer;
@synthesize fftTimer;

float min_fft_hz = 0.8;
float max_fft_hz = 4.0;
int FFT_MIN_SAMPLES_N = 256;
int FFT_OPT_SAMPLES_N = 512;
double Fs = 64;

static NSMutableArray *PPGCollectedData;
static NSMutableArray *PPGCollectedDataTimeStamps;

int arrayLength = 2048;
int hrvLength = 50;
double hrvFunctionOutput[50];
double iirFunctionOutput[2048];
double sineFunctionOutput[2048];
double beatHistory[10];
static NSMutableArray *heartbeats;
bool newestBeatProcessed;
double tau = 1/30; // How often to recalculate the curve
double alpha = 0.98; // How much of the previous value to use
double firstTimestamp = 0;
double psdTimestamp = 0;


double sineMax = 80;
double sineMin = 60;
double maxHR = 80;
double minHR = 60;

CADisplayLink *displayLink;
CFAbsoluteTime prevTime;

FFTSetupD setupHRV;
vDSP_Length fftRadixHRV;

int currentSteps = 0;
double inBreathTime = 4.0;
double outBreathTime = 6.0;
int inSteps = 0;
int outSteps= 0;
int rrIntervals;
bool useRMSSD;
int hrvIndex = 0;
int hrvWindowLength = 30;

double globalTimestamp = 0;
static float const MAX_N_SAMPLES = 513;
static int const PKS_DETECTION_RATE_SECS = 3;
bool createFile = false;
bool shouldLog = false;
bool deviceConnected = false;
bool instantHRVisualization = false; // Always sine visualization, IHR will appear in its own graph
NSUserDefaults *defaults = nil;

// Keys
NSString *rrKey = @"rrIntervalSegmentIndex";
NSString *hrvKey = @"hrvFunctionSegmentIndex";
NSString *logKey = @"logDataSwitchBool";
NSString *secondsInKey = @"secondsBreatheIn";
NSString *secondsOutKey = @"secondsBreatheOut";

FFTBeatDetection *beatDetection;


-(void) viewWillAppear:(BOOL)animated {
    if (defaults == nil) {
        defaults = [NSUserDefaults standardUserDefaults];
    }
    
    if ([self defaultSet]) {
        rrIntervals = (int)[defaults integerForKey:rrKey] + 1;
        hrvIndex = (int)[defaults integerForKey:hrvKey];
        useRMSSD = hrvIndex == 0;
        shouldLog = [defaults boolForKey:logKey];
    } else {
        rrIntervals = 1;
        useRMSSD = true ;
        shouldLog = false;
    }
    
    NSLog(@"RR intervals set to %i", rrIntervals);
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    
    PPGCollectedData = [[NSMutableArray alloc]init];
    PPGCollectedDataTimeStamps = [[NSMutableArray alloc]init];
    heartbeats = [[NSMutableArray alloc] init];
    
    xRangeStartHrv = 0;
    xRangeEndHrv = hrvLength;
    yRangeStartHrv = -0.2;
    yRangeEndHrv = 1.2;
    xRangeStart = 0;
    xRangeEnd = 1000;//64*5;
    yRangeStart = 0;
    yRangeEnd = 2;
    xRangeStartIhr = 0;
    xRangeEndIhr = 1000;
    yRangeStartIhr = 0;
    yRangeEndIhr = 2;
    
    fftRadixHRV = log2(arrayLength);
    
    setupHRV = vDSP_create_fftsetupD(fftRadixHRV, FFT_RADIX2);
    
    // Init the array so there are no rogue null pointer issues
    [self eraseArrays];
    for (int i = 0; i < 10; i++) {
        beatHistory[i] = -1;
    }
    
    // No newest beat, so say that it's been processed
    newestBeatProcessed = true;
    
    beatDetection = [[FFTBeatDetection alloc]init];
    [beatDetection initWithParams:PKS_DETECTION_RATE_SECS withPPG:PPGCollectedData withCameraController:self withTime:PPGCollectedDataTimeStamps withFreq:0];
}


-(BOOL) defaultSet {
    return [[[defaults dictionaryRepresentation] allKeys] containsObject:rrKey];
}


-(void) setUpSineParameters {
    if ([self defaultSet]) {
        inBreathTime = [defaults doubleForKey:secondsInKey];
        outBreathTime = [defaults doubleForKey:secondsOutKey];
    }
    
    inSteps = round(inBreathTime / tau);
    outSteps = round(outBreathTime / tau);
    currentSteps = outSteps;
}


-(void) eraseArrays {
    for (int i = 0; i < arrayLength; i++) {
        iirFunctionOutput[i] = 0;
        sineFunctionOutput[i] = 0;
    }
    
    // HRV output is shorter than the others
    for (int i = 0; i < hrvLength; i++) {
        hrvFunctionOutput[i] = 0;
    }
}


-(NSMutableArray *) getPPGCollectedData {
    return PPGCollectedData;
}


-(NSMutableArray *) getPPGCollectedDataTimeStamps {
    return PPGCollectedDataTimeStamps;
}


- (IBAction)timeSwitchAction:(id)sender {
    if(timeSwitchOutlet.isOn) {
        graphHostView.hidden = NO;
    } else {
        graphHostView.hidden = YES;
    }
}


- (IBAction)ihrSwitchAction:(id)sender {
    if(ihrSwitchOutlet.isOn) {
        instantHRMiniView.hidden = NO;
    } else {
        instantHRMiniView.hidden = YES;
    }
}


- (IBAction)hrvSwitchAction:(id)sender {
    if(hrvSwitchOutlet.isOn) {
        hrvGraphHostView.hidden = NO;
    } else {
        hrvGraphHostView.hidden = YES;
    }
}


- (IBAction)connectButtonAction:(id)sender {
    [connectingUIActivityIndicatorOutlet startAnimating];
    [EmpaticaAPI discoverDevicesWithDelegate:self];
    NSLog(@"Connect button pushed");
}


- (IBAction)startButtonAction:(id)sender {
    if(displayLink == nil) {
        
        prevTime = CFAbsoluteTimeGetCurrent();
        globalTimestamp = firstTimestamp;
        
        visualizationSelectorSegmentedControlOutlet.enabled = NO;
        logSwitchOutlet.enabled = NO;
        [self startPlotting:YES];
        [startButtonOutlet setTitle:@"Stop" forState:UIControlStateNormal];
        
        if (shouldLog)
            [self createFiles:YES];
        
        if (deviceConnected) {
            [self startFFT:YES];
        }
    } else {
        
        visualizationSelectorSegmentedControlOutlet.enabled = YES;
        logSwitchOutlet.enabled = YES;
        [self startPlotting:NO];
        [startButtonOutlet setTitle:@"Start" forState:UIControlStateNormal];
        
        createFile = false;
        
        if (deviceConnected) {
            [self startFFT:NO];
        }
    }
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


-(void) startPlotting: (BOOL) start {
    
    if(start){//Init and start timer
        [self setUpSineParameters];
        displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(performCalculationsAndPlot)];
        [displayLink setPreferredFramesPerSecond:30];
        [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        //plotTimer = [NSTimer scheduledTimerWithTimeInterval:tau target:self selector:@selector(performCalculationsAndPlot) userInfo:nil repeats:YES];
    } else {//Stop timer
        //restore data array
        NSLog(@"Stoping plot timer");
        PPGCollectedData = [[NSMutableArray alloc]init];
        PPGCollectedDataTimeStamps = [[NSMutableArray alloc]init];
        //[plotTimer invalidate];
        [displayLink invalidate];
        [self eraseArrays];
        currentSteps = 0;
        plotTimer = nil;
    }
    
}


-(void) startFFT: (BOOL) start {
    if(start){//Init and start timer that applies fft and shows result in view
        fftTimer = [NSTimer scheduledTimerWithTimeInterval:1
                                                    target:self
                                                  selector:@selector(applyFFT)
                                                  userInfo:nil
                                                   repeats:YES];
        NSLog(@"Estimation started");
    } else {//Stop timer
        [fftTimer invalidate];
        fftTimer = nil;
    }
}


-(void) performCalculationsAndPlot {
    // Always generate the sine wave
    [self generateSinusoidal];
    [self reloadData];
    
    // Check if we have E4 data
    if (deviceConnected) {
        [self generateFunction];
        [self getCurrentPSD];
        //[self calculateHRV];
        [self reloadHRVData];
        [self reloadIHRData];
    }
    
    CFAbsoluteTime currentStep = CFAbsoluteTimeGetCurrent();
    globalTimestamp += (double)currentStep - (double)prevTime;
    prevTime = currentStep;
    //globalTimestamp = globalTimestamp + [displayLink targetTimestamp] - [displayLink timestamp];
}


-(void) updateBeatHistory: (double) timestamp {
    // Remove any heartbeats older than the specified window length
    while ([heartbeats count] > 0 && timestamp - [[heartbeats objectAtIndex:0] doubleValue] > hrvWindowLength) {
        [heartbeats removeObjectAtIndex:0];
    }
    
    [heartbeats addObject:[NSNumber numberWithDouble:timestamp]];
    //NSLog(@"%lu beats in the array", (unsigned long)[heartbeats count]);
    
    // Move back all previous beat timestamps
    for (int i = 0; i < 9; i++) {
        beatHistory[i] = beatHistory[i+1];
    }
    
    // Add newest beat timestamp at the end of the array
    beatHistory[9] = timestamp;
    
    newestBeatProcessed = false;
}


-(void) calculateHRV {
    // Get rid of the oldest point
    for (int i = 0; i < arrayLength - 1; i++) {
        hrvFunctionOutput[i] = hrvFunctionOutput[i+1];
    }
    
    double hrvValue = 0;
    double sumOfSquareDiffs;
    
    if([heartbeats count] > 3) {
        double beatDiffs[(int)[heartbeats count] - 1];
        
        switch(hrvIndex) {
            case 0:
                NSLog(@"Calculating RMSSD");
                
                sumOfSquareDiffs = 0;
                
                for (int i = 0; i < [heartbeats count] - 2; i++) {
                    sumOfSquareDiffs += pow(([[heartbeats objectAtIndex:i] doubleValue] - 2*[[heartbeats objectAtIndex:i + 1] doubleValue] + [[heartbeats objectAtIndex:i+2] doubleValue]) * 1000, 2);
                }
                
                hrvValue = sqrt(sumOfSquareDiffs / ((int)[heartbeats count] - 1));
                
                NSLog(@"HRV value %f, %d beats", hrvValue, (int)[heartbeats count]);
                break;
            case 1:
                NSLog(@"Calculating SDNN");
                
                for (int i = 1; i < [heartbeats count]; i++) {
                    beatDiffs[i - 1] = fabs([[heartbeats objectAtIndex:i - 1] doubleValue] - [[heartbeats objectAtIndex:i] doubleValue]) * 1000;
                }
                
                hrvValue = [HelperFunctions std: beatDiffs withSize:(int)[heartbeats count] - 1];
                
                NSLog(@"HRV value %f, %lu beats", hrvValue, (unsigned long)[heartbeats count]);
                break;
            case 2:
                NSLog(@"Calculating amplitude difference");
                break;
            case 3:
                NSLog(@"PSD estimate of HRV rhythm");
                
                break;
        }
        
    }
    //double fakeSDNN = [HelperFunctions std:iirFunctionOutput withSize:1000];
    hrvFunctionOutput[arrayLength - 1] = alpha * hrvFunctionOutput[arrayLength - 2] + (1 - alpha) * hrvValue;
}


-(void) generateFunction {
    // Get rid of the oldest point
    for (int i = 0; i < arrayLength - 1; i++) {
        iirFunctionOutput[i] = iirFunctionOutput[i+1];
    }
    
    // Get time diff over 1+ rr intervals (as determined by user settings)
    double timeDiff = (beatHistory[9] - beatHistory[9 - rrIntervals]) / (double)rrIntervals;
    
    // Smooth with previous values combined with the time diff
    double newValue;
    if (timeDiff > 0) {
        newValue = alpha * iirFunctionOutput[arrayLength - 2] + (1 - alpha) * 60 / timeDiff;
    } else {
        newValue = alpha * iirFunctionOutput[arrayLength - 2];
    }
    
    iirFunctionOutput[arrayLength - 1] = newValue;
    
    double maxVal = 10;
    double minVal = 200;
    for (int i = (int)(arrayLength / 2); i < arrayLength; i++) {
        double currentVal = iirFunctionOutput[i];
        if (currentVal > maxVal)
            maxVal = currentVal;
        if (currentVal < minVal)
            minVal = currentVal;
    }
    
    maxHR = maxVal;
    minHR = minVal;
    
    if(shouldLog)
        dispatch_async(dispatch_get_main_queue(), ^{
            [self writeToEndOfFileIIR: [NSString stringWithFormat:@"%f, %f\n", newValue, globalTimestamp]];
        });
}


-(void) getCurrentPSD {
    double *fftResponse = [self applyFftToArray];
    
    double maxFFT = 10;
    double minFFT = 10;
    
    int firstFftBin = 0;
    
    // Find max and min
    for (int i = firstFftBin; i < (int)(arrayLength / 2); i++) {
        if (fftResponse[i] > maxFFT)
            maxFFT = fftResponse[i];
        if (fftResponse[i] < minFFT)
            minFFT = fftResponse[i];
    }
    
    double maxMinDiff = maxFFT - minFFT;
    
    // Normalize the fft values before storing them
    for (int i = 0; i < hrvLength; i+=2) {
        hrvFunctionOutput[i] = (fftResponse[i/2+firstFftBin] - minFFT) / maxMinDiff;
    }
    for (int i = 1; i < hrvLength - 1; i+=2) {
        hrvFunctionOutput[i] = (hrvFunctionOutput[i-1] + hrvFunctionOutput[i+1])/2;
    }
    
    /*for (int i = 0; i < hrvLength; i++) {
        hrvFunctionOutput[i] = (fftResponse[i + firstFftBin] - minFFT) / maxMinDiff;
    }*/
    
    if(shouldLog) {
        NSMutableString *fftString = [NSMutableString stringWithString:@""];
        for (int i = 0; i < hrvLength / 2; i++) {
            if (i < hrvLength / 2 - 1)
                [fftString appendString:[NSString stringWithFormat:@"%f, ", fftResponse[i]]];
            else
                [fftString appendString:[NSString stringWithFormat:@"%f, %f\n", fftResponse[i], globalTimestamp]];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self writeToEndOfFileHRV:fftString];
        });
    }
    
    free(fftResponse);
}


-(void) generateSinusoidal {
    // Generate sinusoidal wave with 0.1HZ frequency
    // 4 seconds trough to peak, 6 seconds peak to trough
    // Tau may change, use this to drive our calculations
    
    for (int i = 0; i < arrayLength - 1; i++) {
        sineFunctionOutput[i] = sineFunctionOutput[i+1];
    }
    
    double plotVal;
    
    double tempTimestamp = fmod(globalTimestamp, outBreathTime+inBreathTime);
    double warpedTime;
    
    if (tempTimestamp < outBreathTime)
    {
        warpedTime = tempTimestamp / (2*outBreathTime);
        //plotVal = cos(currentSteps / (double)outSteps * M_PI);
    } else {
        //plotVal = cos((1 + (currentSteps - outSteps) / (double)inSteps) * M_PI);
        warpedTime = (tempTimestamp - outBreathTime) / (2*inBreathTime) + 0.5;
    }
    
    plotVal = cos(2*M_PI*warpedTime);
    
    // Normalize 1-0
    plotVal = (plotVal + 1) / 2;
    
    plotVal = plotVal * 80;
    
    sineFunctionOutput[arrayLength - 1] = plotVal;
    
    if(shouldLog)
        dispatch_async(dispatch_get_main_queue(), ^{
            [self writeToEndOfFileSine: [NSString stringWithFormat:@"%f, %f\n", plotVal, globalTimestamp]];
        });
}


//
// E4 functions //
//
- (void)didReceiveBVP:(float)bvp withTimestamp:(double)timestamp fromDevice:(EmpaticaDeviceManager *)device {
    dispatch_async(dispatch_get_main_queue(), ^{
        if(firstTimestamp == 0) {
            firstTimestamp = timestamp;
            NSLog(@"First timestamp: %f", firstTimestamp);
        }
        [self addPPG:-bvp withTimeStamp:timestamp];
        [beatDetection detectBeat:-bvp withTimestamp:timestamp];
    });
}


- (void)didDiscoverDevices:(NSArray *)devices {
    if (devices.count > 0) {
        // Print names of available devices
        for (EmpaticaDeviceManager *device in devices) {
            NSLog(@"Device: %@", device.name);
        }
        
        // Connect to first available device
        EmpaticaDeviceManager *firstDevice = [devices objectAtIndex:0];
        @try {
            [firstDevice connectWithDeviceDelegate:self];
        }
        @catch (NSException *exception) {
            NSLog(@"Error connecting to device. Maybe timeout? Try again");
        }
        @finally {
            NSLog(@"Finally statement");
        }
    } else {
        NSLog(@"No device found in range");
        [connectingUIActivityIndicatorOutlet stopAnimating];
        [connectingUIActivityIndicatorOutlet setHidden:true];
    }
}


- (void)didUpdateBLEStatus:(BLEStatus)status {
    switch (status) {
        case kBLEStatusNotAvailable:
            NSLog(@"Bluetooth low energy not available");
            break;
        case kBLEStatusReady:
            NSLog(@"Bluetooth low energy ready");
            break;
        case kBLEStatusScanning:
            NSLog(@"Bluetooth low energy scanning for devices");
            break;
        default:
            break;
    }
}


- (void)didUpdateDeviceStatus:(DeviceStatus)status forDevice:(EmpaticaDeviceManager *)device {
    switch (status) {
        case kDeviceStatusDisconnected:
            NSLog(@"Device Disconnected");
            connectButtonOutlet.enabled = YES;
            [connectButtonOutlet setTitle:@"Connect E4" forState:UIControlStateNormal];
            startButtonOutlet.enabled = NO;
            break;
        case kDeviceStatusConnecting:
            NSLog(@"Device Connecting");
            break;
        case kDeviceStatusConnected:
            NSLog(@"Device Connected");
            [connectingUIActivityIndicatorOutlet stopAnimating];
            [connectingUIActivityIndicatorOutlet setHidden:true];
            [connectButtonOutlet setTitle:@"E4 Connected" forState:UIControlStateNormal];
            connectButtonOutlet.enabled = NO;
            startButtonOutlet.enabled = YES;
            deviceConnected = true;
            break;
        case kDeviceStatusDisconnecting:
            NSLog(@"Device Disconnecting");
            break;
        default:
            break;
    }
}


- (void) scanAndConnect {
    @try {
        NSLog(@"Trying to connect");
        [EmpaticaAPI discoverDevicesWithDelegate:self];
    }
    @catch (NSException *e) {
        NSLog(@"Exception when trying to discover devices");
        [connectingUIActivityIndicatorOutlet stopAnimating];
    }
}


//
// Graph functions //
//
- (void)reloadData {
    if ( !self.graph ) {
        NSLog(@"Initializing new graph");
        CPTXYGraph *newGraph = [[CPTXYGraph alloc] initWithFrame:CGRectZero];
        self.graph = newGraph;
        
        newGraph.paddingTop    = 0;
        newGraph.paddingBottom = 0;
        newGraph.paddingLeft   = 0;
        newGraph.paddingRight  = 0;
        
        CPTScatterPlot *dataSourceLinePlot = [[CPTScatterPlot alloc] initWithFrame:newGraph.bounds];
        dataSourceLinePlot.identifier = @"Visualization Plot";
        
        CPTMutableLineStyle *lineStyle = [dataSourceLinePlot.dataLineStyle mutableCopy];
        lineStyle.lineWidth              = 1.0; // Previously 1.0
        lineStyle.lineColor              = [[CPTColor alloc] initWithCGColor: [UIColorFromRGB(0x10517A) CGColor]];
        dataSourceLinePlot.dataLineStyle = lineStyle;
        
        //newGraph.plotAreaFrame.fill = [CPTFill fillWithColor: [CPTColor redColor]];
        //newGraph.fill = [CPTFill fillWithColor: [CPTColor redColor]];//[CPTFill fillWithColor:[[CPTColor alloc] initWithCGColor: [UIColorFromRGB(0x1432AE) CGColor]]];
        
        // Create a white, zero-pt style to hide axes
        CPTMutableLineStyle *axisStyle = [[CPTMutableLineStyle alloc]init];
        axisStyle.lineWidth = 0.0;
        axisStyle.lineColor = [CPTColor whiteColor];
        
        // Set the axis style so they're hidden in the background
        CPTXYAxisSet *axisSet = (CPTXYAxisSet*)[newGraph axisSet];
        axisSet.yAxis.axisLineStyle = axisStyle;
        axisSet.xAxis.axisLineStyle = axisStyle;
        
        dataSourceLinePlot.dataSource = self;
        [newGraph addPlot:dataSourceLinePlot];
        
    }
    
    CPTXYGraph *theGraph = self.graph;
    self.graphHostView.hostedGraph = theGraph;
    
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)theGraph.defaultPlotSpace;
    
    NSDecimalNumber *high   = [[NSDecimalNumber alloc] initWithString:@"255.0"];
    NSDecimalNumber *low    = [[NSDecimalNumber alloc] initWithString:@"0"];
    NSDecimalNumber *length = [high decimalNumberBySubtracting:low];
    
    //Configuring dynamical adjustment of x and y axes
    //int total = (int)[PPGCollectedData count];
    int total = arrayLength;
    //float lowY = 255;
    //double lowY = 60;
    //float highY = 0;
    //double highY = 80;
    if(total>xRangeEnd){
        xRangeStart = total - xRangeEnd;
    }
    
    if(total > 50){
        // Se the highest and lowest values for y
        
        if(instantHRVisualization)
        {
            /*for (int i=xRangeStart + 20; i<total; i++) {
                if(iirFunctionOutput[i] > highY) {
                    highY = iirFunctionOutput[i];
                    NSLog(@"Changing sine max");
                }
                
                if(iirFunctionOutput[i] < lowY) {
                    lowY = iirFunctionOutput[i];
                }
            }*/
        } else {
            for (int i=xRangeStart + 20; i<total; i++) {
                if(sineFunctionOutput[i] > sineMax) {
                    sineMax = sineFunctionOutput[i];
                }
                
                if(sineFunctionOutput[i] < sineMin) {
                    sineMin = sineFunctionOutput[i];
                }
            }
        }
        
        double difLow = fabs(yRangeStart - sineMin);
        if(difLow > 5) yRangeStart = sineMin; //Setting a threshold
        yRangeStart = sineMin - 2;
        
        double difHigh = fabs(yRangeEnd - sineMax);
        if(difHigh > 5) yRangeEnd = sineMax; //Setting a threshold
        yRangeEnd = sineMax + 2;
    }
    
    NSNumber *newXStart = [NSNumber numberWithDouble:xRangeStart];
    NSNumber *newXEnd = [NSNumber numberWithDouble:xRangeEnd];
    NSNumber *newYStart = [NSNumber numberWithDouble:yRangeStart];
    NSNumber *newYEnd = [NSNumber numberWithDouble:(yRangeEnd - yRangeStart)];
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:newXStart length:newXEnd];
    plotSpace.yRange = [CPTPlotRange plotRangeWithLocation:newYStart length:newYEnd];
    
    // Axes
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)theGraph.axisSet;
    
    CPTXYAxis *x = axisSet.xAxis;
    x.hidden = YES;
    x.majorIntervalLength   = @10.0;
    x.orthogonalPosition    = @0.0;
    x.minorTicksPerInterval = 1;
    
    CPTXYAxis *y  = axisSet.yAxis;
    NSDecimal six = CPTDecimalFromInteger(6);
    y.majorIntervalLength   = [NSDecimalNumber decimalNumberWithDecimal:CPTDecimalDivide(length.decimalValue, six)];
    y.majorTickLineStyle    = nil;
    y.minorTicksPerInterval = 4;
    y.minorTickLineStyle    = nil;
    y.orthogonalPosition    = @0.0;
    y.alternatingBandFills  = @[[[CPTColor whiteColor] colorWithAlphaComponent:CPTFloat(0.1)], [NSNull null]];
    
    [theGraph reloadData];
}


- (void) reloadIHRData {
    if ( !self.instantHRGraph ) {
        NSLog(@"Initializing new graph");
        CPTXYGraph *newGraph = [[CPTXYGraph alloc] initWithFrame:CGRectZero];
        self.instantHRGraph = newGraph;
        
        newGraph.paddingTop    = 0;
        newGraph.paddingBottom = 0;
        newGraph.paddingLeft   = 0;
        newGraph.paddingRight  = 0;
        
        CPTScatterPlot *dataSourceLinePlot = [[CPTScatterPlot alloc] initWithFrame:newGraph.bounds];
        dataSourceLinePlot.identifier = @"IHR Plot";
        
        CPTMutableLineStyle *lineStyle = [dataSourceLinePlot.dataLineStyle mutableCopy];
        lineStyle.lineWidth              = 1.0; // Previously 1.0
        lineStyle.lineColor              = [[CPTColor alloc] initWithCGColor: [UIColorFromRGB(0xBF0F0F) CGColor]];
        dataSourceLinePlot.dataLineStyle = lineStyle;
        
        newGraph.plotAreaFrame.plotArea.fill = [CPTFill fillWithColor:[CPTColor whiteColor]];//[CPTFill fillWithColor:[[CPTColor alloc] initWithCGColor: [UIColorFromRGB(0x1432AE) CGColor]]];
        
        // Create a white, zero-pt style to hide axes
        CPTMutableLineStyle *axisStyle = [[CPTMutableLineStyle alloc]init];
        axisStyle.lineWidth = 0.0;
        axisStyle.lineColor = [CPTColor whiteColor];
        
        // Set the axis style so they're hidden in the background
        CPTXYAxisSet *axisSet = (CPTXYAxisSet*)[newGraph axisSet];
        axisSet.yAxis.axisLineStyle = axisStyle;
        axisSet.xAxis.axisLineStyle = axisStyle;
        
        dataSourceLinePlot.dataSource = self;
        [newGraph addPlot:dataSourceLinePlot];
        
    }
    
    CPTXYGraph *theGraph = self.instantHRGraph;
    self.instantHRMiniView.hostedGraph = theGraph;
    
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)theGraph.defaultPlotSpace;
    
    NSDecimalNumber *high   = [[NSDecimalNumber alloc] initWithString:@"255.0"];
    NSDecimalNumber *low    = [[NSDecimalNumber alloc] initWithString:@"0"];
    NSDecimalNumber *length = [high decimalNumberBySubtracting:low];
    
    //Configuring dynamical adjustment of x and y axes
    int total = arrayLength;
    //double ihrMax = 100;
    //double ihrMin = 70;
    
    if(total>xRangeEndIhr){
        xRangeStartIhr = total - xRangeEndIhr;
    }
    
    if(total > 50){
        // Se the highest and lowest values for y
        
        /*for (int i=xRangeStartIhr + 20; i<total; i++) {
            
            if(iirFunctionOutput[i] > ihrMax) {
                ihrMax = iirFunctionOutput[i];
                NSLog(@"Changing IHR Max");
            }
            
            if(iirFunctionOutput[i] < ihrMin) {
                ihrMin = iirFunctionOutput[i];
            }
        }*/
        
        double difLow = fabs(yRangeStartIhr - minHR);
        if(difLow > 10) yRangeStartIhr = minHR; //Setting a threshold
        yRangeStartIhr = minHR - 5;
        
        double difHigh = fabs(yRangeEndIhr - maxHR);
        if(difHigh > 10) yRangeEndIhr = maxHR; //Setting a threshold
        yRangeEndIhr = maxHR + 5;
    }
    
    NSNumber *newXStart = [NSNumber numberWithDouble:xRangeStartIhr];
    NSNumber *newXEnd = [NSNumber numberWithDouble:xRangeEndIhr];
    NSNumber *newYStart = [NSNumber numberWithDouble:yRangeStartIhr]; // Changed from yRangeStartIhr
    NSNumber *newYEnd = [NSNumber numberWithDouble:(yRangeEndIhr - yRangeStartIhr)]; // Changed from yRangeEndIhr - yRangeStartIhr
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:newXStart length:newXEnd];
    plotSpace.yRange = [CPTPlotRange plotRangeWithLocation:newYStart length:newYEnd];
    
    // Axes
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)theGraph.axisSet;
    
    CPTXYAxis *x = axisSet.xAxis;
    x.hidden = YES;
    x.majorIntervalLength   = @10.0;
    x.orthogonalPosition    = @0.0;
    x.minorTicksPerInterval = 1;
    x.axisLabels = nil;
    
    CPTXYAxis *y  = axisSet.yAxis;
    NSDecimal six = CPTDecimalFromInteger(6);
    y.majorIntervalLength   = [NSDecimalNumber decimalNumberWithDecimal:CPTDecimalDivide(length.decimalValue, six)];
    y.majorTickLineStyle    = nil;
    y.minorTicksPerInterval = 4;
    y.minorTickLineStyle    = nil;
    y.orthogonalPosition    = @0.0;
    y.alternatingBandFills  = @[[[CPTColor whiteColor] colorWithAlphaComponent:CPTFloat(0.1)], [NSNull null]];
    
    [theGraph reloadData];
}


- (void) reloadHRVData {
    if ( !self.hrvGraph ) {
        NSLog(@"Initializing new graph");
        CPTXYGraph *newGraph = [[CPTXYGraph alloc] initWithFrame:CGRectZero];
        self.hrvGraph = newGraph;
        
        newGraph.paddingTop    = 0;
        newGraph.paddingBottom = 0;
        newGraph.paddingLeft   = 0;
        newGraph.paddingRight  = 0;
        
        CPTScatterPlot *dataSourceLinePlot = [[CPTScatterPlot alloc] initWithFrame:newGraph.bounds];
        dataSourceLinePlot.identifier = @"HRV Plot";
        
        CPTMutableLineStyle *lineStyle = [dataSourceLinePlot.dataLineStyle mutableCopy];
        lineStyle.lineWidth              = 1.0; // Previously 1.0
        lineStyle.lineColor              = [[CPTColor alloc] initWithCGColor: [UIColorFromRGB(0x97B80E) CGColor]];
        dataSourceLinePlot.dataLineStyle = lineStyle;
        
        newGraph.plotAreaFrame.plotArea.fill = [CPTFill fillWithColor:[CPTColor whiteColor]];//[CPTFill fillWithColor:[[CPTColor alloc] initWithCGColor: [UIColorFromRGB(0x1432AE) CGColor]]];
        
        // Create a white, zero-pt style to hide axes
        CPTMutableLineStyle *axisStyle = [[CPTMutableLineStyle alloc]init];
        axisStyle.lineWidth = 0.0;
        axisStyle.lineColor = [CPTColor whiteColor];
        
        // Set the axis style so they're hidden in the background
        CPTXYAxisSet *axisSet = (CPTXYAxisSet*)[newGraph axisSet];
        axisSet.yAxis.axisLineStyle = axisStyle;
        axisSet.xAxis.axisLineStyle = axisStyle;
        
        dataSourceLinePlot.dataSource = self;
        [newGraph addPlot:dataSourceLinePlot];
        
    }
    
    CPTXYGraph *theGraph = self.hrvGraph;
    self.hrvGraphHostView.hostedGraph = theGraph;
    
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)theGraph.defaultPlotSpace;
    
    NSDecimalNumber *high   = [[NSDecimalNumber alloc] initWithString:@"255.0"];
    NSDecimalNumber *low    = [[NSDecimalNumber alloc] initWithString:@"0"];
    NSDecimalNumber *length = [high decimalNumberBySubtracting:low];
    
    //Configuring dynamical adjustment of x and y axes
    //int total = (int)[PPGCollectedData count];
    int total = hrvLength;
    //float lowY = 255;
    //double lowY = 0;
    //float highY = 0;
    //double highY = 10000;//140;
    //double hrvMax = 1;
    //double hrvMin = 0;
    if(total>xRangeEndHrv){
        xRangeStartHrv = total - xRangeEndHrv;
    }
    
    
    /*if(total > 15){
        // Se the highest and lowest values for y
        
        for (int i = xRangeStartHrv; i<total - 25; i++) {
            
            double currentVal = hrvFunctionOutput[i];
            
            if(currentVal > hrvMax) {
                hrvMax = currentVal;
                NSLog(@"Changing HRV max");
            }
            
            if(currentVal < hrvMin) {
               hrvMin = currentVal;
            }
        }
        
        if (fabs(yRangeStartHrv - hrvMin) > 5)
            yRangeStartHrv = hrvMin - 2;
        
        if(fabs(yRangeEndHrv - hrvMax) > 5)
            yRangeEndHrv = hrvMax + 2;
    }*/
    
    NSNumber *newXStart = [NSNumber numberWithDouble:xRangeStartHrv];
    NSNumber *newXEnd = [NSNumber numberWithDouble:xRangeEndHrv]; // changed from xrangeend
    NSNumber *newYStart = [NSNumber numberWithDouble:yRangeStartHrv];
    NSNumber *newYEnd = [NSNumber numberWithDouble:(yRangeEndHrv - yRangeStartHrv)];
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:newXStart length:newXEnd];
    plotSpace.yRange = [CPTPlotRange plotRangeWithLocation:newYStart length:newYEnd];
    
    // Axes
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)theGraph.axisSet;
    
    CPTXYAxis *x = axisSet.xAxis;
    x.hidden = YES;
    x.axisLabels = nil;
    x.majorIntervalLength   = @10.0;
    x.orthogonalPosition    = @0.0;
    x.minorTicksPerInterval = 4;
    
    CPTXYAxis *y  = axisSet.yAxis;
    NSDecimal six = CPTDecimalFromInteger(6);
    y.majorIntervalLength   = [NSDecimalNumber decimalNumberWithDecimal:CPTDecimalDivide(length.decimalValue, six)];
    y.majorTickLineStyle    = nil;
    y.minorTicksPerInterval = 4;
    y.minorTickLineStyle    = nil;
    y.orthogonalPosition    = @0.0;
    y.alternatingBandFills  = @[[[CPTColor whiteColor] colorWithAlphaComponent:CPTFloat(0.1)], [NSNull null]];
    
    [theGraph reloadData];
    
}


-(NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plotnumberOfRecords {
    if ([(NSString *)plotnumberOfRecords.identifier isEqualToString:@"Visualization Plot"] || [(NSString *)plotnumberOfRecords.identifier isEqualToString:@"IHR Plot"]) {
        return arrayLength;
    } else {
        return hrvLength;
    }
    //return [PPGCollectedData count];
}


-(NSNumber *)numberForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)index {
    
    // This method is actually called twice per point in the plot, one for the X and one for the Y value
    if(fieldEnum == CPTScatterPlotFieldX) {
        return [NSNumber numberWithInt: (int)index];
    } else {
        if ([(NSString *)plot.identifier isEqualToString:@"Visualization Plot"])
        {
            if (instantHRVisualization)
                return [NSNumber numberWithDouble: iirFunctionOutput[index]];
            else
                return [NSNumber numberWithDouble: sineFunctionOutput[index]];
        } else if ([(NSString *)plot.identifier isEqualToString:@"IHR Plot"]){
            return [NSNumber numberWithDouble: iirFunctionOutput[index]];
        } else {
            return [NSNumber numberWithDouble: hrvFunctionOutput[index]];
        }
        
    }
}


//
// Logging Functions //
//
-(void) createFiles:(BOOL) create {
    
    createFile = create;
    //Getting the documents path to write the file
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    //Getting the date to format the document name
    NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
    NSString *currentDate = [dateFormatter stringFromDate:[NSDate date]];
    
    
    //Documents path
    self.filePathPPG = [documentsDirectory stringByAppendingPathComponent:[[@"ppgValues" stringByAppendingString: currentDate] stringByAppendingString:@".txt"]];
    NSLog(@"Created file: %@", self.filePathPPG);
    self.filePathIIR = [documentsDirectory stringByAppendingPathComponent:[[@"iirValues" stringByAppendingString: currentDate] stringByAppendingString:@".txt"]];
    NSLog(@"Created file: %@", self.filePathIIR);
    self.filePathSine = [documentsDirectory stringByAppendingPathComponent:[[@"sineValues" stringByAppendingString: currentDate] stringByAppendingString:@".txt"]];
    NSLog(@"Created file: %@", self.filePathSine);
    self.filePathHRV = [documentsDirectory stringByAppendingPathComponent:[[@"hrvValues" stringByAppendingString: currentDate] stringByAppendingString:@".txt"]];
    NSLog(@"Created file %@", self.filePathHRV);
    
    
    //Handler to write into file
    [[NSFileManager defaultManager] createFileAtPath:self.filePathPPG contents:nil attributes:nil];
    [@"" writeToFile:self.filePathPPG atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [[NSFileManager defaultManager] createFileAtPath:self.filePathIIR contents:nil attributes:nil];
    [@"" writeToFile:self.filePathIIR atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [[NSFileManager defaultManager] createFileAtPath:self.filePathSine contents:nil attributes:nil];
    [@"" writeToFile:self.filePathSine atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [[NSFileManager defaultManager] createFileAtPath:self.filePathHRV contents:nil attributes:nil];
    [@"" writeToFile:self.filePathHRV atomically:YES encoding:NSUTF8StringEncoding error:nil];
}


-(void) writeToEndOfFilePPG: (NSString *) str{
    NSFileHandle *myh= [NSFileHandle fileHandleForWritingAtPath:self.filePathPPG];
    [myh seekToEndOfFile];
    [myh writeData:[str dataUsingEncoding:NSUTF8StringEncoding]];
}


-(void) writeToEndOfFileIIR: (NSString *) str {
    NSFileHandle *myh = [NSFileHandle fileHandleForWritingAtPath:self.filePathIIR];
    [myh seekToEndOfFile];
    [myh writeData:[str dataUsingEncoding:NSUTF8StringEncoding]];
}


-(void) writeToEndOfFileSine: (NSString *) str {
    NSFileHandle *myh = [NSFileHandle fileHandleForWritingAtPath:self.filePathSine];
    [myh seekToEndOfFile];
    [myh writeData:[str dataUsingEncoding:NSUTF8StringEncoding]];
}


-(void) writeToEndOfFileHRV: (NSString *) str {
    NSFileHandle *myh = [NSFileHandle fileHandleForWritingAtPath:self.filePathHRV];
    [myh seekToEndOfFile];
    [myh writeData:[str dataUsingEncoding:NSUTF8StringEncoding]];
}


//
// Other functions //
//
- (void) addPPG: (float) ppg withTimeStamp: (double) timeStamp{
    if((int)[PPGCollectedData count] >= MAX_N_SAMPLES){
        //Remove the old one
        [PPGCollectedData removeObjectAtIndex:0];
        [PPGCollectedDataTimeStamps removeObjectAtIndex:0];
    }
    
    [PPGCollectedData addObject:[NSNumber numberWithFloat:ppg]];
    [PPGCollectedDataTimeStamps addObject:[NSNumber numberWithDouble: timeStamp]];
    
    if (shouldLog) {
        [self writeToEndOfFilePPG: [NSString stringWithFormat:@"%f, %f\n", ppg, timeStamp]];
    }
}


-(double*) applyFftToArray {
    double *arrayCopy = malloc(arrayLength * sizeof(double));
    for (int i = 0; i < arrayLength - 1; i++) {
        arrayCopy[i] = iirFunctionOutput[i+1] - iirFunctionOutput[i];
    }
    
    /*for (int i = arrayLength ; i < arrayLength * 2; i++) {
        arrayCopy[i] = 0;
    }*/
    
    /* MOVED TO INIT FUNCTION BECAUSE ITS SUPPOSEDLY EXPENSIVE
    vDSP_Length fftRadix = log2(arrayLength);
    
    FFTSetupD setup = vDSP_create_fftsetupD(fftRadix, FFT_RADIX2); */
    int halfSamples = (int)(arrayLength / 2);

    double *window = (double *)malloc(sizeof(double) * arrayLength);
    vDSP_hamm_windowD(window, arrayLength, 0);
    vDSP_vmulD(arrayCopy, 1, window, 1, arrayCopy, 1, arrayLength);
    
    DOUBLE_COMPLEX_SPLIT A;
    A.realp = (double *) malloc(halfSamples * sizeof(double));
    A.imagp = (double *) malloc(halfSamples * sizeof(double));
    
    vDSP_ctozD((DSPDoubleComplex*)arrayCopy, 2, &A, 1, halfSamples);
    vDSP_fft_zripD(setupHRV, &A, 1, fftRadixHRV, FFT_FORWARD);
    
    double *absFFT = [HelperFunctions complexAbsD:A withSize:halfSamples];
    
    // Free these since they were created with malloc
    free(A.realp);
    free(A.imagp);
    free(window);
    free(arrayCopy);
    
    return absFFT;
}


-(void) applyFFT{
    
    int dataNum = (int)[PPGCollectedData count];
    if(dataNum > FFT_MIN_SAMPLES_N){
        int samplesToTake = FFT_MIN_SAMPLES_N;
        if(dataNum > FFT_OPT_SAMPLES_N){
            samplesToTake = FFT_OPT_SAMPLES_N;
        }
        
        //Copying last n ppg sample data for manipulation
        NSArray *ppgData = [PPGCollectedData subarrayWithRange:(NSRange){dataNum-samplesToTake, samplesToTake}];
        
        //NSMutableArray *ppgData = [[NSMutableArray alloc] initWithArray:[PPGCollectedData copy]];
        int numSamples = (int)[ppgData count];
        
        //Setup the radix (exponent)
        vDSP_Length fftRadix = log2(numSamples);
        int halfSamples = (int)(numSamples / 2);

        //And setup the FFT
        FFTSetup setup = vDSP_create_fftsetup(fftRadix, FFT_RADIX2);

        
        //Getting a simple float array of PPG data
        float *ppgSamples = malloc(numSamples * sizeof(float));
        for (int i=0;i<numSamples;i++){
            ppgSamples[i] = [ppgData[i] floatValue] ;
        }
        
        //Convert the real data to complex data
        //Populate *window with the values for a hamming window function
        float *window = (float *)malloc(sizeof(float) * numSamples);
        vDSP_hamm_window(window, numSamples, 0);
        //Window the samples
        vDSP_vmul(ppgSamples, 1, window, 1, ppgSamples, 1, numSamples);
        
        //Define complex buffer
        COMPLEX_SPLIT A;
        A.realp = (float *) malloc(halfSamples * sizeof(float));
        A.imagp = (float *) malloc(halfSamples * sizeof(float));
        
        // Pack samples:
        vDSP_ctoz((COMPLEX*)ppgSamples, 2, &A, 1, halfSamples);
        
        // Perform a forward FFT using fftSetup and A, results returned in A
        vDSP_fft_zrip(setup, &A, 1, fftRadix, FFT_FORWARD);
        
        double freq[halfSamples];
        
        // freq = 0:(Fs/num_samples):Fs-(Fs/num_samples);
        double f = 0.0;
        for (int i=0;i<halfSamples;i++){
            freq[i] = f;
            f += Fs / numSamples;
        }
        
        float *absFFT = [HelperFunctions complexAbs:A withSize:halfSamples];
        
        // Find the max
        int maxIndex = 0;
        float maxAmp = 0.0;
        
        //Consider only the frequencies between 0.8-4.0 Hz
        //Verify if is a peak. So absFFT[i-1] < absFFT[i] > absFFT[i+1]
        for(int i=1; i < halfSamples; i++){ // took away half - 1
            if(freq[i] >= min_fft_hz && freq[i] <= max_fft_hz){//Consider only valid frequencies for Heartbeats 60-120 BPM
                if(absFFT[i] > maxAmp){//Validate is greater than the last one
                    maxAmp = absFFT[i];
                    maxIndex = i;
                }
            }
        }
        
        // Free these variables since they were made with malloc
        free(window);
        free(ppgSamples);
        free(A.realp);
        free(A.imagp);
        free(absFFT);
        
        [beatDetection setFrequency:freq[maxIndex]];
        //NSLog(@"%f hz", freq[maxIndex]);
    }
    
}


@end
