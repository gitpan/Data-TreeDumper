$s = {
  'STDIN' => \*STDIN,
  'RS' => \4,
  
  'A' => {
    'a' => {},
    'code1' => sub { "DUMMY" },
    'b' => {
      'a' => 0,
      'b' => 1,
      'c' => {
        'a' => 1,
        'b' => 1,
        'c' => 1,
        }
      },
    'b2' => {
      'a' => 1,
      'b' => 1,
      'c' => 1,
      }
  },
  'C' => {
    'b' => {
      'a' => {
        'c' => 42,
        'a' => {},
        'b' => sub { "DUMMY" },
	'empty' => undef
      }
    }
  },
  'ARRAY' => [
    'elment_1',
    'element_2',
    'element_3',
    [1, 2],
    {a => 1, b => 2}
  ]
};
${$s->{'A'}{'code3'}} = $s->{'A'}{'code1'};
$s->{'A'}{'code2'} = $s->{'A'}{'code1'};
$s->{'CopyOfARRAY'} = $s->{'ARRAY'};
$s->{'C1'} = \($s->{'C2'});
$s->{'C2'} = \($s->{'C1'});

$s->{za} = '';

$object = bless {A =>[], B => 123}, 'SuperObject' ;
$s->{object} = $object ;

