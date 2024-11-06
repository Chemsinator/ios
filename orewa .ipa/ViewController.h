#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface ViewController : UIViewController <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (strong, nonatomic) UIButton *startButton;
@property (strong, nonatomic) UIButton *stopButton;
@property (strong, nonatomic) UITextView *dataTextView;

@end
