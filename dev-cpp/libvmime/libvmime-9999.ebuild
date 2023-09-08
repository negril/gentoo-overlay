# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3 cmake

DESCRIPTION="Library for working with MIME messages and Internet messaging services"
HOMEPAGE="https://www.vmime.org"
EGIT_REPO_URI="https://github.com/kisli/vmime.git"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""
IUSE="debug doc examples gnutls +icu +imap +maildir pop sasl sendmail +smtp ssl static test"

RESTRICT="!test? ( test )"

RDEPEND="
	gnutls? ( >=net-libs/gnutls-1.2.0 )
	icu? ( dev-libs/icu:= )
	sasl? ( >=net-misc/gsasl-2.0.0 )
	sendmail? ( virtual/mta )
	ssl? (
		!gnutls? ( dev-libs/openssl:= )
		gnutls? ( net-libs/gnutls:= )

	)
"

BDEPEND="
	${RDEPEND}
	doc? ( app-doc/doxygen )
"

src_configure() {
	local mycmakeargs=(
	"-DVMIME_BUILD_DOCUMENTATION=$(usex doc)"
	"-DVMIME_BUILD_SAMPLES=$(usex samples)"
	"-DVMIME_BUILD_SHARED_LIBRARY=yes"
	"-DVMIME_BUILD_STATIC_LIBRARY=$(usex static)"
	"-DVMIME_BUILD_TESTS=$(usex test)"
	"-DVMIME_CHARSETCONV_LIB=$(usex icu icu iconv)"

	"-DVMIME_HAVE_FILESYSTEM_FEATURES=$(usex maildir)"
	"-DVMIME_HAVE_MESSAGING_FEATURES=$(usex imap yes "$(usex maildir yes "$(usex pop yes "$(usex sendmail yes "$(usex smtp yes no)")")")")"

	"-DVMIME_HAVE_MESSAGING_PROTO_IMAP=$(usex imap)"
	"-DVMIME_HAVE_MESSAGING_PROTO_MAILDIR=$(usex maildir)"
	"-DVMIME_HAVE_MESSAGING_PROTO_POP3=$(usex pop)"
	"-DVMIME_HAVE_MESSAGING_PROTO_SENDMAIL=$(usex sendmail)"
	"-DVMIME_HAVE_MESSAGING_PROTO_SMTP=$(usex smtp)"

	"-DVMIME_HAVE_SASL_SUPPORT=$(usex sasl)"
	"-DVMIME_HAVE_TLS_SUPPORT=$(usex ssl yes "$(usex gnutls)")"

	"-DVMIME_TLS_SUPPORT_LIB=$(usex ssl openssl "$(usex gnutls gnutls)")"
	)

	if use debug; then
		CMAKE_BUILD_TYPE="Debug"
	else
		CMAKE_BUILD_TYPE="RelWithDebInfo"
	fi
	cmake_src_configure
}

src_install() {
	cmake_src_install
	dodoc AUTHORS

	local HTML_DOCS=( "doc/html" )
	use doc && einstalldocs

	use examples && dodoc examples
}
