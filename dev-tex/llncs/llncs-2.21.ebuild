# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit latex-package

DESCRIPTION="Springer's llncs document class and bibliography style."
HOMEPAGE="https://www.springer.com/gp/computer-science/lncs"
SRC_URI="https://xn--jtunheimr-07a.org/mirror/${P}.zip"

LICENSE="LPPL-1.3c"
SLOT="0"
KEYWORDS="~amd64 ~x86"

RESTRICT="mirror"

S="${WORKDIR}/${PN}"

BDEPEND="app-arch/unzip"

src_install() {
	insinto "${TEXMF}/tex/latex/${PN}"
	doins -r .
}
