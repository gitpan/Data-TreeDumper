#! /usr/bin/perl

use strict ;
use warnings ;
use Carp ;

use Data::TreeDumper ;

my $sub = sub {} ;

my %tree = 
	(
	A => 
		{
		a => 
			{
			}
		, bbbbbb => $sub
		, c123 => $sub
		, d => \$sub
		, eeeee => $sub
		, f => $sub
		, g => $sub
		}
		
	, C =>	{
		b =>
			{
			a => 
				{
				a => 
					{
					}
					
				, b => sub
					{
					}
				, c => 42
				}
				
			}
		}
	, B => 'scalar'
	, C => [qw(element_1 element_2)]
	) ;

my $hi = '25' ;
my $array_ref = [0, 1, \$hi] ;
$tree{Nadim} = \$array_ref ;
#~ $tree{REF2_to_array_ref} = \$array_ref ;

#~ $tree{aREF_to_C} = $tree{C} ;
#~ $tree{REF_to_C} = \($tree{C}) ;

#~ $tree{aREF_REF_to_C} = $tree{REF_to_C} ;
#~ $tree{REF_REF_to_C} = \($tree{REF_to_C}) ;

$tree{SELF} = [ 0, 1, 2, \%tree] ;
$tree{RREF} = \\$array_ref ;
$tree{RREF2} = \\$array_ref ;

$tree{SCALAR} = \$hi ;
$tree{SCALAR2} = \$hi ;
$tree{ARRAY} = [0, 1, \$hi] ;

my $object = {m1 => 12, m2 => [0, 1, 2]} ;
bless $object, 'SuperObject' ;

$tree{OBJECT} = $object ;
$tree{OBJECT2} = $object ;
$tree{OBJECT_REF_REF_REF} = \\\$object ;

my $ln = 'Long_name ' x 20 ;
$tree{$ln} = 0 ;

$tree{ARRAY2} = [0, 1, \$object, $object] ;

use IO::File;
my $fh = new IO::File;
$tree{FILE} = $fh ;

use IO::Handle;
my $io = new IO::Handle;

$tree{IO} = $io ;

$tree{ARRAY_ZERO} = [] ;

sub HashKeysStartingAboveA
{
my $tree = shift ;

if('HASH' eq ref $tree)
	{
	return( 'HASH', undef, sort grep {!/^A/} keys %$tree) ;
	}
	
return (Data::TreeDumper::DefaultNodesToDisplay($tree)) ;
}


my $tree_dumper = new Data::TreeDumper;
#~ $tree_dumper->UseAnsi(1) ;
#~ $tree_dumper->UseAscii(0) ;
#~ $tree_dumper->SetMaxDepth(2) ;

print $tree_dumper->Dump(\%tree, "Data:TreeDumper dump example:", FILTER => \&Data::TreeDumper::HashKeysSorter) ;
#~ print $tree_dumper->Dump(\%tree, "Data:TreeDumper dump example:", INDENTATION => '  ') ;

