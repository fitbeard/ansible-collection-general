resolv
===============================

Ansible role to configure resolv.conf and hosts.

Role Variables
--------------

```yaml
# set custom nameservers in /etc/resolv.conf
resolv_nameservers:
  - 8.8.8.8
  - 1.1.1.1

# set custom records in /etc/hosts
resolv_records:
  - 127.0.0.1 home home.domain
```

Dependencies
------------

None

License
-------

Tool under the BSD license. Do not hesitate to report bugs, ask some
questions or do some pull request if you want to!
