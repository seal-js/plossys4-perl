use strict;
use sealperl::process;     #- make system calls 

my $ra_CommandList = $BuildPdfaProcessCommand->(\%Args);
my $StdOutLogfile = "$ENV{PLSLOG}/pdfaprocess_$$.tmp";

my ($Return, $Status, $ErrorMessage) =
     $ExecuteSystemCallWithTimeOut->($ra_CommandList,
                                     $Args{TIMEOUT}, 
                                     "pdfaprocess", 
                                     $StdOutLogfile);

#---------------------------------------------------------------------------
# Start a process syncronously.
#
#  $_[0]  : Reference to an array with process to start an all arguments
#           passed to the process.
#  $_[1]  : Timeout to abort the started process, if it doesn't return. 
#  $_[2]  : Only the name of the started process .
#  $_[3]  : Logfile. The stdout of the started process is written into logfile.
#
# Return : ($ProgStatus, $Status, $ErrorMessage) : 
#           $ProgStatus is the return value of program which was started.
#           $Status is the return value of program "systemcall.exe"                                     
#           $Status=42 : timeout occured    
#
# Example:
#                                     
#  $refCmd = ["pdfmerge", "-i", "pdf_listfile" ];
#  $Timeout = 60;
#  $Program = "pdfmerge";
#  $Logfile = "$ENV{PLSLOG}/mylogfile.log";
#
#  $Ret = &ExecuteSystemCallWithTimeOut ($refCmd, $Timeout $Program, $Logfile);
#---------------------------------------------------------------------------
my $ExecuteSystemCallWithTimeOut = sub
    {
    my ($refCommandList, $Timeout, $Program, $StdoutLogfile) = @_;
    my ($Status, $ProgStatus);

    ($Status, $ProgStatus) = &SyncCallWithTimeout($refCommandList, $Timeout, $StdoutLogfile);
    if ($Status == 3)
        {
        # Timeout has occured !!!
        return ($ProgStatus, 42, $rLang->Get("OsErrProcTimeout", $Program));
        }
    return ($ProgStatus, $Status);
    };

# ---------------------------------------------------------------------
# Build command for PDF -> PDF/A conversion.
# Param: $_[0] hash reference with arguments
#
# Return: reference to array including command
# ---------------------------------------------------------------------
my $BuildGhostScriptToPdfaCommand = sub 
    {
    my ($rh_Args) = @_;
    my $refCommandList;
    
    my $GhostScriptVersion = $GetGhostScriptVersion->();
    my $ProgGs = $rh_Args->{PROG_GS};
    if ( (!defined $GhostScriptVersion) || ($GhostScriptVersion eq "") )
        {
        my $PDFAdef_File = "$ENV{PLSTOOLS}/gs/lib/PDFA_def.ps";
        $refCommandList = ["$ProgGs", "-dNOPAUSE", "-dBATCH",
                           "-sOutputFile=$rh_Args->{PDFA_OUT_FILE}",
                           "-dUseCropBox", "-dPDFA", 
                           "-sProcessColorModel=DeviceRGB", "-sDEVICE=pdfwrite",
                           "-dUseCIEColor",  "-dPDFSETTINGS=$rh_Args->{PDFA_PROFILE}", 
                           "$PDFAdef_File", "$rh_Args->{PDF_IN_FILE}" ];
       }
    else
        {
        my $PDFAdef_File = "PDFA_def.ps";
        $refCommandList = ["$ProgGs", "-dNOPAUSE", "-dBATCH",
                           "-sOutputFile=$rh_Args->{PDFA_OUT_FILE}",
                           "-sDEVICE=pdfwrite", "-dUseCIEColor", "-dPDFA", 
                           "-dPDFSETTINGS=$rh_Args->{PDFA_PROFILE}", 
                           "$PDFAdef_File", "$rh_Args->{PDF_IN_FILE}" ];
        }
   
    my $Command = join ( ' ' , @$refCommandList);
    if ($DEBUG == ON)
        { 
        print STDERR "GhostScript command to create PDFA: $Command\n";
        }
	$SetGhostscriptCommand->($Command);
    return $refCommandList; 
    };

