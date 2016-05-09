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

require 'chef/mixin/shell_out'
require 'chef/provider/group'

class Chef
  class Provider
    class Group
      # AixGroup Resource Provider for AIX 6.1/7.1/7.2
      # can be used in two ways:
      # aix_group 'groupname' do
      #   AIX-specific attributes
      # end
      # or:
      # group 'groupname' do
      #   provider Chef::Provider::Group::AixGroup
      #   AIX-specific attributes
      # end
      # the list of the attributes can be seen in resource definition
      class AixGroup < Chef::Provider::Group
        include Chef::Mixin::ShellOut

        COMMANDS = {
          chgroup: '/usr/bin/chgroup',
          lsgroup: '/usr/sbin/lsgroup',
          rmgroup: '/usr/sbin/rmgroup',
          mkgroup: '/usr/bin/mkgroup',
          chgrpmem: '/usr/bin/chgrpmem'
        }.freeze

        provides :group, platform: %w(aix)
        provides :aix_group, platform: %w(aix)

        def initialize(new_resource, run_context)
          super
          @group_exists = false
        end

        def define_resource_requirements
          super

          requirements.assert(:all_actions) do |a|
            a.assertion { check_aix_version? }
            a.failure_message(Chef::Exceptions::UnsupportedPlatform,
                              'Chef::Provider::Group::AixGroup supports only'\
                              ' AIX version 6.1 and above')
          end

          COMMANDS.each do |_, c|
            requirements.assert(:all_actions) do |a|
              a.assertion { ::File.exist?(c) }
              a.failure_message(Chef::Exceptions::FileNotFound,
                                "Cannot find #{c} on the system")
            end
          end
        end

        def load_current_resource
          @current_resource = Chef::Resource::AixGroup.new(
            @new_resource.group_name)
          @current_resource.group_name(@new_resource.group_name)

          ls = shell_out(
            "#{COMMANDS[:lsgroup]} -C #{current_resource.group_name}")
          if ls.exitstatus == 0
            names = ls.stdout.split("\n")[0].split(':')
            values = ls.stdout.split("\n")[1].split(':')
            names.each_with_index do |name, ndx|
              name.gsub!(/^#/, '')
              if @current_resource.respond_to?(name.to_sym)
                v = if values[ndx] == 'true' || values[ndx] == 'false'
                      (values[ndx] == 'true')
                    else
                      values[ndx]
                    end
                begin
                  a = @current_resource.send(name.to_sym)
                  v = v.split(',') if a.class == Array
                  Chef::Log.debug("@current_resource.#{name} <= #{v}")
                  @current_resource.send(name.to_sym, v) unless v.to_s.empty?
                rescue Chef::Exceptions::ValidationFailed => e
                  Chef::Log.debug(e)
                end
              else
                Chef::Log.warn("Unknown method #{name}")
              end
              @group_exists = true
            end
          end
          @current_resource
        end

        def create_group
          rc = run(COMMANDS[:mkgroup])
          raise "Error creating group: #{rc}" unless rc == 0
          modify_group_members
        end

        def manage_group
          rc = run(COMMANDS[:chgroup])
          raise "Error creating group: #{rc}" unless rc == 0
          modify_group_members
        end

        def remove_group
          shell_out("#{COMMANDS[:rmgroup]} -R #{@new_resource.registry}"\
                    "#{@new_resource.group_name}")
        end

        def compare_group
          @change_desc = []
          @changed = []
          attr_names.each do |name|
            nr = @new_resource.send(name)
            cr = @current_resource.send(name)
            next if nr.nil?
            next if name == 'users'
            if nr.is_a?(Array)
              next if nr.empty?
            end
            if nr.to_s != cr.to_s
              @changed << name
              @change_desc << "change property #{name} to #{nr}"
            end
          end
          Chef::Log.debug("Changed properties = #{@changed}")
          @changed.any? || compare_group_members
        end

        protected

        def compare_group_members
          @users_to_remove = []
          unless @group_exists
            @users_to_add = @new_resource.members
            return
          end
          @users_to_add = @new_resource.members - @current_resource.members
          if @new_resource.append
            @users_to_remove = @current_resource.members -
                               (@current_resource.members -
                               @new_resource.excluded_members)
          else
            @users_to_remove = @current_resource.members -
                               @new_resource.members unless
                               @new_resource.members.empty?
          end
          Chef::Log.debug("New users to group: #{@users_to_add}")
          Chef::Log.debug("Users to remove from group: #{@users_to_remove}")
          @users_to_remove.any? || @users_to_add.any?
        end

        def modify_group_members
          Chef::Log.debug('modify_group_members')
          return if @new_resource.members.empty? &&
                    @new_resource.excluded_members.empty?
          compare_group_members if @users_to_remove.nil? || @users_to_add.nil?
          return if @users_to_remove.empty? && @users_to_add.empty?
          unless @users_to_add.empty?
            c = "#{COMMANDS[:chgrpmem]} -R #{@new_resource.registry}"\
                " -m + #{@users_to_add.join(',')} #{@new_resource.group_name}"
            Chef::Log.warn("cmd = #{c}")
            rc = shell_out(c)
            unless @new_resource.ignore_failures
              raise "Error changing group membership #{rc.exitstatus}" unless
                rc.exitstatus == 0
            end
          end
          unless @users_to_remove.empty?
            c = "#{COMMANDS[:chgrpmem]} -R #{@new_resource.registry}"\
                " -m - #{@users_to_remove.join(',')}"\
                " #{@new_resource.group_name}"
            Chef::Log.warn("cmd = #{c}")
            rc = shell_out(c)
            unless @new_resource.ignore_failures
              raise "Error changing group membership #{rc.exitstatus}" unless
                rc.exitstatus == 0
            end
          end
        end

        def run(command)
          return 0 if cmd.nil? || cmd.empty?
          c = "#{command} -R #{@new_resource.registry}#{cmd}"\
              " #{@new_resource.group_name}"
          Chef::Log.warn("cmd = #{c}")
          rc = shell_out(c)
          Chef::Log.warn("rc = #{rc.exitstatus}")
          rc.exitstatus
        end

        def cmd
          cmd = ''
          compare_group
          @changed.each do |name|
            v = @new_resource.send(name)
            next if name == 'name'
            next if v.nil?
            if v.is_a?(Array)
              next if v.empty?
              cmd += " #{name}=#{v.join(',')}"
            else
              cmd += " #{name}=#{v}"
            end
          end
          cmd
        end

        def attr_names
          %w(name,
             id,
             admin,
             registry,
             adms,
             dce_export,
             efs_initialks_mode,
             efs_keystore_access,
             efs_keystore_algo, projects
            )
        end

        def aix_version
          node['os_version'].to_s
        end

        def check_aix_version?
          aix_version.start_with?('6', '7')
        end
      end
    end
  end
end
