# What is this?

This is a series of scripts for [Vagrant](https://vagrantup.com) to stand-up and test [Apache (Incubating) Ratis](https://ratis.incubator.apache.org/) servers and clients. One needs to have Vagrant and [VirtualBox](https://virtualbox.org) installed to stand-up these tests environments.

# What is provided?

This provides a multi-host `Vagrantfile` which provides the following VM's:

## `ratistest` VM
This provides a built version of Ratis with the [Namazu](https://github.com/osrg/namazu) test framework as well

## `ratishddslowdown` VM
This VM starts three Ratis servers listening on ports 6000, 6001, 6002 and one of the Ratis servers logs against a directory made pathological (slow and error-prone) by Namazu. The VM forwards ports 6000, 6001 and 6002 to your hypervisor to accept client connections. Further, the configuration of pathology in namazu can be tuned in [hdd_config.toml](./namazu_configs/hdd_config.toml).

The test VM's can be reconfigured and all daemons restarted via: `vagrant up --provision <VM name>`
One can login to the VM and read the message-of-the-day for instructions on how to read the daemon logs; all daemons run in screen today.

# How to get started:
There is a shell script `run_all_tests.sh` which provides the following:

Run with option `build`:
* Builds the `ratistest` VM
* Packages a [Vagrant box](https://www.vagrantup.com/docs/boxes.html) to build specific test VMs off of
* Suspends `ratistest` VM
* Builds all test VMs and suspends them on success

Run with option `clean`:
* Destroys all test VMs
* Destroys the `ratistest` VM
* Removes the `ratistest.box` from Vagrant
* Removes the `ratistest.box` from the local file-system
