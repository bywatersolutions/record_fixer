#!/usr/bin/perl
#---------------------------------
# Copyright 2010 - 2016
# ByWater Solutions
#
#---------------------------------
#
#  Scans for corrupted MARCXML.
#  Creates new MARC record from binary
#  MARC (more forgiving).
#  Removes fields without subfields.
#  Saved updated biblio
#
# -D Ruth Bavousett
#
# Updated by Barton Chittenden
#            2016-04-26
#---------------------------------

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use MARC::Record;
use MARC::Field;
use C4::Context;
use C4::Biblio;
use File::Spec;

use YAML;

my $record_status_file = File::Spec->join( '/tmp', 'hch.record_fixer.yaml' );

my $record_status;

if( -f $record_status_file ) {
    $record_status = YAML::LoadFile( $record_status_file );
} else {
    $record_status = {
          ok  => {}
        , edited => {}
        , bad => {}
    };
}

$|=1;
my $debug=0;
my $recnum = "";
my $count;

GetOptions(
    'debug'    => \$debug,
    'rec=s'    => \$recnum,
    'count=i'  => \$count
);

my @bad_encodings = qw( \xC3 \x8D \xB1 \xA9 );

my $ok=0;
my $edited=0;
my $i=0;
my $dbh=C4::Context->dbh();
my $whereclause = $recnum ? "where biblionumber = recnum" : '';
my $sth=$dbh->prepare("SELECT biblionumber FROM biblioitems $whereclause");
$sth->execute();
my $sth2=$dbh->prepare("SELECT biblioitems.biblionumber AS biblionumber,marc,marcxml,frameworkcode from biblioitems INNER JOIN biblio ON (biblio.biblionumber=biblioitems.biblionumber) where biblioitems.biblionumber=?");

BIB: while (my $rec=$sth->fetchrow_hashref()){
    last if ( defined( $count ) && $i > $count );
    $debug and last if ($edited>0);
    next BIB if(    $record_status->{ok}->{$rec->{'biblionumber'}} 
                 || $record_status->{edited}->{$rec->{'biblionumber'}} 
               );
    $i++;
    print ".";
    print "\r$i" unless ($i % 100);
    $sth2->execute($rec->{'biblionumber'});
    my $cur_rec = $sth2->fetchrow_hashref();
    eval { MARC::Record::new_from_xml( $cur_rec->{'marcxml'}, "utf8", C4::Context->preference('marcflavour') ) };
    if ($@) {
        my $newrec = $cur_rec->{'marc'};
        for my $bad_encoding ( @bad_encodings ) {
            $newrec =~ s/$bad_encoding/ /g
        }
        my $thisrec = eval { MARC::Record::new_from_usmarc( $newrec) }; 
        if ( $@ ) {
            $debug and print "\nCorrecting record $rec->{'biblionumber'}:\n";
            $debug and warn Dumper($newrec);
            $debug and warn Dumper($thisrec);
            C4::Biblio::ModBiblioMarc($thisrec,$rec->{'biblionumber'}, $rec->{'frameworkcode'});
            $edited++;
            $record_status->{edited}->{$rec->{'biblionumber'}} = 1;
        } else {
            $record_status->{bad}->{$rec->{'biblionumber'}} = 1;
        }
    } else {
        $record_status->{ok}->{$rec->{'biblionumber'}} = 1;
        $ok++;
    }
}

print "$i\n\n";
print "$i records processed.\n$ok records were ok.\n$edited records edited.\n";
END{
    YAML::DumpFile( $record_status_file, $record_status ); 
    print "Record sattus file: $record_status_file\n";
}

