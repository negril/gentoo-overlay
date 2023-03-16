# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

SDK="6.0.407"

DESCRIPTION=".NET Core App Host pack for linux x64 (binary)"
HOMEPAGE="https://dotnet.microsoft.com/"
LICENSE="MIT"

SRC_URI="
amd64? (
	elibc_glibc? ( https://dotnetcli.azureedge.net/dotnet/Sdk/${SDK}/dotnet-sdk-${SDK}-linux-x64.tar.gz )
	elibc_musl?  ( https://dotnetcli.azureedge.net/dotnet/Sdk/${SDK}/dotnet-sdk-${SDK}-linux-musl-x64.tar.gz )
)
arm? (
	elibc_glibc? ( https://dotnetcli.azureedge.net/dotnet/Sdk/${SDK}/dotnet-sdk-${SDK}-linux-arm.tar.gz )
	elibc_musl?  ( https://dotnetcli.azureedge.net/dotnet/Sdk/${SDK}/dotnet-sdk-${SDK}-linux-musl-arm.tar.gz )
)
arm64? (
	elibc_glibc? ( https://dotnetcli.azureedge.net/dotnet/Sdk/${SDK}/dotnet-sdk-${SDK}-linux-arm64.tar.gz )
	elibc_musl?  ( https://dotnetcli.azureedge.net/dotnet/Sdk/${SDK}/dotnet-sdk-${SDK}-linux-musl-arm64.tar.gz )
)
"

SLOT="6.0"
KEYWORDS="~amd64 ~arm ~arm64"
QA_PREBUILT="*"
RESTRICT+=" splitdebug"

REQUIRED_USE="|| ( elibc_glibc elibc_musl )"

S=${WORKDIR}

src_install() {
	local dotnet_root="opt/dotnet"
	dodir "${dotnet_root%/*}"

	insinto "${dotnet_root}/packs"
	doins -r packs/Microsoft.NETCore.App.Host.linux-x64
}
