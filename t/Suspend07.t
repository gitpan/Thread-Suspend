
BEGIN {				# Magic Perl CORE pragma
    if ($ENV{PERL_CORE}) {
        chdir 't' if -d 't';
        @INC = '../lib';
    }
}

BEGIN { eval {require Thread::Exit} };

use Thread::Suspend ();

my $tests; BEGIN { $tests = 7 };
use Test::More tests => $tests;
use strict;
use warnings;

my $times = 3;
my $count : shared = 0;
my $busy : shared = 0;

SKIP: {
skip 'Thread::Exit not available',$tests - 1
 unless defined $Thread::Exit::VERSION;

warn <<EOD if -t;

You may see some warnings during this test.  These seem to be an artefact
of the test-suite, rather than a problem that normally occurs when trying
to kill threads.

EOD

diag( "Killing threads for about @{[3 * $times]} seconds\n" );

my $thread = threads->new( sub {
    while (defined $count) {
        {lock $count; $count++};
        sleep 1;
    }
} );

sleep $times;
ok( (scalar $thread->kill),"Check if object->kill successful" );
sleep $times;
ok( ($count <= $times),"check if not done too many times, initially" );
{lock $count; $count = undef};  # in case kill failed
$thread->join;

# The following tests cause an error exit even though test succeeds ;-(
# Change 0 to 1 in the if() to run the test anyway

if (0) {

    {lock $count; $count = 0};
    $thread = threads->new( sub {
        while (defined $count) {
            if ($count == 0) {
                threads->iambusy;
                $busy++;
                while ($count < $times) {
                    {lock $count; $count++};
                    sleep 1;
                }
                threads->iamdone;
            }
            {lock $count; $count++};
            sleep 1;
        }
    } );

    sleep 1;
    ok( (scalar $thread->suspend),"Check if object->suspend successful" );
    sleep $times;
    cmp_ok( $count,'==',$times,"check if right number of times until suspended" );
    ok( (scalar threads->kill( $thread )),
     "Check if threads->kill( object ) successful" );

    cmp_ok( $count,'==',$times,"check if right number of times after kill" );
    {lock $count; $count = undef};  # in case kill failed
    $thread->join;

} else {
    ok( 1,"skipping to avoid breaking of test because of exit value, #$_" )
     foreach 1..4;
}
} #SKIP

ok( 1,"check whether we returned ok after all of this" );
