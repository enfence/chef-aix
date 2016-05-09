issues_url 'https://github.com/enfence/chef-aix/issues'
source_url 'https://github.com/enfence/chef-aix'
name 'chef-aix'
maintainer 'Andrey Klyachkin'
maintainer_email 'andrey.klyachkin@enfence.com'
license 'Apache 2.0'
description 'Some useful resources for IBM AIX'
long_description 'Functions, libraries, resources to configure AIX'
version '0.1.0'
chef_version '~>12'
supports 'aix', '>= 6.1'

provides 'aix_group'
provides 'aix_package'
provides 'aix_user'