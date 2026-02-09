
---

# zapret-toolkit

Linux Bash toolkit for managing and testing [zapret](https://github.com/bol-van/zapret) DPI bypass strategies.

Linux-only Bash scripts that simplify nftables rule management, kernel module loading, and automated testing of previously discovered working zapret strategies.
Tested on **openSUSE Leap 15.6**.
Expected to work on other **systemd-based Linux distributions** (e.g. Tumbleweed, Fedora), but not tested yet.

---

## Overview

This toolkit is designed for **manual (non-systemd) usage of zapret / nfqws** and for **automatic selection of a working DPI desync strategy** under current network conditions.

No services are installed.
Everything is started and stopped explicitly via scripts.

---

## Requirements

* Linux with `nfqueue` and `nftables` support
* Root privileges (`sudo`)
* Compiled `nfqws`
* `curl` installed

---

## Usage Workflow

### 1. Obtain candidate strategies

Run the original script provided by the zapret author:

```bash
./blockcheck.sh
```

This script outputs a list of potentially working DPI-desync strategies.

> Make sure `blockcheck.sh` and all related scripts are executable.

---

### 2. Prepare `strategies.txt`

Copy the strategies printed by `blockcheck.sh` into the file:

```
./zapret/strategies.txt
```

⚠ **Important — file format matters**

* Each strategy must start on a **new line**
* **Strategies must be separated by one empty line**
* No quotes, comments, or line continuations

Example:

```text
--dpi-desync=fake --dpi-desync-ttl=10 --orig-ttl=1

--dpi-desync=hostfakesplit --dpi-desync-fooling=ts --dpi-desync-hostfakesplit-mod=altorder=1

--dpi-desync=fakedsplit --dpi-desync-autottl=-1
```

---

### 3. Automatic strategy testing

Run the autotest script:

```bash
sudo ./zapret-autotest.sh
```

During execution, the script:

* loads required kernel modules (`nfnetlink_queue`, `nf_conntrack`)
* applies required `sysctl` parameters
* configures `nftables` rules for `NFQUEUE`
* starts `nfqws` with each strategy (one by one)
* checks connectivity to a test site (`rutracker.org`) using `curl`
* stops at the first working strategy

> DPI blocking behavior may change over time.
> Re-running the autotest allows you to verify that a strategy still works.

---

### 4. Working strategy output

Once a working strategy is found, it is automatically written to:

```
WORKING_STRATEGY.conf
```

No manual editing is required.

---

### 5. Start zapret using the working strategy

To start zapret in normal working mode:

```bash
sudo ./zapret-start.sh
```

This script:

* re-applies kernel modules and sysctl settings (safe to repeat)
* ensures required nftables rules exist
* launches `nfqws` using the strategy stored in `WORKING_STRATEGY.conf`

At this point, zapret is running with a verified working configuration.

---

## Notes

* All system changes performed by the scripts are **idempotent**
* No reboot is required
* No systemd services are created
* Strategy selection can always be repeated if blocking behavior changes

---
