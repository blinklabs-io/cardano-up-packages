# cardano-up-packages
Package repository for cardano-up Cardano services manager

## Version Maintenance

To validate that package filenames and versions match:

```bash
./scripts/validate-versions.sh
```

To create a new package version from the latest existing version:

```bash
./scripts/add-version.sh cardano-node 11.2.0
```
