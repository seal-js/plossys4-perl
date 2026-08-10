package sealperl::constants;
use strict;
use warnings;
our $VERSION = '1.0';
## no critic qw(ProhibitNoisyQuotes ProhibitAutomaticExportation ProhibitConstantPragma)
use Exporter 'import';
use Readonly;
our @EXPORT_OK
    = qw(PCFG1 PCFG2 PCFG_SECTION CONTAINER DOCUMENT DOCSTRUCTURE %CODES $BOM $CallerSub $BACKSLASH $EMPTY @ENCODINGS);
our @EXPORT      = @EXPORT_OK;
our %EXPORT_TAGS = (
    CONSTANTS => [ "PCFG1", "PCFG2", "PCFG_SECTION", "CONTAINER", "DOCUMENT", "DOCSTRUCTURE" ],
    all       => \@EXPORT_OK
);

use constant {
    PCFG1        => "$ENV{SEAL_CUSTOMDIR}/server/sharepoint/processes.ini",
    PCFG2        => "$ENV{PLSSV}/sharepoint/processes.ini",
    PCFG_SECTION => "PROCESSCONFIG",
    CONTAINER    => "CONTAINER",
    DOCUMENT     => "DOCUMENT",
    DOCSTRUCTURE => "SHP STRUCTURE",
    LIBRARY      => "DocumentList"
};

Readonly our %CODES => (
    SUCCESS           => 0,
    ERROR_FILE        => 3,     # error in File I/O
    ERROR_MAIL        => 5,     # error in mail notification
    ERROR_CONFIG      => 9,     # error in configuration files
    ERROR_DATA        => 10,
    ERROR_UPDATE      => 15,
    ERROR_PERMISSIONS => 16,    # error in permission module
    ERROR_BROKER      => 50,
    ERROR_USEREXIT    => 80,    # error in a user exit
    ERROR_PARAMETER   => 90     # error in parameters for a sub function
);

Readonly our $CallerSub => 3;
Readonly our $BOM       => "\xef\xbb\xbf";
Readonly our $EMPTY     => qw{};
Readonly our $BACKSLASH => '\\';
Readonly our @ENCODINGS => qw/iso-8859-1 utf8/;

1;
