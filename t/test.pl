use strict;
use warnings;


our @DONE :shared;

$SIG{'KILL'} = sub {
    $DONE[threads->tid()] = 1;
    threads->exit();
};


our %CHECKER :shared;

sub checker
{
    my $tid = threads->tid();
    while (1) {
        delete($CHECKER{$tid});
        threads->yield();
    }
}


sub pause
{
    threads->yield() for (0..$::nthreads);
    select(undef, undef, undef, shift);
    threads->yield() for (0..$::nthreads);
}

sub check {
    my ($thr, $state, $line) = @_;
    my $tid = $thr->tid();

    pause(0.1);
    delete($CHECKER{$tid});
    if (exists($CHECKER{$tid})) {
        ok(0, "BUG: \$CHECKER{$tid} not deleted");
    }
    $CHECKER{$tid} = $tid;

    if ($state eq 'running') {
        for (1..100) {
            pause(0.1);
            last if (! exists($CHECKER{$tid}));
        }
        ok(! exists($CHECKER{$tid}), "Thread $tid $state (line $line)");
    } else {
        for (1..3) {
            pause(0.1);
            last if (! exists($CHECKER{$tid}));
        }
        ok(exists($CHECKER{$tid}), "Thread $tid $state (line $line)");
    }
}


sub make_threads
{
    my $nthreads = shift;
    my @threads;
    push(@threads, threads->create('checker')) for (1..$nthreads);
    is(scalar(threads->list()), $nthreads, 'Threads created');
    return @threads;
}

1;
