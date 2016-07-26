# dnf-automatic-restart

[`dnf-automatic`](http://dnf.readthedocs.io/en/latest/automatic.html ) provides automatic updates for your Linux server. However, once updates are applied, you may need to restart services or even the machine (if the Linux kernel was updated) to actually run updated components.

## How it works

`dnf-automatic-restart` is a script to hook into the `dnf-automatic` update process. After `dnf-automatic` finishes `dnf-automatic-restart` is started and will:

* Compare the currently running kernel to the latest installed kernel and reboot the machine if a newer installed kernel is found,
* Check if [systemd](https://www.freedesktop.org/wiki/Software/systemd/) was updated and reboot the machine,
* Use [DNF tracer](http://dnf-plugins-extras.readthedocs.io/en/latest/tracer.html) to inspect what services need to be restarted and restart them.

## Installation

1. Clone this repository to a location of your choice. I'm using `/usr/local/src/dnf-automatic-restart`.

  ```sh
  cd /usr/local/src
  git clone https://github.com/agross/dnf-automatic-restart.git
  ln -s /usr/local/src/dnf-automatic-restart/dnf-automatic-restart /usr/local/sbin/dnf-automatic-restart
  ```

2. Install `dnf-automatic` and enable it.

  ```sh
  dnf install -y dnf-automatic
  # Edit /etc/dnf/automatic.conf.
  systemctl enable dnf-automatic.timer
  ```

3. Install [DNF tracer](http://dnf-plugins-extras.readthedocs.io/en/latest/tracer.html).

  ```sh
  dnf install -y dnf-plugins-extras-tracer
  ```

4. Add a systemd drop-in for `dnf-automatic.service`. The drop-in will enhance the `dnf-automatic.service` unit to run `dnf-automatic-restart` after `dnf-automatic` has finished.

  ```sh
  systemctl edit dnf-automatic.service
  ```

  Enter the following contents and save the file (systemd will put it in the correct place).

  ```
  [Service]
  # Path to the cloned script (see step 1 above).
  ExecStartPost=/usr/local/sbin/dnf-automatic-restart
  ```

## Monitoring

`dnf-automatic-restart` logs its actions and the output of `dnf tracer` to the system journal. You can use this command to inspect actions taken:

```sh
journalctl --unit dnf-automatic
```

You also may run `dnf-automatic-restart` manually. Log entries are then also printed to the terminal.
