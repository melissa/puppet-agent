component "hiera" do |pkg, settings, platform|
  pkg.load_from_json('configs/components/hiera.json')

  pkg.build_requires "ruby"
  pkg.build_requires "rubygem-deep-merge"

  pkg.replaces 'hiera', '2.0.0'
  pkg.provides 'hiera', '2.0.0'

  pkg.replaces 'pe-hiera'

  ruby = File.join(settings[:bindir], 'ruby')
  bindir = settings[:bindir]
  configdir = settings[:puppet_codedir]
  sitelibdir = settings[:ruby_vendordir]
  mandir = settings[:mandir]

  if platform.is_windows?
    ruby = platform.convert_to_windows_path(File.join(settings[:bindir], 'ruby'))
    bindir = platform.convert_to_windows_path(settings[:bindir])
    configdir = platform.convert_to_windows_path(settings[:puppet_codedir])
    sitelibdir = platform.convert_to_windows_path(settings[:ruby_vendordir])
    mandir = platform.convert_to_windows_path(settings[:mandir])
  end


  pkg.install do
    "#{settings[:host_ruby]} install.rb --ruby=#{ruby} --bindir=#{bindir} --configdir=#{configdir} --sitelibdir=#{sitelibdir} --configs --quick --man --mandir=#{mandir}"
  end

  pkg.install_file ".gemspec", "#{settings[:gem_home]}/specifications/#{pkg.get_name}.gemspec"

  pkg.configfile File.join(settings[:puppet_codedir], 'hiera.yaml')

  pkg.link "#{settings[:bindir]}/hiera", "#{settings[:link_bindir]}/hiera" unless platform.is_windows?

  pkg.directory File.join(settings[:puppet_codedir], 'environments', 'production', 'hieradata')
end
