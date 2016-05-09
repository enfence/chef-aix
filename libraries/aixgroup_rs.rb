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

require 'chef/resource/group'

class Chef
  class Resource
    # Group Resource for AIX 6.1/7.1/7.2
    # the usual way to use is:
    # aix_group 'groupname' do
    #   AIX-specific attributes
    # end
    class AixGroup < Chef::Resource::Group
      resource_name :aix_group
      provides :group, platform: %w(aix)
      default_action :create
      allowed_actions :create, :remove, :modify, :manage

      identity_attr :group_name

      property :gid,                         kind_of: [String, Integer]
      property :admin,                       kind_of: [TrueClass, FalseClass]
      property :users,                       kind_of: Array, default: []
      property :registry,                    kind_of: String, default: 'files'

      property :adms,                        kind_of: String
      property :dce_export,                  kind_of: [TrueClass, FalseClass]
      property :efs_initialks_mode,          kind_of: String
      property :efs_keystore_access,         kind_of: String
      property :efs_keystore_algo,           kind_of: String
      property :projects,                    kind_of: String

      property :append,                      kind_of: [TrueClass, FalseClass]
      property :excluded_members,            kind_of: Array, default: []
      property :ignore_failures,             kind_of: [TrueClass, FalseClass]
      property :non_unique,                  kind_of: [FalseClass]

      alias id gid
      alias members users
    end
  end
end
