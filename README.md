# Shell::Piping

[![Build Status](https://travis-ci.org/gfldex/raku-shell-piping.svg?branch=master)](https://travis-ci.org/gfldex/raku-shell-piping)

Shell pipes without a shell but Raku.

## SYNOPSIS

```
use v6.d;
use Shell::Piping;

my int $exitcode = 0;
my &RED = $*OUT.t ?? { „\e[31m$_\e[0m“ } !! { $_ };

sub MAIN(Str $where = ‚/tmp/.‘) {
    my @result;
    my @err;

    px«find $where» |» { /a/ ?? $_ !! Nil } |» px<sort -r> |» @result :stderr(@err) :done({$exitcode ⚛= 1 if .exitcodes});

    .say for @result.head(10);

    if $exitcode {
        $*ERR.put: @err».&RED.join(„\n“);
    }

    exit $exitcode;
}
```

## USAGE

This module provides the operator `|»` (aliased to `|>>`) to implement shell-like
piping using `Proc::Async` objects, `Code` objects, `Channel`, `Supply` and
custom objects. A quote construct like operator `px` is provided to create
`Proc::Async` instances.

### `px<>`, `px«»`, `px{}`

These operators take a single argument without a space between `px` and the
argument. It will then split the argument on white spaces. The first element is
considered a command and the remaining elements arguments to that command.
If a command does not contain a directory separator, `%*ENV<PATH>` will be searched
for that command and the first hit used to create a `Proc::Async`. If a
directory separator is used the first argument is assumed to be a `IO::Path`.
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

It is not the resposibility of `px` to actually do anything with the resulting
`Proc::Async` instance.

### `multi infix:<|»>` and `multi infix:«|>>»`

The MMD candidates of this operator take two arguments and return a
`Shell::Pipe` object. This object implements `.sink` and `.start`, whereby the
first will call the latter. When `.sink` is called all members of a pipe will
be wired up, started in the right order and `await`ed. In sink context the
whole pipe will block until the last `Proc::Async` returned from its `.start`
method.

Members of a pipe can be `Proc::Async`, `Code` objects, `Channel`, `Supply`,
`IO::Handle`, `IO::Path` and `Array`-like objects. The latter are identified by
a subset.

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
`.list`. It will be called once and iterated over its return value. As such we
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
object should therefore be handled with a `Channel`.

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

`IO::Path` objects are opened for reading at the begin of a pipe and for writing
at the end. `IO::Handle` objects are expected to be open already and must be
open for writing at the end. File handles will not be closed by the pipe.

```
px<find /tmp> |» px<sort> |» { .uc  } |» ‚/tmp/sorted.txt‘.IO :quiet;
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

### `:stderr(Arrayish|Code|Channel|IO::Path|IO::Handle|Capture)`

This adverb redirects all STDERR into objects similar to what ‚|»‘ accepts.
Error text is processed line by line and forwarded as a pair of `(Int $index,
Str $text)`.  Whereby `$index` is the position of the pipee producing the text
starting with 0.

```
px<find /usr> |» px<sort> |» @a :stderr(@err) :done({.exitcodes});
for @err.grep({.head == 0}) {
    say ‚find warned about: ‘, .Str;
}
```

To log to a file `:stderr()` takes an `IO::Handle` that is open for writing or a
`IO::Path` that will be opened for writing. To close the handle call
`.stderr.close` in the `:done()` callback.

### `:quiet`

The adverb `:quiet` will gobble up all STDERR streams and discard them.

## Error handling

When any `Proc::Async` in a pipe finished with a non-zero exitcode the pipe
returns a `Failure` of `X::Shell::NonZeroExitcode`. Calling `.exitcode` on the
pipe will mark this `Failure` as handled. The callback in `:done()` is called
before the Failure can throw. Handling exitcodes by hand has to go there.
Individual exitcodes of pipe commands are stored in an Array with an index that
corresponds to the commands position in the pipe. If STDERR output is captured
with `:stderr(Capture)`. The text per command is available, again as a list of
`($idx, $text)`. 

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

```
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
```

### Refining Exceptions

The exceptions `X::Shell::CommandNotFound` and `X::Shell::CommandNoAccess` are
refinable. This means the error message can be tweaked with the class method
`.refine`. This method takes two `Callable`s. When `.message` is called with
the exception instance and expected to return `Bool`. On `True` the 2nd
callback is called with the exception instance and supposed to return a text.
This text will be used instead of the default text and returned from
`.message`. Replacing this message will act on the class and even on created
but yet to be thrown exceptions.

```
X::Shell::CommandNotFound.refine(
    (my &b = {.cmd eq ‚raku‘}),
    { ‚Please install Rakudo with `apt install rakudo`.‘ }
);
X::Shell::CommandNotFound.refine(&b, :revert);
X::Shell::CommandNotFound.refine(:revert-all);
```

The method `.revert` also takes one `Callabel` and the adverb `:revert` to
remove one refinement or all refinements with `:revert-all`.

### X::Shell::CommandNotFound

Will be thrown by `px«»` or when the pipe is started if the file used as a
command is not found. The meaning of "not found" depends on the OS. If the
command was searched for in `%*ENV<PATH>`, that path will be shown in the
exception message.

### X::Shell::CommandNoAccess

Will be thrown by `px«»` or when the pipe is started if the file used as a
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

# Wherecetions

Are subs to be used in where clauses to test for conditions that would throw
later on. Whereceptions will output to STDERR in red unless
`%*ENV<SHELLPIPINGNOCOLOR>` is set to any value. When sensible there will be
checks for dangling symlinks and an alternate error message will be returned by
the exceptions. All exceptions are subclasses of `X::IO::Whereception`.

## SYNOPSIS

```
sub works-with-files(IO::Path(Str) $file where &it-is-a-file) {
    say ‚answer‘ for $file.lines.grep(42);
}

sub works-with-directories(IO::Path(Str) $dir where &it-is-a-directory) {
    for $dir {
        .&works-with-files when .IO.f;
        .IO.dir()».&?BLOCK when .IO.d;
    }
}

}

sub will-shell-out(IO::Path(Str) $file where &it-is-executable) {
    px<find -iname '42'> |» px«$file» |» (my @stdout);
}
```

### `sub it-is-a-file(IO() $f)`

Will call `.e` and `.f` and throw `X::IO::FileNotFound`.

### `sub it-is-a-directory(IO() $d)`

Will call `.d` and throw `X::IO::DirectoryNotFound`.

### `sub it-is-executable(IO() $exec)`

Will call `.x` and throw `X::IO::FileNotExecutable`.

## LICENSE

All files (unless noted otherwise) can be used, modified and redistributed
under the terms of the Artistic License Version 2. Examples (in the
documentation, in tests or distributed as separate files) can be considered
public domain.

ⓒ2020 Wenzel P. P. Peppmeyer
