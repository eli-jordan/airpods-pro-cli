//
//  airpods_pro_core_tests.swift
//  airpods-pro-core-tests
//
//  Created by Elias Jordan on 6/8/20.
//  Copyright © 2020 Elias Jordan. All rights reserved.
//

@testable import airpods_pro_core
import XCTest

class CommandsTest: XCTestCase {
   func test_airpod_pro_device_is_correctly_formatted_as_text() throws {
      let device1 = AirPodProDevice(
         underlying: IOBluetoothDevice(),
         name: "Eli's AirPods Pro",
         mode: .Off,
         state: .Connected
      )

      let device2 = AirPodProDevice(
         underlying: IOBluetoothDevice(),
         name: "Bob's Bluetooth Banana",
         mode: .NoiseCancellation,
         state: .Disconnected
      )

      let expectedText =
         "Name                           Connection State     Listening Mode      " + "\n" +
         "Eli's AirPods Pro              Connected            Off                 " + "\n" +
         "Bob's Bluetooth Banana         Disconnected         NoiseCancellation   "

      let text = AirPodProDeviceList.formatAsText([device1, device2])

      XCTAssertEqual(text, expectedText)
   }

   func test_airpod_pro_device_is_correctly_formatted_as_json() throws {
      let device1 = AirPodProDevice(
         underlying: IOBluetoothDevice(),
         name: "Test Name",
         mode: .Off,
         state: .Connected
      )

      let device2 = AirPodProDevice(
         underlying: IOBluetoothDevice(),
         name: "Test Name 2",
         mode: .Transparency,
         state: .Connected
      )

      let json = AirPodProDeviceList.formatAsJson([device1, device2])

      let parsed = try! JSONSerialization.jsonObject(with: Data(json.utf8), options: []) as! [[String: String]]

      XCTAssertEqual(parsed[0]["name"], "Test Name")
      XCTAssertEqual(parsed[0]["connectionState"], "Connected")
      XCTAssertEqual(parsed[0]["listeningMode"], "Off")

      XCTAssertEqual(parsed[1]["name"], "Test Name 2")
      XCTAssertEqual(parsed[1]["connectionState"], "Connected")
      XCTAssertEqual(parsed[1]["listeningMode"], "Transparency")
   }
   
   
}
