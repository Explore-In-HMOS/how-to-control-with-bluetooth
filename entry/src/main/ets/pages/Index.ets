import { ble, constant } from '@kit.ConnectivityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { abilityAccessCtrl, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit';

@Entry
@Component
struct SmartLampApp {
  @State isScanning: boolean = false;
   connectedDevice: string = 'Not Connected';
  @State statusLog: string = 'System Ready';
  private targetDeviceName: string = 'XXXXXXX'; // The name of your target device
  private serviceUuid: string = '0000ff01-0000-1000-8000-00805f9b34fb';
  private charUuid: string = '0000ff02-0000-1000-8000-00805f9b34fb';
  private gattClient: ble.GattClientDevice | null = null;
  private statusText = '';
  private isConnected = false;
  scroller : Scroller = new Scroller();
  async requestPermissions() {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const atManager = abilityAccessCtrl.createAtManager();

    // List of requested permissions
    const permissions: Array<Permissions> = [
      'ohos.permission.APPROXIMATELY_LOCATION',
      'ohos.permission.LOCATION',
      'ohos.permission.ACCESS_BLUETOOTH'
    ];

    try {
      const data: PermissionRequestResult = await atManager.requestPermissionsFromUser(context, permissions);
      const grantStatus: Array<number> = data.authResults;
      const allGranted = grantStatus.every(status => status === 0);

      if (allGranted) {
        this.statusText = 'Permissions granted, ready to scan.';
      } else {
        this.statusText = 'Error: Permissions denied!';
      }
    } catch (err) {

    }
  }

  aboutToAppear(): void {
    this.requestPermissions();
  }

  //1.DEVICE SCANNING
  startDiscovery() {
    try {
      this.isScanning = true;
      this.statusLog = 'Looking for a lamp...';

      // Scan filters and settings
      const scanOptions: ble.ScanOptions = { interval: 500, dutyMode: ble.ScanDuty.SCAN_MODE_LOW_POWER };

      ble.on('BLEDeviceFind', (devices) => {
        const device = devices[0];
        if (device.deviceName === this.targetDeviceName) {
          this.statusLog = 'The lamp was found, it\'s being connected...';
          ble.stopBLEScan();
          this.isScanning = false;
          this.connectToDevice(device.deviceId);
        }
      });

      ble.startBLEScan(null, scanOptions);
    } catch (e) {
      
    }
  }

  connectToDevice(deviceId: string) {
    try {
      this.gattClient = ble.createGattClientDevice(deviceId);
      this.gattClient.on('BLEConnectionStateChange', (state) => {

        const connectState: ble.ProfileConnectionState = state.state;
        if (constant.ProfileConnectionState.STATE_CONNECTED === connectState) {
          this.statusText = 'Connected! Services are being searched...';

          // 3. Discover services as soon as the connection is established
          this.gattClient?.getServices((err, services) => {
            if (!err) {
              this.isConnected = true;
              this.statusText = 'Lamp Ready! 💡';
              console.info('Service discovery successful.');
            } else {

            }
          });
        } else if (constant.ProfileConnectionState.STATE_DISCONNECTED === connectState) {
          this.isConnected = false;
          this.statusText = 'The connection was lost.';
          this.gattClient?.off('BLEConnectionStateChange'); //Stop listening
        }
      });
      this.gattClient.connect();

    } catch (error) {

    }

  }

  //3.SEND COMMAND (WRITE)
  sendValue(val: number) {
    if (!this.gattClient) {
      this.statusLog = 'Error: Connect first!';
      return;
    }

    const bufferCCC = new ArrayBuffer(8);
    const cccV = new Uint8Array(bufferCCC);

    const descriptors: Array<ble.BLEDescriptor> = [];
    const bufferDesc = new ArrayBuffer(2);
    const descV = new Uint8Array(bufferDesc);
    const uint8Array = new Uint8Array([val]);
    const bufferValue = uint8Array.buffer;
    descV[0] =
      0; // Use the Client Characteristic Configuration descriptor as an example. When bit 0 and
    // bit 1 are both set to 0, the notification and indication functions are disabled.
    const descriptor: ble.BLEDescriptor = {
      serviceUuid: this.serviceUuid,
      characteristicUuid: this.charUuid,
      descriptorUuid: '00002902-0000-1000-8000-00805F9B34FB',
      descriptorValue: bufferDesc
    };
    descriptors[0] = descriptor;
    const characteristic: ble.BLECharacteristic = {
      serviceUuid: this.serviceUuid,
      characteristicUuid: this.charUuid,
      characteristicValue: bufferValue,
      descriptors: descriptors
    };
    try {
      this.gattClient.writeCharacteristicValue(characteristic, ble.GattWriteType.WRITE);
    } catch (err) {

    }
  }

  writeCharacteristicValueCallBack(code: BusinessError) {
    if (code !== null) {
      return;
    }
    console.info('bluetooth writeCharacteristicValue success');
  }

  build() {
  Scroll(this.scroller) {
    Column({ space: 15 }) {
      Text('Smart Home Control Panel').fontSize(14).fontWeight(FontWeight.Bold);

      Divider();

      Text(`Durum: ${this.statusLog}`).fontColor(Color.Gray);
      Text(`Cihaz: ${this.connectedDevice}`).fontWeight(FontWeight.Medium);

      Button(this.isScanning ? 'Searching...' : 'Sheep Shearing and Tying')
        .onClick(() => this.startDiscovery())
        .enabled(!this.isScanning)
        .width('80%');

      Row({ space: 20 }) {
        Button('OPEN')
          .onClick(() => this.sendValue(1))
          .backgroundColor(Color.Green)
          .width('40%')
          .height(60);

        Button('CLOSE')
          .onClick(() => this.sendValue(0))
          .backgroundColor(Color.Red)
          .width('40%')
          .height(60);
      }.margin({ top: 20 });

    }.width('100%').padding(30).alignItems(HorizontalAlign.Center);
  }.scrollable(ScrollDirection.Vertical)
  }
}