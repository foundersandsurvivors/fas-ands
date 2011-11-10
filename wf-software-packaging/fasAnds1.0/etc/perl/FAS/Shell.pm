package FAS::Shell;

use strict;
use warnings FATAL => 'all';
use File::Basename;
use Date::Calc qw(:all);
$|=1; # by default

#----------------- call configure to ensure current work dir is the location of this script
sub configure {
    my $show = shift;
    die "$0 #ERR# bad environment, \$ENV{FASPLATFORM} not defined. Have you sourced a fas environment file?\n" unless ( $ENV{FASPLATFORM} );
    my ($name,$path,$suffix) = fileparse($0);
    my $dir = dirname($0);
    my $mydir = '';
    if    ($dir eq ".")              { $mydir = $ENV{PWD}; }
    elsif ( $dir =~ m~^\./(.+)$~ )   { $mydir = $ENV{PWD} . "/" . $1; }
    else                             { $mydir = $dir; }
    print STDERR "..  FAS::Shell::configure:\n  *name[$name]\n  *mydir[$mydir]\n  path[$path]\n  dir[$dir]\n  PWD[$ENV{PWD}]\n" if $ENV{DEBUG};
    chdir $mydir;
    $ENV{JOB_DIR} = $mydir;
    $ENV{JOB_SCRIPT} = $name;

    if ($show) {
        print "######################## [$show] start ".&nowTs."\n" if ($show);
    }
    else {
        print "######################## $ENV{JOB_SCRIPT} start ".&nowTs."\n" if ($show);
    }

    # read and define environment in .jobenv , if present

    if ( -f "./.jobenv" ) {
        print STDERR ".. reading .jobenv file ...\n" if $ENV{DEBUG};
        open (E,"./.jobenv") || &bad_eoj("failed to open $ENV{JOB_DIR}/.jobenv - permissions?");
        while (<E>) {
           if ( m/^export (\S+)="?(.+?)"?$/ ) {
              $ENV{$1} = $2;
              print "-- config .jobenv: ENV{$1} = [$ENV{$1}]\n" if ($show);
           }
        }
        close(E);
    }
    return;
}

sub eoj {
    print "# $0 normal eoj at ".&nowTs."\n";
}
sub bad_eoj {
    my $msg = shift;
    die "## ABNORMAL EOJ ## ERROR[".$msg."] in script: $ENV{JOB_DIR}/$ENV{JOB_SCRIPT} at ".&nowTs."\n";
}

sub nowTs {
    return sprintf ("%4d-%02d-%02dT%2d:%02d:%02d", Today_and_Now());
}

sub debug {
    print STDERR "-------- FAS::Shell::debug start\n";
    $ENV{DEBUG} = 1;
    &fasenv_print;
    print STDERR "..JOB_DIR[$ENV{JOB_DIR}] JOB_SCRIPT[$ENV{JOB_SCRIPT}] \$0[$0] ENV{PWD}=[$ENV{PWD}] \n";
    print STDERR "-------- FAS::Shell::debug end\n";
}

sub fasenv_print {
    my $filter = shift || "";
    print "-------- FAS::Shell::fasenv_print ($filter) start\n";
    foreach my $var (sort(keys(%ENV))) {
        my $val = $ENV{$var};
        $val =~ s|\n|\\n|g;
        $val =~ s|"|\\"|g;
        if ($filter) {
           print "${var}=\"${val}\"\n" if ( $var =~ m/$filter/ );
        }
        else {
           print "${var}=\"${val}\"\n" if ( $var =~ m/(PWD|FAS|JOB|SEE|BASEX|GOOGLE|JAVA|REDIS|SAXON|SHELL|USER)/ );
        }
    }
    print "-------- FAS::Shell::fasenv_print end\n";
}

############################################################################################ perlpod ducumentation:
=head2 Overview FAS::Shell 

The B<FAS::Shell> perl library is a set of B<common subroutines> useful in Fas/related perl shell/batch/workflow job control scripts. 
Use this library in perl jobs which are functioning as shell scripts.

=head2 Version 

FAS/1.0 (initial release for ANDS) 7 November 2011

=head2 Usage

use FAS::Shell;                     # invokation

FAS::Shell::configure($jobdesc);    # change to the dir containing $0 and optionally print a heading with $jobdesc to STDERR
                                    # Is silent if no $jobdesc given.
                                    # Sets env vars for B<JOB_DIR> and B<JOB_SCRIPT>
                                    # Adds any further environment variables found (^export=) in $ENV{JOB_DIR}/.jobenv

FAS::Shell::fasenv_print($filter);  # print environment variables; optionally filtered by $filter

FAS::Shell::debug;                  # print debugging onfo to STDERR

FAS::Shell::eoj;                    # print normal end of job message

FAS::Shell::bad_eoj($errmsg);       # dies with an abnormal end of job message

=head2 Rationale/Design intent

All FAS workflows have been designed so that paths to related files (e.g. inputs, outputs, configuration etc.) used exclusively by this job are relative to the directory containing the job script. This is why the B<configure> subroutine changes directory to the location of the script (i.e. $0). Commonly shared locations or web server locations should be specified by perl statements giving fully qualified pathnames. Typically, in FAS workflows, commonly shared materials are located under the location B<$ENV{FASREPO}/common_bin> e.g. B</srv/fasrepo/common-bin>.

=head2 Installation and System Requirements

In FAS VMs (Ubuntu/Linux) this library resides in /etc/perl i.e. B</etc/perl/FAS/Shell.pm>.

You may choose to install it as appropriate for your perl installations @INC directories and preferences.

=head3 Environment variables

Environment variables need to be set in the execution platform, at a minimum B<FASPLATFORM>. How you choose to do this depends on your platform and shell. In Founders and Survivors VMs we use Ubuntu linux with B<bash> as a shell. User profiles for shell work and cronjobs should source a file B</srv/.fas_environment> (or equivalent). This file defines all relevant environment variables used in command line work by the user/developer and enables production, development, and testing VMs to have customised configurations whilst using a common code base.

=head3 CPAN dependancies

Uses File::Basename and Date::Calc. These need to be installed in your Perl installation e.g. via CPAN or ActiveState under Windows(untested).
 
=head2 Credits

=head3 Author

Sandra Silcot, for the Founders and Survivors research project, November 2011.

=head3 Funder

ANDS (Australian National Data Service) seeding the commons grant DC3G.

=cut

1;
