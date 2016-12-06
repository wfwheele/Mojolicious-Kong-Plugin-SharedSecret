use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'Mojolicious::Plugin::Kong::SharedSecret',
  VERSION_FROM => 'lib/Mojolicious/Plugin/Kong/SharedSecret.pm',
  AUTHOR       => 'A Good Programmer <nospam@cpan.org>',
  PREREQ_PM    => {'Mojolicious' => '7.09'},
  test         => {TESTS => 't/*.t'}
);
