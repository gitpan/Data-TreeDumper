
package Data::TreeDumper ;

use 5.006 ;
use strict ;
use warnings ;
use Carp ;

require Exporter ;
use AutoLoader qw(AUTOLOAD) ;

our @ISA = qw(Exporter) ;

our %EXPORT_TAGS = 
	(
	'all' => [ qw() ]
	) ;

our @EXPORT_OK = ( @{$EXPORT_TAGS{'all'} } ) ;

our @EXPORT = qw(DumpTree DumpTrees CreateChainingFilter);
our $VERSION = '0.16' ;

my $WIN32_CONSOLE ;

BEGIN
	{
	if($^O ne 'MSWin32')
		{
		eval "use Term::Size;" ;
		die $@ if $@ ;
		}
	else
		{
		eval "use Win32::Console;" ;
		die $@ if $@ ;
		
		$WIN32_CONSOLE= new Win32::Console;
		$WIN32_CONSOLE->Alloc();
		}
	}
	
use Text::Wrap  ;

#----------------------------------------------------------------------
# package variables � la Data::Dumper (as is the silly  naming scheme)
#----------------------------------------------------------------------

our $Filter              = undef ;
our $Levelfilters        = undef ;
our $Useascii            = 1 ;
our $Maxdepth            = -1 ;
our $Indentation         = '' ;
our $Nooutput            = 0;
our $Startlevel          = 1 ;
our $Virtualwidth        = 120 ; 
our $Displayrootaddress  = 0 ;
our $Displayaddress      = 1 ;
our $Displayobjecttype   = 1 ;
our $Displayperlsize     = 0 ;
our $Displayperladdress  = 0 ;
our $Numberlevels        = 0 ;
our $Colorlevels         = undef ;
our $Glyphs              = ['|  ', '|- ', '`- ', '   '] ;
our $Quotehashkeys       = 0 ;

#~ our $Deparse    = 0 ;  # not implemented 

sub GetPackageSetup
{
return
	(
	  FILTER                 => $Data::TreeDumper::Filter
	, LEVEL_FILTERS          => $Data::TreeDumper::Levelfilters
	, USE_ASCII              => $Data::TreeDumper::Useascii
	, MAX_DEPTH              => $Data::TreeDumper::Maxdepth
	, INDENTATION            => $Data::TreeDumper::Indentation
	, NO_OUTPUT              => $Data::TreeDumper::Nooutput
	, START_LEVEL            => $Data::TreeDumper::Startlevel
	, VIRTUAL_WIDTH          => $Data::TreeDumper::Virtualwidth
	, DISPLAY_ROOT_ADDRESS   => $Data::TreeDumper::Displayrootaddress
	, DISPLAY_ADDRESS        => $Data::TreeDumper::Displayaddress
	, DISPLAY_OBJECT_TYPE    => $Data::TreeDumper::Displayobjecttype
	, DISPLAY_PERL_SIZE      => $Data::TreeDumper::Displayperlsize
	, DISPLAY_PERL_ADDRESS   => $Data::TreeDumper::Displayperladdress
	, NUMBER_LEVELS          => $Data::TreeDumper::Numberlevels
	, COLOR_LEVELS           => $Data::TreeDumper::Colorlevels
	, GLYPHS                 => $Data::TreeDumper::Glyphs
	, QUOTE_HASH_KEYS        => $Data::TreeDumper::Quotehashkeys
	
	, __DATA_PATH            => ''
	, __TYPE_SEPARATORS      => {
					  ''       => ['<SCALAR:', '>']
					, 'REF'    => ['<', '>']
					, 'CODE'   => ['<CODE:', '>']
					, 'HASH'   => ['{\'', '\'}']
					, 'ARRAY'  => ['[', ']']
					, 'SCALAR' => ['<SCALAR_REF:', '>']
					} 
	) ;
}

#-------------------------------------------------------------------------------
# API
#-------------------------------------------------------------------------------
sub DumpTree
{
my $structure_to_dump = shift ;
my $title             = shift ;
my %overrides         =  @_ ;

$title = defined $title ? $title : '' ;

return(TreeDumper($structure_to_dump, {TITLE => $title, GetPackageSetup(), %overrides})) ;
}

#-------------------------------------------------------------------------------
sub DumpTrees
{
my @trees           = grep {'ARRAY' eq ref $_} @_ ;
my %global_overrides = grep {'ARRAY' ne ref $_} @_ ;

my $dump = '' ;

for my $tree (@trees)
	{
	my ($structure_to_dump, $title, %overrides) = @{$tree} ;
	
	$dump .= DumpTree($structure_to_dump, $title, %global_overrides, %overrides) ;
	}
	
return($dump) ;
}

