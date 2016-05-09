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

require 'chef/resource/user'

class Chef
  class Resource
    # User Resource for AIX 6.1/7.1/7.2
    # the usual way to use is:
    # aix_user 'username' do
    #   AIX-specific attributes
    # end
    # Please note, that Chef's default `user` resource uses encrypted
    # password. The resource aix_user uses plain-text password!
    class AixUser < Chef::Resource::User
      resource_name :aix_user
      provides :user, platform: %w(aix)
      default_action :create
      allowed_actions :create, :remove, :modify, :manage, :lock, :unlock

      identity_attr :username

      property :pgrp,                        kind_of: String
      property :groups,                      kind_of: [String, Array]
      property :auditclasses,                kind_of: String
      property :login,                       kind_of: [TrueClass, FalseClass]
      property :rlogin,                      kind_of: [TrueClass, FalseClass]
      property :telnet,                      kind_of: [TrueClass, FalseClass]
      property :su,                          kind_of: [TrueClass, FalseClass]
      property :daemon,                      kind_of: [TrueClass, FalseClass]
      property :admin,                       kind_of: [TrueClass, FalseClass]
      property :sugroups,                    kind_of: String
      property :admgroups,                   kind_of: String
      property :tpath,                       kind_of: String
      property :ttys,                        kind_of: String
      property :auth1,                       kind_of: String
      property :auth2,                       kind_of: String
      property :registry,                    kind_of: String
      property :SYSTEM,                      kind_of: String
      property :umask,                       kind_of: [String, Integer]
      property :logintimes,                  kind_of: String
      property :account_locked,              kind_of: [TrueClass, FalseClass]
      property :expires,                     kind_of: [String, Integer]
      property :loginretries,                kind_of: [String, Integer]
      property :pwdwarntime,                 kind_of: [String, Integer]
      property :minage,                      kind_of: [String, Integer]
      property :maxage,                      kind_of: [String, Integer]
      property :maxexpired,                  kind_of: [String, Integer]
      property :minalpha,                    kind_of: [String, Integer]
      property :minloweralpha,               kind_of: [String, Integer]
      property :minupperalpha,               kind_of: [String, Integer]
      property :minother,                    kind_of: [String, Integer]
      property :mindigit,                    kind_of: [String, Integer]
      property :minspecialchar,              kind_of: [String, Integer]
      property :mindiff,                     kind_of: [String, Integer]
      property :maxrepeats,                  kind_of: [String, Integer]
      property :minlen,                      kind_of: [String, Integer]
      property :histexpire,                  kind_of: [String, Integer]
      property :histsize,                    kind_of: [String, Integer]
      property :pwdchecks,                   kind_of: String
      property :dictionlist,                 kind_of: String
      property :default_roles,               kind_of: String
      property :roles,                       kind_of: String
      property :domains,                     kind_of: String
      property :fsize,                       kind_of: [String, Integer]
      property :fsize_hard,                  kind_of: [String, Integer]
      property :cpu,                         kind_of: [String, Integer]
      property :cpu_hard,                    kind_of: [String, Integer]
      property :data,                        kind_of: [String, Integer]
      property :data_hard,                   kind_of: [String, Integer]
      property :stack,                       kind_of: [String, Integer]
      property :stack_hard,                  kind_of: [String, Integer]
      property :core,                        kind_of: [String, Integer]
      property :core_hard,                   kind_of: [String, Integer]
      property :core_compress,               kind_of: [TrueClass, FalseClass]
      property :core_naming,                 kind_of: String
      property :core_name,                   kind_of: String
      property :core_path,                   kind_of: String
      property :core_pathname,               kind_of: String
      property :rss,                         kind_of: [String, Integer]
      property :rss_hard,                    kind_of: [String, Integer]
      property :nofiles,                     kind_of: [String, Integer]
      property :nofiles_hard,                kind_of: [String, Integer]
      property :nproc,                       kind_of: [String, Integer]
      property :nproc_hard,                  kind_of: [String, Integer]
      property :threads,                     kind_of: [String, Integer]
      property :threads_hard,                kind_of: [String, Integer]
      property :capabilities,                kind_of: String
      property :dce_export,                  kind_of: [TrueClass, FalseClass]
      property :maxulogs,                    kind_of: [String, Integer]
      property :uactivity,                   kind_of: String
      property :projects,                    kind_of: String
      property :rcmds,                       kind_of: String
      property :sysenv,                      kind_of: String
      property :usrenv,                      kind_of: String
      property :efs_keystore_access,         kind_of: String
      property :efs_adminks_access,          kind_of: String
      property :efs_initialks_mode,          kind_of: String
      property :efs_allowksmodechangebyuser, kind_of: String
      property :efs_keystore_algo,           kind_of: String
      property :efs_file_algo,               kind_of: String
      property :minsl,                       kind_of: String
      property :maxsl,                       kind_of: String
      property :defsl,                       kind_of: String
      property :mintl,                       kind_of: String
      property :maxtl,                       kind_of: String
      property :deftl,                       kind_of: String
      property :auth_name,                   kind_of: String
      property :auth_domain,                 kind_of: String
      property :hostsallowedlogin,           kind_of: String
      property :hostsdeniedlogin,            kind_of: String
      property :unsuccessful_login_count,    kind_of: [String, Integer]
      property :l_level,                     kind_of: String
      property :u_level,                     kind_of: String
      property :d_level,                     kind_of: String
      property :prompt_mac,                  kind_of: String

      alias id uid
      alias gecos comment
    end
  end
end
