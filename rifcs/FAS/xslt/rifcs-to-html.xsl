<?xml version="1.0"?>
<xsl:stylesheet version = "1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
     xmlns:r="http://ands.org.au/standards/rif-cs/registryObjects"
>
<xsl:param name="USER"></xsl:param>
<xsl:param name="DOPROTLINKS">1</xsl:param>
<xsl:param name="INST" />
<xsl:param name="PROJECT" />
<xsl:param name="OBJECT" />
<xsl:param name="LOCALKEY">INIT</xsl:param>
<xsl:param name="THISURI"></xsl:param>
<xsl:param name="URI_RELOBJ"></xsl:param>
<xsl:param name="URI_RIFCSOBJ"></xsl:param>
<xsl:output method="html" version="4.01"/> 
<xsl:strip-space elements="*"/>
<xsl:preserve-space  elements="r:description r:p"/>
<xsl:variable name="nObjects"><xsl:value-of select="count(//r:registryObject)"/></xsl:variable>

<!--   ................................................ Root document, to html -->
<xsl:template match="/" >
<html>
<head>
  <title><xsl:value-of select="$LOCALKEY"/> as html</title>
  <link rel="stylesheet" type="text/css" href="/pub/xsl/rifcs.css" />
</head>
<body>
  <xsl:apply-templates />
  <xsl:call-template name="footer" />
</body>
</html>
</xsl:template>

<!--
################################################################
####     Handle the master file index here (no namespace)   ####
################################################################
     xmlns:m="http://foundersandsurvivors.org/NS/rifcsMasterfile"
-->

<xsl:template match="div">

<xsl:choose>
  <xsl:when test="@type='index'">
  <h2><xsl:value-of select="head"/></h2>
  <pre><xsl:value-of select="../collection_status"/></pre>
  <xsl:apply-templates />
  </xsl:when>

  <xsl:otherwise test="@type != 'index'">
    <h3><xsl:value-of select="head"/></h3>
    <xsl:apply-templates />
  </xsl:otherwise>
</xsl:choose>

</xsl:template>

<xsl:template match="list">
<xsl:if test="head"><p><b><xsl:value-of select="head/text()"/></b></p></xsl:if>
<ul>
<xsl:apply-templates />
</ul>
</xsl:template>

<xsl:template match="item">
<xsl:variable name='lid'><xsl:value-of select="@localid"/></xsl:variable>
<li><a name="{$lid}"/>
  <xsl:choose>
     <xsl:when test="@generated='shipIndex'"><b><xsl:value-of select="concat(@type,' formats: ')" />
            <xsl:call-template name="makeLink">
            <xsl:with-param name="link"><xsl:value-of select="@htmurl"/></xsl:with-param>
            <xsl:with-param name="anchor">html</xsl:with-param>
            </xsl:call-template>
        <xsl:if test="@teiurl">
        |
            <xsl:call-template name="makeLink">
            <xsl:with-param name="link"><xsl:value-of select="@teiurl"/></xsl:with-param>
            <xsl:with-param name="anchor">tei</xsl:with-param>
            </xsl:call-template>
        </xsl:if>
        </b>
     </xsl:when>
     <xsl:otherwise>
        <xsl:value-of select="concat('(',@type,') ')"/>
     </xsl:otherwise>
  </xsl:choose>
  rifcs: <xsl:call-template name="linkToObject"><xsl:with-param name="lid" select="$lid"/></xsl:call-template>
<xsl:apply-templates /></li>
</xsl:template>

<xsl:template name="linkToObject">
<xsl:param name="lid"></xsl:param>
<xsl:choose>

<!-- ######################## Generated shipIndex content START ##################### -->
<xsl:when test="@generated='shipIndex'">
  <xsl:call-template name="makeLink">
  <xsl:with-param name="link"><xsl:value-of select="concat($URI_RELOBJ,':',$lid)"/></xsl:with-param>
  <xsl:with-param name="anchor"><xsl:value-of select="@label"/> </xsl:with-param>
  </xsl:call-template>
</xsl:when>
<!-- ######################## Generated shipIndex content END   ##################### -->

