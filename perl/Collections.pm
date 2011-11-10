package Collections;
################################################################################# Collections
# Cloned from Fasutil to handle rifcs and project collection documentation
# 
# Backend controller/processor for /pub/ands/xforms xsltforms
#
# V00.1  2011-03-30 sms initial version
# Copied from /srv/fasweb/perl by claudine on 2011-11-10.
########################################################################################
use strict;

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Util ();
use Apache2::Const -compile => qw(:common);
use encoding "utf8";
use XML::LibXML;
use XML::LibXML::XPathContext;
use XML::LibXSLT;
use CGI::Cookie;
use Text::Soundex;
use Text::JaroWinkler qw( strcmp95 );
use Text::LevenshteinXS qw(distance);

# for lkt access
use fasLinkClient;

# for basex access over socket
use BaseX;
use Time::HiRes;

use POSIX qw(strftime);
use vars qw[$now $userwas $VER $UDIR $INST $WEBWORKDIR %OBJECTS $TREEDATA $objNames @SRC $SRCDESC $SRCLIST $BASEX_PATH $FASREPO $FASREPO_PUBTO 
            $DEFAULT_PROJECT $RIFCS_MASTER_FILE $RXMASTER $RXMASTER_XC $RXTREE $RXTREE_XC
            $XSLT_DEFAULT $XSL_PATH %G $MALENODES $FEMALENODES 
            $MALEDEATHTARGETS $FEMALEDEATHTARGETS $SHIPSDOC $SHIPSDOC_XC ];
my $VER = "0.21b";
my $userwas = '';
my $INST = "UNIMELB";
my $now = localtime();
my $UDIR = "/srv/fasweb/webwork"; # dir for saving parms and user parm sets
my $WEBWORKDIR = "/srv/fasweb/webwork/rifcs"; # dir for saving rifcs and models for each collection
my $XSLT_DEFAULT = 'fasQuery-dev.xsl';
my $FEEDBACK = 'http://founders-and-survivors/prot/staffwiki/';
my $BASEX_PATH = '/media/disk2/basex';
my $XSL_PATH = '/pub/xsl';

# ------------------------------- init list of all objects, ids, names (restart apache as required)
# grab namePart from projects in $WEBWORKDIR : each object name corresponds to a file in $WEBWORKDIR/edited
my $objNames = `cd $WEBWORKDIR;grep namePart */edited/*`;
$objNames =~ s~/edited/~:~g;
$objNames =~ s~\s*\<\/?namePart\>~~g;
my $objLabels = '<div type="objects">';
my %OBJECTS = ();
foreach my $line ( split(/\n/,$objNames) ) {
   my ($project,$localid,$name) = split(/:/,$line,3);
   next if ($name =~ m/^INIT/);
   # for reference
   $OBJECTS{$project}{$localid} = $name;
   # for insertion into masterfile index
   $objLabels .= '<objectName localid="'.$localid.'">'.$name.'</objectName>'."\n";
}
$objLabels .= '</div>'."\n";


# Load an xml master file of rifcs details
my $DEFAULT_PROJECT = "FAS";
#my $RIFCS_MASTER_FILE = "$WEBWORKDIR/$DEFAULT_PROJECT/00masterdb_collection-links_DEVEL.xml"; # DEVEL
my $RIFCS_MASTER_FILE = "$WEBWORKDIR/$DEFAULT_PROJECT/00masterdb_collection-links.xml"; # live
############## do we REALLY NEED the above??? #################

# read the tree file, insert the objectNames, and parse it
my $masterfile = masterfile_name($DEFAULT_PROJECT);
my $TREEDATA = ''; open (MF,$masterfile); 
while (<MF>) { if ( m/^\s*<interface/ ) { $TREEDATA .= $objLabels; } $TREEDATA .= $_; } close (MF); 
my $RXTREE = XML::LibXML->load_xml( string => $TREEDATA );
my $RXTREE_XC = XML::LibXML::XPathContext->new($RXTREE);
my $RXMASTER = XML::LibXML->load_xml( location => $RIFCS_MASTER_FILE );
my $RXMASTER_XC = XML::LibXML::XPathContext->new($RXMASTER);
# usage: 
# my $keys = $RXMASTER_XC->findnodes('//uri') ;
# my $keyrefs = $RXTREE_XC->findnodes('//ref') ;
# If FAS is default project, load bateson ships so we can auto generate shipsIndex collection
my ($SHIPSDOC,$SHIPSDOC_XC) = '';
if ( $DEFAULT_PROJECT eq "FAS" ) {
     $SHIPSDOC = XML::LibXML->load_xml( location => "/srv/basex/basex/raw_b4a/b4a-cleaned.xml" ); 
     $SHIPSDOC_XC = XML::LibXML::XPathContext->new($SHIPSDOC);
}


