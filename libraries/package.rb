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

require 'chef/provider/package'
require 'chef/mixin/shell_out'

require 'net/ftp'
require 'net/http'
require 'net/https'
require 'tempfile'
require 'uri'

class Chef
  class Provider
    class Package
      # Package class for AIX
      class AixPackage < Chef::Provider::Package
        include Chef::Mixin::ShellOut

        provides :package, platform: %w(aix)
        provides :aix_package, platform: %w(aix)

        COMMANDS = {
          installp: '/usr/sbin/installp',
          lslpp: '/usr/bin/lslpp',
          emgr: '/usr/sbin/emgr',
          rpm: '/usr/bin/rpm',
          nimclient: '/usr/sbin/nimclient'
        }.freeze

        def initialize(new_resource, run_context)
          super
          @support = []
          COMMANDS.each do |n, c|
            @support << n.to_sym if ::File.exist?(c)
          end
          @pkg_installed = false
          @new_resource.realsrc = real_source?(@new_resource.source)
        end

        def whyrun_supported?
          true
        end

        def define_resource_requirements
          super
          requirements.assert(:all_actions) do |a|
            a.assertion { check_aix_version? }
            a.failure_message(Chef::Exceptions::UnsupportedPlatform,
                              'Chef::Provider::Package::AixPackage only '\
                              'supports AIX 6.1 and above')
          end
        end

        def load_current_resource
          @current_resource =
            Chef::Resource::Package::AixPackage.new(@new_resource.name)
          @current_resource.package_name(@new_resource.package_name)
          @new_resource.type = type? if @new_resource.type.nil?
          @current_resource.type = @new_resource.type
          case @new_resource.type
          when 'rpm'
            lcr_rpm
          when 'emgr'
            lcr_emgr
          when 'installp'
            lcr_lpp
          when 'nimclient'
            lcr_lpp
          when 'none'
            lcr_none
          else
            raise Chef::Exceptions::Package,
                  "Unknown AIX package type #{@new_resource.type}"
          end
          @current_resource
        end

        def candidate_version
          return @candidate_version if @candidate_version
          return nil if @new_resource.source.nil? || @new_resource.realsrc.nil?
          case @new_resource.type
          when 'rpm'
            cv_rpm
          when 'emgr'
            cv_emgr
          when 'installp'
            cv_installp
          when 'nimclient'
            cv_nimclient
          else
            raise Chef::Exceptions::Package,
                  "Unknown AIX package type #{@new_resource.type}"
          end
          unless @current_resource.version.to_s.empty?
            # we have some version installed. check if we have a newer
            # check if candiate_version newer then current_version
            if compare_versions(@candidate_version,
                                @current_resource.version) == -1
              # the newer version is older than current version
              unless @new_resource.allow_downgrade
                # if allow_downgrade is not set, we shouldn't install
                # any package
                @candidate_version = ''
              end
            end
          end
          # if version attr of the new_resource is empty
          # we can install the newest version, we have
          if @new_resource.version.to_s.empty?
            @new_resource.version = @candidate_version
          else
            # if we have a specific version of package
            # either it should be used or nothing
            if @candidate_version.to_s != @new_resource.version.to_s
              @candidate_version = ''
            end
          end
          # if new_resource.version older then current_resource.version
          if compare_versions(@current_resource.version,
                              @new_resource.version) == 1
            unless @new_resource.allow_downgrade
              # if downgrade not allowed, empty version attribute
              @new_resource.version = ''
            end
          end
          Chef::Log.debug("Package #{@current_resource.package_name}")
          Chef::Log.debug("Current version is #{@current_resource.version}")
          Chef::Log.debug("Candidate version is #{@candidate_version}")
          Chef::Log.debug("New resource #{@new_resource.package_name}")
          Chef::Log.debug("Version is #{@new_resource.version}")
          @candidate_version
        end

        def compare_versions(version1, version2)
          if version1.nil?
            return 0 if version2.nil?
            return 1
          end
          return -1 if version2.nil?
          if version1.to_s.empty?
            return 0 if version2.to_s.empty?
            return 1
          end
          return -1 if version2.to_s.empty?
          v1a = version1.to_s.split(/[.-]/)
          v2a = version2.to_s.split(/[.-]/)
          v1a <=> v2a
        end

        def cv_rpm
          rpm = shell_out("#{COMMANDS[:rpm]} -q "\
                          "--queryformat '%{VERSION}-%{RELEASE}\n'"\
                          " -p #{@new_resource.realsrc}")
          Chef::Log.debug("exit code = #{rpm.exitstatus}")
          @candidate_version = rpm.stdout.split("\n")[0] if rpm.exitstatus == 0
        end

        def cv_emgr
          @candidate_version = '1'
        end

        def cv_installp
          inst = shell_out("#{COMMANDS[:installp]} -Ld "\
                           "#{@new_resource.realsrc} | "\
                           "grep ':#{@new_resource.package_name}:'")
          Chef::Log.debug("exit code = #{inst.exitstatus}")
          @candidate_version = inst.stdout.split("\n")[-1].split(':')[2] if
            inst.exitstatus == 0
        end

        def cv_nimclient
          nimcl = shell_out("#{COMMANDS[:nimclient]} -o showres"\
                            " -a installp_flags='-L'"\
                            " -a resource=#{@new_resource.realsrc} |"\
                            " grep ':#{@new_resource.package_name}'")
          Chef::Log.debug("exit code = #{nimcl.exitstatus}")
          Chef::Log.debug(nimcl.stdout)
          Chef::Log.debug(nimcl.stderr)
          @candidate_version = nimcl.stdout.split("\n")[-1].split(':')[2] if
            nimcl.exitstatus == 0
        end

        def install_package(name, version)
          Chef::Log.warn('Chef::Provider::Package::AixPackage install_package')
          r = 0
          case @new_resource.type
          when 'rpm'
            r = install_rpm(name, version)
          when 'emgr'
            r = install_emgr(name, version)
          when 'installp'
            r = install_installp(name, version)
          when 'nimclient'
            r = install_nimclient(name, version)
          else
            raise Chef::Exceptions::Package,
                  "Unknown AIX package type #{@new_resource.type}"
          end
          r
        end

        def install_rpm(_name, _version)
          unless @current_resource.version
            r = shell_out("#{COMMANDS[:rpm]} -i #{@new_resource.options}"\
                      " #{@new_resource.realsrc}")
          else
            if allow_downgrade
              r = shell_out("#{COMMANDS[:rpm]} -U --oldpackage"\
                        " #{@new_resource.realsrc}")
            else
              r = shell_out("#{COMMANDS[:rpm]} -U #{@new_resource.realsrc}")
            end
          end
          r.exitstatus
        end

        def install_emgr(_name, _version)
          unless @current_resource.version
            # first preview installation to find out, if we can install efix
            r = shell_out("#{COMMANDS[:emgr]} -e #{@new_resource.realsrc} -p")
            if r.exitstatus != 0
              # preview was unsuccessful, find out why
              efix2deinstall = []
              r.stderr.lines.each do |line|
                if line.split(' ')[1] == '0645-070'
                  # is blocked by another efix
                  efix2deinstall << line.split(' ')[-1].delete('". ')
                end
              end
              efix2deinstall.uniq!
              # if we don't have anything in efix2deinstall, we have
              # some other problem
              # is not known right now
              if efix2deinstall.empty?
                Chef::Log.warn('emgr is failed and no efixes found'\
                               ' to deinstall')
                Chef::Log.error(r.stderr.lines)
                return r.exitstatus
              end
              Chef::Log.warn('The following efixes will be deinstalled:'\
                             " #{efix2deinstall}")
              efix2deinstall.each do |efix|
                Chef::Log.warn("Deinstalling efix #{efix}")
                r = remove_emgr(efix, '0')
                # return r unless r == 0
              end
              Chef::Log.warn('all efixes are removed from the system')
            end
            Chef::Log.warn("Starting #{COMMANDS[:emgr]} -e"\
                           " #{@new_resource.realsrc}")
            r = shell_out("#{COMMANDS[:emgr]} -e #{@new_resource.realsrc}")
            return r.exitstatus
          end
          0
        end

        def unlock_pkg(name)
          Chef::Log.debug("unlock_pkg(#{name})")
          r = shell_out("#{COMMANDS[:emgr]} -l -v3")
          efixes = []
          if r.exitstatus == 0
            e = ''
            r.stdout.lines do |line|
              e = line.split(' ')[2] if line.start_with?('EFIX LABEL:')
              p = line.split(' ')[1] if line.start_with?('   PACKAGE:')
              efxies << e if p == name
            end
            efixes.uniq!
            Chef::Log.debug("efixes to remove: #{efixes}")
            efixes.each do |fix|
              remove_emgr(fix, '0')
            end
            return 0
          else
            Chef::Log.warn(r.stderr)
            return 1
          end
        end

        def install_installp(name, version)
          Chef::Log.debug('install_installp')
          # if the package already installed, check if it is locked by emgr
          r = 0
          r = unlock_pkg(name) if @pkg_installed && @current_resource.locked
          raise Chef::Exceptions::Package,
                "Package #{name} is locked by emgr" if r != 0
          iflags = '-a'
          iflags += 'c' unless @new_resource.only_apply
          iflags += 'Y'
          iflags += 'g' unless @new_resource.allow_downgrade
          iflags += 'F' if @new_resource.allow_downgrade
          unless @current_resource.version
            r = shell_out("#{COMMANDS[:installp]} #{iflags} "\
                      "#{@new_resource.options} -d #{@new_resource.realsrc}"\
                      " #{name} #{version}")
          else
            if allow_downgrade
              r = shell_out("#{COMMANDS[:installp]} #{iflags} -F "\
                        "#{@new_resource.options} -d #{@new_resource.realsrc}"\
                        " #{name} #{version}")
            else
              r = shell_out("#{COMMANDS[:installp]} #{iflags} "\
                        "#{@new_resource.options} -d #{@new_resource.realsrc}"\
                        " #{name} #{version}")
            end
          end
          Chef::Log.debug(r.stdout)
          Chef::Log.debug(r.stderr)
          r.exitstatus
        end

        def install_nimclient(name, version)
          Chef::Log.debug('install_nimclient')
          # if the package already installed, check if it is locked by emgr
          r = 0
          r = unlock_pkg(name) if @pkg_installed && @current_resource.locked
          raise Chef::Exceptions::Package,
                "Package #{name} is locked by emgr" if r != 0
          iflags = '-a'
          iflags += 'c' unless @new_resource.only_apply
          iflags += 'Y'
          iflags += 'g' unless @new_resource.allow_downgrade
          iflags += 'F' if @new_resource.allow_downgrade
          Chef::Log.debug("allow_downgrade = #{@new_resource.allow_downgrade}")
          r = shell_out("#{COMMANDS[:nimclient]} -o cust "\
                    "-a lpp_source=#{@new_resource.realsrc} "\
                    "-a filesets='#{name} #{version}' "\
                    "-a installp_flags='#{iflags}#{@new_resource.options}'")
          Chef::Log.debug(r.stdout)
          Chef::Log.debug(r.stderr)
          r.exitstatus
        end

        def upgrade_package(_name, _version)
          Chef::Log.warn('Chef::Provider::Package::AixPackage upgrade_package')
        end

        def remove_package(name, version)
          Chef::Log.warn('Chef::Provider::Package::AixPackage remove_package')
          case @new_resource.type
          when 'rpm'
            remove_rpm(name, version)
          when 'emgr'
            remove_emgr(name, version)
          when 'installp'
            remove_installp(name, version)
          when 'nimclient'
            remove_installp(name, version)
          when 'none'
            remove_none(name, version)
          else
            raise Chef::Exceptions::Package,
                  "Unknown AIX package type #{@new_resource.type}"
          end
        end

        def remove_rpm(name, version)
          if version
            shell_out("#{COMMANDS[:rpm]} -e #{@new_resource.options}"\
                      " #{name}-#{version}")
          else
            shell_out("#{COMMANDS[:rpm]} -e --allmatches"\
                      " #{@new_resource.options} #{name}")
          end
        end

        def remove_emgr(name, _version)
          shell_out("#{COMMANDS[:emgr]} -rL #{name}")
        end

        def remove_installp(name, version)
          if version
            shell_out("#{COMMANDS[:installp]} -u #{name} #{version}")
          else
            shell_out("#{COMMANDS[:installp]} -u #{name}")
          end
        end

        def remove_none(name, _version)
          raise Chef::Exceptions::Package,
                "Don't know how to remove package #{name}"
        end

        def purge_package(_name, _version)
          Chef::Log.warn('Chef::Provider::Package::AixPackage purge_package')
        end

        protected

        def lcr_rpm
          rpm = shell_out("#{COMMANDS[:rpm]} -q "\
                          "--queryformat '%{NAME}:%{VERSION}-%{RELEASE}:"\
                          "%{SUMMARY}:%{BUILDTIME}\n'"\
                          " #{@current_resource.package_name}")
          if rpm.exitstatus == 0
            v = rpm.stdout.split("\n")[0].split(':')
            @current_resource.package_name = v[0]
            @current_resource.version = v[1]
            @current_resource.state = 'C' # always commited
            @current_resource.description = v[2]
            @current_resource.locked = false # can't be locked by emgr
            @current_resource.install_path = '/'
            @current_resource.builddate = v[3] # not really
            @pkg_installed = true
          end
          @current_resource
        end

        def lcr_lpp
          lslpp = shell_out("#{COMMANDS[:lslpp]} -Lc"\
                            " #{@current_resource.package_name}")
          if lslpp.exitstatus == 0 && !lslpp.stdout.split("\n")[1].nil?
            v = lslpp.stdout.split("\n")[1].split(':')
            # package name is fileset name.
            # you know, to confuse russians
            @current_resource.package_name = v[1]
            @current_resource.version = v[2]
            @current_resource.state = v[5] # C commited, A applied
            @current_resource.description = v[6]
            @current_resource.locked = v[15] == '1'
            @current_resource.install_path = v[16]
            @current_resource.builddate = v[17]
            @pkg_installed = true
          end
          @current_resource
        end

        def lcr_emgr
          emgr = shell_out("#{COMMANDS[:emgr]} -lL"\
                           " #{@current_resource.package_name} |"\
                           " grep '^[1-9]'")
          if emgr.exitstatus == 0
            v = emgr.stdout.split("\n")[0].split(' ', 6)
            @current_resource.package_name = v[2] # efix label
            @current_resource.version = '1' # what can be version?
            @current_resource.state = v[1]
            @current_resource.description = v[6]
            @current_resource.locked = false
            @current_resource.install_path = '/'
            @current_resource.builddate = v[4] + ' ' + v[5]
            @pkg_installed = true
          end
          @current_resource
        end

        def lcr_none
          # we don't have any type. it is already installed package
          # one of rpm, lpp, emgr
          # try to find
          r = lcr_lpp
          return r if @pkg_installed
          r = lcr_rpm
          return r if @pkg_installed
          r = lcr_emgr
          return r if @pkg_installed
          @current_resource
        end

        def fetch_http(uri)
          return unless uri.scheme == 'http' || uri.scheme == 'https'
          req = Net::HTTP.new(uri.host, uri.port)
          if uri.scheme == 'https'
            req.use_ssl = true
            req.verify_mode = OpenSSL::SSL::VERIFY_NONE
          end
          res = req.get(uri)
          raise Chef::Exceptions::InvalidResourceSpecification,
                "Can't download package #{@new_resource.source}" unless
                res.is_a? Net::HTTPOK
          res.body
        end

        def fetch_ftp(uri)
          return unless uri.scheme == 'ftp'
          req = Net::FTP.new(uri.host, uri.user, uri.password)
          req.login
          res = req.getbinaryfile(uri.path, nil)
          req.close
          res
        end

        def real_source?(source)
          return source if source.nil?
          if source.start_with?('http://', 'https://', 'ftp://')
            # fetch the file
            Chef::Log.warn("Fetching #{source}")
            u = URI.parse(source)
            d = if u.scheme == 'ftp'
                  fetch_ftp(u)
                else
                  fetch_http(u)
                end
            # copy body to a temp file
            f = Tempfile.new(::File.basename(u.path))
            f.write(d)
            f.close
            return f.path
          else
            return source
          end
        end

        def type?
          return @new_resource.type unless @new_resource.type.nil?
          # first - if source begins with http://, https://, ftp://
          # we must download the package
          @new_resource.realsrc = real_source?(@new_resource.source) if
            @new_resource.realsrc.nil?
          # if realsrc still nil, return none - we don't any source
          return 'none' if @new_resource.realsrc.nil?
          # second - if source ends with .rpm it is rpm package and we
          # must have rpm
          if @new_resource.realsrc.end_with?('.rpm')
            @new_resource.type = 'rpm'
            return 'rpm' if @support.include?(:rpm)
            raise Chef::Exceptions::Package,
                  'RPM packages are not supported on the server'
          end
          # third - if source ends with .epkg.Z it is efix and we
          # must have and use emgr to install it
          if @new_resource.realsrc.end_with?('.epkg.Z')
            @new_resource.type = 'emgr'
            return 'emgr' if @support.include?(:emgr)
            raise Chef::Exceptions::Package,
                  'epkg fixes are not supported on the server'
          end
          # forth - if source ends with .bff it is a normal AIX LPP package
          # to install with installp
          if @new_resource.realsrc.end_with?('.bff')
            @new_resource.type = 'installp'
            return 'installp' if @support.include?(:installp)
            raise Chef::Exceptions::Package,
                  'LPP/BFF packages are not supported on the server'
          end
          # if nothing suits, we check if source is a file and try to install
          # it using installp
          if ::File.file?(@new_resource.realsrc) ||
             ::File.directory?(@new_resource.realsrc)
            # assume to be an installp package
            Chef::Log.warn("Assuming #{@new_resource.source} to be"\
                           ' a LPP package/directory')
            @new_resource.type = 'installp'
            return 'installp' if @support.include?(:installp)
            raise Chef::Exceptions::Package,
                  'LPP/BFF packages are not supported on the server'
          end
          # if it is not a file or directory, we assume it is an LPP_SOURCE
          # from NIM server and we must use nimclient to install it
          Chef::Log.warn("Assuming #{@new_resource.source} to be a LPP source")
          @new_resource.type = 'nimclient'
          return 'nimclient' if @support.include?(:nimclient)
          raise Chef::Exceptions::Package,
                'Could not determine the type of '\
                "package #{@new_resource.source}"
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
