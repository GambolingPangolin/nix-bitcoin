nix-bitcoin
===

Nix packages and nixos modules including profiles to easily install featureful Bitcoin nodes.
Work in progress.

Profiles
---
`nix-bitcoin.nix` provides the two profiles "minimal" and "all":

* minimal
    * bitcoind (pruned) with outbound connections through Tor and inbound connections through a hidden
      service
    * [clightning](https://github.com/ElementsProject/lightning) with outbound connections through Tor, not listening
    * includes "nodeinfo" script which prints basic info about the node
    * adds non-root user "operator" which has access to bitcoin-cli and lightning-cli
* all
    * adds clightning hidden service
    * [liquid-daemon](https://github.com/blockstream/liquid)
    * [lightning charge](https://github.com/ElementsProject/lightning-charge)
    * [nanopos](https://github.com/ElementsProject/nanopos)
    * adds an index page using nginx to display node information and link to nanopos
    * [spark-wallet](https://github.com/shesek/spark-wallet)
        * Notes: run `nodeinfo` to get its onion address and `systemctl status spark-wallet` to get the access key.
            When entering the onion address on the Android app don't forgot to prepend "http://"

The data directories can be found in `/var/lib`.

Installing profiles
---
The easiest way is to run `nix-shell env.nix` and then create a [nixops](https://nixos.org/nixops/manual/) deployment with the provided network.nix.
Fix the FIXMEs in configuration.nix and deploy with nixops in nix-shell.

The "all" profile requires 15 GB of disk space and 2GB of memory.

Tutorial: install a nix-bitcoin node on Debian 9 Stretch in a VirtualBox
---

Install Dependencies
```
sudo apt-get install curl git gnupg2 dirmngr
```
Install Latest Nix with GPG Verification
```
curl -o install-nix-2.1.3 https://nixos.org/nix/install
curl -o install-nix-2.1.3.sig https://nixos.org/nix/install.sig
gpg2 --recv-keys B541D55301270E0BCF15CA5D8170B4726D7198DE
gpg2 --verify ./install-nix-2.1.3.sig
sh ./install-nix-2.1.3
. /home/user/.nix-profile/etc/profile.d/nix.sh
```
Add virtualbox.list to /etc/apt/sources.list.d
```
deb http://download.virtualbox.org/virtualbox/debian stretch contrib
```
Add Oracle VirtualBox public key
```
wget https://www.virtualbox.org/download/oracle_vbox_2016.asc
gpg2 oracle_vbox_2016.asc
```
Proceed _only_ if fingerprint reads B9F8 D658 297A F3EF C18D  5CDF A2F6 83C5 2980 AECF

```
sudo apt-key add oracle_vbox_2016.asc
```
Install virtualbox-5.2
```
sudo apt-get update
sudo apt-get install virtualbox-5.2
```

Create Host Adapter in VirtualBox
```
Open VirtualBox
File -> Host Network Manager -> Create
This should create a hostadapter named vboxnet0
```
Clone this project
```
cd
git clone https://github.com/jonasnick/nix-bitcoin
cd ~/nix-bitcoin
```
Setup environment
```
nix-shell env.nix
```
Create nixops deployment in nix-shell
```
nixops create network.nix network-vbox.nix -d bitcoin-node
```
Adjust configuration
Open configuration.nix and remove FIXMEs.
No custom boot options or hardware configuration is needed for a VM install.

Deploy Nixops in nix-shell
```
nixops deploy -d bitcoin-node
```
This will now create a nix-bitcoin node in a VirtualBox on your computer.

Nixops automatically creates a ssh key and adds it to your computer.

Access `bitcoin-node` through ssh in nix-shell.

```
nixops ssh operator@bitcoin-node
```

FAQ
---
* **Q:** When deploying or trying to SSH into the machine I see
    ```
    bitcoin-node> waiting for SSH...
    Received disconnect from 10.1.1.200 port 22:2: Too many authentication failures
    ```
    * **A:** Somehow ssh-agent and nixops don't play well together (see also https://github.com/NixOS/nixops/issues/256), if you have a few keys already added to your ssh-agent. Killing and restarting the ssh-agent should fix the problem. Also make sure you don't have something like
    ```
    Host *
        PubkeyAuthentication no
    ```
    in your ssh config.
* **Q:** When deploying to virtualbox for the first time I see
    ```
    bitcoin-node> Mar 19 09:22:27 bitcoin-node systemd[1]: Started Get NixOps SSH Key.
    bitcoin-node> Mar 19 09:22:27 bitcoin-node get-vbox-nixops-client-key-start[2226]: VBoxControl: error: Failed to connect to the guest property service, error VERR_INTERNAL_ERROR
    bitcoin-node> Mar 19 09:22:27 bitcoin-node systemd[1]: get-vbox-nixops-client-key.service: Main process exited, code=exited, status=1/FAILURE
    bitcoin-node> Mar 19 09:22:27 bitcoin-node systemd[1]: get-vbox-nixops-client-key.service: Failed with result 'exit-code'.
    bitcoin-node> error: Traceback (most recent call last):
      File "/nix/store/6zyvpi0q6mvprycadz2dpdqag4742y18-python2.7-nixops-1.6pre0_abcdef/lib/python2.7/site-packages/nixops/deployment.py", line 731, in worker
        raise Exception("unable to activate new configuration")
    Exception: unable to activate new configuration
    ```
    * **A:** This is issue https://github.com/NixOS/nixops/issues/908. The machine needs to be rebooted. You can do that by running `nixops deploy` with the `--force-reboot` flag once.
* **Q:** I'm deploying to virtualbox it's not able to connect anymore.
    * **A:** Maybe the IP address of the box changed. Run `nixops deploy --check` to update nixops with the new IP address.
* **Q:** The clightning service is running but when I try to use it (f.e. by running `lightning-cli getinfo` as user operator) all I get is `lightning-cli: Connecting to 'lightning-rpc': Connection refused`.
    * **A:** Check your clightning logs with `journalctl -eu clightning`. Do you see something like `bitcoin-cli getblock ... false` failed? Are you using pruned mode? That means that clightning hasn't seen all the blocks it needs to and it can't get that block because your node is pruned. If you're just setting up a new node you can `systemctl stop clightning` and wipe your `/var/lib/clightning` directory. Otherwise you need to reindex the Bitcoin node.
* **Q:** My disk space is getting low due to nix.
    * **A:** run `nix-collect-garbage -d`
