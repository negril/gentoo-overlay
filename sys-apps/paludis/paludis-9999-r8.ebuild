# Copyright 2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{8..12} )

USE_RUBY="$(echo ruby{30..32})"
RUBY_OPTIONAL="yes"

inherit bash-completion-r1 cmake python-r1

#ruby is stupid...
_S="$S"
inherit ruby-ng
S="$_S"

DESCRIPTION="paludis, the other package mangler"
HOMEPAGE="https://paludis.exherbo.org/"

if [[ ${PV} == *9999* ]] ; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/negril/paludis.git"
	EGIT_BRANCH="gentoo"
else
	if [[ ${PV} == *_beta* ]] ; then
		SRC_URI="https://github.com/negril/paludis/archive/refs/tags/v${PV/_/-}.tar.gz -> ${P}.tar.gz"
		S="${WORKDIR}"/${P/_/-}
	else
		SRC_URI="https://github.com/negril/paludis/releases/download/v${PV}/${P}.tar.gz"
		S="${WORKDIR}/${PN}"
		KEYWORDS="~amd64 ~x86"
	fi
fi

LICENSE="GPL-2 vim"
SLOT="0/eapi8"

IUSE="doc pbins pink python ruby search-index test +xml"

COMMON_DEPEND="
	python? ( ${PYTHON_DEPS} )
	ruby? ( $( ruby_implementations_depend ) )
"

LINK_DEPEND="
	dev-libs/libpcre:=[cxx]
	sys-apps/file:=
	pbins? ( >=app-arch/libarchive-3.1.2:= )
	python? ( dev-libs/boost[python,${PYTHON_USEDEP}] )
	search-index? ( >=dev-db/sqlite-3:= )
	xml? ( >=dev-libs/libxml2-2.6:= )
"

#DEPEND specifies dependencies for CHOST, i.e. packages that need to be found on built system, e.g. libraries and headers.
DEPEND="
	${LINK_DEPEND}
	${COMMON_DEPEND}
"

#BDEPEND specifies dependencies applicable to CBUILD, i.e. programs that need to be executed during the build, e.g. virtual/pkgconfig.
BDEPEND="
	>=app-shells/bash-5.0:*
	>=app-text/asciidoc-8.6.3
	app-text/htmltidy
	app-text/xmlto
	>=sys-devel/gcc-8
	virtual/pkgconfig
	doc? (
		app-doc/doxygen
		python? ( dev-python/sphinx[${PYTHON_USEDEP}] )
		ruby? ( dev-ruby/syntax$(ruby_samelib) )
	)
	${COMMON_DEPEND}
	test? (
		${LINK_DEPEND}
		>=dev-cpp/gtest-1.6.0-r1
		sys-apps/sandbox
	)
"

#The RDEPEND ebuild variable should specify any dependencies which are required at runtime. This includes libraries (when dynamically linked), any data packages and (for interpreted languages) the relevant interpreter.
RDEPEND="
	acct-user/paludisbuild
	acct-group/paludisbuild
	sys-apps/sandbox
	${DEPEND}
"

PDEPEND="app-eselect/eselect-package-manager"

REQUIRED_USE="
	python? ( ${PYTHON_REQUIRED_USE} )
	ruby? ( || ( $(ruby_get_use_targets) ) )
"

RESTRICT="!test? ( test )"

# pkg_pretend() {
# 	echo "pkg_pretend"
# 	local MULTIBUILD_VARIANTS
# 	_python_obtain_impls
# 	echo "${MULTIBUILD_VARIANTS[@]}" | tr ' ' ';'
# 	ruby_get_use_implementations | tr ' ' ';'
# }

# pkg_setup() {
	# use python && python_setup
# }

# src_unpack() {
# 	git-r3_fetch
# 	git-r3_checkout
# }

src_prepare() {
# TODO FIXME
# 	if [[ $(use ruby) ]]; then
# 	# Fix the script shebang on Ruby scripts.
# 	# https://bugs.gentoo.org/show_bug.cgi?id=439372#c2
# 	sed -i -e "1s/ruby/&${RUBY_VER/./}/" ruby/demos/*.rb || die
# 	fi

	cmake_src_prepare
}

src_configure() {
	# TODO cmake
	local mycmakeargs=(
		-DENABLE_DOXYGEN=$(usex doc)
		-DENABLE_GTEST=$(usex test)
		-DENABLE_PBINS=$(usex pbins)
		-DENABLE_PYTHON=$(usex python)
		-DENABLE_PYTHON_DOCS=$(usex doc) # USE=python implicit
		-DENABLE_RUBY=$(usex ruby)
		-DENABLE_RUBY_DOCS=$(usex doc) # USE=ruby implicit
		-DENABLE_SEARCH_INDEX=$(usex search-index)
		-DENABLE_VIM=ON
		-DENABLE_XML=$(usex xml)

		-DPALUDIS_COLOUR_PINK=$(usex pink)
		-DPALUDIS_ENVIRONMENTS=all
		-DPALUDIS_DEFAULT_DISTRIBUTION=gentoo
		-DPALUDIS_CLIENTS=all
		-DCONFIG_FRAMEWORK=eselect

		# GNUInstallDirs
# 		-DCMAKE_INSTALL_DOCDIR="${EPREFIX}/usr/share/doc/${PF}"
	)
# 	use ruby && mycmakeargs+=( -DRUBY_VERSIONS="$(ruby_get_use_implementations | tr ' ' ';')" )
# 	use python && {
# 		local MULTIBUILD_VARIANTS
# 		_python_obtain_impls
# 		mycmakeargs+=( -DPYTHON_VERSIONS="$(echo "${MULTIBUILD_VARIANTS[@]//_/.}" | tr ' ' ';')")
# 	}

	cmake_src_configure
}

src_compile() {
	cmake_src_compile
}

src_install() {
	cmake_src_install

	dobashcomp bash-completion/cave

	insinto /usr/share/zsh/site-functions
	doins zsh-completion/_cave
}

src_test() {
	# known broken tests
	skip_tests=(
		"best_version"
		"banned_dolib_rep"
		"prefix"
		"env_unset"
	)
	cmake_src_test -E ".*($(IFS=\| ; echo "${skip_tests[*]}")).*"
}

pkg_postinst() {
	local pm
	if [[ -f ${ROOT}/etc/env.d/50package-manager ]] ; then
		pm=$( source "${ROOT}"/etc/env.d/50package-manager ; echo "${PACKAGE_MANAGER}" )
	fi

	if [[ ${pm} != paludis ]] ; then
		elog "If you are using paludis or cave as your primary package manager,"
		elog "you should consider running:"
		elog "    eselect package-manager set paludis"
	fi
}
