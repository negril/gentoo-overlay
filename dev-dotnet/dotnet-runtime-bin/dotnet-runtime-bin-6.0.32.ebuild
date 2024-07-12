# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

SDK="6.0.424"

DESCRIPTION=".NET Core runtime (binary)"
HOMEPAGE="https://dotnet.microsoft.com/"

SRC_URI="
amd64? (
elibc_glibc? ( https://dotnetcli.azureedge.net/dotnet/Sdk/${SDK}/dotnet-sdk-${SDK}-linux-x64.tar.gz )
)
"

S=${WORKDIR}

LICENSE="MIT"
SLOT="6.0"
KEYWORDS="~amd64 ~arm ~arm64"
QA_PREBUILT="*"
RESTRICT+=" splitdebug"

REQUIRED_USE="|| ( elibc_glibc elibc_musl )"

RDEPEND="
	>=dev-dotnet/dotnet-hostfxr-bin-6.0.32:6.0
"

src_install() {
	local dotnet_root="opt/dotnet"
	dodir "${dotnet_root%/*}"

	insinto "${dotnet_root}/shared"
	doins -r shared/Microsoft.NETCore.App
}
