=====
MEVR
=====

Bash script allowing you to exit through multiple VPN tunnels (which can be grouped).

------
Usage
------

```./mevr.sh up [fast|fast-nocache] [noisemaker]|down|heartbeat|cycle|watchdog```

----------------
Mini setup & howto
----------------

1. Clone this repo.

2. Get your openvpn config files and their dependencies (certs, authentication configs, etc) into `config/vpn/$group` folders.

3. Configure your groups according to examples provided.

4. Run `install-debian.sh` or don't - just make sure you have dependencies ready.

5. `./mevr.sh up` fast or `./mevr.sh watchdog&`

6. Check `ifconfig`/`ps` if the tunnels are there

7. Enjoy your multiple vpn exits.
