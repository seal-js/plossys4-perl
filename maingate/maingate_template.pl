#!/usr/local/bin/seppperl
#!/usr/local/bin/seppperl -d:ptkdb

#------------------------------------------------------------------------------
# "@(#) $Id: maingate_template.pl,v 1.2 2018/07/13 13:22:49 juergen Exp $"
#
# Pupose: The current script can be used as a basic maingate.pl template.
#
# $Log: maingate_template.pl,v $
# Revision 1.2  2018/07/13 13:22:49  juergen
# Add some new features:
# - Work with one common data structure passed to each function.
# - Throw and catch exceptions.
# - Handle undefined functions using AUTOLOAD function.
#
# Revision 1.1  2018/07/11 18:18:50  juergen
# Creation: Basic template for maingate.pl
#
#------------------------------------------------------------------------------
use Carp;
use Data::Dumper;
use File::Basename;
use File::Spec;

require "libhed.pl";  # working wiht header files
require "liblog.pl";  # logging

# Global variable used by liblog.pl
$DEBUG = 0; # 0 => debug logging off, 1 => debug logging on

# header file path is always the first parameter passed to current script.
exit main($ARGV[0]);

#-----------------------------------------------------------------------------
# Purpose  : The main function is our entry point processing a PLOSSYS job
#            member.
# Parameter: -
# Return   : 0 - it doesn't matter because it isn't evaluated by script caller.
#-----------------------------------------------------------------------------
sub main {
    my ($HeaderFile) = @_;

    # Basic initialisations. Set logfile, get member, logfile path.
    # Work with data structure. There you can set variables instead
    # of using global parameters. Pass it to your functions.
    # Alternatively you have to create a class.
    my $data_href   = init($HeaderFile);
	
    my $logfile     = $data_href->{logfile};
    my $memberfile  = $data_href->{memberfile};
	my $header_href = $data_href->{header};
    $data_href->{my_default} = 11;
	
	# Build caller string: <stript> <function>.
	# Pass it Log function.
    my $caller = $data_href->{script_name} . ' ' . (caller(0))[3];
	
    Log ("Script arguments: [@ARGV]" , 'D', $caller);
    Log ("Header file: [$HeaderFile]", 'I', $caller);
    Log ("Member file: [$memberfile]", 'I', $caller);
    Log ("Log file   : [$logfile]"   , 'I', $caller);

    # Log header data (hash structure)
    my $msg = Data::Dumper->Dump([$header_href], [qw(Header)]);
    Log("Header data: \n$msg", 'I', $caller);

	eval {
	  
		my $status = scale_pdf_file($data_href);

		# Do what you want ....
		process_member($data_href);
		
		# Calling the following undefined function is caught by AUTOLOAD function.
		# Then an exeption is thrown.
#       this_function_is_not_defined('I am a bad function call');
		
		# Call function without parameter. Function process_member throws an 
		# exception.
		process_member();
	};
	if ($@) {
	    #- Catch exceptions thrown in eval block
	    my $err_msg = $@;
		Log("Exception caught:\n$err_msg", 'E', $caller);
		set_job_error_and_save($data_href, 'ERROR: Exeption in maingate.pl');
		return 1;
	}
	
    # IMPORTANT! Save modified hash data into header file.
    HedWrite($HeaderFile, %$header_href);

    return 0;
}

#-----------------------------------------------------------------------------
# Purpose  : Basic initalisiations like logfile setting etc.
# Parameter: $HeaderFile - header file path
# Return   : hash reference - contains some common data
#-----------------------------------------------------------------------------
sub init {
    my ($HeaderFile) = @_;

    my %data;
	
    # Use job logfile (displayed in OCON)
    $data{headerfile}  = $HeaderFile;	
    $data{logfile}     = set_job_logfile($HeaderFile);
    $data{memberfile}  = get_member_file($HeaderFile);
    $data{my_default}  = 42;
    $data{script_name} = basename($0); # $0 is script path
	
	# Read header file content
    my %Hed = HedRead($HeaderFile);
    $data{header} = \%Hed;
    return \%data;
}

#-----------------------------------------------------------------------------
# Purpose  : Check data structure
# Parameter: $data - our common data structure
# Return   : 1 => ok, 0 => is not an array
#-----------------------------------------------------------------------------
sub is_valid_data {
    my ($data_href) = @_;
    return ref($data_href) ne 'HASH';
}

#-----------------------------------------------------------------------------
# Purpose  : Set logfile to log job member messages.
# Parameter: $headerfile - header file path
# Return   : logfile path
#-----------------------------------------------------------------------------
sub set_job_logfile {
    my ($headerfile) = @_;

    my $logfile = $headerfile;
    $logfile =~ s/\.h00$/\.log/;    # Replace extension
    SetLogFile($logfile);
    return $logfile;
}