<xsl:when test="@generated">
-- nyi GEN stub [<xsl:value-of select="$lid"/>] attrs[<xsl:value-of select="@*"/>]--
</xsl:when>
<xsl:when test="//objectName[@localid=$lid]">
  <xsl:variable name='objectName' select="//objectName[@localid=$lid]"/> 
  <xsl:call-template name="makeLink">
  <xsl:with-param name="link"><xsl:value-of select="concat($URI_RELOBJ,':',$lid)"/></xsl:with-param>
  <xsl:with-param name="anchor"><xsl:value-of select="$objectName"/> </xsl:with-param>
  </xsl:call-template>
</xsl:when>
<xsl:otherwise>
--stub [<xsl:value-of select="$lid"/>] --
</xsl:otherwise>
</xsl:choose>
</xsl:template>

<xsl:template match="data">
<xsl:apply-templates />
</xsl:template>

<xsl:template match="div[@type='objects']|interface|linkModels|link|institution|project|collection_status|desc|head" />

<!--
################################################################
####     Handle the actual rifcs objects below r: namespace ####
################################################################
-->
<!--   ................................................ r:registryObjects one off header info -->
<xsl:template match="r:registryObjects">
<h1><xsl:choose><xsl:when test="$nObjects = 1">Resource documentation</xsl:when><xsl:otherwise>Documentation for <xsl:value-of select="$nObjects"/> resources</xsl:otherwise></xsl:choose></h1>
<xsl:if test="$USER">
<p>Welcome "<xsl:value-of select="$USER"/>". You can access protected resources.</p>
</xsl:if>

<xsl:if test="count(//r:registryObject) > 1">
  <xsl:call-template name="tableOfContents" />
</xsl:if>
<xsl:apply-templates/>
</xsl:template>

<xsl:template match="r:registryObject">
<hr/>
<xsl:apply-templates/>
</xsl:template>

<!-- collection calls this so we have to go up to the parent -->
<xsl:template name="registryObject_metadata">

<h3>Australian National Data Service Registration of <xsl:value-of select="r:identifier[@type='local']/text()"/></h3>

<!-- table for registryObject key and source -->
<table class="keyInfoTable">
<tr> <th>Local Key</th><td><xsl:value-of select="$LOCALKEY"/></td> </tr>
<tr> <th>ANDS Key</th><td><xsl:value-of select="../r:key/text()"/></td> </tr>
<tr> <th>Authoritative source</th><td>
<xsl:call-template name="makeLink">
    <xsl:with-param name="link" select="concat(normalize-space(../r:originatingSource[@type='authoritative']/text()),'#',r:identifier[@type='local']/text())"/>
</xsl:call-template>
</td> </tr>
<tr> <th>Date accessioned</th> <td><xsl:value-of select="@dateAccessioned"/></td> </tr>
<tr> <th>Date modified</th> <td><xsl:value-of select="@dateModified"/></td> </tr>
<tr> <th>Local Key</th><td><xsl:value-of select="$LOCALKEY"/></td> </tr>
<tr> <th>Local Metadata</th><td>
<ul>
<li><xsl:call-template name="makeLink">
    <xsl:with-param name="link" select="concat($URI_RELOBJ,':',r:identifier[@type='local'])"/>
    <xsl:with-param name="anchor">As HTML</xsl:with-param>
    </xsl:call-template>
</li>
<li><xsl:call-template name="makeLink">
    <xsl:with-param name="link" select="concat($URI_RIFCSOBJ,r:identifier[@type='local'])"/>
    <xsl:with-param name="anchor">As RIF-CS XML</xsl:with-param>
    </xsl:call-template>
</li>
</ul>
</td> </tr>
</table>

</xsl:template>

<xsl:template match="r:collection|r:activity|r:party|r:service">

<h2><xsl:if test="$nObjects > 1"><xsl:number count="//r:registryObject" format="1" />. </xsl:if><xsl:value-of select="local-name()"/> (<xsl:value-of select="@type"/>) 
<br/>
<xsl:value-of select="r:name[@type='primary']/r:namePart/text()"/>
</h2>
<xsl:apply-templates/>

