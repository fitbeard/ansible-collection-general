
packages
===============================

Ansible role that installs and upgrades packages on Linux.

Role Variables
--------------

```yaml
# packages will be merged along with the default packages by OS. See `/vars` directory.
packages_all: |
  {{
    packages_defaults +
    packages_custom
  }}
```

```yaml
# packages are set with:
packages_custom:
  - htop
```

To reboot, set `reboot_required` variable to `true`. To upgrade, set `upgrade_required` variable to `true`.

Dependencies
------------

None

License
-------

Tool under the BSD license. Do not hesitate to report bugs, ask some
questions or do some pull request if you want to!
