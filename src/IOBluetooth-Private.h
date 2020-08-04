
@import IOBluetooth;

@interface IOBluetoothDevice (Private)

- (BOOL) isANCSupported;

@property(readonly) BOOL isTransparencySupported;
@property(nonatomic) unsigned char listeningMode;

@end
