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

$Data::TreeDumper::Useascii     = 0 ;
$Data::TreeDumper::Maxdepth     = 2 ;
$Data::TreeDumper::Filter       =  \&Data::TreeDumper::HashKeysSorter ;
$Data::TreeDumper::Virtualwidth =  80 ;

print Data::TreeDumper::DumpTree($s, "Using package data") ;
print Data::TreeDumper::DumpTree($s, "Using package data with override", MAX_DEPTH => 1) ;

#-------------------------------------------------------------------
# OO interface
#-------------------------------------------------------------------

my $dumper = new Data::TreeDumper() ;
$dumper->UseAnsi(1) ;
$dumper->SetMaxDepth(2) ;
$dumper->SetVirtualWidth(80) ;
$dumper->SetFilter(\&Data::TreeDumper::HashKeysSorter) ;

print $dumper->Dump($s, "Using OO interface") ;
 
#-------------------------------------------------------------------
# native interface
#-------------------------------------------------------------------

print Data::TreeDumper::TreeDumper
	(
	  $s
	, {
	    FILTER        => \&Data::TreeDumper::HashKeysSorter
	  , START_LEVEL   => 0
	  , USE_ASCII     => 1
	  , MAX_DEPTH     => 2
	  , VIRTUAL_WIDTH => 80
	  , TITLE         => "Using Native interface start level = 0"
	  }
	) ;
	
print Data::TreeDumper::TreeDumper
	(
	  $s
	, {
	    FILTER      => \&Data::TreeDumper::HashKeysSorter
	  , START_LEVEL => 1
	  , USE_ASCII   => 1
	  , TITLE       => "Using Native interface"
	  }
	) ;

#~ print DumpTrees
	#~ (
	  #~ [$s, "Using package data", MAX_DEPTH => 1]
	#~ , [$s, "Using package data", MAX_DEPTH => 2]
	#~ , USE_ASCII => 1
	#~ ) ;

#~ print $dumper->DumpMany
	#~ (
	  #~ [$s, "Using package data", MAX_DEPTH => 1]
	#~ , [$s, "Using package data", MAX_DEPTH => 2]
	#~ , USE_ASCII => 1
	#~ ) ;
