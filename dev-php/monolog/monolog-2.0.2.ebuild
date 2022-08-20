# Copyright 2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="Sends your logs to files, sockets, inboxes, databases and various web services"
HOMEPAGE="https://github.com/Seldaek/monolog"

if [[ ${PV} == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/Seldaek/monolog.git"
else
	SRC_URI="https://github.com/Seldaek/monolog/archive/${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64 ~x86"
fi

LICENSE="MIT"
SLOT="0"
RESTRICT="mirror"

RDEPEND="
	>=dev-lang/php-7.2
	dev-php/psr-log
	dev-php/fedora-autoloader"

src_install() {
	insinto "/usr/share/php/Monolog"
	doins -r src/ "${FILESDIR}"/autoload.php
	dodoc README.md
}
