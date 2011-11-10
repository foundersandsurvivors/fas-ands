#!/usr/bin/perl -s
# TODO document this script for ANDS.
# Copied from /srv/fasrepo/common-bin by claudine on 2011-11-10.

use utf8;
$myVersion = '2.1';
# ers = enlistment records sample
# dcf,dcm are a later, Comprehensive record of convict deaths 'def,dem' inc. recs for those who had completed sentence
use vars qw[%C];
chop(my $date = `date`);
#########$TYPES = 'hga,c31a,c33a,c40a,dem,def,c31s,c33s,c37s,c40s,c41s,dlm,dlf,dcf,dcm,c23a';
$TYPES = 'NEW,b4a,ai,of,om,c31a,c33a,c40a,dem,def,c31s,c33s,c37s,c40s,c41s,crs,dlm,dlf,dcf,dcm,dbu,c23a,hga,di,kgd,kgb,kgm,mm,mf,hgf,rpg,ff,ers,ert,wff';
$TYPE = $ARGV[0];
if ($dodesc) {
  # just tell us the column mappings
  print "# $0 : column order for [$TYPE]\n";
  if ($compact) {
    &doDesc($TYPE,'compact');
  }
  else {
    &doDesc($TYPE,'print');
  }
  exit 0;
}
elsif ($dodescall) {
  # load specific/generic descriptions
  &loadFDextraInfo;
  system("cat $ENV{FASREPO}/fas_common/xmldec");
  print "<fasDictionary version=\"$ENV{FASREPO_VERSION} $ENV{FASREPO_DATE}\">\n" .
        "<desc>\n".
        " <label>Founders and Survivors Repository Data Dictionary</label>\n" .
        " <p>Full description of Founders and Survivors Repository data sources: record types and field names for raw XML files.</p>\n" .
        " <source>Generated on $date</source>\n".
        "</desc>\n".
        "<fsRecordList type=\"raw\">\n".
        "  <label>Record type and field name descriptions for Founders and Survivors ingest of incoming Excel, Access and tab delimited files for initial conversion to raw XML files.</label>\n" ;
  foreach ( split(/,/,$TYPES) ) {
    &doDesc($_,'xml');
  }
  print "</fsRecordList>\n</fasDictionary>\n";
  exit 0;
}
$NRECS = $ARGV[2];
$singles = 1 if ($TYPE eq 'dlm'); # desc lists, con18
$singles = 1 if ($TYPE eq 'dlf'); # desc lists, con19, females
$singles = 1 if ($TYPE eq 'c31a' && !$allinone);
$singles = 1 if ($TYPE eq 'c33a');
##### we found the all in one $singles = 1 if ($TYPE eq 'c40a');
$singles = 1 if ($TYPE eq 'hga');
$singles = 1 if ($TYPE eq 'hgf');
if ($TYPES =~ m/$TYPE/ && -f $ARGV[1] && $NRECS =~ m/\d+/ ) {
  print "##========================== $0 NRECS[$NRECS] recs of $TYPE in $ARGV[1] singles[$singles]\n";
}
elsif ( $TYPE eq 'NEW' && -f $ARGV[1] ) {
  print "##========================== $0 $TYPE $ARGV[1]\n";
}
else {
  die "$0 usage: $0 type infile nrecs (where type is one of [$TYPES])\n";
}

use XML::Excel;         # for old format .xls  files
use Spreadsheet::XLSX;  # for new format .xlsx format

my $file = $ARGV[1];
my $xmlfile = $file;
$xmlfile =~ s/\.xls$/.xml/;

