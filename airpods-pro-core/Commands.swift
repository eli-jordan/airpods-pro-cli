
import AMCoreAudio
import ArgumentParser
import Foundation
import IOBluetooth

/**
 * Represents the connection state of a AirPod Pro device
 */
enum ConnectionState: String, CaseIterable {
   case Connected
   case Disconnected
}

/**
 * Represents the current mode of an AirPod Pro device.
 *
 * IOBluetoothDevice uses a UInt8 to represent the three modes, so there are also conversions
 * to / from this representation.
 */
enum ListeningMode: String, CaseIterable, ExpressibleByArgument {
   case Off
   case NoiseCancellation
   case Transparency

   // Convert this listening mode into the UInt8 representation
   func codeValue() -> UInt8 {
      switch self {
         case .Off: return 1
         case .NoiseCancellation: return 2
         case .Transparency: return 3
      }
   }

   // Convert the provided UInt8 representation into the the ListeningMode representation
   static func fromCode(_ code: UInt8) -> ListeningMode? {
      ListeningMode.allCases.filter { $0.codeValue() == code }.first
   }
}

/**
 * Represents the current state of a paired airpod device
 */
struct AirPodProDevice {
   let underlying: IOBluetoothDevice

   let name: String
   let mode: ListeningMode
   let state: ConnectionState

   // Create a new AirPodProDevice instance based on the provided IOBlueToothDevice
   static func from(_ device: IOBluetoothDevice) -> AirPodProDevice {
      let state = device.isConnected() ? ConnectionState.Connected : ConnectionState.Disconnected
      return AirPodProDevice(
         underlying: device,
         name: device.name,
         mode: ListeningMode.fromCode(device.listeningMode)!,
         state: state
      )
   }

   static func findAll() -> [AirPodProDevice] {
      IOBluetoothDevice.pairedDevices()?
         .compactMap { $0 as? IOBluetoothDevice }
         .filter { $0.isANCSupported() }
         .map { AirPodProDevice.from($0) } ?? []
   }
}

/**
 * Responsible for formatting the device list for output to the console.
 */
struct AirPodProDeviceList {
   // Format the list of devices as a textual table for output to the console
   static func formatAsText(_ devices: [AirPodProDevice]) -> String {
      let header = asTextRow(name: "Name", state: "Connection State", mode: "Listening Mode")
      let body = devices.map { asTextRow(device: $0) }.joined(separator: "\n")
      return header + "\n" + body
   }

   private static func asTextRow(device: AirPodProDevice) -> String {
      asTextRow(name: device.name, state: device.state.rawValue, mode: device.mode.rawValue)
   }

   private static func asTextRow(name: String, state: String, mode: String) -> String {
      let paddedDeviceName = name.padding(toLength: 30, withPad: " ", startingAt: 0)
      let paddedConnectionState = state.padding(toLength: 20, withPad: " ", startingAt: 0)
      let paddedListeningMode = mode.padding(toLength: 20, withPad: " ", startingAt: 0)

      return "\(paddedDeviceName) \(paddedConnectionState) \(paddedListeningMode)"
   }

   // Format the list of devices as a json array
   static func formatAsJson(_ devices: [AirPodProDevice]) -> String {
      let data = devices.map { asDictionary(device: $0) }
      // TODO: actual error handling
      return try! String(data: JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted]), encoding: .utf8)!
   }

   private static func asDictionary(device: AirPodProDevice) -> [String: Any] {
      [
         "name": device.name,
         "connectionState": device.state.rawValue,
         "listeningMode": device.mode.rawValue
      ]
   }
}

/**
 * Handles the 'activate' command, which sets the listening mode for a named
 * AirPod Pro device.
 */
