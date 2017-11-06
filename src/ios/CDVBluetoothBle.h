//
//  ViewController.h
//  BluetoothDemo
//
//  Created by Thomas.Wang on 2017/9/9.
//  Copyright © 2017年 Thomas.Wang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Cordova/CDVPlugin.h>
//类的声明
@interface CDVBluetoothBle : CDVPlugin

- (void)getWifiName:(CDVInvokedUrlCommand*)command;
- (void)bluetoothBleSearch:(CDVInvokedUrlCommand*)command;
- (void)bluetoothBleSend:(CDVInvokedUrlCommand*)command;
- (void)bluetoothBleStop:(CDVInvokedUrlCommand*)command;
@end

