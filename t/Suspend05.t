
BEGIN {				# Magic Perl CORE pragma
    if ($ENV{PERL_CORE}) {
        chdir 't' if -d 't';
        @INC = '../lib';
    }
}

use Thread::Suspend ();

use Test::More tests => 9;
use strict;
use warnings;

my $times = 3;
my $count : shared = 0;

diag( "Suspending and resuming a not-busy thread for about @{[9 * $times]} seconds\n" );

my $thread = threads->new( sub {
    threads->iambusy;
    threads->iamdone;
    while (defined $count) {
        {lock $count; $count++};
        sleep 1;
    }
} );

sleep $times;
ok( ($count and $count <= $times),
 "check if not done too many times, initially" );

ok( (scalar $thread->suspend),"Check if object->suspend successful" );
{lock $count; $count = 0};
sleep $times;
ok( ($count == 0),"check if not incremented, object->suspend" );

ok( (scalar $thread->resume),"Check if object->resume successful" );
sleep $times;
ok( ($count and $count <= $times),
 "check if not done too many times, resume( object )" );

ok( (scalar threads->suspend( $thread->tid )),
 "Check if threads->suspend( object->tid ) successful" );
{lock $count; $count = 0};
sleep $times;
ok( ($count == 0),"check if not incremented, threads->suspend( object->tid )" );

ok( (scalar threads->resume( $thread->tid )),
 "Check if threads->resume( object->tid ) successful" );
sleep $times;
ok( ($count and $count <= $times),
 "check if not done too many times, threads->resume( object->tid )" );

{lock $count; $count = undef};
$thread->join;
