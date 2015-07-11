#!/usr/bin/perl

use warnings;
use strict;
use Getopt::Long;
use File::Slurp;
use Term::ANSIColor;
use feature 'state';
use File::Basename;

my $counter;
my $current_file;
my $file_basename;
my $mistakes;
my $file_content;
my @globs;
my $blank_line;
my @function_names;
my $braces_depth;
my $function_loc;
my $user_include;
my $passed_include;

## TODO Check forbidden syscalls
## TODO Check malloc == NULL
## TODO Add option for choosing between building the project with the Makefile and check automatically
##      or just check *.c files
## TODO Once everything finished add options for ignoring checks
## TODO Comments aligned, first must be /* and after ** and the last */
## /*
##  ** Blabla
##  ** Blabla
## */
## TODO Variables must be aligned with function name
## TODO alignment must be done with tabs no spaces
## TODO Variables, macro, function, ... must be named correctly
## TODO no capital letters to variable's names, files and functions only lower case with _ character
## TODO everything in english
## TODO Defines/Macro must be in capital letters
## TODO structure = s_, typedef = t_, union = u_
## TODO One variable per line
## TODO one blank line between declaration variables and instructions
## TODO No additional blank line between function (only one)
## TODO Cannot assign and create variable at the same time
## TODO Count static number if too much print a warning
## TODO * must be on the variable not on the type
## TODO if () { => forbidden
##		something
##	}
## TODO Check if too many parameters in one structure
## TODO No space after the name of the function and '('
## TODO Space after a keyword, sizeof is an exception
## TODO #ifndef #ifdef #endif need comments /* ! MY_H_ */ if the header file is named my.h
## TODO No space after unary operator &/*/+/-
## TODO Makefile : $(NAME), clean, fclean, re, all are mandatory
## TODO Makefile : Check if makefile relink
## TODO Makefile : wildcard (*) usage is forbidden
## TODO Makefile : Check header 

sub print_color
{
    my $location_and_error = $file_basename.":".$counter.": ".$_[1]."\n";

    if ($_[0] == 1)
    {
	print colored($location_and_error, 'bold white');
    }
    elsif ($_[0] == 2)
    {
        print colored($location_and_error, 'bold yellow');
    }
    elsif ($_[0] == 3)
    {
        print colored($location_and_error, 'bold red');
    }
    else
    {
	print $_[1], "\n";
    }
}

sub help
{
}