sub handler {
    my $r = shift;
    $now = strftime('%Y-%m-%dT%H:%M:%S', localtime);
    my $me = $ENV{SCRIPT_NAME};
    my $pi = $ENV{PATH_INFO};
    my $qs = $ENV{QUERY_STRING};
    my $q = '';
    my $qtype = '';
    my $xslt = '';
    my %G = ();
    $G{'ERR'} = 0;

    # get post parameters
    my $debugQuery = "me=[$me] pi=[$pi] qs=[$qs]\n";
    my %PM = '';
    my ($dbg,$parmsAsXml) = fasQueryValidParameters($r,\%PM);
    my $matchFilter = ''; 
    $debugQuery .= "\ndbg[$dbg]\n";
    foreach ( keys %PM ) {
      if ($_ eq "src") {
        $matchFilter = "('".join("','",keys %{$PM{'src'}})."')";
        $debugQuery .= "after{src}hashKeys[".join(",",keys %{$PM{'src'}})."] matchFilter[$matchFilter] ";
      }
      else {
        $debugQuery .= "after{$_}=[".$PM{$_}."] ";
      }
    }
    # we are public but may have come from prot page
    unless ($PM{userwas}) {
       if ( $ENV{REQUEST_URI} =~ m~\?userwas=([a-zA-Z0-9\_\-]+)$~ ) { $PM{userwas} = $1; }
    }
    $userwas = $PM{userwas};

    # PATH_INFO => /pub/collections/sims/string1/string2
    # QUERY_STRING => ? (unused)

    # ------------------------------ construct collections data instance for xforms client
    if ( $ENV{PATH_INFO} =~ m~^/([A-Z0-9]+):(ALL|collection\-links.xml)~ ) {
       my $project_id = $1; 

       ####OLD####my $output = &generate_collection_xml($project_id);
       # This version includes a tree showing hierarchy
       my $output = generate_collection_xml_from_tree($project_id);

       logAnswer($r, $output,"collection-links.xml");
       print_mimetype($r);
       $r->print( $output );

    }
    # ---------------------------------------------------------------------- view constructed xml for metadata
    # Render to html with xslt server side if action=html

    elsif ( $ENV{PATH_INFO} =~ m~^/((view)|(html))/([A-Z0-9]+):([a-zA-Z0-9\-\_\.]+)~ ) {
       my $action = $1; 
       my $project_id = $4; 
       my $object_id = $5; 
       my $xml = '';
       if ( $object_id eq 'ALL' ) {
           $xml = &generate_ands_deployable_rifcs($project_id);
       }
       else {
           $xml = &gen_rifcsxml($project_id, $object_id, $object_id);
       }
       if ( $action eq 'html' ) {

          # transform: the xml, the styleshee, the LOCALKEY (passed for display but not part of rifcs)
          my $html = apply_transform_rifcs_to_html($xml,
                                                   "/srv/fasweb/webwork/rifcs/${project_id}/xslt/rifcs-to-html.xsl",
                                                   ${project_id},$object_id);

          logAnswer($r, "---- xml:[$xml]\n".
                        "---- html:[$html]",
                        "$action");
          print_mimetype($r,'html');
          $r->print( $html );

       }
       else {
          logAnswer($r, $xml,"$action");
          print_mimetype($r);
          $r->print( $xml );
       }
    }
    # ---------------------------------------------------------------------- view all collections in a project
    # e.g. /pub/collections/FAS

    elsif ( $ENV{PATH_INFO} =~ m~^/([A-Z0-9]+)/?$~ ) {
       my $action = 'allInProjectTree'; 
       my $project_id = $1; 
       ##my $output = '';
       ##$output = &generate_collection_xml($project_id);

       # if we add a query string, reload afresh from the masterfile (eg. ?refresh after editing)
       if ( $qs ) {
            my $masterfile = masterfile_name($project_id);
            $TREEDATA = ''; open (MF,$masterfile);
            while (<MF>) { 
               if ( m/^\s*<interface/ ) { $TREEDATA .= $objLabels; } 
               # entity substitution for generated collection rifcs e.g. shipIndex
               # be careful with the xml formatting here, we are just perl hacking it, not parsing
               if ( s/^\s*<entity type="([^"]+)" *(parameters="([^"]+)")? *\/\> *// ) { $TREEDATA .= generate_entity($1,$3); }
               $TREEDATA .= $_; 
            }
            close (MF);
            $RXTREE = XML::LibXML->load_xml( string => $TREEDATA );
       }

       my $xml = $RXTREE->toString; # includes xml declaration

       my $html = apply_transform_rifcs_to_html($xml,
                                                "/srv/fasweb/webwork/rifcs/${project_id}/xslt/rifcs-to-html.xsl",
                                                ${project_id},'');

       logAnswer($r, "---- xml:[$xml]\n".
                     "---- html:[$html]",
                     "$action");
       print_mimetype($r,'html');
       $r->print( $html );

       ####debug_OBJECTS();
       ####print_mimetype($r,'omit_xml_dec');
       ####$r->print( $output );

    }

    # ---------------------------------------------------------------------- view collections

    elsif ( $ENV{PATH_INFO} =~ m~^/(select|rifcs_data)/([A-Z0-9]+):([a-zA-Z0-9\-\_\.]+)~ ) {
       my $action = $1; 
       my $project_id = $2; 
       my $object_id = $3; 
       my $output = '';
       my $procLog = '';
       my $logic = '';
       my ($rifcsFile,$rifcsUserData) = get_rifcsUserData($project_id,$object_id);

       # 
       if ( -f $rifcsFile ) {
          $procLog .= "<p>project $project_id collection [$object_id] exists [$rifcsFile]</p>"."\n";
          $procLog .= $rifcsUserData;
          $logic .= '1';
       }
       else {
          $procLog .= "<p>project $project_id collection [$object_id] DOES NOT exist -- create it using INIT</p>"."\n";
          my ($x,$initialiseUserData) = get_rifcsUserData($project_id,"INIT");

          # substitute $object_id for "INIT" and write file
          $initialiseUserData =~ s/INIT/$object_id/g;
          my $error = set_rifcsUserData($project_id,$object_id,$initialiseUserData);
          if ( $error ) {
               $procLog .= "<p>WOOPS -- $error</p>\n";  
          }
          elsif ( -f $rifcsFile ) {
               $procLog .= "<p>Successfully created rifcsFile[$rifcsFile]</p>"."\n";
               $rifcsUserData = $initialiseUserData;
               $procLog .= $rifcsUserData;
          }
          else {
               $procLog .= "<p>WOOPS -- rifcsFile[$rifcsFile] not found</p>\n";  
          }
          $logic .= '2';
       }

       if ( $action eq 'rifcs_data' ) {
           if ( $rifcsUserData ) {
              $output = $rifcsUserData; 
              $logic .= '4';
           }
           else {
              $output = get_rifcsUserData($project_id,$object_id);
              $logic .= '5';
           }
       }
       else {
    
            $logic .= '6';
            $output .= "<cmd type=\"$action\" method=\"".$r->method."\">\n<REQUEST_URI>".$r->method." $ENV{REQUEST_URI}</REQUEST_URI>\n"
                . "<processing>$procLog</processing>\n"
                . "</cmd>";
       }
       logAnswer($r, $output,"$action ($logic)");
       print_mimetype($r);
       $r->print( $output );
    }
    else {
#if (1) {
      
       ### unkown request ###
       my ($escapedArgs, $showArgs) = ''; 
       if ( $r->method eq 'POST' && $PM{posted_xmldoc} ) {
          my $valid_xml = XML::LibXML->load_xml( string => $PM{posted_xmldoc} );
          my $output = $PM{posted_xmldoc};
          logAnswer($r, $valid_xml,"logic POST+posted_xmldoc");
          print_mimetype($r);
          $r->print($PM{posted_xmldoc});
       }
       elsif ( $r->method eq 'POST' || $r->method eq 'PUT' ) {
          my $output = '';
          ##($escapedArgs, $showArgs) = getPostArgs($r);
          $output .= "<unknownRequest VER=\"$VER\" xmlns=\"\" method=\"POST\" referer=\"$ENV{HTTP_REFERER}\"><h4>POST REQUEST_URI=[$ENV{REQUEST_URI}]</h4>\n<parmsAsXml>" . $parmsAsXml . "</parmsAsXml>\n";
          $output .= "<putdata>".$PM{putdata}."</putdata>\n" if ( $PM{putdata} );
          $output .= "<unnamedParam>".$PM{unnamedParam}."</unnamedParam>\n" if ( $PM{unnamedParam} );
          $output .= "<posted_xmldoc>".$PM{posted_xmldoc}."</posted_xmldoc>\n" if ( $PM{posted_xmldoc} ) ;
          $output .=  &showEnv() ;
          $output .= "</unknownRequest>\n";
          logAnswer($r, $output,"logic:post/put");
          print_mimetype($r);
          $r->print($output);
       }
       else {

          my $output ='';
          $output .= "<unknownRequest  VER=\"$VER\" method=\"".$r->method."\"><h4>".$r->method." $ENV{REQUEST_URI}</h4>";
          $output .= &showEnv() ;
          $output .= "</unknownRequest>";
          logAnswer($r, $output,"logic:noneOfAbove");
          print_mimetype($r);
          $r->print($output);
       }

    }
    return Apache2::Const::OK;

}

