# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="A CoAP (RFC 7252) implementation in C"
HOMEPAGE="https://coap.space/"
SRC_URI="
	https://github.com/obgm/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
"

RESTRICT="mirror"

LICENSE="BSD-2"
SLOT="3/3.2.0"
KEYWORDS="~amd64 ~arm ~arm64 ~ppc64 ~riscv ~x86"
IUSE="
doc
+epoll
examples
gnutls
mbedtls
openssl
test
tinydtls
"
RESTRICT="!test? ( test )"

REQUIRED_USE="
	|| (
		gnutls
		mbedtls
		openssl
		tinydtls
	)
"

DEPEND="
	gnutls? (
		net-libs/gnutls
	)
	openssl? (
		dev-libs/openssl
	)
	mbedtls? (
		net-libs/mbedtls
	)
"
RDEPEND="
	${DEPEND}
"


src_configure() {
	local mycmakeargs=(
# 		#  Name of the dtls backend, only relevant if `ENABLE_DTLS` is ON which is default. Possible values: default, gnutls, openssl, wolfssl, tinydtls and mbedtls. If specified then this library will be searched and if found also used. If not found then the cmake configuration will stop with an error. If not specified, then cmake will try to use the first one found in the following order: gnutls, openssl, wolfssl, tinydtls, mbedtls
# 		-DDTLS_BACKEND:STRING="default"
#
# 		#  enable building with Unix socket support
# 		-DENABLE_AF_UNIX:BOOL=ON
#
# 		#  enable building with async separate response support
# 		-DENABLE_ASYNC:BOOL=ON
#
# 		#  compile with support for client mode code
# 		-DENABLE_CLIENT_MODE:BOOL=ON

		#  build also doxygen documentation
		-DENABLE_DOCS:BOOL="$(usex doc)"

# 		#  enable building with DTLS support
# 		-DENABLE_DTLS:BOOL=ON

		#  build also examples
		-DENABLE_EXAMPLES:BOOL="$(usex examples)"

# 		#  enable building with IPv4 support
# 		-DENABLE_IPV4:BOOL=ON
#
# 		#  enable building with IPv6 support
# 		-DENABLE_IPV6:BOOL=ON
#
# 		#  compile with support for OSCORE
# 		-DENABLE_OSCORE:BOOL=ON
#
# 		#  compile with support for proxy code
# 		-DENABLE_PROXY_CODE:BOOL=ON
#
# 		#  enable building with Q-Block (RFC9177) support
# 		-DENABLE_Q_BLOCK:BOOL=ON
#
# 		#  compile with support for server mode code
# 		-DENABLE_SERVER_MODE:BOOL=ON
#
# 		#  enable if the system has small stack size
# 		-DENABLE_SMALL_STACK:BOOL=OFF
#
# 		#  enable building with TCP support
# 		-DENABLE_TCP:BOOL=ON

		#  build also tests
		-DENABLE_TESTS:BOOL="$(usex test)"

# 		#  enable building with thread recursive lock detection
# 		-DENABLE_THREAD_RECURSIVE_LOCK_CHECK:BOOL=OFF
#
# 		#  enable building with thread safe support
# 		-DENABLE_THREAD_SAFE:BOOL=ON

		#  enable building with WebSockets support
		-DENABLE_WS:BOOL="$(usex websocket)"

# 		#  Only build logging code up to and including the specified logging level (0 - 8)[default=8]]
# 		-DMAX_LOGGING_LEVEL:STRING=8

		#  compile with the tinydtls project in the submodule if on, otherwise try to find the compiled lib with find_package
		-DUSE_VENDORED_TINYDTLS:BOOL="$(usex tinydtls)"

		#  compile with epoll support
		-DWITH_EPOLL:BOOL="$(usex epoll)"

# 		#  compile with observe persist support for server restarts
# 		-DWITH_OBSERVE_PERSIST:BOOL=ON

# 		-DWITH_GNUTLS="$(usex gnutls)"
# 		-DWITH_OPENSSL="$(usex openssl)"
# 		-DWITH_MBEDTLS="$(usex mbedtls)"
	)

	local DTLS_BACKEND="default"
	if use tinydls; then
		DTLS_BACKEND="tinydls"
	elif use gnutls; then
		DTLS_BACKEND="gnutls"
	elif use openssl; then
		DTLS_BACKEND="openssl"
	elif use mbedtls; then
		DTLS_BACKEND="mbedtls"
	fi

	mycmakeargs+=(
		-DDTLS_BACKEND="${DTLS_BACKEND}"
	)

	cmake_src_configure
}
