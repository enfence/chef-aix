# chef-aix

Resources, specific for IBM AIX

## Supported Platforms

* AIX 6.1
* AIX 7.1

### aix_user

Manage users in AIX-way, using mkuser, chuser, rmuser commands. It allows to
use AIX-specific attributes, such as rlogin, login, loginretries, and so on.

Usage 1:

```ruby
aix_user 'myuser' do
  id 666
  pgrp 'staff'
  home '/home/myuser'
  shell '/usr/bin/ksh'
  rlogin true
  login false
  account_locked false
  rss -1
  nofiles -1
  stack -1
  cpu -1
  password 'abc123'
end
```

Usage 2:

```ruby
user 'myotheruser' do
  provider Chef::Provider::User::AixUser
  id 667
  pgrp 'staff'
  home '/home/myotheruser'
  password '123abc'
end
```

### aix_group

Manage groups in AIX-way, using mkgroup, chgroup, rmgroup commands. It allows
to use AIX-specific attributes.

Usage 1:

```ruby
aix_group 'staff' do
  gid 1
end
```

Usage 2:

```ruby
group 'bin' do
  provider Chef::Provider::Group::AixGroup
  id 123
end
```

### aix_package

Manage AIX packages - BFFs, RPMs and eFixes (PTFs). As a source
the folllowing can be specified:

   * Web-Server (http://, https://)
   * FTP-Server (ftp://)
   * NIM LPP source

If the package name ends with .rpm it is assumed to be an RPM package.
If the package name ends with .epkg.Z it is assumed to be an emgr eFix.
If the package name ends with .bff, or the source for the package is
a file or directory, existing on the server, it is assumed to be an LPP
package. 
Otherwise the source assumed to be an LPP source from a NIM server and
the package will be installed using nimclient command.

You can change the detection procedure, if you specify 'type' attribute
for the package resource. The following types are defined:

    * rpm - RPM package
    * emgr - emgr eFix (PTF)
    * installp - LPP/BFF package
    * nimclient - Package, located on a NIM server

During installation of efixes the old efixes are automatically removed.
The same procedure is during updating of LPP packages - if the previous
version of the package is locked by some efix, the provider removes it
first and then install the new version of the package.

Usage examples:

```ruby
aix_package 'openssh.base.server' do
  source '/path/to/openssh/6.0.0.6201'
  action :install
end
```

```ruby
aix_package 'prce' do
  source '/path/to/perzl/rpms/pcre-8.35-1.aix5.1.ppc.rpm'
  action :install
end
```

```ruby
aix_package 'IV75570' do
  source '/path/to/openssl/fix14/IV75570m9a.150729.epkg.Z'
  action :install
end
```

```ruby
package 'chef' do
  provider Chef::Provider::Package::AixPackage
  source 'http://myserver/chef/chef-12.9.38-1.powerpc.bff'
  action :install
end
```

```ruby
# I don't want to see this stuff on my servers
package 'DirectorPlatformAgent' do
  provider Chef::Provider::Package::AixPackage
  action :remove
end
```
