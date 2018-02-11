# dnf-automatic-restart

[`dnf-automatic`](http://dnf.readthedocs.io/en/latest/automatic.html) provides
automatic updates for your Linux server. However, once updates are applied, you
may need to restart services or even the machine (if the Linux kernel was
updated) to actually run updated components.

## How it works

`dnf-automatic-restart` is a script to hook into the `dnf-automatic` update
process. After `dnf-automatic-install.service` finishes `dnf-automatic-restart`
is started and will:

* Compare the currently running kernel to the latest installed kernel and reboot
  the machine if a newer installed kernel is found,
* Check if [systemd](https://www.freedesktop.org/wiki/Software/systemd/) was
  updated and reboot system,
* Use [tracer](http://tracer-package.com/) to inspect what services need to be
  restarted and restart them.

## Installation

1. Clone this repository to a location of your choice. I'm using
   `/usr/local/src/dnf-automatic-restart`.

   ```sh
   cd /usr/local/src
   git clone https://github.com/agross/dnf-automatic-restart.git
   ln -s /usr/local/src/dnf-automatic-restart/dnf-automatic-restart /usr/local/sbin/dnf-automatic-restart
   ```

1. Install
   [DNF tracer plugin](http://dnf-plugins-extras.readthedocs.io/en/latest/tracer.html)
   which also installs [tracer](http://tracer-package.com/).

   ```sh
   dnf install -y dnf-plugins-extras-tracer
   ```

1. Install `dnf-automatic` and enable it.

   ```sh
   dnf install -y dnf-automatic
   # Edit /etc/dnf/automatic.conf.
   systemctl enable dnf-automatic-install.timer
   ```

1. Add a systemd drop-in for `dnf-automatic-install.service`. The drop-in will
   enhance the `dnf-automatic-install.service` unit to run
   `dnf-automatic-restart` after the update process has finished.

   ```sh
   systemctl edit dnf-automatic-install.service
   ```

   Enter the following contents and save the file (systemd will put it in the
   correct place).

   ```ini
   [Service]
   # Path to the cloned script (see step 1 above).
   ExecStartPost=/usr/local/sbin/dnf-automatic-restart
   ```

## Options

You might want to configure times when automatic restarts are allowed or
scheduled.

For example, if you run `dnf-automatic` on your router and that router is also
required for telephony (e.g. VoIP), you might want to delay reboots until the
chances that someone is currently on the phone while your internet connection is
offline are small.

`dnf-automatic-restart` supports the following options:

```text
-d        disable reboot
-h        display this help and exit
-n HOURS  no automatic reboot between hours (e.g. 8-22)
-r HOUR   schedule automatic reboot at hour (e.g. 0)
```

Use them as appropriate for your environment, for example:

```ini
[Service]
# Always schedule reboots at 00:00.
ExecStartPost=/usr/local/sbin/dnf-automatic-restart -r 0
```

```ini
[Service]
# No reboots between 08:00 and 22:00. You will need to reboot manually.
ExecStartPost=/usr/local/sbin/dnf-automatic-restart -n 8-22
```

```ini
[Service]
# No reboots between 08:00 and 22:00, schedule them for 00:00.
# If dnf-automatic runs at night (22:00-08:00), reboot immediately.
ExecStartPost=/usr/local/sbin/dnf-automatic-restart -n 8-22 -r 0
```

```ini
[Service]
# No automatic reboots, only services are restarted.
ExecStartPost=/usr/local/sbin/dnf-automatic-restart -d
```

## Monitoring

`dnf-automatic-restart` logs its actions and the output of `tracer` to the
system journal. You can use this command to inspect actions taken:

```sh
journalctl --unit dnf-automatic-install.service
```

You also may run `dnf-automatic-restart` manually. Log entries are then also
printed to the terminal.
