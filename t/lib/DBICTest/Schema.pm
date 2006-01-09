package DBICTest::Schema;

use base qw/DBIx::Class::Schema/;

no warnings qw/qw/;

__PACKAGE__->load_classes(qw/
  Artist
  CD
  #dummy
  Track
  Tag
  /,
  { 'DBICTest::Schema' => [qw/
    LinerNotes
    OneKey
    #dummy
    TwoKeys
  /]},
  (
    'FourKeys',
    '#dummy',
    'SelfRef',
    'Producer',
    'CD_to_Producer',
  ),
  qw/SelfRefAlias/
);

1;
