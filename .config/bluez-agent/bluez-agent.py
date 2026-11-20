#!/usr/bin/env python3
"""Minimal BlueZ pairing agent.

BlueZ refuses to complete a pairing with no agent registered
("No agent available for request type 2"), which makes CONNECT on an unpaired
device fail from any client that does not ship its own agent (quickshell, for
one). This registers a NoInputNoOutput agent, the "Just Works" pairing model
phones and earbuds use, and auto-confirms it.
"""

import sys

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

AGENT_PATH = "/org/bluez/agent/qsagent"
CAPABILITY = "NoInputNoOutput"


def log(message):
    print(message, flush=True)


class Agent(dbus.service.Object):
    def __init__(self, bus):
        super().__init__(bus, AGENT_PATH)

    @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
    def Release(self):
        log("released")

    @dbus.service.method("org.bluez.Agent1", in_signature="os", out_signature="")
    def AuthorizeService(self, device, uuid):
        log(f"authorize service {uuid} for {device}")

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="")
    def RequestAuthorization(self, device):
        log(f"authorize {device}")

    @dbus.service.method("org.bluez.Agent1", in_signature="ou", out_signature="")
    def RequestConfirmation(self, device, passkey):
        log(f"confirm {int(passkey):06d} for {device}")

    @dbus.service.method("org.bluez.Agent1", in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        log(f"display {int(passkey):06d} for {device} ({int(entered)} entered)")

    @dbus.service.method("org.bluez.Agent1", in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        log(f"pin {pincode} for {device}")

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="s")
    def RequestPinCode(self, device):
        log(f"pin requested for {device}")
        return "0000"

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="u")
    def RequestPasskey(self, device):
        log(f"passkey requested for {device}")
        return dbus.UInt32(0)

    @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
    def Cancel(self):
        log("cancelled")


def register(bus, agent):
    manager = dbus.Interface(
        bus.get_object("org.bluez", "/org/bluez"), "org.bluez.AgentManager1"
    )
    manager.RegisterAgent(AGENT_PATH, CAPABILITY)
    manager.RequestDefaultAgent(AGENT_PATH)
    log(f"registered {AGENT_PATH} as default agent ({CAPABILITY})")


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    agent = Agent(bus)

    try:
        register(bus, agent)
    except dbus.DBusException as error:
        # bluetoothd may still be starting; retry briefly rather than exiting.
        log(f"not registered yet: {error}")
        GLib.timeout_add_seconds(2, lambda: register(bus, agent) or False)

    return GLib.MainLoop().run()


if __name__ == "__main__":
    sys.exit(main())
