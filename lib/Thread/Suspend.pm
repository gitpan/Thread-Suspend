package Thread::Suspend;

# Make sure we have version info for this module
# Make sure we do everything by the book from now on

$VERSION = '0.02';
use strict;

# Only load the things that are necessary

use load;

# Make sure we can do threads
# Make sure we can do shared variables

use threads ();
use threads::shared ();

# Initialize reference to running check

our $running =
 defined( $Thread::Running::VERSION ) ? \&Thread::Running::running  : '';
    
# Hash with suspended thread ID's

our @suspended : shared;

# Initialize signal to be used at compile time

our $signal; BEGIN { $signal = 'CONT' };

# Initialize the busy flag

our $busy = 0;

# Set the signal handler to be used
# Make sure it is always inherited

use Thread::Signal $signal => \&_suspending;
Thread::Signal->automatic( $signal );

# Satisfy -require-

1;

#---------------------------------------------------------------------------

# Stuff that should really be in threads.pm

#---------------------------------------------------------------------------
#  IN: 1 class (ignored) or object to be checked
#      2..N additional thread (ID's) that should be checked (default: all)
# OUT: 1..N thread ID's that are still running

sub threads::suspend {

# Lose the class
# Go do the actual check

    shift unless ref $_[0];
    goto &suspend;
} #threads::suspend

#---------------------------------------------------------------------------
#  IN: 1 class (ignored) or object to be checked
#      2..N additional thread (ID's) that should be checked (default: all)
# OUT: 1..N thread ID's that can be join()ed

sub threads::resume {

# Lose the class
# Go do the actual check

    shift unless ref $_[0];
    goto &resume;
} #threads::resume

#---------------------------------------------------------------------------
#  IN: 1 class/object (ignored)

sub threads::iambusy { goto &iambusy } #threads::iambusy

#---------------------------------------------------------------------------
#  IN: 1 class/object (ignored)

sub threads::iamdone { goto &iamdone } #threads::iamdone

#---------------------------------------------------------------------------
# NOTE: signal handling subroutine _must_ exist and cannot be AUTOLOADed

sub _suspending {

# Return now if we are busy

    return if $busy;

# Obtain the thread ID
# While we're supposed to be suspended
#  Wait until we can get a lock
#  Release the lock, wait until someone tells us to check again

    my $tid = threads->tid;
    while ($suspended[$tid]) {
        {
         lock @suspended;
         threads::shared::cond_wait( @suspended );
        }
    }
} #_suspending

#---------------------------------------------------------------------------

# All the following subroutines are loaded only when they are needed

__END__

#---------------------------------------------------------------------------

# The subroutines

#---------------------------------------------------------------------------
#  IN: 1..N thread (ID's) that should be checked (default: all)
# OUT: 1..N thread ID's that have been suspended

sub suspend {

# Initialize the thread ID's
# Set default thread ID's to handle if none specified
#  Make sure we're the only ones accessing

    my @tid;
    @_ = _running() unless @_;
    {
        lock @suspended;

#  For all of the threads specified
#   Make sure we have a thread ID
#   Reloop if already suspended
#   Mark this thread as suspended
#   Add this thread to the list

        foreach (@_) {
            my $tid = ref( $_ ) ? $_->tid : $_;
            next if $suspended[$tid];
            $suspended[$tid] = time();
            push @tid,$tid;
        }
    }

# Signal the threads
# Return list of thread ID's or whether all have been suspended

    Thread::Signal->signal( $signal, @tid );
    return wantarray ? @tid : @tid == @_;
} #suspend

#---------------------------------------------------------------------------
#  IN: 1..N thread (ID's) that should be checked (default: all)
# OUT: 1..N threads that have been resumed

