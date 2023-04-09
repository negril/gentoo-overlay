# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{9..11} pypy3 )
inherit distutils-r1

DESCRIPTION="INWX Domrobot Python Client"
HOMEPAGE="https://www.inwx.com/en https://github.com/inwx/python-client"

if [[ ${PV} == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/inwx/python-client.git"
	S="${WORKDIR}/python-client"
else
	SRC_URI="https://github.com/inwx/python-client/archive/v${PV}.tar.gz -> inwx-python-client-${PV}.tar.gz"
	KEYWORDS="~amd64 ~x86"
	S="${WORKDIR}/python-client-${PV}"
fi

LICENSE="MIT"
SLOT="0"
IUSE=""
RESTRICT="mirror"

RDEPEND="
	dev-python/requests
"

# src_install() {
# 	insinto "/usr/share/python/INWX"
# 	doins -r src/ "${FILESDIR}"/autoload.python
# 	dodoc README.md
# }
