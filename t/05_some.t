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
    unshift(@threads, threads->create('thr_func'));
}
threads->yield();
sleep(1);

is(scalar(threads->list()), 3, 'Threads created');
ok(! threads->is_suspended(), 'No threads suspended');
foreach my $thr (@threads) {
    my $tid = $thr->tid();
    is($thr->is_suspended(), 0, "Thread $tid not suspended");
    check($thr, 'running');
}


my @suspended = threads->suspend($threads[0], $threads[1]->tid());
threads->yield();
sleep(1);
is(scalar(@suspended), 2, 'Suspended threads');
foreach my $thr (@suspended) {
    is(scalar(grep { $_ == $thr } @threads), 1, 'Thread suspended');
}

is(scalar(threads->is_suspended()), 2, '2 threads suspended');
foreach my $thr (threads->is_suspended()) {
    is(scalar(grep { $_ == $thr } @threads), 1, 'In suspend list');
}

is(scalar($threads[0]->is_suspended()), 1, 'Thread suspended');
is(scalar($threads[1]->is_suspended()), 1, 'Thread suspended');
is(scalar($threads[2]->is_suspended()), 0, 'Thread not suspended');

@suspended = threads->suspend($threads[2]->tid, $threads[1]);
threads->yield();
sleep(1);
is(scalar(@suspended), 2, 'Suspended threads');
foreach my $thr (@suspended) {
    is(scalar(grep { $_ == $thr } @threads), 1, 'Thread suspended');
}

is(scalar(threads->is_suspended()), 3, '3 threads suspended');
foreach my $thr (threads->is_suspended()) {
    is(scalar(grep { $_ == $thr } @threads), 1, 'In suspend list');
}

is(scalar($threads[0]->is_suspended()), 1, 'Thread suspended');
is(scalar($threads[1]->is_suspended()), 2, 'Thread suspended twice');
is(scalar($threads[2]->is_suspended()), 1, 'Thread suspended');
foreach my $thr (@threads) {
    my $tid = $thr->tid();
    check($thr, 'stopped');
}

is(scalar(threads->resume($threads[1], $threads[1]->tid())), 2, 'Resume thread twice');
threads->yield();
sleep(1);
is(scalar($threads[1]->is_suspended()), 0, 'Thread not suspended');
check($threads[1], 'running');

is(scalar(threads->resume($threads[2], $threads[0]->tid())), 2, 'Resuming threads');
threads->yield();
sleep(1);
foreach my $thr (@threads) {
    my $tid = $thr->tid();
    is($thr->is_suspended(), 0, "Thread $tid not suspended");
    check($thr, 'running');
}

# Test with detached threads

$threads[2]->detach();
ok($threads[2]->is_detached(), 'Thread detached');
is(scalar(threads->list()), 2, 'Non-detached threads');

@suspended = threads->suspend($threads[1]->tid(), $threads[2]);
threads->yield();
sleep(1);
is(scalar(@suspended), 2, 'Suspended threads');
foreach my $thr (@suspended) {
    is(scalar(grep { $_ == $thr } @threads), 1, 'Thread suspended');
}

is(scalar(threads->is_suspended()), 1, '1 non-detached thread suspended');
foreach my $thr (threads->is_suspended()) {
    is(scalar(grep { $_ == $thr } @threads), 1, 'In suspend list');
}

is(scalar($threads[0]->is_suspended()), 0, 'Thread not suspended');
is(scalar($threads[1]->is_suspended()), 1, 'Thread suspended');
is(scalar($threads[2]->is_suspended()), 1, 'Thread suspended');

@suspended = threads->suspend($threads[2]);
threads->yield();
sleep(1);
is(scalar(@suspended), 1, 'Suspended thread');
foreach my $thr (@suspended) {
    is(scalar(grep { $_ == $thr } @threads), 1, 'Thread suspended');
}
is(scalar($threads[2]->is_suspended()), 2, 'Thread suspended twice');

is($threads[0]->suspend, $threads[0], 'Suspended last thread');
threads->yield();
sleep(1);

foreach my $thr (@threads) {
    my $tid = $thr->tid();
    check($thr, 'stopped');
}

is(scalar(threads->resume($threads[2], $threads[2])), 2, 'Resume thread twice');
threads->yield();
sleep(1);
is(scalar($threads[2]->is_suspended()), 0, 'Thread not suspended');
check($threads[2], 'running');

is(scalar(threads->resume($threads[1], $threads[0]->tid())), 2, 'Resuming threads');
threads->yield();
sleep(1);

@suspended = threads->suspend($threads[2]->tid());
threads->yield();
sleep(1);
ok(! @suspended, 'Cannot suspend detached thread using TID');

foreach my $thr (@threads) {
    my $tid = $thr->tid();
    is($thr->is_suspended(), 0, "Thread $tid not suspended");
    check($thr, 'running');
    is($thr->kill('KILL'), $thr, 'Killing thread');
}
threads->yield();

# Cleanup

$threads[0]->join();
$threads[1]->join();

foreach my $thr (@threads) {
    my $tid = $thr->tid();
    while (! exists($DONE{$tid})) {
        sleep(1);
    }
}

# EOF
