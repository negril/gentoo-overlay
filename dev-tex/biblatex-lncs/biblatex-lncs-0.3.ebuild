# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit latex-package

DESCRIPTION="BiBLaTeX style for Springer Lecture Notes in Computer Science"
HOMEPAGE="https://github.com/mgttlinger/biblatex-lncs"
SRC_URI="https://github.com/mgttlinger/${PN}/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="LPPL-1.3c"
SLOT="0"
KEYWORDS="~amd64 ~x86"

RESTRICT="mirror"

BDEPEND="
	dev-perl/File-Copy-Recursive
"

RDEPEND="
	dev-texlive/texlive-latexextra
	>=dev-tex/biblatex-3.8
	>=dev-tex/biber-2.8
"

DEPEND="${RDEPEND}"

src_compile(){
	./release.sh
	tar xf "${PN}.tar.gz"
}

src_install() {
	insinto "${TEXMF}/tex/latex"
	doins -r ${PN}
}
