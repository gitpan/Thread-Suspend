BEGIN {				# Magic Perl CORE pragma
    if ($ENV{PERL_CORE}) {
        chdir 't' if -d 't';
        @INC = '../lib';
    }
}

my $threads; BEGIN { $threads = 16 };

use Thread::Suspend ();

use Test::More tests => 7 * $threads + 2;
use strict;
use warnings;

my @todo = 1..$threads;
my $extra = 4; # 4 is rather arbitrary
my $sleep = $threads + $extra;
my @count : shared;
$count[$_] = 0 foreach @todo;

diag( "Testing multiple threads, will take about @{[3 * ($threads+$extra) + 2 * ($extra+$extra)]} seconds\n" );
my @thread;
$thread[$_] = threads->new( \&breathe,$_ ) foreach @todo;

#diag( "Letting $threads threads live for $sleep seconds\n" );
sleep $sleep;
ok( ($count[$_] and $count[$_] <= $sleep + 1),
 "check if not done too many times for $_ ($count[$_]), initially" ) foreach @todo;

#diag( "Waiting @{[$extra+$extra]} seconds for $threads threads to be suspended\n" );
ok( (scalar $thread[$_]->suspend),"Check if object[$_]->suspend successful" )
 foreach @todo;
sleep $extra;
{lock @count; $count[$_] = 0 foreach @todo};
sleep $extra;
ok( ($count[$_] == 0),
 "check if not incremented for $_ ($count[$_]), object->suspend" )
  foreach @todo;

#diag( "Letting $threads threads live again for $sleep seconds\n" );
ok( (scalar $thread[$_]->resume),"Check if object[$_]->resume successful" )
 foreach @todo;
sleep $sleep;
ok( ($count[$_] and $count[$_] <= $sleep + 1),
 "check if not done too many times for $_ ($count[$_]), object->resume" )
  foreach @todo;

#diag( "Waiting @{[$extra+$extra]} seconds for $threads threads to be suspended again\n" );
ok( (() = threads->suspend( map {$thread[$_]} @todo )) == @todo,
 "Check if threads->suspend( threads ) successful" );
sleep $extra;
{lock @count; $count[$_] = 0 foreach @todo};
sleep $extra;
ok( ($count[$_] == 0),
 "check if not incremented for $_ ($count[$_]), threads->suspend( tid )" )
  foreach @todo;

#diag( "Letting all threads live again for $sleep seconds\n" );
ok( (() = threads->resume) == @todo,"Check if threads->resume successful" );
sleep $sleep;
ok( ($count[$_] and $count[$_] <= $sleep + 1),
 "check if not done too many times for $_ ($count[$_]), threads->resume" )
  foreach @todo;

#diag( "Shutting down all threads\n" );
$count[$_] = undef foreach @todo;
$thread[$_]->join foreach @todo;

sub breathe {
    my $id = shift;
    while (defined $count[$id]) {
        {lock @count; $count[$id]++};
        sleep 1;
    }
} #breathe
