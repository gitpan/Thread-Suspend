use strict;
use warnings;

use threads;
use threads::shared;

use Test::More 'tests' => 84;

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

# Test all threads

my @suspended = threads->suspend();
threads->yield();
sleep(1);
is(scalar(@suspended), 3, 'Suspended threads');
foreach my $thr (@suspended) {
    is(scalar(grep { $_ == $thr } @threads), 1, 'Thread suspended');
}

is(scalar(threads->is_suspended()), 3, '3 threads suspended');
foreach my $thr (threads->is_suspended()) {
    is(scalar(grep { $_ == $thr } @threads), 1, 'In suspend list');
}

foreach my $thr (@threads) {
    my $tid = $thr->tid();
    is($thr->is_suspended(), 1, "Thread $tid suspended");
    check($thr, 'stopped');
}

is(scalar(threads->suspend()), 3, 'Suspending again');
threads->yield();
sleep(1);
foreach my $thr (@threads) {
    my $tid = $thr->tid();
    is($thr->is_suspended(), 2, "Thread $tid suspended");
    check($thr, 'stopped');
}

is(scalar(threads->resume()), 3, 'Resuming once');
threads->yield();
sleep(1);
foreach my $thr (@threads) {
    my $tid = $thr->tid();
    is($thr->is_suspended(), 1, "Thread $tid suspended");
    check($thr, 'stopped');
}

is(scalar(threads->resume()), 3, 'Resuming again');
threads->yield();
sleep(1);
foreach my $thr (@threads) {
    my $tid = $thr->tid();
    is($thr->is_suspended(), 0, "Thread $tid not suspended");
    check($thr, 'running');
}

# Test threads with extra suspends

is($threads[1]->suspend(), $threads[1], 'Suspend thread');
threads->yield();
sleep(1);
is(scalar(threads->is_suspended()), 1, '1 thread suspended');
check($threads[1], 'stopped');

@suspended = threads->suspend();
threads->yield();
sleep(1);
is(scalar(@suspended), 3, 'Suspended threads');
foreach my $thr (@suspended) {
    is(scalar(grep { $_ == $thr } @threads), 1, 'Thread suspended');
}
is(scalar($threads[0]->is_suspended()), 1, 'Thread suspended');
is(scalar($threads[1]->is_suspended()), 2, '1 thread suspended twice');
is(scalar($threads[2]->is_suspended()), 1, 'Thread suspended');
foreach my $thr (@threads) {
    my $tid = $thr->tid();
    check($thr, 'stopped');
}

is(scalar(threads->resume()), 3, 'Resuming threads');
threads->yield();
sleep(1);
is(scalar($threads[0]->is_suspended()), 0, 'Thread not suspended');
is(scalar($threads[1]->is_suspended()), 1, 'Thread suspended');
is(scalar($threads[2]->is_suspended()), 0, 'Thread not suspended');
check($threads[1], 'stopped');

is($threads[1]->resume(), $threads[1], 'Thread resumed');
threads->yield();
sleep(1);

foreach my $thr (@threads) {
    my $tid = $thr->tid();
    is($thr->is_suspended(), 0, "Thread $tid not suspended");
    check($thr, 'running');
}

# Test with detached threads

$threads[1]->detach();
ok($threads[1]->is_detached(), 'Thread detached');

@suspended = threads->suspend();
threads->yield();
sleep(1);
is(scalar(@suspended), 2, 'Suspended threads');
is(scalar(grep { $_ == $threads[0] } @suspended), 1, 'Thread suspended');
is(scalar(grep { $_ == $threads[2] } @suspended), 1, 'Thread suspended');
is(scalar($threads[1]->is_suspended()), 0, 'Thread not suspended');

is(scalar(threads->resume()), 2, 'Resuming threads');
threads->yield();
sleep(1);

foreach my $thr (@threads) {
    my $tid = $thr->tid();
    is($thr->is_suspended(), 0, "Thread $tid not suspended");
    check($thr, 'running');
    is($thr->kill('KILL'), $thr, 'Killing thread');
}
threads->yield();

# Cleanup

$threads[0]->join();
$threads[2]->join();

foreach my $thr (@threads) {
    my $tid = $thr->tid();
    while (! exists($DONE{$tid})) {
        sleep(1);
    }
}

# EOF
