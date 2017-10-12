#! /bin/bash
## vim:set ts=4 sw=4 et:
set -e; set -o pipefail

# Support for Travis CI -- https://travis-ci.org/upx/upx/builds
# Copyright (C) Markus Franz Xaver Johannes Oberhumer

#
# very first version of the upx-testsuite
#

if [[ $TRAVIS_OS_NAME == osx ]]; then
argv0=$0; argv0abs=$(greadlink -en -- "$0"); argv0dir=$(dirname "$argv0abs")
else
argv0=$0; argv0abs=$(readlink -en -- "$0"); argv0dir=$(dirname "$argv0abs")
fi
source "$argv0dir/travis_init.sh" || exit 1

if [[ $BM_T =~ (^|\+)SKIP($|\+) ]]; then
    echo "UPX testsuite SKIPPED."
    exit 0
fi
if [[ $BM_X == rebuild-stubs ]]; then
    exit 0
fi
[[ -f $upx_exe ]] && upx_exe=$(readlink -en -- "$upx_exe")

# create dirs
cd / || exit 1
mkbuilddirs $upx_testsuite_BUILDDIR
cd / && cd $upx_testsuite_BUILDDIR || exit 1
if [[ ! -d $upx_testsuite_SRCDIR/files/packed ]]; then exit 1; fi

# /***********************************************************************
# // support functions
# ************************************************************************/

testsuite_header() {
    print_header "$1"
}

testsuite_split_f() {
    fd=$(dirname "$1")
    fb=$(basename "$1")
    fsubdir=$(basename "$fd")
    # sanity checks
    if [[ ! -f "$1" || -z "$fsubdir" || -z "$fb" ]]; then
        fd= fb= fsubdir=
    fi
}

testsuite_check_sha() {
    (cd "$1" && sha256sum -b */* | LC_ALL=C sort -k2) > $1/.sha256sums.current
    echo
    cat $1/.sha256sums.current
    if ! cmp -s $1/.sha256sums.expected $1/.sha256sums.current; then
        echo "UPX-ERROR: $1 FAILED: checksum mismatch"
        diff -u $1/.sha256sums.expected $1/.sha256sums.current || true
        exit_code=1
        let num_errors+=1 || true
        all_errors="${all_errors} $1"
        #exit 1
    fi
    echo
}

testsuite_check_sha_decompressed() {
    (cd "$1" && sha256sum -b */* | LC_ALL=C sort -k2) > $1/.sha256sums.current
    if ! cmp -s $1/.sha256sums.expected $1/.sha256sums.current; then
        cat $1/.sha256sums.current
        echo "UPX-ERROR: FATAL: $1 FAILED: decompressed checksum mismatch"
        diff -u $1/.sha256sums.expected $1/.sha256sums.current || true
        exit 1
    fi
}

