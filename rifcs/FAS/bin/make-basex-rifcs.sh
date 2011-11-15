#!/bin/sh
today=`date +%Y%m%d`
SCOPE="FAS"
DEPLOYTO="/srv/fasweb/httpdocs/pub/ands/rifcs/${SCOPE}-ALL_${today}_rifcs.xml"
DBNAME="rifcs"
URI="$FAS_HTTP_STAFF/pub/collections/view/$SCOPE:ALL?withlocalid"
echo "#== $0 `date`"
OUTFILE="rifcs_fas.xml"
TMP="/tmp/$OUTFILE"
TMP2="/tmp/x_$OUTFILE"
OUTDIR="$BASEX_HOME/$DBNAME"
OUT="$BASEX_HOME/$DBNAME/$OUTFILE"
if [ ! -d "$OUTDIR" ]; then
    mkdir $OUTDIR
    echo "# created $OUTDIR"
fi
if [ ! -d "$OUTDIR" ]; then
    echo "$0 #ERR# OUTDIR[$OUTDIR] does not exist"
fi
echo "# getting URI[$URI]"
if [ -f "$TMP" ]; then
    rm $TMP
fi
wget -O $TMP $URI
echo "# stripping namespace - basex doesn't like it"
perl -pe 's/registryObjects xmlns[^\>]+/registryObjects/;' $TMP > $TMP2
ls -la $TMP2
fasval='/srv/fasrepo/common-bin/validateXML.pl'
$fasval $TMP2
rc=$?
echo "rc[$rc]"
if [ "$rc" -gt "0" ]; then
    echo "# $0 abnormal end"
    exit $rc
fi
echo "# creating $DBNAME in basex"
cp $TMP2 $OUT
ls -la $OUT
echo "--$BASEX_ADMIN/bin/fas-basex-manager.pl $DBNAME create"
$BASEX_ADMIN/bin/fas-basex-manager.pl $DBNAME create
echo "-- $BASEX_ADMIN/bin/fas-basex-manager.pl $DBNAME list"
$BASEX_ADMIN/bin/fas-basex-manager.pl $DBNAME list
rbx='/srv/fasrepo/common-bin/run-basex.pl'
echo "-- $rbx -listels x $DBNAME"
$rbx -listels x $DBNAME
echo "-- deploying with namespace/without localids to $DEPLOYTO"
perl -pe 's/registryObject id="[^"]+"/registryObject /;' $TMP > $DEPLOYTO
ls -la $DEPLOYTO
exit 0

