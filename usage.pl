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
	, ARRAY => [qw(elment_1 element_2 element_3)]
	) ;

my $s = \%tree ;

#-------------------------------------------------------------------
# package global setup data
#-------------------------------------------------------------------

$Data::TreeDumper::Useascii = 0 ;
$Data::TreeDumper::Maxdepth = 2 ;
$Data::TreeDumper::Filter    =  \&Data::TreeDumper::HashKeysSorter ;

print Data::TreeDumper::DumpTree($s, "Using package data") ;
print Data::TreeDumper::DumpTree($s, "Using package data with override", MAX_DEPTH => 1) ;

#-------------------------------------------------------------------
# OO interface
#-------------------------------------------------------------------

my $dumper = new Data::TreeDumper() ;
$dumper->UseAnsi(1) ;
$dumper->Maxdepth(2) ;
$dumper->Filter(\&Data::TreeDumper::HashKeysSorter) ;

print $dumper->Dump($s, "Using OO interface") ;
 
#-------------------------------------------------------------------
# native interface
#-------------------------------------------------------------------

print Data::TreeDumper::TreeDumper
	(
	  $s
	, {
	    FILTER      => \&Data::TreeDumper::HashKeysSorter
	  , START_LEVEL => 0
	  , USE_ASCII   => 1
	  , MAX_DEPTH   => 2
	  , TITLE       => "Using Native interface\n"
	  }
	) ;
print Data::TreeDumper::TreeDumper
	(
	  $s
	, {
	    FILTER      => \&Data::TreeDumper::HashKeysSorter
	  , START_LEVEL => 1
	  , USE_ASCII   => 1
	  #~ , MAX_DEPTH   => 2
	  , TITLE       => "Using Native interface\n"
	  }
	) ;
