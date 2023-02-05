
repos
===============================

Ansible role that installs and configures package repositories on rpm Linux distros.

Role Variables
--------------

```yaml
# set to enable and install certain repositories.
# powertools subrepo is expressed as any other repo in repos_enabled, just without configuration.
repos_enabled:
  - epel
  - powertools
```

```yaml
repos:
  epel:
    gpgkey: https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-{{ ansible_distribution_major_version }}
    rpm: https://dl.fedoraproject.org/pub/epel/epel-release-latest-{{ ansible_distribution_major_version }}.noarch.rpm
```

```yaml
# add "custom" repo to repos_enabled variable, and fill repo information as follows:
repos_enabled:
  - custom
```

```yaml
repos_custom:
  otherrepo1:
    gpgkey: https://someother.key/location1
    baseurl: https://someotherbaseurl1/
    enabled: yes
    state: present
    description: Other repo1
  otherrepo2:
    gpgkey: https://someother.key/location2
    baseurl: https://someotherbaseurl2/
    enabled: yes
    state: absent
    description: Other repo2
```

Dependencies
------------

None

License
-------

Tool under the BSD license. Do not hesitate to report bugs, ask some
questions or do some pull request if you want to!
