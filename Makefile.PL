use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'Mojolicious::Plugin::Kong::SharedSecret',
    VERSION_FROM => 'lib/Mojolicious/Plugin/Kong/SharedSecret.pm',
    AUTHOR       => 'William Wheeler<wfwheele@cpan.org>',
    BUILD_REQUIRES =>
        { 'ExtUtils::MakeMaker' => 0, 'Test::MockModule' => '0.11' },
    PREREQ_PM => { 'Mojolicious' => '7.09', 'Cache::Memory::Simple' => '1.03' },
    test => { TESTS => 't/*.t' }
);
