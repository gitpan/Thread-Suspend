use strict;
use warnings;

use Test::More 'no_plan';

use_ok('Thread::Suspend');

if ($Thread::Suspend::VERSION) {
    diag('Testing Thread::Suspend ' . $Thread::Suspend::VERSION);
}

can_ok('threads', qw(suspend is_suspended resume));

my %COUNTS :shared;

$SIG{'KILL'} = sub { threads->exit(); };

sub thr_func
{
    my $tid = threads->tid();
    while (1) {
        { lock(%COUNTS); $COUNTS{$tid}++; }
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
for (1..3) {
    unshift(@threads, threads->new('thr_func'));
}
threads->yield();

is(scalar(threads->list()), 3, 'Threads created');

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

# EOF
