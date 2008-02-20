use strict;
use warnings;

use threads;
use threads::shared;

use Test::More 'tests' => 42;

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
    while (++$COUNTS{$tid}) {
        threads->yield();
    }
}

sub check {
    my ($thr, $running) = @_;
    my $tid = $thr->tid();

    my ($begin, $end);
    do {
        do {
            threads->yield();
            $begin = $COUNTS{$tid};
        } while (! $begin);
        threads->yield() for (1..3);
        sleep(1);
        threads->yield() for (1..3);
        $end = $COUNTS{$tid};
    } while (! $end);
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
sleep(1);

is(scalar(threads->list()), 3, 'Threads created');

foreach my $thr (@threads) {
    $thr->detach();
}
threads->yield();
sleep(1);

is(scalar(threads->list()), 0, 'Threads detached');

foreach my $thr (@threads) {
    my $tid = $thr->tid();
    ok(! threads->is_suspended(), 'No reported suspended threads');
    is($thr->is_suspended(), 0, "Thread $tid not suspended");
    check($thr, 'running');

    $thr->suspend();
    threads->yield();
    is($thr->is_suspended(), 1, "Thread $tid suspended");
    check($thr, 'stopped');

    $thr->suspend();
    threads->yield();
    ok(! threads->is_suspended(), 'No reported suspended threads');
    is($thr->is_suspended(), 2, "Thread $tid suspended twice");
    check($thr, 'stopped');

    $thr->resume();
    threads->yield();
    is($thr->is_suspended(), 1, "Thread $tid still suspended");
    check($thr, 'stopped');

    $thr->resume();
    threads->yield();
    is($thr->is_suspended(), 0, "Thread $tid not suspended");
    check($thr, 'running');

    is($thr->kill('KILL'), $thr, "Thread $tid killed");
    threads->yield();
    while (! exists($DONE{$tid})) {
        sleep(1);
    }
}

# EOF