# ---- masterfile name
sub masterfile_name {
    my $project_id = shift;
    #return "$WEBWORKDIR/$project_id/00masterdb_collection-links.xml";
    return "$WEBWORKDIR/$project_id/00masterdb_tree.xml";
}

sub apply_transform_rifcs_to_html {
  my $s = shift;
  my $xslFile = shift;
  my $project_id = shift;
  my $object_id = shift;

  my $localkey = "${INST}:${project_id}:$object_id";

  my $xml_parser  = XML::LibXML->new;
  my $xslt_parser = XML::LibXSLT->new;

  my $p_xml       = $xml_parser->parse_string($s);
  my $xsl         = $xml_parser->parse_file($xslFile);
  my $stylesheet  = $xslt_parser->parse_stylesheet($xsl);

  ## Pass xslt parameters as perl LibXSLT ##

  my $uri = 'http://'. $ENV{SERVER_NAME} . $ENV{REQUEST_URI};
  my $uri_relobj = 'http://'. $ENV{SERVER_NAME} . $ENV{SCRIPT_NAME} . '/html/' . $project_id ;
  my $uri_rifcsobj = 'http://'. $ENV{SERVER_NAME} . $ENV{SCRIPT_NAME} . '/view/' . $project_id . ':';
  $uri =~ s~\?userwas=[a-zA-Z0-9\_\-]+~~; # kill this hack
  my $results     = $stylesheet->transform($p_xml, XML::LibXSLT::xpath_to_string(
                      INST => $INST ,
                      PROJECT => $project_id ,
                      OBJECT => $object_id ,
                      LOCALKEY => $localkey ,
                      THISURI => $uri ,
                      URI_RELOBJ => $uri_relobj ,
                      URI_RIFCSOBJ => $uri_rifcsobj ,
                      GENDATE => $now ,
                      USER => $userwas
                    )
                  );
  return $stylesheet->output_string($results);

}


sub debug_OBJECTS {
   my $dbgO = '';
   foreach my $p ( keys %OBJECTS ) {
      foreach my $id ( keys %{$OBJECTS{$p}} ) {
         $dbgO .= "..p[$p] id[$id] name[".$OBJECTS{$p}{$id}."]\n";
      }
   }
   logLine($dbgO);
   logLine("..objNames=[$objNames]\n");
}

sub logLine {
  my $s = shift;
  open (LOG,">>/tmp/Collections.pm.log");
  print LOG "\ndbg[$s]\n";
  close(LOG);
}

sub logAnswer {
  my $r = shift;
  my $s = shift;
  my $headNote = shift;
  open (LOG,">>/tmp/Collections.pm.log");
  print LOG "####\n---------------------- VER:$VER $now userwas[$userwas] ".$r->method." PATH_INFO:[$ENV{PATH_INFO}] [$headNote]\nREFERER:[$ENV{HTTP_REFERER}]\nREQUEST_URI:[$ENV{REQUEST_URI}] output:\n$s\n"; 
  close(LOG);
}

# ---- process the collection master for ands deployable rifcs and generate a document
sub generate_ands_deployable_rifcs {
    my $project_id = shift;
    ####my $masterfile = masterfile_name($project_id);
    ####my $doc = XML::LibXML->new->parse_file($masterfile);

    # use the new tree structure
    my $masterfiledata = generate_collection_xml_from_tree($project_id);
    my $doc = XML::LibXML->new->parse_string($masterfiledata);

    my $xp = XML::LibXML::XPathContext->new($doc); # xpath context
    my $registryObjectsDeclarationTemplate = "$WEBWORKDIR/$project_id/00templates/rifcs-submit.xml";
    my $registryObjectsDeclaration = "";
    open (DF,$registryObjectsDeclarationTemplate); 
    while (<DF>) { 
        if ( m~^\<registryObjects.+~ ) { 
            $registryObjectsDeclaration = $_; 
            last;
        } 
    } 
    close (DF); 

    my $rifcs = $registryObjectsDeclaration || '<registryObjects>';

    foreach my $n ( $xp->findnodes('//link[@ands_deployment="true"]') ) {
       my $localid = $n->findvalue('rifcs_data/@id');
       my $label = $n->findvalue('label');
       my $uri = $n->findvalue('uri');
       my $status = $n->findvalue('status');
       my $rifcs_data = $n->findvalue('rifcs_data');
       &logLine(".. ---- generate_ands_deployable_rifcs project_id[$project_id] localid[$localid] rifcs_data[".$n->toString."]");

       my $this_rifcs .= &gen_rifcsxml($project_id, $uri, $localid);

       # strip the registryObjects wrapper
       $this_rifcs =~ s~\<registryObjects .+~~;
       $this_rifcs =~ s~\<\/registryObjects\>~~;
       $rifcs .= $this_rifcs;
    }
    $rifcs .= "</registryObjects>\n";
    return $rifcs;
}

