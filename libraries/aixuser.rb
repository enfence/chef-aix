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
require 'chef/provider/user'

class Chef
  class Provider
    class User
      # AixUser Resource Provider for AIX 6.1/7.1/7.2
      # can be used in two ways:
      # aix_user 'username' do
      #   AIX-specific attributes
      # end
      # or:
      # user 'username' do
      #   provider Chef::Provider::User::AixUser
      #   AIX-specific attributes
      # end
      # the list of the attributes can be seen in resource definition
      class AixUser < Chef::Provider::User
        include Chef::Mixin::ShellOut

        COMMANDS = {
          chuser: '/usr/bin/chuser',
          lsuser: '/usr/sbin/lsuser',
          rmuser: '/usr/sbin/rmuser',
          mkuser: '/usr/bin/mkuser',
          chpasswd: '/usr/bin/chpasswd'
        }.freeze

        provides :user, platform: %w(aix)
        provides :aix_user, platform: %w(aix)

        def initialize(new_resource, run_context)
          super
          update_attr_names
          @user_exists = false
        end

        def define_resource_requirements
          super

          requirements.assert(:all_actions) do |a|
            a.assertion { check_aix_version? }
            a.failure_message(Chef::Exceptions::UnsupportedPlatform,
                              'Chef::Provider::User::AixUser only supports '\
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
          @current_resource =
            Chef::Resource::AixUser.new(@new_resource.username)
          @current_resource.username(@new_resource.username)

          ls = shell_out("#{COMMANDS[:lsuser]} -c #{current_resource.username}")
          if ls.exitstatus == 0
            names = ls.stdout.split("\n")[0].split(':')
            values = ls.stdout.split("\n")[1].split(':')
            names.each_with_index do |name, ndx|
              name.gsub!(/^#/, '')
              if @current_resource.respond_to?(name.to_sym)
                Chef::Log.debug("@current_resource.#{name} <= #{values[ndx]}")
                v = if values[ndx] == 'true' || values[ndx] == 'false'
                      (values[ndx] == 'true')
                    else
                      values[ndx]
                    end
                @current_resource.send(name.to_sym, v) unless v.to_s.empty?
              else
                Chef::Log.debug("Unknown method #{name}")
              end
              @user_exists = true
            end
          end
          @current_resource
        end

        def compare_user
          update_attr_names if @attr_names.nil?
          @changed = []
          @attr_names.each do |name|
            next if @new_resource.send(name).nil?
            nr = @new_resource.send(name).to_s
            cr = @current_resource.send(name).to_s
            @changed << name if nr != cr
          end
          Chef::Log.debug("Changed parameters = #{@changed}")
          @changed.any?
        end

        def create_user
          rc = run(COMMANDS[:mkuser])
          rc = chpasswd if rc == 0
          raise "Error creating user: #{rc}" unless rc == 0
        end

        def manage_user
          rc = run(COMMANDS[:chuser])
          rc = chpasswd if rc == 0
          raise "Error changing user: #{rc}" unless rc == 0
        end

        def modify_user
          rc = run(COMMANDS[:chuser])
          rc = chpasswd if rc == 0
          raise "Error changing user: #{rc}" unless rc == 0
        end

        def remove_user
          return unless @user_exists
          c = "#{COMMANDS[:rmuser]} -p #{@new_resource.username}"
          Chef::Log.debug("cmd = #{c}")
          rc = shell_out(c)
          Chef::Log.debug("rc = #{rc.exitstatus}")
          raise "Error removing user: #{rc.exitstatus}" unless
            rc.exitstatus == 0
        end

        def lock_user
          return unless @user_exists
          return if locked?
          @current_resource.account_locked = true if chlock(true) == 0
        end

        def unlock_user
          return unless @user_exists
          return unless locked?
          @current_resource.account_locked = false if chlock(false) == 0
        end

        def check_lock
          locked?
        end

        def locked?
          false unless @user_exists
          @current_resource.account_locked
        end

        protected

        def chlock(status)
          Chef::Log.debug('chlock')
          c = "#{COMMANDS[:chuser]} "\
              "account_locked=#{status}"\
              " #{@new_resource.username}"
          Chef::Log.warn("cmd = #{c}")
          rc = shell_out(c)
          Chef::Log.warn("rc = #{rc.exitstatus}")
          rc.exitstatus
        end

        def chpasswd
          Chef::Log.debug('chpasswd')
          return 0 if @new_resource.password.nil? ||
                      @new_resource.password.empty?
          c = "print -- #{@new_resource.username}:#{@new_resource.password} |"\
              " #{COMMANDS[:chpasswd]} -c"
          Chef::Log.warn("cmd = #{c}")
          rc = shell_out(c)
          Chef::Log.warn("rc = #{rc.exitstatus}")
          rc.exitstatus
        end

        def run(command)
          1 if cmd.nil?
          c = "#{command}#{cmd} #{@new_resource.username}"
          Chef::Log.warn("cmd = #{c}")
          rc = shell_out(c)
          Chef::Log.warn("rc = #{rc.exitstatus}")
          rc.exitstatus
        end

        def cmd
          cmd = ''
          update_attr_names if @attr_names.nil?
          compare_user
          @changed.each do |name|
            # name can't be changed, pgrp & gid are handled separately
            next if name == 'name' || name == 'pgrp' || name == 'gid' ||
                    @new_resource.send(name).nil?

            Chef::Log.debug("Get @new_resource.#{name}")
            v = @new_resource.send(name.to_sym)
            cmd += " #{name}=\"#{v}\""
          end
          if @new_resource.gid.nil?
            cmd += " pgrp=#{@new_resource.pgrp}" unless @new_resource.pgrp.nil?
          else
            v = begin
              if @new_resource.gid.is_a? String
                @new_resource.gid
              else
                Etc.getgrgid(@new_resource.gid).name
              end
            rescue
              nil
            end
            cmd += " pgrp=#{v}" unless v.nil?
          end
          cmd
        end

        def update_attr_names
          @attr_names = []
          ls = shell_out("#{COMMANDS[:lsuser]} -c root")
          if ls.exitstatus == 0
            ls.stdout.split("\n")[0].split(':').each do |name|
              name.gsub!(/^#/, '')
              next unless @new_resource.respond_to?(name.to_sym)
              @attr_names << name
            end
          end
          @attr_names
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
