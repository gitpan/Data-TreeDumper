
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
	'all' => [ qw(TreeDumper) ]
	) ;

our @EXPORT_OK = ( @{$EXPORT_TAGS{'all'} } ) ;

our @EXPORT = qw(DumpTree DumpTrees CreateChainingFilter);
our $VERSION = '0.11' ;

use Term::Size;
use Text::Wrap  ;

#----------------------------------------------------------------------
# package variables à la Data::Dumper
#----------------------------------------------------------------------

our $Startlevel         = 1 ;
our $Useascii           = 1 ;
our $Maxdepth           = -1 ;
our $Indentation        = '' ;
our $Filter             = undef ;
our $Virtualwidth       = 120 ; 
our $Displayrootaddress = 0 ;
our $Displayaddress     = 1 ;
our $Numberlevels       = 0 ;
our $Colorlevels        = undef ;

#~ our $Deparse    = 0 ;  # not implemented 

sub DumpTree
{
my $structure_to_dump = shift ;
my $title             = shift ;
my %override          =  @_ ;

$title = defined $title ? $title : '' ;

return 
	(
	Data::TreeDumper::TreeDumper
			(
			  $structure_to_dump
			, {
			    FILTER               => $Filter
			  , START_LEVEL          => $Startlevel
			  , USE_ASCII            => $Useascii
			  , MAX_DEPTH            => $Maxdepth
			  , INDENTATION          => $Indentation
			  , TITLE                => $title
			  , VIRTUAL_WIDTH        => $Virtualwidth
			  , DISPLAY_ROOT_ADDRESS => $Displayrootaddress
			  , DISPLAY_ADDRESS      => $Displayaddress
			  , NUMBER_LEVELS        => $Numberlevels
			  , COLOR_LEVELS         => $Colorlevels
			  , %override
			  }
			)
	) ;
}

sub DumpTrees
{
my @trees           = grep {'ARRAY' eq ref $_} @_ ;
my %global_override = grep {'ARRAY' ne ref $_} @_ ;

my $dump = '' ;

for my $tree (@trees)
	{
	my ($structure_to_dump, $title, %override) = @{$tree} ;
	
	$dump .= DumpTree($structure_to_dump, $title, %global_override, %override) ;
	}
	
return($dump) ;
}

#----------------------------------------------------------------------
# OO interface
#----------------------------------------------------------------------

sub new 
{
my($class, @setup_data) = @_;

my($self) = 
	{
	  FILTER               => undef
	, START_LEVEL          => 1
	, USE_ASCII            => 1
	, MAX_DEPTH            => -1
	, INDENTATION          => '' 
	, VIRTUAL_WIDTH        => 120
	, DISPLAY_ROOT_ADDRESS => 0
	, DISPLAY_ADDRESS      => 1
	, NUMBER_LEVELS        => undef
	, COLOR_LEVELS         => undef
	, @setup_data
	};

return bless($self, $class);
}

sub SetFilter
{
my($self, $filter) = @_;

croak "Filter must be a code reference!" unless ('CODE' eq ref $filter) ;

$self->{FILTER} = $filter;
}

sub SetStartLevel
{
my($self, $start_level) = @_ ;
$self->{START_LEVEL} = $start_level;
}

sub UseAscii
{
my($self, $use_ascii) = @_ ;
$self->{USE_ASCII} = $use_ascii;
}

sub UseAnsi
{
my($self, $use_ansi) = @_ ;
$self->{USE_ASCII} = (!$use_ansi) ;
}

sub SetMaxDepth
{
my($self, $max_depth) = @_ ;
$self->{MAX_DEPTH} = $max_depth ;
}

sub SetIndentation
{
my($self, $indentation) = @_ ;
$self->{INDENTATION} = $indentation ;
}

sub SetVirtualWidth
{
my($self, $width) = @_ ;
$self->{VIRTUAL_WIDTH} = $width ;
}

sub DisplayRootAddress
{
my($self, $display_root_address) = @_ ;
$self->{DISPLAY_ROOT_ADDRESS} = $display_root_address ;
}

