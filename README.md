# Shell::Piping

[![Build Status](https://travis-ci.org/gfldex/raku-shell-piping.svg?branch=master)](https://travis-ci.org/gfldex/raku-shell-piping)

Shell pipes without a shell but Raku.

## SYNOPSIS

```
use Shell::Piping;

my @result;
my $where = ‚/tmp‘;
px«find $where» |» { /a/ ?? $_ !! Nil } |» px<sort -r> |» @result;
.say for @result.head(10);
```

## USAGE

This module provides the operator `|»` (alised to `|>>`) to implement shell-like
piping using `Proc::Async` objects, `Code` objects, `Channel`, `Supply` and
custom objects. A quote construct like operator `px` is provided to create
`Proc::Async` instances.

### `px<>`, `px«»`, `px{}`

These operators take a single argument without a space between `px` and the
argument. It will then split the argument on whitespaces. The first element is
considered a command and the remaining elements arguments to that command.
If a command does not contain a directory separator, `%*ENV<PATH>` will be searched
for that command and the first hit used to create a `Proc::Async`. If a
directory seperator is used the first argument is assumed to be a `IO::Path`.
In both cases the resulting file is checked for existence and filesystem access
rights to execute it. The exceptions `X::Shell::CommandNotFound` and
`X::Shell::CommandNoAccess` will be thrown when those tests fail. Please note
that the file might be deleted between this check and the actual execution of
the command. The semantics of the provided argument follow general Raku
subscript rules. As such `px<foo bar>` and `px«foo $bar»` will generate an
argument list automatically. While the code inside `px{foo, bar}` has to return
that list by your effort.

```
my $proc = px<foo $not-interpolated>; # no interpolation, $PATH is queried
my $var = "42";
$proc = px«/usr/bin/meaning $var»; # interpolation and $PATH is not queried
$proc = px{ 'C:/WINDOWS/SYSTEM32/VIOLATE-PRIVACY'.subst('/', '\') ~ '.exe', secrets.txt };
await $proc.start;
```

It is not the resposibility of `px` to actually do anthing with the resulting
`Proc::Async` instance.

### `multi infix:<|»>` and `multi infix:«|>>»`

The MMD candidates of this operator take two arguments and return a
`Shell::Pipe` object. This object implements `.sink` and `.start`, whereby the
first will call the latter. When `.sink` is called all members of a pipe will
be wired up, started in the right order and `await`ed. In sink context the
whole pipe will block until the last `Proc::Async` returned from its `.start`
method.

Members of a pipe can be `Proc::Async`, `Code` objects, `Channel`, `Supply` and `Array`-like
objects. The latter are identified by a subset.

```
subset Arrayish of Any where { !.isa('Code') && .^can(‚push‘) && .^can(‚list‘) }
```

`Proc::Async` has its STDOUT fed line-by-line to the next element in the pipe.
If it is a RHS argument to `|»` its STDIN is written to with the output of the
LHS. STDERR is left untouched unless the adverbs `:quiet` or `:stderr` are used.

```
px<find /tmp> |» px<sort> :quiet; # equivalent to `find /tmp 2>/dev/null | sort 2>/dev/null`;
```

`Code` objects can be used at any place in a pipe. The semantics however vary.
At the beginning of a pipe the object has to return an Iterable or implement
`.list`. It will be called once and iternated over its return value. As such we
support `gather/take`, sequence operators and many buildins. Each value returned
from an iteration will be added a newline, encoded as utf8 and fed to the next
member of the pipe. If a code object is in the middle of a pipe it will be
called each time a line of text is produced to its left and its return value
fed to the right. If `Nil` is returned this value will be skipped. At the end
of the pipe the code object is called with each line produced by its left
neighbour.

```
my @a;
{ 2,4,8 … 2**32 } |» px<sha256sum> |» @a;
px<find /tmp> |» { /a/ ?? .lc !! Nil } |» px<sort>;
px<find /tmp> |» { .say } :quiet;
```

`Channel` and `Supplier`/`Supply` can be used at the start and end of a pipe.
If they are closed, the entire pipe will have STDIN/STDOUT closed. This allows
a pipe to be controlled from the outside. Any case to complex for a `Code`
object should therefor be handled with a `Channel`.

```
my $c = Channel.new;
my $sort = px<sort>;
start {
    await $sort.ready; # this line is optional
    for 1..∞ {
        $c.send: $^a;
    }
}

Promise.in(60).then: { $c.close }; # a timeout
$c |» $sort |» px<uniq> |» { .say };
```

`Array`-like objects can be used at both ends of a pipe. If used as a first
element its `.list` method will be called and iterated. At the end of a pipe
the `.push` method is called. That means lines from a LHS are always added to
this object.

```
class Custom {
    has @.buffer;
    method push -> v { @.buffer.push: v; @.buffer.shift if +@.buffer > 100; self }
    method list { @.buffer.list }
}

my $c = Custom.new;
px<find /usr -iname *.txt> |» $c;
$c |» px<sort> |» { .say };
```

## Adverbs

### `:done(&c(Shell::Pipe $pipe))`

Will be called after the last command of a pipe has exited and before
`X::Shell::NonZeroExitcode` will be thrown. The argument `$pipe` can be used
for error handling via `.exitcodes` and introspection via `.pipees`.

### `:stderr(Arrayish|Code|Channel|Capture)`

This adverb redirects all STDERR into drains similar to ‚|»‘. Error text is
processed line by line and forwarded as a pair of `(Int $index, Str $text)`.
Whereby `$index` is the position of the pipee starting with 0.

```
px<find /usr> |» px<sort> |» @a :stderr(@err) :done({.exitcodes});
for @err.grep({.head == 0}) {
    say ‚find warned about: ‘, .Str;
}
```

### `:quiet`

The adverb `:quiet` will gobble up all STDERR streams and discard them.

## Error handling

When any `Proc::Async` in a pipe finished with a non-zero exitcode the pipe
returns a `Failure` of `X::Shell::NonZeroExitcode`. Calling `.exitcode` on the
pipe will mark this `Failure` as handled. The callback in `:done()` is called
before the Failure can throw. Handling exitcodes by hand has to go there.
Individual exitcodes of pipe commands are stored in an Array with an index that
corresponds to the commands potision in the pipe. If STDERR output is captured
with :stderr(Capture) the text per command is available. 

```
sub error-handler($pipe) {
    my @a = $pipe.exitcodes;
    for @a {
        .command.say;
        .exitcode.say;
        .STDERR.say;
    }
}
px«find /usr» |» px«sort» :done(&error-handler) :stderr(Capture);
```

The class `Shell::Pipe::Exitcode` supports smartmatching against `Int`, `Str`
and `Regex`. This can be used for handling exceptions.

```
px«find /usr» |» px«sort» :stderr(Capture);

CATCH {
    when X::Shell::NonZeroExitcode { 
        for .pipe.exitcodes {
            when ‚find‘ & 1 & /‘(<![‘]>+)‘: Permission denied/ {
                say „did not look in $0“;
            }
        }
    }

}
```

## Exceptions

CATCH {
    when X::Shell::CommandNotFound {
        say .cmd ~ ‚was not found‘;
    }
    when X::Shell::CommandNoAccess {
        say .cmd ~ ‚was unaccessable‘;
    }
    when X::Shell::NonZeroExitcode {
        for .pipe.exitcodes {
            say .command, .exitcode, .pipe.stderr ~~ Capture ?? .STDERR !! ‚‘;
            when ‚find‘ & 1 & /‘(<![‘]>+)‘: Permission denied/ {
                say „did not look in $0“;
            }
        }
    }
    when X::Shell::NoExitcodeYet {
        say .^name, „\n“, .message;
    }
}

### X::Shell::CommandNotFound

Will be thrown by `px«»` or when the pipe is started when the file used as a
command is not found. The meaning of "not found" depends on the OS.

### X::Shell::CommandNoAccess

Will be thrown by `px«»` or when the pipe is started when the file used as a
command exists but can not be executed. Filesystem access rights depend on the
OS.

### X::Shell::NonZeroExitcode

This will be thrown after the last pipee exits and holds a `Shell::Pipe` in
`.pipe`. If `:stderr(Capture)` is used the exception message contains all error
text grouped by the shell command names.

### X::Shell::NoExitcodeYet

Will be thrown if `.exitcodes` is accessed before the pipe finished. Please
note that filling the underlying Array is not atomic. When or after `.done` is
called using `.exitcodes` is fine.

## LICENSE

All files (unless noted otherwise) can be used, modified and redistributed
under the terms of the Artistic License Version 2. Examples (in the
documentation, in tests or distributed as separate files) can be considered
public domain.

ⓒ2020 Wenzel P. P. Peppmeyer
