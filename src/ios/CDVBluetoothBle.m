//
//  ViewController.m
//  BluetoothDemo
//
//  Created by Thomas.Wang on 2017/9/9.
//  Copyright © 2017年 Thomas.Wang. All rights reserved.
//

#import "CDVBluetoothBle.h"
#import "CoreBluetooth/CoreBluetooth.h"
#import <SystemConfiguration/CaptiveNetwork.h>

@interface CDVBluetoothBle ()<CBCentralManagerDelegate,CBPeripheralDelegate>

@property CBCentralManager* centralManger;
@property NSMutableArray* peripherals;
@property int packageNum;
@property int packageMaxByte ;
@property NSMutableArray * sendArray;
@property NSMutableData * receiveData;
@property NSString * callBackId;
@property NSString *ssid ;
@property NSString *pwd ;
@property NSString *psn ;
@end

//类的实现
@implementation CDVBluetoothBle

- (NSMutableData *)extracted {
    NSMutableData *mData = [[NSMutableData alloc] init];
    return mData;
}

- (void)pluginInitialize {
    
    // Do any additional setup after loading the view, typically from a nib.
    
    
    self.packageMaxByte = 17;
    self.sendArray = [[NSMutableArray alloc] initWithCapacity:0];
    self.receiveData= [self extracted];
    
    //初始化方法
    //设置的代理需要遵守CBCentralManagerDelegate协议
    //queue可以设置蓝牙扫描的线程 传入nil则为在主线程中进行
    self.centralManger = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    self.peripherals = [NSMutableArray array];
    
}

-(NSMutableArray*)generateSendArray{
    NSMutableArray* sendArray =[[NSMutableArray alloc] initWithCapacity:0];
    NSString *sendJsonData =[self generateJsonData];
    NSLog(@"generateJsonData : %@",sendJsonData);
    
    NSData *sendBytes = [sendJsonData dataUsingEncoding:NSUTF8StringEncoding];
    NSUInteger sendBytesLen =sendBytes.length;
    
    int num = sendBytesLen%self.packageMaxByte;
    if (num == 0) {
        self.packageNum = (int)sendBytesLen/self.packageMaxByte;
    }else{
        self.packageNum = (int)sendBytesLen/self.packageMaxByte+1;
    }
    
    
    for(int i = 0;i<self.packageNum;i++){
        Byte byte[] = {0x2b,self.packageNum,i+1};
        NSMutableData * mData = [self extracted];
        [mData appendBytes:byte length:3];
        NSData * subDate;
        if (i == self.packageNum-1) {
            subDate = [sendBytes subdataWithRange:NSMakeRange(i*self.packageMaxByte, num)];
        }else{
            subDate = [sendBytes subdataWithRange:NSMakeRange(i*self.packageMaxByte, self.packageMaxByte)];
        }
        
        [mData appendData:subDate];
        [sendArray addObject:mData];
    }
    
    return sendArray;
}

// 中心管理者连接外设成功
-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{
    
    NSLog(@"中心管理者连接外设成功");
    peripheral.delegate =self;
    //发现服务
    [peripheral discoverServices:nil];
    
}
//中心管理者连接外设失败
-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    NSLog(@"中心管理者连接外设失败");
}

//丢失连接
-(void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    NSLog(@"丢失连接");
}


-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    NSLog(@"%s",__FUNCTION__);
    for (CBService *service in peripheral.services) {
        NSLog(@"services = %@",service.UUID.UUIDString);
        [peripheral discoverCharacteristics:nil forService:service];
    }
    
    
}

// 发现外设服务里的特征的时候调用的代理方法(这个是比较重要的方法，你在这里可以通过事先知道UUID找到你需要的特征，订阅特征，或者这里写入数据给特征也可以)
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    NSLog(@"%s, line = %d", __FUNCTION__, __LINE__);
    
    for (CBCharacteristic *cha in service.characteristics) {
        NSLog(@"%s, line = %d, char = %@", __FUNCTION__, __LINE__, cha);
     
        if ([@"2ABC" isEqualToString:cha.UUID.UUIDString]) {
            //第一个参数是已连接的蓝牙设备 ；第二个参数是要写入到哪个特征； 第三个参数是通过此响应记录是否成功写入
            
            [peripheral setNotifyValue:true forCharacteristic:cha];
            for (int i = 0; i<[self.sendArray count]; i++) {
                 [peripheral writeValue:[self.sendArray objectAtIndex:i] forCharacteristic:cha type:CBCharacteristicWriteWithResponse];
            }
           
        }
        
    }
}

-(NSString *) generateJsonData{
    NSMutableDictionary *detailDic = [[NSMutableDictionary alloc] init];
    [detailDic setValue:self.ssid forKey:@"wifiSSID"];
    [detailDic setValue:self.pwd forKey:@"password"];
    [detailDic setValue:self.psn forKey:@"psn"];
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:detailDic options:0 error:nil];
    NSString * myString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    return myString;
    
}



