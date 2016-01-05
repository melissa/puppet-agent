component "leatherman" do |pkg, settings, platform|
  pkg.load_from_json('configs/components/leatherman.json')

  prefix = settings[:prefix]
  libdir = settings[:libdir]
  make = platform[:make]

  if platform.is_osx?
    pkg.build_requires "cmake"
    pkg.build_requires "boost"
  elsif platform.name =~ /huaweios/
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/HuaweiOS/#{platform.os_version}/ppce500mc/pl-gcc-4.8.2-1.huaweios6.ppce500mc.rpm"
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/HuaweiOS/#{platform.os_version}/ppce500mc/pl-cmake-3.2.3-1.huaweios6.ppce500mc.rpm"
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/HuaweiOS/#{platform.os_version}/ppce500mc/pl-boost-1.58.0-1.huaweios6.ppce500mc.rpm"
  elsif platform.name =~ /solaris-10/
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/solaris/10/pl-gcc-4.8.2.#{platform.architecture}.pkg.gz"
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/solaris/10/pl-binutils-2.25.#{platform.architecture}.pkg.gz"
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/solaris/10/pl-boost-1.58.0-1.#{platform.architecture}.pkg.gz"
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/solaris/10/pl-cmake-3.2.3-2.i386.pkg.gz"
  elsif platform.name =~ /solaris-11/
    pkg.build_requires "pl-gcc-#{platform.architecture}"
    pkg.build_requires "pl-cmake"
    pkg.build_requires "pl-boost-#{platform.architecture}"
  elsif platform.is_aix?
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/aix/#{platform.os_version}/ppc/pl-gcc-5.2.0-1.aix#{platform.os_version}.ppc.rpm"
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/aix/#{platform.os_version}/ppc/pl-cmake-3.2.3-2.aix#{platform.os_version}.ppc.rpm"
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/aix/#{platform.os_version}/ppc/pl-boost-1.58.0-1.aix#{platform.os_version}.ppc.rpm"
  elsif platform.is_windows?
    pkg.build_requires "cmake"
    pkg.build_requires "pl-toolchain-#{platform.architecture}"
    pkg.build_requires "pl-boost-#{platform.architecture}"
  else
    pkg.build_requires "pl-gcc"
    pkg.build_requires "pl-cmake"
    pkg.build_requires "pl-boost"
  end

  # curl is only used for compute clusters (GCE, EC2); so rpm, deb, and Windows
  use_curl = 'FALSE'
  if platform.is_linux? || platform.is_windows?
    pkg.build_requires "curl"
    use_curl = 'TRUE'
  end

  pkg.build_requires "ruby"

  ruby = "#{settings[:host_ruby]} -rrbconfig"
  build_shared = "TRUE"

  # cmake on OSX is provided by brew
  # a toolchain is not currently required for OSX since we're building with clang.
  if platform.is_osx?
    toolchain = ""
    cmake = "/usr/local/bin/cmake"
  elsif platform.is_solaris?
    if platform.architecture == 'sparc'
      ruby = "#{settings[:host_ruby]} -r#{settings[:datadir]}/doc/rbconfig.rb"
    end

    toolchain = "-DCMAKE_TOOLCHAIN_FILE=/opt/pl-build-tools/#{settings[:platform_triple]}/pl-build-toolchain.cmake"
    cmake = "/opt/pl-build-tools/i386-pc-solaris2.#{platform.os_version}/bin/cmake"

    # FACT-1156: If we build with -O3, solaris segfaults due to something in std::vector
    special_flags = "-DCMAKE_CXX_FLAGS_RELEASE='-O2 -DNDEBUG'"
  elsif platform.is_windows?
    arch = platform.architecture == "x64" ? "64" : "32"
    make = "#{platform.drive_root}/tools/mingw#{arch}/bin/mingw32-make"
    prefix = platform.convert_to_windows_path(settings[:prefix])
    libdir = platform.convert_to_windows_path(settings[:libdir])

    pkg.environment "MAKE" => platform.convert_to_windows_path(make)
    pkg.environment "PATH" => "#{settings[:gcc_bindir]}:#{settings[:tools_root]}/bin:#{settings[:bindir]}:#{platform.drive_root}/Windows/system32:#{platform.drive_root}/Windows:#{platform.drive_root}/Windows/System32/Wbem:#{platform.drive_root}/Windows/System32/WindowsPowerShell/v1.0:#{platform.drive_root}/pstools"
    pkg.environment "CYGWIN" => settings[:cygwin]
    pkg.environment "CC" => settings[:cc]
    pkg.environment "CXX" => settings[:cxx]
    pkg.environment "LDFLAGS" => settings[:ldflags]
    pkg.environment "CFLAGS" => settings[:cflags]

    cmake = "#{platform.drive_root}/ProgramData/chocolatey/bin/cmake.exe -G \"MinGW Makefiles\""
    toolchain = "-DCMAKE_TOOLCHAIN_FILE=#{platform.convert_to_windows_path(settings[:tools_root])}/pl-build-toolchain.cmake"

    build_shared = "FALSE"
  else
    toolchain = "-DCMAKE_TOOLCHAIN_FILE=/opt/pl-build-tools/pl-build-toolchain.cmake"
    cmake = "/opt/pl-build-tools/bin/cmake"
  end

  pkg.configure do
    ["#{cmake} \
        #{toolchain} \
        -DCMAKE_VERBOSE_MAKEFILE=ON \
        -DCMAKE_PREFIX_PATH=#{prefix} \
        -DCMAKE_INSTALL_PREFIX=#{prefix} \
        -DLEATHERMAN_SHARED=#{build_shared} \
        #{special_flags} \
        -DBOOST_STATIC=ON \
        -DLEATHERMAN_USE_CURL=#{use_curl} \
        ."]
  end

  # Make test will explode horribly in a cross-compile situation
  # Tests will be skipped on AIX until they are expected to pass
  if platform.architecture == 'sparc' || platform.is_aix?
    test = "/bin/true"
  else
    test = "LEATHERMAN_RUBY=#{libdir}/$(shell #{ruby} -e 'print RbConfig::CONFIG[\"LIBRUBY_SO\"]') #{make} test ARGS=-V"
  end

  if platform.is_solaris? && platform.architecture != 'sparc'
    test = "LANG=C #{test}"
  end

  pkg.build do
    # Until a `check` target exists, run tests are part of the build.
    [
      "#{make} -j$(shell expr $(shell #{platform[:num_cores]}) + 1)",
      "#{test}"
    ]
  end

  pkg.install do
    ["#{make} -j$(shell expr $(shell #{platform[:num_cores]}) + 1) install"]
  end
end
