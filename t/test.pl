use strict;
use warnings;


our @DONE :shared;

$SIG{'KILL'} = sub {
    $DONE[threads->tid()] = 1;
    threads->exit();
};


our %COUNTS :shared;

sub counter
{
    my $tid = threads->tid();
    while (1) {
        delete($COUNTS{$tid});
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
    my ($thr, $running, $line) = @_;
    my $tid = $thr->tid();

    delete($COUNTS{$tid});
    if (exists($COUNTS{$tid})) {
        ok(0, "BUG: \$COUNTS{$tid} not deleted");
    }
    $COUNTS{$tid} = $tid;

    if ($running eq 'running') {
        for (1..100) {
            pause(0.1);
            last if (! exists($COUNTS{$tid}));
        }
        ok(! exists($COUNTS{$tid}), "Thread $tid $running (see line $line)");
    } else {
        for (1..3) {
            pause(0.1);
            last if (! exists($COUNTS{$tid}));
        }
        ok(exists($COUNTS{$tid}), "Thread $tid $running (see line $line)");
    }
}


sub make_threads
{
    my $nthreads = shift;
    my @threads;
    push(@threads, threads->create('counter')) for (1..$nthreads);
    is(scalar(threads->list()), $nthreads, 'Threads created');
    return @threads;
}

1;