sub DisplayAddress
{
my($self, $display_address) = @_ ;
$self->{DISPLAY_ADDRESS} = $display_address ;
}

sub NumberLevels
{
my($self, $number_levels) = @_ ;
$self->{NUMBER_LEVELS} = $number_levels;
}

sub ColorLevels
{
my($self, $color_levels) = @_ ;
$self->{COLOR_LEVELS} = $color_levels ;
}

sub Dump
{
my($self, $structure_to_dump, $title, %override) = @_;

$title = defined $title ? $title : '' ;

return
	(
	Data::TreeDumper::TreeDumper
			(
			  $structure_to_dump
			, {
			    FILTER               => $self->{FILTER}
			  , START_LEVEL          => $self->{START_LEVEL}
			  , USE_ASCII            => $self->{USE_ASCII}
			  , MAX_DEPTH            => $self->{MAX_DEPTH}
			  , INDENTATION          => $self->{INDENTATION}
			  , VIRTUAL_WIDTH        => $self->{VIRTUAL_WIDTH}
			  , DISPLAY_ROOT_ADDRESS => $self->{DISPLAY_ROOT_ADDRESS}
			  , DISPLAY_ADDRESS      => $self->{DISPLAY_ADDRESS}
			  , NUMBER_LEVELS        => $self->{NUMBER_LEVELS}
			  , COLOR_LEVELS         => $self->{COLOR_LEVELS}
			  , TITLE                => $title
			  , %override
			  }
			)
	) ;
}

sub DumpMany
{
my $self = shift ;

my @trees           = grep {'ARRAY' eq ref $_} @_ ;
my %global_override = grep {'ARRAY' ne ref $_} @_ ;

my $dump = '' ;

for my $tree (@trees)
	{
	my ($structure_to_dump, $title, %override) = @{$tree} ;
	
	$dump .= $self->Dump($structure_to_dump, $title, %global_override, %override) ;
	}

return($dump) ;
}

#-------------------------------------------------------------------------------
# The dumper, argument based
#-------------------------------------------------------------------------------

