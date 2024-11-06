#import "ViewController.h"

@interface ViewController ()

@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *connectedPeripheral;
@property (strong, nonatomic) CBCharacteristic *writeCharacteristic;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    
    [self setupUI];
}

#pragma mark - UI Setup

- (void)setupUI {
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    self.startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.startButton setTitle:@"Start Recording" forState:UIControlStateNormal];
    [self.startButton addTarget:self action:@selector(startRecording:) forControlEvents:UIControlEventTouchUpInside];
    self.startButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.startButton];
    
    self.stopButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.stopButton setTitle:@"Stop Recording" forState:UIControlStateNormal];
    [self.stopButton addTarget:self action:@selector(stopRecording:) forControlEvents:UIControlEventTouchUpInside];
    self.stopButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.stopButton];
    
    self.dataTextView = [[UITextView alloc] init];
    self.dataTextView.editable = NO;
    self.dataTextView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.dataTextView.layer.borderWidth = 1.0;
    self.dataTextView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.dataTextView];
    
    [self setupConstraints];
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[

        [self.startButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.startButton.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [self.startButton.widthAnchor constraintEqualToConstant:150],
        [self.startButton.heightAnchor constraintEqualToConstant:50],
        
        [self.stopButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.stopButton.topAnchor constraintEqualToAnchor:self.startButton.bottomAnchor constant:20],
        [self.stopButton.widthAnchor constraintEqualToConstant:150],
        [self.stopButton.heightAnchor constraintEqualToConstant:50],
        
        [self.dataTextView.topAnchor constraintEqualToAnchor:self.stopButton.bottomAnchor constant:20],
        [self.dataTextView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.dataTextView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.dataTextView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20],
    ]];
}

#pragma mark - Button Animations

- (void)animateButton:(UIButton *)button {
    [UIView animateWithDuration:0.1 animations:^{
        button.transform = CGAffineTransformMakeScale(0.95, 0.95);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.1 animations:^{
            button.transform = CGAffineTransformIdentity;
        }];
    }];
}

#pragma mark - Button Actions

- (IBAction)startRecording:(id)sender {
    [self animateButton:self.startButton];
    [self sendCommandToArduino:@"R"];
}

- (IBAction)stopRecording:(id)sender {
    [self animateButton:self.stopButton];
    [self sendCommandToArduino:@"S"];
}

#pragma mark - Bluetooth Communication

- (void)sendCommandToArduino:(NSString *)command {
    if (self.connectedPeripheral && self.writeCharacteristic) {
        NSData *commandData = [command dataUsingEncoding:NSUTF8StringEncoding];
        [self.connectedPeripheral writeValue:commandData forCharacteristic:self.writeCharacteristic type:CBCharacteristicWriteWithResponse];
    } else {
        [self showAlertWithTitle:@"Not Connected" message:@"Please connect to a device first."];
    }
}

#pragma mark - CBCentralManagerDelegate Methods

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state == CBManagerStatePoweredOn) {
        [self.centralManager scanForPeripheralsWithServices:nil options:nil];
    } else {
        NSString *message = @"Bluetooth is not available.";
        if (central.state == CBManagerStatePoweredOff) {
            message = @"Please enable Bluetooth in settings.";
        } else if (central.state == CBManagerStateUnsupported) {
            message = @"Bluetooth Low Energy is not supported on this device.";
        }
        [self showAlertWithTitle:@"Bluetooth Error" message:message];
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI {
    if ([peripheral.name containsString:@"HC-05"]) {
        self.connectedPeripheral = peripheral;
        self.connectedPeripheral.delegate = self;
        [self.centralManager stopScan];
        [self.centralManager connectPeripheral:peripheral options:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    [self showAlertWithTitle:@"Connection Failed" message:error.localizedDescription];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSString *message = error ? error.localizedDescription : @"The device disconnected unexpectedly.";
    [self showAlertWithTitle:@"Disconnected" message:message];
    [self.centralManager scanForPeripheralsWithServices:nil options:nil];
}

#pragma mark - CBPeripheralDelegate Methods

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        [self showAlertWithTitle:@"Service Discovery Error" message:error.localizedDescription];
        return;
    }
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        [self showAlertWithTitle:@"Characteristic Discovery Error" message:error.localizedDescription];
        return;
    }
    for (CBCharacteristic *characteristic in service.characteristics) {
        if (characteristic.properties & CBCharacteristicPropertyWrite) {
            self.writeCharacteristic = characteristic;
        }
        if (characteristic.properties & CBCharacteristicPropertyNotify) {
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        [self showAlertWithTitle:@"Data Error" message:error.localizedDescription];
        return;
    }
    NSString *receivedString = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    self.dataTextView.text = [self.dataTextView.text stringByAppendingFormat:@"%@\n", receivedString];
}

#pragma mark - Helper Methods

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