# if empty, write a stub
if ( $file =~ m|MISSINGFILE| || $file =~ m|_n\.xls| ) {
  open (NEW,">$xmlfile");
  print NEW <<emptySTUB;
<?xml version="1.0" encoding="UTF-8"?>
<dataroot source="$xmlfile" n="0">
</dataroot>
emptySTUB
  close(NEW);
  print "$0 wrote stub for MISSINGFILE $xmlfile\n"; 
}
elsif ( $TYPE eq 'kgd' || $TYPE eq 'kgb' || $TYPE eq 'kgm' ) {
  # tab delimited file, not excel
  # head -1 deaths.dat | perl -pe 's/\t/\|/g;'
  # rec_no|rank|rankocc|district|daydth|mthdth|yeardth|first|first_c|middle|middle_c|last|last_c|sex|age|cause|
  #        firstinf|midinf|lastinf|descinf|residenc|comment|dontuse|
  #        dayreg|mthreg|yearreg|doubreg|agegrp|agernd|ageadded|V3|V4|V5|V6|firstreg|midreg|lastreg|depreg
  $xmlfile = "${TYPE}-input.xml";
  $infile = ""; $n_in = 0; $n_fields = 0; $enc = "UTF-8";
  if ($TYPE eq 'kgd') { $infile = "deaths.dat"; $n_in = 92885; $n_fields = 38; }
  elsif ($TYPE eq 'kgb') { $infile = "births.dat"; $n_in = 194558; $n_fields = 53; $enc = "ISO-8859-1"; }
  elsif ($TYPE eq 'kgm') { $infile = "marriages.dat"; $n_in = 51131; $n_fields = 107; $enc = "ISO-8859-1"; }
  open (NEW,">$xmlfile") || die "$0: failed to open $xmlfile for writing [$!]\n";
  print NEW <<KGD_INPUT;
<?xml version="1.0" encoding="$enc"?>
<dataroot source="$infile" n="$n_in">
KGD_INPUT
  open (IN, $infile) || die "$0: failed to open deaths.dat for read [$!]\n";
  my $oldcols = <IN>; chop($oldcols);
  my @columns = &columns($TYPE);
#$pcols = join("|",@columns);
#print NEW "$pcols\n";
  my $n = 0;
  $doEval{'deathDy'} = $doEval{'deathMo'} = $doEval{'deathYr'} = 1;
  $doEval{'birthDy'} = $doEval{'birthMo'} = $doEval{'birthYr'} = 1;
  $doEval{'birthRegDy'} = $doEval{'birthRegMo'} = $doEval{'birthRegYr'} = 1;
  $doEval{'marriageDy'} = $doEval{'marriageMo'} = $doEval{'marriageYr'} = 1;
  while (<IN>) {
    $n++;
    s/[\r\n]$//g;
    s/&/&amp;/g; s/</&lt;/g; s/>/&gt;/g;
    # always gotta be one! -- deaths
    s/\x92\x73/'/; # <rank>Watchmaker�s child</rank>
    # use ISO-8859-1 as above, so ok as is
    #s/\x85\x73/###/; # Bytes: 0x85 0x73 0x74 0x61 <middle1>�stan?</middle1>
    #s/\x85\x61/###/; # Bytes: 0x85 0x61 0x63 0x65 <middle1>�ace?</middle1>
    #s/\x85\x3F/###/; # Bytes: 0x85 0x3F 0x3C 0x2F <snMotherMaiden>Gr�?</snMotherMaiden>
    #s/\x85\x74/###/; # Bytes: 0x85 0x74 0x3F 0x3C <snMotherMaiden>�t?</snMotherMaiden>
    #s/\x85\x2E/###/; # Bytes: 0x85 0x2E 0x6E 0x3F <snMotherMaiden>Cu�.n?</snMotherMaiden>
    #s/\x85\x20/###/; # Bytes: 0x85 0x20 0x6E 0x73 <snMotherMaiden>� ns?</snMotherMaiden>
    #s/\x85\x77/###/; # Bytes: 0x85 0x77 0x6F 0x6F <snMotherMaiden>�wood?</snMotherMaiden>
    #s/\x85\x79/###/; # Bytes: 0x85 0x79 0x74 0x6F <snMotherMaiden>�yton?</snMotherMaiden>
    undef @fields;
#$flag = 0;
    @fields = split(/\t/,$_,$n_fields);
    #if    ( $TYPE eq 'kgd' ) { $flag=38; @fields = split(/\t/,$_,38); }
    #elsif ( $TYPE eq 'kgb' ) { $flag=53; @fields = split(/\t/,$_,53); }
    #else { "die: kgm NYI\n"; }
#$_ =~ s/\t/\|/g;
#$nfields = $#fields + 1;
    print NEW "<${TYPE}>\n";
    $deathDate = $deathDy = $deathMo = $deathYr = '';
    for ($i = 0; $i < $n_fields; $i++ ) {
      $val = $fields[$i]; $e = $columns[$i];
      # was: $val =~ s/^ +//g; $val =~ s/ +$//;
      $val =~ s/^\s+//; $val =~ s/\s+$//;
      if ($doEval{$e}) {
        $evalCode = '${$e} = "$val";';
        eval($evalCode);
      }
      print NEW "<$e>$val</$e>\n" if ($val && !$doEval{$e}); # not empties
      if ($e eq 'deathYr' && $val) {
        $deathDate = sprintf "%04d-%02d-%02d", $deathYr, $deathMo, $deathDy;
        print NEW "<deathDate>$deathDate</deathDate>\n";
      }
      elsif ($e eq 'birthYr' && $val) {
        $birthDate = sprintf "%04d-%02d-%02d", $birthYr, $birthMo, $birthDy;
        print NEW "<birthDate>$birthDate</birthDate>\n";
      }
      elsif ($e eq 'birthRegYr' && $val) {
        $birthRegDate = sprintf "%04d-%02d-%02d", $birthRegYr, $birthRegMo, $birthRegDy;
        print NEW "<birthRegDate>$birthRegDate</birthRegDate>\n";
      }
      elsif ($e eq 'marriageYr' && $val) {
        $marriageDate = sprintf "%04d-%02d-%02d", $marriageYr, $marriageMo, $marriageDy;
        print NEW "<marriageDate>$marriageDate</marriageDate>\n";
      }
    }
    print NEW "</${TYPE}>\n";
  }
  print NEW "</dataroot>\n";
  close(IN);
  close(NEW);
  if ($n == $n_in) {
    print "# $TYPE end. GOOD. wrote $n to $xmlfile\n";
  }
  else {
    print "# $TYPE end. BOO. wrote $n to $xmlfile Expected 92885.\n";
  }
  print "# Eoj. Custom $TYPE tab delim conversion to xml.\n"; 
}
elsif ($TYPE eq 'NEW') {
  if ($file =~ m/\.xls$/) {

    print "##======== Parsing old format .xls $file with XML::Excel ...\n";

    print "## WARNING: NEW type specified -- not customising columns.\n";
    my $xls = XML::Excel->new();
    print "..xls 1[$xls] file[$file]\n";
    $xls->parse_doc($file);
    print "..xls 2[$xls]\n";
    $xls->declare_xml({version => '1.0', standalone => 'yes'});
    $xls->print_xml($xmlfile, 
                    {file_tag    => 'dataroot',
                     parent_tag  => "NEW" }
                   );
    print "..xls done 3[$xls]\n";
  }
  elsif ($file =~ m/\.xlsx$/) {

    print "##======== Parsing new format .xlsx $file with Spreadsheet::XLSX ...\n";
    print "##======== NB: expecting first row to be column names\n";
    
    my $converter = '';
    my $xls = Spreadsheet::XLSX -> new ($file, $converter);
    my %DROPCOLS = ( 'xxxx'=>1);
    my %COL2INPOS = ();
    my %F = ();
    my @COL = ();
    my $nrow = 0;
    my $fix = 1;
    my $sheetnum = 0;

    foreach my $sheet (@{$xls -> {Worksheet}}) {

      my $fname = $file;
      $sheetnum++;
      $fname =~ s/\.xlsx$//;
      $fname =~ s/ /_/g;
      my $sheetname = $sheet->{Name};
      my $sheetnum_delim = '_' . $sheetnum;
      $sheetnum_delim = '' if ( $sheetnum == 1 );
      my $xmlFile = $fname . $sheetnum_delim . ".xml";
      my $sheetFile = $fname . $sheetnum_delim . ".tab";
      my $sheetFileLog = $fname . $sheetnum_delim . ".log";
      
      $nrow = 0;
      my $columns = 0;

      open (XML,">$xmlFile") || die "#err# $0: failed to open xmlFile[$xmlFile] [$!]\n";
      open (LOG,">$sheetFileLog") || die "#err# $0: failed to open sheetFileLog[$sheetFileLog] [$!]\n";
      open (F,">$sheetFile") || die "#err# $0: failed to open sheetFile[$sheetFile] [$!]\n";

      print "== writing ".$sheet->{Name}." to file: $sheetFile\n";
      printf("Sheet: %s\n", $sheet->{Name});
      $sheet -> {MaxRow} ||= $sheet -> {MinRow};
      print XML "<dataroot generatedBy=\"Fas excel2xml.pl $myVersion Spreadsheet::XLSX\">\n";

      foreach my $row ($sheet -> {MinRow} .. $sheet -> {MaxRow}) {
         %F = ();
         $sheet -> {MaxCol} ||= $sheet -> {MinCol};
         $nrow++;
         print LOG "-- row $nrow\n";
         print XML "<row n=\"$nrow\">\n" if ($nrow > 1);
         $columns = 0;

         # loop for columns

         foreach my $col ($sheet -> {MinCol} ..  $sheet -> {MaxCol}) {

            my $cell = $sheet -> {Cells} [$row] [$col];
            $columns++;
            my $value = '';
            my $ovalue = '';
            my $nonxml_value = '';

            if ($cell) {
	        $ovalue = $cell -> {Val};
                $value = $ovalue;
                if ( $fix && $nrow == 1 ) {

                   printf(LOG "..WAS:( %s , %s ) => %s\n", $row, $col, $ovalue);

                   # make them sortable
                   $value =~ s/^f(\d) /f0${1}_/;

                   # sensible column names

                   $value =~ s/ /_/g;
                   $value =~ s/\#/_No_/g;
                   $value =~ s/['";\(\)\/\\]//g;
                   # and in case of &apos; in columns names
                   $value =~ s/\&apos;//g;
                   $value =~ s/\&apos//g; # !!! lacks ; if in fieldname???
                   $value =~ s/\&quot;//g; # and effing quots too
                   $value =~ s/__+/_/g;

                   # array of colnames in recieved order
                   print LOG "..saving colname[$value] columns[$col]\n";
                   $COL[$col] = $value;
                   #push(@COL,$value);

                }
                # common field cleanups -- remove carriage returns! effing filemaker!!

                # leading/trailing spaces
                $value =~ s/^\s+//;
                $value =~ s/\s+$//;

                # ampersands
                $value =~ s/\&([gl]t;)/\#\1/g;   # gt/lt seems same across Janet v1/v2 BUT now getting &apos; -> &apm;apos; ....
                $value =~ s/\&(apos;)/\#\1/g;    # in case we get &apos; coming in, we really want '
                $value =~ s/\&(quot;)/\#\1/g;    # in case we get &quot; coming in, we really want "
                $value =~ s/\&/\&amp;/g;
                $value =~ s/\#([gl]t;)/\&\1/g;
                $value =~ s/\#apos;/'/g;
                $value =~ s/\#quot;/"/g;

                # the excel conversion gives \r\n for each line break
                $value =~ s~\r\n(\r\n)+~#PARA_START#~g;
                $value =~ s~\r\n~#RETURN#~g;

                # and do this again if we only have \r (e.g. v1 of Janet khrd matched \r\n but now just \r (HUH?????)
                $value =~ s~\r(\r)+~#PARA_START#~g;
                $value =~ s~\r~#RETURN#~g;

                # print to log
                printf(LOG "( %s , %s ) => %s\n", $row, $col, $value);

            }

            # always print the column to tabbed file

            print F "\t" if ($col);
            print F $value;

            # save the value under its named field
            my $fieldname = $COL[$col];
            unless ( $DROPCOLS{$fieldname} ) {
                $F{$fieldname} = $value unless $DROPCOLS{$fieldname};

                if ( $nrow > 1 && $value ) {
                    # print xml element if it has content
                     print XML "<". $COL[$col] . '>' . $value . '</'. $COL[$col] . ">\n" ;
                }
            }

            if ( $nrow > 1 && $DROPCOLS{$fieldname} && $value ) {
                 die "##err## DROPCOLS{$fieldname} has value[$value] nrow[$nrow]\n";
            }
     
         }
         print F "\n"; # close row
         print XML "</row>\n" if ($nrow > 1);
         
      }

      print XML "</dataroot>\n";
      close(XML);
      close(LOG);
      close(F);
      system("ls -la $xmlFile $sheetFile $sheetFileLog");
    }

  }
  else {
    die "##======== ** unsupported filetype[$file] **\n";

  }
}
else {
  my @columns = &columns($TYPE);
  my $xls = XML::Excel->new({column_headings => \@columns});
  $xls->parse_doc($file);
  $xls->declare_xml({version => '1.0',
                     standalone => 'yes'});
  $xls->print_xml($xmlfile,
                  {file_tag    => 'dataroot',
                   parent_tag  => $TYPE }
                 );
  &remove_columns($TYPE,$xmlfile,$NRECS);
}

system("ls -la $file $xmlfile");

print "$0: normal eoj\n";

exit 0;

#--------------------------------------- kill dud first root element
sub remove_columns {
  my $doctype = shift;
  my $f = shift;
  my $nrecs = shift;

  my $n = 0;
  my $state = 'start';

  if ($singles) {
    my $VOLUME = '';
    # get the volume

    # # SINGLES CON[] VOL[] VOLUME[] doctype[hga] nrecs[308] fnNRECS[] cleaning f[htg_absc_1825_n308.xml] -> htg_absc_1825_n308.xml2

# HTG: LINE ORDER	DATE OF HTG	POLICE NUMBER	FIRST NAME	SURNAME	SHIP	ABSCONDED FROM WHERE	ABSCONDED DATE	RECAPTURED DATE	RECAPTURED WHERE	OTHER INFORMATION	COMMENTS

    # they did ships in single files but all one vol, sheesh!
    if ($f =~ m/CON(18)_(\d+)_(\d)/) {
      $VOLUME = sprintf "%02d%02d%1d",$1,$2, $3;
      $CON = $1;
      $VOL = "$2$3";
      if ($f =~ m/_n(\d*)/) {
         $fnNRECS = $1;
      }
      $doctype = "dlm";
    }
    elsif ($f =~ m/CON(19)_(\d+)_(\d)/) {
      $VOLUME = sprintf "%02d%02d%1d",$1,$2, $3;
      $CON = $1;
      $VOL = "$2$3";
      if ($f =~ m/_n(\d*)/) {
         $fnNRECS = $1;
      }
      $doctype = "dlf";
    }
    elsif ($f =~ m/CON(\d\d)_(\d+)/) {
      $VOLUME = sprintf "%02d%02d",$1,$2;
      $CON = $1;
      $VOL = $2;
      if ($f =~ m/_n(\d+).xml/) {
         $fnNRECS = $1;
      }
      $doctype = "c${CON}a";
    }
    # htg_absc_1851_n2452.xls / htg_absc_1818to1824_n28.xls
    elsif ( $f =~ m/htg_absc_([^\_]+)_n(\d+)\.x/ ) {
      $VOL = $1;
      $CON = 'hga'; # series
      $VOLUME = substr($VOL,0,4);
      $fnNRECS = $2;
      $doctype = "hga";
    }
    elsif ( $f =~ m/htg_freedoms_([^\_]+)_n(\d+)\.x/ ) {
      $VOL = $1;
      $CON = 'hgf'; # series
      $VOLUME = substr($VOL,0,4);
      $fnNRECS = $2;
      $doctype = "hgf";
    }
    print "# SINGLES SERIES[$CON] VOL[$VOL] VOLUME[$VOLUME] doctype[$doctype] nrecs[$nrecs] fnNRECS[$fnNRECS] cleaning f[$f] -> ${f}2\n";
    die "No volume -- check filename and rerun\n" unless $VOLUME;
    open (F,"$f") || die "$0 failed to open f[$f] [$!]\n";
    open (F2,">${f}2") || die "$0 failed to open f2[$f2] [$!]\n";

#<?xml version="1.0" standalone="yes"?>
#<dataroot>
#        <c31a>
#                <lineNum>LINE N0.</lineNum>
#                <policeNum>POLICE N0.</policeNum>

    $xmldec = <F>;
    $n = 0;
    print F2 $xmldec;
    while (<F>) {
      if ( m/<lineNum>(\d+)/ ) {
         $lnum = $1;
         unless ($n) {  # first row not matches as its columns
            print "..Got first real row at [$_]";
            print F2 "<$doctype>\n"; # first row not matches as its columns
         }
         $n++;
         # let the lineNum preserve physical document sequence
         print F2 "<lineNum>$VOLUME";
         if ($doctype eq 'dlm') {
           print F2 sprintf("%03d",$lnum);
         }
         elsif ($doctype eq 'hgf') {
           print F2 sprintf("%05d",$lnum);
         }
         else {
           print F2 sprintf("%04d",$lnum);
         }
         print F2 "</lineNum>\n";
         next;
      }
      print F2 if (s/<dataroot/<dataroot source="$f" n="$fnNRECS"/ );
      s/^\s+//;
      # crud in ff \0xb
      if ($doctype eq 'ff') { s/\x0b//; }
      next if (m|\>\<|); 
      print F2 if $n;
    }
    close(F);
    close(F2);
    print "Found $n lineNum\n";
    if ( $n == $fnNRECS ) { print "Excellent, $n is what we expected from $f\n"; }
    else { die "BOO!!!, $n is NOT what we expected from $f\n"; }
  }
  else {

    print "# cleaning $f -> ${f}2\n";
    open (F,"$f") || die "$0 failed to open f[$f] [$!]\n";
    open (F2,">${f}2") || die "$0 failed to open f2[$f2] [$!]\n";
    # ignore until </doctype>, then put out dataroot and rest of file
    while (<F>) {
      if ($state) {
        if ( m|\<\/$doctype\>| ) {
           $state = '';
           print F2 &dataroot($doctype);
        }
        next;
      }
      # remove leading spaces and empty elements
      next if (m|\>\<|);
      s/^\s+//;
      if ( m|\<$doctype\>| ) {
        $n++;
        if ($n > $nrecs ) {
           # ok we are done
           print F2 "</dataroot>\n";
           print "Done: $nrecs written to $xmlfile\n";
           last;
        }
      }
      print F2; 
    }
    close(F);
    close(F2);
    if ($state eq 'start') {
      die "# NO DOCTYPE found in $f ... please fix or use -singles\n";
    }

  }
  system("mv ${f}2 $f");
}

#--------------------------------------- columns
sub columns {
  my $doctype = shift;
  if ( $doctype eq 'wff' ) {
    # wff: uni of woolongong first fleet dataset - no IDS !!!!! faaarrrk!
    return ( 'surname', 'forename', 'alias', 'unused', 
             'ageLeftEngland', 'sex', 'deathDate', 'deathYr',
             'leftColony','sentencedWhere', 'triedDate', 'transportedFor',
             'crimeValueShillings', 'sentence', 'transportedYears',
             'trade','ship','signature','wffNotes');
  }
  elsif ( $doctype eq 'ert' ) {
     return ('barcode','controlSymbol','name','surname','forename','alias',
             'serviceNumber','birthPlace','enlistPlace','nextOfKin',
             'barcodeSeeAlso','nameSeeAlso','wwiiStatus','wwiiBarcode',
             'wwiSeries','wwiiControlSymbol',
             'isOfficer','isMedical','isChaplain','ignore');
  }
  elsif ( $doctype eq 'ers' ) {
     # birthDateCalc = (enlistYr + 1900 + (enlistMo - 1)/12)-(ageYr + (ageMo - 1)/12)
     return ('idNum','surname','forename','ageYr','ageMo','enlistMo','enlistYr','birthDateCalc',
             'xref2kgb','ersComments','serviceNumber','birthPlace','birthPlaceTown','birthPlaceState',
             'birthcode1','birthcode2','birthcode3', 'enlistPlace','enlistPlaceTown','enlistPlaceState',
             'relNextOfKin1','surnameNextOfKin1','forenameNextOfKin1','birthPlaceAddnl',    
             'birthDy','birthMo','birthYr','occupation','maritalStatus',
             'relNextOfKin2','surnameNextOfKin2','forenameNextOfKin2',
             'addressNextOfKin','addressPart1','addressPart2',
             'enlistDy','ignore1','ignore2','sign');
     # this is chris inwoods Bs but excludes tas born
     # return ('idNum','surname','forename','serviceNumber','birthPlace','birthPlaceTown','birthPlaceState',
     #         'birthcode1','birthcode2','birthcode3',
     #         'enlistPlace','enlistPlace1','enlistPlace2',
     #         'relNextOfKin1','surnameNextOfKin1','forenameNextOfKin1',
     #         'birthPlaceAddnl', 'birthDy','birthMo','birthYr','occupation','maritalStatus',
     #         'relNextOfKin2','surnameNextOfKin2','forenameNextOfKin2','addressNextOfKin','res1','res2',
     #         'enlistDy','enlistMo','enlistYr','signature','ageYr','ageMo',
     #         'heightFt','heightIn','weightStones','weightLbs','religion','religionCode','ersComments');
  }
  elsif ( $doctype eq 'kgd' ) {
      # /srv/fasrepo/x_sources/20091202-kippen-bdm-tabdelim
      # head -1 deaths.dat | perl -pe 's/\t/\|/g;'
      # rec_no|rank|rankocc|district|daydth|mthdth|yeardth|first|first_c|middle|middle_c|last|last_c|sex|age|cause|                        #        firstinf|midinf|lastinf|descinf|residenc|comment|dontuse|                                                                   #        dayreg|mthreg|yearreg|doubreg|agegrp|agernd|ageadded|V3|V4|V5|V6|firstreg|midreg|lastreg|depreg
     return ('lineNum','rank','rankocc','district','deathDy','deathMo','deathYr','forename','fnInitial',
             'middlename','mnInitial','surname','snInitial','sex','deathAge','deathCause', 
             'inf1_forename','inf1_middlename','inf1_surname','inf1_desc','residenc','comment','dontuse',
             'deathRegDy','deathRegMo','deathRegYr','doubreg','agegrp','agernd','ageadded','V3','V4','V5','V6',
             'deathRegBy_forename', 'deathRegBy_middlename','deathRegBy_surname','depreg');
  }
  elsif ( $doctype eq 'kgb' ) {
     return ("recnoNu","lineNum","rankFather","rankoccFather","marriageId","marriageIdDoubtful",
             "birthDy","birthMo","birthYr","forename","middle1","middle2","sex",
             "forenameMo","forenameMoMC","middlenameMo","middlenameMoMC","maidennameMo","maidennameMoMC","surnameMo",
             "forenameFa","forenameFaMC","middlenameFa","middlenameFaMC","surnameFa","surnameFaMC",
             "bregDistrict","bregNo","no4","no5","no6","place",
             "forenameInformant1","middlenameInformant1","surnameInformant1","descInformant1","residenceInformant1",
             "birthRegDy","birthRegMo","birthRegYr","fnRegistrar","mnRegistrar","snRegistrar",
             "comment","middlenameAdd","duplicateBreg","registerNum","pdfNum","marriagePlace",
             "marriageDy","marriageMo","marriageYr","comment2");
  }
  elsif ( $doctype eq 'kgm' ) {
    return ("rec_no","marriageYr","forenameHu","middlenameHu","surnameHu",
                                  "forenameWi","middlenameWi","surnameWi",
                     "district","regNum","registerNum","registerVol","registerPage",
                                "marriageDy","marriageMo","marriagePlace",
                     "ageHu","ageWi","maritalStatusWi","rankOccWi","civilStatusWi", "nameFullHu","nameFullWi",
                     "forenameClergy","middlenameClergy","surnameClergy", 
                     "marriageRegDy","marriageRegMo","marriageRegYr","regNum2","nameDuputyRegistrar",
                     "marriedIn","marriagePlace2","rites","nameHu","markCrossSigHu","nameWi","markCrossSigWi",
                     "forenameWitness1","middlenameWitness1","surnameWitness1","markCrossSigWitness1",
                     "forenameWitness2","middlenameWitness2","surnameWitness2","markCrossSigWitness2",
                     "forenameMinister","middlenameMinister","surnameMinister","licenceCert",
                     "f47","f48","f49",
                     "f50","f51","f52","f53","f54","f55","f56","f57","f58","f59",
                     "f60","f61","f62","f63","f64","f65","f66","f67","f68","f69",
                     "f70","f71","f72","f73","f74","f75","f76","f77","forenameRelPers1","middlenameRelPers1",
                     "surnameRelPers1","relPers1Consent","forenameRelPers2","middlenameRelPers2","surnameRelPers2",
                     "relPers2Consent","forenameHuConsent","middlenameHuConsent","surnameHuConsent",
                                       "forenameWiConsent","middlenameWiConsent","surnameWiConsent",
                                       "forenameHuConsent21","middlenameHuConsent21","surnameHuConsent21",
                                       "forenameWiConsent21","middlenameWiConsent21","surnameWiConsent21",
                     "nameMinOrReg","transcribersComment","flagDuplicate","decade",
                     "maritalStatusHu","rankOccHu","civilStatusHu");
  }
  elsif ( $doctype eq 'rpg' ) {
     # place name gazette csv loaded into excel, added lineNum
     return ('lineNum','placeName','gridref','county','countyAdm','district','unitaryAuthority','policeArea', 'region');
  }
  elsif ( $doctype eq 'ai' ) {
     # not excel, see grep ^map /srv/fasrepo/ai/10-ai-log.txt
     return ('idno','nameLabel','surname','forename','extraId','seeSurname','seeForename','seeExtraId',
             'voyageShip','voyageArrivalDate','aotRemarks','voyageNumber','ship','numOfShips',
             'shipDepDate','shipDepPort','arrivalDate','refConduct','refIndent','refDesc','refMuster',
             'refOther','refAppropList','refSurgRptTotal','refSurgRptAdm','refSurgRptReel',
             'refMisc','convictShipNumber','Field27','Field28','Field29','Field30','Field31','Field32');
  }
  elsif ( $doctype =~ m/c18a/i ) {
    return ( 'lineNum', 'ship', 'arrivalDate', 'policeNum', 'surname', 'forename', 'sentencedWhere', 'triedDate', 
             'sentence', 'religion', 'literacy', 'transportedFor', 'gaolRpt', 'hulkRpt', 'maritalStatus', 'statedThisOffence', 
             'family', 'surgeonsRpt', 'trade', 'heightFt', 'heightIn', 'age', 'hair', 'eyes', 'birthPlace', 'bodyMarks', 
             'sourceVol', 'sourcePage', 'imgUrl', 'transcribersComment' );
  }
  elsif ( $doctype =~ m/hga/i ) {
    return ( 'lineNum', 'htgDate', 'policeNum', 'forename', 'surname', 'ship', 
             'abscondedFrom', 'abscondedDate', 'recapturedDate', 'recapturedFrom', 'abscOtherInfo', 'transcribersComment');
  }
  elsif ( $doctype =~ m/hgf/i ) {
    return ( 'lineNum', 'htgDate', 'policeNum', 'forename', 'surname', 'ship', 
             'policeAppointmentDate', 'policeDismissedDate', 
             'freeGrantedTicketOfLeaveDate', 'freeRevokedTicketOfLeaveDate', 
             'freeGrantedCondPardonDate', 'freeGrantedFreePardonDate', 
             'freeGrantedCertificateDate', 'freeRevokedCertificateDate', 
             'remarks');
  }
  elsif ( $doctype =~ m/c31s/i ) {
    return ( 'lineNum', 'policeNum', 'forename', 'surname', 'ship', 'arrivalDate', 
             'sentence', 'sentencedDate', 'sentencedYr', 'occupation', 
             'eventLine', 'eventDate', 'eventMonth', 'eventYr', 'eventLocation', 'eventDesc', 'eventSentence', 'eventMagistrate', 'eventComments',
             'sourceVol', 'transcribersComment');
  }
  elsif ( $doctype =~ m/(c33s)|(c40s)|(c41s)/i ) {
    return ( 'lineNum', 'policeNum', 'forename', 'surname', 'ship', 'arrivalDate', 
             'sentence', 'sentencedDate', 'sentencedYr', 'occupation', 'age', 
             'eventLine', 'eventDate', 'eventMonth', 'eventYr', 'eventLocation', 'eventDesc', 'eventSentence', 'eventMagistrate', 'eventComments',
             'sourceVol', 'transcribersComment');
  }
  # c37s consolidated into crs
  elsif ( $doctype =~ m/c37s/i ) {
    return ( 'lineNum', 'policeNum', 'forename', 'surname', 'age', 'ship', 'arrivalDate',
             'sentence', 'sentencedDate', 'sentencedYr', 'occupation', 
             'eventLine', 'eventDateN', 'eventDate', 'eventMonth', 'eventYr', 'eventLocation', 'eventDesc', 'eventSentence', 'eventMagistrate', 'eventComments',
             'sourceVol', 'transcribersComment', 'religion', 'literacy' );
  }
  ####################################### musters corrspond (@corresp in tei) up to inc sentence, 
  ####################################### their lineNum is the lineNum of the corresponding record
  elsif ( $doctype =~ m/(c31a)|(c40a)/i ) {
    return ( 'lineNum', 'policeNum', 'surname', 'forename', 'ship', 'arrivalDate', 'sentencedWhere', 'triedDate', 'sentence', 
             'transportedFor', 'gaolRpt', 'hulkRpt', 'maritalStatus', 'statedThisOffence', 'family', 'surgeonsRpt',
             'religion', 'literacy', 'sourceVol', 'sourcePage', 'sourceOrderOnPage', 'transcribersComment', 'imgUrl' );
  }
  elsif ( $doctype eq 'ff' ) {
    return ( 'lineNum', 'policeNum', 'surname', 'forename', 'age', 'ship', 'voyage', 'arrivalDate', 'birthPlace', 'birthPlaceWithCty');
  }
  elsif ( $doctype eq 'mm' ) {
    return ( 'lineNum', 'c31aONE_lineNum', 'policeNum', 'pnInitial', 'surname', 'forename', 'ship', 'arrivalDate', 'sentencedWhere', 'triedDate', 'sentence', 
             'mm1830', 'mm1830_trCmmt', 
             'mm1832', 'mm1832_trCmmt', 
             'mm1833', 'mm1833_trCmmt', 
             'mm1835', 'mm1835_trCmmt', 
             );
  }
  elsif ( $doctype eq 'mf' ) {
    return ( 'lineNum', 'policeNum', 'surname', 'forename', 'ship', 'arrivalDate', 'sentencedWhere', 'triedDate', 'sentence', 
             'mf1830', 'mf1830_trCmmt', 
             'mf1832', 'mf1832_trCmmt', 
             'mf1833', 'mf1833_trCmmt', 
             'mf1835', 'mf1835_trCmmt', 
             );
  }
  elsif ( $doctype =~ m/c33a/i ) {
    return ( 'lineNum', 'ship', 'arrivalDate', 'policeNum', 'surname', 'forename', 'sentencedWhere', 'triedDate', 
             'sentence', 'religion', 'literacy', 'transportedFor', 'gaolRpt', 'hulkRpt', 'maritalStatus', 'statedThisOffence', 
             'family', 'surgeonsRpt', 'trade', 'heightFt', 'heightIn', 'age', 'hair', 'eyes', 'birthPlace', 'bodyMarks', 
             'sourceVol', 'sourcePage', 'imgUrl', 'transcribersComment' );
  }
  elsif ( $doctype =~ m/dem/i ) {
    return ( 'lineNum', 'assOrProb', 'sourceVol', 'arrivalDate', 'arrivalDate2','ship','sex',
             'policeNum', 'surname', 'forename',
             'deathDate','reportedDeathDate', 'deathYear', 'daysArrToDeath',
             'deathPlace','deathInstitution','deathCause','convictStatus', 
             'infoVarious','note');
  }
  # dbu (burials) 
  elsif ( $doctype =~ m/dbu/i ) {
    # lineNum requires slashes to be stripped. Alot of this is repeated, can be dropped.
    # Note persRole was 'quality or profession'
    return ( 'burialNum', 'surname', 'forename', 'lineNum', 'sex', 'abode', 'deathDate','burialDate',
             'age','ship','deathCause','persRole','burialPerfBy','burialPlace', 'sourceVol', 
             'transcribersComment','eventType','forenameFa','nameMo','buDay','buMonth','buYear',
             'X','sex2','spouseAge','spouseSex','burialRegPlace','regNumYr','regYr','NAME','PARENTS_SP','REF','WHENDIED');
  }
  # dcm (deaths comprehensive male) similar but different to dem 
  elsif ( $doctype =~ m/dcm/i ) {
    return ( 'lineNum', 'sourceVols', 'arrivalDate', 'arrivalDateDy', 'arrivalDateMo', 'arrivalDateYr', 'ship','sex',
             'policeNum', 'surname', 'forename',
             'deathDate', 'deathDateDy', 'deathDateMo', 'deathDateYr',
             'burialDate', 'burialDateDy', 'burialDateMo', 'burialDateYr',
             'reportedDeathDate', 'reportedDeathDateDy', 'reportedDeathDateMo', 'reportedDeathDateYr',
             'deathPlace','deathInstitution','deathCause','convictStatus', 
             'infoVarious','notes', 'deathTagExcecuted');
  }
  elsif ( $doctype =~ m/def/i ) {
    return ( 'lineNum', 'sourceVol', 'arrivalDate', 'ship','sex',
             'policeNum', 'surname', 'forename',
             'deathDate','reportedDeathDate', 
             'deathPlace','deathInstitution','deathCause','convictStatus', 
             'comments', 'alias', 'extraFromDeathRegister' );
  }
  # dcf (deaths comprehensive female) is similar but different to def 
  elsif ( $doctype =~ m/dcf/i ) {
    return ( 'lineNum', 'sourceVols', 'arrivalDate', 'arrivalDateDy', 'arrivalDateMo', 'arrivalDateYr', 'ship','sex',
             'policeNum', 'surname', 'forename',
             'deathDate', 'deathDateDy', 'deathDateMo', 'deathDateYr',
             'burialDate', 'burialDateDy', 'burialDateMo', 'burialDateYr',
             'reportedDeathDate', 'reportedDeathDateDy', 'reportedDeathDateMo', 'reportedDeathDateYr',
             'deathPlace','deathInstitution','deathCause','convictStatus', 
             'infoVarious','notes', 'deathTagExcecuted');
  }
#'VDL Males 28-05-07', [
#                   'ID', '*case07', '*indent', 'surname', 'firstname', 'alias', 'tried',
#                   'court', '*dayt', 'montht', '*yeart', 'sentce', '*age', 'feet', 'inches',
#                   'religiono', 'literacyo', 'maritalo', '*children', '*childm', '*childf',
#                   'reside', 'born', 'countryb', 'trade1', 'trade1cl', 'trade2', 'trade3',
#                   'trade4', 'trade15', 'trade6', 'trade7', 'crime', 'prosdetails',
#                   'additional', 'additional2', 'victim', 'triedwith', 'comments', 'offences',
#                   'hulk', 'punishhk', 'behaviour', 'earnings', 'relation', 'class', '*yarrived',
#                   'shiporiginal', 'remarks', 'Field87', 'F88'
#],

  ####elsif ( $doctype =~ m/om/i ) { return ( 'TODO_FIELDS_NOT_YET_IMPLEMENTED' ); }
  #  return ( 'lineNum', 'case07Num', 'ship', 'arrivalDate', 'policeNum', 'surname', 'forename', 'sentencedWhere', 'triedDate', 
  #           'sentence', 'religion', 'literacy', 'transportedFor', 'gaolRpt', 'hulkRpt', 'maritalStatus', 'statedThisOffence', 
  #           'family', 'surgeonsRpt', 'trade', 'heightFt', 'heightIn', 'age', 'hair', 'eyes', 'birthPlace', 'bodyMarks', 
  #           'sourceVol', 'sourcePage', 'imgUrl', 'transcribersComment' );
  #}

#'VDL Females 28-05-07', ['*case2006', 'firstnam', 'surname', 'alias', 'born',
#                   '*age', 'feet', 'inches', 'complexi', 'hair', 'eyes', 'literacy', 'religion',
#                   'marital', '*children', 'unfit', 'job1', 'job2', 'job3', 'job4', 'ontown',
#                   'tried', 'court', 'detail', 'victim', 'priorcon', '*cday', 'CCCMONTH', '*cyear',
#                   'sentence', 'sailed', '*daysailed', '*monthsailed', '*yearsailed',
#                   'arrived', '*arrivedday', '*arrivedmonth', '*ARRIVALYEAR', 'FATE', 'shiporig',
#                   'colony', 'shipcharacter', 'death', 'number',
#                   'technicalremarks', 'remarksonshipsarrival'],


  elsif ( $doctype =~ m/of/i ) {
    return ( 'lineNum', 'ship', 'arrivalDate', 'policeNum', 'surname', 'forename', 'sentencedWhere', 'triedDate', 
             'sentence', 'religion', 'literacy', 'transportedFor', 'gaolRpt', 'hulkRpt', 'maritalStatus', 'statedThisOffence', 
             'family', 'surgeonsRpt', 'trade', 'heightFt', 'heightIn', 'age', 'hair', 'eyes', 'birthPlace', 'bodyMarks', 
             'sourceVol', 'sourcePage', 'imgUrl', 'transcribersComment' );
  }
  elsif ( $doctype =~ m/(dlf)/i ) {  # con19 female desc lists; 
# As per 'dl' without pnInitial, sentencedWhere, triedDate, sentence (empty)
# CON19: LINE NUMBER	POLICE NUMBER		SURNAME	FIRST NAME	SHIP	DATE OF ARRIVAL	TRADE	HEIGHT FEET	HEIGHT INCHES	AGE	HAIR	EYES	REMARKS	NATIVE PLACE	PAGE	RECORD NUMBER	COMMENTS	SOURCE	URL
    return ( 'lineNum', 'policeNum', 'surname', 'forename', 'ship', 'arrivalDate', 
             'trade', 'heightFt', 'heightIn', 'age', 'hair', 'eyes', 'bodyMarks', 'birthPlace', 
             'sourcePage', 'sourceOrderOnPage', 'transcribersComment', 'sourceVol', 'imgUrl' );
  }
  elsif ( $doctype =~ m/(dlm)/i ) {  # con18 male desc lists
# CON18: LINE NUMBER	POLICE NUMBER		SURNAME	FIRST NAME	SHIP	DATE OF ARRIVAL	PLACE SENTENCED	DATE OF SENTENCE	SENTENCE	TRADE	HEIGHT FEET	HEIGHT INCHES	AGE	HAIR	EYES	REMARKS	NATIVE PLACE	PAGE	RECORD NUMBER	COMMENTS	SOURCE	URL
    return ( 'lineNum', 'policeNum', 'pnInitial', 'surname', 'forename', 'ship', 'arrivalDate', 'sentencedWhere', 'triedDate',
             'sentence', 'trade', 'heightFt', 'heightIn', 'age', 'hair', 'eyes', 'bodyMarks', 'birthPlace', 
             'sourcePage', 'sourceOrderOnPage', 'transcribersComment', 'sourceVol', 'imgUrl' );
  }
  elsif ( $doctype =~ m/(c23a)/i ) {  # con23 male desc lists -- supplement to con18
# LINE N0.	POLICE N0.	SURNAME	FORENAME	HEIGHT	COMPLEXION	HAIR	EYES	AGE	TRADE	WHERE SENTENCED	DATE TRIED	SENTENCE	COLONIAL CONVICTION [USUALLY ENTERED BELOW THE ORIGINAL CONVICTION]	SHIP	DATE OF ARRIVAL	NATIVE PLACE	MARKS	NUMBER & DATE OF FREE CERTIFICATE FREE PARDON OR EMANCIPATION	MARRIED OR NOT ON ARRIVAL	RELIGION	REMARKS	COMMENTS	SOURCE

    return ( 'lineNum', 'policeNum', 'surname', 'forename', 
             'height', 'complexion', 'hair', 'eyes', 'age', 'trade', 'sentencedWhere', 'triedDate', 'sentence',
             'colonialConviction', 'ship', 'arrivalDate', 'birthPlace', 'bodyMarks', 
             'freedomDetails', 'maritalStatusOnArr', 'religion', 'remarks',
             'transcribersComment', 'sourceVol');
  }
  else {
    print STDERR "$0 #error# doctype[$doctype] TODO_FIELDS_NOT_YET_IMPLEMENTED\n";
    return ( 'TODO_FIELDS_NOT_YET_IMPLEMENTED' ); 
  }
}

#--------------------------------------- dataroot
sub dataroot {
  my $doctype = shift;
  my $s = <<xmlTOP;
<?xml version="1.0" encoding="UTF-8"?>
<dataroot xmlns:od="urn:schemas-microsoft-com:officedata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"  xsi:noNamespaceSchemaLocation="${doctype}.xsd" generated="2009-10-30T00:11:59">
xmlTOP
  return $s;
}

sub doDesc {
  my $RT = shift;
  my $format = shift;
  my @c = &columns($RT); ########## unless $RT =~ m/c31s, c33s, c37s, c40s, c41s/;
  # require the config file for this type (except for crs, is a compound file of c31s, c33s, c40s, c41s)
  $indir{c31s} = $indir{c33s} = $indir{c40s} = $indir{c41s} = $indir{c37s} = 'crs';
  $use = $indir{$RT} || $RT;
  undef %C;
  require "$ENV{FASREPO}/${use}/00-xml-config.pl";
  $transdoc = '';
  $aotonline = '';
  if ($format eq 'xml') {
    $transdoc = "Transcription documentation: " . $ENV{FASREPO_URL} . "documentation/" . $C{DOCUMENTATION} if ($C{DOCUMENTATION});
    $aotonline = "<ref type=\"aot\">AOT Series Details for $C{AOTONLINE}: " .
                 'http://search.archives.tas.gov.au/default.aspx?detail=1&amp;type=S&amp;id=' .
                 $C{AOTONLINE} . "</ref>\n"  if $C{AOTONLINE};
    print "\n<fsRecord type=\"raw\" xml:id=\"FD.$RT\" key=\"$RT\" n=\"$C{NUMRECS}\">\n";
    print "  <desc>\n" .
          "    <label>$C{DESC}</label>\n" .
          "    <workflow>$C{SOURCE}</workflow>\n" .
          "    <ref type=\"fasdoc\">$transdoc</ref>\n$aotonline" .
          "  </desc>\n  <fsFieldList>\n";
  }
  my $alpha = ' ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  $i = 0;
  foreach (@c) {
    $i++;
    my $excelCol = substr($alpha,$i,1);
    if ($i > 52) {
      $excelCol = 'B' . substr($alpha,($i - 52),1);
    }
    elsif ($i > 26) {
      $excelCol = 'A' . substr($alpha,($i - 26),1);
    }
    if ($format eq 'xml') {
      $sp_key = "${RT}.$_";
      $desc = '';
      if ( $C{KEYS}{$_} ) {
        $desc .= " Generally for \"$_\": " . $C{KEYS}{$_};
      }
      if ( $C{KEYS}{$sp_key} ) {
        $desc .= " Specifically for \"$sp_key\": " . $C{KEYS}{$sp_key};
      }

      print <<fsFieldMODEL;
<fsField xml:id="FD.${RT}.$_" key="$_" >
  <elementName column="$i">$_</elementName>
  <column>$i</column>
  <desc>In original source file type \"$RT\", column $i or $excelCol is XML element \"$_\".$desc</desc>
</fsField>
fsFieldMODEL
    }
    elsif ( $format eq 'compact' ) {
      print "\$FD{$RT}{$_}{colnum} = ${i};\n";
      print "\$FD{$RT}{$_}{colpos} = \"$excelCol\";\n";
      print "\$FD{$RT}{qnames} .= \"$_,\";\n";
    }
    else {
      printf "Source rectype <$RT> column %2d or %s maps to xml element <%s>\n",($i,$excelCol,$_);
    }
  }
  if ($format eq 'xml') {
    print "  </fsFieldList>\n</fsRecord>\n";
  }
}

sub loadFDextraInfo {
  open (F,"$ENV{FASREPO}/fas_common/fasDictionary.txt");
  while (<F>) {
    next if m/^#/;
    chop;
    ($key,$desc) = split(/\t/,$_,2);
    $C{KEYS}{$key} = $desc; 
  }
  close(F);
}