sub include_c
{
    if ($passed_include == 0 && $_[0] !~ /^\s*?$/ && $_[0] !~ /^\s*?#\s*?include/)
    {
	$passed_include = 1;
    }
    if ($_[0] =~ /^\s*?#\s*?include/)
    {
	if ($passed_include == 1)
	{
	    print_color(3, "#include must be located at the top of the file");
	    $mistakes++;
	}
	if ($_[0] =~ /^\s*?#\s*?include\s*?\"/)
	{
	    $user_include = 1;
	}
	if ($user_include == 1 && $_[0] =~ /^\s*?#\s*?include\s*?\</)
	{
	    print_color(3, "System includes must be before user includes");
	    $mistakes++;
	}
    }
}

sub header
{
    my $user = substr `cat /etc/passwd | grep "/home/$ENV{'LOGNAME'}" | cut -d ':' -f 1`, 0, -1;
    my $fullname = substr `cat /etc/passwd | grep "/home/$ENV{'LOGNAME'}" | cut -d ':' -f 5 | cut -d ',' -f 1`, 0, -1;
    if ($_[0] ne "/*" ||
	$_[1] !~ /^\*\* $file_basename for .* in [^\s]*$/ ||
	$_[2] ne "** " ||
	$_[3] !~ /^\*\* Made by $fullname$/ ||
	$_[4] !~ /^\*\* Login   \<$user\@epitech\.net\>$/ ||
	$_[5] ne "** " ||
	$_[6] !~ /^\*\* Started on  [A-Za-z]{3} [A-Za-z]{3} [0-9]{2} [0-9]{2}\:[0-9]{2}\:[0-9]{2} [0-9]{4} $fullname$/ ||
	$_[7] !~ /^\*\* Last update [A-Za-z]{3} [A-Za-z]{3} [0-9]{2} [0-9]{2}\:[0-9]{2}\:[0-9]{2} [0-9]{4} $fullname$/ ||
	$_[8] ne "*/" ||
	$_[9] !~ /^\s*$/)
    {
	print_color(3, "Invalid header");
	$mistakes++;
    }
}

sub spaces
{
    if ($_[0] =~ /,[^ ]/)
    {
	print_color(3, "You need to add a whitespace after a coma");
	$mistakes++;
    }
    if ($_[0] =~ /.*\s$/)
    {
	print_color(3, "Space detected at the end of the line");
	$mistakes++;
    }
    if ($_[0] =~ /^\s*$/)
    {
	if ($blank_line > 0)
	{
	    print_color(3, "Too many blank lines");
	    $mistakes++;
	}
	if ($_[0] =~ /^\s+$/)
	{
	    print_color(3, "Blank line with spaces detected");
	    $mistakes++;
	}
	$blank_line++;
    }
    else
    {
	$blank_line = 0;
    }
    if ($_[0] =~ /[~\!]\s/ || $_[0] =~ /\s\+\+/ || $_[0] =~ /\s\-\-/ || $_[0] =~ /\s;/)
    {
	print_color(3, "No space after ~/! before ++/--/;");
	$mistakes++;
    }
    if ($_[0] =~ /if[^\s]/)
    {
	print_color(3, "Missing space after keyword");
	$mistakes++;
    }
    if ($braces_depth == 0 && $_[0] =~ /^\s+/)
    {
	print_color(3, "Spaces detected at the beginning of the line");
	$mistakes++;
    }
}

sub defines_c
{
    if ($_[0] =~ /#\s*?define\s*?(?:(?!_BSD_SOURCE|_XOPEN_SOURCE|_GNU_SOURCE|__STRICT_ANSI__|_POSIX_C_SOURCE|_POSIX_SOURCE|_XOPEN_SOURCE|_XOPEN_SOURCE_EXTENDED|_ISOC95_SOURCE|_ISOC99_SOURCE\|_ISOC11_SOURCE|_LARGEFILE64_SOURCE|_FILE_OFFSET_BITS|_BSD_SOURCE|_SVID_SOURCE|_ATFILE_SOURCE|_REENTRANT|_THREAD_SAFE|_FORTIFY_SOURCE).)*$/m)
    {
	print_color(3, "You're not allowed to add your own #define in C files");
	$mistakes++;
    }
    if ($_[0] =~ /#\s*?define\s*?.*\\/)
    {
	print_color(3, "You're not allowed to use multilines macro");
	$mistakes++;
    }
}

sub general_c
{
    if (`echo "quotemeta($_[0])" | wc -L` > 80)
    {
	print_color(3, "Column number exceeded, more than 80");
	$mistakes++;
    }
    if ($_[0] =~ /;/ > 1)
    {
	print_color(3, "Multiple statements on one line");
	$mistakes++;
    }
    if ($_[0] =~ /(if|else)\s*?\(.*\)\s*?\{?.*\}?;$/)
    {
	print_color(3, "Statement cannot be on one line with if/else/else if");
	$mistakes++;
    }
    if ($_[0] =~ /switch\s|for\s|goto\s/)
    {
	print_color(3, "Forbidden keyword");
	$mistakes++;
    }
    if ($_[0] =~ /.*return\s[^\(].*;/ ||
	$_[0] =~ /.*return\s\(.*[^\)];/)
    {
	print_color(3, "Return must have parenthesis");
	$mistakes++;
    }
    if ($_[0] =~ /;.+/)
    {
	print_color(3, "Something has been detected after a brace(;)");
	$mistakes++;
    }
}

sub comments_c
{
    if ($braces_depth > 0 && ($_[0] =~ /\/\*/ || $_[0] =~ /\/\//))
    {
	print_color(3, "Comments in function detected");
	$mistakes++;
    }    
}

sub ctags_forbidden_c
{
    if (length `ctags -x --c-kinds=pstug $current_file` > 0)
    {
	print_color(3, "Forbidden prototype, union, structure, typedef, enumeration declaration");
	$mistakes++;
    }
}

sub global_c
{
    @globs = split /\n/, 
    `ctags -x --c-kinds=v $current_file | sed -e 's/\\s\\+/ /g' | cut -d ' ' -f 5-`;

    if (@globs > 0)
    {
	print_color(2, "Careful you have global somewhere");
	$mistakes++;
    }
    foreach my $cur (@globs)
    {
	if ($cur !~ /.*\s+g_.*/)
	{
	    print_color(3, "The global $cur must be in the format g_.*");
	    $mistakes++;
	}
    }
}

sub function_general_c
{
    my @funcs = split /\n/,
	`ctags -x --c-kinds=f $current_file | sed -e 's/\\s\\+/ /g' | cut -d ' ' -f 5-`;

    if (@funcs > 5)
    {
	print_color(3, "More than 5 functions");
	$mistakes++;
    }
    foreach (@funcs)
    {
	(my $single_func = $_) =~ s/^.*\s([^\s]*)\(.*\)/$1/;
	if (length $single_func == 0 ||
	    $single_func =~ /[^a-zA-z0-9]/)
	{
	    print_color(3, "Bad function definition format for $_");
	    $mistakes++;
	}
	else
	{
	    push @function_names, $single_func;
	}
    }
}

sub function_c
{
    if ($braces_depth == 0)
    {
	foreach my $func (@function_names)
	{
	    if ($_[0] =~ /.*\s*$func\(.*\)/)
	    {
		my $c = () = $_[0] =~ /,/g;
		if ($c > 3)
		{
		    print_color(3, "More than 4 parameters");
		    $mistakes++;
		}
	    }
	}
    }
    if ($braces_depth > 0)
    {
	$function_loc++;
    }
    if (index($_[0], "{") != -1)
    {
	if ($braces_depth == 0)
	{
	    $function_loc = 0;
	}
	$braces_depth++;
    }
    if (index($_[0], "}") != -1)
    {
	$braces_depth--;
	if ($braces_depth == 0)
	{
	    $function_loc--;
	    if ($function_loc > 25)
	    {
		print_color(3, "Function exceeds 25 lines");
		$mistakes++;
	    }
	}
    }
}

sub do_while_forbidden
{
    if ($file_content =~ /do\s*?\{\s*?.*\s*?\}.*\s*?while/g)
    {
	print_color(3, "do while keyword detected");
	$mistakes++;
    }
}

sub content_c
{
    my $multiline_comment = 0;
    my @splitted_lines = split /\n/, $_[0];
    $braces_depth = 0;
    header(@splitted_lines);
    function_general_c();
    defines_c($_[0]);
    ctags_forbidden_c();
    global_c();
    do_while_forbidden();
    for (@splitted_lines)
    {
	comments_c($_);
	if ($_ =~ /\s*?\/\*/)
	{
	    $multiline_comment = 1;
	}
	if ($_ =~ /\s*?\/\// || $multiline_comment == 1)
	{
	    if ($multiline_comment == 1 && $_ =~ /.*\*\/\s*?$/)
	    {
		$multiline_comment = 0;
	    }
	    $counter++;
	    next;
	}
	include_c($_);
	general_c($_);
	spaces($_);
	function_c($_);
	$counter++;
    }
}

sub norme
{
    $current_file = $_[0];
    $file_basename = basename($_[0]);
    $file_content = read_file($_[0]);
    $blank_line = 0;
    $user_include = 0;
    $passed_include = 0;
    my $extension = substr $_[0], -2;

    if ($extension eq ".c")
    {
	$counter = 1;
	content_c($file_content);	
    }
}

sub main
{
    $mistakes = 0;
    my $help = '';
    GetOptions ('help' => \$help);

    if ($help eq '1')
    {
	help();
    }
    foreach (@ARGV)
    {
	next if $_ =~ /^-/;
	print "\nAnalyzing $_\n";
	norme($_);
    }
    print "\nErrors : $mistakes\n\n";
}

main();
