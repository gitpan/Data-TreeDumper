$s = {
  'A' => {
    'a' => {},
    'c123' => sub { "DUMMY" },
    'd' => \do{my $o},
    'bbbbbb' => do{my $o}
  },
  'C' => {
    'b' => {
      'a' => {
        'c' => 42,
        'a' => {},
        'b' => sub { "DUMMY" }
      }
    }
  },
  'ARRAY' => [
    'elment_1',
    'element_2',
    'element_3'
  ]
};
${$s->{'A'}{'d'}} = $s->{'A'}{'c123'};
$s->{'A'}{'bbbbbb'} = $s->{'A'}{'c123'};
$s->{'CopyOfARRAY'} = $s->{'ARRAY'};

$s->{za} = '';

