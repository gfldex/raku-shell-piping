use v6.d;

INIT my $colour = %*ENV<SHELLPIPINGNOCOLOR>:!exists;

sub RED($str) { $*ERR.t && $colour ?? „\e[31m$str\e[0m“ !! $str }

class X::IO::FileNotFound is Exception is export {
    has $.path;
    method message {
        RED „The file ⟨$.path⟩ was not found.“
    }
}

class X::IO::DirectoryNotFound is Exception is export {
    has $.path;
    method message {
        RED „The directory ⟨$.path⟩ was not found.“
    }
}
class X::IO::FileNotExecutable is Exception is export {
    has $.path;
    method message {
        RED „The file ⟨$.path⟩ is not executable.“
    }
}

our &it-is-a-file = -> IO() $_ {
    .e && .f || fail (X::IO::FileNotFound.new(:path(.Str)))
}

our &it-is-a-directory = -> IO() $_ {
    .d || fail (X::IO::DirectoryNotFound.new(:path(.Str)))
}

our &it-is-executable = -> IO() $_ {
    .x || fail (X::IO::FileNotExecutable.new(:path(.Str)))
}