<table class="collectionInfoTable">
<tr> <th>Brief description</th> <td><b><xsl:value-of select="r:description[@type='brief']"/></b></td> </tr>
<tr> <th>Local Key</th><td><xsl:value-of select="$LOCALKEY"/></td> </tr>
<tr> <th>Local Identifier</th><td><xsl:value-of select="r:identifier[@type='local']"/></td> </tr>
<tr> <th>Primary name</th><td><xsl:value-of select="r:name[@type='primary']/r:namePart/text()"/></td> </tr>
<tr> <th>Class of resource</th><td><xsl:value-of select="local-name()"/></td> </tr>
<tr> <th>Type</th><td><xsl:value-of select="@type"/></td> </tr>
<xsl:if test="r:coverage">
  <tr> <th>Temporal coverage</th><td><xsl:value-of select="concat(r:coverage/r:temporal/r:dateFrom/text(),' -- ',r:coverage/r:temporal/r:dateTo/text())"/></td> </tr>
  <tr> <th>Spatial coverage</th><td><xsl:value-of select="concat(r:coverage/r:spatial/r:text/text(),'')"/></td> </tr>
</xsl:if>
<tr> <th>Full description</th> <td><pre><xsl:value-of select="r:description[@type='full']"/></pre></td> </tr>
<xsl:if test="r:description[@type='note']">
  <tr> <th>Notes</th> <td><ol>
  <xsl:for-each select="r:description[@type='note']">
  <li><xsl:value-of select="."/></li>
  </xsl:for-each>
  </ol></td> </tr>
</xsl:if>
<xsl:if test="r:subject[@type='local']">
<tr> <th>Subject keywords (local)</th><td>
<xsl:for-each select="r:subject[@type='local']">
<xsl:value-of select="./text()"/><xsl:text> / </xsl:text>
</xsl:for-each>
</td> </tr>
</xsl:if>
<xsl:call-template name="otherDescriptions"/>

<xsl:if test="local-name()='service' and r:accessPolicy">
<tr> <th>Access policy</th><td><xsl:value-of select="r:accessPolicy"/></td> </tr>
</xsl:if>

<xsl:if test="local-name()='collection' or local-name()='service'">
  <tr> <th>Access this <xsl:value-of select="local-name()"/></th><td>
  <xsl:for-each select="r:location/r:address/r:electronic[@type='url']/r:value/text()">
  <ul>
  <li>
      <xsl:call-template name="makeLink">
      <xsl:with-param name="link" select="normalize-space(.)"/>
      </xsl:call-template>
  </li>
  </ul>
  </xsl:for-each>
  </td> </tr>
</xsl:if>
</table>


<xsl:if test="r:relatedObject">
<h3>Objects related to this <xsl:value-of select="local-name()"/></h3>
<dl>
<xsl:for-each select="r:relatedObject">
<dt><p><b><xsl:value-of select="concat( ./r:relation/@type,' &quot;',./r:relation/r:description/text(),'&quot;' )"/></b>:</p></dt>
<dd>
  <xsl:if test="key !=''">
    ANDS copy of object: 
    <xsl:call-template name="makeLink">
    <xsl:with-param name="link"><xsl:value-of select="./r:key/text()"/> </xsl:with-param>
    </xsl:call-template>
    <br/>
  </xsl:if>
Local copy of object: 
  <xsl:call-template name="makeLink">
  <xsl:with-param name="link"><xsl:value-of select="concat($URI_RELOBJ,':',@local_id)"/></xsl:with-param>
  <xsl:with-param name="anchor"><xsl:value-of select="@local_id"/> </xsl:with-param>
  </xsl:call-template>

</dd>
</xsl:for-each>
</dl>
</xsl:if>


<xsl:if test="r:relatedInfo">
<h3>Related information:</h3>
<dl>
<xsl:for-each select="r:relatedInfo">
<dt><p><b><xsl:value-of select="./r:title/text()"/></b></p></dt>
<dd>
  <xsl:value-of select="./r:notes/text()"/>
<br/>
  <xsl:call-template name="makeLink">
  <xsl:with-param name="link" select="normalize-space(./r:identifier/text())"/>
  <xsl:with-param name="anchor">Access the related <xsl:value-of select="@type"/> ...</xsl:with-param>
  </xsl:call-template>