testsuite_use_canonicalized=1
testsuite_run_compress() {
    testsuite_header $testdir
    local files f
    if [[ $testsuite_use_canonicalized == 1 ]]; then
        files=t020_canonicalized/*/*
    else
        files=t010_decompressed/*/*
    fi
    for f in $files; do
        testsuite_split_f $f
        [[ -z $fb ]] && continue
        echo "# $f"
        mkdir -p $testdir/$fsubdir $testdir/.decompressed/$fsubdir
        $upx_run -qq --prefer-ucl "$@" $f -o $testdir/$fsubdir/$fb
        $upx_run -qq -d $testdir/$fsubdir/$fb -o $testdir/.decompressed/$fsubdir/$fb
    done
    testsuite_check_sha $testdir
    $upx_run -qq -l $testdir/*/*
    $upx_run -qq --file-info $testdir/*/*
    $upx_run -q -t $testdir/*/*
    if [[ $testsuite_use_canonicalized == 1 ]]; then
        # check that after decompression the file matches the canonicalized version
        cp t020_canonicalized/.sha256sums.expected $testdir/.decompressed/
        testsuite_check_sha_decompressed $testdir/.decompressed
        rm -rf "./$testdir/.decompressed"
    fi
}

# /***********************************************************************
# // expected checksums
# //
# // To ease maintenance of this script in case of updates this section
# // can be automatically re-created from the current checksums -
# // see call of function recreate_expected_sha256sums below.
# ************************************************************************/

recreate_expected_sha256sums() {
    local o="$1"
    local files f d
    echo "########## begin .sha256sums.recreate" > "$o"
    files=*/.sha256sums.current
    for f in $files; do
        d=$(dirname "$f")
        echo "expected_sha256sums__${d}="'"\' >> "$o"
        cat "$f" >> "$o"
        echo '"' >> "$o"
    done
    echo "########## end .sha256sums.recreate" >> "$o"
}

########## begin .sha256sums.recreate
expected_sha256sums__t010_decompressed="\
24158f78c34c4ef94bb7773a6dda7231d289be76c2f5f60e8b9ddb3f800c100e *amd64-linux.elf/upx-3.91
28d7ca8f0dfca8159e637eaf2057230b6e6719e07751aca1d19a45b5efed817c *arm-wince.pe/upx-3.91.exe
b1c1c38d50007616aaf8e942839648c80a6111023e0b411e5fa7a06c543aeb4a *armeb-linux.elf/upx-3.91
bcac77a287289301a45fde9a75e4e6c9ad7f8d57856bae6eafaae12ae4445a34 *i386-dos32.djgpp2.coff/upx-3.91.exe
730a513b72a094697f827e4ac1a4f8ef58a614fc7a7ad448fa58d60cd89af7ed *i386-linux.elf/upx-3.91
0dbc3c267ca8cd35ee3ea138b59c8b1ae35872c918be6d17df1a892b75710f9b *i386-win32.pe/upx-3.91.exe
8e5333ea040f5594d3e67d5b09e005d52b3a52ef55099a7c11d7e39ead38e66d *m68k-atari.tos/upx-3.91.ttp
c3f44b4d00a87384c03a6f9e7aec809c1addfe3e271244d38a474f296603088c *mipsel-linux.elf/upx-3.91
b8c35fa2956da17ca505956e9f5017bb5f3a746322647e24ccb8ff28059cafa4 *powerpc-linux.elf/upx-3.91
"
expected_sha256sums__t020_canonicalized="\
24158f78c34c4ef94bb7773a6dda7231d289be76c2f5f60e8b9ddb3f800c100e *amd64-linux.elf/upx-3.91
28d7ca8f0dfca8159e637eaf2057230b6e6719e07751aca1d19a45b5efed817c *arm-wince.pe/upx-3.91.exe
b1c1c38d50007616aaf8e942839648c80a6111023e0b411e5fa7a06c543aeb4a *armeb-linux.elf/upx-3.91
bcac77a287289301a45fde9a75e4e6c9ad7f8d57856bae6eafaae12ae4445a34 *i386-dos32.djgpp2.coff/upx-3.91.exe
730a513b72a094697f827e4ac1a4f8ef58a614fc7a7ad448fa58d60cd89af7ed *i386-linux.elf/upx-3.91
0dbc3c267ca8cd35ee3ea138b59c8b1ae35872c918be6d17df1a892b75710f9b *i386-win32.pe/upx-3.91.exe
8e5333ea040f5594d3e67d5b09e005d52b3a52ef55099a7c11d7e39ead38e66d *m68k-atari.tos/upx-3.91.ttp
c3f44b4d00a87384c03a6f9e7aec809c1addfe3e271244d38a474f296603088c *mipsel-linux.elf/upx-3.91
b8c35fa2956da17ca505956e9f5017bb5f3a746322647e24ccb8ff28059cafa4 *powerpc-linux.elf/upx-3.91
"
expected_sha256sums__t110_compress_ucl_nrv2b_3_no_filter="\
fd8b72e7adf24e46235f445769a881d1cbb8e883a8ddf9a4663bb6b10a23440a *amd64-linux.elf/upx-3.91
c1a6ef9d0b8a26f1d6e3307af6f119bc95411a54421c7da3bd6ade9c4eead187 *arm-wince.pe/upx-3.91.exe
f8e9a7201a3016b4bbd97c0e468fc69affccc18fc5a71ba70c0aa1d2212f3027 *armeb-linux.elf/upx-3.91
7d5f0fd6f18e4cd16655ef58805f228bcaddd5b035ce998faed446e290aea3d9 *i386-dos32.djgpp2.coff/upx-3.91.exe
f0ad83e018214c26093c0ada70ea0156b63c824a5bdf0ead9120634d67f73cea *i386-linux.elf/upx-3.91
d3cfb5347758ee54e54cfc92ae502a3e19702cd4fec115d74f84f8a5ab7a9bc2 *i386-win32.pe/upx-3.91.exe
c4c8b912a48bcaaef72fd94cd0c307659a03be2ec359bf01a42a2a39307dd964 *m68k-atari.tos/upx-3.91.ttp
60a5d572b45cd819c17ee1b6178eb09865f47e7db9ffb29152326f3a826371ba *mipsel-linux.elf/upx-3.91
16b0d079f5d005222f346466e8c567219dfe4feb71a0662342d04168c07c3f8b *powerpc-linux.elf/upx-3.91
"
expected_sha256sums__t120_compress_ucl_nrv2d_3_no_filter="\
906c1ba3e6165d828e56c4fec918c9dd81ac742ded137cc42636dcd68ee31040 *amd64-linux.elf/upx-3.91
2bb2477bdf4643954b4bb707b1017459238b03f66883303cd20e9e8740764dd7 *arm-wince.pe/upx-3.91.exe
4dfd0f09628bd76fd1d49a4de1c77e1d17227ca6659a009e987c8d85e93ebe4e *armeb-linux.elf/upx-3.91
c52473f5dbdac560c05d5d173e5342b5e696e604517359baef581672eb25a9e6 *i386-dos32.djgpp2.coff/upx-3.91.exe
89dca0f4252c058767832a4f5021f1c2682ed8b54bf5cd779f0252bc1ea50beb *i386-linux.elf/upx-3.91
5bebadb8455b052580b1f22a949c3eb5a441c8b6ba9c6b50506cb703fc3f65ce *i386-win32.pe/upx-3.91.exe
ef94d8b0e02a650c302bec9f2d50462f2accc2fbb8003cc4977bc550d2e5b9f2 *m68k-atari.tos/upx-3.91.ttp
901a01c0170e8550102ab96b991bd1d607bcf423f52322e546a29ce286fc5385 *mipsel-linux.elf/upx-3.91
81ee676127a44a63945a3b2d6e7272623df0620c6bef935252b43970c977f562 *powerpc-linux.elf/upx-3.91
"
expected_sha256sums__t130_compress_ucl_nrv2e_3_no_filter="\
bb8ca19268e5b1d5f1f8c1c46ec8a7ead470f1883f0b0c0166148eedb54560d0 *amd64-linux.elf/upx-3.91
0915344e0ee8e7c006e6cce71c024f518e097a88820c7ab3ca183ab1c614ce82 *arm-wince.pe/upx-3.91.exe
ea3103c3df4f09ab6f9a720be8c52ce8d3f8540b0ddc33abfbaa3273fcb5bd87 *armeb-linux.elf/upx-3.91
5c5ff78652e76834f3f9ab110c42e3a34ef54c748bce212b0e942049f43f5d4d *i386-dos32.djgpp2.coff/upx-3.91.exe
bc5174b72168fc614245560fc0a0ba1de440fb5b59f56a66c19a6b40d5c4b3b3 *i386-linux.elf/upx-3.91
ef5e25c79d356e9ed0736f34dc5ee7a8f4c66d0c330b8d16672fac7d829b5a7c *i386-win32.pe/upx-3.91.exe
dfc6abff2d3417b9708b1232d5791a9232c6623dcedb9dcb59428b67bbf864e9 *m68k-atari.tos/upx-3.91.ttp
34d1faebe6a8f6228de4ec44f3df4111d103c1a4fab81ecc1147422a1538b37a *mipsel-linux.elf/upx-3.91
f5d1badd9bdeb0e5c9ad6bacec7c24963bd37fa8e7a36a2db8b3d8f957f16ae6 *powerpc-linux.elf/upx-3.91
"
expected_sha256sums__t140_compress_lzma_2_no_filter="\
7e890b2f684329dc036f913536dc61472721d73825a75892952cd363dc1ab7a4 *amd64-linux.elf/upx-3.91
3af2a2346a252dfacefb6209725907b2947dc1ccf5e99af139608354f852507c *arm-wince.pe/upx-3.91.exe
2fcace545a64bc19e82a18ff16d8b5b106b4f6b3a8e4a318dec00c6a5308ec61 *armeb-linux.elf/upx-3.91
964fb400b0b4a2b1926ce7076610db8c3a8e41807fe030209af1615d43b6a020 *i386-dos32.djgpp2.coff/upx-3.91.exe
828f34977b65e1555688766a6dd20739a66be47ecf69119aaea5f5279ea0fd75 *i386-linux.elf/upx-3.91
171bde9f27a5571b524e9d7cdba6cefa142bb8a0b114c4d5294944ee5781e0bb *i386-win32.pe/upx-3.91.exe
8826c1f910007360ba6cec02c91bd7cdc87bce1ce27804ca728846b92d9086c9 *m68k-atari.tos/upx-3.91.ttp
2466d621b46a084718a50327bef8ac54ac961fd297a9d8cc747603cd255ac68e *mipsel-linux.elf/upx-3.91
b79c08d2ba96a669b207f8b09a9603df17fdda316f49159d2d30857d18c7ab85 *powerpc-linux.elf/upx-3.91
"
expected_sha256sums__t150_compress_ucl_2_all_filters="\
2e8cb4e0af4c9620d7ad6de6df535f6be388a2275c5a5c70d6c074e8e15c3dea *amd64-linux.elf/upx-3.91
dc7323e753ce62e6a1c22112f139953dbaa1e5268530479f8ad48e0c54062295 *arm-wince.pe/upx-3.91.exe
28bdf621be8b1e6d5c6df647232417d6b3eb3103f94fe5ed1cecb449099f170b *armeb-linux.elf/upx-3.91
8614d93ba30def6866b3be92ae5bdd5f294266e0fc4a26c078682917f127656d *i386-dos32.djgpp2.coff/upx-3.91.exe
7c33a5300d93079e6612229242584c80103a11826e78c0fcf6f8e5047d638c27 *i386-linux.elf/upx-3.91
7c3d7398f63eb9e235992d2d8fd6de9e355f6f21621c45032a6ae6c9009067e6 *i386-win32.pe/upx-3.91.exe
25e9e84bf4e01350b362d088f8107d8228b4576bc47b6b718e9e742f7e4a5205 *m68k-atari.tos/upx-3.91.ttp
9a3a2af66cffe78d99ccc53ee83d9a05c7a047e4e98469c499d8b72549f6e9c9 *mipsel-linux.elf/upx-3.91
7323c6f928549a61f1ff705af523ce4b8b420d114f4abd1fa91dab33b0938329 *powerpc-linux.elf/upx-3.91
"
expected_sha256sums__t160_compress_all_methods_1_no_filter="\
011ff89c098768e23b1bfbce85161d187c78eca6c1a6165bc22d26c0e6b111b4 *amd64-linux.elf/upx-3.91
1c9c618741739404f40d198d2fc77010539589379bf260502af9f10f1ec0d05b *arm-wince.pe/upx-3.91.exe
9650cd1ca32414fc25a85999dde2e927239f2158a9d49e9e99ab88ed1ecd2cef *armeb-linux.elf/upx-3.91
863bbf7f3cf41296987b085a4db8acba372e3d65d8d9c656f9a7276f2e7aa4d3 *i386-dos32.djgpp2.coff/upx-3.91.exe
5f4eb68842b46b9a1c138e5330e588b493d2927e27130be245f6d7aded82ef15 *i386-linux.elf/upx-3.91
4c73a38e81fe12f36dc37e514f8580c12bdf5d8cb92e9a07b7070db291a2f7eb *i386-win32.pe/upx-3.91.exe
0f902defbce3c9a8ea08910ff2ac62b9f06e7ceed0570501cb3b6287bfd6d797 *m68k-atari.tos/upx-3.91.ttp
dfe91501e4cb0b9e4686ffa9aa1e0e9bf1ea8b4c363fbc2cd35713d11267bcc5 *mipsel-linux.elf/upx-3.91
a25a6932e539861cd28eaa0b7b9192c5f4de826d4552d9ef0206565adedc2da5 *powerpc-linux.elf/upx-3.91
"
expected_sha256sums__t170_compress_all_methods_no_lzma_5_no_filter="\
1ffc826e136538484c697b784bd692f9da101e4f7e76de111390fce5bab76b2b *amd64-linux.elf/upx-3.91
66653a91c355a1ad1ab7b07c6c20b2d2899d0f42078683d0f4d540df476b1afb *arm-wince.pe/upx-3.91.exe
6cbf1744a7bbc16fbf15c197d9d6aaa3599ce3f033bda143e51812ecfa0d0906 *armeb-linux.elf/upx-3.91
490a196fbba4a8f21bfb9ac2a3b92a6dc7e287f255a3ab987f7d29d5a75d8db4 *i386-dos32.djgpp2.coff/upx-3.91.exe
a0630df230ec301d1919d4fb15c66e7a403d17a03dfe4c79cd7835e2eb0d1b19 *i386-linux.elf/upx-3.91
14b192b5419ca0ec2b3f238dc6ed9c17596e82ff2674a299d4b0a76d118a73de *i386-win32.pe/upx-3.91.exe
2eb756cf3c7e4f80fea379a267071c981f3ab1fbb3eaab7057ca18a2b400fb8f *m68k-atari.tos/upx-3.91.ttp
4db8801f9b71e42949ebac0d12b01314b8411ed416d72dd60765da912acce32c *mipsel-linux.elf/upx-3.91
6624628c98403eb74de906a4589f2a9a0f93c3e743d742ee71eeace202736778 *powerpc-linux.elf/upx-3.91
"
########## end .sha256sums.recreate

# /***********************************************************************
# // init
# ************************************************************************/

#set -x # debug
exit_code=0
num_errors=0
all_errors=

if [[ $BM_T =~ (^|\+)ALLOW_FAIL($|\+) ]]; then
    echo "ALLOW_FAIL"
    set +e
fi

[[ -z $upx_exe && -f $upx_BUILDDIR/upx.out ]] && upx_exe=$upx_BUILDDIR/upx.out
[[ -z $upx_exe && -f $upx_BUILDDIR/upx.exe ]] && upx_exe=$upx_BUILDDIR/upx.exe
if [[ -z $upx_exe ]]; then exit 1; fi
upx_run=$upx_exe
if [[ $BM_T =~ (^|\+)qemu($|\+) && -n $upx_qemu ]]; then
    upx_run="$upx_qemu $upx_qemu_flags -- $upx_exe"
fi
if [[ $BM_T =~ (^|\+)wine($|\+) && -n $upx_wine ]]; then
    upx_run="$upx_wine $upx_wine_flags $upx_exe"
fi
if [[ $BM_T =~ (^|\+)valgrind($|\+) ]]; then
    if [[ -z $upx_valgrind ]]; then
        upx_valgrind="valgrind"
    fi
    if [[ -z $upx_valgrind_flags ]]; then
        #upx_valgrind_flags="--leak-check=full --show-reachable=yes"
        #upx_valgrind_flags="-q --leak-check=no --error-exitcode=1"
        upx_valgrind_flags="--leak-check=no --error-exitcode=1"
    fi
    upx_run="$upx_valgrind $upx_valgrind_flags $upx_exe"
fi

if [[ $BM_B =~ (^|\+)coverage($|\+) ]]; then
    (cd / && cd $upx_BUILDDIR && lcov -d . --zerocounters)
fi

export UPX="--prefer-ucl --no-color --no-progress"

# let's go
if ! $upx_run --version;          then echo "UPX-ERROR: FATAL: upx --version FAILED"; exit 1; fi
if ! $upx_run -L >/dev/null 2>&1; then echo "UPX-ERROR: FATAL: upx -L FAILED"; exit 1; fi
if ! $upx_run --help >/dev/null;  then echo "UPX-ERROR: FATAL: upx --help FAILED"; exit 1; fi
rm -rf ./testsuite_1
mkbuilddirs testsuite_1
cd testsuite_1 || exit 1

# /***********************************************************************
# // decompression tests
# ************************************************************************/

testdir=t010_decompressed
mkdir $testdir; v=expected_sha256sums__$testdir; echo -n "${!v}" >$testdir/.sha256sums.expected

testsuite_header $testdir
for f in $upx_testsuite_SRCDIR/files/packed/*/upx-3.91*; do
    testsuite_split_f $f
    [[ -z $fb ]] && continue
    echo "# $f"
    mkdir -p $testdir/$fsubdir
    $upx_run -qq -d $f -o $testdir/$fsubdir/$fb
done
testsuite_check_sha $testdir


# run one pack+unpack step to canonicalize the files
testdir=t020_canonicalized
mkdir $testdir; v=expected_sha256sums__$testdir; echo -n "${!v}" >$testdir/.sha256sums.expected

testsuite_header $testdir
for f in t010_decompressed/*/*; do
    testsuite_split_f $f
    [[ -z $fb ]] && continue
    echo "# $f"
    mkdir -p $testdir/$fsubdir/.packed
    $upx_run -qq --prefer-ucl -1 $f -o $testdir/$fsubdir/.packed/$fb
    $upx_run -qq -d $testdir/$fsubdir/.packed/$fb -o $testdir/$fsubdir/$fb
done
testsuite_check_sha $testdir

# /***********************************************************************
# // compression tests
# // info: we use fast compression levels because we want to
# //   test UPX and not the compression libraries
# ************************************************************************/

testdir=t110_compress_ucl_nrv2b_3_no_filter
mkdir $testdir; v=expected_sha256sums__$testdir; echo -n "${!v}" >$testdir/.sha256sums.expected
time testsuite_run_compress --nrv2b -3 --no-filter

testdir=t120_compress_ucl_nrv2d_3_no_filter
mkdir $testdir; v=expected_sha256sums__$testdir; echo -n "${!v}" >$testdir/.sha256sums.expected
time testsuite_run_compress --nrv2d -3 --no-filter

testdir=t130_compress_ucl_nrv2e_3_no_filter
mkdir $testdir; v=expected_sha256sums__$testdir; echo -n "${!v}" >$testdir/.sha256sums.expected
time testsuite_run_compress --nrv2e -3 --no-filter

testdir=t140_compress_lzma_2_no_filter
mkdir $testdir; v=expected_sha256sums__$testdir; echo -n "${!v}" >$testdir/.sha256sums.expected
time testsuite_run_compress --lzma -2 --no-filter

testdir=t150_compress_ucl_2_all_filters
mkdir $testdir; v=expected_sha256sums__$testdir; echo -n "${!v}" >$testdir/.sha256sums.expected
time testsuite_run_compress -2 --all-filters

testdir=t160_compress_all_methods_1_no_filter
mkdir $testdir; v=expected_sha256sums__$testdir; echo -n "${!v}" >$testdir/.sha256sums.expected
time testsuite_run_compress --all-methods -1 --no-filter

testdir=t170_compress_all_methods_no_lzma_5_no_filter
mkdir $testdir; v=expected_sha256sums__$testdir; echo -n "${!v}" >$testdir/.sha256sums.expected
time testsuite_run_compress --all-methods --no-lzma -5 --no-filter

# /***********************************************************************
# // summary
# ************************************************************************/

# recreate checkums from current version for an easy update in case of changes
recreate_expected_sha256sums .sha256sums.recreate

testsuite_header "UPX testsuite summary"
if ! $upx_run --version; then
    echo "UPX-ERROR: upx --version FAILED"
    exit 1
fi
echo
echo "upx_exe='$upx_exe'"
if [[ "$upx_run" != "$upx_exe" ]]; then
    echo "upx_run='$upx_run'"
fi
if [[ -f "$upx_exe" ]]; then
    ls -l "$upx_exe"
    file "$upx_exe" || true
fi
echo "upx_testsuite_SRCDIR='$upx_testsuite_SRCDIR'"
echo "upx_testsuite_BUILDDIR='$upx_testsuite_BUILDDIR'"
echo ".sha256sums.{expected,current}:"
cat */.sha256sums.expected | LC_ALL=C sort | wc
cat */.sha256sums.current  | LC_ALL=C sort | wc
echo
if [[ $exit_code == 0 ]]; then
    echo "UPX testsuite passed. All done."
else
    echo "UPX-ERROR: UPX testsuite FAILED:${all_errors}"
    echo "UPX-ERROR: UPX testsuite FAILED with $num_errors error(s). See log file."
fi
exit $exit_code
