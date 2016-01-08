component "facter" do |pkg, settings, platform|
  pkg.load_from_json('configs/components/facter.json')

  if platform.is_rpm?
    # In our rpm packages, facter has an epoch set, so we need to account for that here
    pkg.replaces 'facter', '1:3.0.0'
    pkg.provides 'facter', '1:3.0.0'
  else
    pkg.replaces 'facter', '3.0.0'
    pkg.provides 'facter', '3.0.0'
  end
  pkg.replaces 'cfacter', '0.5.0'
  pkg.provides 'cfacter', '0.5.0'

  pkg.replaces 'pe-facter'

  pkg.build_requires "ruby"
  pkg.build_requires 'openssl'
  pkg.build_requires 'leatherman'

  if platform.is_linux?
    # Running facter (as part of testing) expects virt-what is available
    pkg.build_requires 'virt-what'
  end

  # Running facter (as part of testing) expects augtool are available
  pkg.build_requires 'augeas' unless platform.is_windows?
  pkg.build_requires "openssl"

  pkg.environment "PATH" => "#{settings[:bindir]}:$$PATH"

  # OSX uses clang and system openssl.  cmake comes from brew.
  if platform.is_osx?
    pkg.build_requires "cmake"
    pkg.build_requires "boost"
    pkg.build_requires "yaml-cpp --with-static-lib"
  elsif platform.name =~ /huaweios/
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/HuaweiOS/#{platform.os_version}/ppce500mc/pl-gcc-4.8.2-1.huaweios6.ppce500mc.rpm"
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/HuaweiOS/#{platform.os_version}/ppce500mc/pl-cmake-3.2.3-1.huaweios6.ppce500mc.rpm"
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/HuaweiOS/#{platform.os_version}/ppce500mc/pl-boost-1.58.0-1.huaweios6.ppce500mc.rpm"
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/HuaweiOS/#{platform.os_version}/ppce500mc/pl-yaml-cpp-0.5.1-1.huaweios6.ppce500mc.rpm"
  elsif platform.name =~ /solaris-10/
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/solaris/10/pl-gcc-4.8.2.#{platform.architecture}.pkg.gz"
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/solaris/10/pl-binutils-2.25.#{platform.architecture}.pkg.gz"
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/solaris/10/pl-boost-1.58.0-1.#{platform.architecture}.pkg.gz"
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/solaris/10/pl-yaml-cpp-0.5.1.#{platform.architecture}.pkg.gz"
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/solaris/10/pl-cmake-3.2.3-2.i386.pkg.gz"
  elsif platform.name =~ /solaris-11/
    pkg.build_requires "pl-gcc-#{platform.architecture}"
    pkg.build_requires "pl-cmake"
    pkg.build_requires "pl-boost-#{platform.architecture}"
    pkg.build_requires "pl-yaml-cpp-#{platform.architecture}"
  elsif platform.is_aix?
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/aix/#{platform.os_version}/ppc/pl-gcc-5.2.0-1.aix#{platform.os_version}.ppc.rpm"
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/aix/#{platform.os_version}/ppc/pl-cmake-3.2.3-2.aix#{platform.os_version}.ppc.rpm"
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/aix/#{platform.os_version}/ppc/pl-boost-1.58.0-1.aix#{platform.os_version}.ppc.rpm"
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/aix/#{platform.os_version}/ppc/pl-yaml-cpp-0.5.1-1.aix#{platform.os_version}.ppc.rpm"
    pkg.build_requires "runtime"
  elsif platform.is_windows?
    pkg.build_requires "cmake"
    pkg.build_requires "pl-toolchain-#{platform.architecture}"
    pkg.build_requires "pl-boost-#{platform.architecture}"
    pkg.build_requires "pl-yaml-cpp-#{platform.architecture}"
    pkg.build_requires "runtime"
  else
    pkg.build_requires "pl-gcc"
    pkg.build_requires "pl-cmake"
    pkg.build_requires "pl-boost"
    pkg.build_requires "pl-yaml-cpp"
  end

  # Explicitly skip jruby if not installing a jdk.
  skip_jruby = 'OFF'
  java_home = ''
  java_includedir = ''
  case platform.name
  when /fedora-f20/
    pkg.build_requires 'java-1.7.0-openjdk-devel'
  when /(el-(6|7)|fedora-(f21|f22))/
    pkg.build_requires 'java-1.8.0-openjdk-devel'
  when /(debian-(7|8)|ubuntu-(12|14))/
    pkg.build_requires 'openjdk-7-jdk'
    java_home = "/usr/lib/jvm/java-7-openjdk-#{platform.architecture}"
  when /(debian-9|ubuntu-15)/
    pkg.build_requires 'openjdk-8-jdk'
    java_home = "/usr/lib/jvm/java-8-openjdk-#{platform.architecture}"
  when /sles-12/
    pkg.build_requires 'java-1_7_0-openjdk-devel'
    java_home = "/usr/lib64/jvm/java-1.7.0-openjdk"
  when /sles-11/
    pkg.build_requires 'java-1_7_0-ibm-devel'
    java_home = "/usr/lib64/jvm/java-1.7.0-ibm-1.7.0"
    java_includedir = "-DJAVA_JVM_LIBRARY=/usr/lib64/jvm/java-1.7.0-ibm-1.7.0/include"
  else
    skip_jruby = 'ON'
  end

  if skip_jruby == 'OFF'
    settings[:java_available] = true
  else
    settings[:java_available] = false
  end

  if java_home
    pkg.environment "JAVA_HOME" => java_home
  end

  # Skip blkid unless we can ensure it exists at build time. Otherwise we depend
  # on the vagaries of the system we build on.
  skip_blkid = 'ON'
  if platform.is_deb? || platform.is_cisco_wrlinux?
    pkg.build_requires "libblkid-dev"
    skip_blkid = 'OFF'
  elsif platform.is_rpm?
    if (platform.is_el? && platform.os_version.to_i >= 6) || (platform.is_sles? && platform.os_version.to_i >= 11) || platform.is_fedora?
      pkg.build_requires "libblkid-devel"
      skip_blkid = 'OFF'
    elsif (platform.is_el? && platform.os_version.to_i < 6) || (platform.is_sles? && platform.os_version.to_i < 11)
      pkg.build_requires "e2fsprogs-devel"
      skip_blkid = 'OFF'
    end
  end

  # curl is only used for compute clusters (GCE, EC2); so rpm, deb, and Windows
  skip_curl = 'ON'
  if platform.is_linux? || platform.is_windows?
    pkg.build_requires "curl"
    skip_curl = 'OFF'
  end

  ruby = "#{settings[:host_ruby]} -rrbconfig"

  prefix = settings[:prefix]
  bindir = settings[:bindir]
  ruby_vendordir = settings[:ruby_vendordir]
  libdir = settings[:libdir]
  make = platform[:make]

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

    pkg.environment "MAKE" => platform.convert_to_windows_path(make)
    pkg.environment "PATH" => "#{settings[:gcc_bindir]}:#{settings[:tools_root]}/bin:#{settings[:bindir]}:#{platform.drive_root}/Windows/system32:#{platform.drive_root}/Windows:#{platform.drive_root}/Windows/System32/Wbem:#{platform.drive_root}/Windows/System32/WindowsPowerShell/v1.0:#{platform.drive_root}/pstools"
    pkg.environment "CYGWIN" => settings[:cygwin]
    pkg.environment "CC" => settings[:cc]
    pkg.environment "CXX" => settings[:cxx]
    pkg.environment "LDFLAGS" => settings[:ldflags]
    pkg.environment "CFLAGS" => settings[:cflags]

    cmake = "#{platform.drive_root}/ProgramData/chocolatey/bin/cmake.exe -G \"MinGW Makefiles\""
    toolchain = "-DCMAKE_TOOLCHAIN_FILE=#{platform.convert_to_windows_path(settings[:tools_root])}/pl-build-toolchain.cmake"

    prefix = platform.convert_to_windows_path(settings[:prefix])
    bindir = platform.convert_to_windows_path(settings[:bindir])
    ruby_vendordir = platform.convert_to_windows_path(settings[:ruby_vendordir])
    libdir = platform.convert_to_windows_path(settings[:libdir])
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
        #{special_flags} \
        -DBOOST_STATIC=ON \
        -DYAMLCPP_STATIC=ON \
        -DFACTER_PATH=#{bindir} \
        -DRUBY_LIB_INSTALL=#{ruby_vendordir} \
        -DFACTER_RUBY=#{libdir}/$(shell #{ruby} -e 'print RbConfig::CONFIG[\"LIBRUBY_SO\"]') \
        -DWITHOUT_CURL=#{skip_curl} \
        -DWITHOUT_BLKID=#{skip_blkid} \
        -DWITHOUT_JRUBY=#{skip_jruby} \
        #{java_includedir} \
        ."]
  end

  # Make test will explode horribly in a cross-compile situation
  # Tests will be skipped on AIX until they are expected to pass
  if platform.architecture == 'sparc' || platform.is_aix?
    test = ":"
  else
    test = "#{make} test ARGS=-V"
  end

  pkg.build do
    # Until a `check` target exists, run tests are part of the build.
    [
      "#{make} -j$(shell expr $(shell #{platform[:num_cores]}) + 1)",
      test
    ]
  end

  pkg.install do
    ["#{make} -j$(shell expr $(shell #{platform[:num_cores]}) + 1) install"]
  end

  pkg.install_file ".gemspec", "#{settings[:gem_home]}/specifications/#{pkg.get_name}.gemspec"

  if platform.is_windows?
    pkg.directory File.join(settings[:sysconfdir], "facter", "facts.d")
  else
    pkg.link "#{settings[:bindir]}/facter", "#{settings[:link_bindir]}/facter"
    pkg.directory File.join('/opt/puppetlabs', 'facter')
    pkg.directory File.join('/opt/puppetlabs', 'facter', 'facts.d')
  end
end
