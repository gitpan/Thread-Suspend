
BEGIN {				# Magic Perl CORE pragma
    if ($ENV{PERL_CORE}) {
        chdir 't' if -d 't';
        @INC = '../lib';
    }
}

use Thread::Suspend ();

use Test::More tests => 6;
use strict;
use warnings;

my $times = 3;
my $count : shared = 0;
my $busy : shared = 0;

diag( "Suspending and resuming a busy thread for about @{[3 * $times]} seconds\n" );

my $thread = threads->new( sub {
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
sleep $times + $times;
cmp_ok( $busy,'==',1,"check if only busy once" );
cmp_ok( $count,'==',$times,"check if not done too many times, initially" );

{lock $count; $count = 0};
ok( (scalar $thread->resume),"Check if object->resume successful" );
sleep $times;
cmp_ok( $busy,'==',1,"check if still only busy once" );
ok( ($count and $count <= $times),
 "check if not done too many times, object->resume" );

{lock $count; $count = undef};
$thread->join;
