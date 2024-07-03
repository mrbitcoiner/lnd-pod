# LND POD
## Containerized LND from source
---
* build image
```bash
./control.sh build
```

* start
```bash
./control.sh up
```

* stop
```bash
./control.sh down
```

* create systemd unit
```bash
./control.sh mk-systemd
```

* remove systemd unit
```bash
./control.sh rm-systemd
```

* run lncli commands
```bash
./control.sh lncli 'getinfo'
```
