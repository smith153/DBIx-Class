BEGIN { do "./t/lib/ANFANG.pm" or die( $@ || $! ) }

use strict;
use warnings;

use Test::More;
use Test::Deep;
use Test::Warn;
use Test::Exception;
use Data::Dumper;

use DBICTest;

delete $ENV{DBIC_COLUMNS_INCLUDE_FILTER_RELS};

my $schema = DBICTest->init_schema( no_populate => 1 );

my $g1 = $schema->resultset('Genre')->create( { name => 'hard' } );
my $g2 = $schema->resultset('Genre')->create( { name => 'mid' } );
my $g3 = $schema->resultset('Genre')->create( { name => 'soft' } );

$schema->resultset('Artist')->create(
  {
    name => 'Group Test',
    cds  => [
      {
        title => 'Title 1',
        year  => 2000,
        genre => $g1,

        single_track => {
          position => 1,
          title    => 'Title 1 - Track 1',
          cd       => 1,
        },
      },
      {
        title        => 'Title 2',
        year         => 2000,
        genre        => $g1,
        single_track => {
          position => 1,
          title    => 'Title 2 - Track 1',
          cd       => 2,
        },
      },
      {
        title        => 'Title 3',
        year         => 2001,
        genre        => $g2,
        single_track => {
          position => 1,
          title    => 'Title 3 - Track 1',
          cd       => 3,
        },
      },
      {
        title        => 'Title 4',
        year         => 2005,
        genre        => $g3,
        single_track => {
          position => 1,
          title    => 'Title 4 - Track 1',
          cd       => 4,
        },
      },
      {
        title        => 'Title 5',
        year         => 2006,
        genre        => $g3,
        single_track => {
          position => 1,
          title    => 'Title 5 - Track 1',
          cd       => 5,
        },
      }

    ]
  }
);

#somewhat contrived, but should be a proper one-to-many rset joined to a
#few belongs_to rels and aggregated on a 2nd level belongs_to.
my $rs = $schema->resultset('Artist')->search(
  {},
  {
    join     => { cds => [ 'genre', { single_track => 'disc' } ] },
    collapse => 1,
    columns  => [
      { artistid                     => 'me.artistid' },
      { name                         => 'me.name' },
      { 'cds.cdid'                   => 'cds.genreid' },
      { 'cds.genre.name'             => 'genre.name' },
      { 'cds.single_track.disc.cdid' => 'disc.year' },
      { 'cds.single_track.disc.year' => 'disc.year' },
      { 'cds.rcount'                 => { count => 'disc.year' } }
    ],
    group_by => [ 'me.artistid', 'me.name', 'cds.genreid', 'genre.name', 'disc.year', ],
    order_by => [ { -asc => 'me.name' }, { -asc => 'disc.year' } ],
  }
);

my $hri_rs = $rs->search( {}, { result_class => 'DBIx::Class::ResultClass::HashRefInflator' } );

my $collapsed = $hri_rs->next();

#warn Dumper $collapsed;

#our 5 tracks should be collapsed down to just 4 by cds.genreid and disc.year
cmp_ok( scalar @{ $collapsed->{cds} }, '==', 4, 'Should have 4 results here' );

done_testing;
