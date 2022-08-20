# Copyright 2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="PHP Client to easily use the Domrobot API of INWX"
HOMEPAGE="https://www.inwx.com/en/ https://github.com/inwx/php-client"

if [[ ${PV} == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/inwx/php-client.git"
	S="${WORKDIR}/php-client"
else
	SRC_URI="https://github.com/inwx/php-client/archive/v${PV}.tar.gz -> inwx-domrobot-${PV}.tar.gz"
	KEYWORDS="~amd64 ~x86"
	S="${WORKDIR}/php-client-${PV}"
fi

LICENSE="MIT"
SLOT="0"
IUSE="json xmlrpc"
RESTRICT="mirror"

RDEPEND="
	>=dev-lang/php-7.2[curl]
	dev-php/psr-log
	dev-php/fedora-autoloader
	>=dev-php/monolog-2.0.0
	json? (
		|| (
			>=dev-lang/php-8
			<dev-lang/php-8[json]
		)
	)
	xmlrpc? (
		|| (
			>=dev-lang/php-8
			<dev-lang/php-8[xmlrpc]
		)
	)
"

src_install() {
	insinto "/usr/share/php/INWX"
	doins -r src/ "${FILESDIR}"/autoload.php
	dodoc README.md
}
