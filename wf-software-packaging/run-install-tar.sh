#!/bin/sh
INSTALLDIR="fasAnds1.0"
FASENV=".fas_environment"
if [ -f "$1" ]; then
   echo "installing $1 to $INSTALLDIR"
   if [ -d $INSTALLDIR ]; then
       if [ -f $INSTALLDIR/$FASENV ]; then
          echo "## Not proceeding - found $FASENV in $INSTALLDIR"
          echo "## To preserve your customised environment:"
          echo "##    -- rename your $FASENV"
          echo "##    -- rerun $0"
          echo "##    -- replace the freshly installed $FASENV with your renamed one."
          exit 1
       fi
       echo "-- WARNING: $INSTALLDIR exists; overwiting with contents of $1 ..."
   else
       mkdir $INSTALLDIR
       echo "-- Created $INSTALLDIR"
   fi
   cd $INSTALLDIR
   echo ""
   echo "Untarring ../$1 ..."
   echo ""
   tar xfv ../$1
   echo ""
   echo "Done."
   echo "-- INSTALLDIR[$INSTALLDIR] has been populated from $1, contains:"
   cd ..
   ls -laR $INSTALLDIR
   echo ""
   echo "### ======================= IMPORTANT ============================ ###"
   echo "######################################################################"
   echo "### You need to modify .fas_environment to suit your installation! ###"
   echo "######################################################################"
   echo ""
   echo "######################################################################"
   echo "### You need to move the contents of etc/perl to a perl @INC path! ###"
   echo "######################################################################"
else
   echo "Failed to find \$1[$1]. Usage: $0 fas-software-tar"
fi
