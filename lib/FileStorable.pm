package FileStorable;

use strict;
use warnings;

use base qw(Exporter);
use Carp;
use Storable;

use vars qw( $AUTOLOAD $VERSION $DEBUG);   # Keep 'use strict' happy

#----------------------------------------------------------------
# Constructor
#----------------------------------------------------------------
sub new {
    my $class = shift;
	
    if (@_ % 2) {
	    confess 'Illegal parameter list has odd number of values';
	}
	
	my %default = (
	    database_file => undef,
		model => undef,
	);
	
	my %params = (%default, @_);
	
	if (!$params{database_file} ) {
	    confess 'Key database_file not defined.';
	}
	
	my $self = {};
    bless $self, $class;

    for my $attrib ( keys %params ) {
		$self->{$attrib} = $params{$attrib};
    }	
	
	return $self;
}

#---------------------------------------------------------------------------------
# Purpose  : Use Perl module 'Storable' to read data from file.
# Parameter: $database_file
# Return   : reference to Perl data structure
#---------------------------------------------------------------------------------
sub read_database {
    my ($self) = shift;
  
    my $data_ref;
    if ( -e $self->{database_file}) {
        $data_ref = retrieve($self->{database_file});
    }
    return $data_ref;
}

#---------------------------------------------------------------------------------
# Purpose  : Use Perl module 'Storable' to save a Perl data structure into file.
# Parameter: $job_data
#            $database_file
# Return   : 0 => ok
#          : 1 => error
# Exception: throws an exception if data cannot be stored.
#---------------------------------------------------------------------------------
sub save_database {
    my ($self) = shift;
    my ($job_data) = @_;

    my $fct = (caller(0))[3];

    # Write data structure into file
    eval {
        store $job_data, $self->{database_file};
    };
    if ($@) {
	    my $error = qq{Error save database file [$self->{database_file}]};
		confess "$fct $error";
        return 1;
    }
    return 0;
}

#------------------------------------------------------------------------------
sub add {
    my $self = shift;
    my ($data) = @_;

    my $fct  = (caller(0))[3];

    return if (!$data);
	 
    my $stored_data = $self->read_database($self->{database_file});
	
    if ( ! $stored_data ) {
        $stored_data = [ $data ];
    }
    elsif ( ref ($stored_data) eq 'ARRAY' ) {
        push @$stored_data, $data ;
    }
 	else {
        confess "$fct Stored data must be an array reference.";
    }
    $self->save_database($stored_data, $self->{database_file});
	
    return $stored_data;
}

#------------------------------------------------------------------------------
# Purpose  : Save file and header parameters for later use.
#            Append header data to data structure $job_data.
#
# Parameter: $database_file - absolute path to database file
#            $data   - reference to a data structure
# Return   : $stored_data
# Exception: Throws exception.
#------------------------------------------------------------------------------
sub add_model {
    my $self = shift;
    my ($data) = @_;

    my $fct  = (caller(0))[3];

    return if (!$data);

	if ( ref($self->{model}) ne 'CODE' ) {
	    confess 'Define a model how to save data with method add()';
	}
	
    my $stored_data = $self->read_database($self->{database_file});
    $stored_data    = $self->{model}->($stored_data, $data);
	if ( ref($stored_data) ne 'ARRAY' ) {
        confess "$fct Stored data must be an array reference.";
    }
    $self->save_database($stored_data, $self->{database_file});
	
    return $stored_data;
}

#------------------------------------------------------------------------------
sub add_hash {
    my $self = shift;
    my ($data) = @_;

    my $fct  = (caller(0))[3];

    return if (!$data);
	
    if (ref($data) ne 'HASH') {
        confess "$fct Missing parameter. Pass hash reference as argument!";
    }
	
    return $self->add($data);
}

#------------------------------------------------------------------------------
sub add_array {
    my $self = shift;
    my ($data) = @_;

    my $fct  = (caller(0))[3];

    return if (!$data);
	
    if (ref($data) ne 'ARRAY') {
        confess "$fct Missing parameter. Pass array reference as argument!";
    }
	
    return $self->add($data);
}

#----------------------------------------------------------------
# Destructor.
#----------------------------------------------------------------
sub DESTROY {
    my $self = shift;

}


1;