sub TreeDumper
{
my $tree             = shift ;
my $setup            = shift ;
my $level            = shift || 0 ;
my $levels_left      = shift || [] ;

my $tree_type = ref $tree ;

confess "TreeDumper can only display objects passed by reference!\n" if('' eq  $tree_type) ;

my $filter_sub           = $setup->{FILTER} ;
my $start_level          = $setup->{START_LEVEL} ;
my $use_ascii            = $setup->{USE_ASCII} ;
my $max_depth            = $setup->{MAX_DEPTH} ;
my $indentation          = $setup->{INDENTATION} ;
my $virtual_width        = $setup->{VIRTUAL_WIDTH} ;
my $display_root_address = $setup->{DISPLAY_ROOT_ADDRESS} ;
my $display_address      = $setup->{DISPLAY_ADDRESS} ;
my $number_levels        = $setup->{NUMBER_LEVELS} ;
my $color_levels         = $setup->{COLOR_LEVELS} ;

$start_level = 0   unless defined $start_level ;
$use_ascii   = 1   unless defined $use_ascii ;
$max_depth   = -1  unless defined $max_depth ;
$indentation = ''  unless defined $indentation ;
$virtual_width = 120 unless defined $virtual_width ;
$display_root_address = 0 unless defined $display_root_address ;
$display_address = 1 unless defined $display_address ;

return('') if ($max_depth == $level) ;

# used in the recursive call
my $already_displayed_nodes = shift || {$tree => GetReferenceType($tree) . '0', NEXT_INDEX => 1} ;

# filters
my ($replacement_tree, $nodes_to_display) ;

if(defined $filter_sub)
	{
	($tree_type, $replacement_tree, @$nodes_to_display) = $filter_sub->($tree, $level, $nodes_to_display, $setup) ;
	$tree = $replacement_tree if(defined $replacement_tree) ;
	}
else
	{
	($tree_type, undef, @$nodes_to_display) = DefaultNodesToDisplay($tree, $level) ;
	}
	
return('') unless defined $tree_type ;

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

# wrapping	
my ($columns, $rows) = Term::Size::chars *STDOUT{IO} ;

$columns = $virtual_width if $columns eq '' ;

local $Text::Wrap::columns  = $columns ;
local $Text::Wrap::unexpand = 0 ;

my $output = '' ;
for (my $nodes_left = $#nodes_to_display ; $nodes_left >= 0 ; $nodes_left--)
	{
	my 
		(
		  $previous_level_separator
		, $separator
		, $subsequent_separator
		, $separator_size
		) = GetSeparator
				(
				  $level
				, $nodes_left
				, $levels_left
				, $start_level
				, $color_levels
				) ;
				
	$levels_left->[$level] = $nodes_left ;
	
	my $node_index = $#nodes_to_display - $nodes_left ;
	
	my ($element, $element_name, $element_ref) ;
	for($tree_type)
		{
		'HASH' eq $_ and do
			{
			$element = $tree->{$nodes_to_display[$node_index]} ;
			$element_name = $node_names[$node_index] ;
			$element_ref = \($tree->{$nodes_to_display[$node_index]}) ;
			last
			} ;
		
		'ARRAY' eq $_ and do
			{
			$element = $tree->[$nodes_to_display[$node_index]] ;
			$element_name = $node_names[$node_index] ;
			$element_ref = \($tree->[$nodes_to_display[$node_index]]) ;
			last ;
			} ;
			
		'REF' eq $_ and do
			{
			$element = $$tree ;
			$element_name = "$tree" ;
			$element_ref = $tree ;
			last ;
			} ;
			
		'CODE' eq $_ and do
			{
			$element = $tree ;
			$element_name = "$tree" ;
			$element_ref = "code_$tree" ;
			last ;
			} ;
			
		'SCALAR' eq $_ and do
			{
			$element = $$tree ;
			$element_name = '?' ;
			$element_ref = "element_$tree" ;
			last ;
			} ;
			
		#?object
		#?glob
		}
		
	# All recursive calls are made with the same arguments
	my @recursion_args =
			(
			  $element
			, $setup
			, $level + 1
			, $levels_left
			, $already_displayed_nodes
			) ;
			
	my $level_text = '' ;
	if($number_levels)
		{
		if('CODE' eq ref $number_levels)
			{
			$level_text = $number_levels->($element, $level, $setup) ;
			}
		else
			{
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
			$level_text = sprintf("$color_start%${number_levels}d$color_end ", ($level + 1)) ;
			}
		}
		
	my $tree_header            = $indentation . $level_text . $previous_level_separator . $separator  ;
	my $tree_subsequent_header = $indentation . $level_text . $previous_level_separator . $subsequent_separator ;
	
		
	for(ref $element)
		{
		'' eq $_ and do
			{
			my $value = defined $element ? $element : 'undef' ;
			
			$already_displayed_nodes->{$element_ref} = 'S' . $already_displayed_nodes->{NEXT_INDEX} ;
			$already_displayed_nodes->{NEXT_INDEX}++ ;
			
			my $address = '' ;
			$address = "[$already_displayed_nodes->{$element_ref}] " if $display_address ;
			
			$output .= wrap
						(
						  $tree_header
						, $tree_subsequent_header . '  '
						, "$element_name $address= " . $value
						) ;
			$output .= "\n" ;
			
			last
			} ;
			
		'CODE' eq $_ and do 
			{
			$output .= HeaderAndSubTree
							(
							  $tree_header, $tree_subsequent_header
							, $element, $element_ref, $element_name
							, $element_name . " = $element"
							, 'C'
							, $already_displayed_nodes
							, $display_address
							) ;
			last ;
			} ;
			
		'HASH' eq $_ and do
			{
			$output .= HeaderAndSubTree
							(
							  $tree_header, $tree_subsequent_header
							, $element, $element_ref, $element_name, $element_name, 'H'
							, $already_displayed_nodes
							, $display_address
							, @recursion_args
							) ;
			last ;
			} ;
			
		'ARRAY' eq $_ and do
			{
			$output .= HeaderAndSubTree
							(
							  $tree_header, $tree_subsequent_header
							, $element, $element_ref, $element_name, $element_name, 'A'
							, $already_displayed_nodes
							, $display_address
							, @recursion_args
							) ;
			last ;
			} ;
			
		'SCALAR' eq $_ and do
			{
			$output .= HeaderAndSubTree
							(
							  $tree_header, $tree_subsequent_header
							, $element, $element_ref, $element_name, $element_name, 'RS'
							, $already_displayed_nodes
							, $display_address
							, @recursion_args
							) ;
			last ;
			} ;
			
		'GLOB' eq $_ and do
			{
			$output .= $tree_header . $element_name . " = GLOB ($element)\n" ;
			last ;	
			} ;
			
		'REF' eq $_ and do
			{
			$output .= HeaderAndSubTree
							(
							  $tree_header, $tree_subsequent_header
							, $element, $element_ref, $element_name, $element_name, 'R'
							, $already_displayed_nodes
							, $display_address
							, @recursion_args
							) ;
			last ;
			} ;
			
		# DEFAULT, an object.
		$output .= HeaderAndSubTree
						(
						  $tree_header, $tree_subsequent_header
						, $element, $element_ref, $element_name
						, $element_name . " = Object of type '" . ref($element) . "'"
						, 'O'
						, $already_displayed_nodes
						, $display_address
						, @recursion_args
						) ;
		}
	}
	
if($level == 0)
	{
	my $title = defined $setup->{TITLE} ? $setup->{TITLE} : '' ;
	
	if($display_root_address)
		{
		$title .= '[' . GetReferenceType($tree) . "0]\n" ;
		}
	else
		{
		$title .= "\n" ;
		}
	
	my $indentation = defined $setup->{INDENTATION} ? $setup->{INDENTATION} : '' ;
	if($use_ascii)
		{
		return($indentation . $title . $output) ;
		}
	else
		{
		return($indentation . $title . ConvertToAnsi(\$output)) ;
		}
	}
else
	{
	return($output) ;
	}
}

#-------------------------------------------------------------------------------

sub GetReferenceType
{
my $object = shift ;
my $reference = ref $object;

my %type =
	(
	  '' => 'SCALAR! not a reference!'
	, 'REF' => 'R'
	, 'CODE' => 'C'
	, 'HASH' => 'H'
	, 'ARRAY' => 'A'
	, 'SCALAR' => 'RS'
	) ;
	
if(exists $type{$reference})
	{
	return($type{$reference}) ;
	}
else
	{
	return('O') ;
	}
}

#-------------------------------------------------------------------------------

sub HeaderAndSubTree
{
my 
	(
	  $tree_header, $tree_subsequent_header
	, $element, $element_ref, $element_name, $element_header, $type
	, $already_displayed_nodes
	, $display_address
	, @recursion_args
	) = @_ ;
	
$already_displayed_nodes->{$element_ref} = $type . $already_displayed_nodes->{NEXT_INDEX} ;
$already_displayed_nodes->{NEXT_INDEX}++ ;
	
my $address = $already_displayed_nodes->{$element_ref} ;
my $output = '' ;
		
if(exists $already_displayed_nodes->{$element})
	{
	my $element_address = '' ;
	$element_address = " [$address -> $already_displayed_nodes->{$element}]" if $display_address ;
	
	$output .= wrap
				(
				  $tree_header
				, $tree_subsequent_header
				, $element_name . $element_address . "\n"
				) ;
	}
else	
	{
	$already_displayed_nodes->{$element} = $address ;
	
	my $element_address = '' ;
	$element_address = " [$address]" if $display_address ;
	
	$output .= wrap
				(
				  $tree_header 
				, $tree_subsequent_header 
				, $element_header . $element_address . "\n"
				) ;
				
	$output .= TreeDumper(@recursion_args) if @recursion_args ;
	}

return($output) ;
}

#----------------------------------------------------------------------
#  filters
#----------------------------------------------------------------------

sub DefaultNodesToDisplay
{
my $tree = shift ;

my $tree_type = ref $tree ;
my $level = shift ; # not used by this sub
my $keys = shift ;

if('HASH' eq $tree_type)
	{
	return('HASH', undef, sort keys %$tree) unless(defined $keys) ;
	return('HASH', undef, @$keys) ;
	}
	
if('ARRAY' eq $tree_type) 
	{
	return('ARRAY', undef, (0 .. @$tree - 1)) unless(defined $keys) ;
	return('ARRAY', undef, @$keys) ;
	}

return('REF', undef, (0))                 if('REF'     eq $tree_type) ;
return('CODE', undef, (0))                if('CODE'    eq $tree_type) ;
return('SCALAR', undef, (0))              if('SCALAR'  eq $tree_type) ;

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
		undef $tree_type ;
		}
	}

