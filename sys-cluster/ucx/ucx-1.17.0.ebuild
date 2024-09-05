# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools toolchain-funcs flag-o-matic

DESCRIPTION="Unified Communication X"
HOMEPAGE="https://github.com/openucx/ucx https://www.openucx.org"
SRC_URI="https://github.com/openucx/ucx/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
# SRC_URI="https://github.com/openucx/ucx/releases/download/v${PV}/${P}.tar.gz"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64 -riscv ~x86"

X86_CPU_FLAGS=(
	sse4_1
	sse4_2
	avx
)
CPU_FLAGS=(
	"${X86_CPU_FLAGS[@]/#/cpu_flags_x86_}"
)
IUSE="+cma +cuda +examples +fuse go java +mpi +openmp +rocm +test +threads ${CPU_FLAGS[*]}"

RESTRICT="!test? ( test )"

RDEPEND="
	sys-libs/binutils-libs:=
"
DEPEND="${RDEPEND}"

PATCHES=(
	"${FILESDIR}/${PN}-1.13.0-drop-werror.patch"
	# "${FILESDIR}"/${PN}-1.13.0-fix-bashisms.patch
	# "${FILESDIR}"/${PN}-1.13.0-fix-fcntl-include-musl.patch
	# "${FILESDIR}"/${PN}-1.13.0-cstdint-include.patch
	# "${FILESDIR}"/${PN}-1.13.0-binutils-2.39-ptr-typedef.patch
	# "${FILESDIR}"/${PN}-1.13.0-no-rpm-sandbox.patch
	"${FILESDIR}/${PN}-1.17.0-include-cstdint.patch"
)

pkg_pretend() {
	[[ ${MERGE_TYPE} != binary ]] && use openmp && tc-check-openmp
}

pkg_setup() {
	[[ ${MERGE_TYPE} != binary ]] && use openmp && tc-check-openmp
}

src_prepare() {
	default
	eautoreconf
}

src_configure() {
	local march mcpu

	local myeconfargs=(
		--disable-compiler-opt
		"$(use_with cpu_flags_x86_avx avx)"
		"$(use_with cpu_flags_x86_sse4_1 sse41)"
		"$(use_with cpu_flags_x86_sse4_2 sse42)"
		"$(use_with fuse fuse3)"
		"$(use_with go)"
		"$(use_with java)"
		"$(use_enable openmp)"
		"$(use_with cuda cuda "$(pkgconf --variable=cudaroot cuda)")"
		"$(use_with rocm)"
		"$(use_enable test gtest)"
		"$(use_enable cma)"
		"$(use_enable threads mt)"
		"$(use_enable examples)"
		"$(use_with mpi)"

		# --enable-devel-headers
	)

	march="$(get-flag march)"
	[[ -n "${march}" ]] && myeconfargs+=( --with-march="${march}" )

	mcpu="$(get-flag mcpu)"
	[[ -n "${mcpu}" ]] && myeconfargs+=( --with-mcpu="${mcpu}" )

	if use cuda && use examples; then
		myeconfargs+=(
			--with-iodemo-cuda
		)
	fi

	BASE_CFLAGS="${CFLAGS}" \
	BASE_CXXFLAGS="${CXXFLAGS}" \
		econf "${myeconfargs[@]}"
}

src_compile() {
	adddeny=/usr/lib64/libucp.so.0

	BASE_CFLAGS="${CFLAGS}" \
	BASE_CXXFLAGS="${CXXFLAGS}" \
		emake
}

src_test() {
	# ./src/tools/perf/ucx_perftest -c 0
	# ./src/tools/perf/ucx_perftest <server-hostname> -t tag_lat -c 1
	BASE_CFLAGS="${CFLAGS}" \
	BASE_CXXFLAGS="${CXXFLAGS}" \
		emake -C test/gtest test
}
