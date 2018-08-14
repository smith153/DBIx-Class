use strict;
use warnings;

use Test::More;
use Test::Deep;
use Test::Warn;
use Test::Exception;
use lib qw(t/lib);
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
      { artistid         => 'me.artistid' },
      { name             => 'me.name' },
      { 'cds.cdid'       => 'cds.genreid' },    #fake id since we can't collapse without a pkey (it seems?)
      { 'cds.genre.name' => 'genre.name' },

#     { 'cds.single_track.trackid' => 'disc.year' },   #sometimes collapsing works without this, see http://paste.debian.net/1037947/
      { 'cds.single_track.disc.cdid' => 'disc.year' },                 #and another fake id
      { 'cds.single_track.disc.year' => 'disc.year' },
      { 'cds.rcount'                 => { count => 'disc.year' } },    #number of rows collapsed
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
cmp_deeply(
  $collapsed,

  {
    'artistid' => 1,
    'name'     => 'Group Test',
    'cds'      => [
      {
        'genre' => {
          'name' => 'hard'
        },
        'single_track' => {
          'disc' => {
            'cdid' => '2000',
            'year' => '2000'
          }
        },
        'rcount' => 2,
        'cdid'   => 1
      },
      {
        'genre' => {
          'name' => 'mid'
        },
        'cdid'         => 2,
        'rcount'       => 1,
        'single_track' => {
          'disc' => {
            'cdid' => '2001',
            'year' => '2001'
          }
        }
      },
      {
        'cdid'         => 3,
        'single_track' => {
          'disc' => {
            'year' => '2005',
            'cdid' => '2005'
          }
        },
        'rcount' => 1,
        'genre'  => {
          'name' => 'soft'
        }
      },
      {
        'cdid'         => 3,
        'single_track' => {
          'disc' => {
            'year' => '2006',
            'cdid' => '2006'
          }
        },
        'rcount' => 1,
        'genre'  => {
          'name' => 'soft'
        }
      }
    ],
  }
);

done_testing;

__END__

#enabled dbic tracing, populated db with exact insert statements and then
#executed the generated query from above which produces the correct 4 rows:

user@t61: sqlite test.dat

SQLite version 3.16.2 2017-01-06 16:32:41
sqlite> SELECT me.artistid, me.name, cds.genreid, genre.name, disc.year, disc.year, COUNT( disc.year ) 
   ...>   FROM artist me 
   ...>   LEFT JOIN cd cds 
   ...>     ON cds.artist = me.artistid 
   ...>   LEFT JOIN genre genre 
   ...>     ON genre.genreid = cds.genreid 
   ...>   LEFT JOIN track single_track 
   ...>     ON single_track.trackid = cds.single_track 
   ...>   LEFT JOIN cd disc 
   ...>     ON disc.cdid = single_track.cd 
   ...> GROUP BY me.artistid, me.name, cds.genreid, genre.name, disc.year 
   ...> ORDER BY me.name ASC, disc.year ASC;

1|Group Test|1|hard|2000|2000|2
1|Group Test|2|mid|2001|2001|1
1|Group Test|3|soft|2005|2005|1
1|Group Test|3|soft|2006|2006|1

sqlite> .q
user@t61:

