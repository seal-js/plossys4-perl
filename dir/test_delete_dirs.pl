use strict;
use warnings;

# Test harness for delete_directories from dir/delete_dirs.pl.
# It validates successful deletion, handling of missing directories,
# and the parameter validation error path.

use FindBin qw($Bin);
use File::Spec;
use File::Path qw(make_path remove_tree);

BEGIN {
    # Local stub to satisfy "use seppperl::msghandler" from delete_dirs.pl in this repo.
    package seppperl::msghandler;

    sub New {
        my ( $class, undef, undef, undef, $messages ) = @_;
        return bless { messages => $messages || {} }, $class;
    }

    sub Get {
        my ( $self, $key, @args ) = @_;

        my $template = $self->{messages}{de}{$key} || $key;
        for my $i ( 1 .. scalar @args ) {
            my $value = defined $args[ $i - 1 ] ? $args[ $i - 1 ] : '';
            $template =~ s/%$i/$value/g;
        }

        return $template . "\n";
    }

    1;
}

# Mark the local stub as already loaded so delete_dirs.pl does not try to
# resolve seppperl/msghandler.pm again via @INC.
$INC{'seppperl/msghandler.pm'} = 1;

my @log_lines;

sub Log {
    my ( $message, $level ) = @_;
    $level = defined $level ? $level : 'I';
    push @log_lines, "$level $message";
    print "$level $message\n";
}

sub run_case {
    my (%args) = @_;

    my $name     = $args{name};
    my $test_sub = $args{test_sub};

    @log_lines = ();

    my ( $ok, $detail ) = ( 0, '' );
    my $eval_ok = eval {
        ( $ok, $detail ) = $test_sub->();
        1;
    };

    if ( !$eval_ok ) {
        my $err = $@ || 'unknown error';
        chomp $err;
        $ok     = 0;
        $detail = "unexpected exception: $err";
    }

    my $status = $ok ? 'PASS' : 'FAIL';
    print "$status: $name";
    print " - $detail" if defined $detail && $detail ne '';
    print "\n";

    return $ok ? 1 : 0;
}

sub _create_file {
    my ($path) = @_;

    open my $fh, '>', $path or die "cannot create file [$path]: $!";
    print {$fh} "test\n";
    close $fh or die "cannot close file [$path]: $!";
}

sub _prepare_case_dirs {
    my ($base_root) = @_;

    my $dir_one      = File::Spec->catdir( $base_root, 'case_one' );
    my $dir_one_sub  = File::Spec->catdir( $dir_one, 'sub' );
    my $dir_two      = File::Spec->catdir( $base_root, 'case_two' );
    my $dir_two_sub  = File::Spec->catdir( $dir_two, 'nested' );

    make_path( $dir_one_sub, $dir_two_sub );

    _create_file( File::Spec->catfile( $dir_one, 'a.txt' ) );
    _create_file( File::Spec->catfile( $dir_one_sub, 'b.txt' ) );
    _create_file( File::Spec->catfile( $dir_two_sub, 'c.txt' ) );

    return ( $dir_one, $dir_two );
}

sub main {
    # delete_dirs.pl is a script file, not a module, therefore it is loaded
    # explicitly via do() instead of use() / require() with package lookup.
    my $delete_dirs_script = File::Spec->catfile( $Bin, '..', 'dir', 'delete_dirs.pl' );

    my $loaded = do $delete_dirs_script;
    if ( !defined $loaded ) {
        die "Cannot load $delete_dirs_script: $@ $!";
    }

    my $test_root = File::Spec->catdir( $Bin, 'tmp_test_delete_dirs_' . $$ );
    remove_tree($test_root) if -d $test_root;
    make_path($test_root);

    my @results;

    push @results, run_case(
        name     => 'Delete existing directories',
        test_sub => sub {
            my $case_root = File::Spec->catdir( $test_root, 'success' );
            make_path($case_root);
            my ( $dir_one, $dir_two ) = _prepare_case_dirs($case_root);

            my @deleted = delete_directories( [ $dir_one, $dir_two ] );

            my $dirs_gone = ( !-d $dir_one && !-d $dir_two ) ? 1 : 0;
            my $has_deleted_entries = scalar(@deleted) > 0 ? 1 : 0;

            my $ok = $dirs_gone && $has_deleted_entries;
            my $detail = "deleted_entries=" . scalar(@deleted);
            return ( $ok, $detail );
        },
    );

    push @results, run_case(
        name     => 'Skip missing directory without crash',
        test_sub => sub {
            my $missing = File::Spec->catdir( $test_root, 'does_not_exist' );

            my @deleted = delete_directories( [$missing] );

            my $ok = ( scalar(@deleted) == 0 ) ? 1 : 0;
            my $detail = "deleted_entries=" . scalar(@deleted);
            return ( $ok, $detail );
        },
    );

    push @results, run_case(
        name     => 'Reject invalid parameter type',
        test_sub => sub {
            my $ok = eval {
                delete_directories('not-an-arrayref');
                0;
            };

            my $err = $@ || '';
            my $died_as_expected = ( !$ok && $err =~ /array reference/i ) ? 1 : 0;
            my $detail = $died_as_expected
                ? 'exception detected'
                : 'expected exception was not raised';

            return ( $died_as_expected, $detail );
        },
    );

    my $passed = scalar grep { $_ } @results;
    my $total  = scalar @results;

    print "Summary: $passed/$total tests passed\n";

    remove_tree($test_root) if -d $test_root;

    return $passed == $total ? 0 : 1;
}

exit main();
