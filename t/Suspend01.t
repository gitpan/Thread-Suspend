BEGIN {				# Magic Perl CORE pragma
    if ($ENV{PERL_CORE}) {
        chdir 't' if -d 't';
        @INC = '../lib';
    }
}

use Test::More tests => 23;
use strict;
use warnings;

my $times = 3;
my $count : shared = 0;

diag( "Suspending and resuming a thread for about @{[9 * $times]} seconds\n" );

use_ok( 'Thread::Suspend' );
can_ok( $_,qw(
 suspend
 resume
 suspended
 iambusy
 iamdone
 kill
) ) foreach qw(Thread::Suspend threads);

my $thread = threads->new( sub {
    while (defined $count) {
        {lock $count; $count++};
        sleep 1;
    }
} );

sleep $times;
ok( ($count and $count <= $times),
 "check if not done too many times, initially" );

ok( (scalar $thread->suspend),"Check if object->suspend succesful" );
{lock $count; $count = 0};
sleep $times;

ok( ($count == 0),"check if not incremented, object->suspend" );
ok( (scalar $thread->suspended),"Check if object->suspended" );
ok( (scalar $thread->resume),"Check if object->suspend successful" );
sleep $times;
ok( ($count and $count <= $times),
 "check if not done too many times, object->resume" );

ok( (scalar threads->suspend( $thread )),
 "Check if threads->suspend( object ) successful" );
{lock $count; $count = 0};
sleep $times;

ok( ($count == 0),"check if not incremented, threads->suspend( object )" );
ok( (scalar threads->suspended( $thread )),
 "Check if threads->suspended( object )" );
ok( (scalar threads->resume( $thread )),
 "Check if threads->resume( object ) successful" );
sleep $times;
ok( ($count and $count <= $times),
 "check if not done too many times, threads->resume( object )" );

ok( (scalar threads->suspend( $thread->tid )),
 "Check if threads->suspend( object->tid ) successful" );
{lock $count; $count = 0};
sleep $times;

ok( ($count == 0),"check if not incremented, threads->suspend( object->tid )" );
ok( (scalar threads->suspended( $thread->tid )),
 "Check if threads->suspended( tid )" );
ok( (scalar threads->resume( $thread->tid )),
 "Check if threads->resume( object->tid ) successful" );
sleep $times;
ok( ($count and $count <= $times),
 "check if not done too many times, threads->resume( object->tid )" );

ok( (scalar $thread->suspend),"Check if object->suspend successful (2nd)" );
{lock $count; $count = 0};
sleep $times;

ok( ($count == 0),"check if not incremented, object->suspend (2nd)" );
ok( (scalar threads->resume),"Check if threads->resume successful" );
sleep $times;
ok( ($count and $count <= $times),
 "check if not done too many times, threads->resume" );

{lock $count; $count = undef};
$thread->join;