return($tree_type, undef, @nodes_to_display) ;
}

#-------------------------------------------------------------------------------

sub HashKeysSorter
{
my $structure_to_dump = shift ;
my $level = shift ; # not used by this sub
my $keys = shift ;

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
	my $keys = shift ;
	
	my ($tree_type, $replacement_tree);
	
	for my $filter (@filters)
		{
		($tree_type, $replacement_tree, @$keys) = $filter->($tree, $level, $keys) ;
		$tree = $replacement_tree if (defined $replacement_tree) ;
		}
		
	return ($tree_type, $replacement_tree, @$keys) ;
	}
} ;

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
		$previous_level_separator .= "$color_start   $color_end" ;
		}
	else
		{
		$previous_level_separator .= "$color_start|  $color_end" ;
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
		$separator            = "$color_start`- $color_end" ;
		$subsequent_separator = "$color_start   $color_end" ;
		}
	else
		{
		$separator            = "$color_start|- $color_end" ;
		$subsequent_separator = "$color_start|  $color_end"  ;
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

sub ConvertToAnsi
{
my $string_ref = shift ;

$$string_ref =~ s/\|  /\033(0\170  \033(B/g ;
$$string_ref =~ s/\|- /\033(0\164\161 \033(B/g ;
$$string_ref =~ s/\`- /\033(0\155\161 \033(B/g ;

return($$string_ref) ;
}

#----------------------------------------------------------------------
1 ;

__END__
=head1 NAME

Data::TreeDumper - dumps a data structure in a tree fashion.

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
  
  #-------------------------------------------------------------------
  # OO interface
  #-------------------------------------------------------------------
  
  my $dumper = new Data::TreeDumper() ;
  $dumper->UseAnsi(1) ;
  $dumper->Maxdepth(2) ;
  $dumper->Filter(\&Data::TreeDumper::HashKeysSorter) ;
  
  print $dumper->Dump($s, "Using OO interface") ;
  print $dumper->DumpMany
	  (
	    [$s, "title", MAX_DEPTH => 1]
	  , [$s2, "other_title", DISPLAY_ADDRESS => 0]
	  , USE_ASCII => 1
	  , MAX_DEPTH => 5
	  ) ;
   
  #-------------------------------------------------------------------
  # native interface
  #-------------------------------------------------------------------
  
  print Data::TreeDumper::TreeDumper
  	(
  	  $s
  	, {
  	    FILTER      => \&Data::TreeDumper::HashKeysSorter
  	  , START_LEVEL => 1
  	  , USE_ASCII   => 0
  	  , MAX_DEPTH   => 2
  	  , TITLE       => "Using Native interface\n"
  	  }
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

Data::Dumper and other modules do a great job at dumping data structure but their output sometime takes more
brain to understand than it takes to understand the data itself. When dumping big amounts of data, the output
is overwhelming and it's difficult to see the relationship between each piece of the dumped data.

Data::TreeDumper dumps data in a trees like fashion I<hopping> for the output to be easier on the beholder's eye 
and brain. But it might as well be the opposite!

=head2 Label

Each node in the tree has a label. The label contains a type and an address . The label is displayed to
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
generates. How to set the options depends on which L<Interface> you use and is explained bellow.
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

When the dumped data are not self referential, displaying the address of each node clutters the display. You can
direct B<Data::TreeDumper> to not display the node address by using:

  DISPLAY_ADDRESS => 0

=head2 Filters

Data::TreeDumper can sort the tree nodes with a user defined sub.

  FILTER => \&ReverseSort
  FILTER => \&Data::TreeDumper::HashKeysSorter

The filter sub is passed three arguments, a reference to the node which is going to be displayed,
it's depth (this allows you to selectively display elements at a certain depth) and an array reference
containing the keys to be displayed (see filter chaining bellow) last argument can be undefined and can then
be safely ignored.

The filter returns the node's type, an eventual new structure (see bellow) and a list of 'keys' to display.
The keys are hash keys or array indexes.

If you set FILTER to \&Data::TreeDumper::HashKeysSorter, hashes will be sorted in alphabetic order.

=head3 Key removal

Entries can be removed by not returning their keys.

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
for returning the key name, return an array reference containing the key name and the label you want to display.
You only need to return such a reference for the entries you want to change thus a mix of scalars and array ref is acceptable.

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

If you use an ansi terminal, you can also change the color of the label, this can greatly improve visual search time.
See the I<label coloring> example in I<colors.pl>.

=head3 Structure replacement

It is possible to replace the whole data structure in a filter. This comes handy when you want to display a 'worked'
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

=head3 filter chaining

It is possible to chain filters. B<Data::TreeDumper> exports I<CreateChainingFilter>. I<CreateChainingFilter>
takes a list of filtering sub references. The filters must properly handle the third parameter passed to them.

Suppose you want to chain a filter, that adds a star before each hash key label, with a filter 
that removes all (original) keys that match /^a/i.

  sub AddStar
  	{
  	my $s = shift ;
  	my $level = shift ;
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

You can direct Data:TreeDumper to output ANSI codes instead for ASCII characters. The display 
will be much nicer but takes slightly longer time (not significant for small data structures).

  USE_ASCII => 0 # will use ANSI codes instead

=head2 Maximum depth of the dump

Controls the depth beyond which which we don't recurse into a structure. Default is -1, which
means there is no maximum depth. This is useful to limit the amount of data displayed.

  MAX_DEPTH => 1 
	
=head2 Indentation

Every line of the tree dump will be appended with the value of I<INDENTATION>.

  INDENTATION => '   ' ;

=head1 Level numbering and tagging

Data:TreeDumper can prepend the level of the current line to the tree glyphs. This can be very useful when
searching in tree dump either visually or with a pager.

  NUMBER_LEVELS => 2
  NUMBER_LEVELS => \&NumberingSub

NUMBER_LEVELS can be assigned a number or a sub reference. When assigned a number, Data::TreeDumper will use that value to 
define the width of the field where the level is displayed. For more control, you can define a sub that returns a string to be displayed
on the left side of the tree glyphs. The example bellow tags all the nodes which level is zero.

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

If COLOR_LEVEL is assigned a sub, the sub is called for each glyph element. It should return a coloring code and a reset code. If you return an
empty string for the reset code, the whole node is displayed using the last glyph element color.

If level numbering is on, it is also colorized.

=head1 Wrapping

Data::TreeDumper uses the Text::Wrap module to wrap your data to fit your display. Entries can be
wrapped multiple times so they snuggly fit your screen.

  |  |        |- 1 [S21] = 1
  |  |        `- 2 [S22] = 2
  |  `- 3 [O23 -> R17]
  |- ARRAY_ZERO [A24]
  |- B [S25] = scalar
  |- Long_name Long_name Long_name Long_name Long_name Long_name 
  |    Long_name Long_name Long_name Long_name Long_name Long_name
  |    Long_name Long_name Long_name Long_name Long_name [S26] = 0

=head1 Zero width console

When no console exists, while redirecting to a file for example, Data::TreeDumper uses the variable
B<VIRTUAL_WIDTH> instead. Default is 120.

	VIRTUAL_WIDTH => 120 ;

=head1 OVERRIDE list

=over 2

=item * COLOR_LEVELS

=item * DISPLAY_ADDRESS 

=item * DISPLAY_ROOT_ADDRESS 

=item * FILTER 

=item * INDENTATION 

=item * MAX_DEPTH 

=item * NUMBER_LEVELS 

=item * START_LEVEL 

=item * USE_ASCII 

=item * VIRTUAL_WIDTH 

=back

=head1 Interfaces

Data:TreeDumper has three interfaces. A 'package data' interface resembling Data::Dumper, an
object oriented interface and the native interface. All interfaces return a string containing the dump.

=head2 Package Data (à la Data::Dumper)

=head3 Configuration Variables

  $Data:TreeDumper::Startlevel         = 1 ;
  $Data:TreeDumper::Useascii           = 1 ;
  $Data:TreeDumper::Maxdepth           = -1 ;
  $Data:TreeDumper::Indentation        = '' ;
  $Data:TreeDumper::Virtualwidth       = 120 ;
  $Data:TreeDumper::Displayrootaddress = 0 ;
  $Data:TreeDumper::Displayaddress     = 1 ;
  $Data:TreeDumper::Filter             = \&FlipEverySecondOne ;
  $Data:TreeDumper::Numberlevels       = 0 ;
  $Data:TreeDumper::Colorlevels        = undef ;
  
=head3 Functions

B<DumpTree> uses the configuration variables defined above. It takes the following arguments

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

=head2 Object oriented Methods

  # constructor
  my $dumper = new Data::TreeDumper(MAX_DEPTH => 1) ;
  
  $dumper->UseAnsi(1) ;
  $dumper->UseAscii(1) ;
  $dumper->Maxdepth(2) ;
  $dumper->SetIndentation('   ') ;
  $dumper->SetVirtualWidth(80) ;
  $dumper->SetFilter(\&Data::TreeDumper::HashKeysSorter) ;
  $dumper->SetStartLevel(0) ;
  $dumper->DisplayRootAddress(1) ;
  $dumper->DisplayAddress(0) ;
  $dumper->NumberLevels(2) ;
  $dumper->ColorLevels(\&ColorLevelSub) ;
  
  $dumper->Dump($s, "Using OO interface", %OVERRIDES) ;
  $dumper->DumpMany
            (
	      [$s, "dump1", %OVERRIDES]
	    , [$s, "dump2", %OVERRIDES]
	    , %OVERRIDES
	    ) ;
  	
=head2 Native

  Data::TreeDumper::TreeDumper
  	(
  	  $s
  	, {
  	    FILTER               => \&Data::TreeDumper::HashKeysSorter
  	  , START_LEVEL          => 1
  	  , USE_ASCII            => 0
  	  , MAX_DEPTH            => 2
  	  , TITLE                => "Using Native interface"
  	  , DISPLAY_ROOT_ADDRESS => 0
  	  , DISPLAY_ADDRESS      => 1
	  , INDENTATION          => ''
	  , NUMBER_LEVELS        => 0
	  , COLOR_LEVELS         => undef
  	}
  	) ;
  
=head1 Bugs

None I know of in this release but plenty, lurking in the dark corners, waiting to be found.

=head1 Examples

Four examples files are included in the distribution.

I<usage.pl> shows you how you can use B<Data::TreeDumper>.

I<filters.pl> shows you how you how to do advance filtering.

I<colors.pl> shows you how you how to colorize a dump.

I<try_it.pl> is meant as a scratch pad for you to try B<Data::TreeDumper>.

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

The excellent B<Data::Dumper>.

B<PBS>: the Perl Build System from which B<Data::TreeDumper> was extracted. Contact the author
for more information about B<PBS>.

=cut

