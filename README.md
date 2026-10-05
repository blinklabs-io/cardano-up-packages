# cardano-up-packages
Package repository for cardano-up Cardano services manager

## Version Maintenance

To check for upstream updates and create new package versions locally, run:

```bash
./scripts/check-versions.sh
```

To validate that package filenames and versions match:

```bash
./scripts/validate-versions.sh
```

To add a specific package version:

```bash
./scripts/add-version.sh cardano-node 10.6.2
```

You can also use the Makefile targets:

```bash
make check-versions
make validate-versions
make add-version PACKAGE=cardano-node VERSION=10.6.2
```