#-------------------------------------------------------------------------------
# The dumper
#-------------------------------------------------------------------------------
sub TreeDumper
{
my $tree             = shift ;
my $setup            = shift ;
my $level            = shift || 0 ;
my $levels_left      = shift || [] ;
my $already_displayed_nodes = shift || {$tree => GetReferenceType($tree) . '0', NEXT_INDEX => 1} ;

my $tree_type = ref $tree ;

confess "TreeDumper can only display objects passed by reference!\n" if('' eq  $tree_type) ;

return('') if ($setup->{MAX_DEPTH} == $level) ;

#--------------------------
# perl data size
#--------------------------
if($level == 0)
	{
	eval 'use Devel::Size qw(size total_size) ;' ;

	if($@)
		{
		# shoud we warn ???
		delete $setup->{DISPLAY_PERL_SIZE} ;
		}
	}
	
local $Devel::Size::warn = 0 if($level == 0) ;

#--------------------------
# filters
#--------------------------
my $filter_sub    = $setup->{FILTER} ;
my $level_filters = $setup->{LEVEL_FILTERS} ;

my ($replacement_tree, $nodes_to_display) ;

# specific level filter has higher priority
$filter_sub = $level_filters->{$level} if(defined $level_filters && exists $level_filters->{$level}) ;

if(defined $filter_sub)
	{
	($tree_type, $replacement_tree, @$nodes_to_display) = $filter_sub->($tree, $level, $setup->{__DATA_PATH}, $nodes_to_display, $setup) ;
	$tree = $replacement_tree if(defined $replacement_tree) ;
	}
else
	{
	($tree_type, undef, @$nodes_to_display) = DefaultNodesToDisplay($tree) ;
	}
	
return('') unless defined $tree_type ; #easiest way to prune in a filter is to return undef as type

# filters can change the name of the nodes by passing an array ref
my @node_names ;
my @nodes_to_display = @$nodes_to_display ;

for my $node (@nodes_to_display)
	{
	if('ARRAY' eq ref $node)
		{
		push @node_names, $node->[1] ;
		$node = $node->[0] ; # Modify $nodes_to_display
		}
	else
		{
		push @node_names, $node ;
		}
	}

#--------------------------
# dump
#--------------------------
my $output = '' ;
if($level == 0)
	{
	if(defined $setup->{RENDERER} && '' eq ref $setup->{RENDERER})
		{
		eval <<EOE ;
		use Data::TreeDumper::Renderer::$setup->{RENDERER} ;
		\$setup->{RENDERER} = Data::TreeDumper::Renderer::$setup->{RENDERER}::GetRenderer() ;
EOE
		
		die "Data::TreeDumper couldn't load renderer '$setup->{RENDERER}':\n$@" if $@ ;
		}
	
	if(defined $setup->{RENDERER}{NAME})
		{
		eval <<EOE ;
		use Data::TreeDumper::Renderer::$setup->{RENDERER}{NAME} ;
		\$setup->{RENDERER} = {%{\$setup->{RENDERER}}, %{Data::TreeDumper::Renderer::$setup->{RENDERER}{NAME}::GetRenderer()}} ;
EOE
		
		die "Data::TreeDumper couldn't load renderer '$setup->{RENDERER}{NAME}':\n$@" if $@ ;
		}
		
	if(defined $setup->{RENDERER}{BEGIN})
		{
		$output .= $setup->{RENDERER}{BEGIN}($setup->{TITLE}, '[' . GetReferenceType($tree) . "0]", $tree, $setup) ;
		}
	else
		{
		$output = $setup->{INDENTATION} ;
		
		$output .= defined $setup->{TITLE} ? $setup->{TITLE} : '' ;
		$output .= '[' . GetReferenceType($tree) . "0]" if($setup->{DISPLAY_ROOT_ADDRESS}) ;
		$output .= " $tree"                             if($setup->{DISPLAY_PERL_ADDRESS}) ;
		$output .= " <" . total_size($tree) . ">"       if($setup->{DISPLAY_PERL_SIZE}) ;
		$output .= "\n" ;
		}
	}

my ($opening_bracket, $closing_bracket) ;
if(exists $setup->{__TYPE_SEPARATORS}{$tree_type})
	{
	($opening_bracket, $closing_bracket) = @{$setup->{__TYPE_SEPARATORS}{$tree_type}} ;
	}
else
	{
	($opening_bracket, $closing_bracket) = ('<Unknown type!', '>') ;
	}

for (my $nodes_left = $#nodes_to_display ; $nodes_left >= 0 ; $nodes_left--)
	{
	$levels_left->[$level] = $nodes_left ;
	
	my $node_index = $#nodes_to_display - $nodes_left ;
	
	my ($element, $element_name, $element_address, $element_id) ;
	for($tree_type)
		{
		# TODO, move this out of the loop with static table of functions
		'HASH' eq $_ and do
			{
			$element = $tree->{$nodes_to_display[$node_index]} ;
			$element_address = "$element" if defined $element ;
			
			if($setup->{QUOTE_HASH_KEYS})
				{
				$element_name = "'$node_names[$node_index]'" ;
				}
			else
				{
				$element_name = $node_names[$node_index] ;
				}
				
			$element_id = \($tree->{$nodes_to_display[$node_index]}) ;
			
			last
			} ;
		
		'ARRAY' eq $_ and do
			{
			$element = $tree->[$nodes_to_display[$node_index]] ;
			$element_address = "$element" if defined $element ;
			$element_name = $node_names[$node_index] ;
			$element_id = \($tree->[$nodes_to_display[$node_index]]) ;
			last ;
			} ;
			
		'REF' eq $_ and do
			{
			$element = $$tree ;
			$element_address = "$element" if defined $element ;
			$element_name = "$tree" ;
			$element_id = $tree ;
			last ;
			} ;
			
		'CODE' eq $_ and do
			{
			$element = $tree ;
			$element_address = "$element" if defined $element ;
			$element_name = $tree ;
			$element_id = $tree ;
			last ;
			} ;
			
		('SCALAR' eq $_) and do
		#~ ('SCALAR' eq $_ or 'GLOB' eq $_) and do
			{
			$element = $$tree ;
			$element_address = "$element" if defined $element ;
			$element_name = '?' ;
			$element_id = $tree ;
			last ;
			} ;
		}
	
	local $setup->{__DATA_PATH} = "$setup->{__DATA_PATH}$opening_bracket$element_name$closing_bracket" ;
	
	my $perl_data = '' ;
	$perl_data = " <" . total_size($element) . ">" if($setup->{DISPLAY_PERL_SIZE}) ;
	
	my $tag = '' ;
	my $element_value = '' ;
	my $is_terminal_node = 0 ;
	
	for(ref $element)
		{
		'' eq $_ and do
			{
			$is_terminal_node++ ;
			$tag = 'S' ;
			
			my $value = defined $element ? $element : 'undef' ;
			$element_address = $element_id ; # OK for terminal nodes
			$element_value = "$value" ;
			
			$perl_data  .= " $element_id" if($setup->{DISPLAY_PERL_ADDRESS}) ;
			last ;
			} ;
			
		'CODE' eq $_ and do 
			{
			$is_terminal_node++ ;
			$tag = 'C' ;
			$element_value = "$element" ;
			$perl_data  .= " $element_id" if($setup->{DISPLAY_PERL_ADDRESS}) ;
			last ;
			} ;
			
		'SCALAR' eq $_ and do
			{
			$tag = 'RS' ;
			$element_address = $element_id ;
			$perl_data  .= " $element_id" if($setup->{DISPLAY_PERL_ADDRESS}) ;
			last ;
			} ;
			
		'GLOB' eq $_ and do
			{
			$is_terminal_node++ ;
			$tag = 'G' ;
			$perl_data  .= " $element" if($setup->{DISPLAY_PERL_ADDRESS}) ;
			last ;	
			} ;
			
		'HASH' eq $_ and do
			{
			$tag = 'H' ;
			$perl_data  .= " $element" if($setup->{DISPLAY_PERL_ADDRESS}) ;
			last ;
			} ;
			
		'ARRAY' eq $_ and do
			{
			$tag = 'A' ;
			$perl_data  .= " $element" if($setup->{DISPLAY_PERL_ADDRESS}) ;
			last ;
			} ;
			
		'REF' eq $_ and do
			{
			$tag = 'R' ;
			$perl_data  .= " $element" if($setup->{DISPLAY_PERL_ADDRESS}) ;
			last ;
			} ;
			
		# DEFAULT, an object.
		$tag = 'O' ;
		$element_value = "Object of type '" . ref($element) . "'" if($setup->{DISPLAY_OBJECT_TYPE}) ;
		$perl_data  .= " $element" if($setup->{DISPLAY_PERL_ADDRESS}) ;
		}
		
	my $dtd_address = $tag . $already_displayed_nodes->{NEXT_INDEX} ;
	my $address_field = '' ;
	
	if(exists $already_displayed_nodes->{$element_address})
		{
		$already_displayed_nodes->{NEXT_INDEX}++ ;
		
		$address_field = " [$dtd_address -> $already_displayed_nodes->{$element_address}]" if $setup->{DISPLAY_ADDRESS} ;
		$is_terminal_node = 1 ;
		}
	else	
		{
		$already_displayed_nodes->{$element_address} = $dtd_address ;
		$already_displayed_nodes->{NEXT_INDEX}++ ;
				
		$address_field = " [$dtd_address]" if $setup->{DISPLAY_ADDRESS} ;
		}
		
	#default renderer is inlined
	unless($setup->{NO_OUTPUT})
		{
		my 
			(
			  $previous_level_separator
			, $separator
			, $subsequent_separator # used for  wrapping text
			, $separator_size
			) = GetSeparator
					(
					  $level
					, $nodes_left
					, $levels_left
					, $setup->{START_LEVEL}
					, $setup->{GLYPHS}
					, $setup->{COLOR_LEVELS}
					) ;
					
		if(defined $setup->{RENDERER}{NODE})
			{
			$output .= $setup->{RENDERER}{NODE}
						(
						  $element
						, $level
						, $is_terminal_node
						, $previous_level_separator
						, $separator
						, $element_name
						, $element_value
						, $dtd_address
						, $address_field
						, $perl_data
						, $setup
						) ;
			}
		else
			{
			#--------------------------
			# wrapping	
			#--------------------------
			my $level_text             = GetLevelText($element, $level, $setup)	;
			my $tree_header            = $setup->{INDENTATION} . $level_text . $previous_level_separator . $separator  ;
			my $tree_subsequent_header = $setup->{INDENTATION} . $level_text . $previous_level_separator . $subsequent_separator ;
			
			my $element_description = $element_name ;
			$element_description .= " = $element_value" if $element_value ne '' ;
			$element_description .= $address_field. $perl_data . "\n" ;
			
			my ($columns, $rows) ;
			if($^O ne 'MSWin32')
				{
				($columns, $rows) = Term::Size::chars *STDOUT{IO} ;
				}
			else
				{
				($columns, $rows) = $WIN32_CONSOLE->Size();
				}
			
			$columns = $setup->{VIRTUAL_WIDTH} if $columns eq '' ;
			
			local $Text::Wrap::columns  = $columns ;
			local $Text::Wrap::unexpand = 0 ;
			
			if(length($tree_header) + length($element_description) > $columns)
				{
				$output .= wrap
						(
						  $tree_header 
						, $tree_subsequent_header 
						, $element_description
						) ;
				}
			else
				{
				$output .= $tree_header ;
				$output .= $element_description ;
				}
			}
		}
		
	$output .= TreeDumper($element, $setup, $level + 1, $levels_left, $already_displayed_nodes) unless $is_terminal_node ;
	}
	
if($level == 0)
	{
	if(defined $setup->{RENDERER}{END})
		{
		$output .= $setup->{RENDERER}{END}($setup) ;
		}
	else
		{
		unless ($setup->{USE_ASCII})
			{
			# convert to ANSI
			$output =~ s/\|  /\033(0\170  \033(B/g ;
			$output =~ s/\|- /\033(0\164\161 \033(B/g ;
			$output =~ s/\`- /\033(0\155\161 \033(B/g ;
			}
		}
	}
	
return($output) ;
}

#----------------------------------------------------------------------
#  filters
#----------------------------------------------------------------------

sub DefaultNodesToDisplay
{
my ($tree, undef, undef, $keys) = @_ ;

my $tree_type = ref $tree ;

if('HASH' eq $tree_type)
	{
	return('HASH', undef, @$keys) if(defined $keys) ;
	return('HASH', undef, sort keys %$tree) ;
	}
	
if('ARRAY' eq $tree_type) 
	{
	return('ARRAY', undef, @$keys) if(defined $keys) ;
	return('ARRAY', undef, (0 .. @$tree - 1)) ;
	}

return('SCALAR', undef, (0))  if('SCALAR'  eq $tree_type) ;
return('REF', undef, (0))     if('REF'     eq $tree_type) ;
return('CODE', undef, (0))    if('CODE'    eq $tree_type) ;

my @nodes_to_display ;
undef $tree_type ;

if($tree =~ /=/)
	{
	for($tree)
		{
		/=HASH/ and do
			{
			@nodes_to_display = sort keys %$tree ;
			$tree_type = 'HASH' ;
			last ;
			} ;
		
		/=ARRAY/ and do
			{
			@nodes_to_display = (0 .. @$tree - 1) ;
			$tree_type = 'ARRAY' ;
			last ;
			} ;
			
		/=GLOB/ and do
			{
			@nodes_to_display = (0) ;
			$tree_type = 'REF' ;
			last ;
			} ;
			
		warn "TreeDumper: Unsupported underlying type for $tree.\n" ;
		}
	}

return($tree_type, undef, @nodes_to_display) ;
}

#-------------------------------------------------------------------------------

sub HashKeysSorter
{
my ($structure_to_dump, undef, undef, $keys) = @_ ;

if('HASH' eq ref $structure_to_dump)
	{
	return('HASH', undef, sort keys %$structure_to_dump) unless defined $keys ;
	
	my %keys ;
	for my $key (@$keys)
		{
		if('ARRAY' eq ref $key)
			{
			$keys{$key->[0]} = $key ;
			}
		else
			{
			$keys{$key} = $key ;
			}
		}
		
	return('HASH', undef, map{$keys{$_}} sort keys %keys) ;
	}

return(Data::TreeDumper::DefaultNodesToDisplay($structure_to_dump)) ;
}

#----------------------------------------------------------------------

sub CreateChainingFilter
{
my @filters = @_ ;

return sub
	{
	my $tree = shift ;
	my $level = shift ;
	my $path = shift ;
	my $keys = shift ;
	
	my ($tree_type, $replacement_tree);
	
	for my $filter (@filters)
		{
		($tree_type, $replacement_tree, @$keys) = $filter->($tree, $level, $path, $keys) ;
		$tree = $replacement_tree if (defined $replacement_tree) ;
		}
		
	return ($tree_type, $replacement_tree, @$keys) ;
	}
} ;

#-------------------------------------------------------------------------------
# renderinf support
#-------------------------------------------------------------------------------

{ # make %types private
my %types =
	(
	  ''       => 'SCALAR! not a reference!'
	, 'REF'    => 'R'
	, 'CODE'   => 'C'
	, 'HASH'   => 'H'
	, 'ARRAY'  => 'A'
	, 'SCALAR' => 'RS'
	) ;

sub GetReferenceType
{
my $reference = ref $_[0] ;
	
if(exists $types{$reference})
	{
	return($types{$reference}) ;
	}
else
	{
	return('O') ;
	}
}

} # make %types private

#-------------------------------------------------------------------------------
sub GetLevelText
{
my ($element, $level, $setup) = @_ ;
my $level_text = '' ;

if($setup->{NUMBER_LEVELS})
	{
	if('CODE' eq ref $setup->{NUMBER_LEVELS})
		{
		$level_text = $setup->{NUMBER_LEVELS}->($element, $level, $setup) ;
		}
	else
		{
		my $color_levels = $setup->{COLOR_LEVELS} ;
		my ($color_start, $color_end) = ('', '') ;
		
		if($color_levels)
			{
			if('ARRAY' eq ref $color_levels)
				{
				my $color_index = $level % @{$color_levels->[0]} ;
				($color_start, $color_end) = ($color_levels->[0][$color_index] , $color_levels->[1]) ;
				}
			else
				{
				# assume code
				($color_start, $color_end) = $color_levels->($level) ;
				}
			}
			
		$level_text = sprintf("$color_start%$setup->{NUMBER_LEVELS}d$color_end ", ($level + 1)) ;
		}
	}

return($level_text) ;
}

#----------------------------------------------------------------------

sub GetSeparator 
{
# This sub is a good candidate for Memoize
my 
	(
	  $level
	, $is_last_in_level
	, $levels_left
	, $start_level
	, $glyphs
	, $colors # array or code ref
	) = @_ ;
	
my $separator_size = 0 ;
my $previous_level_separator = '' ;
my ($color_start, $color_end) = ('', '') ;
	
for my $current_level ((1 - $start_level) .. ($level - 1))
	{
	$separator_size += 3 ;
	
	if($colors)
		{
		if('ARRAY' eq ref $colors)
			{
			my $color_index = $current_level % @{$colors->[0]} ;
			($color_start, $color_end) = ($colors->[0][$color_index] , $colors->[1]) ;
			}
		else
			{
			if('CODE' eq ref $colors)
				{
				($color_start, $color_end) = $colors->($current_level) ;
				}
			#else
				# ignore other types
			}
		}
		
	if($levels_left->[$current_level] == 0)
		{
		#~ $previous_level_separator .= "$color_start   $color_end" ;
		$previous_level_separator .= "$color_start$glyphs->[3]$color_end" ;
		}
	else
		{
		#~ $previous_level_separator .= "$color_start|  $color_end" ;
		$previous_level_separator .= "$color_start$glyphs->[0]$color_end" ;
		}
	}
	
my $separator            =  '' ;
my $subsequent_separator =  '' ;

$separator_size += 3 ;

if($level > 0 || $start_level)	
	{
	if($colors)
		{
		if('ARRAY' eq ref $colors)
			{
			my $color_index = $level % @{$colors->[0]} ;
			($color_start, $color_end) = ($colors->[0][$color_index] , $colors->[1]) ;
			}
		else
			{
			# assume code
			($color_start, $color_end) = $colors->($level) ;
			}
		}
		
	if($is_last_in_level == 0)
		{
		#~ $separator            = "$color_start`- $color_end" ;
		#~ $subsequent_separator = "$color_start   $color_end" ;
		$separator            = "$color_start$glyphs->[2]$color_end" ;
		$subsequent_separator = "$color_start$glyphs->[3]$color_end" ;
		}
	else
		{
		#~ $separator            = "$color_start|- $color_end" ;
		#~ $subsequent_separator = "$color_start|  $color_end"  ;
		$separator            = "$color_start$glyphs->[1]$color_end" ;
		$subsequent_separator = "$color_start$glyphs->[0]$color_end"  ;
		}
	}
	
return
	(
	  $previous_level_separator
	, $separator
	, $subsequent_separator
	, $separator_size
	) ;
}

#----------------------------------------------------------------------

1 ;

__END__
=head1 NAME

Data::TreeDumper - Dumps a data structure in a tree fashion.

=head1 SYNOPSIS

  use Data::TreeDumper ;
  
  my $sub = sub {} ;
  
  my $s = 
  {
  A => 
  	{
  	a => 
  		{
  		}
  	, bbbbbb => $sub
  	, c123 => $sub
  	, d => \$sub
  	}
  	
  , C =>
	{
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
  } ;
    
  
  #-------------------------------------------------------------------
  # package setup data
  #-------------------------------------------------------------------
  
  $Data::TreeDumper::Useascii = 0 ;
  $Data::TreeDumper::Maxdepth = 2 ;
  $Data::TreeDumper::Filter   = \&Data::TreeDumper::HashKeysSorter ;
  
  print DumpTree($s, 'title') ;
  print DumpTree($s, 'title', MAX_DEPTH => 1) ;
  print DumpTrees
	  (
	    [$s, "title", MAX_DEPTH => 1]
	  , [$s2, "other_title", DISPLAY_ADDRESS => 0]
	  , USE_ASCII => 1
	  , MAX_DEPTH => 5
	  ) ;
  
=head1 Output

  title:
  |- A [H1]
  |  |- a [H2]
  |  |- bbbbbb = CODE(0x8139fa0) [C3]
  |  |- c123 [C4 -> C3]
  |  `- d [R5]
  |     `- REF(0x8139fb8) [R5 -> C3]
  |- ARRAY [A6]
  |  |- 0 [S7] = elment_1
  |  |- 1 [S8] = element_2
  |  `- 2 [S9] = element_3
  `- C [H10]
     `- b [H11]
        `- a [H12]
           |- a [H13]
           |- b = CODE(0x81ab130) [C14]
           `- c [S15] = 42
    
=head1 DESCRIPTION

Data::Dumper and other modules do a great job of dumping data 
structures.  Their output, however, often takes more brain power to 
understand than the data itself.  When dumping large amounts of data, 
the output can be overwhelming and it can be difficult to see the 
relationship between each piece of the dumped data.

Data::TreeDumper also dumps data in a tree-like fashion but I<hopefully> 
in a format more easily understood.

=head2 Label

Each node in the tree has a label. The label contains a type and an address. The label is displayed to
the right of the entry name within square brackets. 

  |  |- bbbbbb = CODE(0x8139fa0) [C3]
  |  |- c123 [C4 -> C3]
  |  `- d [R5]
  |     `- REF(0x8139fb8) [R5 -> C3]

=head3 Address

The addresses are linearly incremented which should make it easier to locate data.
If the entry is a reference to data already displayed, a B<->> followed with the address of the already displayed data is appended
within the label.

  ex: c123 [C4 -> C3]
             ^     ^ 
             |     | address of the data refered to
             |
             | current address

=head3 Types

B<H>: Hash,
B<C>: Code,
B<A>: Array,
B<R>: Reference,

B<O>: Object,
B<S>: Scalar,
B<RS>: Scalar reference.

=head2 Empty Hash or Array

No structure is displayed for empty hashes or arrays, The address contains the type.

  |- A [S10] = string
  |- EMPTY_ARRAY [A11]
  |- B [S12] = 123
  
=head1 Configuration and Overrides

Data::TreeDumper has configuration options you can set to modify the output it
generates. How to set the options depends on which L<Interface> you use and is explained below.
The configuration options are available in all the Interfaces and are the I<Native>
interface arguments.

The package and object oriented interface take overrides as trailing arguments. Those
overrides are active within the current dump call only.

  ex:
  $Data::TreeDumper::Maxdepth = 2 ;
  
  # maximum depth set to 1 for the duration of the call only
  print DumpTree($s, 'title', MAX_DEPTH => 1) ;
	
  # maximum depth is 2
  print DumpTree($s, 'title') ;
  
=head2 DISPLAY_ROOT_ADDRESS

By default, B<Data::TreeDumper> doesn't display the address of the root.

  DISPLAY_ROOT_ADDRESS => 1 # show the root address
  
=head2 DISPLAY_ADDRESS

When the dumped data is not self-referential, displaying the address of each node clutters the display. You can
direct B<Data::TreeDumper> to not display the node address by using:

  DISPLAY_ADDRESS => 0

=head2 DISPLAY_OBJECT_TYPE

Data::TreeDumper displays the package in which an object is blessed.  You 
can suppress this display by using:

  DISPLAY_OBJECT_TYPE => 1

=head2 PERL DATA 

Setting one of the options below will show internal perl data:

  Cells: <2234> HASH(0x814F20c)
  |- A1 [H1] <204> HASH(0x824620c)
  |  `- VALUE [S2] = datadatadatadatadatadatadatadatadatadata <85>
  |- A8 [H11] <165> HASH(0x8243d68)
  |  `- VALUE [S12] = C <46>
  `- C2 [H19] <165> HASH(0x8243dc0)
     `- VALUE [S20] = B <46>

=head3 DISPLAY_PERL_ADDRESS

Setting this option will show the perl-address of the dumped data.

  DISPLAY_PERL_ADDRESS => 1 
  
=head3 DISPLAY_PERL_SIZE

Setting this option will show the size of the memory allocated for each element in the tree within angle brackets.

  DISPLAY_PERL_SIZE => 1 

See also the excellent B<Devel::Size::Report> from which I stole the idea.

=head2 QUOTE_HASH_KEYS

B<QUOTE_HASH_KEYS> and its package variable B<$Data::TreeDumper::Quotehashkeys> can be set if you wish to single quote
the hash keys. Hash keys are not quoted by default.

  DumpTree(\$s, 'some data:', QUOTE_HASH_KEYS => 1) ;
  
  # output
  some data:
  `- REF(0x813da3c) [H1]
     |- 'A' [H2]
     |  |- 'a' [H3]
     |  |- 'b' [H4]
     |  |  |- 'a' = 0 [S5]

=head2 NO_OUTPUT

This option suppresses all output generated by Data::TreeDumper. 
This is useful when you want to iterate through your data structures and 
display the data yourself, manipulate the data structure, or do a search 
(see L<using filter as iterators> below)

=head2 Filters

Data::TreeDumper can sort the tree nodes with a user defined subroutine.

  FILTER => \&ReverseSort
  FILTER => \&Data::TreeDumper::HashKeysSorter

The filter routine is passed these arguments:

=over 2

=item 1 - a reference to the node which is going to be displayed

=item 2 - the nodes depth (this allows you to selectively display elements at a certain depth) 

=item 3 - the path to the reference from the start of the dump.

=item 4 - an array reference containing the keys to be displayed (see filter chaining below) last argument can be undefined and can then
be safely ignored.

=item 5 - the dumpers setup

=back

The filter returns the node's type, an eventual new structure (see below) and a list of 'keys' to display. The keys are hash keys or array indexes.


In Perl:

  ($tree_type, $replacement_tree, @nodes_to_display) = $your_filter->($tree, $level, $path, $nodes_to_display, $setup) ;

Filter are not as complicated as they sound and they are very powerfull, 
especially when using the path argument.  The path idea was given to me by 
another module writer but I forgot whom. If this writer will contact me, I 
will give him the proper credit.

Lots of examples can be found in I<filters.pl> and I'll be glad to help if 
you want to develop a specific filter.

=head3 Key removal

Entries can be removed from the display by not returning their keys.

  my $s = {visible => '', also_visible => '', not_visible => ''} ;
  my $OnlyVisible = sub
  	{
  	my $s = shift ;
  	
	if('HASH' eq ref $s)
  		{
  		return('HASH', undef, grep {! /^not_visible/} keys %$s) ;
  		}
  		
  	return(Data::TreeDumper::DefaultNodesToDisplay($s)) ;
  	}
  	
  DumpTree($s, 'title', FILTER => $OnlyVisible) ;

=head3 Label changing

The label for a hash keys or an array index can be altered. This can be used to add visual information to the tree dump. Instead 
of returning the key name, return an array reference containing the key name and the label you want to display.
You only need to return such a reference for the entries you want to change, thus a mix of scalars and array ref is acceptable.

  sub StarOnA
  {
  # hash entries matching /^a/i have '*' prepended
  
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

  print DumpTree($s, "Entries matching /^a/i have '*' prepended", FILTER => \&StarOnA) ;

If you use an ANSI terminal, you can also change the color of the label. 
This can greatly improve visual search time.
See the I<label coloring> example in I<colors.pl>.

=head3 Structure replacement

It is possible to replace the whole data structure in a filter. This comes handy when you want to display a I<"worked">
version of the structure. You can even change the type of the data structure, for example changing an array to a hash.

  sub ReplaceArray
  {
  # replace arrays with hashes!!!
  
  my $tree = shift ;
  
  if('ARRAY' eq ref $tree)
  	{
	my $multiplication = $tree->[0] * $tree->[1] ;
	my $replacement = {MULTIPLICATION => $multiplication} ;
  	return('HASH', $replacement, keys %$replacement) ;
  	}
  	
  return (Data::TreeDumper::DefaultNodesToDisplay($tree)) ;
  }

  print DumpTree($s, 'replace arrays with hashes!', FILTER => \&ReplaceArray) ;

Here is a real life replacement. B<Tree::Simple> L<http://search.cpan.org/dist/Tree-Simple/> allows one
to build tree structures. The child nodes are not directly in the parent object (hash). Here is an unfiltered
dump of a tree with seven nodes:

  Tree::Simple through Data::TreeDumper
  |- _children
  |  |- 0
  |  |  |- _children
  |  |  |  `- 0
  |  |  |     |- _children
  |  |  |     |- _depth = 1
  |  |  |     |- _node = 1.1
  |  |  |     `- _parent
  |  |  |- _depth = 0
  |  |  |- _node = 1
  |  |  `- _parent
  |  |- 1
  |  |  |- _children
  |  |  |  |- 0
  |  |  |  |  |- _children
  |  |  |  |  |- _depth = 1
  |  |  |  |  |- _node = 2.1
  |  |  |  |  `- _parent
  |  |  |  |- 1
  |  |  |  |  |- _children
  |  |  |  |  |- _depth = 1
  |  |  |  |  |- _node = 2.1a
  |  |  |  |  `- _parent
  |  |  |  `- 2
  |  |  |     |- _children
  |  |  |     |- _depth = 1
  |  |  |     |- _node = 2.2
  |  |  |     `- _parent
  |  |  |- _depth = 0
  |  |  |- _node = 2
  |  |  `- _parent
  |  `- 2
  |     |- _children
  |     |- _depth = 0
  |     |- _node = 3
  |     `- _parent
  |- _depth = -1
  |- _node = 0
  `- _parent = root

This is nice for the developer but not for a user wanting to oversee the node hierarchy. One of the
possible filters would be:

  FILTER => sub
  		{
  		my $s = shift ;
  		
  		if('Tree::Simple' eq ref $s)	
  			{
  			my $counter = 0 ;
  			
  			return
  				(
  				'ARRAY'
  				, $s->{_children}
  				, map{[$counter++, $_->{_node}]} @{$s->{_children}} # index generation
  				) ;
  			}
  			
  		return(Data::TreeDumper::DefaultNodesToDisplay($s)) ;
  		}

Which would give this much more readable output:

  Tree::Simple through Data::TreeDumper2
  |- 1
  |  `- 1.1
  |- 2
  |  |- 2.1
  |  |- 2.1a
  |  `- 2.2
  `- 3

What about counting the children nodes? The index generating code becomes:

  map{[$counter++, "$_->{_node} [" . @{$_->{_children}} . "]"]} @{$s->{_children}}
 
  Tree::Simple through Data::TreeDumper4
  |- 1 [1]
  |  `- 1.1 [0]
  |- 2 [3]
  |  |- 2.1 [0]
  |  |- 2.1a [0]
  |  `- 2.2 [0]
  `- 3 [0]

=head3 Filter chaining

It is possible to chain filters. I<CreateChainingFilter> takes a list of filtering sub references.
The filters must properly handle the third parameter passed to them.

Suppose you want to chain a filter that adds a star before each hash key label, with a filter 
that removes all (original) keys that match /^a/i.

  sub AddStar
  	{
  	my $s = shift ;
  	my $level = shift ;
  	my $path = shift ;
  	my $keys = shift ;
  
  	if('HASH' eq ref $s)
  		{
  		$keys = [keys %$s] unless defined $keys ;
  		
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
  		
  	return(Data::TreeDumper::DefaultNodesToDisplay($s)) ;
  	} ;
  	
  sub RemoveA
  	{
  	my $s = shift ;
  	my $level = shift ;
  	my $path = shift ;
  	my $keys = shift ;
  
  	if('HASH' eq ref $s)
  		{
  		$keys = [keys %$s] unless defined $keys ;
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
  		
  	return(Data::TreeDumper::DefaultNodesToDisplay($s)) ;
  	} ;
  
  DumpTree($s, 'Chained filters', FILTER => CreateChainingFilter(\&AddStar, \&RemoveA)) ;

=head2 level Filters

It is possible to define one filter for a specific level. If a filter for a specific level exists it is used
instead of the global filter.

LEVEL_FILTERS => {1 => \&FilterForLevelOne, 5 => \&FilterForLevelFive ... } ;

=head2 Using filters as iterators

You can iterate through your data structures and display data yourself, 
manipulate the data structure, or do a search. While iterating through the 
data structure, you can prune arbitrary branches to speedup processing.

  # this example counts the nodes in a tree (hash based)
  # a node is counted if it has a '__NAME' key
  # any field that starts with '__' is considered rivate and we prune so we don't recurse in it
  # anything that is not a hash (the part of the tree that interests us in this case) is pruned
  
  my $number_of_nodes_in_the_dependency_tree = 0 ;
  my $node_counter = sub 
                      {
                      my $tree = shift ;
		      if('HASH' eq ref $tree && exists $tree->{__NAME})
	                 {
			 $number_of_nodes_in_the_dependency_tree++ if($tree->{__NAME} !~ /^__/) ;
			 
	                 return('HASH', $tree, grep {! /^__/} keys %$tree) ; # prune to run faster
	                 }
                      else
	                 {
	                 return('SCALAR', 1) ; # prune
	                 }
                      } ;
		
  DumpTree($dependency_tree, '', NO_OUTPUT => 1, FILTER => $node_counter) ;


=head2 Start level

This configuration option controls whether the tree trunk is displayed or not.

START_LEVEL => 1:

  $tree:
  |- A [H1]
  |  |- a [H2]
  |  |- bbbbbb = CODE(0x8139fa0) [C3]
  |  |- c123 [C4 -> C3]
  |  `- d [R5]
  |     `- REF(0x8139fb8) [R5 -> C3]
  |- ARRAY [A6]
  |  |- 0 [S7] = elment_1
  |  |- 1 [S8] = element_2
  
START_LEVEL => 0:

  $tree:
  A [H1]
  |- a [H2]
  |- bbbbbb = CODE(0x8139fa0) [C3]
  |- c123 [C4 -> C3]
  `- d [R5]
     `- REF(0x8139fb8) [R5 -> C3]
  ARRAY [A6]
  |- 0 [S7] = elment_1
  |- 1 [S8] = element_2
  
=head2 ASCII vs ANSI

You can direct Data:TreeDumper to output ANSI codes instead of ASCII characters. The display 
will be much nicer but takes slightly longer (not significant for small data structures).

  USE_ASCII => 0 # will use ANSI codes instead

=head2 Maximum depth of the dump

Controls the depth beyond which which we don't recurse into a structure. Default is -1, which
means there is no maximum depth. This is useful to limit the amount of data displayed.

  MAX_DEPTH => 1 
	
=head2 Indentation

Every line of the tree dump will be appended with the value of I<INDENTATION>.

  INDENTATION => '   ' ;

=head1 Custom glyphs

You can  change the glyphs used by B<Data::TreeDumper>.

  DumpTree(\$s, 's', , GLYPHS => ['.  ', '.  ', '.  ', '.  ']) ;
  
  # output
  s
  .  REF(0x813da3c) [H1]
  .  .  A [H2]
  .  .  .  a [H3]
  .  .  .  b [H4]
  .  .  .  .  a = 0 [S5]
  .  .  .  .  b = 1 [S6]
  .  .  .  .  c [H7]
  .  .  .  .  .  a = 1 [S8]

Four glyphs must be given. They replace the standard glyphs ['|  ', '|- ', '`- ', '   ']. It is also possible to set
the package variable B<$Data::TreeDumper::Glyphs>. B<USE_ASCII> should be set, which it is by default.

=head1 Level numbering and tagging

Data:TreeDumper can prepend the level of the current line to the tree glyphs. This can be very useful when
searching in tree dump either visually or with a pager.

  NUMBER_LEVELS => 2
  NUMBER_LEVELS => \&NumberingSub

NUMBER_LEVELS can be assigned a number or a sub reference. When assigned a number, Data::TreeDumper will use that value to 
define the width of the field where the level is displayed. For more control, you can define a sub that returns a string to be displayed
on the left side of the tree glyphs. The example below tags all the nodes whose level is zero.

  print DumpTree($s, "Level numbering", NUMBER_LEVELS => 2) ;

  sub GetLevelTagger
  {
  my $level_to_tag = shift ;
  
  sub 
  	{
  	my ($element, $level, $setup) = @_ ;
  	
  	my $tag = "Level $level_to_tag => ";
  	
  	if($level == 0) 
  		{
  		return($tag) ;
  		}
  	else
  		{
  		return(' ' x length($tag)) ;
  		}
  	} ;
  }
  
  print DumpTree($s, "Level tagging", NUMBER_LEVELS => GetLevelTagger(0)) ;

=head1 Level coloring

Another way to enhance the output for easier searching is to colorize it. Data::TreeDumper can colorize the glyph elements or whole levels.
If your terminal supports ANSI codes, using Term::ANSIColors and Data::TreeDumper together can greatly ease the reading of large dumps.
See the examples in color.pl. 

  COLOR_LEVELS => [\@color_codes, $reset_code]

When passed an array reference, the first element is an array containing coloring codes. The codes are indexed
with the node level modulo the size of the array. The second element is used to reset the color after the glyph is displayed. If the second 
element is an empty string, the glyph and the rest of the level is colorized.

  COLOR_LEVELS => \&LevelColoringSub

If COLOR_LEVEL is assigned a sub, the sub is called for each glyph element. It is passed the following elements:

=over 2

=item 1 - the nodes depth (this allows you to selectively display elements at a certain depth) 

=back

It should return a coloring code and a reset code. If you return an
empty string for the reset code, the whole node is displayed using the last glyph element color.

If level numbering is on, it is also colorized.

=head1 Wrapping

B<Data::TreeDumper> uses the Text::Wrap module to wrap your data to fit your display. Entries can be
wrapped multiple times so they snuggly fit your screen.

  |  |        |- 1 [S21] = 1
  |  |        `- 2 [S22] = 2
  |  `- 3 [O23 -> R17]
  |- ARRAY_ZERO [A24]
  |- B [S25] = scalar
  |- Long_name Long_name Long_name Long_name Long_name Long_name 
  |    Long_name Long_name Long_name Long_name Long_name Long_name
  |    Long_name Long_name Long_name Long_name Long_name [S26] = 0

=head1 Custom Rendering

B<Data::TreeDumper> has a plug-in interface for other rendering formats. The renderer callbacks are
set by overriding the native renderer. Thanks to Stevan Little author of Tree::Simple::View for getting
B<Data::TreeDumper> on this track.

 DumpTree
  	(
  	  $s
  	, 'Tree'
  	, RENDERER =>
  		{
  		  BEGIN => \&RenderDhtmlBegin
  		, NODE  => \&RenderDhtmlNode
  		, END   => \&RenderDhtmlEnd
  		
  		# data needed by the renderer
  		, PREVIOUS_LEVEL => -1
  		, PREVIOUS_ADDRESS => 'ROOT'
  		}
  	) ;

=head2 Callbacks

=over 2

=item * {RENDERER}{BEGIN} is called before the traversal of the data structure starts. This allows you
to setup the document (ex:: html header).

=item * {RENDERER}{NODE} is called for each node in the data structure. The following arguments are 
passed to the callback

=over 4

=item 1 $element


=item 2 $level


=item 3 $is_terminal (whether a deeper structure will follow or not)


=item 4 $previous_level_separator (ASCII separators before this node)


=item 5 $separator (ASCII separator for this element)


=item 6 $element_name


=item 7 $element_value


=item 8 $dtd_address (address of the element, Ex: C12 or H34. Unique for each element)


=item 9 $address_field (address and link displayed by the native renderer)


=item 10 $perl_data (perl size and/or address if the dumper was set too generate them)


=item 11 $setup (the dumper's settings)


=back

=item * {RENDERER}{END} is called after the last node has been processed.

=item * {RENDERER}{ ... }Arguments to the renderer can be stores within the {RENDERER} hash.

=back

=head2 Renderer modules

Renderers should be defined in modules under B<Data::TreeDumper::Renderer> and should define a function
called I<GetRenderer>. I<GetRenderer> can be passed whatever arguments the developer whishes. It is
acceptable for the modules to also export a specifc sub.

  print DumpTree($s, 'Tree', Data::TreeDumper::Renderer::DHTML::GetRenderer()) ;
  or
  print DumpTree($s, 'Tree', GetDhtmlRenderer()) ;

If B<{RENDERER}> is set to a scalar, B<Data::TreeDumper> will load the 
specified module if it exists. I<GetRenderer> will be called without 
arguments.

  print DumpTree($s, 'Tree', RENDERER => 'DHTML') ;

If B<{RENDERER}{NAME}> is set to a scalar, B<Data::TreeDumper> will load the specified module if it exists. I<GetRenderer>
will be called without arguments. Arguments to the renderer can aither be passed to the GetRenderer sub or as elements in the {RENDERER} hash.

  print DumpTree($s, 'Tree', RENDERER => {NAME => 'DHTML', STYLE => \$style) ;


=head1 Zero width console

When no console exists, while redirecting to a file for example, Data::TreeDumper uses the variable
B<VIRTUAL_WIDTH> instead. Default is 120.

	VIRTUAL_WIDTH => 120 ;

=head1 OVERRIDE list

=over 2

=item * COLOR_LEVELS

=item * DISPLAY_ADDRESS 

=item * DISPLAY_PERL_SIZE

=item * DISPLAY_ROOT_ADDRESS 

=item * DISPLAY_PERL_ADDRESS

=item * FILTER 

=item * GLYPHS

=item * INDENTATION

=item * LEVEL_FILTERS

=item * MAX_DEPTH 

=item * NUMBER_LEVELS 

=item * QUOTE_HASH_KEYS

=item * START_LEVEL 

=item * USE_ASCII 

=item * VIRTUAL_WIDTH 

=item * NO_OUTPUT

=back

=head1 Interface

=head2 Package Data (� la Data::Dumper (as is the silly naming scheme))

=head3 Configuration Variables

  $Data::TreeDumper::Startlevel           = 1 ;
  $Data::TreeDumper::Useascii             = 1 ;
  $Data::TreeDumper::Maxdepth             = -1 ;
  $Data::TreeDumper::Indentation          = '' ;
  $Data::TreeDumper::Virtualwidth         = 120 ;
  $Data::TreeDumper::Displayrootaddress   = 0 ;
  $Data::TreeDumper::Displayaddress       = 1 ;
  $Data::TreeDumper::DisplayObjectType    = 1 ;
  $Data::TreeDumper::Displayperlsize      = 0 ;
  $Data::TreeDumper::Displayperladdress   = 0 ;
  $Data::TreeDumper::Filter               = \&FlipEverySecondOne ;
  $Data::TreeDumper::Levelfilters         = {1 => \&Filter_1, 5 => \&Filter_5} ;
  $Data::TreeDumper::Numberlevels         = 0 ;
  $Data::TreeDumper::Glyphs               = ['|  ', '|- ', '`- ', '   '] ; 
  $Data::TreeDumper::Colorlevels          = undef ;
  $Data::TreeDumper::Nooutput             = 0 ; # generate an output
  $Data::TreeDumper::Quotehashkeys        = 0 ;

=head3 API

B<DumpTree> uses the configuration variables defined above. It takes the following arguments:

=over 2

=item [1] structure_to_dump, this must be a reference

=item [2] title, a string to prepended to the tree (optional)

=item [3] overrides (optional)
	
=back

  print DumpTree($s, "title", MAX_DEPTH => 1) ;

B<DumpTrees> uses the configuration variables defined above. It takes the following arguments

=over 2

=item [1] One or more array references containing

=over 4

=item [a] structure_to_dump, this must be a reference

=item [b] title, a string to prepended to the tree (optional)

=item [c] overrides (optional)
	
=back

=item [2] overrides (optional)

=back

  print DumpTrees
	  (
	    [$s, "title", MAX_DEPTH => 1]
	  , [$s2, "other_title", DISPLAY_ADDRESS => 0]
	  , USE_ASCII => 1
	  , MAX_DEPTH => 5
	  ) ;

=head1 Bugs

None that I know of in this release but plenty, lurking in the dark 
corners, waiting to be found.

=head1 Examples

Four examples files are included in the distribution.

I<usage.pl> shows you how you can use B<Data::TreeDumper>.

I<filters.pl> shows you how you how to do advance filtering.

I<colors.pl> shows you how you how to colorize a dump.

I<try_it.pl> is meant as a scratch pad for you to try B<Data::TreeDumper>.

=head1 DEPENDENCY

Optional B<Devel::Size> if you want Data::TreeDumper to show perl sizes for the tree elements.

=head1 EXPORT

I<DumpTree>, I<DumpTrees> and  I<CreateChainingFilter>.

=head1 AUTHOR

Khemir Nadim ibn Hamouda. <nadim@khemir.net>

Thanks to Ed Avis for showing interest and pushing me to re-write the documentation.

  Copyright (c) 2003 Nadim Ibn Hamouda el Khemir. All rights
  reserved.  This program is free software; you can redis-
  tribute it and/or modify it under the same terms as Perl
  itself.
  
If you find any value in this module, mail me!  All hints, tips, flames and wishes
are welcome at <nadim@khemir.net>.

=head1 SEE ALSO

B<Data::TreeDumper::00>.
B<Data::Dumper>.
B<Devel::Size::Report>.
B<Devel::Size>.

B<PBS>: the Perl Build System from which B<Data::TreeDumper> was extracted. Contact the author
for more information about B<PBS>.

=cut