// 更新特征的value的时候会调用 （凡是从蓝牙传过来的数据都要经过这个回调，简单的说这个方法就是你拿数据的唯一方法） 你可以判断是否
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
//    NSLog(@"%s, line = %d", __FUNCTION__, __LINE__);
    if ( [@"2ABC" isEqualToString:characteristic.UUID.UUIDString]) {
        //characteristic.value就是你要的数据
//        NSString *aString = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
//        NSLog(@"接受到的数据：%@",aString);
        
        Byte * bytes = (Byte *)[characteristic.value bytes];
        UInt8 start =  bytes[0];
        
        if (start == 0x2c) {
            UInt8 packageNum =  bytes[1];
            UInt8 packageIndex =  bytes[2];
            NSData *subDate = [characteristic.value subdataWithRange:NSMakeRange(3, [characteristic.value length]-3)];
            [self.receiveData appendData: subDate];
            if (packageIndex>=packageNum) {
                 NSString *aString = [[NSString alloc] initWithData:self.receiveData encoding:NSUTF8StringEncoding];
                NSLog(@"接受到的数据：%@",aString);
                NSDictionary* receivedDictionary = [self dictionaryWithJsonString:aString];
                int resultId = [[receivedDictionary objectForKey:@"id"] intValue];
                NSString* resultContent = [receivedDictionary objectForKey:@"content"];
                if (resultId==0) {
                    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:resultContent];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callBackId];
                }else{
                    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:resultContent];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callBackId];
                }
                //清空数据
                [self.receiveData resetBytesInRange:NSMakeRange(0, self.receiveData.length)];
                [self.receiveData setLength:0];
                [self.centralManger cancelPeripheralConnection:peripheral];
            }
            
        }
        
        
    }
}

/*!
 * @brief 把格式化的JSON格式的字符串转换成字典
 * @param jsonString JSON格式的字符串
 * @return 返回字典
 */
- (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString {
    if (jsonString == nil) {
        return nil;
    }
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONReadingMutableContainers
                                                          error:&err];
    if(err) {
        NSLog(@"json解析失败：%@",err);
        return nil;
    }
    return dic;
}

-(void)centralManagerDidUpdateState:(CBCentralManager *)central{
    switch(central.state) {
        case CBCentralManagerStatePoweredOn:
            NSLog(@"The central manager is powered on and ready.");
            break;
        default:
            break;
    }
}
//扫描的结果会在如下代理方法中回掉：

//peripheral 扫描到的外设
//advertisementData是外设发送的广播数据
//RSSI 是信号强度
-(void) centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI{
    
    if(peripheral.name.length > 0&&![self.peripherals containsObject:peripheral]){
        
        [self.peripherals addObject:peripheral];
        //向上反馈一个
        NSMutableDictionary *detailDic = [[NSMutableDictionary alloc] init];
        [detailDic setValue:peripheral.name forKey:@"name"];
        [detailDic setValue:[NSString stringWithFormat:@"%ld",[self.peripherals indexOfObject:peripheral]] forKey:@"deviceIndex"];
        NSData * jsonData = [NSJSONSerialization dataWithJSONObject:detailDic options:0 error:nil];
        NSString * myString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        NSLog(@"myString:%@",myString);
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:myString];
        [pluginResult setKeepCallbackAsBool:true];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callBackId];
    }
    
   
}





- (void)getWifiName:(CDVInvokedUrlCommand*)command{
    NSString *apSsid = [self currentWifiSSID];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:apSsid];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (NSString *)currentWifiSSID
{
    NSString *ssid = nil;
    NSArray *ifs = (__bridge   id)CNCopySupportedInterfaces();
    for (NSString *ifname in ifs) {
        NSDictionary *info = (__bridge id)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifname);
        if (info[@"SSID"])
        {
            ssid = info[@"SSID"];
        }
    }
    return ssid;
}

//开始搜索
- (void)bluetoothBleSearch:(CDVInvokedUrlCommand*)command{
    NSLog(@"BluetoothSearch");
    for (CBPeripheral* peripheral in self.peripherals) {
        if (peripheral.state != CBPeripheralStateDisconnected) {
            [self.centralManger cancelPeripheralConnection:peripheral];
        }
    }
    [self.peripherals removeAllObjects];
     self.callBackId = command.callbackId;
    [self.centralManger stopScan];
    [self.centralManger scanForPeripheralsWithServices:nil options:nil];
   
}

- (void)bluetoothBleSend:(CDVInvokedUrlCommand*)command{
    self.callBackId = command.callbackId;
    [self.centralManger stopScan];
    NSArray *arguments = command.arguments;
    self.ssid = arguments[0];
    self.pwd = arguments[1];
    int deviceIndex =[arguments[2] intValue];
    self.psn = arguments[3];
    self.sendArray = [self generateSendArray];
    CBPeripheral *peripheral = self.peripherals[deviceIndex];
    [self.centralManger connectPeripheral:peripheral options:nil];
    
    
}

//停止搜索
- (void)bluetoothBleStop:(CDVInvokedUrlCommand*)command{
    [self.centralManger stopScan];
}


@end
