#!/usr/bin/env perl
use strict;
use warnings;

# Copyright 2012  Johns Hopkins University (Author: Daniel Povey).
#           2014  Johns Hopkins University (Author: Vimal Manohar)
#           2015  Queensland University of Technology (Author: Ahilan Kanagasundaram <a.kanagasundaram@qut.edu.au>)
# Apache 2.0.

use File::Basename;
use Cwd;
use Getopt::Long;
use Carp;

# This is a version of the queue.pl modified so that it works under PBS
# The PBS PRO is one of the several "almost compatible" queueing systems. The
# command switches and environment variables are different, so we are adding
# a this script. An optimal solution might probably be to make the variable
# names and the commands configurable, as similar problems can be expected
# with Torque, Univa... and who knows what else
#
# pbspro.pl has the same functionality as run.pl, except that
# it runs the job in question on the queue (PBS).
# This version of queue.pl uses the task array functionality
# of PBS.  
# The script now supports configuring the queue system using a config file
# (default in conf/pbspro.conf
my $qsub_opts = "";

my $gpu = 0;
my $config = "conf/pbspro.conf";

my $jobname = 'JOB';
my $jobstart = 0;
my $jobend = 1;
my $job_stepping_factor = 1;
my $array_job = 0;
$ARGV[0] =~ /^JOB=(\d+):(\d+)$/;
$jobstart = $1;
$jobend = $2;
if ( defined $jobend and $jobend > 1 ) {
  $array_job = 1;
}

shift;


my $cwd = getcwd();
my @remaining_commandline = @ARGV;
my $logfile = shift @ARGV;
if ($array_job == 1 && $logfile !~ m/$jobname/
    && $jobend > $jobstart) {
  warn "pbspro.pl: you are trying to run a parallel job but "
    . "you are putting the output into just one log file ($logfile)\n"
    . "jobname: $jobname";
}

#
# Work out the command; quote escaping is done here.
# Note: the rules for escaping stuff are worked out pretty
# arbitrarily, based on what we want it to do.  Some things that
# we pass as arguments to pbspro.pl, such as "|", we want to be
# interpreted by bash, so we don't escape them.  Other things,
# such as archive specifiers like 'ark:gunzip -c foo.gz|', we want
# to be passed, in quotes, to the Kaldi program.  Our heuristic
# is that stuff with spaces in should be quoted.  This doesn't
# always work.
#
my $cmd = "";
foreach my $x (@remaining_commandline) {
  if ($x =~ /^\S+$/) {
    $cmd .= $x . " " 
  } elsif ($x =~ m:\":) {
    $cmd .= "'$x' ";
  }   else {
    $cmd .= "\"$x\" ";
  }
}

