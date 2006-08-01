use strict;
use warnings;

use Test::More 'no_plan';

use_ok('Thread::Suspend');

my %COUNTS :shared;

$SIG{'KILL'} = sub { threads->exit(); };

sub thr_func
{
    my $tid = threads->tid();
    $COUNTS{$tid} = 0;
    threads->self()->suspend();
    while (1) {
        $COUNTS{$tid}++;
        threads->yield();
    }
}

sub check {
    my ($thr, $running) = @_;
    my $tid = $thr->tid();

    threads->yield();
    my $begin = $COUNTS{$tid};
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
    is(scalar(threads->is_suspended())-1, scalar(@threads), "Threads suspended");
    is(scalar(grep { $_ == $thr } threads->is_suspended()), 1, 'In suspend list');
    is($thr->is_suspended(), 2, "Thread $tid suspended twice");
    check($thr, 'stopped');

    $thr->resume();
    is(scalar(threads->is_suspended())-1, scalar(@threads), "Threads suspended");
    is(scalar(grep { $_ == $thr } threads->is_suspended()), 1, 'In suspend list');
    is($thr->is_suspended(), 1, "Thread $tid still suspended");
    check($thr, 'stopped');
    is($COUNTS{$tid}, 0, "Thread $tid has 0 count");

    $thr->resume();
    is(scalar(threads->is_suspended()), scalar(@threads), "Threads suspended");
    is(scalar(grep { $_ == $thr } threads->is_suspended()), 0, 'Not in suspend list');
    is($thr->is_suspended(), 0, "Thread $tid not suspended");
    check($thr, 'running');

    $thr->kill('KILL')->join();
}

# EOF
