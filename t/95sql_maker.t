use strict;
use warnings;

use Test::More;
use SQL::Abstract::Test import => ['is_same_sql_bind'];


BEGIN {
    eval "use DBD::SQLite";
    plan $@
        ? ( skip_all => 'needs DBD::SQLite for testing' )
        : ( tests => 3 );
}

use lib qw(t/lib);

use_ok('DBICTest');

my $schema = DBICTest->init_schema();

my $sql_maker = $schema->storage->sql_maker;


SKIP: {
  skip "SQL::Abstract < 1.50 does not pass through arrayrefs", 2 if $SQL::Abstract::VERSION < 1.50;

  my ($sql, @bind) = $sql_maker->insert(
            'lottery',
            {
              'day' => '2008-11-16',
              'numbers' => [13, 21, 34, 55, 89]
            }
  );

  is_same_sql_bind(
    $sql, \@bind,
    q/INSERT INTO lottery (day, numbers) VALUES (?, ?)/,
      [ ['day' => '2008-11-16'], ['numbers' => [13, 21, 34, 55, 89]] ],
    'sql_maker passes arrayrefs in insert'
  );


  ($sql, @bind) = $sql_maker->update(
            'lottery',
            {
              'day' => '2008-11-16',
              'numbers' => [13, 21, 34, 55, 89]
            }
  );

  is_same_sql_bind(
    $sql, \@bind,
    q/UPDATE lottery SET day = ?, numbers = ?/,
      [ ['day' => '2008-11-16'], ['numbers' => [13, 21, 34, 55, 89]] ],
    'sql_maker passes arrayrefs in update'
  );
}