# Work out the location of the script file, and open it for writing.
#
my $dir = dirname $logfile;
my $base = basename($logfile);
my $qdir = "$dir/q";
$qdir =~ s:/(log|LOG)/*q:/q:; # If qdir ends in .../log/q, make it just .../q.
my $queue_logfile = "$qdir/$base";

if (!-d $dir) {
  system "mkdir -p $dir 2>/dev/null";
} # another job may be doing this...
if (!-d $dir) {
  croak "Cannot make the directory $dir\n";
}
# make a directory called "q",
# where we will put the log created by qsub... normally this doesn't contain
# anything interesting, evertyhing goes to $logfile.

if (! -d "$qdir") {
  system "mkdir $qdir 2>/dev/null";
  sleep(5); ## This is to fix an issue we encountered in denominator lattice creation,
  ## where if e.g. the exp/tri2b_denlats/log/15/q directory had just been
  ## created and the job immediately ran, it would die with an error because nfs
  ## had not yet synced.  I'm also decreasing the acdirmin and acdirmax in our
  ## NFS settings to something like 5 seconds.
}

my $queue_array_opt = "";

if ($array_job == 1) {
  $queue_array_opt = "-J $jobstart-$jobend";
  $logfile =~ s/\$jobname/\$PBS_ARRAY_INDEX/g;
  #  $logfile will get replaced by qsub, in each job, with the job-id.
  $cmd =~ s/$jobname/\$\{PBS_ARRAY_INDEX\}/g; # same for the command...
  $queue_logfile =~ s/\.?$jobname//;
# the log file in the q/ subdirectory
# is for the queue to put its log, and this doesn't need the task array subscript
  # so we remove it.
}
warn "hello\t$cmd\t$logfile";
# queue_scriptfile is as $queue_logfile [e.g. dir/q/foo.log] but
# with the suffix .sh.
my $queue_scriptfile = $queue_logfile;
($queue_scriptfile =~ s/\.[a-zA-Z]{1,5}$/.sh/) || ($queue_scriptfile .= ".sh");
if ($queue_scriptfile !~ m:^/:) {
  $queue_scriptfile = $cwd . "/" . $queue_scriptfile; # just in case.
}

# We'll write to the standard input of "qsub" (the file-handle Q),
# the job that we want it to execute.
# Also keep our current PATH around, just in case there was something
# in it that we need (although we also source ./path.sh)

my $syncfile = "$qdir/done.$$";

system("rm $queue_logfile $syncfile 2>/dev/null");
#
# Write to the script file, and then close it.
#
open my $Q, '>', $queue_scriptfile or croak "Failed to write to $queue_scriptfile $!";

print $Q "#!/bin/bash\n";
print $Q "cd $cwd\n";
print $Q ". ./path.sh\n";
print $Q "( echo '#' Running on \`hostname\`\n";
print $Q "  echo '#' Started at \`date\`\n";
print $Q "  echo -n '# '; cat <<EOF\n";
print $Q "$cmd\n"; # this is a way of echoing the command into a comment in the log file,
print $Q "EOF\n"; # without having to escape things like "|" and quote characters.
print $Q ") >$logfile\n";
print $Q "time1=\`date +\"%s\"\`\n";
print $Q " ( $cmd ) 2>>$logfile >>$logfile\n";
print $Q "ret=\$?\n";
print $Q "time2=\`date +\"%s\"\`\n";
print $Q "echo '#' Accounting: time=\$((\$time2-\$time1)) >>$logfile\n";
print $Q "echo '#' Finished at \`date\` with status \$ret >>$logfile\n";
print $Q "[ \$ret -eq 137 ] && exit 100;\n"; # If process was killed (e.g. oom) it will exit with status 137;
  # let the script return with status 100 which will put it to E state; more easily rerunnable.
if ($array_job == 0) { # not an array job
  print $Q "touch $syncfile\n"; # so we know it's done.
} else {
  print $Q "touch $syncfile.\$PBS_ARRAY_INDEX\n"; # touch a bunch of sync-files.
}
print $Q "exit \$[\$ret ? 1 : 0]\n"; # avoid status 100 which grid-engine
print $Q "## submitted with:\n";       # treats specially.
my $qsub_cmd .= "-o $queue_logfile $qsub_opts $queue_array_opt $queue_scriptfile >>$queue_logfile 2>&1";

print $Q "# $qsub_cmd\n";
if (!close $Q) { # close was not successful... || croak "Could not close script file $shfile $!";
  croak "Failed to close the script file (full disk?)";
}

my $ret = system ($qsub_cmd);
if ($ret != 0) {
  print STDERR "pbspro.pl: error submitting jobs to queue (return status was $ret)\n";
  print STDERR "queue log file is $queue_logfile, command was $qsub_cmd\n";
  print STDERR `tail $queue_logfile`;
  exit(1);
}

my $pbs_job_id;

# need to wait for the jobs to finish.  We wait for the
# sync-files we "touched" in the script to exist.
my @syncfiles = ();
#if (!defined $jobname) { # not an array job.
if ( $array_job == 0 ) { # not an array job.
  push @syncfiles, $syncfile;
} else {
  for (my $jobid = $jobstart; $jobid <= $jobend; $jobid++) {
    push @syncfiles, "$syncfile.$jobid";
  }
}
# We will need the pbs_job_id, to check that job still exists
{ # Get the PBS job-id from the log file in q/
  open my $L, '<', $queue_logfile || die "Error opening log file $queue_logfile";
  undef $pbs_job_id;
  while (<$L>) {
    if (/(\d+.+\.pbsserver)/) {
      if (defined $pbs_job_id) {
        die "Error: your job was submitted more than once (see $queue_logfile)";
      } else {
        $pbs_job_id = $1;
      }
    }
  }
  close $L;
  if (!defined $pbs_job_id) {
    die "Error: log file $queue_logfile does not specify the PBS job-id.";
  }
}
my $check_pbs_job_ctr=1;
#
my $wait = 0.1;
my $counter = 0;
foreach my $f (@syncfiles) {
  # wait for them to finish one by one.
  while (! -f $f) {
    sleep($wait);
    $wait *= 1.2;
    if ($wait > 3.0) {
      $wait = 3.0; # never wait more than 3 seconds.
      # the following (.kick) commands are basically workarounds for NFS bugs.
      if (rand() < 0.25) { # don't do this every time...
        if (rand() > 0.5) {
          system("touch $qdir/.kick");
        } else {
          system("rm $qdir/.kick 2>/dev/null");
        }
      }
      if ($counter++ % 10 == 0) {
        # This seems to kick NFS in the teeth to cause it to refresh the
        # directory.  I've seen cases where it would indefinitely fail to get
        # updated, even though the file exists on the server.
        # Only do this every 10 waits (every 30 seconds) though, or if there
        # are many jobs waiting they can overwhelm the file server.
        system("ls $qdir >/dev/null");
      }
    }

    # Check that the job exists in PBS. Job can be killed if duration
    # exceeds some hard limit, or in case of a machine shutdown.
    if (($check_pbs_job_ctr++ % 10) == 0) { # Don't run qstat too often, avoid stress on PBS.
      if ( -f $f ) { next; }; #syncfile appeared: OK.
      $ret = system("qstat -t $pbs_job_id >/dev/null 2>/dev/null");
      # system(...) : To get the actual exit value, shift $ret right by eight bits.
      if ($ret>>8 == 1) {     # Job does not seem to exist
        # Don't consider immediately missing job as error, first wait some
        # time to make sure it is not just delayed creation of the syncfile.

        sleep(3);
        # Sometimes NFS gets confused and thinks it's transmitted the directory
        # but it hasn't, due to timestamp issues.  Changing something in the
        # directory will usually fix that.
        system("touch $qdir/.kick");
        system("rm $qdir/.kick 2>/dev/null");
        if ( -f $f ) { next; }   #syncfile appeared, ok
        sleep(7);
        system("touch $qdir/.kick");
        sleep(1);
        system("rm $qdir/.kick 2>/dev/null");
        if ( -f $f ) {  next; }   #syncfile appeared, ok
        sleep(60);
        system("touch $qdir/.kick");
        sleep(1);
        system("rm $qdir/.kick 2>/dev/null");
        if ( -f $f ) { next; }  #syncfile appeared, ok
        $f =~ m/\.(\d+)$/ || die "Bad sync-file name $f";
        my $job_id = $1;
        if (defined $jobname) {
          $logfile =~ s/\$PBS_ARRAY_INDEX/$job_id/g;
        }
        my $last_line = `tail -n 1 $logfile`;
        if ($last_line =~ m/status 0$/ && (-M $logfile) < 0) {
          # if the last line of $logfile ended with "status 0" and
          # $logfile is newer than this program [(-M $logfile) gives the
          # time elapsed between file modification and the start of this
          # program], then we assume the program really finished OK,
          # and maybe something is up with the file system.
          print STDERR "**pbspro.pl: syncfile $f was not created but job seems\n" .
            "**to have finished OK.  Probably your file-system has problems.\n" .
            "**This is just a warning.\n";
          last;
        } else {
          chop $last_line;
          print STDERR "pbspro.pl: Error, unfinished job no " .
            "longer exists, log is in $logfile, last line is '$last_line', " .
            "syncfile is $f, return status of qstat was $ret\n" .
            "Possible reasons: a) Exceeded time limit? -> Use more jobs!" .
            " b) Shutdown/Frozen machine? -> Run again!\n";
          exit(1);
        }
      } elsif ($ret != 0) {
        print STDERR "pbspro.pl: Warning: qstat command returned status $ret (qstat -t $pbs_job_id,$!)\n";
      }
    }
  }
}
my $all_syncfiles = join(" ", @syncfiles);
system("rm $all_syncfiles 2>/dev/null");


# OK, at this point we are synced; we know the job is done.
# But we don't know about its exit status.  We'll look at $logfile for this.
# First work out an array @logfiles of file-locations we need to
# read (just one, unless it's an array job).
my @logfiles = ();
if (!defined $jobname) { # not an array job.
  push @logfiles, $logfile;
} else {
  for (my $jobid = $jobstart; $jobid <= $jobend; $jobid++) {
    my $l = $logfile;
    $l =~ s/\$PBS_ARRAY_INDEX/$jobid/g;
    push @logfiles, $l;
  }
}

my $num_failed = 0;
my $status = 1;
foreach my $l (@logfiles) {
  my @wait_times = (0.1, 0.2, 0.2, 0.3, 0.5, 0.5, 1.0, 2.0, 5.0, 5.0, 5.0, 10.0, 25.0);
  for (my $iter = 0; $iter <= @wait_times; $iter++) {
    my $line = `tail -10 $l 2>/dev/null`; # Note: although this line should be the last
    # line of the file, I've seen cases where it was not quite the last line because
    # of delayed output by the process that was running, or processes it had called.
    # so tail -10 gives it a little leeway.
    if ($line =~ m/with status (\d+)/) {
      $status = $1;
      last;
    } else {
      if ($iter < @wait_times) {
        sleep($wait_times[$iter]);
      } else {
        if (! -f $l) {
          print STDERR "Log-file $l does not exist.\n";
        } else {
          print STDERR "The last line of log-file $l does not seem to indicate the "
            . "return status as expected\n";
        }
        exit(1);                # Something went wrong with the queue, or the
        # machine it was running on, probably.
      }
    }
  }
  # OK, now we have $status, which is the return-status of
  # the command in the job.
  if ($status != 0) { $num_failed++; }
}
if ($num_failed == 0) { exit(0); }
else { # we failed.
  if (@logfiles == 1) {
    if (defined $jobname) { $logfile =~ s/\$PBS_ARRAY_INDEX/$jobstart/g; }
    print STDERR "pbspro.pl: job failed with status $status, log is in $logfile\n";
    if ($logfile =~ /JOB/) {
      print STDERR "pbspro.pl: probably you forgot to put JOB=1:\$nj in your script.\n";
    }
  } else {
    if (defined $jobname) { $logfile =~ s/\$PBS_ARRAY_INDEX/*/g; }
    my $numjobs = 1 + $jobend - $jobstart;
    print STDERR "pbspro.pl: $num_failed / $numjobs failed, log is in $logfile\n";
  }
  exit(1);
}