#-----------------------------------------------------------------------------
# Purpose  : Get member file belonging to header file.
# Parameter: $headerfile - header file path
# Return   : member path or nothing, if file does not exist.
#-----------------------------------------------------------------------------
sub get_member_file {
    my ($headerfile) = @_;

    my $memberfile = $headerfile;
    $memberfile =~ s/\.h00$/\.m00/;    # Replace extension
    if (-e $memberfile) {
        return $memberfile;
    }
    return;
}


#-----------------------------------------------------------------------------
# Purpose  : Build your command in a nice way.
# Parameter: -
# Return   : array
#-----------------------------------------------------------------------------
sub build_pdfsetscale_command {
    my (@arg) = @_;

    my $program = File::Spec->catfile($ENV{PLSTBIN}, 'pdfsetscale');
    my @cmd = ($program, @arg);

    return @cmd;
}

#-----------------------------------------------------------------------------
# Purpose  : Scale PDF file
# Parameter: $data - our common data structure
# Return   : status of program pdfsetscale.exe
# Exception: throws exception if parameter is not a hash reference
#-----------------------------------------------------------------------------
sub scale_pdf_file {

    my ($data_href) = @_;
   
    if ( is_valid_data($data_href) ) {
        # OOPS!! Throw an exception, print a message on STDERR output channel.
	    confess 'ERROR: Missing function parameter $data_href';
    }
	
    my $caller = $data_href->{script_name} . ' ' . (caller(0))[3];	
	
	# Build your command dynamically.
	my @cmd =
	   build_pdfsetscale_command(
		   -f      => $data_href->{memberfile},
		   -format => 'auto'
	);

	# Log the array structure
	$msg = Data::Dumper->Dump([\@cmd], [qw(cmd)]);
	Log("Run command \n$msg", 'I', $caller);

	# Alternatively convert array to string
	$msg = join(' ', @cmd);
	Log("Run command [$msg]", 'I', $caller);

##	return system(@cmd);
    return 0;
}

#-----------------------------------------------------------------------------
# Purpose  : Do something
# Parameter: $data - our common data structure
# Return   : -
# Exception: throws exception if parameter is not a hash reference
#-----------------------------------------------------------------------------
sub process_member {

    my ($data_href) = @_;
   
    if ( is_valid_data($data_href) ) {
        # OOPS!! Throw an exception, print a message on STDERR output channel.
	    confess 'ERROR: Missing function parameter $data_href';
    }
	
    my $caller = $data_href->{script_name} . ' ' . (caller(0))[3];	
	Log("Now let's start the member processing ...", 'I', $caller);
	
	return;
}

#-----------------------------------------------------------------------------
# Purpose  : Set job error using header parameter to notify manager aborting
#            the current job.
# Parameter: $err_msg - error text, keep it short (max. 64 characters)
# Return   : -
#-----------------------------------------------------------------------------
sub set_job_error_and_save {
    my ($data_href, $err_msg) = @_;

    if ( is_valid_data($data_href) ) {
        # OOPS!! Throw an exception, print a message on STDERR output channel.
	    confess 'ERROR: Missing function parameter $data_href';
    }
	
	$err_msg ||= 'ERROR occurred in maingate.pl'; # Use a defualt string, if not defined

    # Job ERROR handling:
	# Because exit code of maingate script is not evaluated modify the job status.
	# OK is default and does not need to be set.
    # Use other values for $Hed{PLS_JOB_STAT} to abort the current job.
    # See SEAL documentation 'netdome_header_tec_de.pdf (page 76,77)'.
    # Here we have the mainly used header entries.
    # You can use arbitrary text. The manager aborts the job evaluating PLS_JOB_STAT.
    # In OCON your job will go in ERROR (red).
	
	my $header_href = $data_href->{header};
    $header_href->{PLS_JOB_STAT}     = 'PLS_HED_ERROR';
    $header_href->{PLS_JOB_STAT_MSG} = $err_msg;
	
#   $header_href->{PLS_JOB_STAT}     = 'PLS_MET_ERROR';
#   $header_href->{PLS_JOB_STAT_MSG} = 'PUUH.. something is wrong with metafile!';

    HedWrite($data_href->{headerfile}, %$header_href);
	return;
}

#----------------------------------------------------------------------------   
# The function AUTOLOAD is executed, if a undefined function will be called .
#----------------------------------------------------------------------------    
sub AUTOLOAD
    {
    my $fct = our $AUTOLOAD; 
    Log("AUTOLOAD $0: function $fct not defined !", 'E', 'AUTOLOAD' );
	confess "AUTOLOAD called";
    }

END { }  # Modul-Cleanup (is called before script ends)
