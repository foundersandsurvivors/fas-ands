ANDS-funded software: 'ands-excel2xml' from Founders and Survivors: README file
===============================================================================

OVERVIEW
--------

The ANDS-funded "excel2xml" software is a Perl application which will
enable any binary Excel file to be converted to a well formed XML file
with element names easily defined by the user in configuration data. 

The software can process both:
 * Excel 97 files named .xls 
 * current (as at Jan 2011) Excel files named .xlsx

It was developed as the required first step in ingesting data into the large XML database
developed by the Founders and Survivors research project.

The software consists of a Perl scripts (some external libraries are required)
and user created configuration data.

It should be usable in any Unix/Linux environment, Mac OSX (use the Terminal program),
or a Windows environment with access to Perl (e.g. cygwin's Perl, or ActiveState Perl).

USE CASE
--------

This software may be useful to any researcher, research assistant or data analyst
who creates or receives Excel datasets from others with little or no documentation,
and who wishes to use that data in a human and machine readable XML format. 

Downstream uses of the generated XML could be as input to a aggregated 
XML database load procedure (e.g. Founders and Survivors), or it may simply involve 
eyeballing or exploring the generated XML in an exploratory XML visualisation tool 
such as BaseX (See: http://basex.org/ ). 

SYSTEM REQUIREMENTS
-------------------

The software is usable in any Unix/Linux environment, Mac OSX (use the Terminal program),
or a Windows environment with access to Perl (e.g. cygwin's Perl, or ActiveState Perl).

The following perl libraries, obtainable from CPAN, are required:
 * encoding "utf8"
 * XML::LibXML

Follow the appropriate procedures for your Perl installation (e.g. CPAN) to install
up to date copies of those libraries.

INSTALLATION GUIDE
------------------

**** claudine to add some notes ****

USAGE GUIDE (rough, in progress)
-----------

Open a terminal/shell in your os.

Navigate to where your excel binary file resides.

Assign a short mnemonic "record type" for your file.

*** sms *** to add function for the system to generate config data 
by reading 1st record/excel names in existing file.
*** EXPLAIN that xml element names must be entered into the file
named "excel2xml_config.xml" in the working directoryi.

Execute the script. With no parameters, you will be given the following usage information:

..................................................
./excel2xml.pl usage:

    ./excel2xml.pl recordType inputFilename nrecs

Where
 * "type" is a RECORD_TYPE ID attribute as defined in excel2xml_config.xml = [NEW,b4a,ai,of,om,c31a,c33a,c40a,dem,def,c31s,c33s,c37s,c40s,c41s,crs,dlm,dlf,dcf,dcm,dbu,c23a,hga,di,kgd,kgb,kgm,mm,mf,hgf,rpg,ff,ers,ert,wff]

 * "inputFilename" is the name of the Excel binary file

 * "nrecs" is the number of excel rows contained in the file to be processed
..................................................

See the 'test' directory in the distribution for a complete working example 
for the 'dcf' record type and shell script showing how to run it.


