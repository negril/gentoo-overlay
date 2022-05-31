# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

if [[ "${PV}" == 9999 ]] ; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/mariadb-corporation/mariadb-connector-cpp.git"
else
	MY_PN=${PN#mariadb-}
	MY_PV=${PV/_b/-b}
	SRC_URI="https://downloads.mariadb.com/Connectors/cpp/connector-cpp-${PV}/${P}-src.tar.gz"
	S="${WORKDIR%/}/${PN}-${MY_PV}-src"
	KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~hppa ~ia64 ~ppc ~ppc64 ~riscv ~s390 ~sparc ~x86"
fi

CMAKE_ECLASS=cmake
inherit cmake-multilib toolchain-funcs

MULTILIB_WRAPPED_HEADERS+=(
	/usr/include/mariadb/mariadb_version.h
)

DESCRIPTION="MariaDB Connector for C++"
HOMEPAGE="https://mariadb.org/"
LICENSE="LGPL-2.1"

SLOT="0/1"
IUSE="+curl gnutls kerberos +ssl static-libs test"

RESTRICT="!test? ( test ) mirror"

DEPEND="sys-libs/zlib:=[${MULTILIB_USEDEP}]
	virtual/libiconv:=[${MULTILIB_USEDEP}]
	curl? ( net-misc/curl:0=[${MULTILIB_USEDEP}] )
	kerberos? ( || ( app-crypt/mit-krb5[${MULTILIB_USEDEP}]
			app-crypt/heimdal[${MULTILIB_USEDEP}] ) )
	ssl? (
		gnutls? ( >=net-libs/gnutls-3.3.24:0=[${MULTILIB_USEDEP}] )
		!gnutls? (
			dev-libs/openssl:0=[${MULTILIB_USEDEP}]
		)
	)
	"
RDEPEND="${DEPEND}"

multilib_src_configure() {
	# bug 508724 mariadb cannot use ld.gold
	tc-ld-disable-gold

	local mycmakeargs=(
		-DWITH_EXTERNAL_ZLIB=ON
		-DWITH_SSL:STRING=$(usex ssl $(usex gnutls gnutls openssl) OFF)
		-DWITH_CURL=$(usex curl ON OFF)
		-DWITH_ICONV=ON
		-DMARIADB_UNIX_ADDR="${EPREFIX}/var/run/mysqld/mysqld.sock"
		-DINSTALL_LIBDIR="$(get_libdir)"
		-DINSTALL_MANDIR=share/man
		-DINSTALL_PCDIR="$(get_libdir)/pkgconfig"
		-DINSTALL_PLUGINDIR="$(get_libdir)/mariadb/plugin"
		-DINSTALL_BINDIR=bin
		-DWITH_UNIT_TESTS=$(usex test ON OFF)
	)
	cmake_src_configure
}

multilib_src_install_all() {
	if ! use static-libs ; then
		find "${ED}" -name "*.a" -delete || die
	fi
}
