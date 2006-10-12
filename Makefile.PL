# Module makefile for Thread::Suspend (using ExtUtils::MakeMaker)

require 5.006;

use strict;
use warnings;

use ExtUtils::MakeMaker;

# Construct make file
WriteMakefile(
    'NAME'          => 'Thread::Suspend',
    'AUTHOR'        => 'Jerry D. Hedden <jdhedden AT cpan DOT org>',
    'VERSION_FROM'  => 'lib/Thread/Suspend.pm',
    'ABSTRACT_FROM' => 'lib/Thread/Suspend.pm',
    'PREREQ_PM'     => {
        'strict'          => 0,
        'warnings'        => 0,
        'threads'         => 1.39,
        'threads::shared' => 1.01,

        'Test::More'      => 0.50,
    },

    ((ExtUtils::MakeMaker->VERSION() lt '6.25') ?
        ('PL_FILES' => { })            : ()),
    ((ExtUtils::MakeMaker->VERSION() gt '6.30') ?
        ('LICENSE'  => 'perl')         : ()),
);

# EOF
