# AirPod Pro CLI

A simple CLI for interacting with paired AirPod Pro devices. 

## Usage

```
./airpods-pro --help
OVERVIEW: Control available AirPod Pro devices

USAGE: airpods-pro <subcommand>

OPTIONS:
  -h, --help              Show help information.

SUBCOMMANDS:
  list                    List available AirPod Pro devices
  set-mode                Set the listening mode of a specified AirPod Pro device

  See 'airpods-pro help <subcommand>' for detailed help.
```

## Credits

* The code used to inspect / set the listening mode of an AirPods Pro device was taken from [NoiseBuddy](https://github.com/insidegui/NoiseBuddy)
* The code to ensure bluetooth is on, and to connect to the selected device was taken from [BluetoothConnector](https://github.com/lapfelix/BluetoothConnector)