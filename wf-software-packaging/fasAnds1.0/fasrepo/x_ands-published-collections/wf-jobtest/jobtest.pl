#!/usr/bin/perl

use strict;
use FAS::Shell;
FAS::Shell::configure("Test FAS::Shell batch library");

$ENV{JOB_PUBDIR_TEI} = "$ENV{JOB_PUBDIR_COLLECTIONS}/shipIndex/tei";
FAS::Shell::fasenv_print("JOB");

#FAS::Shell::debug;
FAS::Shell::eoj;

exit 0;


