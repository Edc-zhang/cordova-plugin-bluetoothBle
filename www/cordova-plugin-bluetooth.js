var exec = require('cordova/exec');

var bluetoothBle = {
    getWifiName:function(success){
      exec(success, null, "BluetoothBle", "getWifiName", []);
    },
    bluetoothBleSearch:function(success,error){
        exec(success, error, "BluetoothBle", "bluetoothBleSearch", []);
    },
    bluetoothBleSend:function(sendMessage,success,error){
        exec(success,error,"BluetoothBle","bluetoothBleSend",[sendMessage.ssid,sendMessage.pwd,sendMessage.deviceIndex,sendMessage.psn]);
    },
    bluetoothBleStop:function () {
      exec(null,null,"BluetoothBle","bluetoothBleStop",[]);
    }
};
module.exports = bluetoothBle;
