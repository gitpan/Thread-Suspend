BEGIN {				# Magic Perl CORE pragma
    if ($ENV{PERL_CORE}) {
        chdir 't' if -d 't';
        @INC = '../lib';
    }
}

BEGIN {
    eval {require Thread::Running; Thread::Running->import};
} #BEGIN
use Thread::Suspend;

use Test::More tests => 16;
use strict;
use warnings;

my $times = 3;
my $count : shared = 0;

diag( "Suspending and resuming a thread for about @{[9 * $times]} seconds\n" );

my $thread = threads->new( sub {
    while (defined $count) {
        {lock $count; $count++};
        sleep 1;
    }
} );

sleep $times;
ok( ($count and $count <= $times),
 "check if not done too many times, initially" );

ok( (scalar suspend( $thread )),"Check if suspend( object ) successful" );
{lock $count; $count = 0};
sleep $times;
ok( ($count == 0),"check if not incremented, suspend( object )" );

ok( (scalar suspended( $thread )),"Check if suspended( object ) successful" );
ok( (scalar resume( $thread )),"Check if resume( object ) successful" );
sleep $times;
ok( ($count and $count <= $times),
 "check if not done too many times, resume( object )" );

ok( (scalar suspend( $thread->tid )),
 "Check if suspend( object->tid ) successful" );
{lock $count; $count = 0};
sleep $times;
ok( ($count == 0),"check if not incremented, suspend( object->tid )" );

ok( (scalar suspended( $thread->tid )),
 "Check if suspended( object->tid ) successful" );
ok( (scalar resume( $thread->tid )),
 "Check if resume( object->tid ) successful" );
sleep $times;
ok( ($count and $count <= $times),
 "check if not done too many times, resume( object->tid )" );

SKIP : {
    skip 'Thread::Running not available',5 unless defined $Thread::Running::VERSION;

    ok( (scalar suspend()), "Check if suspend() successful" );
    {lock $count; $count = 0};
    sleep $times;
    ok( ($count == 0),"check if not incremented, suspend()" );

    ok( (scalar suspended()), "Check if suspended() successful" );
    ok( (scalar resume()), "Check if resume() successful" );
    sleep $times;
    ok( ($count and $count <= $times),
     "check if not done too many times, resume()" );
} #SKIP

{lock $count; $count = undef};
$thread->join;
