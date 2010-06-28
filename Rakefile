
begin
  require 'bones'
rescue LoadError
  abort '### Please install the "bones" gem ###'
end

task :default => 'test:run'
task 'gem:release' => 'test:run'

Bones {
  name  'roadie'
  authors  'Tim Pease'
  email  'tim.pease@gmail.com'
  url  'http://github.com/TwP/roadie'
  ignore_file  '.gitignore'
}

