use strict;
use warnings;

use Test::More 'no_plan';

use_ok('Thread::Suspend');

my %COUNTS :shared;
my %DONE :shared;

$SIG{'KILL'} = sub {
    my $tid = threads->tid();
    $DONE{$tid} = 1;
    threads->exit();
};

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
for (1..3) {
    push(@threads, threads->create('thr_func'));
}
threads->yield();

is(scalar(threads->list()), 3, 'Threads created');

foreach my $thr (@threads) {
    $thr->detach();
}
threads->yield();

is(scalar(threads->list()), 0, 'Threads detached');

foreach my $thr (@threads) {
    my $tid = $thr->tid();
    ok(! threads->is_suspended(), 'No reported suspended threads');
    is($thr->is_suspended(), 0, "Thread $tid not suspended");
    check($thr, 'running');

    $thr->suspend();
    is($thr->is_suspended(), 1, "Thread $tid suspended");
    check($thr, 'stopped');

    $thr->suspend();
    ok(! threads->is_suspended(), 'No reported suspended threads');
    is($thr->is_suspended(), 2, "Thread $tid suspended twice");
    check($thr, 'stopped');

    $thr->resume();
    is($thr->is_suspended(), 1, "Thread $tid still suspended");
    check($thr, 'stopped');

    $thr->resume();
    is($thr->is_suspended(), 0, "Thread $tid not suspended");
    check($thr, 'running');

    is($thr->kill('KILL'), $thr, "Thread $tid killed");
    threads->yield();
    while (! exists($DONE{$tid})) {
        sleep(1);
    }
}

# EOF
