Gem::Specification.new do |s|
  s.name          = 'video-fetcher'
  s.version       = '0.0.1'
  s.platform      = Gem::Platform::RUBY
  s.date          = '2014-07-07'
  s.summary       = ''
  s.description   = ''
  s.authors       = 'ben7th'
  s.email         = 'ben7th@sina.com'
  s.homepage      = ''
  s.licenses      = 'MIT'

  s.files         = Dir.glob("lib/**/*") + Dir.glob("vendor/**/*") + %w(README.md)
  s.require_paths = ['lib']
end