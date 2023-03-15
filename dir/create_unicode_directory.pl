#!/usr/bin/perl

use strict; use warnings;
use utf8;

use Encode qw( encode );

use sealperl::file;

my $base_dir = "Волгогра́д";
my @dir_list = ($base_dir);

if ( IsDirectory($base_dir) ) {
	print "Directory existiert!\n";
}
else {
	print "Directory existiert nicht -> erzeugen\n";
	CreateDir(@dir_list);	
}



my $dir_name_1 = "Волгогра́д/桑原 たかのり　様";
my $dir_name_2 = 'कार्तिक';
my $dir_name_3 = "桑原 たかのり　様";

@dir_list = ($dir_name_1, $dir_name_2, $dir_name_3);

CreateDir(@dir_list);

exit 0;
