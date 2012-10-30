# This module allows the test driver to connect to the virtual machine
# via a root shell attached to port 514.

{ config, pkgs, ... }:

with pkgs.lib;

let kernel = config.boot.kernelPackages.kernel; in

{

  config = {

    boot.systemd.services.backdoor =
      { wantedBy = [ "multi-user.target" ];
        requires = [ "dev-hvc0.device" "dev-ttyS0.device" ];
        after = [ "dev-hvc0.device" "dev-ttyS0.device" ];
        script =
          ''
            export USER=root
            export HOME=/root
            export DISPLAY=:0.0
            source /etc/profile
            cd /tmp
            exec < /dev/hvc0 > /dev/hvc0 2> /dev/ttyS0
            echo "connecting to host..." >&2
            stty -F /dev/hvc0 raw -echo # prevent nl -> cr/nl conversion
            echo
            PS1= exec /bin/sh
          '';
        serviceConfig.KillSignal = "SIGHUP";
      };

    # Prevent agetty from being instantiated on ttyS0, since it
    # interferes with the backdoor (writes to ttyS0 will randomly fail
    # with EIO).
    boot.systemd.services."serial-getty@ttyS0".enable = false;

    boot.initrd.postDeviceCommands =
      ''
        # Using acpi_pm as a clock source causes the guest clock to
        # slow down under high host load.  This is usually a bad
        # thing, but for VM tests it should provide a bit more
        # determinism (e.g. if the VM runs at lower speed, then
        # timeouts in the VM should also be delayed).
        echo acpi_pm > /sys/devices/system/clocksource/clocksource0/current_clocksource
      '';

    boot.postBootCommands =
      ''
        # Panic on out-of-memory conditions rather than letting the
        # OOM killer randomly get rid of processes, since this leads
        # to failures that are hard to diagnose.
        echo 2 > /proc/sys/vm/panic_on_oom

        # Coverage data is written into /tmp/coverage-data.
        mkdir -p /tmp/xchg/coverage-data

        # Mount debugfs to gain access to the kernel coverage data (if
        # available).
        mount -t debugfs none /sys/kernel/debug || true
      '';

    # If the kernel has been built with coverage instrumentation, make
    # it available under /proc/gcov.
    boot.kernelModules = [ "gcov-proc" ];

    # Panic if an error occurs in stage 1 (rather than waiting for
    # user intervention).
    boot.kernelParams =
      [ "console=tty1" "console=ttyS0" "panic=1" "stage1panic=1" ];

    # `xwininfo' is used by the test driver to query open windows.
    environment.systemPackages = [ pkgs.xorg.xwininfo ];

    # Log everything to the serial console.
    services.journald.console = "/dev/console";

    # Prevent tests from accessing the Internet.
    networking.defaultGateway = mkOverride 150 "";
    networking.nameservers = mkOverride 150 [ ];

    system.upstartEnvironment.GCOV_PREFIX = "/tmp/xchg/coverage-data";

    system.requiredKernelConfig = with config.lib.kernelConfig; [
      (isYes "SERIAL_8250_CONSOLE")
      (isYes "SERIAL_8250")
      (isEnabled "VIRTIO_CONSOLE")
    ];

  };

}
