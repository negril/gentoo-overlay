# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

SDK="7.0.302"

DESCRIPTION="ASP.NET Core runtime (binary)"
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

SLOT="7.0"
KEYWORDS="~amd64 ~arm ~arm64"
QA_PREBUILT="*"
RESTRICT+=" splitdebug"

REQUIRED_USE="|| ( elibc_glibc elibc_musl )"

RDEPEND="
	>=dev-dotnet/dotnet-runtime-bin-7.0.5:7.0
"

S=${WORKDIR}

src_install() {
	local dotnet_root="opt/dotnet"
	dodir "${dotnet_root%/*}"

	insinto "${dotnet_root}/shared"
	[[ -d "shared/Microsoft.AspNetCore.App" ]] && doins -r shared/Microsoft.AspNetCore.App
	[[ -d "shared/Microsoft.AspNetCore.All" ]] && doins -r shared/Microsoft.AspNetCore.All
}