sub resume {

# Initialize the list of thread ID's
# Set the list of thread ID's to handle if not set already
#  Make sure we're the only one accessing

    my @tid;
    @_ = _suspended() unless @_;
    {
        lock (@suspended );

#  For all of the threads specified
#   Make sure we have a thread ID
#   Reloop if this thread not suspended
#   Mark thread for resume
#   Save the thread ID on the list

        foreach (@_) {
            my $tid = ref( $_ ) ? $_->tid : $_;
            next unless $suspended[$tid];
            $suspended[$tid] = 0;
            push @tid,$tid;
        }

#  Wake up all the threads, the resuming ones will resume
# Return list of thread ID's or whether all have resumed

        threads::shared::cond_broadcast( @suspended );
    }
    return wantarray ? @tid : @tid == @_;
} #resume

#---------------------------------------------------------------------------
#  IN: 1 class/object (ignored)

sub iambusy { $busy++ } #iambusy

#---------------------------------------------------------------------------
#  IN: 1 class/object (ignored)

sub iamdone { _suspending() if $busy and !--$busy } #iamdone

#---------------------------------------------------------------------------

# Methods needed by Perl

#---------------------------------------------------------------------------
#  IN: 1 class
#      2..N subroutines to export

sub import {

# Lose the class
# Obtain the namespace
# Set the defaults if nothing specified
# Allow for evil stuff
# Export whatever needs to be exported

    shift;
    my $namespace = (scalar caller() ).'::';
    @_ = qw(suspend resume iambusy iamdone) unless @_;
    no strict 'refs';
    *{$namespace.$_} = \&$_ foreach @_;
} #import

#---------------------------------------------------------------------------

# Internal subroutines

#---------------------------------------------------------------------------
# OUT: 1..N all the thread ID's currently running (including detached threads)

sub _running { $running ? &$running : () } #_running

#---------------------------------------------------------------------------
# OUT: 1..N all the thread ID's currently suspended (including detached threads)

sub _suspended {

# Make sure we are the only ones with access
# Return the list of suspended thread

    lock @suspended;
    map {$suspended[$_] ? ($_) : ()} 0..$#suspended;
} #_suspended

#---------------------------------------------------------------------------

__END__

=head1 NAME

Thread::Suspend - suspend and resume threads from another thread

=head1 SYNOPSIS

    use Thread::Suspend;             # exports suspend, resume, iambusy, iamdone
    use Thread::Suspend qw(suspend); # only exports suspend()
    use Thread::Suspend ();          # threads class methods only

    my $thread = threads->new( sub { whatever } );
    $thread->suspend;                # suspend thread by object
    threads->suspend( $thread );     # also
    threads->suspend( $tid );        # suspend by thread ID
    threads->suspend;                # suspend all (other) threads

    $thread->resume;                 # resume a single thread
    threads->resume;                 # resume all suspended threads

    threads->iambusy;                # don't allow suspending in thread
    threads->iamdone;                # allow suspending again in thread

=head1 DESCRIPTION

                  *** A note of CAUTION ***

 This module only functions on Perl versions 5.8.0 and later.
 And then only when threads are enabled with -Dusethreads.  It
 is of no use with any version of Perl before 5.8.0 or without
 threads enabled.

                  *************************

This module adds one feauture to threads that are sorely missed by some:
the capability to suspend execution of a thread and be able to resume it
when needed afterwards.

=head1 METHODS

These are the methods.

=head2 suspend

 $thread->suspend;                 # suspend execution of given thread
 threads->suspend( $thread );      # same
 threads->suspend( $thread->tid ); # same, but specified by thread ID

 threads->suspend;                 # suspend all other threads

The "suspend" method allows you to suspend the execution of one or more
threads.  It accepts one or more thread objects or thread ID's (as
obtained by the C<threads::tid()> method).

If called as a class method or as a subroutine without parameters, then it
will suspend all running threads but the current thread.  This can only
be done if L<Thread::Running> has been loaded prior to loading Thread::Suspend.

If called as an instance method without parameters, it will only check the
thread associated with the object.

