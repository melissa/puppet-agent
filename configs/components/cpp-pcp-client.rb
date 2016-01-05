component "cpp-pcp-client" do |pkg, settings, platform|
  pkg.load_from_json('configs/components/cpp-pcp-client.json')
  cmake = "/opt/pl-build-tools/bin/cmake"
  toolchain = "-DCMAKE_TOOLCHAIN_FILE=/opt/pl-build-tools/pl-build-toolchain.cmake"
  pkg.environment "PATH" => "#{settings[:bindir]}:#{settings[:tools_root]}/bin:$$PATH"

  platform_flags = ''

  prefix = settings[:prefix]
  make = platform[:make]

  pkg.build_requires "openssl"
  if platform.is_aix?
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/aix/#{platform.os_version}/ppc/pl-gcc-5.2.0-1.aix#{platform.os_version}.ppc.rpm"
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/aix/#{platform.os_version}/ppc/pl-cmake-3.2.3-2.aix#{platform.os_version}.ppc.rpm"
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/aix/#{platform.os_version}/ppc/pl-boost-1.58.0-1.aix#{platform.os_version}.ppc.rpm"
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/aix/#{platform.os_version}/ppc/pl-yaml-cpp-0.5.1-1.aix#{platform.os_version}.ppc.rpm"
    # This should be moved to the toolchain file
    platform_flags = '-DCMAKE_SHARED_LINKER_FLAGS="-Wl,-bbigtoc"'
  elsif platform.is_osx?
    cmake = "/usr/local/bin/cmake"
    toolchain = ""
  elsif platform.is_solaris?
    cmake = "/opt/pl-build-tools/i386-pc-solaris2.#{platform.os_version}/bin/cmake"
    toolchain = "-DCMAKE_TOOLCHAIN_FILE=/opt/pl-build-tools/#{settings[:platform_triple]}/pl-build-toolchain.cmake"
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
      "#{cmake} \
      #{toolchain} \
      #{platform_flags} \
          -DCMAKE_VERBOSE_MAKEFILE=ON \
          -DCMAKE_PREFIX_PATH=#{prefix} \
          -DCMAKE_INSTALL_PREFIX=#{prefix} \
          -DCMAKE_SYSTEM_PREFIX_PATH=#{prefix} \
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
end
