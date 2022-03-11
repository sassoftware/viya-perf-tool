# Viya Perf Tool

The Viya Perf Tool is a Bash script that measures network and/or storage I/O performance on SAS Viya 3.5 hosts running RHEL or CentOS 7.x. It runs independently using operating system commands and no SAS software is required.

The methods used are designed to mimic the basic behavior of SAS Viya 3.5. The results should provide a reasonable estimate of network and I/O throughput but may not reflect the actual performance of SAS applications.

## Prerequisites

- RHEL or CentOS 7.x
	- Support for RHEL/CentOS 8.x will be added in a future update.
- Bash version 4+
- Required commands (must be in $PATH):
	- Iperf version 2 (only required if running Network tests)
		- Note: Iperf 3 is not compatible with this script due to limitations with its single-threaded nature.
	- bc and /usr/bin/time (only required if running IO tests)
	- The majority of the remaining commands are included by default with these operating systems. The tool will check for and output any missing packages prior to running the tests.
- Passwordless SSH between all nodes (only required for MPP tests)

## Installation

Use Git to clone the contents of the Viya Perf Tool GitHub repo: https://github.com/sassoftware/viya-perf-tool.

## Getting Started

The Viya Perf Tool should be executed from the CAS Controller node. This should also be the first host defined in the host list (see [General Test Options](https://github.com/sassoftware/viya-perf-tool/blob/main/README.md#general-test-options)).

The tool can be run in either SMP (one host) or MPP (2+ hosts) environments. When running in a SMP environment, the defined host list is ignored, and all tests are run on localhost.

The config file (viya_perf_tool.conf) allows you enable or disable the following tests:

- \*Network tests
	- Sequential
	- Parallel
- Data directory IO tests
	- Non-shared (PATH) or \*shared (DNFS) directories
	- Sequential or \*parallel execution 
- CAS Disk Cache directory IO tests
	- Non-shared or \*shared directories
	- Sequential or \*parallel execution

\*Only valid for MPP tests

For more configuration options, see [Using the Config File](https://github.com/sassoftware/viya-perf-tool/blob/main/README.md#using-the-config-file).

## Usage

```bash
./viya_perf_tool.sh (parameter)
```
Optional parameters:
- `-y`:                 Auto accept config file values and immediately start running the tool
- `-h`, `--help`:       Show usage info
- `-v`, `--version`:    Show version info

If `-y` is not set, you will be prompted to confirm the options set in the config file when the program is run.

All additional options are read from the config file called "viya_perf_tool.conf".

Note: several pieces of information are collected about the given system(s). At a high-level, this information includes:
- Operating system, kernel and bash versions
- 'lscpu' output
- /proc/meminfo contents
- '/sbin/ifconfig -a' output
- If MPP test mode, info about the IP address and NIC being used (via '/sbin/ip addr show' and '/sbin/ethtool' output)

For a more thorough list of what's collected, see [Example Log File Output](https://github.com/sassoftware/viya-perf-tool/blob/main/README.md#example-log-file-output).

## Using the Config File

The config file (viya_perf_tool.conf) is included in the Git repository and contains several configuration options (some required, some optional) that can be set. A list of these options is below.

### General Test Options
- HOSTS
    - REQUIRED
    - Default Value: empty
    - The list of hostnames or IPs where the tests will be performed. These can be separated by commas, colons, semicolons, or spaces. For example: host1, host2, host3.
    - NOTE: The system this is being executed on should be the first host in the list.
    - NOTE: To test using a specific NIC, simply list that NIC's IP in place of the hostname.

### Network Test Options
- NETWORK_TESTS
    - REQUIRED
    - Default Value: Y
    - The valid values are "Y" to run the network throughput tests or "N" to not run the network tests.
    - NOTE: Network tests only performed if multiple hosts are being tested.
- NETWORK_LISTEN_PORT
    - REQUIRED if NETWORK_TESTS=Y
    - Default Value: 24975
    - The port to use for the iperf listener on the remote host(s) during the network tests.

### General Storage IO Test Options
- PARALLEL_IO_TESTS
    - REQUIRED if IO_TESTS_DATA=Y or IO_TESTS_CDC=Y
    - Default Value: N
    - The valid values are "Y" to the run Storage IO tests in parallel or "N" to run the Storage IO tests sequentially.
    - NOTE: Running the Storage IO tests sequentially *may* take significantly longer.

### Data IO Test Options
- IO_TESTS_DATA
    - REQUIRED
	- Default Value: Y
	- The valid values are "Y" to run the Data IO tests against the DATA_DIR directory or "N" to not run the Data IO tests.
- DATA_DIR
	- REQUIRED if IO_TESTS_DATA=Y
	- Default Value: empty
	- The full path of the permanent data directory. This path must exist and be read/write accessible for the user executing this script.
- SHARED_DATA_DIR
	- REQUIRED if IO_TESTS_DATA=Y, PARALLEL_IO_TESTS=Y, and more than one HOST is defined
	- Default Value: N
	- The valid values are "Y" if the directory specified in DATA_DIR is shared (DNFS) and tests should run in parallel or "N" if either the DATA_DIR directory is not shared (PATH) or tests should run sequentially.
	- NOTE: SHARED_DATA_DIR defaults to "N" if PARALLEL_IO_TESTS=N or if only one HOST is defined.

### CAS Disk Cache (CDC) Test Options
- IO_TESTS_CDC
	- REQUIRED
	- Default Value: Y
	- The valid values are "Y" to run the CDC IO tests against the CDC_DIR directory or "N" to not run the CDC IO tests.
- CDC_DIR
	- REQUIRED if IO_TESTS_CDC=Y
	- Default Value: empty
	- The full path of the CAS Disk Cache directory. This path must exist and be read/write accessible for the user executing this script.
- SHARED_CDC_DIR
	- REQUIRED if IO_TESTS_CDC=Y, PARALLEL_IO_TESTS=Y, and more than one HOST is defined
	- Default Value: N
	- The valid values are "Y" if the directory specified in CDC_DIR is shared and tests should run in parallel or "N" if either the CDC_DIR directory is not shared or tests should run sequentially.
	- NOTE: SHARED_CDC_DIR defaults to "N" if PARALLEL_IO_TESTS=N or if only one HOST is defined.

### Debug Test Options
- CLEANUP
	- REQUIRED
	- Default Value: Y
	- The valid values are "Y" to clean up after execution or "N" for leave test directories and temporary files on the systems.
- OUTPUT_TO_FILE
	- REQUIRED
	- Default Value: Y
	- The valid values are "Y" to write output to a log file [e.g. viya_perf_tool_1616433582.log] or "N" to write output to STDOUT.

## Contributing
We welcome your contributions! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to submit contributions to this project.

## License
This project is licensed under the [Apache 2.0 License](LICENSE).

## Example Log File Output
```bash
[node1][2021-07-27T19:01:19.574Z]: Using config file [/sasdata/viya-perf-tool/viya_perf_tool.conf]
[node1][2021-07-27T19:01:19.574Z]: Validating config file [/sasdata/viya-perf-tool/viya_perf_tool.conf]
[node1][2021-07-27T19:01:25.360Z]: [/sasdata/viya-perf-tool/viya_perf_tool.conf] validation successful
[node1][2021-07-27T19:01:25.361Z]: Hosts included in tests:               node1 node2
[node1][2021-07-27T19:01:25.362Z]: Perform Network Tests:                 y
[node1][2021-07-27T19:01:25.363Z]:   Listen port for Network Tests:       24975
[node1][2021-07-27T19:01:25.364Z]: Perform Data directory IO Tests:       y
[node1][2021-07-27T19:01:25.364Z]:   Data directory path:                 /datashare
[node1][2021-07-27T19:01:25.365Z]:   Data directory is shared (DNFS):     y
[node1][2021-07-27T19:01:25.366Z]: Perform CAS Disk Cache IO Tests:       y
[node1][2021-07-27T19:01:25.367Z]:   CAS Disk Cache path:                 /saswork
[node1][2021-07-27T19:01:25.368Z]:   CAS Disk Cache directory is shared:  n
[node1][2021-07-27T19:01:25.368Z]: Run IO Tests in parallel:              y
[node1][2021-07-27T19:01:25.369Z]: Clean up after tests:                  y
[node1][2021-07-27T19:01:25.370Z]: Output To log:                         y
[node1][2021-07-27T19:01:25.371Z]: ----------
[node1][2021-07-27T19:01:25.372Z]: Script Name:    viya_perf_tool.sh
[node1][2021-07-27T19:01:25.372Z]: Script Version: 4.0.1
[node1][2021-07-27T19:01:25.373Z]: Script Build:   20220201401
[node1][2021-07-27T19:01:25.374Z]: Config Version: 1.0.0
[node1][2021-07-27T19:01:25.375Z]: Copyright (c) 2020 SAS Institute Inc.
[node1][2021-07-27T19:01:25.376Z]: Unpublished - All Rights Reserved.
[node1][2021-07-27T19:01:25.377Z]: -----------------------------
[node1][2021-07-27T19:01:25.378Z]: Running in MPP mode
[node1][2021-07-27T19:01:25.378Z]: -----------------------------
[node1][2021-07-27T19:01:25.381Z]: Running as user: [sasdemo]
[node1][2021-07-27T19:01:25.382Z]: Number of hosts: 2
[node1][2021-07-27T19:01:25.383Z]: Host list: [node1 node2]
[node1][2021-07-27T19:01:25.383Z]: Validating host list and passwordless SSH for user [sasdemo] on all hosts
[node1][2021-07-27T19:01:25.694Z]: Host list and passwordless SSH validation completed successfully!
[node1][2021-07-27T19:01:25.697Z]: Short hostnames: [node1: node1] [node2: node2]
[node1][2021-07-27T19:01:25.698Z]: Checking for bash shell v4+ on all hosts
[node1][2021-07-27T19:01:25.982Z]: Bash shell check completed successfully!
[node1][2021-07-27T19:01:25.983Z]: Temporary working directory: [/tmp/viya_perf_tool_1627412479_tmpdir]
[node1][2021-07-27T19:01:25.984Z]: Creating temporary working directory [/tmp/viya_perf_tool_1627412479_tmpdir] on [node1]
[node1][2021-07-27T19:01:25.986Z]: Checking required commands on all hosts
[node1][2021-07-27T19:01:26.866Z]: Creating temporary working directory [/tmp/viya_perf_tool_1627412479_tmpdir] on remote hosts
[node1][2021-07-27T19:01:27.152Z]: -----------------------------
[node1][2021-07-27T19:01:27.153Z]: Begin system information output
[node1][2021-07-27T19:01:27.154Z]: -----------------------------
[node1][2021-07-27T19:01:27.311Z]: -------------------------
[node1][2021-07-27T19:01:27.311Z]: Begin system information for [node1]
[node1][2021-07-27T19:01:27.311Z]: -------------------------
[node1][2021-07-27T19:01:27.311Z]: Bash version: 4.2.46(2)-release
[node1][2021-07-27T19:01:27.311Z]: RHEL version: Red Hat Enterprise Linux Server release 7.6 (Maipo)
[node1][2021-07-27T19:01:27.311Z]: Uname -a: Linux node1.perf.sas.com 3.10.0-957.el7.x86_64 #1 SMP Thu Oct 4 20:48:51 UTC 2018 x86_64 x86_64 x86_64 GNU/Linux
[node1][2021-07-27T19:01:27.311Z]: ---------------------
[node1][2021-07-27T19:01:27.311Z]: Begin 'lscpu' output
[node1][2021-07-27T19:01:27.311Z]: ---------------------
[node1][2021-07-27T19:01:27.311Z]: Architecture:          x86_64
[node1][2021-07-27T19:01:27.311Z]: CPU op-mode(s):        32-bit, 64-bit
[node1][2021-07-27T19:01:27.311Z]: Byte Order:            Little Endian
[node1][2021-07-27T19:01:27.311Z]: CPU(s):                16
[node1][2021-07-27T19:01:27.311Z]: On-line CPU(s) list:   0-15
[node1][2021-07-27T19:01:27.311Z]: Thread(s) per core:    1
[node1][2021-07-27T19:01:27.311Z]: Core(s) per socket:    1
[node1][2021-07-27T19:01:27.311Z]: Socket(s):             16
[node1][2021-07-27T19:01:27.311Z]: NUMA node(s):          2
[node1][2021-07-27T19:01:27.311Z]: Vendor ID:             GenuineIntel
[node1][2021-07-27T19:01:27.311Z]: CPU family:            6
[node1][2021-07-27T19:01:27.311Z]: Model:                 85
[node1][2021-07-27T19:01:27.311Z]: Model name:            Intel(R) Xeon(R) Gold 6254 CPU @ 3.10GHz
[node1][2021-07-27T19:01:27.311Z]: Stepping:              7
[node1][2021-07-27T19:01:27.311Z]: CPU MHz:               3092.734
[node1][2021-07-27T19:01:27.311Z]: BogoMIPS:              6185.46
[node1][2021-07-27T19:01:27.311Z]: Hypervisor vendor:     VMware
[node1][2021-07-27T19:01:27.311Z]: Virtualization type:   full
[node1][2021-07-27T19:01:27.311Z]: L1d cache:             32K
[node1][2021-07-27T19:01:27.311Z]: L1i cache:             32K
[node1][2021-07-27T19:01:27.311Z]: L2 cache:              1024K
[node1][2021-07-27T19:01:27.311Z]: L3 cache:              25344K
[node1][2021-07-27T19:01:27.311Z]: NUMA node0 CPU(s):     0-7
[node1][2021-07-27T19:01:27.311Z]: NUMA node1 CPU(s):     8-15
[node1][2021-07-27T19:01:27.311Z]: Flags:                 fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush mmx fxsr sse sse2 ss syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon nopl xtopology tsc_reliable nonstop_tsc eagerfpu pni pclmulqdq ssse3 fma cx16 pcid sse4_1 sse4_2 x2apic movbe popcnt tsc_deadline_timer aes xsave avx f16c rdrand hypervisor lahf_lm abm 3dnowprefetch ssbd ibrs ibpb stibp ibrs_enhanced fsgsbase tsc_adjust bmi1 avx2 smep bmi2 invpcid avx512f avx512dq rdseed adx smap clflushopt clwb avx512cd avx512bw avx512vl xsaveopt xsavec arat pku ospke spec_ctrl intel_stibp flush_l1d arch_capabilities
[node1][2021-07-27T19:01:27.311Z]: ---------------------
[node1][2021-07-27T19:01:27.311Z]: End 'lscpu' output
[node1][2021-07-27T19:01:27.311Z]: ---------------------
[node1][2021-07-27T19:01:27.311Z]: ---------------------
[node1][2021-07-27T19:01:27.311Z]: Begin 'cat /proc/meminfo' output
[node1][2021-07-27T19:01:27.311Z]: ---------------------
[node1][2021-07-27T19:01:27.311Z]: MemTotal:       98834848 kB
[node1][2021-07-27T19:01:27.311Z]: MemFree:        95786740 kB
[node1][2021-07-27T19:01:27.311Z]: MemAvailable:   96891652 kB
[node1][2021-07-27T19:01:27.311Z]: Buffers:               0 kB
[node1][2021-07-27T19:01:27.311Z]: Cached:          1829724 kB
[node1][2021-07-27T19:01:27.311Z]: SwapCached:            0 kB
[node1][2021-07-27T19:01:27.311Z]: Active:          1609712 kB
[node1][2021-07-27T19:01:27.311Z]: Inactive:         333224 kB
[node1][2021-07-27T19:01:27.311Z]: Active(anon):     351912 kB
[node1][2021-07-27T19:01:27.311Z]: Inactive(anon):   139780 kB
[node1][2021-07-27T19:01:27.311Z]: Active(file):    1257800 kB
[node1][2021-07-27T19:01:27.311Z]: Inactive(file):   193444 kB
[node1][2021-07-27T19:01:27.311Z]: Unevictable:           0 kB
[node1][2021-07-27T19:01:27.311Z]: Mlocked:               0 kB
[node1][2021-07-27T19:01:27.311Z]: SwapTotal:             0 kB
[node1][2021-07-27T19:01:27.311Z]: SwapFree:              0 kB
[node1][2021-07-27T19:01:27.311Z]: Dirty:                16 kB
[node1][2021-07-27T19:01:27.311Z]: Writeback:             0 kB
[node1][2021-07-27T19:01:27.311Z]: AnonPages:        112564 kB
[node1][2021-07-27T19:01:27.311Z]: Mapped:            37700 kB
[node1][2021-07-27T19:01:27.311Z]: Shmem:            378480 kB
[node1][2021-07-27T19:01:27.311Z]: Slab:             279708 kB
[node1][2021-07-27T19:01:27.311Z]: SReclaimable:     196984 kB
[node1][2021-07-27T19:01:27.311Z]: SUnreclaim:        82724 kB
[node1][2021-07-27T19:01:27.311Z]: KernelStack:        5632 kB
[node1][2021-07-27T19:01:27.311Z]: PageTables:        17372 kB
[node1][2021-07-27T19:01:27.311Z]: NFS_Unstable:          0 kB
[node1][2021-07-27T19:01:27.311Z]: Bounce:                0 kB
[node1][2021-07-27T19:01:27.311Z]: WritebackTmp:          0 kB
[node1][2021-07-27T19:01:27.311Z]: CommitLimit:    49417424 kB
[node1][2021-07-27T19:01:27.311Z]: Committed_AS:     760316 kB
[node1][2021-07-27T19:01:27.311Z]: VmallocTotal:   34359738367 kB
[node1][2021-07-27T19:01:27.311Z]: VmallocUsed:      361924 kB
[node1][2021-07-27T19:01:27.311Z]: VmallocChunk:   34308222972 kB
[node1][2021-07-27T19:01:27.311Z]: HardwareCorrupted:     0 kB
[node1][2021-07-27T19:01:27.311Z]: AnonHugePages:     24576 kB
[node1][2021-07-27T19:01:27.311Z]: CmaTotal:              0 kB
[node1][2021-07-27T19:01:27.311Z]: CmaFree:               0 kB
[node1][2021-07-27T19:01:27.311Z]: HugePages_Total:       0
[node1][2021-07-27T19:01:27.311Z]: HugePages_Free:        0
[node1][2021-07-27T19:01:27.311Z]: HugePages_Rsvd:        0
[node1][2021-07-27T19:01:27.311Z]: HugePages_Surp:        0
[node1][2021-07-27T19:01:27.311Z]: Hugepagesize:       2048 kB
[node1][2021-07-27T19:01:27.311Z]: DirectMap4k:      204672 kB
[node1][2021-07-27T19:01:27.311Z]: DirectMap2M:     5038080 kB
[node1][2021-07-27T19:01:27.311Z]: DirectMap1G:    97517568 kB
[node1][2021-07-27T19:01:27.311Z]: ---------------------
[node1][2021-07-27T19:01:27.311Z]: End 'cat /proc/meminfo' output
[node1][2021-07-27T19:01:27.311Z]: ---------------------
[node1][2021-07-27T19:01:27.311Z]: ---------------------
[node1][2021-07-27T19:01:27.311Z]: Begin '/sbin/ip addr show' output
[node1][2021-07-27T19:01:27.311Z]: ---------------------
[node1][2021-07-27T19:01:27.311Z]: 1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
[node1][2021-07-27T19:01:27.311Z]:     link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
[node1][2021-07-27T19:01:27.311Z]:     inet 127.0.0.1/8 scope host lo
[node1][2021-07-27T19:01:27.311Z]:        valid_lft forever preferred_lft forever
[node1][2021-07-27T19:01:27.311Z]:     inet6 ::1/128 scope host 
[node1][2021-07-27T19:01:27.311Z]:        valid_lft forever preferred_lft forever
[node1][2021-07-27T19:01:27.311Z]: 2: ens192: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
[node1][2021-07-27T19:01:27.311Z]:     link/ether 00:50:56:bc:ba:a2 brd ff:ff:ff:ff:ff:ff
[node1][2021-07-27T19:01:27.311Z]:     inet 10.122.33.173/22 brd 10.122.35.255 scope global ens192
[node1][2021-07-27T19:01:27.311Z]:        valid_lft forever preferred_lft forever
[node1][2021-07-27T19:01:27.311Z]:     inet6 fe80::250:56ff:febc:baa2/64 scope link 
[node1][2021-07-27T19:01:27.311Z]:        valid_lft forever preferred_lft forever
[node1][2021-07-27T19:01:27.311Z]: 3: ens224: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
[node1][2021-07-27T19:01:27.311Z]:     link/ether 00:50:56:bc:c4:ba brd ff:ff:ff:ff:ff:ff
[node1][2021-07-27T19:01:27.311Z]:     inet 192.168.240.179/24 brd 192.168.240.255 scope global ens224
[node1][2021-07-27T19:01:27.311Z]:        valid_lft forever preferred_lft forever
[node1][2021-07-27T19:01:27.311Z]:     inet6 fe80::250:56ff:febc:c4ba/64 scope link 
[node1][2021-07-27T19:01:27.311Z]:        valid_lft forever preferred_lft forever
[node1][2021-07-27T19:01:27.311Z]: ---------------------
[node1][2021-07-27T19:01:27.311Z]: End '/sbin/ip addr show' output
[node1][2021-07-27T19:01:27.311Z]: ---------------------
[node1][2021-07-27T19:01:27.311Z]: Current IP: 10.122.33.173
[node1][2021-07-27T19:01:27.311Z]: Current interface: ens192
[node1][2021-07-27T19:01:27.311Z]: ---------------------
[node1][2021-07-27T19:01:27.311Z]: Begin /sbin/ethtool NIC info
[node1][2021-07-27T19:01:27.311Z]: ---------------------
[node1][2021-07-27T19:01:27.311Z]: Settings for ens192:
[node1][2021-07-27T19:01:27.311Z]: 	Supported ports: [ TP ]
[node1][2021-07-27T19:01:27.311Z]: 	Supported link modes:   1000baseT/Full 
[node1][2021-07-27T19:01:27.311Z]: 	                        10000baseT/Full 
[node1][2021-07-27T19:01:27.311Z]: 	Supported pause frame use: No
[node1][2021-07-27T19:01:27.311Z]: 	Supports auto-negotiation: No
[node1][2021-07-27T19:01:27.311Z]: 	Supported FEC modes: Not reported
[node1][2021-07-27T19:01:27.311Z]: 	Advertised link modes:  Not reported
[node1][2021-07-27T19:01:27.311Z]: 	Advertised pause frame use: No
[node1][2021-07-27T19:01:27.311Z]: 	Advertised auto-negotiation: No
[node1][2021-07-27T19:01:27.311Z]: 	Advertised FEC modes: Not reported
[node1][2021-07-27T19:01:27.311Z]: 	Speed: 10000Mb/s
[node1][2021-07-27T19:01:27.311Z]: 	Duplex: Full
[node1][2021-07-27T19:01:27.311Z]: 	Port: Twisted Pair
[node1][2021-07-27T19:01:27.311Z]: 	PHYAD: 0
[node1][2021-07-27T19:01:27.311Z]: 	Transceiver: internal
[node1][2021-07-27T19:01:27.311Z]: 	Auto-negotiation: off
[node1][2021-07-27T19:01:27.311Z]: 	MDI-X: Unknown
[node1][2021-07-27T19:01:27.311Z]: 	Link detected: yes
[node1][2021-07-27T19:01:27.311Z]: ---------------------
[node1][2021-07-27T19:01:27.311Z]: End /sbin/ethtool NIC info
[node1][2021-07-27T19:01:27.311Z]: ---------------------
[node1][2021-07-27T19:01:27.311Z]: -------------------------
[node1][2021-07-27T19:01:27.311Z]: End system information for [node1]
[node1][2021-07-27T19:01:27.311Z]: -------------------------
[node2][2021-07-27T19:01:27.677Z]: -------------------------
[node2][2021-07-27T19:01:27.677Z]: Begin system information for [node2]
[node2][2021-07-27T19:01:27.677Z]: -------------------------
[node2][2021-07-27T19:01:27.677Z]: Bash version: 4.2.46(2)-release
[node2][2021-07-27T19:01:27.677Z]: RHEL version: Red Hat Enterprise Linux Server release 7.6 (Maipo)
[node2][2021-07-27T19:01:27.677Z]: Uname -a: Linux node2.perf.sas.com 3.10.0-957.el7.x86_64 #1 SMP Thu Oct 4 20:48:51 UTC 2018 x86_64 x86_64 x86_64 GNU/Linux
[node2][2021-07-27T19:01:27.677Z]: ---------------------
[node2][2021-07-27T19:01:27.677Z]: Begin 'lscpu' output
[node2][2021-07-27T19:01:27.677Z]: ---------------------
[node2][2021-07-27T19:01:27.677Z]: Architecture:          x86_64
[node2][2021-07-27T19:01:27.677Z]: CPU op-mode(s):        32-bit, 64-bit
[node2][2021-07-27T19:01:27.677Z]: Byte Order:            Little Endian
[node2][2021-07-27T19:01:27.677Z]: CPU(s):                16
[node2][2021-07-27T19:01:27.677Z]: On-line CPU(s) list:   0-15
[node2][2021-07-27T19:01:27.677Z]: Thread(s) per core:    1
[node2][2021-07-27T19:01:27.677Z]: Core(s) per socket:    1
[node2][2021-07-27T19:01:27.677Z]: Socket(s):             16
[node2][2021-07-27T19:01:27.677Z]: NUMA node(s):          2
[node2][2021-07-27T19:01:27.677Z]: Vendor ID:             GenuineIntel
[node2][2021-07-27T19:01:27.677Z]: CPU family:            6
[node2][2021-07-27T19:01:27.677Z]: Model:                 85
[node2][2021-07-27T19:01:27.677Z]: Model name:            Intel(R) Xeon(R) Gold 6254 CPU @ 3.10GHz
[node2][2021-07-27T19:01:27.677Z]: Stepping:              7
[node2][2021-07-27T19:01:27.677Z]: CPU MHz:               3092.734
[node2][2021-07-27T19:01:27.677Z]: BogoMIPS:              6185.46
[node2][2021-07-27T19:01:27.677Z]: Hypervisor vendor:     VMware
[node2][2021-07-27T19:01:27.677Z]: Virtualization type:   full
[node2][2021-07-27T19:01:27.677Z]: L1d cache:             32K
[node2][2021-07-27T19:01:27.677Z]: L1i cache:             32K
[node2][2021-07-27T19:01:27.677Z]: L2 cache:              1024K
[node2][2021-07-27T19:01:27.677Z]: L3 cache:              25344K
[node2][2021-07-27T19:01:27.677Z]: NUMA node0 CPU(s):     0-7
[node2][2021-07-27T19:01:27.677Z]: NUMA node1 CPU(s):     8-15
[node2][2021-07-27T19:01:27.677Z]: Flags:                 fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush mmx fxsr sse sse2 ss syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon nopl xtopology tsc_reliable nonstop_tsc eagerfpu pni pclmulqdq ssse3 fma cx16 pcid sse4_1 sse4_2 x2apic movbe popcnt tsc_deadline_timer aes xsave avx f16c rdrand hypervisor lahf_lm abm 3dnowprefetch ssbd ibrs ibpb stibp ibrs_enhanced fsgsbase tsc_adjust bmi1 avx2 smep bmi2 invpcid avx512f avx512dq rdseed adx smap clflushopt clwb avx512cd avx512bw avx512vl xsaveopt xsavec arat pku ospke spec_ctrl intel_stibp flush_l1d arch_capabilities
[node2][2021-07-27T19:01:27.677Z]: ---------------------
[node2][2021-07-27T19:01:27.677Z]: End 'lscpu' output
[node2][2021-07-27T19:01:27.677Z]: ---------------------
[node2][2021-07-27T19:01:27.677Z]: ---------------------
[node2][2021-07-27T19:01:27.677Z]: Begin 'cat /proc/meminfo' output
[node2][2021-07-27T19:01:27.677Z]: ---------------------
[node2][2021-07-27T19:01:27.677Z]: MemTotal:       98834848 kB
[node2][2021-07-27T19:01:27.677Z]: MemFree:        56647912 kB
[node2][2021-07-27T19:01:27.677Z]: MemAvailable:   96974836 kB
[node2][2021-07-27T19:01:27.677Z]: Buffers:               0 kB
[node2][2021-07-27T19:01:27.677Z]: Cached:         40571700 kB
[node2][2021-07-27T19:01:27.677Z]: SwapCached:            0 kB
[node2][2021-07-27T19:01:27.677Z]: Active:         40485560 kB
[node2][2021-07-27T19:01:27.677Z]: Inactive:         163104 kB
[node2][2021-07-27T19:01:27.677Z]: Active(anon):     314840 kB
[node2][2021-07-27T19:01:27.677Z]: Inactive(anon):   139876 kB
[node2][2021-07-27T19:01:27.677Z]: Active(file):   40170720 kB
[node2][2021-07-27T19:01:27.677Z]: Inactive(file):    23228 kB
[node2][2021-07-27T19:01:27.677Z]: Unevictable:           0 kB
[node2][2021-07-27T19:01:27.677Z]: Mlocked:               0 kB
[node2][2021-07-27T19:01:27.677Z]: SwapTotal:             0 kB
[node2][2021-07-27T19:01:27.677Z]: SwapFree:              0 kB
[node2][2021-07-27T19:01:27.677Z]: Dirty:               116 kB
[node2][2021-07-27T19:01:27.677Z]: Writeback:             0 kB
[node2][2021-07-27T19:01:27.677Z]: AnonPages:         78240 kB
[node2][2021-07-27T19:01:27.677Z]: Mapped:            37556 kB
[node2][2021-07-27T19:01:27.677Z]: Shmem:            377752 kB
[node2][2021-07-27T19:01:27.677Z]: Slab:             768676 kB
[node2][2021-07-27T19:01:27.677Z]: SReclaimable:     690508 kB
[node2][2021-07-27T19:01:27.677Z]: SUnreclaim:        78168 kB
[node2][2021-07-27T19:01:27.677Z]: KernelStack:        5152 kB
[node2][2021-07-27T19:01:27.677Z]: PageTables:         8272 kB
[node2][2021-07-27T19:01:27.677Z]: NFS_Unstable:          0 kB
[node2][2021-07-27T19:01:27.677Z]: Bounce:                0 kB
[node2][2021-07-27T19:01:27.677Z]: WritebackTmp:          0 kB
[node2][2021-07-27T19:01:27.677Z]: CommitLimit:    49417424 kB
[node2][2021-07-27T19:01:27.677Z]: Committed_AS:     694400 kB
[node2][2021-07-27T19:01:27.677Z]: VmallocTotal:   34359738367 kB
[node2][2021-07-27T19:01:27.677Z]: VmallocUsed:      360748 kB
[node2][2021-07-27T19:01:27.677Z]: VmallocChunk:   34308222972 kB
[node2][2021-07-27T19:01:27.677Z]: HardwareCorrupted:     0 kB
[node2][2021-07-27T19:01:27.677Z]: AnonHugePages:     20480 kB
[node2][2021-07-27T19:01:27.677Z]: CmaTotal:              0 kB
[node2][2021-07-27T19:01:27.677Z]: CmaFree:               0 kB
[node2][2021-07-27T19:01:27.677Z]: HugePages_Total:       0
[node2][2021-07-27T19:01:27.677Z]: HugePages_Free:        0
[node2][2021-07-27T19:01:27.677Z]: HugePages_Rsvd:        0
[node2][2021-07-27T19:01:27.677Z]: HugePages_Surp:        0
[node2][2021-07-27T19:01:27.677Z]: Hugepagesize:       2048 kB
[node2][2021-07-27T19:01:27.677Z]: DirectMap4k:      194432 kB
[node2][2021-07-27T19:01:27.677Z]: DirectMap2M:     8194048 kB
[node2][2021-07-27T19:01:27.677Z]: DirectMap1G:    94371840 kB
[node2][2021-07-27T19:01:27.677Z]: ---------------------
[node2][2021-07-27T19:01:27.677Z]: End 'cat /proc/meminfo' output
[node2][2021-07-27T19:01:27.677Z]: ---------------------
[node2][2021-07-27T19:01:27.677Z]: ---------------------
[node2][2021-07-27T19:01:27.677Z]: Begin '/sbin/ip addr show' output
[node2][2021-07-27T19:01:27.677Z]: ---------------------
[node2][2021-07-27T19:01:27.677Z]: 1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
[node2][2021-07-27T19:01:27.677Z]:     link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
[node2][2021-07-27T19:01:27.677Z]:     inet 127.0.0.1/8 scope host lo
[node2][2021-07-27T19:01:27.677Z]:        valid_lft forever preferred_lft forever
[node2][2021-07-27T19:01:27.677Z]:     inet6 ::1/128 scope host 
[node2][2021-07-27T19:01:27.677Z]:        valid_lft forever preferred_lft forever
[node2][2021-07-27T19:01:27.677Z]: 2: ens192: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
[node2][2021-07-27T19:01:27.677Z]:     link/ether 00:50:56:bc:bf:d0 brd ff:ff:ff:ff:ff:ff
[node2][2021-07-27T19:01:27.677Z]:     inet 10.122.33.174/22 brd 10.122.35.255 scope global ens192
[node2][2021-07-27T19:01:27.677Z]:        valid_lft forever preferred_lft forever
[node2][2021-07-27T19:01:27.677Z]:     inet6 fe80::250:56ff:febc:bfd0/64 scope link 
[node2][2021-07-27T19:01:27.677Z]:        valid_lft forever preferred_lft forever
[node2][2021-07-27T19:01:27.677Z]: 3: ens224: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
[node2][2021-07-27T19:01:27.677Z]:     link/ether 00:50:56:bc:54:dc brd ff:ff:ff:ff:ff:ff
[node2][2021-07-27T19:01:27.677Z]:     inet 192.168.240.177/24 brd 192.168.240.255 scope global ens224
[node2][2021-07-27T19:01:27.677Z]:        valid_lft forever preferred_lft forever
[node2][2021-07-27T19:01:27.677Z]:     inet6 fe80::250:56ff:febc:54dc/64 scope link 
[node2][2021-07-27T19:01:27.677Z]:        valid_lft forever preferred_lft forever
[node2][2021-07-27T19:01:27.677Z]: ---------------------
[node2][2021-07-27T19:01:27.677Z]: End '/sbin/ip addr show' output
[node2][2021-07-27T19:01:27.677Z]: ---------------------
[node2][2021-07-27T19:01:27.677Z]: Current IP: 10.122.33.174
[node2][2021-07-27T19:01:27.677Z]: Current interface: ens192
[node2][2021-07-27T19:01:27.677Z]: ---------------------
[node2][2021-07-27T19:01:27.677Z]: Begin /sbin/ethtool NIC info
[node2][2021-07-27T19:01:27.677Z]: ---------------------
[node2][2021-07-27T19:01:27.677Z]: Settings for ens192:
[node2][2021-07-27T19:01:27.677Z]: 	Supported ports: [ TP ]
[node2][2021-07-27T19:01:27.677Z]: 	Supported link modes:   1000baseT/Full 
[node2][2021-07-27T19:01:27.677Z]: 	                        10000baseT/Full 
[node2][2021-07-27T19:01:27.677Z]: 	Supported pause frame use: No
[node2][2021-07-27T19:01:27.677Z]: 	Supports auto-negotiation: No
[node2][2021-07-27T19:01:27.677Z]: 	Supported FEC modes: Not reported
[node2][2021-07-27T19:01:27.677Z]: 	Advertised link modes:  Not reported
[node2][2021-07-27T19:01:27.677Z]: 	Advertised pause frame use: No
[node2][2021-07-27T19:01:27.677Z]: 	Advertised auto-negotiation: No
[node2][2021-07-27T19:01:27.677Z]: 	Advertised FEC modes: Not reported
[node2][2021-07-27T19:01:27.677Z]: 	Speed: 10000Mb/s
[node2][2021-07-27T19:01:27.677Z]: 	Duplex: Full
[node2][2021-07-27T19:01:27.677Z]: 	Port: Twisted Pair
[node2][2021-07-27T19:01:27.677Z]: 	PHYAD: 0
[node2][2021-07-27T19:01:27.677Z]: 	Transceiver: internal
[node2][2021-07-27T19:01:27.677Z]: 	Auto-negotiation: off
[node2][2021-07-27T19:01:27.677Z]: 	MDI-X: Unknown
[node2][2021-07-27T19:01:27.677Z]: 	Link detected: yes
[node2][2021-07-27T19:01:27.677Z]: ---------------------
[node2][2021-07-27T19:01:27.677Z]: End /sbin/ethtool NIC info
[node2][2021-07-27T19:01:27.677Z]: ---------------------
[node2][2021-07-27T19:01:27.677Z]: -------------------------
[node2][2021-07-27T19:01:27.677Z]: End system information for [node2]
[node2][2021-07-27T19:01:27.677Z]: -------------------------
[node1][2021-07-27T19:01:27.883Z]: -----------------------------
[node1][2021-07-27T19:01:27.884Z]: End system information output
[node1][2021-07-27T19:01:27.885Z]: -----------------------------
[node1][2021-07-27T19:01:27.886Z]: -----------------------------
[node1][2021-07-27T19:01:27.886Z]: Begin Network Tests
[node1][2021-07-27T19:01:27.887Z]: -----------------------------
[node1][2021-07-27T19:01:27.888Z]: NOTE - Network tests are only run against remote hosts and will not be run against [node1].
[node1][2021-07-27T19:01:27.889Z]: ---------------------------
[node1][2021-07-27T19:01:27.890Z]: Begin Sequential Network Tests
[node1][2021-07-27T19:01:27.890Z]: ---------------------------
[node1][2021-07-27T19:01:27.891Z]: -------------------------
[node1][2021-07-27T19:01:27.892Z]: Begin Sequential Network Test for [node2]
[node1][2021-07-27T19:01:27.893Z]: -------------------------
[node1][2021-07-27T19:01:27.894Z]: Starting iperf listener on [node2]
[node1][2021-07-27T19:01:28.896Z]: Starting iperf sender on [node1] connecting to [node2]
[node1][2021-07-27T19:01:33.037Z]: Listener pid: 3096
[node1][2021-07-27T19:01:33.037Z]: Listener return code: 0
[node1][2021-07-27T19:01:33.037Z]: Sender return code: 0
[node1][2021-07-27T19:01:33.037Z]: ------------------------------------------------------------
[node1][2021-07-27T19:01:33.037Z]: Client connecting to node2, TCP port 24975
[node1][2021-07-27T19:01:33.037Z]: TCP window size: 0.00 GByte (default)
[node1][2021-07-27T19:01:33.037Z]: ------------------------------------------------------------
[node1][2021-07-27T19:01:33.037Z]: [ 11] local 10.122.33.173 port 37510 connected with 10.122.33.174 port 24975
[node1][2021-07-27T19:01:33.037Z]: [  3] local 10.122.33.173 port 37496 connected with 10.122.33.174 port 24975
[node1][2021-07-27T19:01:33.037Z]: [  5] local 10.122.33.173 port 37498 connected with 10.122.33.174 port 24975
[node1][2021-07-27T19:01:33.037Z]: [  6] local 10.122.33.173 port 37502 connected with 10.122.33.174 port 24975
[node1][2021-07-27T19:01:33.037Z]: [  4] local 10.122.33.173 port 37500 connected with 10.122.33.174 port 24975
[node1][2021-07-27T19:01:33.037Z]: [  8] local 10.122.33.173 port 37506 connected with 10.122.33.174 port 24975
[node1][2021-07-27T19:01:33.037Z]: [  7] local 10.122.33.173 port 37504 connected with 10.122.33.174 port 24975
[node1][2021-07-27T19:01:33.037Z]: [ 10] local 10.122.33.173 port 37508 connected with 10.122.33.174 port 24975
[node1][2021-07-27T19:01:33.037Z]: [ 12] local 10.122.33.173 port 37514 connected with 10.122.33.174 port 24975
[node1][2021-07-27T19:01:33.037Z]: [  9] local 10.122.33.173 port 37512 connected with 10.122.33.174 port 24975
[node1][2021-07-27T19:01:33.037Z]: [ ID] Interval       Transfer     Bandwidth
[node1][2021-07-27T19:01:33.037Z]: [  3]  0.0- 2.0 sec  0.51 GBytes  2.18 Gbits/sec
[node1][2021-07-27T19:01:33.037Z]: [  3]  0.0- 2.0 sec  0.51 GBytes  2.17 Gbits/sec
[node1][2021-07-27T19:01:33.037Z]: [  5]  0.0- 2.0 sec  0.46 GBytes  1.99 Gbits/sec
[node1][2021-07-27T19:01:33.037Z]: [  5]  0.0- 2.0 sec  0.46 GBytes  1.99 Gbits/sec
[node1][2021-07-27T19:01:33.037Z]: [  4]  0.0- 2.0 sec  0.49 GBytes  2.11 Gbits/sec
[node1][2021-07-27T19:01:33.037Z]: [  4]  0.0- 2.0 sec  0.49 GBytes  2.10 Gbits/sec
[node1][2021-07-27T19:01:33.037Z]: [  8]  0.0- 2.0 sec  0.19 GBytes  0.81 Gbits/sec
[node1][2021-07-27T19:01:33.037Z]: [  8]  0.0- 2.0 sec  0.19 GBytes  0.81 Gbits/sec
[node1][2021-07-27T19:01:33.037Z]: [  7]  0.0- 2.0 sec  0.42 GBytes  1.79 Gbits/sec
[node1][2021-07-27T19:01:33.037Z]: [  7]  0.0- 2.0 sec  0.42 GBytes  1.79 Gbits/sec
[node1][2021-07-27T19:01:33.037Z]: [SUM]  0.0- 2.0 sec  4.14 GBytes  17.7 Gbits/sec
[node1][2021-07-27T19:01:33.037Z]: [ 10]  0.0- 2.0 sec  0.27 GBytes  1.17 Gbits/sec
[node1][2021-07-27T19:01:33.037Z]: [ 10]  0.0- 2.0 sec  0.27 GBytes  1.18 Gbits/sec
[node1][2021-07-27T19:01:33.037Z]: [ 12]  0.0- 2.0 sec  0.38 GBytes  1.64 Gbits/sec
[node1][2021-07-27T19:01:33.037Z]: [ 12]  0.0- 2.0 sec  0.38 GBytes  1.64 Gbits/sec
[node1][2021-07-27T19:01:33.037Z]: [  9]  0.0- 2.0 sec  0.31 GBytes  1.34 Gbits/sec
[node1][2021-07-27T19:01:33.037Z]: [  9]  0.0- 2.0 sec  0.31 GBytes  1.34 Gbits/sec
[node1][2021-07-27T19:01:33.037Z]: [ 11]  0.0- 2.0 sec  0.27 GBytes  1.16 Gbits/sec
[node1][2021-07-27T19:01:33.037Z]: [ 11]  0.0- 2.0 sec  0.27 GBytes  1.15 Gbits/sec
[node1][2021-07-27T19:01:33.037Z]: [  6]  0.0- 2.0 sec  0.37 GBytes  1.60 Gbits/sec
[node1][2021-07-27T19:01:33.037Z]: [  6]  0.0- 2.0 sec  0.37 GBytes  1.59 Gbits/sec
[node1][2021-07-27T19:01:33.037Z]: [SUM]  0.0- 2.0 sec  3.22 GBytes  13.8 Gbits/sec
[node1][2021-07-27T19:01:33.040Z]: -------------------------
[node1][2021-07-27T19:01:33.041Z]: End Sequential Network Test for [node2]
[node1][2021-07-27T19:01:33.042Z]: -------------------------
[node1][2021-07-27T19:01:33.043Z]: ---------------------------
[node1][2021-07-27T19:01:33.044Z]: End Sequential Network Tests
[node1][2021-07-27T19:01:33.045Z]: ---------------------------
[node1][2021-07-27T19:01:33.046Z]: NOTE - Parallel network tests are only run if there's more than one remote host.
[node1][2021-07-27T19:01:33.046Z]: -----------------------------
[node1][2021-07-27T19:01:33.047Z]: End Network Tests
[node1][2021-07-27T19:01:33.048Z]: -----------------------------
[node1][2021-07-27T19:01:33.049Z]: Copying files to all hosts
[node1][2021-07-27T19:01:33.642Z]: -----------------------------
[node1][2021-07-27T19:01:33.643Z]: Begin DATA IO Tests
[node1][2021-07-27T19:01:33.644Z]: -----------------------------
[node1][2021-07-27T19:01:33.645Z]: DATA IO Tests running in parallel. Waiting for all hosts to finish
[node1][2021-07-27T19:01:33.646Z]: Starting write test (readhold file) watcher on all hosts to synchronize the start of read tests
[node1][2021-07-27T19:07:29.914Z]: Write tests complete on all nodes. Starting read tests
[node1][2021-07-27T19:01:33.827Z]: -------------------------
[node1][2021-07-27T19:01:33.828Z]: Begin DNFS IO Test for [node1]
[node1][2021-07-27T19:01:33.829Z]: -------------------------
[node1][2021-07-27T19:01:33.830Z]: Defined target dir: /datashare
[node1][2021-07-27T19:01:33.831Z]: New target dir:     /datashare/viya_perf_tool_DNFS_node1_1627412479
[node1][2021-07-27T19:01:33.837Z]: --- Beginning calculations ---
[node1][2021-07-27T19:01:33.846Z]: Total memory: 94.26 GB
[node1][2021-07-27T19:01:33.854Z]: Target file system type: nfs4
[node1][2021-07-27T19:01:33.861Z]: Assuming target dir is a shared file system because [SHARED_DATA_DIR=Y]
[node1][2021-07-27T19:01:33.863Z]: Total shared file system space: 297.90 GB
[node1][2021-07-27T19:01:33.865Z]: Available shared file system space: 282.35 GB
[node1][2021-07-27T19:01:33.867Z]: 10% buffer: 29.79 GB
[node1][2021-07-27T19:01:33.868Z]: Available space - buffer: 252.56 GB
[node1][2021-07-27T19:01:33.869Z]: Workers: 2
[node1][2021-07-27T19:01:33.871Z]: Available space per worker [(available space - buffer) / # of workers]: 126.28 GB
[node1][2021-07-27T19:01:33.872Z]: Sockets: 16
[node1][2021-07-27T19:01:33.872Z]: Physical cores per socket: 1
[node1][2021-07-27T19:01:33.873Z]: Total physical cores: 16
[node1][2021-07-27T19:01:33.874Z]: WARNING - More than two sockets detected. CPU performance may be affected by NUMA.
[node1][2021-07-27T19:01:33.878Z]: Iterations (threads) per physical core: 1
[node1][2021-07-27T19:01:33.879Z]: Total iterations: 16
[node1][2021-07-27T19:01:33.879Z]: Block size: 64 KB
[node1][2021-07-27T19:01:33.880Z]: Blocks per iteration: 655,360
[node1][2021-07-27T19:01:33.880Z]: File size per iteration: 40 GB
[node1][2021-07-27T19:01:33.881Z]: Total file size: 640.00 GB
[node1][2021-07-27T19:01:33.883Z]: Total required space (including an extra file for flushing file cache): 680.00 GB
[node1][2021-07-27T19:01:33.884Z]: WARNING - Insufficient free space in [/datashare/viya_perf_tool_DNFS_node1_1627412479] for FULL test. Smaller file sizes will be used.
[node1][2021-07-27T19:01:33.885Z]: -- Recalculating file size and # of blocks --
[node1][2021-07-27T19:01:33.892Z]: Iterations (threads) per physical core: 1
[node1][2021-07-27T19:01:33.893Z]: Total iterations: 16
[node1][2021-07-27T19:01:33.895Z]: Block size: 64 KB
[node1][2021-07-27T19:01:33.896Z]: Blocks per iteration: 121,705
[node1][2021-07-27T19:01:33.897Z]: File size per iteration: 7.43 GB
[node1][2021-07-27T19:01:33.898Z]: Total file size: 118.85 GB
[node1][2021-07-27T19:01:33.899Z]: Total required space (including an extra file for flushing file cache): 126.28 GB
[node1][2021-07-27T19:01:33.901Z]: Current time: Tue Jul 27 15:01:33 EDT 2021
[node1][2021-07-27T19:01:33.902Z]: --- Calculations complete ---
[node1][2021-07-27T19:01:33.903Z]: --- Executing DNFS IO test ---
[node1][2021-07-27T19:01:33.903Z]: Executing write tests
[node1][2021-07-27T19:01:33.907Z]: Launching iteration: 1
[node1][2021-07-27T19:01:33.908Z]: Launching iteration: 2
[node1][2021-07-27T19:01:33.909Z]: Launching iteration: 3
[node1][2021-07-27T19:01:33.910Z]: Launching iteration: 4
[node1][2021-07-27T19:01:33.911Z]: Launching iteration: 5
[node1][2021-07-27T19:01:33.912Z]: Launching iteration: 6
[node1][2021-07-27T19:01:33.914Z]: Launching iteration: 7
[node1][2021-07-27T19:01:33.915Z]: Launching iteration: 8
[node1][2021-07-27T19:01:33.916Z]: Launching iteration: 9
[node1][2021-07-27T19:01:33.917Z]: Launching iteration: 10
[node1][2021-07-27T19:01:33.918Z]: Launching iteration: 11
[node1][2021-07-27T19:01:33.920Z]: Launching iteration: 12
[node1][2021-07-27T19:01:33.921Z]: Launching iteration: 13
[node1][2021-07-27T19:01:33.922Z]: Launching iteration: 14
[node1][2021-07-27T19:01:33.924Z]: Launching iteration: 15
[node1][2021-07-27T19:01:33.925Z]: Launching iteration: 16
[node1][2021-07-27T19:01:33.926Z]: Waiting for write tests to complete
[node1][2021-07-27T19:04:17.011Z]: Write tests complete
[node1][2021-07-27T19:04:17.012Z]: Flushing test files from cache - removing write files and creating copies via direct IO
[node1][2021-07-27T19:07:27.715Z]: Flushing test files from cache complete
[node1][2021-07-27T19:07:27.717Z]: Waiting for write tests to complete on all nodes before continuing
[node1][2021-07-27T19:07:31.720Z]: All write tests complete. Continuing
[node1][2021-07-27T19:07:31.721Z]: Executing read tests
[node1][2021-07-27T19:07:31.722Z]: Launching iteration: 1
[node1][2021-07-27T19:07:31.723Z]: Launching iteration: 2
[node1][2021-07-27T19:07:31.724Z]: Launching iteration: 3
[node1][2021-07-27T19:07:31.726Z]: Launching iteration: 4
[node1][2021-07-27T19:07:31.727Z]: Launching iteration: 5
[node1][2021-07-27T19:07:31.728Z]: Launching iteration: 6
[node1][2021-07-27T19:07:31.729Z]: Launching iteration: 7
[node1][2021-07-27T19:07:31.730Z]: Launching iteration: 8
[node1][2021-07-27T19:07:31.732Z]: Launching iteration: 9
[node1][2021-07-27T19:07:31.733Z]: Launching iteration: 10
[node1][2021-07-27T19:07:31.734Z]: Launching iteration: 11
[node1][2021-07-27T19:07:31.736Z]: Launching iteration: 12
[node1][2021-07-27T19:07:31.737Z]: Launching iteration: 13
[node1][2021-07-27T19:07:31.738Z]: Launching iteration: 14
[node1][2021-07-27T19:07:31.739Z]: Launching iteration: 15
[node1][2021-07-27T19:07:31.741Z]: Launching iteration: 16
[node1][2021-07-27T19:07:31.742Z]: Waiting for read tests to complete
[node1][2021-07-27T19:09:05.295Z]: Read tests complete
[node1][2021-07-27T19:09:05.296Z]: --- DNFS IO test complete ---
[node1][2021-07-27T19:09:05.475Z]: --- Begin DNFS IO test results ---
[node1][2021-07-27T19:09:05.476Z]: RESULTS
[node1][2021-07-27T19:09:05.477Z]: TARGET DETAILS
[node1][2021-07-27T19:09:05.478Z]:    directory:    /datashare/viya_perf_tool_DNFS_node1_1627412479
[node1][2021-07-27T19:09:05.479Z]:    df -k:        10.122.33.184:/datashare      312371200 16303104 296068096   6% /datashare
[node1][2021-07-27T19:09:05.480Z]:    mount point:  10.122.33.184:/datashare on /datashare type nfs4 (rw,relatime,vers=4.1,rsize=1048576,wsize=1048576,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=10.122.33.173,local_lock=none,addr=10.122.33.184)
[node1][2021-07-27T19:09:05.483Z]:    file size:    7.42 GB
[node1][2021-07-27T19:09:05.483Z]:  STATISTICS
[node1][2021-07-27T19:09:05.486Z]:    read time:              93.37 seconds per physical core
[node1][2021-07-27T19:09:05.488Z]:    read throughput rate:   81.46 MB/second per physical core
[node1][2021-07-27T19:09:05.491Z]:    write time:             162.47 seconds per physical core
[node1][2021-07-27T19:09:05.493Z]:    write throughput rate:  46.81 MB/second per physical core
[node1][2021-07-27T19:09:05.494Z]: --- End DNFS IO test results ---
[node1][2021-07-27T19:09:05.495Z]: Processing complete.
[node1][2021-07-27T19:09:05.495Z]: Start time: Tue Jul 27 15:01:33 EDT 2021.
[node1][2021-07-27T19:09:05.497Z]: End time:   Tue Jul 27 15:09:05 EDT 2021.
[node1][2021-07-27T19:09:05.498Z]: -------------------------
[node1][2021-07-27T19:09:05.499Z]: End DNFS IO Test for [node1]
[node1][2021-07-27T19:09:05.500Z]: -------------------------
[node1][2021-07-27T19:09:16.152Z]: The target directory [/datashare/viya_perf_tool_DNFS_node1_1627412479] has been removed.
[node2][2021-07-27T19:01:33.832Z]: -------------------------
[node2][2021-07-27T19:01:33.833Z]: Begin DNFS IO Test for [node2]
[node2][2021-07-27T19:01:33.834Z]: -------------------------
[node2][2021-07-27T19:01:33.835Z]: Defined target dir: /datashare
[node2][2021-07-27T19:01:33.836Z]: New target dir:     /datashare/viya_perf_tool_DNFS_node2_1627412479
[node2][2021-07-27T19:01:33.843Z]: --- Beginning calculations ---
[node2][2021-07-27T19:01:33.854Z]: Total memory: 94.26 GB
[node2][2021-07-27T19:01:33.862Z]: Target file system type: nfs4
[node2][2021-07-27T19:01:33.869Z]: Assuming target dir is a shared file system because [SHARED_DATA_DIR=Y]
[node2][2021-07-27T19:01:33.871Z]: Total shared file system space: 297.90 GB
[node2][2021-07-27T19:01:33.873Z]: Available shared file system space: 282.35 GB
[node2][2021-07-27T19:01:33.875Z]: 10% buffer: 29.79 GB
[node2][2021-07-27T19:01:33.876Z]: Available space - buffer: 252.56 GB
[node2][2021-07-27T19:01:33.877Z]: Workers: 2
[node2][2021-07-27T19:01:33.879Z]: Available space per worker [(available space - buffer) / # of workers]: 126.28 GB
[node2][2021-07-27T19:01:33.880Z]: Sockets: 16
[node2][2021-07-27T19:01:33.881Z]: Physical cores per socket: 1
[node2][2021-07-27T19:01:33.881Z]: Total physical cores: 16
[node2][2021-07-27T19:01:33.882Z]: WARNING - More than two sockets detected. CPU performance may be affected by NUMA.
[node2][2021-07-27T19:01:33.886Z]: Iterations (threads) per physical core: 1
[node2][2021-07-27T19:01:33.887Z]: Total iterations: 16
[node2][2021-07-27T19:01:33.887Z]: Block size: 64 KB
[node2][2021-07-27T19:01:33.888Z]: Blocks per iteration: 655,360
[node2][2021-07-27T19:01:33.889Z]: File size per iteration: 40 GB
[node2][2021-07-27T19:01:33.889Z]: Total file size: 640.00 GB
[node2][2021-07-27T19:01:33.891Z]: Total required space (including an extra file for flushing file cache): 680.00 GB
[node2][2021-07-27T19:01:33.892Z]: WARNING - Insufficient free space in [/datashare/viya_perf_tool_DNFS_node2_1627412479] for FULL test. Smaller file sizes will be used.
[node2][2021-07-27T19:01:33.893Z]: -- Recalculating file size and # of blocks --
[node2][2021-07-27T19:01:33.901Z]: Iterations (threads) per physical core: 1
[node2][2021-07-27T19:01:33.902Z]: Total iterations: 16
[node2][2021-07-27T19:01:33.903Z]: Block size: 64 KB
[node2][2021-07-27T19:01:33.904Z]: Blocks per iteration: 121,705
[node2][2021-07-27T19:01:33.904Z]: File size per iteration: 7.43 GB
[node2][2021-07-27T19:01:33.906Z]: Total file size: 118.85 GB
[node2][2021-07-27T19:01:33.908Z]: Total required space (including an extra file for flushing file cache): 126.28 GB
[node2][2021-07-27T19:01:33.909Z]: Current time: Wed Jul 28 09:01:33 +14 2021
[node2][2021-07-27T19:01:33.910Z]: --- Calculations complete ---
[node2][2021-07-27T19:01:33.911Z]: --- Executing DNFS IO test ---
[node2][2021-07-27T19:01:33.912Z]: Executing write tests
[node2][2021-07-27T19:01:33.915Z]: Launching iteration: 1
[node2][2021-07-27T19:01:33.916Z]: Launching iteration: 2
[node2][2021-07-27T19:01:33.917Z]: Launching iteration: 3
[node2][2021-07-27T19:01:33.919Z]: Launching iteration: 4
[node2][2021-07-27T19:01:33.920Z]: Launching iteration: 5
[node2][2021-07-27T19:01:33.921Z]: Launching iteration: 6
[node2][2021-07-27T19:01:33.922Z]: Launching iteration: 7
[node2][2021-07-27T19:01:33.924Z]: Launching iteration: 8
[node2][2021-07-27T19:01:33.932Z]: Launching iteration: 9
[node2][2021-07-27T19:01:33.939Z]: Launching iteration: 10
[node2][2021-07-27T19:01:33.946Z]: Launching iteration: 11
[node2][2021-07-27T19:01:33.961Z]: Launching iteration: 12
[node2][2021-07-27T19:01:33.970Z]: Launching iteration: 13
[node2][2021-07-27T19:01:33.971Z]: Launching iteration: 14
[node2][2021-07-27T19:01:33.977Z]: Launching iteration: 15
[node2][2021-07-27T19:01:33.979Z]: Launching iteration: 16
[node2][2021-07-27T19:01:33.980Z]: Waiting for write tests to complete
[node2][2021-07-27T19:04:21.071Z]: Write tests complete
[node2][2021-07-27T19:04:21.072Z]: Flushing test files from cache - removing write files and creating copies via direct IO
[node2][2021-07-27T19:07:02.800Z]: Flushing test files from cache complete
[node2][2021-07-27T19:07:02.803Z]: Waiting for write tests to complete on all nodes before continuing
[node2][2021-07-27T19:07:30.821Z]: All write tests complete. Continuing
[node2][2021-07-27T19:07:30.822Z]: Executing read tests
[node2][2021-07-27T19:07:30.823Z]: Launching iteration: 1
[node2][2021-07-27T19:07:30.824Z]: Launching iteration: 2
[node2][2021-07-27T19:07:30.825Z]: Launching iteration: 3
[node2][2021-07-27T19:07:30.827Z]: Launching iteration: 4
[node2][2021-07-27T19:07:30.828Z]: Launching iteration: 5
[node2][2021-07-27T19:07:30.830Z]: Launching iteration: 6
[node2][2021-07-27T19:07:30.834Z]: Launching iteration: 7
[node2][2021-07-27T19:07:30.836Z]: Launching iteration: 8
[node2][2021-07-27T19:07:30.838Z]: Launching iteration: 9
[node2][2021-07-27T19:07:30.839Z]: Launching iteration: 10
[node2][2021-07-27T19:07:30.840Z]: Launching iteration: 11
[node2][2021-07-27T19:07:30.841Z]: Launching iteration: 12
[node2][2021-07-27T19:07:30.843Z]: Launching iteration: 13
[node2][2021-07-27T19:07:30.844Z]: Launching iteration: 14
[node2][2021-07-27T19:07:30.845Z]: Launching iteration: 15
[node2][2021-07-27T19:07:30.846Z]: Launching iteration: 16
[node2][2021-07-27T19:07:30.847Z]: Waiting for read tests to complete
[node2][2021-07-27T19:09:15.445Z]: Read tests complete
[node2][2021-07-27T19:09:15.446Z]: --- DNFS IO test complete ---
[node2][2021-07-27T19:09:15.596Z]: --- Begin DNFS IO test results ---
[node2][2021-07-27T19:09:15.597Z]: RESULTS
[node2][2021-07-27T19:09:15.598Z]: TARGET DETAILS
[node2][2021-07-27T19:09:15.599Z]:    directory:    /datashare/viya_perf_tool_DNFS_node2_1627412479
[node2][2021-07-27T19:09:15.600Z]:    df -k:        10.122.33.184:/datashare      312371200 16303104 296068096   6% /datashare
[node2][2021-07-27T19:09:15.601Z]:    mount point:  10.122.33.184:/datashare on /datashare type nfs4 (rw,relatime,vers=4.1,rsize=1048576,wsize=1048576,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=10.122.33.174,local_lock=none,addr=10.122.33.184)
[node2][2021-07-27T19:09:15.603Z]:    file size:    7.42 GB
[node2][2021-07-27T19:09:15.603Z]:  STATISTICS
[node2][2021-07-27T19:09:15.605Z]:    read time:              104.43 seconds per physical core
[node2][2021-07-27T19:09:15.607Z]:    read throughput rate:   72.83 MB/second per physical core
[node2][2021-07-27T19:09:15.609Z]:    write time:             166.55 seconds per physical core
[node2][2021-07-27T19:09:15.611Z]:    write throughput rate:  45.67 MB/second per physical core
[node2][2021-07-27T19:09:15.612Z]: --- End DNFS IO test results ---
[node2][2021-07-27T19:09:15.613Z]: Processing complete.
[node2][2021-07-27T19:09:15.614Z]: Start time: Wed Jul 28 09:01:33 +14 2021.
[node2][2021-07-27T19:09:15.615Z]: End time:   Wed Jul 28 09:09:15 +14 2021.
[node2][2021-07-27T19:09:15.616Z]: -------------------------
[node2][2021-07-27T19:09:15.617Z]: End DNFS IO Test for [node2]
[node2][2021-07-27T19:09:15.618Z]: -------------------------
[node2][2021-07-27T19:09:25.167Z]: The target directory [/datashare/viya_perf_tool_DNFS_node2_1627412479] has been removed.
[node1][2021-07-27T19:09:25.181Z]: -----------------------------
[node1][2021-07-27T19:09:25.182Z]: End DATA IO Tests
[node1][2021-07-27T19:09:25.183Z]: -----------------------------
[node1][2021-07-27T19:09:25.184Z]: -----------------------------
[node1][2021-07-27T19:09:25.184Z]: Begin CDC IO Tests
[node1][2021-07-27T19:09:25.185Z]: -----------------------------
[node1][2021-07-27T19:09:25.187Z]: CDC IO Tests running in parallel. Waiting for all hosts to finish
[node1][2021-07-27T19:09:25.397Z]: -------------------------
[node1][2021-07-27T19:09:25.398Z]: Begin CDC IO Test for [node1]
[node1][2021-07-27T19:09:25.399Z]: -------------------------
[node1][2021-07-27T19:09:25.400Z]: Defined target dir: /saswork
[node1][2021-07-27T19:09:25.400Z]: New target dir:     /saswork/viya_perf_tool_CDC_node1_1627412479
[node1][2021-07-27T19:09:25.406Z]: --- Beginning calculations ---
[node1][2021-07-27T19:09:25.418Z]: Total memory: 94.26 GB
[node1][2021-07-27T19:09:25.430Z]: Target file system type: xfs
[node1][2021-07-27T19:09:25.440Z]: Total space: 297.90 GB
[node1][2021-07-27T19:09:25.443Z]: Available space: 84.50 GB
[node1][2021-07-27T19:09:25.445Z]: 10% buffer: 29.79 GB
[node1][2021-07-27T19:09:25.447Z]: Available space - buffer: 54.71 GB
[node1][2021-07-27T19:09:25.448Z]: Sockets: 16
[node1][2021-07-27T19:09:25.449Z]: Physical cores per socket: 1
[node1][2021-07-27T19:09:25.450Z]: Total physical cores: 16
[node1][2021-07-27T19:09:25.451Z]: WARNING - More than two sockets detected. CPU performance may be affected by NUMA.
[node1][2021-07-27T19:09:25.454Z]: Iterations (threads) per physical core: 2
[node1][2021-07-27T19:09:25.455Z]: Total iterations: 32
[node1][2021-07-27T19:09:25.456Z]: Block size: 64 KB
[node1][2021-07-27T19:09:25.457Z]: Blocks per iteration: 327,680
[node1][2021-07-27T19:09:25.458Z]: File size per iteration: 20 GB
[node1][2021-07-27T19:09:25.459Z]: Total file size: 640.00 GB
[node1][2021-07-27T19:09:25.460Z]: Max preallocation size per iteration: 8.00 GB
[node1][2021-07-27T19:09:25.462Z]: Total max preallocation size: 256.00 GB
[node1][2021-07-27T19:09:25.464Z]: Total required space (including an extra file for flushing file cache): 916.00 GB
[node1][2021-07-27T19:09:25.465Z]: WARNING - Insufficient free space in [/saswork/viya_perf_tool_CDC_node1_1627412479] for FULL test. Smaller file sizes will be used.
[node1][2021-07-27T19:09:25.466Z]: -- Recalculating file size and # of blocks --
[node1][2021-07-27T19:09:25.477Z]: Iterations (threads) per physical core: 2
[node1][2021-07-27T19:09:25.478Z]: Total iterations: 32
[node1][2021-07-27T19:09:25.480Z]: Block size: 64 KB
[node1][2021-07-27T19:09:25.480Z]: Blocks per iteration: 13,580
[node1][2021-07-27T19:09:25.480Z]: File size per iteration: 0.83 GB
[node1][2021-07-27T19:09:25.482Z]: Total file size: 53.05 GB
[node1][2021-07-27T19:09:25.484Z]: Max preallocation size per iteration: 0.83 GB
[node1][2021-07-27T19:09:25.486Z]: Total max preallocation size: 26.52 GB
[node1][2021-07-27T19:09:25.488Z]: Total required space (including an extra file for flushing file cache): 53.88 GB
[node1][2021-07-27T19:09:25.489Z]: Current time: Tue Jul 27 15:09:25 EDT 2021
[node1][2021-07-27T19:09:25.490Z]: --- Calculations complete ---
[node1][2021-07-27T19:09:25.491Z]: --- Executing CDC IO test ---
[node1][2021-07-27T19:09:25.492Z]: Executing write tests
[node1][2021-07-27T19:09:25.494Z]: Launching iteration: 1
[node1][2021-07-27T19:09:25.495Z]: Launching iteration: 2
[node1][2021-07-27T19:09:25.497Z]: Launching iteration: 3
[node1][2021-07-27T19:09:25.498Z]: Launching iteration: 4
[node1][2021-07-27T19:09:25.499Z]: Launching iteration: 5
[node1][2021-07-27T19:09:25.501Z]: Launching iteration: 6
[node1][2021-07-27T19:09:25.502Z]: Launching iteration: 7
[node1][2021-07-27T19:09:25.504Z]: Launching iteration: 8
[node1][2021-07-27T19:09:25.505Z]: Launching iteration: 9
[node1][2021-07-27T19:09:25.510Z]: Launching iteration: 10
[node1][2021-07-27T19:09:25.512Z]: Launching iteration: 11
[node1][2021-07-27T19:09:25.513Z]: Launching iteration: 12
[node1][2021-07-27T19:09:25.514Z]: Launching iteration: 13
[node1][2021-07-27T19:09:25.516Z]: Launching iteration: 14
[node1][2021-07-27T19:09:25.517Z]: Launching iteration: 15
[node1][2021-07-27T19:09:25.518Z]: Launching iteration: 16
[node1][2021-07-27T19:09:25.534Z]: Launching iteration: 17
[node1][2021-07-27T19:09:25.551Z]: Launching iteration: 18
[node1][2021-07-27T19:09:25.564Z]: Launching iteration: 19
[node1][2021-07-27T19:09:25.593Z]: Launching iteration: 20
[node1][2021-07-27T19:09:25.609Z]: Launching iteration: 21
[node1][2021-07-27T19:09:25.622Z]: Launching iteration: 22
[node1][2021-07-27T19:09:25.648Z]: Launching iteration: 23
[node1][2021-07-27T19:09:25.661Z]: Launching iteration: 24
[node1][2021-07-27T19:09:25.691Z]: Launching iteration: 25
[node1][2021-07-27T19:09:25.709Z]: Launching iteration: 26
[node1][2021-07-27T19:09:25.724Z]: Launching iteration: 27
[node1][2021-07-27T19:09:25.748Z]: Launching iteration: 28
[node1][2021-07-27T19:09:25.778Z]: Launching iteration: 29
[node1][2021-07-27T19:09:25.805Z]: Launching iteration: 30
[node1][2021-07-27T19:09:25.827Z]: Launching iteration: 31
[node1][2021-07-27T19:09:25.853Z]: Launching iteration: 32
[node1][2021-07-27T19:09:25.890Z]: Waiting for write tests to complete
[node1][2021-07-27T19:09:35.164Z]: Write tests complete
[node1][2021-07-27T19:09:35.165Z]: Flushing test files from cache - removing write files and creating copies via direct IO
[node1][2021-07-27T19:09:45.337Z]: Flushing test files from cache complete
[node1][2021-07-27T19:09:45.338Z]: Executing read tests
[node1][2021-07-27T19:09:45.339Z]: Launching iteration: 1
[node1][2021-07-27T19:09:45.341Z]: Launching iteration: 2
[node1][2021-07-27T19:09:45.342Z]: Launching iteration: 3
[node1][2021-07-27T19:09:45.343Z]: Launching iteration: 4
[node1][2021-07-27T19:09:45.345Z]: Launching iteration: 5
[node1][2021-07-27T19:09:45.346Z]: Launching iteration: 6
[node1][2021-07-27T19:09:45.347Z]: Launching iteration: 7
[node1][2021-07-27T19:09:45.349Z]: Launching iteration: 8
[node1][2021-07-27T19:09:45.350Z]: Launching iteration: 9
[node1][2021-07-27T19:09:45.351Z]: Launching iteration: 10
[node1][2021-07-27T19:09:45.353Z]: Launching iteration: 11
[node1][2021-07-27T19:09:45.355Z]: Launching iteration: 12
[node1][2021-07-27T19:09:45.356Z]: Launching iteration: 13
[node1][2021-07-27T19:09:45.357Z]: Launching iteration: 14
[node1][2021-07-27T19:09:45.359Z]: Launching iteration: 15
[node1][2021-07-27T19:09:45.360Z]: Launching iteration: 16
[node1][2021-07-27T19:09:45.363Z]: Launching iteration: 17
[node1][2021-07-27T19:09:45.379Z]: Launching iteration: 18
[node1][2021-07-27T19:09:45.381Z]: Launching iteration: 19
[node1][2021-07-27T19:09:45.382Z]: Launching iteration: 20
[node1][2021-07-27T19:09:45.383Z]: Launching iteration: 21
[node1][2021-07-27T19:09:45.385Z]: Launching iteration: 22
[node1][2021-07-27T19:09:45.386Z]: Launching iteration: 23
[node1][2021-07-27T19:09:45.387Z]: Launching iteration: 24
[node1][2021-07-27T19:09:45.389Z]: Launching iteration: 25
[node1][2021-07-27T19:09:45.390Z]: Launching iteration: 26
[node1][2021-07-27T19:09:45.391Z]: Launching iteration: 27
[node1][2021-07-27T19:09:45.393Z]: Launching iteration: 28
[node1][2021-07-27T19:09:45.394Z]: Launching iteration: 29
[node1][2021-07-27T19:09:45.395Z]: Launching iteration: 30
[node1][2021-07-27T19:09:45.396Z]: Launching iteration: 31
[node1][2021-07-27T19:09:45.398Z]: Launching iteration: 32
[node1][2021-07-27T19:09:45.399Z]: Waiting for read tests to complete
[node1][2021-07-27T19:09:50.124Z]: Read tests complete
[node1][2021-07-27T19:09:50.125Z]: --- CDC IO test complete ---
[node1][2021-07-27T19:09:50.408Z]: --- Begin CDC IO test results ---
[node1][2021-07-27T19:09:50.409Z]: RESULTS
[node1][2021-07-27T19:09:50.410Z]: TARGET DETAILS
[node1][2021-07-27T19:09:50.410Z]:    directory:    /saswork/viya_perf_tool_CDC_node1_1627412479
[node1][2021-07-27T19:09:50.411Z]:    df -k:        /dev/sda2      312371180 223769992  88601188  72% /
[node1][2021-07-27T19:09:50.412Z]:    mount point:  /dev/sda2 on / type xfs (rw,relatime,attr2,inode64,noquota)
[node1][2021-07-27T19:09:50.414Z]:    file size:    0.82 GB
[node1][2021-07-27T19:09:50.415Z]:  STATISTICS
[node1][2021-07-27T19:09:50.417Z]:    read time:              7.53 seconds per physical core
[node1][2021-07-27T19:09:50.419Z]:    read throughput rate:   112.71 MB/second per physical core
[node1][2021-07-27T19:09:50.421Z]:    write time:             15.19 seconds per physical core
[node1][2021-07-27T19:09:50.424Z]:    write throughput rate:  55.87 MB/second per physical core
[node1][2021-07-27T19:09:50.424Z]: --- End CDC IO test results ---
[node1][2021-07-27T19:09:50.425Z]: Processing complete.
[node1][2021-07-27T19:09:50.426Z]: Start time: Tue Jul 27 15:09:25 EDT 2021.
[node1][2021-07-27T19:09:50.428Z]: End time:   Tue Jul 27 15:09:50 EDT 2021.
[node1][2021-07-27T19:09:50.428Z]: -------------------------
[node1][2021-07-27T19:09:50.429Z]: End CDC IO Test for [node1]
[node1][2021-07-27T19:09:50.430Z]: -------------------------
[node1][2021-07-27T19:09:52.589Z]: The target directory [/saswork/viya_perf_tool_CDC_node1_1627412479] has been removed.
[node2][2021-07-27T19:09:25.399Z]: -------------------------
[node2][2021-07-27T19:09:25.400Z]: Begin CDC IO Test for [node2]
[node2][2021-07-27T19:09:25.400Z]: -------------------------
[node2][2021-07-27T19:09:25.401Z]: Defined target dir: /saswork
[node2][2021-07-27T19:09:25.403Z]: New target dir:     /saswork/viya_perf_tool_CDC_node2_1627412479
[node2][2021-07-27T19:09:25.408Z]: --- Beginning calculations ---
[node2][2021-07-27T19:09:25.419Z]: Total memory: 94.26 GB
[node2][2021-07-27T19:09:25.430Z]: Target file system type: xfs
[node2][2021-07-27T19:09:25.441Z]: Total space: 297.90 GB
[node2][2021-07-27T19:09:25.443Z]: Available space: 249.89 GB
[node2][2021-07-27T19:09:25.445Z]: 10% buffer: 29.79 GB
[node2][2021-07-27T19:09:25.447Z]: Available space - buffer: 220.10 GB
[node2][2021-07-27T19:09:25.447Z]: Sockets: 16
[node2][2021-07-27T19:09:25.448Z]: Physical cores per socket: 1
[node2][2021-07-27T19:09:25.449Z]: Total physical cores: 16
[node2][2021-07-27T19:09:25.450Z]: WARNING - More than two sockets detected. CPU performance may be affected by NUMA.
[node2][2021-07-27T19:09:25.454Z]: Iterations (threads) per physical core: 2
[node2][2021-07-27T19:09:25.455Z]: Total iterations: 32
[node2][2021-07-27T19:09:25.456Z]: Block size: 64 KB
[node2][2021-07-27T19:09:25.456Z]: Blocks per iteration: 327,680
[node2][2021-07-27T19:09:25.456Z]: File size per iteration: 20 GB
[node2][2021-07-27T19:09:25.458Z]: Total file size: 640.00 GB
[node2][2021-07-27T19:09:25.460Z]: Max preallocation size per iteration: 8.00 GB
[node2][2021-07-27T19:09:25.462Z]: Total max preallocation size: 256.00 GB
[node2][2021-07-27T19:09:25.464Z]: Total required space (including an extra file for flushing file cache): 916.00 GB
[node2][2021-07-27T19:09:25.466Z]: WARNING - Insufficient free space in [/saswork/viya_perf_tool_CDC_node2_1627412479] for FULL test. Smaller file sizes will be used.
[node2][2021-07-27T19:09:25.467Z]: -- Recalculating file size and # of blocks --
[node2][2021-07-27T19:09:25.479Z]: Iterations (threads) per physical core: 2
[node2][2021-07-27T19:09:25.479Z]: Total iterations: 32
[node2][2021-07-27T19:09:25.482Z]: Block size: 64 KB
[node2][2021-07-27T19:09:25.482Z]: Blocks per iteration: 54,637
[node2][2021-07-27T19:09:25.482Z]: File size per iteration: 3.33 GB
[node2][2021-07-27T19:09:25.484Z]: Total file size: 53.05 GB
[node2][2021-07-27T19:09:25.486Z]: Max preallocation size per iteration: 3.33 GB
[node2][2021-07-27T19:09:25.488Z]: Total max preallocation size: 106.71 GB
[node2][2021-07-27T19:09:25.490Z]: Total required space (including an extra file for flushing file cache): 216.76 GB
[node2][2021-07-27T19:09:25.492Z]: Current time: Wed Jul 28 09:09:25 +14 2021
[node2][2021-07-27T19:09:25.492Z]: --- Calculations complete ---
[node2][2021-07-27T19:09:25.493Z]: --- Executing CDC IO test ---
[node2][2021-07-27T19:09:25.494Z]: Executing write tests
[node2][2021-07-27T19:09:25.497Z]: Launching iteration: 1
[node2][2021-07-27T19:09:25.499Z]: Launching iteration: 2
[node2][2021-07-27T19:09:25.500Z]: Launching iteration: 3
[node2][2021-07-27T19:09:25.501Z]: Launching iteration: 4
[node2][2021-07-27T19:09:25.502Z]: Launching iteration: 5
[node2][2021-07-27T19:09:25.503Z]: Launching iteration: 6
[node2][2021-07-27T19:09:25.505Z]: Launching iteration: 7
[node2][2021-07-27T19:09:25.506Z]: Launching iteration: 8
[node2][2021-07-27T19:09:25.507Z]: Launching iteration: 9
[node2][2021-07-27T19:09:25.508Z]: Launching iteration: 10
[node2][2021-07-27T19:09:25.509Z]: Launching iteration: 11
[node2][2021-07-27T19:09:25.510Z]: Launching iteration: 12
[node2][2021-07-27T19:09:25.512Z]: Launching iteration: 13
[node2][2021-07-27T19:09:25.513Z]: Launching iteration: 14
[node2][2021-07-27T19:09:25.514Z]: Launching iteration: 15
[node2][2021-07-27T19:09:25.515Z]: Launching iteration: 16
[node2][2021-07-27T19:09:25.535Z]: Launching iteration: 17
[node2][2021-07-27T19:09:25.551Z]: Launching iteration: 18
[node2][2021-07-27T19:09:25.576Z]: Launching iteration: 19
[node2][2021-07-27T19:09:25.602Z]: Launching iteration: 20
[node2][2021-07-27T19:09:25.616Z]: Launching iteration: 21
[node2][2021-07-27T19:09:25.641Z]: Launching iteration: 22
[node2][2021-07-27T19:09:25.655Z]: Launching iteration: 23
[node2][2021-07-27T19:09:25.680Z]: Launching iteration: 24
[node2][2021-07-27T19:09:25.694Z]: Launching iteration: 25
[node2][2021-07-27T19:09:25.716Z]: Launching iteration: 26
[node2][2021-07-27T19:09:25.738Z]: Launching iteration: 27
[node2][2021-07-27T19:09:25.767Z]: Launching iteration: 28
[node2][2021-07-27T19:09:25.795Z]: Launching iteration: 29
[node2][2021-07-27T19:09:25.819Z]: Launching iteration: 30
[node2][2021-07-27T19:09:25.846Z]: Launching iteration: 31
[node2][2021-07-27T19:09:25.868Z]: Launching iteration: 32
[node2][2021-07-27T19:09:25.886Z]: Waiting for write tests to complete
[node2][2021-07-27T19:09:53.192Z]: Write tests complete
[node2][2021-07-27T19:09:53.193Z]: Flushing test files from cache - removing write files and creating copies via direct IO
[node2][2021-07-27T19:10:17.544Z]: Flushing test files from cache complete
[node2][2021-07-27T19:10:17.545Z]: Executing read tests
[node2][2021-07-27T19:10:17.546Z]: Launching iteration: 1
[node2][2021-07-27T19:10:17.548Z]: Launching iteration: 2
[node2][2021-07-27T19:10:17.549Z]: Launching iteration: 3
[node2][2021-07-27T19:10:17.551Z]: Launching iteration: 4
[node2][2021-07-27T19:10:17.552Z]: Launching iteration: 5
[node2][2021-07-27T19:10:17.554Z]: Launching iteration: 6
[node2][2021-07-27T19:10:17.555Z]: Launching iteration: 7
[node2][2021-07-27T19:10:17.556Z]: Launching iteration: 8
[node2][2021-07-27T19:10:17.557Z]: Launching iteration: 9
[node2][2021-07-27T19:10:17.559Z]: Launching iteration: 10
[node2][2021-07-27T19:10:17.560Z]: Launching iteration: 11
[node2][2021-07-27T19:10:17.561Z]: Launching iteration: 12
[node2][2021-07-27T19:10:17.564Z]: Launching iteration: 13
[node2][2021-07-27T19:10:17.566Z]: Launching iteration: 14
[node2][2021-07-27T19:10:17.567Z]: Launching iteration: 15
[node2][2021-07-27T19:10:17.568Z]: Launching iteration: 16
[node2][2021-07-27T19:10:17.570Z]: Launching iteration: 17
[node2][2021-07-27T19:10:17.571Z]: Launching iteration: 18
[node2][2021-07-27T19:10:17.574Z]: Launching iteration: 19
[node2][2021-07-27T19:10:17.586Z]: Launching iteration: 20
[node2][2021-07-27T19:10:17.603Z]: Launching iteration: 21
[node2][2021-07-27T19:10:17.641Z]: Launching iteration: 22
[node2][2021-07-27T19:10:17.670Z]: Launching iteration: 23
[node2][2021-07-27T19:10:17.673Z]: Launching iteration: 24
[node2][2021-07-27T19:10:17.681Z]: Launching iteration: 25
[node2][2021-07-27T19:10:17.693Z]: Launching iteration: 26
[node2][2021-07-27T19:10:17.699Z]: Launching iteration: 27
[node2][2021-07-27T19:10:17.701Z]: Launching iteration: 28
[node2][2021-07-27T19:10:17.702Z]: Launching iteration: 29
[node2][2021-07-27T19:10:17.704Z]: Launching iteration: 30
[node2][2021-07-27T19:10:17.705Z]: Launching iteration: 31
[node2][2021-07-27T19:10:17.706Z]: Launching iteration: 32
[node2][2021-07-27T19:10:17.707Z]: Waiting for read tests to complete
[node2][2021-07-27T19:10:35.823Z]: Read tests complete
[node2][2021-07-27T19:10:35.824Z]: --- CDC IO test complete ---
[node2][2021-07-27T19:10:36.096Z]: --- Begin CDC IO test results ---
[node2][2021-07-27T19:10:36.097Z]: RESULTS
[node2][2021-07-27T19:10:36.098Z]: TARGET DETAILS
[node2][2021-07-27T19:10:36.099Z]:    directory:    /saswork/viya_perf_tool_CDC_node2_1627412479
[node2][2021-07-27T19:10:36.100Z]:    df -k:        /dev/sda2      312371180 50344836 262026344  17% /
[node2][2021-07-27T19:10:36.101Z]:    mount point:  /dev/sda2 on / type xfs (rw,relatime,attr2,inode64,noquota)
[node2][2021-07-27T19:10:36.103Z]:    file size:    3.33 GB
[node2][2021-07-27T19:10:36.104Z]:  STATISTICS
[node2][2021-07-27T19:10:36.106Z]:    read time:              36.03 seconds per physical core
[node2][2021-07-27T19:10:36.108Z]:    read throughput rate:   94.77 MB/second per physical core
[node2][2021-07-27T19:10:36.110Z]:    write time:             51.33 seconds per physical core
[node2][2021-07-27T19:10:36.113Z]:    write throughput rate:  66.52 MB/second per physical core
[node2][2021-07-27T19:10:36.114Z]: --- End CDC IO test results ---
[node2][2021-07-27T19:10:36.115Z]: Processing complete.
[node2][2021-07-27T19:10:36.115Z]: Start time: Wed Jul 28 09:09:25 +14 2021.
[node2][2021-07-27T19:10:36.117Z]: End time:   Wed Jul 28 09:10:36 +14 2021.
[node2][2021-07-27T19:10:36.118Z]: -------------------------
[node2][2021-07-27T19:10:36.119Z]: End CDC IO Test for [node2]
[node2][2021-07-27T19:10:36.120Z]: -------------------------
[node2][2021-07-27T19:10:41.223Z]: The target directory [/saswork/viya_perf_tool_CDC_node2_1627412479] has been removed.
[node1][2021-07-27T19:10:41.233Z]: -----------------------------
[node1][2021-07-27T19:10:41.234Z]: End CDC IO Tests
[node1][2021-07-27T19:10:41.235Z]: -----------------------------
[node1][2021-07-27T19:10:41.241Z]: The working directory [/tmp/viya_perf_tool_1627412479_tmpdir] has been removed from host [node1].
[node1][2021-07-27T19:10:41.396Z]: The working directory [/tmp/viya_perf_tool_1627412479_tmpdir] has been removed from host [node2].
[node1][2021-07-27T19:10:41.397Z]: Execution is complete!
```
