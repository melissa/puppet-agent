component "marionette-collective" do |pkg, settings, platform|
  #pkg.load_from_json("configs/components/marionette-collective.json")

  pkg.build_requires "ruby"
  pkg.build_requires "ruby-stomp"

  # Here we replace and provide mcollective 3 to ensure that even as we continue
  # to release 2.x versions of mcollective upgrades to puppet-agent will be clean
  pkg.replaces 'mcollective', '3.0.0'
  pkg.replaces 'mcollective-common', '3.0.0'
  pkg.replaces 'mcollective-client', '3.0.0'

  pkg.provides 'mcollective', '3.0.0'
  pkg.provides 'mcollective-common', '3.0.0'
  pkg.provides 'mcollective-client', '3.0.0'

  pkg.replaces 'pe-mcollective'
  pkg.replaces 'pe-mcollective-common'
  pkg.replaces 'pe-mcollective-client'

  if platform.is_deb?
    pkg.replaces 'mcollective-doc'
  end

  case platform.servicetype
  when "systemd"
    pkg.install_service "ext/aio/redhat/mcollective.service", "ext/aio/redhat/mcollective.sysconfig", "mcollective"
    pkg.install_file "ext/aio/redhat/mcollective-systemd.logrotate", "/etc/logrotate.d/mcollective"
  when "sysv"
    if platform.is_deb?
      pkg.install_service "ext/aio/debian/mcollective.init", "ext/aio/debian/mcollective.default", "mcollective"
    elsif platform.is_sles?
      pkg.install_service "ext/aio/suse/mcollective.init", "ext/aio/redhat/mcollective.sysconfig", "mcollective"
    elsif platform.is_rpm?
      pkg.install_service "ext/aio/redhat/mcollective.init", "ext/aio/redhat/mcollective.sysconfig", "mcollective"
    end
    if platform.is_rpm?
      puppet_bin = "/opt/puppetlabs/bin/puppet"
      rpm_statedir = "%{_localstatedir}/lib/rpm-state/#{pkg.get_name}"
      service_statefile = "#{rpm_statedir}/service.pp"
      pkg.add_preinstall_action ["upgrade"],
        [<<-HERE.undent
          install --owner root --mode 0700 --directory #{rpm_statedir} || :
          if [ -x #{puppet_bin} ] ; then
            #{puppet_bin} resource service mcollective > #{service_statefile} || :
          fi
          HERE
        ]

      pkg.add_postinstall_action ["upgrade"],
        [<<-HERE.undent
          if [ -f #{service_statefile} ] ; then
            #{puppet_bin} apply #{service_statefile} > /dev/null 2>&1 || :
            rm -rf #{rpm_statedir} || :
          fi
          HERE
        ]
    end

    pkg.install_file "ext/aio/redhat/mcollective-sysv.logrotate", "/etc/logrotate.d/mcollective"

  when "launchd"
    pkg.install_service "ext/aio/osx/mcollective.plist", nil, "com.puppetlabs.mcollective"
  when "smf"
    pkg.install_service "ext/aio/solaris/smf/mcollective.xml", nil, "mcollective", service_type: "network"
  when "aix"
    pkg.install_service "resources/aix/mcollective.service", nil, "mcollective"
  when "windows"
    service_hash = [{
      :directory_ref => settings[:bindir_id],
      :id => "MCOService",
      :guid => "7601FCEA-90B3-CC69-6A69-4087FBC7292D",
      :win64 => settings[:win64],
      :file => {
        :id => "RubyWExe",
        :source => settings[:rubyw],
      },
      # This service is installed with start set to demand because
      # it won't be correctly configured to start right away. The
      # puppet run that configures mcollective will allow it to start
      # and set it to automatic
      :serviceinstall => {
        :id => "MCOServiceInstaller",
        :description => "Puppet Labs server orchestration framework",
        :displayname => "Marionette Collective Server",
        :name => "mcollective",
        :start => "demand",
        :arguments => '-I&quot;[INSTALLDIR]\\lib&quot; -rubygems &quot;[INSTALLDIR]\\bin\\mcollectived&quot; --daemonize',
      },
      :servicecontrol => {
        :id => "MCOStartService",
        :name => "mcollective",
      },
    }]
    pkg.install_service nil, service_hash: service_hash
  else
    fail "need to know where to put service files"
  end

  if platform.is_windows?
    extra_flags = "--no-service-files"
  end

  #pkg.install do
  #  ["#{settings[:host_ruby]} install.rb \
  #      --ruby=#{File.join(settings[:bindir], 'ruby')} \
  #      --bindir=#{settings[:bindir]} \
  #      --configdir=#{File.join(settings[:sysconfdir], 'mcollective')} \
  #      --sitelibdir=#{settings[:ruby_vendordir]} \
  #      --quick \
  #      --sbindir=#{settings[:bindir]} \
  #      --plugindir=#{File.join(settings[:install_root], 'mcollective', 'plugins')} \
  #      #{extra_flags}"]
  #end

  pkg.directory File.join(settings[:sysconfdir], "mcollective")
  pkg.directory File.join(settings[:install_root], 'mcollective')
  pkg.directory File.join(settings[:install_root], 'mcollective', 'plugins')

  # Bring in the client.cfg and server.cfg from ext/aio.
  #pkg.install_file "ext/aio/common/client.cfg.dist", File.join(settings[:sysconfdir], 'mcollective', 'client.cfg')
  #pkg.install_file "ext/aio/common/server.cfg.dist", File.join(settings[:sysconfdir], 'mcollective', 'server.cfg')

  pkg.configfile File.join(settings[:sysconfdir], 'mcollective', 'client.cfg')
  pkg.configfile File.join(settings[:sysconfdir], 'mcollective', 'server.cfg')
  pkg.configfile File.join(settings[:sysconfdir], 'mcollective', 'facts.yaml')
  pkg.configfile "/etc/logrotate.d/mcollective" if platform.is_linux?

  pkg.link "#{settings[:bindir]}/mco", "#{settings[:link_bindir]}/mco" unless platform.is_windows?
end
