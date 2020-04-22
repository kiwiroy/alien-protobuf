#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Test::Alien qw(alien_ok run_ok xs_ok with_subtest);
use Text::ParseWords qw( shellwords );
use Devel::PPPort;
use ExtUtils::CppGuess;
use ExtUtils::CBuilder;
use Alien::ProtoBuf;
use Path::Tiny 'path';

plan skip_all => 'compiler only install detected'
  if Alien::ProtoBuf->compiler_only;

alien_ok 'Alien::ProtoBuf';

my $fxt
  = (my $fxt_dir = path('.')->absolute->child('t', 'fixtures'))->stringify;
run_ok(['protoc', "-I$fxt", "--cpp_out=$fxt", 'addressbook.proto'], 'compile')
  ->success('compiled')->out_like(qr/^$/)->err_like(qr/^$/);

Devel::PPPort::WriteFile($fxt_dir->child('ppport.h')->stringify);

my $xs = do { local $/; <DATA> };

# Guess compiler, options and linker
my %opts                 = ExtUtils::CppGuess->new->module_build_options;
my @extra_compiler_flags = shellwords $opts{extra_compiler_flags};
my @extra_linker_flags   = shellwords $opts{extra_linker_flags};

my @alien_cflags = shellwords +Alien::ProtoBuf->cflags_static;
note "Alien cflags_static = @alien_cflags";

# translate to compile pb.cc
my %cbuilder_options = (
  'C++'        => 1,
  include_dirs => [$fxt],
  source       => $fxt_dir->child('addressbook.pb.cc')->stringify,
  extra_compiler_flags =>
    [@alien_cflags, Alien::ProtoBuf->cxxflags, @extra_compiler_flags,],
);

# compile pb.cc
my $cbuilder = ExtUtils::CBuilder->new(config =>
    {cc => $opts{config}{cc}, ld => $opts{config}{ld} || $opts{config}{cc}});
my $obj_file = $cbuilder->compile(%cbuilder_options);
note "$cbuilder_options{source} -> $obj_file";
ok -e $obj_file, 'source compiled to object';

# add object file to linker flags
unshift @extra_linker_flags, $obj_file;

# Include libs again ...sigh...
# https://wiki.gentoo.org/wiki/Project:Quality_Assurance/As-needed#Importance_of_linking_order
# http://www.bnikolic.co.uk/blog/gnu-ld-as-needed.html
push @extra_linker_flags, grep {/^-l/} shellwords +Alien::ProtoBuf->libs_static;

# only real difference vs Test::Alien::CPP is setting {cbuilder_config}{ld}
xs_ok {
  xs             => $xs,
  pxs            => {'C++' => 1},
  c_ext          => 'cpp',
  cbuilder_check => 'have_cplusplus',
  cbuilder_config =>
    {cc => $opts{config}{cc}, ld => $opts{config}{ld} || $opts{config}{cc}},
  cbuilder_compile => {
    include_dirs         => [$fxt],
    extra_compiler_flags => [
      "-DPERL_NO_GET_CONTEXT",   '-DNO_MATHOMS',
      Alien::ProtoBuf->cxxflags, @extra_compiler_flags,
    ],
  },
  cbuilder_link => {extra_linker_flags => \@extra_linker_flags},
  verbose       => $ENV{TEST_VERBOSE} ? 2 : 0
} => with_subtest {
  my $module = shift;
  is $module->version_check, $module, 'same version compiled ok';
  is $module->first_entry_name($fxt_dir->child('addressbook.data')->stringify),
    'Philip J Fry', 'first entry';
};

done_testing;

__DATA__
#ifdef __cplusplus
extern "C" {
#endif

#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>
#include <ppport.h>

/* perl unpollute */
#undef New
#undef Move
#undef do_open
#undef do_close
#undef seed

#ifdef __cplusplus
}
#endif

#include <fstream>
#include <iostream>
#include <string>
#include <google/protobuf/stubs/common.h>
#include <addressbook.pb.h>

using namespace std;

MODULE = TA_MODULE PACKAGE = TA_MODULE

const char *
version_check(klass)
    const char *klass
  CODE:
    GOOGLE_PROTOBUF_VERIFY_VERSION;
    RETVAL = klass;
  OUTPUT:
    RETVAL

const char *
first_entry_name(klass, filepath)
    const char *klass
    const char *filepath
  CODE:
    tutorial::AddressBook address_book;
    fstream input(filepath, ios::in | ios::binary);
    if (!address_book.ParseFromIstream(&input)) {
      cerr << "Failed to parse address book." << endl;
      RETVAL = "";
    } else {
      const tutorial::Person& person = address_book.people(0);
      RETVAL = person.name().c_str();
    }
  OUTPUT:
    RETVAL