If called in void context, then no check will be performed whether the
specified threads are actually suspended.  If called in scalar or list
context, the call will block until all specified threads have indicated
back that they've been suspended.  Due to latency, this may take a little
while.  By default a 5 second timeout will be applied: if the threads still
haven't indicated that they're suspended by then, then execution of the
current thread will continue.

In list context it returns the thread ID's of the threads that have indicated
that they have been suspended.  In scalar context, it returns 1 or 0 to
indicate whether all of the specified threads have indicated that they have
been suspended.

=head2 resume

 $thread->resume;                # resume execution of this thread
 threads->resume( $thread );     # same
 threads->resome( $thread->tid); # same

 threads->resume;                # resume all threads that were suspended

The "resume" method allows you to resume execution of one or more threads
that were previously suspended.  It accepts one or more thread objects
or thread ID's (as obtained by the C<threads::tid()> method).

If called as a class method or as a subroutine without parameters, then it
will check all threads of which it knows.  If called as an instance method
without parameters, it will only check the thread associated with the object.

If called in void context, then no check will be performed whether the
specified threads are actually resumed.  If called in scalar or list
context, the call will block until all specified threads have indicated
back that they've been resumed.  Due to latency, this may take a little
while.  By default a 5 second timeout will be applied: if the threads still
haven't indicated that they've resumed by then, then execution of the
current thread will continue.

In list context it returns thread id's of the threads that have resumed.
In scalar context, it just returns 1 or 0 to indicate whether all of the
(implicitely) indicated threads have resumed.

=head2 iambusy

 threads->iambusy;         # don't allow suspending right now
 iambusy();                # same

Sometimes you don't want certain sections of your code in a thread to be
interrupted.  The "iambusy" method can be called to indicate such a section.
It can either be called as a class method or a subroutine (if exported).

Call the L<iamdone> method to mark that the execution of the thread may
be suspended again from other threads.  Nested calls to "iambusy" are
allowed.  Only when each call to "iambusy" has been counteracted by a call
to "iamdone" is suspending of the current thread allowed again.

Please note that if you call the "iambusy" method at the beginning of the
execution of a thread, and never call the "iamdone" method in that thread,
then that thread  will B<never> get suspended.

=head2 iamdone

 threads->iamdone;         # allow suspending again in principle
 iamdone();                # same

The "iamdone" method can be called to indicate that the current thread may
be suspended again from another thread.  It is the opposite of L<iambusy>.
Please note that the number of "iamdone" method calls should counteract the
number of nested "iambusy" calls to really allow suspending of the current
thread again.

If suspending of the thread is allowed again, then immediate suspending of
the thread will occur if another thread asked for suspending of the current
thread while the current thread was busy.

=head1 CAVEATS

This module is dependent on the L<Thread::Signal> module, with all of its
CAVEATS applicable.  However, if you are using the L<iambusy> and L<iamdone>
methods to mark critical sections in your threaded code, this has the
side-effect of not having to have working signals on your system.  This is
caused by the fact that L<iamdone> checks the "suspended" flag without
having received a signal.

This module uses the L<load> module to make sure that subroutines are loaded
only when they are needed.

=head1 WHY NOT USE "SIGSTOP" AND "SIGCONT"?

Many operating systems already support the signals SIGSTOP (for halting
execution of a process) and SIGCONT (for continuing execution of a process).
The reason I've decided not to use that, is that in that way, execution
may be halted in critical sections of Perl.  This seemed like a Very Bad
Idea(tm).  Therefore a more general approach involving locking on a
shared array, was chosen.

=head1 TODO

Examples should be added.

=head1 AUTHOR

Elizabeth Mattijsen, <liz@dijkmat.nl>.

Please report bugs to <perlbugs@dijkmat.nl>.

=head1 COPYRIGHT

Copyright (c) 2003 Elizabeth Mattijsen <liz@dijkmat.nl>. All rights
reserved.  This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<threads>, L<Thread::Signal>, L<Thread::Running>, L<load>.

=cut
