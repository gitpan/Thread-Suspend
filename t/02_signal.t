use strict;
use warnings;

BEGIN {
    use Config;
    if (! $Config{'useithreads'}) {
        print("1..0 # Skip: Perl not compiled with 'useithreads'\n");
        exit(0);
    }
}

use threads;
use threads::shared;


### Preamble ###

our $nthreads;
BEGIN { $nthreads = 2; }
use Test::More 'tests' => 5 + 18 * $nthreads;

### Load module ###

use_ok('Thread::Suspend', 'SIGILL');


### Setup ###

require 't/test.pl';

my @threads = make_threads($nthreads);


### Functionality testing ###

foreach my $thr (@threads) {
    my $tid = $thr->tid();

    ok(! threads->is_suspended(), 'No threads suspended');
    is($thr->is_suspended(), 0, "Thread $tid not suspended");
    check($thr, 'running', __LINE__);

    $thr->suspend();
    threads->yield();
    is(scalar(threads->is_suspended()), 1, 'One thread suspended');
    ok((threads->is_suspended())[0] == $thr, "Thread $tid suspended");
    is($thr->is_suspended(), 1, "Thread $tid suspended");
    check($thr, 'stopped', __LINE__);

    $thr->suspend();
    threads->yield();
    is(scalar(threads->is_suspended()), 1, 'One thread suspended');
    ok((threads->is_suspended())[0] == $thr, "Thread $tid suspended");
    is($thr->is_suspended(), 2, "Thread $tid suspended twice");
    check($thr, 'stopped', __LINE__);

    $thr->resume();
    threads->yield();
    is(scalar(threads->is_suspended()), 1, 'One thread suspended');
    ok((threads->is_suspended())[0] == $thr, "Thread $tid suspended");
    is($thr->is_suspended(), 1, "Thread $tid still suspended");
    check($thr, 'stopped', __LINE__);

    $thr->resume();
    threads->yield();
    ok(! threads->is_suspended(), 'No threads suspended');
    is($thr->is_suspended(), 0, "Thread $tid not suspended");
    check($thr, 'running', __LINE__);
}

# Cleanup
$_->kill('KILL')->join() foreach (@threads);


SKIP: {
    skip('Test::More broken WRT threads in 5.8.0', 3) if ($] == 5.008);
    $SIG{'ILL'} = sub {
        is(shift, 'ILL', 'Received suspend signal');
    };

    my $thr = threads->create('counter');

    is($thr->suspend(), $thr, 'Sent suspend signal');
    pause(0.1);
    is($thr->kill('KILL'), $thr, 'Thread killed');
    $thr->join();
}

# EOF
