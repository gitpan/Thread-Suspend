use strict;
use warnings;


our @DONE :shared;

$SIG{'KILL'} = sub {
    $DONE[threads->tid()] = 1;
    threads->exit();
};


our @COUNTS :shared;

sub counter
{
    my $tid = threads->tid();
    while (1) {
        {
            lock(@COUNTS);
            $COUNTS[$tid]++;
        }
        threads->yield();
    }
}


sub pause
{
    threads->yield() for (1..$::nthreads);
    select(undef, undef, undef, shift);
    threads->yield() for (1..$::nthreads);
}

sub check {
    my ($thr, $running, $line) = @_;
    my $tid = $thr->tid();
    my ($begin, $end);
    pause(0.1);
    {
        lock(@COUNTS);
        $COUNTS[$tid] = 0;
    }
    pause(0.1);
    {
        lock(@COUNTS);
        $begin = $COUNTS[$tid];
    }
    pause(0.5);
    {
        lock(@COUNTS);
        $end = $COUNTS[$tid];
    }
    if ($running eq 'running') {
        my $delta = $end - $begin;
        ok($begin < $end, "Thread $tid running (delta=$delta) (see line $line)");
    } else {
        is($end, 0, "Thread $tid stopped (see line $line)");
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
