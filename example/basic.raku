use v6;

use Shell::Piping;

my $find = Proc::Async.new('/usr/bin/find', '/tmp');
my $grep = Proc::Async.new('/bin/grep', 'a');
my $sort = Proc::Async.new('/usr/bin/sort');
my $segfaulter = Proc::Async.new('./t/segfaulter');
my $errorer = Proc::Async.new('./t/errorer');
my @a;
my @spy;
# 
# sub my-little-filter { $^a ~~ s/a/b/ }
# 
# my $pipe = $find \
#            |> @spy \
#            |> $grep \
#            |> &my-little-filter \
#            |> $sort \
#            |> { .uc } \
#            |> @a;
# 
# say $pipe;
# @a = <1 b 4 a c>;
# my $p = $find |> $sort |> @a;
# say $p;

# { (‚a‘..‚z‘).roll(10) } |> $sort |> -> \e { @a.push: e };
# 
# say @a;

# my $obj = class AnonClass {
#     has @.a;
#     method push(\e) { self.a.push: e; self }
#     method list { self.a.list }
# }.new;
# 
# { (‚a‘..‚z‘).roll(10) } |> $sort |> $obj;
# 
# dd $obj;
# 
# my $reverse = Proc::Async.new(</usr/bin/sort -r>);
# 
# my $exitcodes;
# my $false = Proc::Async.new(</bin/false>);
# $obj |> $reverse |> $false |> store-exitcodes({ $exitcodes = $_ }) |> { .put }
# say so $exitcodes;

# $find |> { say $++; .uc } |> $sort |> { .lc } |> @a;
# dd @a;

# my $sup-out = ('a'..'z').pick(30).Supply;
# my $sup-in = Supplier.new;
# $sup-in.Supply.tap: { .say };
# $sup-out |> $sort |> $sup-in;

# my $c = Channel.new;
# Promise.in(1).then: {
#     say ‚sending‘;
#     for ('a'..'z').pick(30) {
#         $c.send: .Str;
#     }
#     say 'closing';
#     $c.close;
# };
# 
# my @stderr;

# $c |> $grep |> $sort;
#

# multi sub handle-stderr(|) { };
# multi sub handle-stderr(0, $line) { say „ERR stream find: $line“ };
# $find |> $errorer |> $sort :done({ say .exitcode if .exitcode }) :stderr(&handle-stderr);

# $find |> $errorer |> $sort :done({ say .exitcode if .exitcode }) :stderr(-> $index, $line { say „ERR stream $index: $line“});

# my @err;
# my $c = Channel.new;
# $c.Supply.tap: -> ($index, $line) { @err[$index].push: $line; };
# 
# $find |> $errorer |> $sort :stderr($c);
# 
# $c.close;
# 
# dd @err;

# $find |> $errorer |> $sort :quiet;

# $find |> $segfaulter |> $sort;

# Shell::<&ls> = px <ls -l>;
# dd Shell::ls;

$find |» -> $l { $l ~~ /a/ ?? $l !! Nil } |» $sort :quiet;
