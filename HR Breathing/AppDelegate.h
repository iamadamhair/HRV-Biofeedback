//
//  AppDelegate.h
//  HR Breathing
//
//  Created by Adam Hair on 5/23/17.
//  Copyright © 2017 Adam Hair. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import <Empalink-ios-0.7-full/EmpaticaAPI-0.7.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong) NSPersistentContainer *persistentContainer;

- (void)saveContext;


@end

