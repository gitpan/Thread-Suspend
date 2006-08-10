use strict;
use warnings;

use Test::More 'no_plan';

use_ok('Thread::Suspend');

my %COUNTS :shared;

$SIG{'KILL'} = sub { threads->exit(); };

sub thr_func
{
    my $tid = threads->tid();
    $COUNTS{$tid} = 1;
    threads->self()->suspend();
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

foreach my $thr (threads->is_suspended()) {
    is(scalar(grep { $_ == $thr } @threads), 1, 'In suspend list');
}

while (my $thr = pop(@threads)) {
    my $tid = $thr->tid();

    is(scalar(threads->is_suspended())-1, scalar(@threads), "Threads suspended");
    is(scalar(grep { $_ == $thr } threads->is_suspended()), 1, 'In suspend list');
    is($thr->is_suspended(), 1, "Thread $tid suspended");
    check($thr, 'stopped');

    $thr->suspend();
    threads->yield();
    is(scalar(threads->is_suspended())-1, scalar(@threads), "Threads suspended");
    is(scalar(grep { $_ == $thr } threads->is_suspended()), 1, 'In suspend list');
    is($thr->is_suspended(), 2, "Thread $tid suspended twice");
    check($thr, 'stopped');

    $thr->resume();
    threads->yield();
    is(scalar(threads->is_suspended())-1, scalar(@threads), "Threads suspended");
    is(scalar(grep { $_ == $thr } threads->is_suspended()), 1, 'In suspend list');
    is($thr->is_suspended(), 1, "Thread $tid still suspended");
    check($thr, 'stopped');
    is($COUNTS{$tid}, 1, "Thread $tid has 1 count");

    $thr->resume();
    threads->yield();
    is(scalar(threads->is_suspended()), scalar(@threads), "Threads suspended");
    is(scalar(grep { $_ == $thr } threads->is_suspended()), 0, 'Not in suspend list');
    is($thr->is_suspended(), 0, "Thread $tid not suspended");
    check($thr, 'running');

    $thr->kill('KILL')->join();
}

# EOF
