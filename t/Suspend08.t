
BEGIN {				# Magic Perl CORE pragma
    if ($ENV{PERL_CORE}) {
        chdir 't' if -d 't';
        @INC = '../lib';
    }
}

use Thread::Suspend ();

use Test::More tests => 4;
use strict;
use warnings;

foreach (qw(suspend suspended kill)) {
    eval {threads->suspend};
    is( $@,"Cannot find out which other threads are running because Thread::Running was not loaded\n" );
}

my $thread = threads->new( sub {1} );
eval {$thread->kill};
is( $@,"Cannot kill other threads because Thread::Exit was not loaded\n" );
$thread->join;
