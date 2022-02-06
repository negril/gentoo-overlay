# Copyright 2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

EGIT_REPO_URI="https://git.xn--jtunheimr-07a.org/aerith/paludis.git"
EGIT_BRANCH="gentoo"
PYTHON_COMPAT=( python3_{8..10} )
USE_RUBY="ruby26 ruby27 ruby30"

inherit bash-completion-r1 cmake git-r3 python-r1 ruby-utils

DESCRIPTION="paludis, the other package mangler"
HOMEPAGE="http://paludis.exherbo.org/"
SRC_URI=""

IUSE="doc pbins pink python ruby search-index test +xml"
LICENSE="GPL-2 vim"
SLOT="0/eapi8"
KEYWORDS=""

#ruby is stupid...
_ruby_get_all_impls() {
	local i
	for i in ${USE_RUBY}; do
		case ${i} in
			# removed implementations
			ruby19|ruby20|ruby21|ruby22|ruby23|ruby24|ruby25|jruby)
				;;
			*)
				echo ${i};;
		esac
	done
}

ruby_samelib() {
	local res=
	for _ruby_implementation in $(_ruby_get_all_impls); do
		has -${_ruby_implementation} $@ || \
			res="${res}ruby_targets_${_ruby_implementation}(-)?,"
	done

	echo "[${res%,}]"
}

ruby_implementations_depend() {
	local depend
	for _ruby_implementation in $(_ruby_get_all_impls); do
		depend="${depend}${depend+ }ruby_targets_${_ruby_implementation}? ( $(_ruby_implementation_depend $_ruby_implementation) )"
	done
	echo "${depend}"
}

ruby_get_use_targets() {
	local t implementation
	for implementation in $(_ruby_get_all_impls); do
		t+=" ruby_targets_${implementation}"
	done
	echo $t
}
IUSE+=" $(ruby_get_use_targets)"
###

COMMON_DEPEND="
	>=app-shells/bash-5.0:*
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
	${COMMON_DEPEND}
	${LINK_DEPEND}
"

#BDEPEND specifies dependencies applicable to CBUILD, i.e. programs that need to be executed during the build, e.g. virtual/pkgconfig. 
BDEPEND="${COMMON_DEPEND}
	>=app-text/asciidoc-8.6.3
	app-text/htmltidy
	app-text/xmlto
	>=sys-devel/gcc-8
	doc? (
		app-doc/doxygen
		python? ( dev-python/sphinx[${PYTHON_USEDEP}] )
		ruby? ( dev-ruby/syntax$(ruby_samelib) )
	)
	virtual/pkgconfig
	test? (
		${LINK_DEPEND}
		>=dev-cpp/gtest-1.6.0-r1
		sys-apps/sandbox
	)
"

#The RDEPEND ebuild variable should specify any dependencies which are required at runtime. This includes libraries (when dynamically linked), any data packages and (for interpreted languages) the relevant interpreter.
RDEPEND="
	${DEPEND}
	>=app-admin/eselect-1.2.13
	acct-user/paludisbuild
	acct-group/paludisbuild
	sys-apps/sandbox
"

PDEPEND="app-eselect/eselect-package-manager"

REQUIRED_USE="
	python? ( ${PYTHON_REQUIRED_USE} )
	ruby? ( || ( $(ruby_get_use_targets) ) )
"

RESTRICT="!test? ( test )"

pkg_pretend() {
	if [[ ${MERGE_TYPE} != buildonly ]]; then
		if id paludisbuild >/dev/null 2>/dev/null ; then
			if ! groups paludisbuild | grep --quiet '\<tty\>' ; then
				eerror "The 'paludisbuild' user is now expected to be a member of the"
				eerror "'tty' group. You should add the user to this group before"
				eerror "upgrading Paludis."
				die "Please add paludisbuild to tty group"
			fi
		fi
	fi
}

#pkg_setup() {
#	use python && python_setup
#	use ruby && ruby
#}

src_unpack() {
	git-r3_fetch
	git-r3_checkout
}

src_prepare() {
	if [[ $(use ruby) ]]; then
	# Fix the script shebang on Ruby scripts.
	# https://bugs.gentoo.org/show_bug.cgi?id=439372#c2
	sed -i -e "1s/ruby/&${RUBY_VER/./}/" ruby/demos/*.rb || die
	fi

	cmake_src_prepare
}

src_configure() {
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
	[[ $(use ruby) ]] && mycmakeargs+=( -DRUBY_VERSION=${RUBY_VER} )

	cmake_src_configure
}

src_install() {
	cmake_src_install

	dobashcomp bash-completion/cave

	insinto /usr/share/zsh/site-functions
	doins zsh-completion/_cave
}

src_test() {
	# Work around Portage bugs
	local -x PALUDIS_DO_NOTHING_SANDBOXY="portage sucks"
	local -x BASH_ENV=/dev/null

	if [[ ${EUID} == 0 ]] ; then
		# hate
		local -x PALUDIS_REDUCED_UID=0
		local -x PALUDIS_REDUCED_GID=0
	fi

	cmake_src_test
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