sub generate_collection_xml_from_tree {
    my $project_id = shift;
    my $output = "";
   
    # include objects from <div type="index"> which have a objectName in <div type="objects"> oXPATH
    # /data/div[@type='index']//item[@localid=/data/div[@type='objects']/objectName/@localid]/
    # for now just read the file system
    my $listIds = '';
    $listIds = $RXTREE_XC->findnodes('//objectName[@localid != "INIT"]') ;
    #logLine( "\n########################################################### test:\n" );
    my ($rifcsFile,$rifcsUserData,$output) = '';

    $output = $TREEDATA; $output =~ s~<OBJECTS\/>\n~~; $output =~ s~<\/data>\n~~;

    # loop through objectNames and create rif cs

    my $i = 0;
    foreach my $n ( $listIds->get_nodelist ) {

      my $id = $n->findnodes('@localid')->string_value();
      my $name = $n->findnodes('./text()')->string_value();
      #logLine( "..id[$id] name[$name] [".$n->toString()."]" );
      ($rifcsFile,$rifcsUserData) = get_rifcsUserData($project_id,$id);  
      $i++;
      # the editing interface wants this
      $output .= "<link n=\"$i\" ands_deployment=\"true\">\n".
                 "<label>$name</label>\n".
                 "<uri>$id</uri>\n".
                 $rifcsUserData .
                 "</link>\n";

    }
    $output .= '</data>'."\n";
    #logLine( "\n########################################################### generate_collection_xml_from_tree:\n[". $output ."]\n" );
    return $output;
}

sub generate_collection_xml {
    my $project_id = shift;
    my $output = "";

    # the data in the masterfile is ADDITIONAL to RIF-CS
    # and is for controlling this system and delivery of actual content

    my $masterfile = masterfile_name($project_id);
    open (COLL,$masterfile);
    my ($rifcsFile,$rifcsUserData) = '';
    while (<COLL>) { 
        my $line = $_;
        if ( m~\<uri\>([^\<]+)\<\/uri\>~ ) {
           # in a new collection
           ($rifcsFile,$rifcsUserData) = get_rifcsUserData($project_id,$1);
        }
        if ( m~\<\/link\>~ ) {
           # append the user edited stuff to the controlled stuff
           $output .= $rifcsUserData;
        }
        $output .= $line; 
    } 
    close(COLL);
    return $output;
}

# ------- calc the name of the source generated data
sub rifcs_GEN_datafile_name {
  my $project_id = shift;
  my $genType = shift;
  my $object_id = shift;
  return "$WEBWORKDIR/$project_id/generated/$genType/${object_id}";
}

# ------- calc the name of the source edited data
sub rifcs_datafile_name {
  my $project_id = shift;
  my $object_id = shift;
  return "$WEBWORKDIR/$project_id/edited/${object_id}";
}

# ------- rifcs data for edit in FILES in: proj/edited/${object_id}
sub get_rifcsUserData {
  my $project_id = shift;
  my $object_id = shift;
  my $rifcsFile = rifcs_datafile_name($project_id,$object_id);
  my $rifcsUserData = '';
  if ( -f $rifcsFile ) {

     ##############################################
     # the rifcs desc exists on the file system
     ##############################################

     open (F,$rifcsFile); while (<F>) { $rifcsUserData .= $_; } close(F);
  }
  elsif ( $object_id =~ m~GEN\-shipIndex\-(.+)~ ) {

     ##############################################
     # generated rifcs for shipIndex
     ##############################################

     my $genType = 'shipIndex';
     my $genKey = $1;
     if ( $genKey eq 'idx' ) {
         $rifcsFile = rifcs_GEN_datafile_name($project_id,$genType,'GEN-shipIndex-idx');
         open (F,$rifcsFile); while (<F>) { $rifcsUserData .= $_; } close(F);

         # Read bateson reference

         my $s = '';
         my $ro = '';
         my @n =  $SHIPSDOC_XC->findnodes('//b4a[toColony="VDL" or toColony="NI" or toColony="PP"]');
         my $num = 0;
         foreach my $n ( @n ) {
                  $num++;
                  my $shipid = $n->findvalue('@n');
                  my $toColony = $n->findvalue('toColony');
                  my $shipNameNorm = $n->findvalue('shipNameNorm');
                  my $VdlShipName = $n->findvalue('VdlShipName') || $shipNameNorm;
                  my $arrDate = $n->findvalue('arrivalDate');
                  my $arrYr = substr( $n->findvalue('arrivalDate'), 0, 4);
                  my $pop = $n->findvalue('populations'); $pop =~ s~/~; ~g; 
                 
                  my $arrYr = substr ( $n->findvalue('arrivalDate') , 0, 4 );
                  my $test = $VdlShipName . ' arr '. $arrDate . " ($pop)";
                  
                  $s .= "<p> * <b>$shipid</b> : $test</p>\n";
                  $ro .= <<relOBJ;
<relatedObject local_id="c-GEN-shipIndex-$shipid">
<key/>
<relation type="describes">
<description>FAS Convict Ship $shipid $VdlShipName arr $arrYr at $toColony Prosopography Index</description>
</relation>
</relatedObject>
relOBJ

                  #my $test = $shipid . ' ' . $shipNameNorm . ' arr '. $arrYr . ' at ' . $toColony;
                  #$s .= '<item type="dataset" generated="shipIndex" localid="c-GEN-shipIndex-'.$shipid.'" '.
                  #       'ands_deployment="true" '.
                  #       "label=\"$label\" ";

                  ## is the tei file deployed? If so, allow link to it as its metadata is a superset of the RifCS.
                  #if ( -d "$teidir/$shipid" ) {
                  #   $s .= 'teiurl="'.$webUri.'/tei/'.$shipid.'/index.xml" ' if ( -f "$teidir/$shipid/index.xml" );
                  #   $s .= 'htmurl="'.$webUri.'/tei/'.$shipid.'/index.htm" ' if ( -f "$teidir/$shipid/index.htm" );
          }
         $s .= '';
         $rifcsUserData =~ s~###GENINDEX###~$s~;
         $rifcsUserData =~ s~###RELATEDOBJECTS###~$ro~;
     }
     else {
         $rifcsFile = rifcs_GEN_datafile_name($project_id,$genType,'GEN-shipIndex-SHIPID');
         open (F,$rifcsFile); while (<F>) { $rifcsUserData .= $_; } close(F);
         $rifcsUserData =~ s~(<identifier.+)###SHIP###(.+)~${1}${genKey}${2}~;
         foreach my $n ( $SHIPSDOC_XC->findnodes('//b4a[@n="'.$genKey.'"]') ) {
            my $toColony = $n->findvalue('toColony');
            my $VdlShipName = $n->findvalue('VdlShipName') || $n->findvalue('shipNameNorm');
            my $arrYr = substr( $n->findvalue('arrivalDate'), 0, 4);
            my $arrDate = $n->findvalue('arrivalDate');
            my $pop = $n->findvalue('populations'); $pop =~ s~/~; ~g; 
            my $label = $genKey . " " . $VdlShipName . ' arr '. $arrYr . " at " . $toColony;
            $rifcsUserData =~ s~###SHIP###~$genKey~g;
            $rifcsUserData =~ s~###SHIPNAME###~$VdlShipName~g;
            $rifcsUserData =~ s~###SHIPARRDATE###~$arrDate~g;
            $rifcsUserData =~ s~###SHIPPOP###~$pop~g;
            $rifcsUserData =~ s~###SHIPTO###~$toColony~g;
            $rifcsUserData =~ s~###SHIPLABEL###~$label~;
         }
     }
  }
  else {

     ##############################################
     # use INIT as skeletal collection
     ##############################################
     
     $rifcsFile = rifcs_datafile_name($project_id,'INIT');
     open (F,$rifcsFile); while (<F>) { $rifcsUserData .= $_; } close(F);
     $rifcsUserData =~ s~<description~<description type="WARNING">object_id [$object_id] does not exist. You are viewing a skeleton of a new collection.</description>\n<description~;
  }
  return ( $rifcsFile, $rifcsUserData );
}

