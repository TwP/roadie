
begin
  require 'bones'
rescue LoadError
  abort '### Please install the "bones" gem ###'
end

task :default => 'spec:specdoc'
task 'gem:release' => 'spec:run'

Bones {
  name         'roadie'
  authors      'Tim Pease'
  email        'tim.pease@gmail.com'
  url          'http://github.com/TwP/roadie'
  ignore_file  '.gitignore'
  spec.opts << '--color'
  use_gmail

  depend_on 'loquacious'
  depend_on 'rspec', :development => true
}

