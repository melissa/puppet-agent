component "pxp-agent" do |pkg, settings, platform|
  pkg.load_from_json('configs/components/pxp-agent.json')

  toolchain = "-DCMAKE_TOOLCHAIN_FILE=/opt/pl-build-tools/pl-build-toolchain.cmake"
  cmake = "/opt/pl-build-tools/bin/cmake"

  pkg.environment "PATH" => "#{settings[:bindir]}:#{settings[:tools_root]}/bin:$$PATH"

  pkg.build_requires "openssl"

  prefix = settings[:prefix]
  install_root = settings[:install_root]
  make = platform[:make]

  if platform.is_aix?
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/aix/#{platform.os_version}/ppc/pl-gcc-5.2.0-1.aix#{platform.os_version}.ppc.rpm"
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/aix/#{platform.os_version}/ppc/pl-cmake-3.2.3-2.aix#{platform.os_version}.ppc.rpm"
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/aix/#{platform.os_version}/ppc/pl-boost-1.58.0-1.aix#{platform.os_version}.ppc.rpm"
  elsif platform.is_osx?
    cmake = "/usr/local/bin/cmake"
    toolchain = ""
  elsif platform.is_solaris?
    cmake = "/opt/pl-build-tools/i386-pc-solaris2.#{platform.os_version}/bin/cmake"
    toolchain = "-DCMAKE_TOOLCHAIN_FILE=/opt/pl-build-tools/#{settings[:platform_triple]}/pl-build-toolchain.cmake"

    # PCP-87: If we build with -O3, solaris segfaults due to something in std::vector
    special_flags = "-DCMAKE_CXX_FLAGS_RELEASE='-O2 -DNDEBUG'"
  elsif platform.is_windows?
    pkg.build_requires "cmake"
    pkg.build_requires "pl-toolchain-#{platform.architecture}"
    pkg.build_requires "pl-boost-#{platform.architecture}"

    arch = platform.architecture == "x64" ? "64" : "32"
    make = "#{platform.drive_root}/tools/mingw#{arch}/bin/mingw32-make"
    prefix = platform.convert_to_windows_path(settings[:prefix])

    pkg.environment "MAKE" => platform.convert_to_windows_path(make)
    pkg.environment "PATH" => "#{settings[:gcc_bindir]}:#{settings[:tools_root]}/bin:#{settings[:bindir]}:#{platform.drive_root}/Windows/system32:#{platform.drive_root}/Windows:#{platform.drive_root}/Windows/System32/Wbem:#{platform.drive_root}/Windows/System32/WindowsPowerShell/v1.0:#{platform.drive_root}/pstools"
    pkg.environment "CYGWIN" => settings[:cygwin]
    pkg.environment "CC" => settings[:cc]
    pkg.environment "CXX" => settings[:cxx]
    pkg.environment "LDFLAGS" => settings[:ldflags]
    pkg.environment "CFLAGS" => settings[:cflags]

    cmake = "#{platform.drive_root}/ProgramData/chocolatey/bin/cmake.exe -G \"MinGW Makefiles\""
    toolchain = "-DCMAKE_TOOLCHAIN_FILE=#{platform.convert_to_windows_path(settings[:tools_root])}/pl-build-toolchain.cmake"
  else
    pkg.build_requires "pl-gcc"
    pkg.build_requires "pl-cmake"
    pkg.build_requires "pl-boost"
  end

  pkg.configure do
    [
      "#{cmake}\
      #{toolchain} \
          -DCMAKE_VERBOSE_MAKEFILE=ON \
          -DCMAKE_PREFIX_PATH=#{prefix} \
          -DCMAKE_INSTALL_PREFIX=#{prefix} \
          -DCMAKE_SYSTEM_PREFIX_PATH=#{prefix} \
          -DMODULES_INSTALL_PATH=#{File.join(install_root, 'pxp-agent', 'modules')} \
          #{special_flags} \
          -DBOOST_STATIC=ON \
          ."
    ]
  end

  pkg.build do
    ["#{make} -j$(shell expr $(shell #{platform[:num_cores]}) + 1)"]
  end

  pkg.install do
    ["#{make} -j$(shell expr $(shell #{platform[:num_cores]}) + 1) install"]
  end

  # Due to windows, when we run the configure, we need this variable to be set
  # in accordance with windows pathing. However, when we create the directory
  # below, we need it in accordance with cygwin pathing.
  install_root = settings[:prefix] if platform.is_windows?

  pkg.directory File.join(settings[:sysconfdir], 'pxp-agent')
  pkg.directory File.join(settings[:sysconfdir], 'pxp-agent', 'modules')
  pkg.directory File.join(install_root, 'pxp-agent', 'spool')
  pkg.directory File.join(settings[:logdir], 'pxp-agent')

  case platform.servicetype
  when "systemd"
    pkg.install_service "ext/systemd/pxp-agent.service", "ext/redhat/pxp-agent.sysconfig"
    pkg.install_configfile "ext/systemd/pxp-agent.logrotate", "/etc/logrotate.d/pxp-agent"
  when "sysv"
    if platform.is_deb?
      pkg.install_service "ext/debian/pxp-agent.init", "ext/debian/pxp-agent.default"
    elsif platform.is_sles?
      pkg.install_service "ext/suse/pxp-agent.init", "ext/redhat/pxp-agent.sysconfig"
    elsif platform.is_rpm?
      pkg.install_service "ext/redhat/pxp-agent.init", "ext/redhat/pxp-agent.sysconfig"
    end
    pkg.install_configfile "ext/pxp-agent.logrotate", "/etc/logrotate.d/pxp-agent"
  when "launchd"
    pkg.install_service "ext/osx/pxp-agent.plist", nil, "com.puppetlabs.pxp-agent"
  when "smf"
    pkg.install_service "ext/solaris/smf/pxp-agent.xml", service_type: "network"
  when "aix"
    pkg.install_service "resources/aix/pxp-agent.service", nil, "pxp-agent"
  when "windows"
    puts "Service files not enabled on windows"
  else
    fail "need to know where to put #{pkg.get_name} service files"
  end
end
