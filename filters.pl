#! /usr/bin/perl 

use strict ;
use warnings ;
use Carp ;

use Data::TreeDumper ;

our $s ;
do "s" ;

$Data::TreeDumper::Useascii = 0 ;

print Data::TreeDumper::DumpTree($s, 'Unaltered data structure') ;

#-------------------------------------------------------------------------------
# removing nodes from dump
#-------------------------------------------------------------------------------

sub RemoveAFromHash
{
# Entries matching /^a/i have '*' prepended

my $tree = shift ;

if('HASH' eq ref $tree)
	{
	my @keys_to_dump ;
	
	for my $key_name (keys %$tree)
		{
		push @keys_to_dump, $key_name unless($key_name =~ /^a/i)
		}
		
	return ('HASH', undef, @keys_to_dump) ;
	}
	
return (Data::TreeDumper::DefaultNodesToDisplay($tree)) ;
}

print Data::TreeDumper::DumpTree($s, "Remove hash keys matching /^a/i", FILTER => \&RemoveAFromHash) ;

#-------------------------------------------------------------------------------
# label changing
#-------------------------------------------------------------------------------

sub StarOnA
{
# Entries matching /^a/i have '*' prepended

my $tree = shift ;

if('HASH' eq ref $tree)
	{
	my @keys_to_dump ;
	
	for my $key_name (keys %$tree)
		{
		if($key_name =~ /^a/i)
			{
			$key_name = [$key_name, "* $key_name"] ;
			}
			
		push @keys_to_dump, $key_name ;
		}
		
	return ('HASH', undef, @keys_to_dump) ;
	}
	
return (Data::TreeDumper::DefaultNodesToDisplay($tree)) ;
}

print Data::TreeDumper::DumpTree($s, "Entries matching /^a/i have '*' prepended", FILTER => \&StarOnA) ;

#-------------------------------------------------------------------------------
# tree replacement
#-------------------------------------------------------------------------------

sub MungeArray
{
my $tree = shift ;

if('ARRAY' eq ref $tree)
	{
	my $concatenation = '' ;
	$concatenation .= $_ for (@$tree) ;
	
	return ('ARRAY', [$concatenation ], [0, 'concatenation of all the values']) ;
	}
	
return (Data::TreeDumper::DefaultNodesToDisplay($tree)) ;
}

print Data::TreeDumper::DumpTree($s, 'MungeArray!', FILTER => \&MungeArray) ;

sub ReplaceArray
{
# replace arrays with hashes!!!

my $tree = shift ;

if('ARRAY' eq ref $tree)
	{
	my $replacement = {OLD_TYPE => 'Array', NEW_TYPE => 'Hash'} ;
	return ('HASH', $replacement, keys %$replacement) ;
	}
	
return (Data::TreeDumper::DefaultNodesToDisplay($tree)) ;
}

print Data::TreeDumper::DumpTree($s, 'Replace arrays with hashes!', FILTER => \&ReplaceArray) ;

#-------------------------------------------------------------------------------
# filter chaining
#-------------------------------------------------------------------------------

sub AddStar
{
my $tree = shift ;
my $level = shift ;
my $keys = shift ;

if('HASH' eq ref $tree)
	{
	$keys = [keys %$tree] unless defined $keys ;
	
	my @new_keys ;
	
	for (@$keys)
		{
		if('' eq ref $_)
			{
			push @new_keys, [$_, "* $_"] ;
			}
		else
			{
			# another filter has changed the label
			push @new_keys, [$_->[0], "* $_->[1]"] ;
			}
		}
	
	return('HASH', undef, @new_keys) ;
	}
	
return(Data::TreeDumper::DefaultNodesToDisplay($tree)) ;
}

sub RemoveA
{
my $tree = shift ;
my $level = shift ;
my $keys = shift ;

if('HASH' eq ref $tree)
	{
	$keys = [keys %$tree] unless defined $keys ;
	my @new_keys ;
	
	for (@$keys)
		{
		if('' eq ref $_)
			{
			push @new_keys, $_ unless /^a/i ;
			}
		else
			{
			# another filter has changed the label
			push @new_keys, $_ unless $_->[0] =~ /^a/i ;
			}
		}
	
	return('HASH', undef, @new_keys) ;
	}
	
return(Data::TreeDumper::DefaultNodesToDisplay($tree)) ;
}

print DumpTree($s, 'AddStar', FILTER => \&AddStar) ;
print DumpTree($s, 'HashKeysSorter+ AddStar', FILTER => CreateChainingFilter(\&Data::TreeDumper::HashKeysSorter, \&AddStar)) ;
print DumpTree($s, 'AddStar + HashKeysSorter', FILTER => CreateChainingFilter(\&AddStar, \&Data::TreeDumper::HashKeysSorter)) ;

print DumpTree($s, 'RemoveA', FILTER => \&RemoveA) ;
print DumpTree($s, 'AddStart + RemoveA', FILTER => CreateChainingFilter(\&AddStar, \&RemoveA)) ;