</dd>
</xsl:for-each>
</dl>
</xsl:if>

<hr/>
<xsl:call-template name="registryObject_metadata"/>

</xsl:template>

<!-- silent, dealt with in parents templates -->
<xsl:template match="r:key|r:location|r:identifier[@type='local']|r:originatingSource[@type='authoritative']|
                     r:name|r:subject|r:description|r:relatedInfo|r:coverage|r:accessPolicy" />

<xsl:template name="tableOfContents" >
<p>Index to <xsl:value-of select="count(//r:registryObject)"/> resources: </p>
<ol>
<xsl:for-each select="//r:namePart[../@type='primary']/text()" >
<li><xsl:value-of select="."/></li>
</xsl:for-each>
</ol>

</xsl:template>

<!-- Utility for making a hypertext link. anchor is optional. 
     Check for /prot/ and USER before making the link a hyperlink
-->
<xsl:template name="makeLink">
<xsl:param name="link"></xsl:param>
<xsl:param name="anchor"></xsl:param>
<xsl:choose>
<xsl:when test="starts-with($link,'http:') and ($USER or not(contains($link,'/prot/')) )">
<a><xsl:attribute name="href"><xsl:value-of select="$link"/></xsl:attribute>
   <xsl:choose>
     <xsl:when test="$anchor"><xsl:value-of select="$anchor"/></xsl:when>
     <xsl:otherwise><xsl:value-of select="$link"/></xsl:otherwise>
   </xsl:choose>
</a>
</xsl:when>
<xsl:when test="starts-with($link,'http:') and (not($USER) and contains($link,'/prot/') )" >
  <xsl:if test="$DOPROTLINKS">
<a><xsl:attribute name="href"><xsl:value-of select="$link"/></xsl:attribute>
   <xsl:choose>
     <xsl:when test="$anchor"><xsl:value-of select="$anchor"/></xsl:when>
     <xsl:otherwise><xsl:value-of select="$link"/></xsl:otherwise>
   </xsl:choose>
</a><br/>
  </xsl:if>
  <xsl:if test="not($DOPROTLINKS)">
<xsl:value-of select="$link"/><br/>
  </xsl:if>
<xsl:call-template name="requestForAccess" />
</xsl:when>
<xsl:otherwise>
  <xsl:value-of select="$link"/>
</xsl:otherwise>
</xsl:choose>
</xsl:template>

<xsl:template name="requestForAccess">
<!-- START requestForAccess (from xslt only) -->
<p>Documentation about the resource is public but access to the resource itself is restricted to project team members.</p>
<p>If you are not a member of the project team, contact the project manager directly for terms and conditions of access. The manager of this collection may provide access to this data collection by negotiation. You may be required to indicate your intended use of the data, to meet any costs associated with providing you with the data, and to fulfil any other terms and conditions as determined by the data manager. Send your request via the <a href="http://foundersandsurvivors.org/contact">contact page of the project website</a> or by email to: inquiries@foundersandsurvivors.org</p>
<!-- END requestForAccess -->
</xsl:template>

<xsl:template name="footer">
<div class="footer">
<hr/>
<p><xsl:value-of select="concat('Generated by FAS(RIF-CS) at ',$GENDATE,' for project ',$PROJECT,' at institution ',$INST,'.')"/>
<br/>
URI: <xsl:value-of select="$THISURI"/></p>
</div>

</xsl:template>

<xsl:template name="otherDescriptions">
<xsl:for-each select="r:description">
<xsl:if test="not(@type='brief' or @type='full' or @type='note')">
<tr> <th class="{@type}"><xsl:value-of select="@type"/></th> <td><xsl:value-of select="."/></td> </tr>
</xsl:if>
</xsl:for-each>
</xsl:template>

<!-- for some structured text -->
<xsl:template name="ul">
<ul><li>DUMMY ITEM</li><xsl:apply-templates /></ul>
</xsl:template>

<xsl:template name="li">
<li><p><xsl:apply-templates /></p></li>
</xsl:template>

<xsl:template name="r:b">
<b><xsl:apply-templates /></b>
</xsl:template>

</xsl:stylesheet>