func runActivateCommand(deviceName: String, inMode: ListeningMode, onChannel: AudioChannel) {
   let device = AirPodProDevice.findAll().filter { $0.name == deviceName }.first
   if device == nil {
      print("There are no AirpodPro devices named \(deviceName) available")
   } else {
      turnOnBluetoothIfNeeded()
      let btDevice = device!.underlying
      if device!.state == .Disconnected {
         btDevice.openConnection()
      }
      btDevice.listeningMode = inMode.codeValue()

      // Since we may have just connected to the bluetooth device
      // We poll the audio device list, until the device we connected
      // to is available, so that we can use it as input / output
      waitFor(timeout: 5) {
         AudioDevice.allDevices().filter { $0.name == deviceName }.count > 0
      }

      let audioDevices = AudioDevice.allDevices().filter { $0.name == deviceName }
      audioDevices.forEach { device in
         if device.isOutputOnlyDevice() {
            device.setAsDefaultOutputDevice()
         } else if device.isInputOnlyDevice() {
            device.setAsDefaultInputDevice()
         }
      }
   }
}

func waitFor(timeout: UInt32, _ condition: () -> Bool) {
   print("Running waitFor")
   var timeWaited: UInt32 = 0
   let interval: UInt32 = 200000 // 0.2 seconds as microseconds
   let timeoutMicros = timeout * 1000 * 1000
   while !condition() {
      usleep(interval)
      timeWaited += interval
      if timeWaited > timeoutMicros {
         fatalError("Error: Timedout after \(timeout) seconds")
      }
   }
}

/**
 * Turns on bluetooth if it is not already turned on.
 */
func turnOnBluetoothIfNeeded() {
   guard let bluetoothHost = IOBluetoothHostController.default(),
      bluetoothHost.powerState != kBluetoothHCIPowerStateON else { return }

   // Definitely not App Store safe
   if let iobluetoothClass = NSClassFromString("IOBluetoothPreferences") as? NSObject.Type {
      let obj = iobluetoothClass.init()
      let selector = NSSelectorFromString("setPoweredOn:")
      if obj.responds(to: selector) {
         obj.perform(selector, with: 1)
      }
   }

   waitFor(timeout: 5) {
      bluetoothHost.powerState == kBluetoothHCIPowerStateON
   }
}

/**
 * Handles the 'list' command, which lists all paired AirPod Pro devices.
 */
func runListCommand(format: OutputFormat) {
   let devices = AirPodProDevice.findAll()
   if devices.isEmpty {
      print("There are no AirpodPro devices available")
   } else {
      switch format {
         case .Text: print(AirPodProDeviceList.formatAsText(devices))
         case .Json: print(AirPodProDeviceList.formatAsJson(devices))
      }
   }
}

enum OutputFormat: String, CaseIterable, ExpressibleByArgument {
   case Text
   case Json
}

enum AudioChannel: String, CaseIterable, ExpressibleByArgument {
   case Input
   case Output
   case Both
}

/**
 * Defines the CLI, and delegates command execution to the above handlers.
 */
public struct AirpodsProCommandParser: ParsableCommand {
   public init() {}
   public static let configuration = CommandConfiguration(
      commandName: "airpods-pro",
      abstract: "Control available AirPod Pro devices",
      subcommands: [List.self, Activate.self]
   )

   struct List: ParsableCommand {
      static let configuration = CommandConfiguration(
         abstract: "List available AirPod Pro devices",
         discussion: """
         This will list all bluetooth devices that support active noise cancellation. This
         is used as a proxy for the device being AirPod Pros. The device name, current
         listening mode and whether its connected will be output.
         """
      )

      @Option(help: "The format of the generated results. Options are 'Text' and 'Json'")
      var format: OutputFormat = OutputFormat.Text

      func run() {
         runListCommand(format: format)
      }
   }

   struct Activate: ParsableCommand {
      static let configuration = CommandConfiguration(
         abstract: "Activate a named AirPods Pro device",
         discussion: """
         This will perform all the steps necessary to activate the specified device.
         - If bluetooth is turned off, it will be turned on
         - If the device is not connected, it will be connected
         - The listening mode of the device will be set
         - The default audio input and/or output will be set to the device
         """
      )

      @Argument(help: "The name of the device")
      var name: String

      @Option(help: "The listening mode to set. Options are 'Off', 'NoiseCancellation' and 'Transparency'")
      var mode: ListeningMode

      @Option(help: "Should the device be used for audio input and/or output. Options are 'Input', 'Output' and 'Both'")
      var audio: AudioChannel = .Both

      func run() {
         runActivateCommand(deviceName: name, inMode: mode, onChannel: audio)
      }
   }
}
