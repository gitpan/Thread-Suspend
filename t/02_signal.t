use strict;
use warnings;

use threads;
use threads::shared;

use Test::More 'no_plan';

use_ok('Thread::Suspend', 'SIGILL');

my %COUNTS :shared;

$SIG{'KILL'} = sub { threads->exit(); };

sub thr_func
{
    my $tid = threads->tid();
    while (1) {
        $COUNTS{$tid}++;
        threads->yield();
    }
}

sub check {
    my ($thr, $running) = @_;
    my $tid = $thr->tid();

    my $begin = $COUNTS{$tid};
    threads->yield();
    sleep(1);
    my $end = $COUNTS{$tid};
    if ($running eq 'running') {
        ok($begin < $end, "Thread $tid running");
    } else {
        ok($begin == $end, "Thread $tid stopped");
    }
}

my @threads;
for (1..1) {
    unshift(@threads, threads->create('thr_func'));
}
threads->yield();

is(scalar(threads->list()), 1, 'Threads created');

foreach my $thr (@threads) {
    my $tid = $thr->tid();
    ok(! threads->is_suspended(), 'No threads suspended');
    is($thr->is_suspended(), 0, "Thread $tid not suspended");
    check($thr, 'running');

    $thr->suspend();
    is(scalar(threads->is_suspended()), 1, 'One thread suspended');
    ok((threads->is_suspended())[0] == $thr, "Thread $tid suspended");
    is($thr->is_suspended(), 1, "Thread $tid suspended");
    check($thr, 'stopped');

    $thr->suspend();
    is(scalar(threads->is_suspended()), 1, 'One thread suspended');
    ok((threads->is_suspended())[0] == $thr, "Thread $tid suspended");
    is($thr->is_suspended(), 2, "Thread $tid suspended twice");
    check($thr, 'stopped');

    $thr->resume();
    is(scalar(threads->is_suspended()), 1, 'One thread suspended');
    ok((threads->is_suspended())[0] == $thr, "Thread $tid suspended");
    is($thr->is_suspended(), 1, "Thread $tid still suspended");
    check($thr, 'stopped');

    $thr->resume();
    ok(! threads->is_suspended(), 'No threads suspended');
    is($thr->is_suspended(), 0, "Thread $tid not suspended");
    check($thr, 'running');
}

foreach my $thr (@threads) {
    $thr->kill('KILL')->join();
}


$SIG{'ILL'} = sub {
    is(shift, 'ILL', 'Received suspend signal');
};

my $thr = threads->create('thr_func');

is($thr->suspend(), $thr, 'Sent suspend signal');
threads->yield();
is($thr->kill('KILL'), $thr, 'Thread killed');
$thr->join();

# EOF
