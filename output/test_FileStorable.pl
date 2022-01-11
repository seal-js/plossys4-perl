use strict;
use warnings;

use Carp;
use Data::Dumper;
use FindBin qw($Bin);
use lib "$Bin/../lib";  # get absolute path o subdirectory 'lib' 

use FileStorable;

my %user_1 = ( name => 'Juergen', age => 55);
my %user_2 = ( name => 'Tini'   , age => 53);

my %task_1 = ( todo => 'Clean kitchen', completed => 1);
my %task_2 = ( todo => 'Do homework'  , completed => 0);

#-----------------------------------------------------------------------
# Define a model how to handle data to store.
#-----------------------------------------------------------------------
my $model_1 = sub {
    my ($stored_data, $data) = @_;

    if (ref($data) ne 'HASH') {
        confess 'Missing parameter. Pass header hash reference as argument!';
    }

    if ( ! $stored_data ) {
        $stored_data = [ { 'user' => $data } ];
    }
    elsif ( ref ($stored_data) eq 'ARRAY' ) {
        push @$stored_data, { 'user' => $data };
    }
  
    return $stored_data;
};

#---
my $model_2 = sub {
    my ($stored_data, $data) = @_;

    if (ref($data) ne 'ARRAY') {
        confess 'Missing parameter. Pass array reference as argument!';
    }

    if ( ! $stored_data ) {
        $stored_data = [ $data ];
    }
    elsif ( ref ($stored_data) eq 'ARRAY' ) {
        push @$stored_data, $data ;
    }
 
    return $stored_data;
};

#-----------------------------------------------------------------------
# Test add_hash()
#-----------------------------------------------------------------------
my $db_file_model_0 = 'FileStorable_model_0.db';
my $s = FileStorable->new(database_file => $db_file_model_0);
$s->add_hash( { user => \%user_1, task => \%task_1 } );
$s->add_hash( { user => \%user_2, task => \%task_2 } );

my $from_file = $s->read_database();

print 'Result array: ' . Data::Dumper->Dump([$from_file], [qw(*from_file)]);


#-----------------------------------------------------------------------
# Test model_1
#-----------------------------------------------------------------------
my $db_file_model_1 = 'FileStorable_model_1.db';
$s = FileStorable->new(database_file => $db_file_model_1, model => $model_1);
$s->add_model(\%user_1);
$s->add_model(\%user_2);

$from_file = $s->read_database();

print 'Result array: ' . Data::Dumper->Dump([$from_file], [qw(*from_file)]);
print '-' x 80 . "\n";

#-----------------------------------------------------------------------
# Test model_2
#-----------------------------------------------------------------------
my $db_file_model_2 = 'FileStorable_model_2.db';
$s = FileStorable->new(database_file => $db_file_model_2, model => $model_2);
$s->add_model([\%user_1, \%task_1]);
$s->add_model([\%user_2, \%task_2]);

$from_file = $s->read_database();

print 'Result array: ' . Data::Dumper->Dump([$from_file], [qw(*from_file)]);


#-----------------------------------------------------------------------
# Test add()
#-----------------------------------------------------------------------
my $db_file_model_3 = 'FileStorable_model_3.db';
$s = FileStorable->new(database_file => $db_file_model_3);
$s->add('1. Das ist die erste Zeile');
$s->add('2. Das ist die zweite Zeile');

$from_file = $s->read_database();
print 'Result array: ' . Data::Dumper->Dump([$from_file], [qw(*from_file)]);
$s->add('3. Das ist die zweite Zeile');

$from_file = $s->read_database();
print 'Result array: ' . Data::Dumper->Dump([$from_file], [qw(*from_file)]);

1;