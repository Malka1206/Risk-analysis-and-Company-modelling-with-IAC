"""
BioLab Analytics - Modbus vulnerability demo (Description.md section 2.6).

Run this from ANY workstation on net_sci_admin (e.g. ws_it or ws_admin) to
show that the lab automation device requires no credentials whatsoever:

  docker exec -it biolab-ws-it python modbus_demo.py --read
  docker exec -it biolab-ws-it python modbus_demo.py --write-status 2

Usage:
  python modbus_demo.py --read
  python modbus_demo.py --write-status <0|1|2>
"""

import argparse
import os

from pymodbus.client import ModbusTcpClient

AUTOMATE_HOST = os.environ.get("AUTOMATE_HOST", "automate")
AUTOMATE_PORT = int(os.environ.get("AUTOMATE_PORT", "502"))

REGISTER_NAMES = ["sample_count", "temperature_tenths_c", "machine_status", "door_sensor"]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--read", action="store_true")
    parser.add_argument("--write-status", type=int, choices=[0, 1, 2], default=None)
    args = parser.parse_args()

    client = ModbusTcpClient(AUTOMATE_HOST, port=AUTOMATE_PORT)
    client.connect()

    if args.write_status is not None:
        # No authentication required for this write -- that's the point.
        client.write_register(2, args.write_status)
        print(f"[modbus-demo] wrote machine_status={args.write_status} "
              f"with ZERO authentication.")

    result = client.read_holding_registers(0, 4)
    for name, value in zip(REGISTER_NAMES, result.registers):
        print(f"  {name}: {value}")

    client.close()


if __name__ == "__main__":
    main()
