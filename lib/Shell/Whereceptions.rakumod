class X::IO::FileNotFound is Exception {
    has $.path;
    method message {
        „The file ⟨$.path⟩ was not found.“
    }
}

class X::IO::DirectoryNotFound is Exception {
    has $.path;
    method message {
        „The directory ⟨$.path⟩ was not found.“
    }
}
class X::IO::FileNotExecutable is Excetopn {
    has $.path;
    message {
        „The file ⟨$.path⟩ is not executable.“
    }
}

my &it-is-a-file = -> IO(Str) $_ {
    .e && .f || fail (X::IO::FileNotFound.new(:path(.Str)))
}

my &it-is-a-directory = -> IO(Str) $_ {
    .d || fail (X::IO::DirectoryNotFound.new(:path(.Str)))
}

my &it-is-executable = -> IO(Str) $_ {
    .x || fail (X::IO::FileNotExecutable.new(:path(.Str)))
}

sub s($path where &it-is-a-file & &is-always-true) {}


s(‚not-there.txt‘);