sub set_rifcsUserData {
  my $project_id = shift;
  my $object_id = shift;
  my $rifcsUserData = shift;
  my $rifcsFile = rifcs_datafile_name($project_id,$object_id);
  my $err = '';
  if ( open (F,">$rifcsFile") ) {
       print F $rifcsUserData;
       close(F);
  }
  else {
     $err = "Failed to open rifcsFile[$rifcsFile] [$!]";
  }
  return $err;
}

sub gen_rifcsxml {

  my $project_id = shift;
  my $object_id = shift;
  my $localid = shift;

  # data driven template substitution: create files in 
  # $WEBWORKDIR/$project_id/00templates/common_$tplName

  #my $common_tpl = "accessRightsSTAFF,relatedInfo,relatedObjects,subjects_anzsrc-for";
  my $common_tpl = `cd $WEBWORKDIR/$project_id/00templates; ls common_* | xargs`; 
  
  my %tpl = ();
  foreach my $tplName ( split(/ /, $common_tpl) ) {
     my $key = "${project_id}:$tplName";
     my $template_filename = "$WEBWORKDIR/$project_id/00templates/$tplName";
     $tpl{$key} = "";
     if ( open (TF, $template_filename) ) {
          while (<TF>) { $tpl{$key} .= $_; } close(TF);
     }
     ####&logLine("..key[$key] template_filename[$template_filename] tpl[".$tpl{$key}."]");

  } 

  # this is the core stuff the user has edited
  my ($rifcsFile,$rifcsUserData) = get_rifcsUserData($project_id,$object_id);

  # make substitutions
  $rifcsUserData =~ s~\<TOBE_INCLUDED type="([^"]+)" *\/\>~$tpl{$1}~g;

  # generated stuff
  if ( $project_id eq 'FAS' && $object_id eq 'crs' ) {
    my $generatedData = &fas_rectype_relatedInfo($object_id);
    $rifcsUserData =~ s~\<TOBE_GENERATED type="fas_rectype_relatedInfo" *\/\>~$generatedData~;
  }

  # it will be wrapped in this xml template
  my $tplDir = "$WEBWORKDIR/$project_id/00templates";
  my $xmlFile = "$tplDir/rifcs-submit.xml";
  my $xml = '';
  my $doLocalId = 0; if ( ($ENV{QUERY_STRING} eq 'withlocalid') && $localid ) { $doLocalId = 1; }
  logLine("..TEST:withlocalid=".$ENV{QUERY_STRING}."\n");
  if ( open (T,"$xmlFile") ) {
       while (<T>) {
          if ( $doLocalId ) {
              $doLocalId = 0 if s~\<registryObject group~\<registryObject id="${localid}" group~;
          }
          if ( s~\<TOBE_INCLUDED type="([^"]+)" *\/\>~~ ) {
             my $before = $`;
             my $after = $';
             $xml .= $before;
             my $template = $1;
             my $proj = $project_id;
             if ( $template =~ s/^([^:]+):([^:]+)$// ) {
                $proj = $1;
                $template = $2;
             }

             # make the substitution
             if ( $template eq 'collection' ) {
                $rifcsUserData =~ s~\<\/?rifcs_data.+\n~~g; # kill the rifcs_data wrapper
                $rifcsUserData =~ s~\.\.today\.\.~$now~g ; # date substitution
                $xml .= $rifcsUserData;
             }
             else {
                my $sub = `cat $tplDir/$template`;
                if ($sub) {
                    $xml .= $sub;
                }
                else {
                    $xml .= "<error>####Content of template [$proj:$template] not yet defined####</err>";
                }
             }
             $xml .= $after;
          }
          else {
             $xml .= $_;
          }
       }
       close(T);
  }
  else {
    $xml = "<error>$!</error>\n";
  }

  # and lastly substitute entity definitions for the project
  if ( open (ENTS,"$tplDir/entity_definitions.txt") ) {
     
     while (<ENTS>) {
       chop;
       my ( $entity, $content ) = split( /\t/, $_, 2);
       ####logLine("#check ENTS# ${project_id}:$object_id ent[$entity] con[$content]");
       # use [[[entname]]] as the inline text otherwise parsers will croak
       # we only expand this here when generating the RIF-CS
       $xml =~ s~\[{3}$entity\]{3}~$content~g;
       # if needed to debug
       #while ( $xml =~ s~\[{3}$entity\]{3}~$content~ ) {
       #   logLine("    ..replaced [$entity]\n");
       #}
     }
     # global entities
     $xml =~ s~\[{3}keyLocal\]{3}~${INST}:${project_id}:${object_id}~g;
     $xml =~ s~\[{3}TODAY\]{3}~$now~g;

     close (ENTS);
  }
  else {
     ####logLine("#NOENTS#");
     1;
  }


  return $xml;
}

sub showEnv {
  my $s = "<environment>\n";
  foreach ( sort keys %ENV ) {
     my $v = &escapeAmp($ENV{$_});
     $s .= "<l>${_}=[$v]</l>\n";
  }
  return $s ."</environment>\n";
}


sub query_xml_basex {
  my $r = shift;
  my $fastype = shift;
  my $q  = shift;
  my $verbose  = shift;
  my $noprint = shift; # return <query> and <result> elements to the caller
  my $userinfo = shift;
  $userinfo = $q unless $userinfo;

  my $s = 'no session';
  my $n = 0;

  # if the outage file is in place, do't run
  my $outage = 'The BaseX XML database is unavailable. Please try later.';
  if ( open (M,"$BASEX_PATH/OUTAGE")  ) { 
     $outage = ''; while (<M>) { $outage .= $_; } 
     close(M) 
  }
  else { $outage = '';}
  if ($outage) {
    $r->print("<weberror>$outage</weberror>\n");
    return ($n,$s);
  }

  if ( $fastype eq 'run_xquery_file' ) {
    $q = "run ${BASEX_PATH}/xquery/$q"; # $q is a filename
  }
  elsif ( $fastype eq 'run_xquery_file_fullpath' ) {
    $q = "run $q"; # $q is a filename
  }
  else {
    $q = "xquery ". $q; # $q is a string
  }

  # See /etc/perl/BaseX.pm 
  
  my $session = BaseX->new("localhost", 8888, "staffweb", "founders10");
  if ($session =~ m/^ERROR/) {
    # check outage message 
    my $outage = 'The BaseX XML database is unavailable. Please try later.';
    # grab a custom informative outage message from this file
    if ( open (M,"$BASEX_PATH/OUTAGE")  ) { $outage = ''; while (<M>) { $outage .= $_; } close(M) };
    $r->print("<weberror>$outage</weberror>\n");
    return ($n,$s);
  }
  $session->execute("open fasdb"); 
  if($session->execute($q)) {
    $s = $session->result();
    #if($session->execute("xquery count(". $q . ")")) {
    #   $n = $session->result();
    #}
    # count occurances of xml id  ############################ need to make this more robust
    $n++ while $s =~ /xml:id=/g;

  } else {
    $s = $session->info();
  }
  $session->close();

  my $f = "";
  $q =~ s/\>/\&gt;/g;
  $q =~ s/\</\&lt;/g;
  if ( $noprint ) {
    # return findings to the caller
    return ($n,$s,"<query><found>$n</found><from>$fastype</from><xpath>$userinfo</xpath></query>\n");
  }
  else {
    # we are done, print it
    $r->print("<query><found>$n</found><from>$fastype</from><xpath>$userinfo</xpath></query>\n");
    $r->print("<result>".$s."</result>");
    return ($n);
  }
}

sub NYI {
  my $r = shift;
  #### we always put out application/xml see above
  ####$r->content_type('application/xml'); 
  #### <?xml version="1.0" encoding="UTF-8"?>
  my $s = <<notYETimplemented_ABC;
<fasQuery>
<fasMessage>Sorry, but downloading selections as flat text files for local analysis is not yet implemented.</fasMessage>
notYETimplemented_ABC
  $r->print($s);
  &printFooter($r,'</fasQuery>');
}

sub escape {
  my($str) = splice(@_);
  $str =~ s/(\W)/sprintf('%%%02X', ord($1))/eg;
  return $str;
}

sub unescape {
  my($str) = splice(@_);
  $str =~ s/%(..)/chr(hex($1))/eg;
  return $str;
}

sub escapeAmp {
  my($str) = splice(@_);
  $str =~ s/\&amp;/##KEEPAMP##/eg;
  $str =~ s/\&/\&amp;/eg;
  $str =~ s/##KEEPAMP##/##amp;##/eg;
  return $str;
}

sub fasQueryValidParameters {
  my $r = shift;
  my $debugQuery = '';
  $debugQuery = "PWD=[".$ENV{PWD}."] ";

  # Note. parameters named "src" are multiple rectypes specified by user to be displayed
  #       Store this as another hash in the %P parameters hash i.e. $$P{src}{value} = 1 where valeu is a rectype
  #
  my $P = shift; # passed a reference to a hash
  if ( $r->method eq 'POST' ) {
     my $cl = $r->headers_in->{'content-length'};
     my $args; $r->read($args, $cl);

     my $escapedArgs = unescape($args);
     my $showIt = $escapedArgs; $showIt =~ s/&/&amp;/g;
     $debugQuery .= " ########escapedArgs[$showIt]\n";

     # escape entities
     ##### on way out?: $args =~ s/&amp;/&/g; #$args =~ s/&quot;/"/g; #$args =~ s/&gt;/>/g; #$args =~ s/&lt;/</g;
     ###########foreach ( split(/\&/,$args) ) {

     # if args matches an xml doc/start with angle bracket, grab it, otherwise treat & as varaiable split
     if ( $args =~ m~^\<~ ) {
     #####if ( $args =~ m~^<Data>.+</Data>$~ ) {
        $$P{posted_xmldoc} = $args;
     }
     else {

       foreach ( split(/\&/,$escapedArgs) ) {

         # char conversions here 

####################### + to ' ' so how to have a + in a pattern??????????????????/
         
         s/\+/ /g; s/\%26/&amp;/g; s/\%3E/&gt;/g; s/\%3C/&lt;/g; s/\%3F/?/g;
         #s/^[a-zA-Z0-9 \&;\.\-\_\{\}:]+//g; # kill bad chars

         if ( m/^([^=]+)= *(.*) *$/ ) {
           my $paramName = $1; my $paramValue = $2;
           # kill leading/trailing spaces
           $paramValue =~ s/^ +//;
           $paramValue =~ s/ +$//;
# this doesn't look right but seems to work. force yes on some if NO value?????
           if ($paramValue) {
             ####if ( $SOURCES =~ m/,$paramName,/ ) { $paramValue = "yes"; }
             if ( $paramName eq "src" ) {
               $$P{$paramName}{$paramValue} = 1;
               $debugQuery .= " before:src{$paramValue}=1";
             }
             else {
               $$P{$paramName} = $paramValue;
               $debugQuery .= " before:$paramName=[".$$P{$paramName}."]";
             }
           }
         }
         else {
             $$P{unnamedParam} = $_;
         }
       }

     }
     # always force out the source args, and 'debug' if not present
     ####foreach ( split(/,/,$SOURCES) ) {
     ####   next unless ($_);
     ####   next if $$P{$_};
     ####   $$P{$_} = "no";
     ####}
     $debugQuery .= "args end\n";
  }
  elsif ( $r->method eq 'PUT' ) {
     my $cl = $r->headers_in->{'content-length'};
     my $args; $r->read($args, $cl);
     my $escapedArgs = unescape($args);
     my $showIt = $escapedArgs; $showIt =~ s/&/&amp;/g;
     $$P{putdata} = $args;
     $$P{putdata_escaped} = $escapedArgs;
     $$P{putdata_show} = $showIt;
     $debugQuery .= "PUTargs end\n";
     return ( $debugQuery, $args );
  }
  else {   $debugQuery .= " GET\n";  }
  ################################### $$P{debug} = "no" unless ($$P{debug});
  my $xml = '<parm>';
  # process again, and validate as required
  foreach ( keys %$P ) {
    next unless $_;
    if ( $$P{$_} && $_ eq 'recid' ) {
       $$P{$_} = &normalise_id($$P{$_});
       # allow for A, B, C etc at end to distinguish later insertions, or multiple items derived from a rec
       if ( $$P{$_} =~ m/^([a-zA-Z][a-zA-Z0-9]*[a-zA-Z])(\d+)[a-z]?$/ ) {
            $xml .= &parm2xml($_,$$P{$_}); 
       }
       else {
            $xml .= &parm2xml($_,$$P{$_},"is not a record type followed by a number");
       }
    }
    elsif ( $$P{$_} && $_ eq 'surname' ) {
       # validate surname -- must start with at least 2 alpha chars, allow patterns
       if ( $$P{$_} =~ m/^[A-Z]{2,}[a-zA-Z \.\+\-\_0-9\*{}\$]*$/i ) {
            $xml .= &parm2xml($_,$$P{$_}); 
       }
       else {
            $xml .= &parm2xml($_,$$P{$_},"must start with at least 2 letters");
       }
    }
    elsif ( $$P{$_} && $_ eq 'forename' ) {
       # validate forname -- must start with at least 1 alpha chars, allow patterns, AND surname present
       if ( $$P{$_} =~ m/^[A-Z]{1,}[a-zA-Z \.\+\-\_0-9\*{}]*$/i ) {
            if ( length($$P{'surname'}) >= 2 ) {
              $xml .= &parm2xml($_,$$P{$_}); 
            }
            elsif ( $$P{'b4aLink'} || $$P{'ship'} || $$P{'arrYr2'} ) {
              # allow surname with ship or year
              $xml .= &parm2xml($_,$$P{$_}); 
            }
            else {
              $xml .= &parm2xml($_,$$P{$_},"cannot search on forename alone -- please enter a surname/year/ship to filter hits on forename."); 
            }
       }
       else {
            $xml .= &parm2xml($_,$$P{$_},"must start with at least 1 letter");
       }
    }
    elsif ( $$P{$_} && $_ eq 'policeNum' ) {
       # validate police number
       if ( $$P{$_} =~ m/^(\d+[A-Z])/i ) {
            $$P{$_} = $1;
            $xml .= &parm2xml($_,$$P{$_}); 
       }
       else {
            $xml .= &parm2xml($_,$$P{$_},"is not a number followed by a letter");
       }
    }
    elsif ( $$P{$_} && $_ eq 'b4aLink' ) {
       # validate bateson ref
       if ( $$P{$_} =~ m/^(\d\d\d\.\d\d)$/i ) {
            $xml .= &parm2xml($_,$$P{$_}); 
       }
       else {
            $xml .= &parm2xml($_,$$P{$_},"BatesonId must be 3 digits (page no in 4th ed.), a fullstop, and 2 digits e.g. 378.01");
       }
    }
    elsif ( $$P{$_} && $_ eq 'ship' ) {
       # like surname, at least 2 chars
       if ( $$P{$_} =~ m/^[A-Z]{2,}[a-zA-Z \.\+\-\_0-9\*{}]*$/i ) {
            $xml .= &parm2xml($_,$$P{$_}); 
       }
       else {
            $xml .= &parm2xml($_,$$P{$_},"must start with at least 2 letters");
       }
    }
    elsif ( $$P{$_} && ($_ eq 'arrYr' || $_ eq 'arrYr2') ) {
        if ( $$P{$_} =~ m/^[<>]?(\d\d\d\d)([ba])?$/ ) { 
           if ( ($1 gt "1788") && ($1 le "1899") ) {
              $xml .= &parm2xml($_,$$P{$_}); 
              if ($2) { $xml .= &parm2xml('ba',$2); }
           }
           else {
              $xml .= &parm2xml($_,$$P{$_},"Not in range 1788 to 1899");
           }
        }
        else { $xml .= &parm2xml($_,$$P{$_},"Bad year"); }
    }
    elsif ( $$P{$_} && ($_ eq 'shiplinked') ) {
        # cannot stand alone -- must have ship, year OR a surname
        if (  ( $$P{'rectask'} eq 'match' || $$P{'rectask'} eq 'ref' || $$P{'rectask'} eq 'link' ) 
           || ( length($$P{'surname'}) >= 2 ) || ( length($$P{'ship'}) >= 2 ) || ( length($$P{'surname'}) == 4 ) ) {
           $xml .= &parm2xml($_,$$P{$_}); 
        }
        else {
           $xml .= &parm2xml($_,$$P{$_},"cannot search on UNLINKED alone -- please enter a shipname, a year and/or a surname as well."); 
        }
    }
    elsif ( $$P{$_} && $_ eq 'sex' ) {
       # validate ALL parms against injection attacks
       if ( $$P{$_} eq "M" || $$P{$_} eq "F" ) {
         $xml .= &parm2xml($_,$$P{$_},'');
       }
       else {
         $xml .= &parm2xml($_,$$P{$_},'must be "M" or "F"');
       }
    }
    else {
       $xml .= &parm2xml($_,$$P{$_},'');
    }
  }
  $xml .= '</parm>';
  return ($debugQuery,$xml);
}

sub parm2xml {
  my $e = shift;
  my $v = shift;
  my $err = shift;
  if ($e eq "src") {
    my $s = '';
    foreach ( keys %$v ) { $s .= "<$e>$_</$e>\n"; }
    return $s;
  }
  else {
    if ($err) { $G{ERR}++; return "<$e>$v<parmError>$err</parmError></$e>\n"; }
    else      { return "<$e>$v</$e>\n"; }
  }
}

sub loadSourceDescriptions {
  my $s = ''; my $state = 'start';
  open (F,"/srv/fasrepo/common-bin/xquery/fas-web-1.0.xq");
  while (<F>) { 
    if ($state eq 'start' && m/.+\<fas\>/) {
       $s = '<srcDesc>'; $state = 'in';
    }
    elsif ($state eq 'in' && m/^\<\/fas\>/) {
       $s .= '</srcDesc>'; $state = 'done';
    }
    elsif ($state eq 'in') { $s .= $_; }
  } 
  close(F);
  $s =~ s|.+\<fas\>|\<fas\>|m;
  $s =~ s|\<\/fas\>.+|\<\/fas\>|m;
  return $s;
}

sub normalise_id {
   my $id = shift;
   if ($id =~ m/ai(\d+)([A-Z]?)/i) {
      return sprintf "ai%05d%s",$1,$2;
   }
   else {
      return $id;
   }
}

# default is xml
sub print_mimetype {
  my $r = shift;
  my $type = shift;
  if ( $type eq 'html' ) {
    $r->content_type('text/html');
  }
  else {
    $r->content_type('application/xml');
    $r->print('<?xml version="1.0" encoding="UTF-8"?>') unless ($type eq 'omit_xml_dec');
  }
}

sub getPostArgs {
  my $r = shift;
  my ($escapedArgs,$showArgs,$cl,$args) = '';
  
  if ( $r->method eq 'POST' ) {
     $cl = $r->headers_in->{'content-length'};
     $args; $r->read($args, $cl);

     $escapedArgs = unescape($args);
     $showArgs = $escapedArgs; 
     $showArgs =~ s/&/&amp;/g;
  }
  return ($escapedArgs,$showArgs."..cl=[$cl] args[$args]")
}

#################################### generated content
sub fas_rectype_relatedInfo {
  my $object_id = shift;

  # this one is scope prot.staff
  if ( $ENV{HTTP_REFERER} =~ m~\/prot\/~ ) {

  my $s = <<fas_rectype_relatedInfo_TEXT;
  <!-- start GENERATED fas_rectype_relatedInfo [$object_id] 
       HTTP_REFERER was authenticated: $ENV{HTTP_REFERER}
  -->
  <relatedInfo scope="prot.staff" type="publication" >
    <identifier type="uri">http://founders-and-survivors.org/prot/fasrepo/current/$object_id/</identifier>
    <title>FAS ingest workflow standard outputs for rectype:$object_id</title>
    <notes>Logs, XML datasets, and codebook arising from ingest workflow for rectype:$object_id.
    </notes>
  </relatedInfo>
  <relatedInfo scope="prot.staff" type="publication" >
    <identifier type="uri">http://founders-and-survivors.org/prot/fasrepo/current/$object_id/recodes/</identifier>
    <title>FAS ingest codebook FAS rectype:${object_id}</title>
    <notes>Recodes and corrections and all data values from ingest of FAS rectype:${object_id}.</notes>
  </relatedInfo>
  <!-- end   GENERATED fas_rectype_relatedInfo [$object_id] -->
fas_rectype_relatedInfo_TEXT
  return $s;

  }
  else {
    return '';
  }
}

# In the master file this provides for auto-generated collections e.g. <entity type="shipIndex">
# as opposed to manually edited ones living as files in $WEBWORK/edited
sub generate_entity {
  my $type = shift;
  my $parameters = shift;
  my $s = '';
  if ($type eq 'shipIndex_GENERATEDCOLLECTION') {
      #
      # Generated collections. We deliver useful public content as a tei/html file ????? (tei for now)
      # and the rifcs has itself been generated from this. 
      # The RIFCS files live in RIFCSDIR as specified in parameters contained in the masterfile/entity element.
      # These files are NOT edited in the manual rifcs editing system but program generated.
      #
      
      my $webUri = '';
      my $tpl_label = "FAS Convict Ship##SHIPorS## Prosopography Index";

      # TEIDIR is required, contains shipid directories

      if ( $parameters =~ s~WEBURI=(\S+)$~~ ) {
           $webUri = $1;
      }

      if ( $parameters =~ s~TEIDIR=(\S+)~~ && -d "$1" ) {
         my $teidir = $1; # this is the file system

         # RifCS is required, contains generated RifCS descriptive stubs and a template ????

         if ( $parameters =~ s~RIFCSDIR=(\S+)~~ && -d "$1" ) {
              my $rifcsDir = $1;
              
              # generate the collection entry for each found ship in the rifcs masterfile index
              my $label = $tpl_label; 
              $label =~ s/##SHIPorS##/s/;

              # An index to the collection

              $s = '<item type="catalogueOrIndex" generated="shipIndex" localid="c-GEN-shipIndex-idx" '.
                   'ands_deployment="true" '.
                   'label="'.$label.'" '.
                   'url="'.$webUri.'/index.xml" '.
                   'rifcsDir="'.$rifcsDir.'" ';

              # is the tei dir deployed? If so, allow link to it as its metadata is a superset of the RifCS.
              if ( -d "$teidir" ) {
                 $s .= 'teiurl="'.$webUri.'/tei/"';
              }
              $s .= '>'."\n";

              # Read bateson reference

              foreach my $n ( $SHIPSDOC_XC->findnodes('//b4a[toColony="VDL" or toColony="NI" or toColony="PP"]') ) { 
              
                  my $shipid = $n->findvalue('@n');
                  my $toColony = $n->findvalue('toColony');
                  my $shipNameNorm = $n->findvalue('shipNameNorm');
                  my $arrYr = substr ( $n->findvalue('arrivalDate') , 0, 4 );
                  my $test = $shipid . ' ' . $shipNameNorm . ' arr '. $arrYr . ' at ' . $toColony;
                  $label = $tpl_label;
                  $label =~ s/##SHIPorS##/ $test/;
                  $s .= '<item type="dataset" generated="shipIndex" localid="c-GEN-shipIndex-'.$shipid.'" '.
                         'ands_deployment="true" '.
                         "label=\"$label\" ";

                  # is the tei file deployed? If so, allow link to it as its metadata is a superset of the RifCS.
                  if ( -d "$teidir/$shipid" ) {
                     $s .= 'teiurl="'.$webUri.'/tei/'.$shipid.'/index.xml" ' if ( -f "$teidir/$shipid/index.xml" );
                     $s .= 'htmurl="'.$webUri.'/tei/'.$shipid.'/index.htm" ' if ( -f "$teidir/$shipid/index.htm" );
                  }

                  $s .= '/>'."\n";

              }


              # Read the actual TEI collection - see what's been generated so far

              #my %foundTei = ();
              #opendir(DIR,$teidir);
              #while (my $file = readdir(DIR)) {
              #    next if ($file =~ m/^\./);
              #    if ( -d "$teidir/$file" ) {
              #         $foundTei{$file} = 1;
              #         # http://dev.founders-and-survivors.org/pub/collections/html/FAS:c-pop1-m-pre1840
              #    }
              #}
              #closedir(DIR);

              $s .= '</item>'."\n"; 
         }
         else {
              $s = <<__shipIndexBadRif__;
<item type="catalogueOrIndex" localid="c-gen_shipIndex_ERROR_RIFCSDIR-NOT-FOUND-parameters-$parameters" />
__shipIndexBadRif__
         }
      }
      else {
           $s = <<__shipIndexBad__;
<item type="catalogueOrIndex" localid="c-gen-shipIndex_ERROR-TEIDIR-NOT-FOUND-parameters-${parameters}_1[$1]" />
__shipIndexBad__
      }
  }
  else {
      $s = <<__unknownTYPE__;
      <item type="catalogueOrIndex" localid="c-entity-UNKNOWN-$type"/>
__unknownTYPE__
  }
  return $s;
}

1;

