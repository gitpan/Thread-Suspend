
BEGIN {				# Magic Perl CORE pragma
    if ($ENV{PERL_CORE}) {
        chdir 't' if -d 't';
        @INC = '../lib';
    }
}

use Thread::Suspend;

use Test::More tests => 9;
use strict;
use warnings;

my $times = 3;
my $count : shared = 0;

diag( "Suspending and resuming a busy thread for about @{[9 * $times]} seconds\n" );

my $thread = threads->new( sub {
    iambusy();
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
ok( ($count and $count <= $times),
 "check if incremented still, suspend( object )" );

ok( (scalar resume( $thread )),"Check if resume( object ) successful" );
{lock $count; $count = 0};
sleep $times;
ok( ($count and $count <= $times),
 "check if not done too many times, resume( object )" );

ok( (scalar suspend( $thread->tid )),
 "Check if suspend( object->tid ) successful" );
{lock $count; $count = 0};
sleep $times;
ok( ($count and $count <= $times),
 "check if incremented still, suspend( object->tid )" );

ok( (scalar resume( $thread->tid )),
 "Check if resume( object->tid ) successful" );
{lock $count; $count = 0};
sleep $times;
ok( ($count and $count <= $times),
 "check if not done too many times, resume( object->tid )" );

{lock $count; $count = undef};
$thread->join;
