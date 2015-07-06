#!/usr/bin/perl

use warnings;
use strict;
use Getopt::Long;
use File::Slurp;
use Term::ANSIColor;
use feature 'state';

my $counter;
my $current_file;
my $mistakes;
my $file_content;
my @globs;

## TODO Global alignment
## TODO Check header
## TODO Once everything finished add options for ignoring checks
## TODO No comments inside body function
## TODO Comments aligned, first must be /* and after ** and the last */
## /*
##  ** Blabla
##  ** Blabla
## */
## TODO Variables must be aligned with function name
## TODO no end spaces
## TODO alignment must be done with tabs no spaces
## TODO Variables, macro, function, ... must be named correctly
## TODO no capital letters to variable's names, files and functions only lower case with _ character
## TODO everything in english
## TODO Defines/Macro must be in capital letters
## TODO structure = s_, typedef = t_, union = u_, globale = g_
## TODO One variable per line
## TODO one blank line between declaration variables and instructions
## TODO No additional blank line between function (only one)
## TODO Cannot assign and create variable at the same time
## TODO Count static number if too much print a warning
## TODO * must be on the variable not on the type
## TODO if () { => forbidden
##		something
##	}
## TODO Max 4 parameters on functions
## TODO Check if too many parameters in one structure
## TODO No space after the name of the function and '('
## TODO Space after a keyword and return must have parenthesis, sizeof is an exception
## TODO #ifndef #ifdef #endif need comments /* ! MY_H_ */ if the header file is named my.h
## TODO check if function more than 25 lines
## TODO Makefile : $(NAME), clean, fclean, re, all are mandatory
## TODO Makefile : Check if makefile relink
## TODO Makefile : wildcard (*) usage is forbidden
## TODO Makefile : Check header 

sub print_color
{
    my $location_and_error = $current_file.":".$counter.": ".$_[1]."\n";

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

sub spaces
{
    if ($_[0] =~ /,[^ ]/)
    {
	print_color(3, "You need to add a whitespace after a coma");
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
    if ($_[0] =~ /.*return\s[^\(].*[^\)];/)
    {
	print_color(3, "Return must have parenthesis");
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
	my $single_func = ($_ =~ //g);
    }
    print join(",", @funcs), "\n";
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
    function_general_c();
    defines_c($_[0]);
    ctags_forbidden_c();
    global_c();
    do_while_forbidden();
    for (split /\n/, $_[0])
    {
	general_c($_);
	spaces($_);
	$counter++;
    }
}

sub norme
{
    $current_file = $_[0];
    $file_content = read_file($_[0]);
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
}

main();
