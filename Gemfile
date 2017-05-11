source ENV['GEM_SOURCE'] || "https://rubygems.org"

def location_for(place)
  if place =~ /^(git[:@][^#]*)#(.*)/
    [{ :git => $1, :branch => $2, :require => false }]
  elsif place =~ /^file:\/\/(.*)/
    ['>= 0', { :path => File.expand_path($1), :require => false }]
  else
    [place, { :require => false }]
  end
end

gem 'vanagon', *location_for(ENV['VANAGON_LOCATION'] || '0.11.3')
gem 'packaging', :git => 'git@github.com:melissa/packaging.git', :branch => 'ticket/master/RE-8726-allow-ship-to-nonfinal-repo'
gem 'rake'
gem 'json'
gem 'rubocop', "~> 0.34.2"
