"""
BioLab Analytics - lab automation device (Description.md section 2.6 /
Plan_Maquette.txt section 6).

Simulates a real industrial protocol used by lab sequencers / automated
sample handlers: Modbus TCP. Registers exposed (holding registers):

  0: sample_count      (increments over time, simulating throughput)
  1: temperature_c      (oscillates in a plausible range)
  2: machine_status     (0=idle, 1=running, 2=error)
  3: door_sensor        (0=closed, 1=open)

Deliberate weakness: Modbus TCP has NO built-in authentication or
encryption by design (this is a protocol-level fact, not a
misconfiguration) -- anyone who can reach this container on TCP/502 can
read AND write these registers. Combined with this device sitting on the
same flat network as the administrative workstations (net_sci_admin, see
terraform/networks.tf), any compromised workstation on that network can
manipulate a piece of lab equipment.
"""

import random
import threading
import time

from pymodbus.datastore import (
    ModbusSequentialDataBlock,
    ModbusSlaveContext,
    ModbusServerContext,
)
from pymodbus.server import StartTcpServer

SAMPLE_COUNT = 0
TEMPERATURE = 1
MACHINE_STATUS = 2
DOOR_SENSOR = 3

store = ModbusSlaveContext(
    hr=ModbusSequentialDataBlock(0, [0, 21, 1, 0]),  # initial values
)
context = ModbusServerContext(slaves=store, single=True)


def simulate_operation():
    """Background thread: makes the registers evolve like a real machine
    would, independently of whatever a client reads/writes."""
    sample_count = 0
    while True:
        sample_count += 1
        temperature = 20 + random.uniform(-1.5, 1.5)
        status = 1  # running

        store.setValues(3, SAMPLE_COUNT, [sample_count])
        store.setValues(3, TEMPERATURE, [int(temperature * 10)])  # tenths of a degree
        store.setValues(3, MACHINE_STATUS, [status])

        time.sleep(5)


def main() -> None:
    thread = threading.Thread(target=simulate_operation, daemon=True)
    thread.start()

    print("[automate] Modbus TCP server listening on 0.0.0.0:502 (no auth)")
    StartTcpServer(context=context, address=("0.0.0.0", 502))


if __name__ == "__main__":
    main()
