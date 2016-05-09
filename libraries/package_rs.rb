#
# Author:: Andrey Klyachkin <andrey.klyachkin@enfence.com>
# Copyright:: Copyright 2016, eNFence GmbH
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'chef/resource/package'

class Chef
  class Resource
    # Package resource for AIX 6.1/7.1
    class AixPackage < Chef::Resource::Package
      resource_name :aix_package
      provides :package, platform: %w(aix)
      default_action :install
      allowed_actions :install, :upgrade, :remove, :purge, :check

      identity_attr :package_name

      property :version,         kind_of: String
      property :options,         kind_of: String
      property :source,          kind_of: String
      property :type,            kind_of: String
      property :allow_downgrade, kind_of: [TrueClass, FalseClass], default: false
      property :only_apply,      kind_of: [TrueClass, FalseClass]

      ####
      property :realsrc,         kind_of: String
      property :locked,          kind_of: [TrueClass, FalseClass]
      property :description,     kind_of: String
      property :state,           kind_of: String
      property :install_path,    kind_of: String
      property :builddate,       kind_of: String
    end
  end
end
