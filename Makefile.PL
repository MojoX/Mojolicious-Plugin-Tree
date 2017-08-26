use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'Mojolicious::Plugin::Tree',
    VERSION_FROM => 'lib/Mojolicious/Plugin/Tree.pm',
    AUTHOR       => 'Kostya Ten <kostya@cpan.org>',
    PREREQ_PM    => {
        'Mojolicious' => '7.33',
        'Mojo::Pg' => '4.01',
        'SQL::Abstract::More' => '1.28',
        'Try::Tiny' => '0.28',
        'Test::Perl::Critic' => '1.03',
    },
    test => {TESTS => 't/*.t'}
);
