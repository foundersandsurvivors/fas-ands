#!/bin/bash
echo "# $0 : creating fas ands software package as a tar"
cd /srv
TARNAME=fas-ands-1.0.tar
MYTAR=./fasrepo/x_ands-published-collections/wf-software-packaging/$TARNAME
tar cfp $MYTAR --exclude=*.swp .fas_environment -C /srv fasrepo/x_ands-published-collections/wf-jobtest fasrepo/x_ands-published-collections/.jobenv  /etc/perl/FAS
ls -la $MYTAR
echo "# Done."
echo "# To test the package: ./run-install-tar.sh $TARNAME"


