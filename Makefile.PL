require 5.008;
use threads (); # just to force breakage if threads are not available
use ExtUtils::MakeMaker;
eval "use Devel::Required";

WriteMakefile (
 NAME		=> "Thread::Suspend",
 AUTHOR		=> 'Elizabeth Mattijsen (liz@dijkmat.nl)',
 ABSTRACT	=> 'suspend and resume threads from other threads',
 VERSION_FROM	=> 'lib/Thread/Suspend.pm',
 PREREQ_PM	=> {
		   'load' => 0,
		   'Thread::Signal' => 0.07,
                   },
);
