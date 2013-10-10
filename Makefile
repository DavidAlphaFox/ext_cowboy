# See LICENSE for licensing information.

PROJECT = ext_cowboy

# Options.

COMPILE_FIRST = ext_multipart_handler
CT_SUITES = http
PLT_APPS = crypto public_key ssl

# Dependencies.

DEPS = cowboy
dep_cowboy = pkg://cowboy 0.8.6

TEST_DEPS = ct_helper gun
dep_ct_helper = https://github.com/extend/ct_helper.git master
dep_gun = pkg://gun master

# Standard targets.

include erlang.mk
